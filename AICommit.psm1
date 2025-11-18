function aicommit {
    param(
        [switch]$push,
        [switch]$clasp,
        [switch]$wrangler,
        [switch]$export
    )
    # Check if we're in a git repository
    try {
        git rev-parse --git-dir | Out-Null
    }
    catch {
        Write-Host "Error: Not in a git repository" -ForegroundColor Red
        return
    }
    # Check for clasp if flag is set
    if ($clasp) {
        # Check if .clasp.json exists
        if (!(Test-Path ".clasp.json")) {
            Write-Host "Error: Not in a clasp repository (.clasp.json not found)" -ForegroundColor Red
            return
        }
        
        # Ask if clasp has been pulled
        $claspPulled = Read-Host "Have you pulled from clasp? (y/n)"
        if ($claspPulled.ToLower() -notin @('y', 'yes')) {
            Write-Host "Please run 'clasp pull' first, then try again" -ForegroundColor Yellow
            return
        }
    }

    # Check for wrangler if flag is set
    if ($wrangler) {
        # Check if wrangler.toml exists
        if (!(Test-Path "wrangler.toml")) {
            Write-Host "Error: Not in a wrangler project (wrangler.toml not found)" -ForegroundColor Red
            return
        }
    }

    # Model configuration - Check for user preference, if none use default
    $AI_MODEL = if ($env:AI_COMMIT_MODEL) { 
        $env:AI_COMMIT_MODEL 
    } else { 
        "gemini-2.5-flash"  # Default model
    }

    # Detect carrier and check for appropriate API key
    if ($AI_MODEL -like "claude-*") {
        $carrier = "anthropic"
        $apiKey = $env:ANTHROPIC_API_KEY
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Host "Error: ANTHROPIC_API_KEY environment variable not set" -ForegroundColor Red
            Write-Host "Set it with: `$env:ANTHROPIC_API_KEY = 'your-api-key-here'" -ForegroundColor Yellow
            return
        }
    } elseif ($AI_MODEL -like "gemini-*" -or $AI_MODEL -like "models/gemini-*") {
        $carrier = "google"
        # Check for Gemini API key
        $apiKey = $env:GEMINI_API_KEY
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Host "Error: GEMINI_API_KEY environment variable not set" -ForegroundColor Red
            Write-Host "Set it with: `$env:GEMINI_API_KEY = 'your-api-key-here'" -ForegroundColor Yellow
            return
        }
    } else {
        Write-Host "Error: Unknown model carrier for model: $AI_MODEL" -ForegroundColor Red
        return
    }

    # Ensure console and HTTP body use UTF-8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    Write-Host "Analyzing changes..." -ForegroundColor Yellow
    
    # Get tracked file changes
    $trackedChanges = git diff HEAD
    
    # Get untracked files
    $untrackedFiles = git ls-files --others --exclude-standard
    
    # Combine both into a comprehensive diff
    $fullDiff = ""
    if (![string]::IsNullOrWhiteSpace($trackedChanges)) {
        $fullDiff += "=== MODIFIED FILES ===`n$trackedChanges`n`n"
    }
    
    if (![string]::IsNullOrWhiteSpace($untrackedFiles)) {
        $fullDiff += "=== NEW FILES ===`n"
        $untrackedFiles -split "`n" | ForEach-Object {
            if (![string]::IsNullOrWhiteSpace($_)) {
                $fullDiff += "`n--- New file: $_ ---`n"
                # Try to read the file content
                if (Test-Path $_) {
                    try {
                        $fileContent = Get-Content $_ -Raw -ErrorAction Stop
                        # Add line numbers for consistency with git diff format
                        $lineNumber = 1
                        $fileContent -split "`n" | ForEach-Object {
                            $fullDiff += "+$_`n"
                            $lineNumber++
                        }
                    }
                    catch {
                        $fullDiff += "[Could not read file content: $($_.Exception.Message)]`n"
                    }
                }
                $fullDiff += "`n"
            }
        }
    }
    
    # Check if there are any changes at all
    if ([string]::IsNullOrWhiteSpace($fullDiff)) {
        Write-Host "No changes to commit" -ForegroundColor Green
        return
    }

    # Truncate if necessary (configurable via environment variable)
    $maxLength = if ($env:AI_COMMIT_MAX_DIFF_LENGTH) { 
        [int]$env:AI_COMMIT_MAX_DIFF_LENGTH 
    } else { 
        30000  # Default: 30,000 characters
    }
    if ($fullDiff.Length -gt $maxLength) {
        $fullDiff = $fullDiff.Substring(0, $maxLength) + "`n... (diff truncated)"
        Write-Host "Note: Diff was truncated due to length" -ForegroundColor Yellow
    }

    # Export diff to file if requested
    if ($export) {
        $exportFile = "git-diff-export.txt"
        $fullDiff | Out-File -FilePath $exportFile -Encoding UTF8
        Write-Host "Diff exported to: $exportFile" -ForegroundColor Green
        return
    }

    # Build the complete prompt
    $promptContent = @"
