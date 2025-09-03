function aicommit {
    param(
        [switch]$push,
        [switch]$clasp
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

    # Check for API key early
    if ([string]::IsNullOrWhiteSpace($env:ANTHROPIC_API_KEY)) {
        Write-Host "Error: ANTHROPIC_API_KEY environment variable not set" -ForegroundColor Red
        Write-Host "Set it with: `$env:ANTHROPIC_API_KEY = 'your-api-key-here'" -ForegroundColor Yellow
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
                $fullDiff += "New file: $_`n"
            }
        }
    }
    
    # Check if there are any changes at all
    if ([string]::IsNullOrWhiteSpace($fullDiff)) {
        Write-Host "No changes to commit" -ForegroundColor Green
        return
    }

    # Truncate if necessary (increased limit for better context)
    $maxLength = 30000
    if ($fullDiff.Length -gt $maxLength) {
        $fullDiff = $fullDiff.Substring(0, $maxLength) + "`n... (diff truncated)"
        Write-Host "Note: Diff was truncated due to length" -ForegroundColor Yellow
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

    # Build request object using explicit content blocks
    $messages = @(
        @{
            role = "user"
            content = @(
                @{ type = "text"; text = $promptContent }
            )
        }
    )

    $requestObj = @{
        model = "claude-sonnet-4-20250514"
        max_tokens = 1000
        messages = $messages
    }

    # Convert to JSON using PowerShell's native converter
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

    # Prepare headers
    $headers = @{
        "Content-Type"      = "application/json; charset=utf-8"
        "x-api-key"         = $env:ANTHROPIC_API_KEY
        "anthropic-version" = "2023-06-01"
    }

    # Debug info (comment out in production)
    Write-Host "Request size: $($jsonRequest.Length) characters" -ForegroundColor Cyan

    # Call Claude API (PS5.1/PS7+ compatible)
    try {
        Write-Host "Getting AI suggestion..." -ForegroundColor Yellow

        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonRequest)

        $irmParams = @{
            Uri     = "https://api.anthropic.com/v1/messages"
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

        $suggestion = $response.content[0].text
        
        Write-Host "`n--- SUGGESTED COMMIT MESSAGE ---" -ForegroundColor Cyan
        Write-Host $suggestion -ForegroundColor White
        Write-Host "--- END SUGGESTION ---`n" -ForegroundColor Cyan
        
    }
    catch {
        Write-Host "Error calling Claude API:" -ForegroundColor Red
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
    $finalMessage = ""
    
    switch ($choice) {
        {$_ -in @('c', 'cancel')} {
            Write-Host "Commit cancelled" -ForegroundColor Yellow
            return
        }
        
        {$_ -in @('e', 'edit')} {
            Write-Host "`nEdit your commit message:" -ForegroundColor Yellow
            
            $newHeader = Read-Host "Header [$header]"
            if ([string]::IsNullOrWhiteSpace($newHeader)) { 
                $newHeader = $header 
            }
            
            $newDescription = Read-Host "Description [$description]"
            if ([string]::IsNullOrWhiteSpace($newDescription)) { 
                $newDescription = $description 
            }
            
            $finalMessage = if ([string]::IsNullOrWhiteSpace($newDescription)) { 
                $newHeader 
            } else { 
                "$newHeader`n`n$newDescription" 
            }
        }
        
        {$_ -in @('y', 'yes')} {
            $finalMessage = if ([string]::IsNullOrWhiteSpace($description)) { 
                $header 
            } else { 
                "$header`n`n$description" 
            }
        }
    }

    # Stage all changes and commit
    try {
        Write-Host "Staging changes..." -ForegroundColor Yellow
        git add . 2>&1 | Out-Null
        
        Write-Host "Committing..." -ForegroundColor Yellow
        git commit -m "$finalMessage"
        
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