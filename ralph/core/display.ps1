<#
.SYNOPSIS
    Display and UI module for Ralph Loop

.DESCRIPTION
    Provides all user interface functions including:
    - Logging and output formatting (Write-Ralph, Write-VerboseOutput, Write-DebugOutput)
    - Session summary display (Show-SessionSummary)
    - Duration formatting
    - Iteration prompts

.NOTES
    This module is sourced by loop.ps1 and requires:
    - $script:VerboseMode to be defined
    - $script:SessionStats to be defined
    - $script:AvailableModels to be defined
    - Menu system (menus.ps1) to be loaded
    - Memory system (memory.ps1) to be loaded
#>

# Helper function to conditionally clear screen
function Clear-HostConditional {
    <#
    .SYNOPSIS
        Clears the host screen unless developer mode is enabled
    .DESCRIPTION
        In developer mode, screen is not cleared so history can be scrolled
        If DeveloperMode is not set, defaults to clearing screen
    #>
    $devMode = if (Get-Variable -Name 'DeveloperMode' -Scope Script -ErrorAction SilentlyContinue) {
        $script:DeveloperMode
    } else {
        $false
    }
    
    if (-not $devMode) {
        try {
            Clear-Host
        } catch {
            # Handle non-interactive console (e.g., running in subprocess)
            # Just skip clearing - it's not critical
        }
    } else {
        Write-Host ""
        Write-Host ("═" * 80) -ForegroundColor DarkGray
        Write-Host ""
    }
}

# ═══════════════════════════════════════════════════════════════
#                    LOGGING & OUTPUT
# ═══════════════════════════════════════════════════════════════

function Write-Ralph {
    <#
    .SYNOPSIS
        Main logging function for Ralph with typed output
    .PARAMETER Message
        Message to display
    .PARAMETER Type
        Message type: info, success, warning, error, task, header, verbose, debug
    #>
    param(
        [string]$Message,
        [ValidateSet('info', 'success', 'warning', 'error', 'task', 'header', 'verbose', 'debug')]
        [string]$Type = 'info'
    )
    
    # Skip verbose/debug messages unless verbose mode is enabled
    if ($Type -in @('verbose', 'debug') -and -not $script:VerboseMode) {
        return
    }
    
    # Build mode prefix from active modes
    $modes = @()
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        $modes += "DRY-RUN"
    }
    if ($script:DeveloperMode) {
        $modes += "DEV"
    }
    if ($script:VerboseMode -and $Type -notin @('verbose', 'debug')) {
        $modes += "VERBOSE"
    }
    
    $modePrefix = if ($modes.Count -gt 0) {
        "[" + ($modes -join "|") + "] "
    } else {
        ""
    }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Type) {
        'success' { 'Green' }
        'warning' { 'Yellow' }
        'error'   { 'Red' }
        'info'    { 'Gray' }
        'task'    { 'Cyan' }
        'header'  { 'Magenta' }
        'verbose' { 'DarkGray' }
        'debug'   { 'DarkCyan' }
        default   { 'White' }
    }
    
    $prefix = switch ($Type) {
        'verbose' { '  │ ' }
        'debug'   { '  ▸ ' }
        default   { '' }
    }
    
    if ($Type -eq 'header') {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $color
        Write-Host "  $modePrefix$Message" -ForegroundColor White
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $color
    } else {
        Write-Host "$prefix[$timestamp] $modePrefix$Message" -ForegroundColor $color
    }
    
    # Also log to file if logging module is available
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        $logTag = switch ($Type) {
            'error'   { 'ERROR' }
            'warning' { 'WARNING' }
            'success' { 'INFO' }
            'task'    { 'TASK' }
            'header'  { 'SESSION' }
            'verbose' { 'DEBUG' }
            'debug'   { 'DEBUG' }
            default   { 'INFO' }
        }
        Write-Log -Message $Message -Tag $logTag
    }
}

