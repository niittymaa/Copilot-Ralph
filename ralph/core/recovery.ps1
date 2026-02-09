<#
.SYNOPSIS
    Recovery module for Ralph Loop - resume from checkpoints after errors

.DESCRIPTION
    Provides functions to:
    - Check if a session can be resumed
    - Restore state from checkpoint
    - Handle resume flow in menus
    - Validate checkpoint integrity

.NOTES
    Works with checkpoint.ps1 and errors.ps1 modules
#>

# ═══════════════════════════════════════════════════════════════
#                     RECOVERY STATE
# ═══════════════════════════════════════════════════════════════

$script:ResumeMode = $false
$script:RestoredCheckpoint = $null

# ═══════════════════════════════════════════════════════════════
#                     RECOVERY DETECTION
# ═══════════════════════════════════════════════════════════════

function Test-SessionNeedsRecovery {
    <#
    .SYNOPSIS
        Checks if a session has an interrupted checkpoint that can be resumed
    .PARAMETER TaskId
        Task ID to check (defaults to active task)
    .OUTPUTS
        Boolean - True if session can be resumed
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not (Get-Command Test-HasCheckpoint -ErrorAction SilentlyContinue)) {
        return $false
    }
    
    if (-not (Test-HasCheckpoint -TaskId $TaskId)) {
        return $false
    }
    
    if (-not (Get-Command Get-Checkpoint -ErrorAction SilentlyContinue)) {
        return $false
    }
    
    $checkpoint = Get-Checkpoint -TaskId $TaskId
    if (-not $checkpoint) {
        return $false
    }
    
    # Check if checkpoint is in an interrupted state
    $interruptedPhases = @('building', 'planning', 'spec-creation', 'error')
    
    if ($checkpoint.phase -in $interruptedPhases) {
        # For error state, check if it's resumable
        if ($checkpoint.phase -eq 'error') {
            return $checkpoint.canResume -eq $true
        }
        return $true
    }
    
    return $false
}

function Get-RecoveryInfo {
    <#
    .SYNOPSIS
        Gets detailed recovery information for a session
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Hashtable with recovery details, or $null if no recovery needed
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not (Test-SessionNeedsRecovery -TaskId $TaskId)) {
        return $null
    }
    
    $checkpoint = Get-Checkpoint -TaskId $TaskId
    if (-not $checkpoint) {
        return $null
    }
    
    $info = @{
        HasCheckpoint     = $true
        CanResume         = $true
        Phase             = if ($checkpoint.ContainsKey('phase')) { $checkpoint.phase } else { 'unknown' }
        InterruptedPhase  = if ($checkpoint.ContainsKey('interruptedPhase')) { $checkpoint.interruptedPhase } elseif ($checkpoint.ContainsKey('phase')) { $checkpoint.phase } else { 'unknown' }
        Iteration         = if ($checkpoint.ContainsKey('iteration')) { $checkpoint.iteration } else { 0 }
        CompletedTasks    = if ($checkpoint.ContainsKey('completedTasks') -and $checkpoint.completedTasks) { $checkpoint.completedTasks.Count } else { 0 }
        CurrentTask       = if ($checkpoint.ContainsKey('currentTask')) { $checkpoint.currentTask } else { $null }
        Timestamp         = if ($checkpoint.ContainsKey('timestamp')) { $checkpoint.timestamp } else { $null }
        Error             = if ($checkpoint.ContainsKey('error')) { $checkpoint.error } else { $null }
        Summary           = ''
    }
    
    # Build summary
    if ($checkpoint.ContainsKey('phase') -and $checkpoint.phase -eq 'error' -and $checkpoint.ContainsKey('error') -and $checkpoint.error) {
        $errorMsg = if ($checkpoint.error -is [hashtable] -and $checkpoint.error.ContainsKey('Message')) { $checkpoint.error.Message } elseif ($checkpoint.error.PSObject.Properties['Message']) { $checkpoint.error.Message } else { "$($checkpoint.error)" }
        $info.Summary = "Stopped due to: $errorMsg"
        $info.CanResume = $checkpoint.ContainsKey('canResume') -and $checkpoint.canResume -eq $true
    } elseif ($checkpoint.ContainsKey('phase') -and $checkpoint.phase -eq 'building') {
        $info.Summary = "$(if ($checkpoint.ContainsKey('iteration')) { $checkpoint.iteration } else { 0 }) iteration(s) completed"
        if ($checkpoint.ContainsKey('currentTask') -and $checkpoint.currentTask) {
            $info.Summary += " - Last: $($checkpoint.currentTask)"
        }
    } elseif ($checkpoint.ContainsKey('phase') -and $checkpoint.phase -eq 'planning') {
        $info.Summary = "Planning was interrupted"
    } elseif ($checkpoint.ContainsKey('phase') -and $checkpoint.phase -eq 'spec-creation') {
        $info.Summary = "Spec creation was interrupted"
    }
    
    return $info
}

