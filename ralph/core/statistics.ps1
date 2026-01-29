<#
.SYNOPSIS
    Statistics tracking module for Ralph Loop

.DESCRIPTION
    Provides git and session statistics tracking including:
    - Git file change tracking (created, modified, deleted)
    - Line-level statistics (lines added/removed)
    - Copilot CLI call statistics
    - Session duration tracking

.NOTES
    This module is sourced by loop.ps1 and requires:
    - $script:SessionStats to be defined
    - Git to be available in the environment
#>

# ═══════════════════════════════════════════════════════════════
#                    GIT STATISTICS
# ═══════════════════════════════════════════════════════════════

function Get-GitFileChanges {
    <#
    .SYNOPSIS
        Gets the current git status to track file changes
    .DESCRIPTION
        Parses git status --porcelain to get list of changed files with their status codes
    .OUTPUTS
        Array of hashtables with Status and File properties
    #>
    try {
        $status = git status --porcelain 2>$null
        if (-not $status) { return @() }
        
        $changes = @()
        foreach ($line in ($status -split "`n")) {
            if ($line.Length -ge 3) {
                $statusCode = $line.Substring(0, 2).Trim()
                $file = $line.Substring(3).Trim()
                
                # Handle renamed files (old -> new format)
                if ($file -match '(.+) -> (.+)') {
                    $file = $Matches[2]
                }
                
                $changes += @{
                    Status = $statusCode
                    File   = $file
                }
            }
        }
        return $changes
    } catch {
        return @()
    }
}

