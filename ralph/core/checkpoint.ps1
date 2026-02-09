<#
.SYNOPSIS
    Checkpoint module for Ralph Loop - state persistence and recovery

.DESCRIPTION
    Provides state checkpointing for Ralph to enable:
    - Graceful recovery from errors
    - Resume from last solid checkpoint
    - Track progress through phases and iterations
    
    Checkpoints are saved at key points:
    - Before starting each phase
    - After completing each task
    - When errors occur (with error state)

.NOTES
    Checkpoint files stored in: .ralph/tasks/{taskId}/checkpoint.json
#>

# ═══════════════════════════════════════════════════════════════
#                     MODULE STATE
# ═══════════════════════════════════════════════════════════════

$script:CheckpointEnabled = $true
$script:CurrentCheckpoint = $null

# Phase definitions
$script:Phases = @{
    Idle         = 'idle'
    SpecCreation = 'spec-creation'
    Planning     = 'planning'
    Building     = 'building'
    Complete     = 'complete'
    Error        = 'error'
}

# ═══════════════════════════════════════════════════════════════
#                     CHECKPOINT OPERATIONS
# ═══════════════════════════════════════════════════════════════

function Get-CheckpointPath {
    <#
    .SYNOPSIS
        Gets the checkpoint file path for a task
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        String - Path to checkpoint.json
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not $TaskId) {
        if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
            $TaskId = Get-ActiveTaskId
        }
    }
    
    if (-not $TaskId) {
        return $null
    }
    
    if (Get-Command Get-TaskDirectory -ErrorAction SilentlyContinue) {
        $taskDir = Get-TaskDirectory -TaskId $TaskId
        if ($taskDir) {
            return Join-Path $taskDir 'checkpoint.json'
        }
    }
    
    return $null
}

function New-Checkpoint {
    <#
    .SYNOPSIS
        Creates a new checkpoint object with current state
    .PARAMETER Phase
        Current phase (idle, spec-creation, planning, building, complete, error)
    .PARAMETER Iteration
        Current build iteration number
    .PARAMETER CurrentTask
        Description of the current task being worked on
    .PARAMETER CompletedTasks
        Array of completed task descriptions
    .PARAMETER ErrorInfo
        Error information if checkpoint is due to an error
    .OUTPUTS
        Hashtable - Checkpoint object
    #>
    param(
        [ValidateSet('idle', 'spec-creation', 'planning', 'building', 'complete', 'error')]
        [string]$Phase = 'idle',
        
        [int]$Iteration = 0,
        
        [string]$CurrentTask = '',
        
        [string[]]$CompletedTasks = @(),
        
        [hashtable]$ErrorInfo = $null
    )
    
    $checkpoint = @{
        version        = 1
        taskId         = $null
        phase          = $Phase
        iteration      = $Iteration
        currentTask    = $CurrentTask
        completedTasks = $CompletedTasks
        timestamp      = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        timestampUtc   = (Get-Date).ToUniversalTime().ToString('o')
        error          = $ErrorInfo
        canResume      = $true
    }
    
    # Get active task ID
    if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
        $checkpoint.taskId = Get-ActiveTaskId
    }
    
    # If there's an error, set canResume based on error info
    if ($ErrorInfo) {
        $checkpoint.canResume = if ($ErrorInfo.ContainsKey('CanResume')) { $ErrorInfo.CanResume } else { $true }
    }
    
    return $checkpoint
}

function Save-Checkpoint {
    <#
    .SYNOPSIS
        Saves checkpoint to disk
    .PARAMETER Checkpoint
        Checkpoint object to save
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Boolean - True if saved successfully
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Checkpoint,
        
        [string]$TaskId = $null
    )
    
    if (-not $script:CheckpointEnabled) {
        return $true
    }
    
    # Skip in dry-run mode
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        return $true
    }
    
    $checkpointPath = Get-CheckpointPath -TaskId $TaskId
    if (-not $checkpointPath) {
        return $false
    }
    
    try {
        # Ensure directory exists
        $checkpointDir = Split-Path -Parent $checkpointPath
        if (-not (Test-Path $checkpointDir)) {
            New-Item -ItemType Directory -Path $checkpointDir -Force | Out-Null
        }
        
        # Save checkpoint
        $Checkpoint | ConvertTo-Json -Depth 10 | Set-Content -Path $checkpointPath -Encoding UTF8 -Force
        
        # Update current checkpoint reference
        $script:CurrentCheckpoint = $Checkpoint
        
        # Log checkpoint save
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Tag 'SESSION' -Message "Checkpoint saved: phase=$($Checkpoint.phase), iteration=$($Checkpoint.iteration)"
        }
        
        return $true
    }
    catch {
        # Log error but don't fail the operation
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Tag 'ERROR' -Message "Failed to save checkpoint: $_"
        }
        return $false
    }
}

