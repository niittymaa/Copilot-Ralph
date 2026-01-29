<#
.SYNOPSIS
    Ralph Update Module - Check and apply updates from upstream repository

.DESCRIPTION
    Provides functions to check for updates from the upstream Ralph repository
    and apply them by syncing only the ralph/ folder.
    
    Updates are applied selectively:
    - ralph/ folder files are updated/added from upstream
    - User files outside ralph/ are preserved
    - Files in ralph/ that don't exist in upstream are preserved
#>

# ═══════════════════════════════════════════════════════════════
#                     CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:DefaultUpstreamUrl = "https://github.com/niittymaa/Copilot-Ralph.git"
$script:DefaultUpstreamBranch = "main"

# ═══════════════════════════════════════════════════════════════
#                     UPSTREAM DETECTION
# ═══════════════════════════════════════════════════════════════

function Get-RalphUpstreamUrl {
    <#
    .SYNOPSIS
        Gets the upstream URL for Ralph updates
    .DESCRIPTION
        Checks multiple sources in order:
        1. .ralph/upstream.json (for GitHub forks)
        2. .ralph/source.json (for local copies)
        3. Git remote named 'upstream'
        4. Falls back to default upstream URL
        
        Returns $null if this IS the main repo (to prevent self-update checks)
    .OUTPUTS
        String - The upstream repository URL, or $null if no updates needed
    #>
    param(
        [string]$ProjectRoot = $script:ProjectRoot
    )
    
    # Check if this IS the main Ralph repository
    # If origin points to niittymaa/Copilot-Ralph, this is the source repo
    try {
        $origin = git -C $ProjectRoot config --get remote.origin.url 2>$null
        if ($origin) {
            # Normalize URL for comparison (handle .git suffix and https/git protocols)
            $normalizedOrigin = $origin -replace '\.git$', '' -replace '^git@github\.com:', 'https://github.com/' -replace '^git://', 'https://'
            $normalizedDefault = $script:DefaultUpstreamUrl -replace '\.git$', ''
            
            if ($normalizedOrigin -eq $normalizedDefault) {
                # This IS the main repo - no upstream to check
                return $null
            }
        }
    } catch {
        # Ignore git errors
    }
    
    # Try .ralph/upstream.json (for GitHub forks)
    $upstreamConfig = Join-Path $ProjectRoot '.ralph\upstream.json'
    if (Test-Path $upstreamConfig) {
        try {
            $config = Get-Content $upstreamConfig -Raw | ConvertFrom-Json
            if ($config.upstream) {
                return $config.upstream
            }
        } catch {
            # Ignore parse errors
        }
    }
    
    # Try .ralph/source.json (local copies - use the source URL)
    $sourceConfig = Join-Path $ProjectRoot '.ralph\source.json'
    if (Test-Path $sourceConfig) {
        try {
            $config = Get-Content $sourceConfig -Raw | ConvertFrom-Json
            if ($config.url) {
                return $config.url
            }
        } catch {
            # Ignore parse errors
        }
    }
    
    # Try git remote 'upstream'
    try {
        $upstream = git -C $ProjectRoot config --get remote.upstream.url 2>$null
        if ($upstream) {
            return $upstream
        }
    } catch {
        # Ignore git errors
    }
    
    # Return default
    return $script:DefaultUpstreamUrl
}

function Get-RalphUpstreamBranch {
    <#
    .SYNOPSIS
        Gets the upstream branch for Ralph updates
    .OUTPUTS
        String - The upstream branch name (default: main)
    #>
    param(
        [string]$ProjectRoot = $script:ProjectRoot
    )
    
    # Check config for branch preference
    $upstreamConfig = Join-Path $ProjectRoot '.ralph\upstream.json'
    if (Test-Path $upstreamConfig) {
        try {
            $config = Get-Content $upstreamConfig -Raw | ConvertFrom-Json
            if ($config.branch) {
                return $config.branch
            }
        } catch {
            # Ignore parse errors
        }
    }
    
    return $script:DefaultUpstreamBranch
}

