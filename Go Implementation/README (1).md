# AICommit - AI-Powered Git Commit Message Generator

![Go Version](https://img.shields.io/badge/Go-1.21%2B-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)

Generate intelligent git commit messages using AI. This Go-based CLI tool analyzes your git diff and suggests properly formatted commit messages using Claude (Anthropic), Gemini (Google), or GPT (OpenAI) models.

## Features

- 🤖 **Multi-Provider AI Support**: Works with Claude, Gemini, and OpenAI models
- 🔒 **Secure Credential Storage**: Uses system keyring for API keys
- 📝 **Professional Format**: Generates commit messages with proper header and description
- 🔍 **Comprehensive Diff Analysis**: Analyzes both tracked and untracked files
- ✏️ **Interactive Workflow**: Review, edit, or cancel before committing
- 🌍 **Cross-Platform**: Works on Windows, macOS, and Linux
- ⚡ **Fast & Native**: Written in Go for optimal performance
- 🚀 **Git Push Support**: Optional flag to push after committing
- 📦 **Google Apps Script Integration**: Optional clasp push support
- ☁️ **Cloudflare Workers Integration**: Optional wrangler deploy support
- 📤 **Export Mode**: Export diff to file for review without committing

## Installation

### Package Managers

#### Homebrew (macOS/Linux)
```bash
brew tap SCHWAI-AI/tap
brew install aicommit
```

#### Scoop (Windows)
```powershell
scoop bucket add schwai https://github.com/SCHWAI-AI/scoop-bucket
scoop install aicommit
```

#### Chocolatey (Windows)
```powershell
choco install aicommit
```

#### WinGet (Windows)
```powershell
winget install SCHWAI.AICommit
```

#### APT (Debian/Ubuntu)
```bash
# Add the repository
echo "deb [trusted=yes] https://apt.schwai.ai/ /" | sudo tee /etc/apt/sources.list.d/schwai.list
sudo apt update
sudo apt install aicommit
```

#### YUM/DNF (RHEL/Fedora)
```bash
sudo dnf config-manager --add-repo https://rpm.schwai.ai/aicommit.repo
sudo dnf install aicommit
```

#### Pacman (Arch Linux)
```bash
yay -S aicommit
# or
pamac install aicommit
```

#### Docker
```bash
docker run --rm -v $(pwd):/repo ghcr.io/schwai-ai/aicommit
```

### Manual Installation

Download the latest binary for your platform from the [releases page](https://github.com/SCHWAI-AI/aicommit/releases).

```bash
# Linux/macOS
curl -L https://github.com/SCHWAI-AI/aicommit/releases/latest/download/aicommit_Linux_x86_64.tar.gz | tar xz
sudo mv aicommit /usr/local/bin/

# Windows (PowerShell)
iwr -Uri https://github.com/SCHWAI-AI/aicommit/releases/latest/download/aicommit_Windows_x86_64.zip -OutFile aicommit.zip
Expand-Archive aicommit.zip -DestinationPath .
Move-Item aicommit.exe C:\Windows\System32\
```

### Build from Source
```bash
git clone https://github.com/SCHWAI-AI/aicommit.git
cd aicommit
go build -o aicommit
sudo mv aicommit /usr/local/bin/
```

## Configuration

### Initial Setup

1. **Create configuration file** (optional - defaults work out of the box):
```bash
aicommit config init
```

2. **Set your API key** (choose one):

#### Secure Keyring Storage (Recommended)
```bash
# For Gemini (default)
aicommit config set-key gemini YOUR_API_KEY

# For Claude
aicommit config set-key anthropic YOUR_API_KEY

# For OpenAI
aicommit config set-key openai YOUR_API_KEY
```

#### Environment Variables
```bash
# Gemini
export GEMINI_API_KEY="your-google-api-key"

# Claude
export ANTHROPIC_API_KEY="sk-ant-api04-your-key"

# OpenAI
export OPENAI_API_KEY="sk-proj-your-key"
```

#### Configuration File
Edit `~/.config/aicommit/config.yaml`:
```yaml
# Provider selection
provider: anthropic  # Options: anthropic, gemini, openai

# Model selection
model: claude-haiku-4-5-20251015  # Or gemini-2.5-flash, gpt-5-mini

# Provider-specific models
anthropic_model: claude-haiku-4-5-20251015
gemini_model: gemini-2.5-flash
openai_model: gpt-5-mini

# Maximum diff size in characters
max_diff_length: 30000
```

### Getting API Keys

- **Gemini**: [Google AI Studio](https://aistudio.google.com/apikey)
- **Claude**: [Anthropic Console](https://console.anthropic.com/)
- **OpenAI**: [OpenAI Platform](https://platform.openai.com/api-keys)

## Usage

### Basic Usage
```bash
# Navigate to any git repository
cd my-project

# Generate commit message
aicommit
```

### With Options
```bash
# Commit and push to git remote
aicommit --push

# Commit and push to clasp (Google Apps Script)
aicommit --clasp

# Commit and deploy to Cloudflare Workers
aicommit --wrangler

# Commit and push to both git and wrangler
aicommit --push --wrangler

# Export diff to file without committing (for review)
aicommit --export

# Use specific configuration file
aicommit --config ~/custom-config.yaml
```

### Workflow

1. **Check Repository**: Verifies you're in a valid git repository
2. **Analyze Changes**: Examines all modified and new files
3. **Generate Message**: AI analyzes the diff and suggests a commit message
4. **Review Options**:
   - **Accept** (y/yes/Enter): Use the suggested message
   - **Edit** (e/edit): Modify the message in your editor
   - **Cancel** (c/cancel): Abort the commit
5. **Commit**: Stages all changes and creates the commit
6. **Push** (optional): Pushes to remote if flags are set

### Example Session

```bash
$ aicommit
Analyzing changes...
Getting AI suggestion...

--- SUGGESTED COMMIT MESSAGE ---
HEADER: Add user authentication module
DESCRIPTION: Implements JWT-based authentication with login/logout endpoints and middleware for protecting routes
--- END MESSAGE ---

Use this message? (yes/edit/cancel): y
Staging changes...
Committing...

Commit successful!
Created: a3f2d45 Add user authentication module
```

## Advanced Features

### Provider Switching
```bash
# Use Gemini for one commit
AI_COMMIT_PROVIDER=gemini aicommit

# Use GPT-5 for one commit
AI_COMMIT_PROVIDER=openai AI_COMMIT_MODEL=gpt-5-mini aicommit
```

### Custom Diff Length
```bash
# For very large commits
AI_COMMIT_MAX_DIFF_LENGTH=50000 aicommit
```

### Shell Completions
```bash
# Bash
aicommit completion bash > /etc/bash_completion.d/aicommit

# Zsh
aicommit completion zsh > "${fpath[1]}/_aicommit"

# Fish
aicommit completion fish > ~/.config/fish/completions/aicommit.fish

# PowerShell
aicommit completion powershell > $PROFILE.CurrentUserAllHosts
```

## Comparison to PowerShell Version

This Go implementation offers several advantages over the original PowerShell version:

| Feature | PowerShell Version | Go Version |
|---------|-------------------|------------|
| **Performance** | Slower startup | 10x faster |
| **Cross-Platform** | Windows only | Windows, macOS, Linux, BSD |
| **Installation** | Manual setup | Package managers |
| **Dependencies** | Requires PowerShell | Single binary |
| **Credential Storage** | Environment vars | Secure keyring |
| **Providers** | Claude, Gemini | Claude, Gemini, OpenAI |
| **Binary Size** | N/A (script) | ~8MB |
| **Shell Support** | PowerShell only | Any shell |

## Development

### Prerequisites
- Go 1.21+
- Git
- Make (optional)

### Building
```bash
# Clone repository
git clone https://github.com/SCHWAI-AI/aicommit.git
cd aicommit

# Build
go build

# Install locally
go install

# Run tests
go test ./...

# Build for all platforms
goreleaser build --snapshot --clean
```

### Project Structure
```
aicommit/
├── cmd/                    # Command definitions
│   └── root.go            # Main command logic
├── internal/              # Internal packages
│   ├── config/           # Configuration management
│   ├── git/              # Git operations
│   ├── llm/              # AI provider clients
│   │   ├── anthropic.go # Claude client
│   │   ├── gemini.go    # Gemini client
│   │   └── openai.go    # OpenAI client
│   └── prompt/           # Interactive UI
├── .goreleaser.yaml      # Build configuration
├── go.mod                # Dependencies
└── main.go              # Entry point
```

## Troubleshooting

### Not in a git repository
- Ensure you're in a directory initialized with `git init`
- Check with `git status`

### API Key Issues
```bash
# Check if key is set
aicommit config show

# Re-set the key
aicommit config set-key gemini YOUR_KEY

# Test with environment variable
GEMINI_API_KEY=your-key aicommit
```

### Rate Limits
- Gemini: 60 requests per minute (free tier)
- Claude: Varies by plan
- OpenAI: Varies by plan

### Large Diffs
If your diff is too large:
1. Increase the limit: `AI_COMMIT_MAX_DIFF_LENGTH=50000`
2. Commit in smaller chunks
3. Use `.gitignore` to exclude unnecessary files

## Security

- **API Keys**: Stored in system keyring (Keychain on macOS, Windows Credential Manager, GNOME Keyring on Linux)
- **No Network Access**: Besides API calls, no data is sent anywhere
- **Local Processing**: All diff analysis happens locally
- **Open Source**: Fully auditable code

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (using aicommit! 😄)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Aaron Zlotowitz**  
[SCHWAI](https://github.com/SCHWAI-AI)

## Acknowledgments

- Original PowerShell implementation inspiration
- Built with [Cobra](https://github.com/spf13/cobra) for CLI
- [Viper](https://github.com/spf13/viper) for configuration
- [Keyring](https://github.com/99designs/keyring) for secure storage
- [Anthropic](https://www.anthropic.com/), [Google](https://ai.google.dev/), and [OpenAI](https://openai.com/) for AI APIs

## Support

If you encounter issues or have questions:
- [Open an issue](https://github.com/SCHWAI-AI/aicommit/issues)
- Check [existing issues](https://github.com/SCHWAI-AI/aicommit/issues?q=is%3Aissue)
- Read the [FAQ](https://github.com/SCHWAI-AI/aicommit/wiki/FAQ)
