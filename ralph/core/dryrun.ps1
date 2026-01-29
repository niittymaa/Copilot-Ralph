<#
.SYNOPSIS
    Dry-run/preview module for Ralph Loop

.DESCRIPTION
    Provides dry-run functionality to preview what Ralph would do without:
    - Making any actual file changes
    - Spending any AI tokens
    - Executing any external commands
    
    This is a completely free way to test and understand how the system would work.

.NOTES
    This module provides:
    - Global dry-run state management
    - Mock functions for AI calls
    - Preview/summary generation
    - Integration with menu and execution systems
#>

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:DryRunMode = $false
$script:DryRunActions = @()
$script:DryRunStartTime = $null

# ═══════════════════════════════════════════════════════════════
#                     STATE MANAGEMENT
# ═══════════════════════════════════════════════════════════════

function Enable-DryRun {
    <#
    .SYNOPSIS
        Enables dry-run mode globally
    #>
    $script:DryRunMode = $true
    $script:DryRunActions = @()
    $script:DryRunStartTime = Get-Date
}

function Disable-DryRun {
    <#
    .SYNOPSIS
        Disables dry-run mode globally
    #>
    $script:DryRunMode = $false
    $script:DryRunActions = @()
    $script:DryRunStartTime = $null
}

function Test-DryRunEnabled {
    <#
    .SYNOPSIS
        Checks if dry-run mode is currently enabled
    .OUTPUTS
        Boolean - true if dry-run mode is active
    #>
    return $script:DryRunMode
}

function Add-DryRunAction {
    <#
    .SYNOPSIS
        Records an action that would be performed in real mode
    .PARAMETER Type
        Type of action (AI_Call, File_Write, File_Delete, Command, etc.)
    .PARAMETER Description
        Human-readable description of the action
    .PARAMETER Details
        Additional details about the action
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('AI_Call', 'File_Write', 'File_Delete', 'File_Read', 'Command', 'Menu', 'Task', 'Other')]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [hashtable]$Details = @{}
    )
    
    $action = @{
        Type        = $Type
        Description = $Description
        Details     = $Details
        Timestamp   = Get-Date
    }
    
    $script:DryRunActions += $action
}

function Get-DryRunActions {
    <#
    .SYNOPSIS
        Returns all recorded dry-run actions
    .OUTPUTS
        Array of action hashtables
    #>
    return $script:DryRunActions
}

function Clear-DryRunActions {
    <#
    .SYNOPSIS
        Clears all recorded dry-run actions
    #>
    $script:DryRunActions = @()
}

# ═══════════════════════════════════════════════════════════════
#                     DRY-RUN PROTECTION FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Show-DryRunBlocked {
    <#
    .SYNOPSIS
        Shows a message when an operation is blocked by dry-run mode
    .PARAMETER Operation
        The type of operation that was blocked
    .PARAMETER Description
        Description of what would have happened
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Operation,
        
        [string]$Description = ''
    )
    
    Write-Host ""
    Write-Host "  ⛔ [DRY RUN] $Operation blocked" -ForegroundColor Yellow
    if ($Description) {
        Write-Host "     Would: $Description" -ForegroundColor Gray
    }
    Write-Host ""
}

function Invoke-CopilotDryRun {
    <#
    .SYNOPSIS
        Mock version of Invoke-Copilot that doesn't make actual AI calls
    .DESCRIPTION
        Records what would be done and returns a simulated success response
        WITHOUT spending any AI tokens
    .PARAMETER Prompt
        The prompt that would be sent to Copilot
    .PARAMETER AllowAllTools
        Whether all tools would be allowed
    .PARAMETER SpinnerMessage
        Message that would be displayed
    .OUTPUTS
        Hashtable with simulated response
    #>
    param(
        [string]$Prompt,
        [switch]$AllowAllTools,
        [string]$SpinnerMessage = "Copilot is working..."
    )
    
    # Record this action
    Add-DryRunAction -Type 'AI_Call' -Description $SpinnerMessage -Details @{
        PromptLength   = $Prompt.Length
        AllowAllTools  = $AllowAllTools.IsPresent
        Model          = if ($script:Model) { $script:Model } else { 'default' }
        PromptPreview  = $Prompt.Substring(0, [Math]::Min(200, $Prompt.Length))
    }
    
    # Show blocked message
    Show-DryRunBlocked -Operation "AI Call" -Description "Send prompt to Copilot ($($Prompt.Length) chars)"
    
    # Simulate minimal delay
    Start-Sleep -Milliseconds 100
    
    # Return mock success response
    return @{
        Success  = $true
        Output   = "[DRY RUN] This is a simulated response. No actual AI call was made."
        Raw      = @("[DRY RUN] Simulated output")
        Duration = New-TimeSpan -Seconds 0.1
    }
}