# ═══════════════════════════════════════════════════════════════
#                     UPDATE CHECK
# ═══════════════════════════════════════════════════════════════

function Test-RalphUpdateAvailable {
    <#
    .SYNOPSIS
        Checks if updates are available from upstream
    .DESCRIPTION
        Fetches from upstream and compares ralph/ folder changes.
        Uses sparse checkout concepts to only compare relevant paths.
    .OUTPUTS
        Hashtable with:
        - Available: bool - whether updates are available
        - LocalCommit: string - current commit SHA for ralph/
        - RemoteCommit: string - upstream commit SHA for ralph/
        - ChangedFiles: array - list of changed files in ralph/
        - Ahead: int - commits ahead of upstream
        - Behind: int - commits behind upstream
        - Error: string - error message if check failed
    #>
    param(
        [string]$ProjectRoot = $script:ProjectRoot,
        [switch]$Silent
    )
    
    $result = @{
        Available = $false
        LocalCommit = $null
        RemoteCommit = $null
        ChangedFiles = @()
        Ahead = 0
        Behind = 0
        Error = $null
    }
    
    # Verify we're in a git repository
    try {
        $repoRoot = git -C $ProjectRoot rev-parse --show-toplevel 2>$null
        if (-not $repoRoot) {
            $result.Error = "Not in a git repository"
            return $result
        }
    } catch {
        $result.Error = "Git not available"
        return $result
    }
    
    # Get upstream URL
    $upstreamUrl = Get-RalphUpstreamUrl -ProjectRoot $ProjectRoot
    
    # If this IS the main repo, no updates to check
    if ($null -eq $upstreamUrl) {
        if (-not $Silent) {
            Write-Host "  This is the main Ralph repository - no upstream to check" -ForegroundColor Gray
        }
        return $result
    }
    
    $upstreamBranch = Get-RalphUpstreamBranch -ProjectRoot $ProjectRoot
    
    if (-not $Silent) {
        Write-Host "  Checking for updates from: $upstreamUrl" -ForegroundColor Gray
    }
    
    # Ensure ralph-upstream remote exists
    try {
        $existingRemote = git -C $ProjectRoot config --get remote.ralph-upstream.url 2>$null
        if ($existingRemote -ne $upstreamUrl) {
            if ($existingRemote) {
                git -C $ProjectRoot remote set-url ralph-upstream $upstreamUrl 2>$null
            } else {
                git -C $ProjectRoot remote add ralph-upstream $upstreamUrl 2>$null
            }
        }
    } catch {
        $result.Error = "Failed to configure upstream remote"
        return $result
    }
    
    # Fetch from upstream
    try {
        if (-not $Silent) {
            Write-Host "  Fetching latest changes..." -ForegroundColor Gray
        }
        $fetchOutput = git -C $ProjectRoot fetch ralph-upstream $upstreamBranch 2>&1
        if ($LASTEXITCODE -ne 0) {
            $result.Error = "Failed to fetch from upstream: $fetchOutput"
            return $result
        }
    } catch {
        $result.Error = "Network error while fetching: $_"
        return $result
    }
    
    # Get current commit hashes
    try {
        $result.LocalCommit = git -C $ProjectRoot rev-parse HEAD 2>$null
        $result.RemoteCommit = git -C $ProjectRoot rev-parse "ralph-upstream/$upstreamBranch" 2>$null
    } catch {
        $result.Error = "Failed to get commit information"
        return $result
    }
    
    # Compare ralph/ folder specifically by comparing tree hashes, not commit history
    # This correctly detects actual file changes, even when git histories differ
    try {
        # Get the tree object hash for ralph/ folder in both commits
        $localTreeHash = git -C $ProjectRoot rev-parse HEAD:ralph 2>$null
        $remoteTreeHash = git -C $ProjectRoot rev-parse "ralph-upstream/$upstreamBranch:ralph" 2>$null
        
        # If tree hashes match, folders are identical - no updates needed
        if ($localTreeHash -and $remoteTreeHash -and $localTreeHash -eq $remoteTreeHash) {
            $result.Available = $false
            return $result
        }
        
        # Trees differ - get the list of changed files
        if ($localTreeHash -and $remoteTreeHash) {
            $diffOutput = git -C $ProjectRoot diff-tree --name-only -r $localTreeHash $remoteTreeHash 2>$null
            if ($diffOutput) {
                # Prepend 'ralph/' to each file path
                $result.ChangedFiles = @($diffOutput -split "`n" | Where-Object { $_ -match '\S' } | ForEach-Object { "ralph/$_" })
                $result.Available = $result.ChangedFiles.Count -gt 0
            }
        } else {
            # Fallback to regular diff if tree comparison fails
            $diffOutput = git -C $ProjectRoot diff --name-only HEAD "ralph-upstream/$upstreamBranch" -- ralph/ 2>$null
            if ($diffOutput) {
                $result.ChangedFiles = @($diffOutput -split "`n" | Where-Object { $_ -match '\S' })
                $result.Available = $result.ChangedFiles.Count -gt 0
            }
        }
        
    } catch {
        $result.Error = "Failed to compare with upstream: $_"
        return $result
    }
    
    return $result
}