# ═══════════════════════════════════════════════════════════════
#                     RESUME FLOW
# ═══════════════════════════════════════════════════════════════

function Show-RecoveryPrompt {
    <#
    .SYNOPSIS
        Shows a recovery prompt to the user when a session can be resumed
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .PARAMETER RecoveryInfo
        Recovery info from Get-RecoveryInfo (optional, will be fetched if not provided)
    .OUTPUTS
        String - 'resume', 'restart', or 'cancel'
    #>
    param(
        [string]$TaskId = $null,
        
        [hashtable]$RecoveryInfo = $null
    )
    
    if (-not $RecoveryInfo) {
        $RecoveryInfo = Get-RecoveryInfo -TaskId $TaskId
    }
    
    if (-not $RecoveryInfo) {
        return 'restart'  # No recovery needed
    }
    
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║              PREVIOUS SESSION INTERRUPTED                 ║" -ForegroundColor Yellow
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    # Show checkpoint info
    Write-Host "  📋 Progress Saved (last completed state):" -ForegroundColor Cyan
    Write-Host "     • Timestamp: $($RecoveryInfo.Timestamp)" -ForegroundColor Gray
    Write-Host "     • Phase: $($RecoveryInfo.InterruptedPhase)" -ForegroundColor Gray
    
    if ($RecoveryInfo.Iteration -gt 0) {
        Write-Host "     • Completed Iterations: $($RecoveryInfo.Iteration)" -ForegroundColor Gray
    }
    
    if ($RecoveryInfo.CompletedTasks -gt 0) {
        Write-Host "     • Completed Tasks: $($RecoveryInfo.CompletedTasks)" -ForegroundColor Gray
    }
    
    if ($RecoveryInfo.CurrentTask) {
        Write-Host "     • Last Completed Task: $($RecoveryInfo.CurrentTask)" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Show error if present
    if ($RecoveryInfo.Error) {
        $errMsg = if ($RecoveryInfo.Error -is [hashtable] -and $RecoveryInfo.Error.ContainsKey('Message')) { $RecoveryInfo.Error.Message } elseif ($RecoveryInfo.Error.PSObject.Properties['Message']) { $RecoveryInfo.Error.Message } else { "$($RecoveryInfo.Error)" }
        Write-Host "  ⚠️  Stopped Reason:" -ForegroundColor Yellow
        Write-Host "     $errMsg" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Show resume option
    Write-Host "  $($RecoveryInfo.Summary)" -ForegroundColor White
    Write-Host ""
    
    if (-not $RecoveryInfo.CanResume) {
        Write-Host "  ⛔ This session cannot be resumed (error type prevents resume)" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Press any key to start fresh..." -ForegroundColor DarkGray
        $null = [Console]::ReadKey($true)
        return 'restart'
    }
    
    # Show choices using arrow navigation if available
    if (Get-Command Show-ArrowChoice -ErrorAction SilentlyContinue) {
        try {
            $choice = Show-ArrowChoice -Title "What would you like to do?" -Choices @(
                @{ Label = "Resume from checkpoint"; Value = "resume"; Default = $true }
                @{ Label = "Start fresh (discard progress)"; Value = "restart" }
                @{ Label = "Cancel (return to menu)"; Value = "cancel" }
            )
            if ($choice) { return $choice }
            return 'cancel'
        } catch {
            if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                Write-Log -Tag 'WARN' -Message "Arrow menu failed in recovery prompt, using fallback: $_"
            }
            # Fall through to text-based prompt below
        }
    }
    
    # Fallback to simple prompt
    Write-Host "  [R] Resume from checkpoint (recommended)" -ForegroundColor Green
    Write-Host "  [S] Start fresh (discard progress)" -ForegroundColor Yellow
    Write-Host "  [C] Cancel" -ForegroundColor Gray
    Write-Host ""
    
    while ($true) {
        $key = [Console]::ReadKey($true)
        switch ($key.KeyChar.ToString().ToLower()) {
            'r' { return 'resume' }
            's' { return 'restart' }
            'c' { return 'cancel' }
        }
    }
}

function Invoke-Recovery {
    <#
    .SYNOPSIS
        Restores state from checkpoint and prepares for resume
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Hashtable with restoration details
    #>
    param(
        [string]$TaskId = $null
    )
    
    $checkpoint = Get-Checkpoint -TaskId $TaskId
    if (-not $checkpoint) {
        return @{
            Success = $false
            Error   = 'No checkpoint found'
        }
    }
    
    # Validate checkpoint
    if (-not (Test-CheckpointValid -Checkpoint $checkpoint)) {
        return @{
            Success = $false
            Error   = 'Checkpoint is invalid or corrupted'
        }
    }
    
    # Store for resume
    $script:ResumeMode = $true
    $script:RestoredCheckpoint = $checkpoint
    
    # Log recovery
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Tag 'SESSION' -Message "Recovering from checkpoint: phase=$($checkpoint.phase), iteration=$($checkpoint.iteration)"
    }
    
    # Determine which phase to resume
    $resumePhase = if ($checkpoint.phase -eq 'error' -and $checkpoint.ContainsKey('interruptedPhase')) {
        $checkpoint.interruptedPhase
    } else {
        $checkpoint.phase
    }
    
    return @{
        Success       = $true
        Phase         = $resumePhase
        Iteration     = $checkpoint.iteration
        CurrentTask   = $checkpoint.currentTask
        CompletedCount = if ($checkpoint.completedTasks) { $checkpoint.completedTasks.Count } else { 0 }
    }
}

