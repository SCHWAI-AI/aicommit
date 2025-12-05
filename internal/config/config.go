package config

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/99designs/keyring"
	"github.com/adrg/xdg"
	"github.com/spf13/viper"
)

const (
	serviceName = "aicommit"
	appName     = "AICommit"
)

type Config struct {
	Model          string `mapstructure:"model"`
	MaxDiffLength  int    `mapstructure:"max_diff_length"`
	Provider       string `mapstructure:"provider"`
	AnthropicModel string `mapstructure:"anthropic_model"`
	GeminiModel    string `mapstructure:"gemini_model"`
	OpenAIModel    string `mapstructure:"openai_model"`
}

var (
	cfg     *Config
	keyRing keyring.Keyring
)

// Initialize loads the configuration
func Initialize(configFile string) error {
	// Setup config directory
	configDir := filepath.Join(xdg.ConfigHome, "aicommit")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}

	// Initialize Viper
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	
	if configFile != "" {
		viper.SetConfigFile(configFile)
	} else {
		viper.AddConfigPath(configDir)
		viper.AddConfigPath(".")
		
		// Also check old PowerShell locations for migration
		if runtime.GOOS == "windows" {
			viper.AddConfigPath(os.ExpandEnv("$USERPROFILE\\Documents\\WindowsPowerShell\\Modules\\AICommit"))
		}
	}

	// Set defaults
	viper.SetDefault("model", "claude-haiku-4-5-20251015")
	viper.SetDefault("max_diff_length", 30000)
	viper.SetDefault("provider", "anthropic")
	viper.SetDefault("anthropic_model", "claude-haiku-4-5-20251015")
	viper.SetDefault("gemini_model", "gemini-2.5-flash")
	viper.SetDefault("openai_model", "gpt-5-mini")

	// Environment variable support
	viper.SetEnvPrefix("AI_COMMIT")
	viper.AutomaticEnv()
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	// Read config file
	if err := viper.ReadInConfig(); err != nil {
		// Create default config if it doesn't exist
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			configFile := filepath.Join(configDir, "config.yaml")
			if err := createDefaultConfig(configFile); err != nil {
				return err
			}
			// Re-read the newly created config
			viper.SetConfigFile(configFile)
			if err := viper.ReadInConfig(); err != nil {
				return err
			}
		} else {
			return err
		}
	}

	// Unmarshal config
	cfg = &Config{}
	if err := viper.Unmarshal(cfg); err != nil {
		return fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Initialize keyring for secure credential storage
	if err := initKeyring(); err != nil {
		// Keyring is optional, just log the error
		fmt.Fprintf(os.Stderr, "Warning: Could not initialize keyring (credentials will use environment variables): %v\n", err)
	}

	return nil
}

func initKeyring() error {
	var err error
	keyRing, err = keyring.Open(keyring.Config{
		ServiceName: serviceName,
		// Use file backend on servers or when system keyring is unavailable
		AllowedBackends: []keyring.BackendType{
			keyring.KeychainBackend,     // macOS
			keyring.WinCredBackend,       // Windows
			keyring.SecretServiceBackend, // Linux (GNOME Keyring, KWallet)
			keyring.FileBackend,          // Fallback (encrypted file)
		},
		FileDir:         filepath.Join(xdg.DataHome, "aicommit", "keys"),
		FilePasswordFunc: func(prompt string) (string, error) {
			// In production, this should prompt for a password
			// For now, use a default password (not secure for production)
			return "aicommit-default-key", nil
		},
	})
	return err
}

func createDefaultConfig(path string) error {
	defaultConfig := `# AICommit Configuration
#
# Available providers: anthropic, gemini, openai
provider: anthropic

# Model selection (can also be set via AI_COMMIT_MODEL env var)
model: claude-haiku-4-5-20251015

# Provider-specific models
anthropic_model: claude-haiku-4-5-20251015
gemini_model: gemini-2.5-flash
openai_model: gpt-5-mini

# Maximum diff size in characters (default: 30000)
max_diff_length: 30000

# Note: API keys should be stored securely using 'aicommit config set-key'
# or via environment variables:
# - ANTHROPIC_API_KEY
# - GEMINI_API_KEY
# - OPENAI_API_KEY
`
	return os.WriteFile(path, []byte(defaultConfig), 0644)
}

// GetConfig returns the current configuration
func GetConfig() *Config {
	if cfg == nil {
		panic("config not initialized")
	}
	return cfg
}

// GetAPIKey retrieves the API key for the current provider
func (c *Config) GetAPIKey() string {
	provider := strings.ToLower(c.Provider)
	
	// Environment variable names
	envVars := map[string][]string{
		"anthropic": {"ANTHROPIC_API_KEY", "AI_COMMIT_ANTHROPIC_KEY"},
		"gemini":    {"GEMINI_API_KEY", "AI_COMMIT_GEMINI_KEY"},
		"openai":    {"OPENAI_API_KEY", "AI_COMMIT_OPENAI_KEY"},
	}

	// Check environment variables first
	if vars, ok := envVars[provider]; ok {
		for _, env := range vars {
			if key := os.Getenv(env); key != "" {
				return key
			}
		}
	}

	// Try to get from keyring
	if keyRing != nil {
		keyName := fmt.Sprintf("%s_api_key", provider)
		item, err := keyRing.Get(keyName)
		if err == nil {
			return string(item.Data)
		}
	}

	return ""
}

// SetAPIKey stores an API key securely
func SetAPIKey(provider, key string) error {
	if keyRing == nil {
		return fmt.Errorf("keyring not available, use environment variables instead")
	}

	keyName := fmt.Sprintf("%s_api_key", strings.ToLower(provider))
	return keyRing.Set(keyring.Item{
		Key:  keyName,
		Data: []byte(key),
	})
}

// DeleteAPIKey removes a stored API key
func DeleteAPIKey(provider string) error {
	if keyRing == nil {
		return fmt.Errorf("keyring not available")
	}

	keyName := fmt.Sprintf("%s_api_key", strings.ToLower(provider))
	return keyRing.Remove(keyName)
}