Analyze this git diff and suggest a commit message. 

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

$fullDiff
"@

    # Build request based on carrier
    if ($carrier -eq "anthropic") {
        # Claude/Anthropic request format
        $messages = @(
            @{
                role = "user"
                content = @(
                    @{ type = "text"; text = $promptContent }
                )
            }
        )

        $requestObj = @{
            model = $AI_MODEL
            max_tokens = 1000
            messages = $messages
        }
        
        $apiUrl = "https://api.anthropic.com/v1/messages"
        $headers = @{
            "Content-Type"      = "application/json; charset=utf-8"
            "x-api-key"         = $apiKey
            "anthropic-version" = "2023-06-01"
        }
    } else {
        # Gemini/Google request format
        $requestObj = @{
            contents = @(
                @{
                    parts = @(
                        @{ text = $promptContent }
                    )
                }
            )
        }
        
        # Handle model name format (add "models/" prefix if not present)
        $modelName = if ($AI_MODEL -like "models/*") { $AI_MODEL } else { "models/$AI_MODEL" }
        $apiUrl = "https://generativelanguage.googleapis.com/v1beta/$($modelName):generateContent"
        $headers = @{
            "Content-Type"     = "application/json; charset=utf-8"
            "x-goog-api-key"   = $apiKey
        }
    }

    # Convert to JSON
    $jsonRequest = $requestObj | ConvertTo-Json -Depth 12 -Compress

    # Validate JSON structure
    try {
        $null = $jsonRequest | ConvertFrom-Json
        Write-Host "JSON validation passed" -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: JSON validation failed - $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Attempting to continue anyway..." -ForegroundColor Yellow
    }

    # Debug info
    Write-Host "Using model: $AI_MODEL ($carrier)" -ForegroundColor Cyan
    Write-Host "Request size: $($jsonRequest.Length) characters" -ForegroundColor Cyan

    # Call the AI
    try {
        Write-Host "Getting AI suggestion..." -ForegroundColor Yellow

        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonRequest)

        $irmParams = @{
            Uri     = $apiUrl
            Method  = "Post"
            Headers = $headers
            Body    = $bodyBytes
        }

        $irmCmd   = Get-Command Invoke-RestMethod
        $hasSkip  = $irmCmd.Parameters.ContainsKey('SkipHttpErrorCheck')
        $hasSCV   = $irmCmd.Parameters.ContainsKey('StatusCodeVariable')

        if ($hasSkip) { $irmParams['SkipHttpErrorCheck'] = $true }
        if ($hasSCV)  { $irmParams['StatusCodeVariable'] = 'scv' }

        $scv = 0
        $response = Invoke-RestMethod @irmParams

        if ($hasSkip -and $hasSCV -and $scv -ge 400) {
            Write-Host "HTTP $scv" -ForegroundColor Red
            try {
                ($response | ConvertTo-Json -Depth 12) | Write-Host -ForegroundColor Red
            } catch {
                Write-Host "$response" -ForegroundColor Red
            }
            $debugFile = "debug_failed_request.json"
            $jsonRequest | Out-File -FilePath $debugFile -Encoding UTF8
            Write-Host "Request saved to $debugFile for debugging" -ForegroundColor Yellow
            return
        }

        # Extract suggestion based on carrier
        if ($carrier -eq "anthropic") {
            $suggestion = $response.content[0].text
        } else {
            # Gemini response structure
            $suggestion = $response.candidates[0].content.parts[0].text
        }
    }
    catch {
        Write-Host "Error calling $carrier API:" -ForegroundColor Red
        if ($_.Exception.Response) {
            try {
                $statusCode = $_.Exception.Response.StatusCode.value__
                Write-Host "Status: $statusCode" -ForegroundColor Red
            } catch { }
        } else {
            Write-Host "Status: (unknown)" -ForegroundColor Red
        }
        Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
        
        # Try to get detailed error response
        if ($_.Exception.Response) {
            try {
                $responseStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($responseStream, [System.Text.Encoding]::UTF8)
                $errorBody = $reader.ReadToEnd()
                Write-Host "Response body: $errorBody" -ForegroundColor Red
                $reader.Close()
                $responseStream.Close()
            }
            catch {
                Write-Host "Could not read error response body" -ForegroundColor Red
            }
        }
        
        # Save request for debugging
        $debugFile = "debug_failed_request.json"
        $jsonRequest | Out-File -FilePath $debugFile -Encoding UTF8
        Write-Host "Request saved to $debugFile for debugging" -ForegroundColor Yellow
        
        return
    }

    # Parse the suggestion
    $lines = $suggestion -split "`n"
    $header = ($lines | Where-Object { $_ -match "^HEADER:" }) -replace "^HEADER:\s*", ""
    $description = ($lines | Where-Object { $_ -match "^DESCRIPTION:" }) -replace "^DESCRIPTION:\s*", ""

    # Interactive commit message loop
    $committed = $false
    $currentHeader = $header
    $currentDescription = $description
    $firstRun = $true
    
    while (-not $committed) {
        # Display current message
        if ($firstRun) {
            Write-Host "`n--- SUGGESTED COMMIT MESSAGE ---" -ForegroundColor Cyan
        } else {
            Write-Host "`n--- CURRENT COMMIT MESSAGE ---" -ForegroundColor Cyan
        }
        Write-Host "HEADER: $currentHeader" -ForegroundColor White
        if (![string]::IsNullOrWhiteSpace($currentDescription)) {
            Write-Host "DESCRIPTION: $currentDescription" -ForegroundColor White
        }
        Write-Host "--- END MESSAGE ---`n" -ForegroundColor Cyan
        
        $firstRun = $false
        
        # Get user decision
        do {
            $choice = Read-Host "Use this message? (y)es / (e)dit / (c)ancel"
            $choice = $choice.ToLower()
        } while ($choice -notin @('y', 'yes', 'e', 'edit', 'c', 'cancel', ''))
        
        # Default to yes if just Enter pressed
        if ([string]::IsNullOrWhiteSpace($choice)) { 
            $choice = 'y' 
        }
        
        # Process user choice
        switch ($choice) {
            {$_ -in @('c', 'cancel')} {
                Write-Host "Commit cancelled" -ForegroundColor Yellow
                return
            }
            
            {$_ -in @('e', 'edit')} {
                Write-Host "`nOpening editor..." -ForegroundColor Yellow
                Write-Host "Edit the message, then SAVE (Ctrl+S) and CLOSE notepad to continue" -ForegroundColor Cyan
                
                # Create temp file with current message
                $tempFile = [System.IO.Path]::GetTempFileName()
                $tempFile = [System.IO.Path]::ChangeExtension($tempFile, ".txt")
                
                # Write current message to temp file
                $editContent = "HEADER: $currentHeader`n`nDESCRIPTION: $currentDescription"
                Set-Content -Path $tempFile -Value $editContent -Encoding UTF8
                
                # Open in notepad and wait
                Start-Process notepad.exe -ArgumentList $tempFile -Wait
                
                # Read back the edited content
                $editedContent = Get-Content -Path $tempFile -Raw -Encoding UTF8
                
                # Parse the edited content
                $editedLines = $editedContent -split "`n"
                $newHeader = ($editedLines | Where-Object { $_ -match "^HEADER:" }) -replace "^HEADER:\s*", ""
                $newDescription = ($editedLines | Where-Object { $_ -match "^DESCRIPTION:" }) -replace "^DESCRIPTION:\s*", ""
                
                # Clean up temp file
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                
                # Update current values for next loop iteration
                $currentHeader = if ($newHeader) { $newHeader } else { $currentHeader }
                $currentDescription = if ($newDescription) { $newDescription } else { $currentDescription }
                # Loop continues to show the edited message
            }
            
            {$_ -in @('y', 'yes')} {
                $finalMessage = if ([string]::IsNullOrWhiteSpace($currentDescription)) { 
                    $currentHeader 
                } else { 
                    "$currentHeader`n`n$currentDescription" 
                }
                $committed = $true
            }
        }
    }

    # Stage all changes and commit
    try {
        Write-Host "Staging changes..." -ForegroundColor Yellow
        git add . 2>&1 | Out-Null
        
        Write-Host "Committing..." -ForegroundColor Yellow
        # Write message to temp file to avoid command-line parsing issues
        $tempMsgFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempMsgFile -Value $finalMessage -Encoding UTF8 -NoNewline
        git commit -F $tempMsgFile
        Remove-Item $tempMsgFile -Force -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nCommit successful!" -ForegroundColor Green
            
            # Show what was committed
            $lastCommit = git log -1 --oneline
            Write-Host "Created: $lastCommit" -ForegroundColor Cyan

            # Push if requested
            if ($push) {
                Write-Host "Pushing to remote..." -ForegroundColor Yellow
                git push
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Push successful!" -ForegroundColor Green
                }
                else {
                    Write-Host "Push failed with exit code: $LASTEXITCODE" -ForegroundColor Red
                }
            }
            # Push to clasp if flag was set
            if ($clasp) {
                Write-Host "Pushing to clasp..." -ForegroundColor Yellow
                clasp push
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Clasp push successful!" -ForegroundColor Green
                }
                else {
                    Write-Host "Clasp push failed with exit code: $LASTEXITCODE" -ForegroundColor Red
                }
            }
            # Deploy to wrangler if flag was set
            if ($wrangler) {
                Write-Host "Deploying to wrangler..." -ForegroundColor Yellow
                wrangler deploy
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Wrangler deployment successful!" -ForegroundColor Green
                }
                else {
                    Write-Host "Wrangler deployment failed with exit code: $LASTEXITCODE" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "Git commit failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error during commit: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Export-ModuleMember -Function aicommit