# ═══════════════════════════════════════════════════════════════
#                     UPDATE APPLICATION
# ═══════════════════════════════════════════════════════════════

function Invoke-RalphUpdate {
    <#
    .SYNOPSIS
        Applies updates from upstream to the ralph/ folder
    .DESCRIPTION
        Selectively updates only ralph/ folder files:
        - Updates existing files with newer versions
        - Adds new files from upstream
        - Preserves files that don't exist in upstream
        - Preserves all user files outside ralph/
    .PARAMETER ProjectRoot
        Root directory of the project
    .PARAMETER Force
        Skip confirmation prompt
    .OUTPUTS
        Hashtable with:
        - Success: bool
        - UpdatedFiles: array
        - AddedFiles: array
        - Error: string
    #>
    param(
        [string]$ProjectRoot = $script:ProjectRoot,
        [switch]$Force
    )
    
    $result = @{
        Success = $false
        UpdatedFiles = @()
        AddedFiles = @()
        Error = $null
    }
    
    # Check for updates first
    $updateCheck = Test-RalphUpdateAvailable -ProjectRoot $ProjectRoot
    
    if ($updateCheck.Error) {
        $result.Error = $updateCheck.Error
        return $result
    }
    
    if (-not $updateCheck.Available) {
        $result.Success = $true
        Write-Host "  Ralph is already up to date!" -ForegroundColor Green
        return $result
    }
    
    $upstreamBranch = Get-RalphUpstreamBranch -ProjectRoot $ProjectRoot
    
    Write-Host ""
    Write-Host "  Update available!" -ForegroundColor Cyan
    Write-Host "  Files to update: $($updateCheck.ChangedFiles.Count)" -ForegroundColor White
    Write-Host ""
    
    # Show changed files
    if ($updateCheck.ChangedFiles.Count -le 20) {
        foreach ($file in $updateCheck.ChangedFiles) {
            Write-Host "    $file" -ForegroundColor Gray
        }
    } else {
        # Show first 10 and last 5
        for ($i = 0; $i -lt 10; $i++) {
            Write-Host "    $($updateCheck.ChangedFiles[$i])" -ForegroundColor Gray
        }
        Write-Host "    ... and $($updateCheck.ChangedFiles.Count - 15) more files ..." -ForegroundColor DarkGray
        for ($i = $updateCheck.ChangedFiles.Count - 5; $i -lt $updateCheck.ChangedFiles.Count; $i++) {
            Write-Host "    $($updateCheck.ChangedFiles[$i])" -ForegroundColor Gray
        }
    }
    Write-Host ""
    
    # Confirmation
    if (-not $Force) {
        if (Get-Command Show-ArrowConfirm -ErrorAction SilentlyContinue) {
            $confirmed = Show-ArrowConfirm -Title "Update Ralph" -Message "This will update ralph/ folder files.`nYour specs, sessions, and other files will be preserved.`n`nProceed with update?" -DefaultYes:$true
        } else {
            $confirm = Read-Host "Update ralph/ folder? ([Y]es/no)"
            if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = 'y' }
            $confirmed = $confirm -match "^(y|yes)$"
        }
        
        if (-not $confirmed) {
            Write-Host "  Update cancelled." -ForegroundColor Gray
            $result.Success = $true
            return $result
        }
    }
    
    Write-Host ""
    Write-Host "  Applying update..." -ForegroundColor Cyan
    
    # Strategy: Checkout specific files from upstream
    # This preserves local files that don't exist in upstream
    try {
        foreach ($file in $updateCheck.ChangedFiles) {
            # Check if file exists in upstream
            $fileExistsInUpstream = git -C $ProjectRoot ls-tree -r "ralph-upstream/$upstreamBranch" --name-only -- $file 2>$null
            
            if ($fileExistsInUpstream) {
                # File exists in upstream - checkout the new version
                git -C $ProjectRoot checkout "ralph-upstream/$upstreamBranch" -- $file 2>$null
                
                if ($LASTEXITCODE -eq 0) {
                    # Check if it's a new file or update
                    $localPath = Join-Path $ProjectRoot $file
                    $wasNew = -not (git -C $ProjectRoot ls-files --error-unmatch $file 2>$null)
                    
                    if ($wasNew) {
                        $result.AddedFiles += $file
                        Write-Host "    + $file" -ForegroundColor Green
                    } else {
                        $result.UpdatedFiles += $file
                        Write-Host "    ~ $file" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "    ! Failed: $file" -ForegroundColor Red
                }
            } else {
                # File deleted in upstream - leave it (user may have customizations)
                Write-Host "    - Skipped (deleted in upstream): $file" -ForegroundColor DarkGray
            }
        }
        
        $result.Success = $true
        
    } catch {
        $result.Error = "Update failed: $_"
        return $result
    }
    
    # Summary
    Write-Host ""
    Write-Host "  Update complete!" -ForegroundColor Green
    if ($result.UpdatedFiles.Count -gt 0) {
        Write-Host "    Updated: $($result.UpdatedFiles.Count) files" -ForegroundColor Yellow
    }
    if ($result.AddedFiles.Count -gt 0) {
        Write-Host "    Added:   $($result.AddedFiles.Count) files" -ForegroundColor Green
    }
    Write-Host ""
    
    return $result
}

