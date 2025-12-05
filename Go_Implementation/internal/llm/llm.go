package llm

import (
	"fmt"
	"strings"
)

// CommitMessage represents a structured commit message
type CommitMessage struct {
	Header      string
	Description string
}

// Format returns the formatted commit message
func (c *CommitMessage) Format() string {
	if c.Description == "" {
		return c.Header
	}
	return fmt.Sprintf("%s\n\n%s", c.Header, c.Description)
}

// Client interface for LLM providers
type Client interface {
	GenerateCommitMessage(diff string) (*CommitMessage, error)
}

// NewClient creates a new LLM client based on the model name
func NewClient(model, apiKey string) (Client, error) {
	if apiKey == "" {
		return nil, fmt.Errorf("API key not found for model %s", model)
	}

	modelLower := strings.ToLower(model)
	
	// Detect provider from model name
	switch {
	case strings.Contains(modelLower, "claude"):
		return NewAnthropicClient(apiKey, model)
	case strings.Contains(modelLower, "gemini"):
		return NewGeminiClient(apiKey, model)
	case strings.Contains(modelLower, "gpt"):
		return NewOpenAIClient(apiKey, model)
	default:
		// Default to Gemini for backward compatibility
		return NewGeminiClient(apiKey, model)
	}
}

// Common prompt for all providers
const commitPrompt = `Analyze this git diff and suggest a commit message. 

CRITICAL: You must respond in EXACTLY this format. Do not add any other text, explanations, or formatting:

HEADER: [your header text here]
DESCRIPTION: [your description text here]

STRICT REQUIREMENTS:
- Start with exactly "HEADER: " (including the space after colon)
- Header must be 50 characters or less
- Use imperative mood (Add, Fix, Update - NOT Added, Fixed, Updated)
- Then a blank line
- Then start with exactly "DESCRIPTION: " (including the space after colon)
- Description should explain what changed and why
- Do not use markdown, bullets, or special formatting
- Do not add introductory text like "Here's a suggested commit message"
- Do not add closing text or explanations
- Your response should contain ONLY these two lines

EXAMPLE FORMAT:
HEADER: Add user authentication system
DESCRIPTION: Implements login/logout functionality with JWT tokens and password hashing for secure user management

Now analyze this diff:

%s`

// ParseResponse parses the LLM response into a CommitMessage
func ParseResponse(response string) (*CommitMessage, error) {
	lines := strings.Split(response, "\n")
	
	var header, description string
	
	for _, line := range lines {
		line = strings.TrimSpace(line)
		
		if strings.HasPrefix(line, "HEADER:") {
			header = strings.TrimSpace(strings.TrimPrefix(line, "HEADER:"))
		} else if strings.HasPrefix(line, "DESCRIPTION:") {
			description = strings.TrimSpace(strings.TrimPrefix(line, "DESCRIPTION:"))
		}
	}
	
	if header == "" {
		return nil, fmt.Errorf("no header found in response")
	}
	
	// Ensure header is not too long
	if len(header) > 72 {
		header = header[:72]
	}
	
	return &CommitMessage{
		Header:      header,
		Description: description,
	}, nil
}

// TruncateDiff truncates the diff if it's too long
func TruncateDiff(diff string, maxLength int) string {
	if len(diff) <= maxLength {
		return diff
	}
	return diff[:maxLength] + "\n... (diff truncated)"
}