function Get-Checkpoint {
    <#
    .SYNOPSIS
        Loads checkpoint from disk
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Hashtable - Checkpoint object, or $null if not found
    #>
    param(
        [string]$TaskId = $null
    )
    
    $checkpointPath = Get-CheckpointPath -TaskId $TaskId
    if (-not $checkpointPath -or -not (Test-Path $checkpointPath)) {
        return $null
    }
    
    try {
        $checkpoint = Get-Content -Path $checkpointPath -Raw | ConvertFrom-Json -AsHashtable
        return $checkpoint
    }
    catch {
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Tag 'ERROR' -Message "Failed to load checkpoint: $_"
        }
        return $null
    }
}

function Remove-Checkpoint {
    <#
    .SYNOPSIS
        Removes checkpoint file (used when task completes successfully)
    .PARAMETER TaskId
        Task ID (defaults to active task)
    #>
    param(
        [string]$TaskId = $null
    )
    
    $checkpointPath = Get-CheckpointPath -TaskId $TaskId
    if ($checkpointPath -and (Test-Path $checkpointPath)) {
        Remove-Item -Path $checkpointPath -Force -ErrorAction SilentlyContinue
    }
    
    $script:CurrentCheckpoint = $null
}

function Test-HasCheckpoint {
    <#
    .SYNOPSIS
        Checks if a checkpoint exists for a task
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Boolean - True if checkpoint exists
    #>
    param(
        [string]$TaskId = $null
    )
    
    $checkpointPath = Get-CheckpointPath -TaskId $TaskId
    return $checkpointPath -and (Test-Path $checkpointPath)
}

function Test-CanResumeFromCheckpoint {
    <#
    .SYNOPSIS
        Checks if session can be resumed from checkpoint
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Boolean - True if can resume
    #>
    param(
        [string]$TaskId = $null
    )
    
    $checkpoint = Get-Checkpoint -TaskId $TaskId
    if (-not $checkpoint) {
        return $false
    }
    
    # Check if checkpoint is in a resumable state
    if ($checkpoint.phase -eq 'complete') {
        return $false  # Already complete
    }
    
    if ($checkpoint.phase -eq 'error' -and -not $checkpoint.canResume) {
        return $false  # Error that can't be resumed from
    }
    
    return $true
}

# ═══════════════════════════════════════════════════════════════
#                     PHASE CHECKPOINTING
# ═══════════════════════════════════════════════════════════════

function Save-PhaseCheckpoint {
    <#
    .SYNOPSIS
        Saves a checkpoint at the start of a phase
    .PARAMETER Phase
        Phase being started
    .PARAMETER TaskId
        Task ID (defaults to active task)
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('idle', 'spec-creation', 'planning', 'building', 'complete', 'error')]
        [string]$Phase,
        
        [string]$TaskId = $null
    )
    
    # Get current completed tasks from plan file
    $completedTasks = @()
    if (Get-Command Get-AllTasks -ErrorAction SilentlyContinue) {
        # Get completed tasks from plan
        $completedTasks = Get-CompletedTasksFromPlan -TaskId $TaskId
    }
    
    $checkpoint = New-Checkpoint -Phase $Phase -CompletedTasks $completedTasks
    Save-Checkpoint -Checkpoint $checkpoint -TaskId $TaskId
}

function Save-IterationCheckpoint {
    <#
    .SYNOPSIS
        Saves a checkpoint AFTER a build iteration completes successfully
    .DESCRIPTION
        This should ONLY be called after a task has been successfully completed.
        The checkpoint represents the last known GOOD state - completed iterations only.
        Never call this before or during an AI call.
    .PARAMETER Iteration
        The iteration number that just COMPLETED (not starting)
    .PARAMETER CurrentTask
        The task that was just completed
    .PARAMETER TaskId
        Task ID (defaults to active task)
    #>
    param(
        [Parameter(Mandatory)]
        [int]$Iteration,
        
        [string]$CurrentTask = '',
        
        [string]$TaskId = $null
    )
    
    # Get completed tasks - this should include the task we just finished
    $completedTasks = Get-CompletedTasksFromPlan -TaskId $TaskId
    
    $checkpoint = New-Checkpoint `
        -Phase 'building' `
        -Iteration $Iteration `
        -CurrentTask $CurrentTask `
        -CompletedTasks $completedTasks
    
    # Mark this as a completed-state checkpoint
    $checkpoint.isCompletedState = $true
    
    Save-Checkpoint -Checkpoint $checkpoint -TaskId $TaskId
}