function Clear-Recovery {
    <#
    .SYNOPSIS
        Clears recovery state (after successful resume or user chooses to restart)
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .PARAMETER KeepCheckpoint
        If true, keeps the checkpoint file
    #>
    param(
        [string]$TaskId = $null,
        
        [switch]$KeepCheckpoint
    )
    
    $script:ResumeMode = $false
    $script:RestoredCheckpoint = $null
    
    if (-not $KeepCheckpoint) {
        if (Get-Command Remove-Checkpoint -ErrorAction SilentlyContinue) {
            Remove-Checkpoint -TaskId $TaskId
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                     VALIDATION
# ═══════════════════════════════════════════════════════════════

function Test-CheckpointValid {
    <#
    .SYNOPSIS
        Validates checkpoint structure and integrity
    .PARAMETER Checkpoint
        Checkpoint hashtable to validate
    .OUTPUTS
        Boolean - True if valid
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Checkpoint
    )
    
    # Required fields
    $requiredFields = @('version', 'phase', 'timestamp')
    
    foreach ($field in $requiredFields) {
        if (-not $Checkpoint.ContainsKey($field)) {
            return $false
        }
    }
    
    # Version check
    if ($Checkpoint.version -lt 1) {
        return $false
    }
    
    # Phase validation
    $validPhases = @('idle', 'spec-creation', 'planning', 'building', 'complete', 'error')
    if ($Checkpoint.phase -notin $validPhases) {
        return $false
    }
    
    return $true
}

# ═══════════════════════════════════════════════════════════════
#                     STATE ACCESSORS
# ═══════════════════════════════════════════════════════════════

function Test-ResumeMode {
    <#
    .SYNOPSIS
        Checks if we're in resume mode
    .OUTPUTS
        Boolean - True if resuming from checkpoint
    #>
    return $script:ResumeMode
}

function Get-RestoredCheckpoint {
    <#
    .SYNOPSIS
        Gets the restored checkpoint data
    .OUTPUTS
        Hashtable - Checkpoint data, or $null
    #>
    return $script:RestoredCheckpoint
}

function Get-ResumeIteration {
    <#
    .SYNOPSIS
        Gets the iteration to resume from
    .OUTPUTS
        Int - Iteration number to start from
    #>
    if ($script:RestoredCheckpoint) {
        return $script:RestoredCheckpoint.iteration
    }
    return 0
}

function Get-ResumePhase {
    <#
    .SYNOPSIS
        Gets the phase to resume
    .OUTPUTS
        String - Phase name
    #>
    if ($script:RestoredCheckpoint) {
        if ($script:RestoredCheckpoint.phase -eq 'error' -and $script:RestoredCheckpoint.ContainsKey('interruptedPhase')) {
            return $script:RestoredCheckpoint.interruptedPhase
        }
        return $script:RestoredCheckpoint.phase
    }
    return 'idle'
}