function Get-GitLineStats {
    <#
    .SYNOPSIS
        Gets lines added/removed using git diff --numstat
    .DESCRIPTION
        Returns hashtable with LinesAdded and LinesRemoved counts.
        Compares current HEAD against the initial commit SHA to include
        all committed changes during the session, plus any uncommitted changes.
    .OUTPUTS
        Hashtable with LinesAdded and LinesRemoved keys
    #>
    try {
        $linesAdded = 0
        $linesRemoved = 0
        
        # Get initial commit SHA from session stats
        $initialSha = $script:SessionStats.InitialCommitSha
        
        # If we have an initial SHA, compare against it to include committed changes
        if ($initialSha) {
            $committedStats = git diff --numstat "$initialSha..HEAD" 2>$null
            if ($committedStats) {
                foreach ($line in ($committedStats -split "`n")) {
                    if ($line -match '^(\d+)\s+(\d+)\s+') {
                        $linesAdded += [int]$Matches[1]
                        $linesRemoved += [int]$Matches[2]
                    }
                }
            }
        }
        
        # Get stats for staged changes (not yet committed)
        $stagedStats = git diff --cached --numstat 2>$null
        if ($stagedStats) {
            foreach ($line in ($stagedStats -split "`n")) {
                if ($line -match '^(\d+)\s+(\d+)\s+') {
                    $linesAdded += [int]$Matches[1]
                    $linesRemoved += [int]$Matches[2]
                }
            }
        }
        
        # Get stats for unstaged changes (working directory)
        $unstagedStats = git diff --numstat 2>$null
        if ($unstagedStats) {
            foreach ($line in ($unstagedStats -split "`n")) {
                if ($line -match '^(\d+)\s+(\d+)\s+') {
                    $linesAdded += [int]$Matches[1]
                    $linesRemoved += [int]$Matches[2]
                }
            }
        }
        
        # For untracked files, count all lines as added
        $untrackedFiles = git ls-files --others --exclude-standard 2>$null
        if ($untrackedFiles) {
            foreach ($file in ($untrackedFiles -split "`n")) {
                if ($file -and (Test-Path $file)) {
                    try {
                        $lineCount = (Get-Content $file -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
                        $linesAdded += $lineCount
                    } catch {
                        # Skip files that can't be read (binary, locked, etc.)
                    }
                }
            }
        }
        
        return @{
            LinesAdded   = $linesAdded
            LinesRemoved = $linesRemoved
        }
    } catch {
        return @{
            LinesAdded   = 0
            LinesRemoved = 0
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                    SESSION STATISTICS
# ═══════════════════════════════════════════════════════════════

function Initialize-SessionStats {
    <#
    .SYNOPSIS
        Captures initial git state for tracking changes during session
    .DESCRIPTION
        Records the git status at session start so we can calculate
        what changed during the Ralph session. Also captures the initial
        commit SHA to track line changes across commits.
    #>
    $script:SessionStats.InitialGitStatus = Get-GitFileChanges
    $script:SessionStats.Files = @{
        CreatedCount  = 0
        ModifiedCount = 0
        DeletedCount  = 0
        Created       = @()
        Modified      = @()
        Deleted       = @()
    }
    
    # Capture initial commit SHA to track line changes across commits
    try {
        $script:SessionStats.InitialCommitSha = (git rev-parse HEAD 2>$null)
        if (-not $script:SessionStats.InitialCommitSha) {
            $script:SessionStats.InitialCommitSha = $null
        }
    } catch {
        $script:SessionStats.InitialCommitSha = $null
    }
}

function Update-CopilotStats {
    <#
    .SYNOPSIS
        Updates statistics after a Copilot CLI call
    .DESCRIPTION
        Tracks successful, failed, and cancelled calls, along with
        duration and phase breakdown
    .PARAMETER Result
        Hashtable with Success, Cancelled, and Duration properties
    .PARAMETER Phase
        Phase name (AgentsUpdate, Planning, Building, SpecCreation)
    #>
    param(
        [hashtable]$Result,
        [string]$Phase = 'Building'
    )
    
    $script:SessionStats.CopilotCalls.Total++
    
    # Convert TimeSpan to seconds for logging
    $durationSeconds = 0
    if ($Result.Duration) {
        if ($Result.Duration -is [TimeSpan]) {
            $durationSeconds = $Result.Duration.TotalSeconds
        } else {
            $durationSeconds = [double]$Result.Duration
        }
    }
    
    if ($Result.Success) {
        $script:SessionStats.CopilotCalls.Successful++
        # Log successful Copilot call
        if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
            Write-LogCopilotCall -Action SUCCESS -Duration $durationSeconds
        }
    } elseif ($Result.Cancelled) {
        $script:SessionStats.CopilotCalls.Cancelled++
        # Log cancelled Copilot call
        if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
            Write-LogCopilotCall -Action CANCELLED -Duration $durationSeconds
        }
    } else {
        $script:SessionStats.CopilotCalls.Failed++
        # Log failed Copilot call
        if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
            Write-LogCopilotCall -Action FAILURE -Duration $durationSeconds -Output $Result.Output
        }
    }
    
    if ($Result.Duration) {
        $script:SessionStats.CopilotCalls.TotalDuration += $Result.Duration
        
        if ($script:SessionStats.CopilotCalls.Phases.ContainsKey($Phase)) {
            $script:SessionStats.CopilotCalls.Phases[$Phase].Count++
            $script:SessionStats.CopilotCalls.Phases[$Phase].Duration += $Result.Duration
        }
    }
}

function Update-FileStats {
    <#
    .SYNOPSIS
        Calculates file changes since session start
    .DESCRIPTION
        Compares current git state with initial state to determine
        what files were created, modified, or deleted during the session.
        Includes both committed changes (since initial SHA) and uncommitted changes.
        Also updates line-level statistics.
    #>
    $created = @()
    $modified = @()
    $deleted = @()
    
    # Get initial commit SHA
    $initialSha = $script:SessionStats.InitialCommitSha
    
    # Track committed file changes since session start
    if ($initialSha) {
        $committedFiles = git diff --name-status "$initialSha..HEAD" 2>$null
        if ($committedFiles) {
            foreach ($line in ($committedFiles -split "`n")) {
                if ($line -match '^([AMDRC])\s+(.+)$') {
                    $status = $Matches[1]
                    $file = $Matches[2].Trim()
                    
                    # Handle renamed files (R status shows as "R\told\tnew")
                    if ($status -eq 'R' -and $file -match '(.+)\t(.+)') {
                        $file = $Matches[2]
                    }
                    
                    switch ($status) {
                        'A' { $created += $file }
                        'D' { $deleted += $file }
                        'M' { $modified += $file }
                        'R' { $modified += $file }
                        'C' { $created += $file }
                    }
                }
            }
        }
    }
    
    # Also include uncommitted changes (staged and unstaged)
    $currentChanges = Get-GitFileChanges
    $initialFiles = @{}
    
    # Index initial changes
    foreach ($change in $script:SessionStats.InitialGitStatus) {
        $initialFiles[$change.File] = $change.Status
    }
    
    foreach ($change in $currentChanges) {
        $file = $change.File
        $status = $change.Status
        
        # Skip if file was already in initial state
        if ($initialFiles.ContainsKey($file) -and $initialFiles[$file] -eq $status) {
            continue
        }
        
        # Classify the change
        switch -Regex ($status) {
            '^A' { $created += $file }
            '^\?\?' { $created += $file }
            '^D' { $deleted += $file }
            '^M' { $modified += $file }
            '^ M' { $modified += $file }
            '^R' { $modified += $file }
            default { $modified += $file }
        }
    }
    
    $script:SessionStats.Files.Created = @($created | Select-Object -Unique)
    $script:SessionStats.Files.Modified = @($modified | Select-Object -Unique)
    $script:SessionStats.Files.Deleted = @($deleted | Select-Object -Unique)
    $script:SessionStats.Files.CreatedCount = $script:SessionStats.Files.Created.Count
    $script:SessionStats.Files.ModifiedCount = $script:SessionStats.Files.Modified.Count
    $script:SessionStats.Files.DeletedCount = $script:SessionStats.Files.Deleted.Count
    
    # Get line-level statistics
    $lineStats = Get-GitLineStats
    $script:SessionStats.Files.LinesAdded = $lineStats.LinesAdded
    $script:SessionStats.Files.LinesRemoved = $lineStats.LinesRemoved
}
