# AI Commit - PowerShell Git Commit Assistant

Generate intelligent git commit messages using Claude AI. This PowerShell module analyzes your git diff and suggests properly formatted commit messages following best practices.

## Features

- 🤖 **AI-Powered Analysis**: Uses AI to understand your code changes
- 📝 **Professional Format**: Generates commit messages with proper header and description
- 🔄 **Multi-Model Support**: Works with both Claude (Anthropic) and Gemini (Google) AI models
- 🔍 **Comprehensive Diff Analysis**: Analyzes both tracked and untracked files
- ✏️ **Interactive Workflow**: Review, edit, or cancel before committing
- 🌍 **UTF-8 Support**: Handles international characters correctly
- ⚡ **PowerShell 5.1+ Compatible**: Works with Windows PowerShell and PowerShell Core
- 🚀 **Git Push Support**: Optional flag to push after committing
- 📦 **Google Apps Script Integration**: Optional clasp push support for GAS projects
- ☁️ **Cloudflare Workers Deployment**: Optional wrangler deploy support for Workers projects
- 📤 **Diff Export**: Export the comprehensive diff to a file for review

## Prerequisites

- PowerShell 5.1 or higher
- Git installed and accessible from PowerShell
- AI API key: Either Anthropic ([Anthropic Console](https://console.anthropic.com/)) or Google ([Google AI Studio](https://aistudio.google.com/apikey))
- (Optional) Clasp CLI for Google Apps Script projects (`npm install -g @google/clasp`)
- (Optional) Wrangler CLI for Cloudflare Workers projects (`npm install -g wrangler`)

## Installation

### Option 1: Clone to PowerShell Modules (Recommended)

```powershell
# Clone directly to your modules folder
git clone https://github.com/SCHWAI-AI/aicommit-powershell.git "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\AICommit"

# Import the module
Import-Module AICommit
```

### Option 2: Clone and Import Manually

```powershell
# Clone to any location
git clone https://github.com/SCHWAI-AI/aicommit-powershell.git
cd aicommit-powershell

# Import the module
Import-Module .\AICommit.psm1
```

### Option 3: Add to Your PowerShell Profile

For permanent availability, add this to your PowerShell profile:

```powershell
# Open your profile
notepad $PROFILE

# Add these lines:
Import-Module "C:\path\to\aicommit-powershell\AICommit.psm1"

# API Keys (set the ones you need)
$env:ANTHROPIC_API_KEY_AICOMMIT = "your-anthropic-key-here"
$env:GEMINI_API_KEY_AICOMMIT = "your-google-key-here"

# Your preferred model (optional, defaults to gemini-2.5-flash)
$env:AI_COMMIT_MODEL = "gemini-2.5-flash"

# Increase diff size for large commits (Optional, default is 30000 characters)
$env:AI_COMMIT_MAX_DIFF_LENGTH = "50000"
```

## Setup

### Setting Your API Key

The module supports both Claude (Anthropic) and Gemini (Google) models. Set the appropriate API key for your chosen model:

**For Gemini (default):**
```powershell
$env:GEMINI_API_KEY_AICOMMIT = "your-google-api-key-here"
```
For Claude:
```powershell
$env:ANTHROPIC_API_KEY_AICOMMIT = "sk-ant-api04-your-key-here"
```
For permanent setup (add both to your profile if you want to switch between them):
```powershell
Add-Content $PROFILE '$env:GEMINI_API_KEY_AICOMMIT = "your-google-api-key-here"'
Add-Content $PROFILE '$env:ANTHROPIC_API_KEY_AICOMMIT = "sk-ant-api04-your-key-here"'
```
And restart your profile:
```powershell
. $PROFILE
```

### Setting Your Preferred Model (Optional)

Choose your preferred AI model by setting an environment variable:

```powershell
# For Gemini (default):
$env:AI_COMMIT_MODEL = "gemini-2.5-flash"

# For Claude:
powershell$env:AI_COMMIT_MODEL = "claude-3-5-haiku-20241022"

# For permanent setup:
Add-Content $PROFILE '$env:AI_COMMIT_MODEL = "gemini-2.5-flash"'
```

## Usage

Navigate to any git repository with changes and run:

```powershell
# Basic commit
aicommit

# Commit and push to git remote
aicommit -push

# Commit and push to clasp (for Google Apps Script projects)
aicommit -clasp

# Commit and push to both git and clasp
aicommit -push -clasp

# Commit, push to git, and deploy to wrangler
aicommit -push -wrangler

# Export diff to file without committing (for review)
aicommit -export
```

The tool will:
1. Check if you're in a valid git repository
2. If using -clasp, verify .clasp.json exists and confirm you've pulled latest changes. If using -wrangler, verify wrangler.toml exists
3. Analyze your git diff (both staged and unstaged changes)
4. Send the diff to Claude AI for analysis
5. Present a suggested commit message
6. Give you options to:
   - **Accept** (y/yes or Enter): Use the suggested message
   - **Edit** (e/edit): Modify the header and/or description
   - **Cancel** (c/cancel): Abort the commit
7. Stage and commit changes
8. Push to git remote (if -push flag used)
9. Push to clasp (if -clasp flag used)

**Note:** When using `-export`, the tool exports the diff to `git-diff-export.txt` and exits without calling the AI or committing. This is useful for reviewing what would be analyzed.

### Example Workflow

```powershell
PS C:\MyProject> aicommit
Analyzing changes...
JSON validation passed
Request size: 2543 characters
Getting AI suggestion...

--- SUGGESTED COMMIT MESSAGE ---
HEADER: Add user authentication module
DESCRIPTION: Implements JWT-based authentication with login/logout endpoints and middleware for protecting routes
--- END SUGGESTION ---

Use this message? (y)es / (e)dit / (c)ancel: y
Staging changes...
Committing...

Commit successful!
Created: a3f2d45 Add user authentication module
```
#### Example with Flags
```powershell
# Push to git remote after commit
PS C:\MyProject> aicommit -push
[... commit process ...]
Commit successful!
Created: a3f2d45 Add user authentication module
Pushing to remote...
Push successful!

# For Google Apps Script project with clasp
PS C:\MyGASProject> aicommit -clasp
Have you pulled from clasp? (y/n): y
[... commit process ...]
Commit successful!
Created: b4g3e56 Update Google Sheets functions
Pushing to clasp...
Clasp push successful!
```

## How It Works

1. **Diff Collection**: Gathers all changes including:
   - Modified tracked files (`git diff HEAD`)
   - New untracked files (`git ls-files --others`)

2. **AI Analysis**: Sends the diff to Claude with specific instructions for:
   - Imperative mood (Add, Fix, Update)
   - 50-character header limit
   - Detailed description of what and why

3. **Interactive Review**: Presents the suggestion and allows editing before commit

4. **Auto-staging**: Automatically stages all changes (`git add .`) before committing

## Configuration

The module uses these environment variables:

- **`AI_COMMIT_MODEL`**: Your preferred AI model
- **`AI_COMMIT_MAX_DIFF_LENGTH`**: Maximum diff size in characters (default: `30000`)
- **`GEMINI_API_KEY_AICOMMIT`**: Required for Gemini models
- **`ANTHROPIC_API_KEY_AICOMMIT`**: Required for Claude models


## Troubleshooting

### "Not in a git repository"
- Ensure you're in a directory initialized with `git init`

### "API_KEY environment variable not set"
- For Gemini: Check with `echo $env:GEMINI_API_KEY_AICOMMIT`
- For Claude: Check with `echo $env:ANTHROPIC_API_KEY_AICOMMIT`
- Ensure you've restarted PowerShell after setting permanent environment variables

### API Errors
- Verify your API key is valid
- Check you have credits in your Anthropic account
- Review the `debug_failed_request.json` file created on errors

### Encoding Issues
- The module sets UTF-8 encoding automatically
- If you see character issues, ensure your terminal supports UTF-8

### Module not updating after changes
If you've modified the module files and changes aren't reflected:
- Reload the module: `Import-Module AICommit -Force`

## Security

- **Never commit your API key** to version control
- The `.gitignore` includes patterns to prevent accidental key exposure
- API keys should only be set as environment variables

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Aaron Zlotowitz**  
[SCHW-AI](https://github.com/SCHW-AI)

## Acknowledgments

- Built with [Anthropic's Claude AI](https://www.anthropic.com/)
- Inspired by the need for better commit messages

## Support

If you encounter any issues or have questions, please [open an issue](https://github.com/SCHWAI-AI/aicommit-powershell/issues) on GitHub.