function Write-VerboseOutput {
    <#
    .SYNOPSIS
        Writes verbose output (only shown when -ShowVerbose is enabled)
    .PARAMETER Message
        Verbose message to display
    .PARAMETER Category
        Optional category tag for the message
    #>
    param(
        [string]$Message,
        [string]$Category = ''
    )
    
    if (-not $script:VerboseMode) { return }
    
    $prefix = if ($Category) { "[$Category] " } else { "" }
    Write-Host "  │ $prefix$Message" -ForegroundColor DarkGray
}

function Write-DebugOutput {
    <#
    .SYNOPSIS
        Writes debug output for raw CLI responses with line truncation
    .PARAMETER Message
        Debug message (typically multi-line CLI output)
    .PARAMETER MaxLines
        Maximum lines to display (default: 20)
    #>
    param(
        [string]$Message,
        [int]$MaxLines = 20
    )
    
    if (-not $script:VerboseMode) { return }
    
    $lines = $Message -split "`n"
    $total = $lines.Count
    
    Write-Host "  ┌─ CLI Output ($total lines) ──────────────────────────" -ForegroundColor DarkCyan
    
    $displayLines = if ($total -gt $MaxLines) { $MaxLines } else { $total }
    
    for ($i = 0; $i -lt $displayLines; $i++) {
        $line = $lines[$i]
        if ($line.Length -gt 70) {
            $line = $line.Substring(0, 67) + "..."
        }
        Write-Host "  │ $line" -ForegroundColor DarkGray
    }
    
    if ($total -gt $MaxLines) {
        Write-Host "  │ ... ($($total - $MaxLines) more lines)" -ForegroundColor DarkGray
    }
    
    Write-Host "  └──────────────────────────────────────────────────────" -ForegroundColor DarkCyan
}

# ═══════════════════════════════════════════════════════════════
#                     FORMATTING UTILITIES
# ═══════════════════════════════════════════════════════════════

function Format-Duration {
    <#
    .SYNOPSIS
        Formats a TimeSpan into a human-readable string
    .PARAMETER Duration
        TimeSpan to format
    .OUTPUTS
        Formatted string (e.g., "01:23:45", "45m 23s", "12s")
    #>
    param([TimeSpan]$Duration)
    
    if ($Duration.TotalHours -ge 1) {
        return "{0:00}:{1:00}:{2:00}" -f [int]$Duration.TotalHours, $Duration.Minutes, $Duration.Seconds
    } elseif ($Duration.TotalMinutes -ge 1) {
        return "{0}m {1}s" -f [int]$Duration.TotalMinutes, $Duration.Seconds
    } else {
        return "{0}s" -f [int]$Duration.TotalSeconds
    }
}

# ═══════════════════════════════════════════════════════════════
#                    SESSION SUMMARY
# ═══════════════════════════════════════════════════════════════

