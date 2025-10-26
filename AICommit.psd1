@{
    RootModule = 'AICommit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a4f7d3e2-8b5c-4d6f-9e3a-2c1b8f9d7e4a'
    Author = 'Aaron Zlotowitz'
    CompanyName = 'SCHWAI'
    Copyright = '(c) 2025 Aaron Zlotowitz. All rights reserved.'
    Description = 'AI-powered Git commit message generator using Claude API. Analyzes your git diff and suggests well-formatted commit messages. Supports git push, clasp push, and wrangler deploy.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('aicommit')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('git', 'ai', 'claude', 'anthropic', 'commit', 'productivity', 'devtools', 'wrangler', 'cloudflare')
            LicenseUri = 'https://github.com/SCHWAI-AI/aicommit-powershell/blob/main/LICENSE'
            ProjectUri = 'https://github.com/SCHWAI-AI/aicommit-powershell'
            ReleaseNotes = 'Initial release - AI-powered commit message generation'
        }
    }
}