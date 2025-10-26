package cmd

import (
	"fmt"
	"os"

	"github.com/SCHWAI-AI/aicommit/internal/config"
	"github.com/SCHWAI-AI/aicommit/internal/git"
	"github.com/SCHWAI-AI/aicommit/internal/llm"
	"github.com/SCHWAI-AI/aicommit/internal/prompt"
	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

var (
	pushFlag  bool
	claspFlag bool
	cfgFile   string
	version   = "1.0.0"
)

var rootCmd = &cobra.Command{
	Use:   "aicommit",
	Short: "AI-powered Git commit message generator",
	Long: `AICommit analyzes your git diff and generates intelligent commit messages
using AI models (Claude, Gemini, or OpenAI).`,
	RunE: runCommit,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	cobra.OnInitialize(initConfig)

	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.config/aicommit/config.yaml)")
	rootCmd.Flags().BoolVarP(&pushFlag, "push", "p", false, "Push to git remote after committing")
	rootCmd.Flags().BoolVarP(&claspFlag, "clasp", "c", false, "Push to clasp after committing (for Google Apps Script projects)")
	rootCmd.Version = version
}

func initConfig() {
	if err := config.Initialize(cfgFile); err != nil {
		color.Red("Error initializing config: %v", err)
		os.Exit(1)
	}
}

func runCommit(cmd *cobra.Command, args []string) error {
	// Check if we're in a git repository
	if !git.IsGitRepository() {
		return fmt.Errorf("not in a git repository")
	}

	// Check for clasp if flag is set
	if claspFlag {
		if !git.IsClaspProject() {
			return fmt.Errorf("not in a clasp repository (.clasp.json not found)")
		}

		confirmed, err := prompt.Confirm("Have you pulled from clasp?", false)
		if err != nil {
			return err
		}
		if !confirmed {
			color.Yellow("Please run 'clasp pull' first, then try again")
			return nil
		}
	}

	// Get the diff
	color.Yellow("Analyzing changes...")
	diff, err := git.GetFullDiff()
	if err != nil {
		return fmt.Errorf("failed to get diff: %w", err)
	}

	if diff == "" {
		color.Green("No changes to commit")
		return nil
	}

	// Get configuration
	cfg := config.GetConfig()

	// Initialize LLM client
	client, err := llm.NewClient(cfg.Model, cfg.GetAPIKey())
	if err != nil {
		return fmt.Errorf("failed to initialize AI client: %w", err)
	}

	// Generate commit message
	color.Yellow("Getting AI suggestion...")
	suggestion, err := client.GenerateCommitMessage(diff)
	if err != nil {
		return fmt.Errorf("failed to generate commit message: %w", err)
	}

	// Interactive commit message loop
	committed := false
	currentMessage := suggestion

	for !committed {
		// Display current message
		fmt.Println()
		color.Cyan("--- SUGGESTED COMMIT MESSAGE ---")
		color.White("HEADER: %s", currentMessage.Header)
		if currentMessage.Description != "" {
			color.White("DESCRIPTION: %s", currentMessage.Description)
		}
		color.Cyan("--- END MESSAGE ---")
		fmt.Println()

		// Get user decision
		choice, err := prompt.Select("Use this message?", []string{"yes", "edit", "cancel"})
		if err != nil {
			return err
		}

		switch choice {
		case "cancel":
			color.Yellow("Commit cancelled")
			return nil

		case "edit":
			edited, err := prompt.EditCommitMessage(currentMessage)
			if err != nil {
				return err
			}
			currentMessage = edited

		case "yes":
			// Stage all changes
			color.Yellow("Staging changes...")
			if err := git.StageAll(); err != nil {
				return fmt.Errorf("failed to stage changes: %w", err)
			}

			// Commit
			color.Yellow("Committing...")
			finalMessage := currentMessage.Format()
			if err := git.Commit(finalMessage); err != nil {
				return fmt.Errorf("failed to commit: %w", err)
			}

			color.Green("\nCommit successful!")
			
			// Show what was committed
			lastCommit, _ := git.GetLastCommit()
			if lastCommit != "" {
				color.Cyan("Created: %s", lastCommit)
			}

			committed = true

			// Push if requested
			if pushFlag {
				color.Yellow("Pushing to remote...")
				if err := git.Push(); err != nil {
					color.Red("Push failed: %v", err)
				} else {
					color.Green("Push successful!")
				}
			}

			// Push to clasp if requested
			if claspFlag {
				color.Yellow("Pushing to clasp...")
				if err := git.ClaspPush(); err != nil {
					color.Red("Clasp push failed: %v", err)
				} else {
					color.Green("Clasp push successful!")
				}
			}
		}
	}

	return nil
}