function Show-SessionSummary {
    <#
    .SYNOPSIS
        Displays comprehensive end-of-session summary with statistics
    .PARAMETER Iterations
        Number of build iterations completed
    .PARAMETER StartTime
        Session start time
    #>
    param(
        [int]$Iterations,
        [DateTime]$StartTime
    )
    
    # Update file stats before showing summary
    Update-FileStats
    
    $endTime = Get-Date
    $totalDuration = $endTime - $StartTime
    $taskStats = Get-TaskStats
    $stats = $script:SessionStats
    
    # Get model display name
    $modelInfo = $script:AvailableModels | Where-Object { $_.Name -eq $script:Model } | Select-Object -First 1
    $modelDisplay = if ($modelInfo) { "$($modelInfo.Display) ($($modelInfo.Multiplier))" } else { $script:Model }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  RALPH SESSION SUMMARY" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    
    # Session Overview
    Write-Host "  SESSION OVERVIEW" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    # Show active task
    $activeTaskId = $script:CurrentTaskId
    if ($activeTaskId -and $activeTaskId -ne 'default') {
        Write-Host "  Task:            " -NoNewline -ForegroundColor White
        Write-Host $activeTaskId -ForegroundColor Cyan
    }
    
    Write-Host "  Model:           " -NoNewline -ForegroundColor White
    Write-Host $modelDisplay -ForegroundColor Green
    Write-Host "  Mode:            " -NoNewline -ForegroundColor White
    Write-Host $Mode -ForegroundColor Yellow
    Write-Host "  Start Time:      " -NoNewline -ForegroundColor White
    Write-Host $StartTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Gray
    Write-Host "  End Time:        " -NoNewline -ForegroundColor White
    Write-Host $endTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Gray
    Write-Host "  Total Duration:  " -NoNewline -ForegroundColor White
    Write-Host (Format-Duration -Duration $totalDuration) -ForegroundColor Cyan
    Write-Host ""
    
    # Task Progress
    Write-Host "  TASK PROGRESS" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Build Iterations:" -NoNewline -ForegroundColor White
    $iterLimit = if ($script:EffectiveMaxIterations -eq 0) { "unlimited" } else { "of $($script:EffectiveMaxIterations)" }
    Write-Host " $Iterations " -NoNewline -ForegroundColor Yellow
    Write-Host "($iterLimit)" -ForegroundColor DarkGray
    Write-Host "  Tasks Completed: " -NoNewline -ForegroundColor White
    $taskColor = if ($taskStats.Pending -eq 0) { "Green" } else { "Yellow" }
    Write-Host "$($taskStats.Completed)/$($taskStats.Total)" -NoNewline -ForegroundColor $taskColor
    if ($taskStats.Pending -gt 0) {
        Write-Host " ($($taskStats.Pending) remaining)" -ForegroundColor DarkYellow
    } else {
        Write-Host " (all complete!)" -ForegroundColor Green
    }
    Write-Host ""
    
    # Copilot CLI Statistics
    Write-Host "  COPILOT CLI CALLS" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Total Calls:     " -NoNewline -ForegroundColor White
    Write-Host $stats.CopilotCalls.Total -ForegroundColor Yellow
    Write-Host "  Successful:      " -NoNewline -ForegroundColor White
    Write-Host $stats.CopilotCalls.Successful -ForegroundColor Green
    if ($stats.CopilotCalls.Failed -gt 0) {
        Write-Host "  Failed:          " -NoNewline -ForegroundColor White
        Write-Host $stats.CopilotCalls.Failed -ForegroundColor Red
    }
    if ($stats.CopilotCalls.Cancelled -gt 0) {
        Write-Host "  Cancelled:       " -NoNewline -ForegroundColor White
        Write-Host $stats.CopilotCalls.Cancelled -ForegroundColor DarkYellow
    }
    Write-Host "  AI Time:         " -NoNewline -ForegroundColor White
    Write-Host (Format-Duration -Duration $stats.CopilotCalls.TotalDuration) -ForegroundColor Cyan
    
    # Phase breakdown if there were multiple phases
    $phases = $stats.CopilotCalls.Phases
    $activePhasesCount = 0
    if ($phases) {
        $activePhasesCount = @($phases.Values | Where-Object { $_ -and $_.Count -gt 0 }).Count
    }
    if ($activePhasesCount -gt 1) {
        Write-Host ""
        Write-Host "  Phase Breakdown:" -ForegroundColor DarkGray
        foreach ($phase in $stats.CopilotCalls.Phases.Keys) {
            $phaseData = $stats.CopilotCalls.Phases[$phase]
            if ($phaseData.Count -gt 0) {
                $phaseDuration = Format-Duration -Duration $phaseData.Duration
                Write-Host "    $phase`: " -NoNewline -ForegroundColor White
                Write-Host "$($phaseData.Count) call(s), $phaseDuration" -ForegroundColor Gray
            }
        }
    }
    Write-Host ""
    
    # File Changes
    $totalFileChanges = $stats.Files.CreatedCount + $stats.Files.ModifiedCount + $stats.Files.DeletedCount
    Write-Host "  FILE CHANGES" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    if ($totalFileChanges -eq 0 -and $stats.Files.LinesAdded -eq 0 -and $stats.Files.LinesRemoved -eq 0) {
        Write-Host "  No file changes detected" -ForegroundColor DarkGray
    } else {
        # Show line-level statistics
        Write-Host "  Total code changes:" -NoNewline -ForegroundColor White
        Write-Host " $($stats.Files.LinesAdded) lines added" -NoNewline -ForegroundColor Green
        Write-Host ", " -NoNewline -ForegroundColor White
        Write-Host "$($stats.Files.LinesRemoved) lines removed" -ForegroundColor Red
        
        if ($stats.Files.CreatedCount -gt 0) {
            Write-Host "  Created:         " -NoNewline -ForegroundColor White
            Write-Host "$($stats.Files.CreatedCount) file(s)" -ForegroundColor Green
            foreach ($file in ($stats.Files.Created | Select-Object -First 10)) {
                Write-Host "    + $file" -ForegroundColor DarkGreen
            }
            if ($stats.Files.CreatedCount -gt 10) {
                Write-Host "    ... and $($stats.Files.CreatedCount - 10) more" -ForegroundColor DarkGray
            }
        }
        if ($stats.Files.ModifiedCount -gt 0) {
            Write-Host "  Modified:        " -NoNewline -ForegroundColor White
            Write-Host "$($stats.Files.ModifiedCount) file(s)" -ForegroundColor Yellow
            foreach ($file in ($stats.Files.Modified | Select-Object -First 10)) {
                Write-Host "    ~ $file" -ForegroundColor DarkYellow
            }
            if ($stats.Files.ModifiedCount -gt 10) {
                Write-Host "    ... and $($stats.Files.ModifiedCount - 10) more" -ForegroundColor DarkGray
            }
        }
        if ($stats.Files.DeletedCount -gt 0) {
            Write-Host "  Deleted:         " -NoNewline -ForegroundColor White
            Write-Host "$($stats.Files.DeletedCount) file(s)" -ForegroundColor Red
            foreach ($file in ($stats.Files.Deleted | Select-Object -First 5)) {
                Write-Host "    - $file" -ForegroundColor DarkRed
            }
            if ($stats.Files.DeletedCount -gt 5) {
                Write-Host "    ... and $($stats.Files.DeletedCount - 5) more" -ForegroundColor DarkGray
            }
        }
    }
    Write-Host ""
    
    # Final status bar
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    if ($taskStats.Pending -eq 0 -and $taskStats.Total -gt 0) {
        Write-Host "  ✓ ALL TASKS COMPLETED SUCCESSFULLY" -ForegroundColor Green
    } elseif ($taskStats.Completed -gt 0) {
        Write-Host "  ◐ SESSION ENDED - Progress saved, $($taskStats.Pending) tasks remaining" -ForegroundColor Yellow
    } else {
        Write-Host "  ○ SESSION ENDED" -ForegroundColor DarkGray
    }
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                    INTERACTIVE PROMPTS
# ═══════════════════════════════════════════════════════════════

function Show-IterationPrompt {
    <#
    .SYNOPSIS
        Prompts user to confirm iteration settings before building.
        Uses centralized arrow navigation menu from menus.ps1.
    .PARAMETER CurrentMax
        Current maximum iteration count
    .PARAMETER PendingTasks
        Number of pending tasks
    .OUTPUTS
        Number of iterations (0 = unlimited, -1 = exit)
    #>
    param(
        [int]$CurrentMax = 0,
        [int]$PendingTasks = 0
    )
    
    # Delegate to the centralized arrow navigation menu
    return Show-IterationMenu -PendingTasks $PendingTasks -CurrentMax $CurrentMax
}