# ═══════════════════════════════════════════════════════════════
#                     STARTUP CHECK
# ═══════════════════════════════════════════════════════════════

function Show-UpdateNotification {
    <#
    .SYNOPSIS
        Shows a non-intrusive notification if updates are available
    .DESCRIPTION
        Called at startup to inform user about available updates.
        Does not block or prompt - just shows a message.
    #>
    param(
        [string]$ProjectRoot = $script:ProjectRoot
    )
    
    $updateCheck = Test-RalphUpdateAvailable -ProjectRoot $ProjectRoot -Silent
    
    if ($updateCheck.Available) {
        Write-Host ""
        Write-Host "  ┌────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "  │  📦 Ralph update available!                    │" -ForegroundColor Cyan
        Write-Host "  │     $($updateCheck.ChangedFiles.Count) file(s) changed in upstream         │" -ForegroundColor Cyan
        Write-Host "  │     Press 'U' in main menu to update          │" -ForegroundColor Cyan
        Write-Host "  └────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
        return $true
    }
    
    return $false
}

function Get-UpdateStatus {
    <#
    .SYNOPSIS
        Gets a brief status string for display in menus
    .OUTPUTS
        String describing update status
    #>
    param(
        [string]$ProjectRoot = $script:ProjectRoot
    )
    
    $updateCheck = Test-RalphUpdateAvailable -ProjectRoot $ProjectRoot -Silent
    
    if ($updateCheck.Error) {
        return "Unable to check"
    }
    
    if ($updateCheck.Available) {
        return "$($updateCheck.ChangedFiles.Count) updates available"
    }
    
    return "Up to date"
}