function Save-CompletionCheckpoint {
    <#
    .SYNOPSIS
        Saves a completion checkpoint and optionally clears it
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .PARAMETER KeepCheckpoint
        If true, keeps the checkpoint file; otherwise removes it
    #>
    param(
        [string]$TaskId = $null,
        
        [switch]$KeepCheckpoint
    )
    
    $completedTasks = Get-CompletedTasksFromPlan -TaskId $TaskId
    
    $checkpoint = New-Checkpoint `
        -Phase 'complete' `
        -CompletedTasks $completedTasks
    
    $checkpoint.canResume = $false
    
    Save-Checkpoint -Checkpoint $checkpoint -TaskId $TaskId
    
    if (-not $KeepCheckpoint) {
        Remove-Checkpoint -TaskId $TaskId
    }
}

# ═══════════════════════════════════════════════════════════════
#                     HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Get-CompletedTasksFromPlan {
    <#
    .SYNOPSIS
        Gets list of completed tasks from the plan file
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Array of completed task descriptions
    #>
    param(
        [string]$TaskId = $null
    )
    
    $completedTasks = @()
    
    # Get plan file path
    $planFile = $null
    if (Get-Command Get-TaskPlanFile -ErrorAction SilentlyContinue) {
        if (-not $TaskId) {
            if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
                $TaskId = Get-ActiveTaskId
            }
        }
        if ($TaskId) {
            $planFile = Get-TaskPlanFile -TaskId $TaskId
        }
    }
    
    if (-not $planFile -or -not (Test-Path $planFile)) {
        return $completedTasks
    }
    
    try {
        $content = Get-Content -Path $planFile
        foreach ($line in $content) {
            # Match checked checkbox: - [x] Task description
            if ($line -match '^\s*-\s*\[[xX]\]\s*(.+)$') {
                $completedTasks += $Matches[1].Trim()
            }
        }
    }
    catch {
        # Ignore errors reading plan file
    }
    
    return $completedTasks
}

function Get-CheckpointSummary {
    <#
    .SYNOPSIS
        Gets a human-readable summary of checkpoint state
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        String - Summary of checkpoint state
    #>
    param(
        [string]$TaskId = $null
    )
    
    $checkpoint = Get-Checkpoint -TaskId $TaskId
    if (-not $checkpoint) {
        return "No checkpoint"
    }
    
    $summary = "Phase: $(if ($checkpoint.ContainsKey('phase')) { $checkpoint.phase } else { 'unknown' })"
    
    if ($checkpoint.ContainsKey('iteration') -and $checkpoint.iteration -gt 0) {
        $summary += ", Iteration: $($checkpoint.iteration)"
    }
    
    if ($checkpoint.ContainsKey('completedTasks') -and $checkpoint.completedTasks -and $checkpoint.completedTasks.Count -gt 0) {
        $summary += ", Completed: $($checkpoint.completedTasks.Count) tasks"
    }
    
    if ($checkpoint.ContainsKey('error') -and $checkpoint.error) {
        $errorMsg = if ($checkpoint.error -is [hashtable] -and $checkpoint.error.ContainsKey('Message')) { $checkpoint.error.Message } elseif ($checkpoint.error.PSObject.Properties['Message']) { $checkpoint.error.Message } else { "$($checkpoint.error)" }
        $summary += " [ERROR: $errorMsg]"
    }
    
    return $summary
}

# ═══════════════════════════════════════════════════════════════
#                     CONFIGURATION
# ═══════════════════════════════════════════════════════════════

function Enable-Checkpointing {
    $script:CheckpointEnabled = $true
}

function Disable-Checkpointing {
    $script:CheckpointEnabled = $false
}

function Test-CheckpointingEnabled {
    return $script:CheckpointEnabled
}

# ═══════════════════════════════════════════════════════════════
#                     EXPORTS
# ═══════════════════════════════════════════════════════════════

function Get-Phases {
    return $script:Phases
}