function Test-CopilotCLIDryRun {
    <#
    .SYNOPSIS
        Mock version of Test-CopilotCLI that always succeeds in dry-run
    #>
    Add-DryRunAction -Type 'Other' -Description "Check Copilot CLI availability"
    return $true
}

function Get-NextTaskDryRun {
    <#
    .SYNOPSIS
        Mock version that simulates getting next task
    .PARAMETER PlanFile
        Path to the plan file
    .OUTPUTS
        Mock task or $null
    #>
    param(
        [string]$PlanFile
    )
    
    Add-DryRunAction -Type 'File_Read' -Description "Read next task from IMPLEMENTATION_PLAN.md" -Details @{
        File = $PlanFile
    }
    
    # If plan exists, simulate finding a task
    if ($PlanFile -and (Test-Path $PlanFile)) {
        $content = Get-Content $PlanFile -Raw
        $hasUnchecked = $content -match '- \[ \]'
        
        if ($hasUnchecked) {
            return "[DRY RUN] Simulated task from implementation plan"
        }
    } else {
        return "[DRY RUN] No plan file found - would need planning phase first"
    }
    
    return $null
}

function New-TaskDryRun {
    <#
    .SYNOPSIS
        Dry-run version of New-Task that logs instead of creating files
    .DESCRIPTION
        Allows full menu navigation but logs the intent instead of creating files
    .PARAMETER Name
        Human-readable task name
    .PARAMETER Description
        Optional description
    .OUTPUTS
        Hashtable with simulated task info
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Description = ''
    )
    
    # Generate simulated task ID
    $slug = ($Name -replace '[^a-zA-Z0-9]+', '-' -replace '^-|-$', '').ToLower()
    $date = Get-Date -Format 'yyyyMMdd-HHmmss'
    $taskId = "$slug-$date"
    
    # Record the action
    Add-DryRunAction -Type 'Task' -Description "Create session: $Name" -Details @{
        TaskId      = $taskId
        Name        = $Name
        Description = $Description
    }
    
    # Show blocked message
    Show-DryRunBlocked -Operation "Create Session" -Description "Create task '$Name' with ID '$taskId'"
    
    # Return simulated task info (used for menu flow continuity)
    return @{
        Id          = $taskId
        Name        = $Name
        Description = $Description
        Directory   = "[DRY RUN] Would be .ralph/tasks/$taskId"
        IsDryRun    = $true
    }
}

function Set-ActiveTaskDryRun {
    <#
    .SYNOPSIS
        Dry-run version of Set-ActiveTask
    .PARAMETER TaskId
        Task ID to activate
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TaskId
    )
    
    Add-DryRunAction -Type 'File_Write' -Description "Set active session: $TaskId" -Details @{
        TaskId = $TaskId
        File   = '.ralph/active-task'
    }
    
    Write-Host "  [DRY RUN] Would activate session: $TaskId" -ForegroundColor Yellow
}

function Remove-TaskDryRun {
    <#
    .SYNOPSIS
        Dry-run version of Remove-Task
    .PARAMETER TaskId
        Task ID to remove
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TaskId
    )
    
    Add-DryRunAction -Type 'File_Delete' -Description "Delete session: $TaskId" -Details @{
        TaskId    = $TaskId
        Directory = ".ralph/tasks/$TaskId"
    }
    
    Show-DryRunBlocked -Operation "Delete Session" -Description "Remove task '$TaskId' and all its files"
}

