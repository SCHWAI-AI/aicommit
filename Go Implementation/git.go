package git

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// IsGitRepository checks if the current directory is a git repository
func IsGitRepository() bool {
	cmd := exec.Command("git", "rev-parse", "--git-dir")
	err := cmd.Run()
	return err == nil
}

// IsClaspProject checks if .clasp.json exists
func IsClaspProject() bool {
	_, err := os.Stat(".clasp.json")
	return err == nil
}

// GetFullDiff gets the complete diff including tracked and untracked files
func GetFullDiff() (string, error) {
	var fullDiff strings.Builder

	// Get tracked file changes
	trackedCmd := exec.Command("git", "diff", "HEAD")
	trackedOutput, err := trackedCmd.Output()
	if err != nil {
		// If there's no HEAD (initial commit), use diff --cached
		trackedCmd = exec.Command("git", "diff", "--cached")
		trackedOutput, _ = trackedCmd.Output()
	}

	if len(trackedOutput) > 0 {
		fullDiff.WriteString("=== MODIFIED FILES ===\n")
		fullDiff.Write(trackedOutput)
		fullDiff.WriteString("\n\n")
	}

	// Get untracked files
	untrackedCmd := exec.Command("git", "ls-files", "--others", "--exclude-standard")
	untrackedOutput, err := untrackedCmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get untracked files: %w", err)
	}

	if len(untrackedOutput) > 0 {
		fullDiff.WriteString("=== NEW FILES ===\n")
		untrackedFiles := strings.Split(strings.TrimSpace(string(untrackedOutput)), "\n")
		
		for _, file := range untrackedFiles {
			if file == "" {
				continue
			}
			
			fullDiff.WriteString(fmt.Sprintf("\n--- New file: %s ---\n", file))
			
			// Try to read the file content
			content, err := os.ReadFile(file)
			if err != nil {
				fullDiff.WriteString(fmt.Sprintf("[Could not read file: %v]\n", err))
				continue
			}

			// Add content with + prefix (like git diff)
			lines := strings.Split(string(content), "\n")
			for _, line := range lines {
				fullDiff.WriteString("+" + line + "\n")
			}
			fullDiff.WriteString("\n")
		}
	}

	return fullDiff.String(), nil
}

// StageAll stages all changes
func StageAll() error {
	cmd := exec.Command("git", "add", ".")
	return cmd.Run()
}

// Commit creates a commit with the given message
func Commit(message string) error {
	cmd := exec.Command("git", "commit", "-m", message)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("git commit failed: %v - %s", err, stderr.String())
	}
	return nil
}

// Push pushes to the remote repository
func Push() error {
	cmd := exec.Command("git", "push")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("git push failed: %v - %s", err, stderr.String())
	}
	return nil
}

// ClaspPush pushes to clasp
func ClaspPush() error {
	// Check if clasp is installed
	if _, err := exec.LookPath("clasp"); err != nil {
		return fmt.Errorf("clasp is not installed")
	}

	cmd := exec.Command("clasp", "push")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("clasp push failed: %v - %s", err, stderr.String())
	}
	return nil
}

// GetLastCommit returns the last commit message
func GetLastCommit() (string, error) {
	cmd := exec.Command("git", "log", "-1", "--oneline")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// GetCurrentBranch returns the current branch name
func GetCurrentBranch() (string, error) {
	cmd := exec.Command("git", "rev-parse", "--abbrev-ref", "HEAD")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// HasRemote checks if a remote is configured
func HasRemote() bool {
	cmd := exec.Command("git", "remote")
	output, _ := cmd.Output()
	return len(output) > 0
}

// GetRepoRoot returns the root directory of the git repository
func GetRepoRoot() (string, error) {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// IsClean checks if the working directory is clean
func IsClean() bool {
	cmd := exec.Command("git", "status", "--porcelain")
	output, _ := cmd.Output()
	return len(output) == 0
}

// GetStatus returns the git status output
func GetStatus() (string, error) {
	cmd := exec.Command("git", "status", "--short")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(output), nil
}

// GetStagedFiles returns a list of staged files
func GetStagedFiles() ([]string, error) {
	cmd := exec.Command("git", "diff", "--cached", "--name-only")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	
	if len(output) == 0 {
		return []string{}, nil
	}
	
	files := strings.Split(strings.TrimSpace(string(output)), "\n")
	return files, nil
}

// GetModifiedFiles returns a list of modified files
func GetModifiedFiles() ([]string, error) {
	cmd := exec.Command("git", "diff", "--name-only")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	
	if len(output) == 0 {
		return []string{}, nil
	}
	
	files := strings.Split(strings.TrimSpace(string(output)), "\n")
	return files, nil
}

// GetUntrackedFiles returns a list of untracked files
func GetUntrackedFiles() ([]string, error) {
	cmd := exec.Command("git", "ls-files", "--others", "--exclude-standard")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	
	if len(output) == 0 {
		return []string{}, nil
	}
	
	files := strings.Split(strings.TrimSpace(string(output)), "\n")
	
	// Filter out empty strings
	var result []string
	for _, file := range files {
		if file != "" {
			result = append(result, file)
		}
	}
	
	return result, nil
}

// GetFileExtensions returns unique file extensions from changed files
func GetFileExtensions() ([]string, error) {
	extensions := make(map[string]bool)
	
	// Get all changed files
	modified, _ := GetModifiedFiles()
	untracked, _ := GetUntrackedFiles()
	
	allFiles := append(modified, untracked...)
	
	for _, file := range allFiles {
		ext := filepath.Ext(file)
		if ext != "" {
			extensions[ext] = true
		}
	}
	
	// Convert map to slice
	var result []string
	for ext := range extensions {
		result = append(result, ext)
	}
	
	return result, nil
}