function Write-FileDryRun {
    <#
    .SYNOPSIS
        Dry-run version of file writing operations
    .PARAMETER Path
        Path to the file
    .PARAMETER Content
        Content that would be written
    .PARAMETER Description
        Description of the operation
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Content = '',
        
        [string]$Description = 'Write file'
    )
    
    Add-DryRunAction -Type 'File_Write' -Description $Description -Details @{
        Path          = $Path
        ContentLength = $Content.Length
        ContentPreview = if ($Content.Length -gt 100) { $Content.Substring(0, 100) + "..." } else { $Content }
    }
    
    Show-DryRunBlocked -Operation "File Write" -Description "Write to $Path ($($Content.Length) chars)"
}

# ═══════════════════════════════════════════════════════════════
#                     PREVIEW & SUMMARY
# ═══════════════════════════════════════════════════════════════

function Show-DryRunSummary {
    <#
    .SYNOPSIS
        Displays a comprehensive summary of what would happen in real mode
    #>
    $actions = Get-DryRunActions
    
    if ($actions.Count -eq 0) {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  DRY RUN SUMMARY" -ForegroundColor White
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  No actions recorded." -ForegroundColor Gray
        Write-Host ""
        return
    }
    
    # Group actions by type
    $grouped = $actions | Group-Object -Property Type
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  DRY RUN SUMMARY - PREVIEW OF OPERATIONS" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  🔍 Total Actions: $($actions.Count)" -ForegroundColor Yellow
    Write-Host ""
    
    # Duration
    if ($script:DryRunStartTime) {
        $duration = (Get-Date) - $script:DryRunStartTime
        Write-Host "  ⏱️  Duration: $([math]::Round($duration.TotalSeconds, 2))s (dry-run only)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Show breakdown by type
    foreach ($group in $grouped | Sort-Object Name) {
        $icon = switch ($group.Name) {
            'AI_Call'      { '🤖' }
            'File_Write'   { '📝' }
            'File_Delete'  { '🗑️' }
            'File_Read'    { '📖' }
            'Command'      { '⚙️' }
            'Menu'         { '📋' }
            'Task'         { '✅' }
            default        { '•' }
        }
        
        $color = switch ($group.Name) {
            'AI_Call'      { 'Magenta' }
            'File_Write'   { 'Yellow' }
            'File_Delete'  { 'Red' }
            'File_Read'    { 'Cyan' }
            'Command'      { 'Green' }
            'Menu'         { 'Blue' }
            'Task'         { 'Green' }
            default        { 'White' }
        }
        
        Write-Host "  $icon $($group.Name): $($group.Count)" -ForegroundColor $color
        
        # Show individual actions
        foreach ($action in $group.Group) {
            Write-Host "     • $($action.Description)" -ForegroundColor Gray
            
            # Show important details
            if ($action.Details -and $action.Details.Count -gt 0) {
                foreach ($key in $action.Details.Keys) {
                    $value = $action.Details[$key]
                    if ($value -and $key -in @('File', 'Model', 'PromptLength')) {
                        Write-Host "       - ${key}: $value" -ForegroundColor DarkGray
                    }
                }
            }
        }
        Write-Host ""
    }
    
    # AI calls summary
    $aiCalls = @($actions | Where-Object { $_.Type -eq 'AI_Call' })
    if ($aiCalls.Count -gt 0) {
        Write-Host "  💰 AI Token Usage: 0 (DRY RUN - NO TOKENS SPENT)" -ForegroundColor Green
        Write-Host "     In real mode, this would make $($aiCalls.Count) AI call(s)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # File operations summary
    $fileOps = @($actions | Where-Object { $_.Type -in @('File_Write', 'File_Delete') })
    if ($fileOps.Count -gt 0) {
        Write-Host "  📁 File Changes: 0 (DRY RUN - NO FILES MODIFIED)" -ForegroundColor Green
        Write-Host "     In real mode, this would affect $($fileOps.Count) file(s)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "  ℹ️  This was a dry-run preview only." -ForegroundColor Cyan
    Write-Host "     No actual changes were made to your system." -ForegroundColor Gray
    Write-Host ""
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                     MODULE EXPORT
# ═══════════════════════════════════════════════════════════════

# Note: This file is dot-sourced, not imported as a module
# Functions are automatically available in the calling scope
# No Export-ModuleMember needed
