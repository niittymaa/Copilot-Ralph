<#
.SYNOPSIS
    Task management module for Ralph Loop multi-task support

.DESCRIPTION
    Provides functions to create, switch, list, and manage isolated task contexts.
    Each task has its own:
    - specs/ folder (in ralph/specs/ for shared, or task-specific)
    - IMPLEMENTATION_PLAN.md
    - progress.txt
    
    All tasks are stored in .ralph/tasks/<task-id>/

.NOTES
    Task ID format: <name>-<timestamp> (e.g., "auth-feature-20260115-123456")
    Active task is tracked in .ralph/active-task
#>

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# Note: Clear-HostConditional is defined in display.ps1 which must be loaded before this module

function Initialize-TaskPaths {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    
    $script:TasksRoot = Join-Path $ProjectRoot '.ralph\tasks'
    $script:ActiveTaskFile = Join-Path $ProjectRoot '.ralph\active-task'
    $script:GlobalSpecsDir = Join-Path $ProjectRoot 'ralph\specs'
    $script:GlobalReferencesDir = Join-Path $ProjectRoot 'ralph\references'
    $script:SharedSpecsDir = $script:GlobalSpecsDir  # Alias for backward compatibility
    $script:ProjectRoot = $ProjectRoot
}

# ═══════════════════════════════════════════════════════════════
#                     GLOBAL FOLDER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Get-GlobalSpecsFolder {
    <#
    .SYNOPSIS
        Gets the global specs folder path (ralph/specs/)
    .OUTPUTS
        String - Path to global specs folder
    #>
    return $script:GlobalSpecsDir
}

function Get-GlobalReferencesFolder {
    <#
    .SYNOPSIS
        Gets the global references folder path (ralph/references/)
    .OUTPUTS
        String - Path to global references folder
    #>
    return $script:GlobalReferencesDir
}

function Get-SessionSpecsFolder {
    <#
    .SYNOPSIS
        Gets the session-specific specs folder path
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        String - Path to session specs folder
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    if (-not $TaskId) {
        return $null
    }
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    return Join-Path $taskDir 'session-specs'
}

function Get-SessionReferencesFolder {
    <#
    .SYNOPSIS
        Gets the session-specific references folder path
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        String - Path to session references folder
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    if (-not $TaskId) {
        return $null
    }
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    return Join-Path $taskDir 'session-references'
}

# ═══════════════════════════════════════════════════════════════
#                      TASK OPERATIONS
# ═══════════════════════════════════════════════════════════════

function Get-ActiveTaskId {
    <#
    .SYNOPSIS
        Gets the currently active task ID
    .OUTPUTS
        String - Task ID or $null if no task is active
    #>
    if (Test-Path $script:ActiveTaskFile) {
        $taskId = (Get-Content $script:ActiveTaskFile -Raw).Trim()
        if ($taskId -and (Test-TaskExists -TaskId $taskId)) {
            return $taskId
        }
    }
    return $null
}

function Set-ActiveTask {
    <#
    .SYNOPSIS
        Sets the active task
    .PARAMETER TaskId
        Task ID to activate
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TaskId
    )
    
    # DRY-RUN MODE: Use mock function
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        Set-ActiveTaskDryRun -TaskId $TaskId
        return
    }
    
    if (-not (Test-TaskExists -TaskId $TaskId)) {
        throw "Task '$TaskId' does not exist"
    }
    
    # Ensure .ralph directory exists
    $ralphDir = Split-Path $script:ActiveTaskFile -Parent
    if (-not (Test-Path $ralphDir)) {
        New-Item -ItemType Directory -Path $ralphDir -Force | Out-Null
    }
    
    $TaskId | Set-Content $script:ActiveTaskFile -NoNewline
}

function Test-TaskExists {
    <#
    .SYNOPSIS
        Checks if a task exists
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TaskId
    )
    
    # In dry-run mode, also check if this is a simulated task
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        # Check real tasks first
        $taskDir = Get-TaskDirectory -TaskId $TaskId
        if (Test-Path $taskDir) {
            return $true
        }
        # In dry-run, simulated tasks are considered to exist for menu navigation
        return $false
    }
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    return (Test-Path $taskDir)
}

function Get-TaskDirectory {
    <#
    .SYNOPSIS
        Gets the directory path for a task
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TaskId
    )
    
    return Join-Path $script:TasksRoot $TaskId
}

function Get-TaskPlanFile {
    <#
    .SYNOPSIS
        Gets the IMPLEMENTATION_PLAN.md path for a task
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    if (-not $TaskId) {
        return $null
    }
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    return Join-Path $taskDir 'IMPLEMENTATION_PLAN.md'
}

function Get-TaskProgressFile {
    <#
    .SYNOPSIS
        Gets the progress.txt path for a task
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    if (-not $TaskId) {
        return $null
    }
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    return Join-Path $taskDir 'progress.txt'
}

function Get-TaskSpecsDir {
    <#
    .SYNOPSIS
        Gets the specs directory for a task
    .DESCRIPTION
        Delegates to Get-TaskSpecsFolder for consistent behavior.
        Returns the appropriate specs folder based on specsSource config:
        - 'session' = session-based (.ralph/tasks/{id}/session-specs/)
        - 'global' = global folder (ralph/specs/)
        - 'custom' = custom folder path
        - 'none' = returns $null
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    if (-not $TaskId) {
        return $script:GlobalSpecsDir
    }
    
    # Use Get-TaskSpecsFolder for consistent logic
    return Get-TaskSpecsFolder -TaskId $TaskId
}

function New-Task {
    <#
    .SYNOPSIS
        Creates a new task with isolated context
    .PARAMETER Name
        Human-readable task name (will be slugified)
    .PARAMETER Description
        Optional description of the task
    .OUTPUTS
        Hashtable with task info
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Description = ''
    )
    
    # DRY-RUN MODE: Use mock function
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        return New-TaskDryRun -Name $Name -Description $Description
    }
    
    # Generate task ID: slugified name + date
    $slug = ($Name -replace '[^a-zA-Z0-9]+', '-' -replace '^-|-$', '').ToLower()
    $date = Get-Date -Format 'yyyyMMdd-HHmmss'
    $taskId = "$slug-$date"
    
    # Create task directory
    $taskDir = Join-Path $script:TasksRoot $taskId
    if (Test-Path $taskDir) {
        throw "Task directory already exists: $taskDir"
    }
    
    New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
    
    # Create task config with new folder structure
    $config = @{
        id          = $taskId
        name        = $Name
        description = $Description
        created     = (Get-Date).ToString('o')
        status      = 'active'
        # Specs configuration
        specsSource = 'session'  # 'session', 'global', 'custom', or 'none'
        specsFolder = ''         # Custom folder path (if specsSource is 'custom')
        # References configuration
        referencesSource = 'session'  # 'session', 'global', 'custom', or 'none'
        referencesFolder = ''    # Custom folder path (if referencesSource is 'custom')
        referencesEnabled = $true  # Whether references are active for building
        # Legacy: individual files (still supported for custom additions)
        referenceDirectories = @()
        referenceFiles = @()
    }
    $config | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $taskDir 'task.json') -Encoding UTF8
    
    # Create IMPLEMENTATION_PLAN.md
    @"
# Implementation Plan

## Task: $Name

$Description

## Overview

Run ``./ralph.ps1`` to auto-generate tasks from specs and start building.

## Tasks

(Tasks will be generated from specs - run planning phase first)

## Completed

(Completed tasks are marked with [x])
"@ | Set-Content (Join-Path $taskDir 'IMPLEMENTATION_PLAN.md') -Encoding UTF8
    
    # Create progress.txt
    @"
# Ralph Progress Log - $Name

## Codebase Patterns
(Add reusable patterns here)

---
Task created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Set-Content (Join-Path $taskDir 'progress.txt') -Encoding UTF8
    
    # Create session-specs and session-references directories
    $sessionSpecsDir = Join-Path $taskDir 'session-specs'
    $sessionRefsDir = Join-Path $taskDir 'session-references'
    New-Item -ItemType Directory -Path $sessionSpecsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $sessionRefsDir -Force | Out-Null
    
    # Copy template if exists
    $templateFile = Join-Path $script:ProjectRoot 'ralph\specs\_example.template.md'
    if (Test-Path $templateFile) {
        Copy-Item $templateFile (Join-Path $sessionSpecsDir '_example.template.md')
    }
    
    return @{
        Id          = $taskId
        Name        = $Name
        Description = $Description
        Directory   = $taskDir
        IsDryRun    = $false
    }
}

function Get-AllTasks {
    <#
    .SYNOPSIS
        Lists all tasks
    .OUTPUTS
        Array of task info hashtables
    #>
    $tasks = @()
    $activeId = Get-ActiveTaskId
    
    # Add all tasks from .ralph/tasks/
    if (Test-Path $script:TasksRoot) {
        $taskDirs = Get-ChildItem -Path $script:TasksRoot -Directory -ErrorAction SilentlyContinue
        
        foreach ($dir in $taskDirs) {
            $configFile = Join-Path $dir.FullName 'task.json'
            if (Test-Path $configFile) {
                $config = Get-Content $configFile -Raw | ConvertFrom-Json
                $planFile = Join-Path $dir.FullName 'IMPLEMENTATION_PLAN.md'
                $stats = Get-TaskStatsFromFile -PlanFile $planFile
                
                $tasks += @{
                    Id          = $config.id
                    Name        = $config.name
                    Description = $config.description
                    Directory   = $dir.FullName
                    Status      = $config.status
                    Created     = $config.created
                    Stats       = $stats
                    IsActive    = ($activeId -eq $config.id)
                }
            }
        }
    }
    
    return $tasks
}

function Get-TaskStatsFromFile {
    <#
    .SYNOPSIS
        Gets task statistics from a plan file
    #>
    param(
        [string]$PlanFile
    )
    
    if (-not (Test-Path $PlanFile)) {
        return @{ Total = 0; Completed = 0; Pending = 0 }
    }
    
    $content = Get-Content $PlanFile -Raw
    $pending = ([regex]::Matches($content, '- \[ \]')).Count
    $completed = ([regex]::Matches($content, '- \[x\]')).Count
    
    return @{
        Total     = $pending + $completed
        Completed = $completed
        Pending   = $pending
    }
}

function Remove-Task {
    <#
    .SYNOPSIS
        Removes a task and its data
    .PARAMETER TaskId
        Task ID to remove
    .PARAMETER Force
        Skip confirmation
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TaskId,
        
        [switch]$Force
    )
    
    # DRY-RUN MODE: Use mock function
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        Remove-TaskDryRun -TaskId $TaskId
        return
    }
    
    if (-not (Test-TaskExists -TaskId $TaskId)) {
        throw "Task '$TaskId' does not exist"
    }
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    
    # If this is the active task, clear the active task
    if ((Get-ActiveTaskId) -eq $TaskId) {
        if (Test-Path $script:ActiveTaskFile) {
            Remove-Item $script:ActiveTaskFile -Force
        }
    }
    
    # Remove task directory
    Remove-Item -Path $taskDir -Recurse -Force
}

function New-TaskInteractive {
    <#
    .SYNOPSIS
        Interactive session creation wizard with arrow navigation
    .OUTPUTS
        New session info, $null if cancelled, or @{Action='back'} if ESC pressed
    #>
    
    # Clear screen before showing the form
    Clear-HostConditional
    
    # Show dry-run indicator
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "  🔍 DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
    }
    
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  CREATE NEW SESSION" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Press [ESC] to go back" -ForegroundColor DarkGray
    
    # Session name input
    $nameInput = Show-ArrowTextInput -Prompt "Session name (e.g., 'Todo App', 'API Refactor')" -Required -AllowBack
    if ($nameInput.Type -eq 'back') {
        return @{ Action = 'back' }
    }
    $name = $nameInput.Value
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Host "  Cancelled - name is required" -ForegroundColor Yellow
        return $null
    }
    
    # Description input
    $descInput = Show-ArrowTextInput -Prompt "Description (optional)" -AllowBack
    if ($descInput.Type -eq 'back') {
        return @{ Action = 'back' }
    }
    $description = $descInput.Value
    
    # Sessions now auto-create with session specs - no mode selection needed
    
    Write-Host ""
    Write-Host "  Creating session..." -ForegroundColor Gray
    
    try {
        $task = New-Task -Name $name -Description $description
        
        # Check if this was a dry-run
        $isDryRun = $task.IsDryRun -eq $true
        
        Write-Host ""
        if ($isDryRun) {
            Write-Host "  [DRY RUN] Would create session: $($task.Id)" -ForegroundColor Yellow
            Write-Host "    Would create directory: $($task.Directory)" -ForegroundColor Gray
        } else {
            Write-Host "  ✓ Session created: $($task.Id)" -ForegroundColor Green
            Write-Host "    Directory: $($task.Directory)" -ForegroundColor Gray
        }
        Write-Host ""
        
        # Activation confirmation with arrow navigation
        $activate = Show-ArrowConfirm -Message "Activate this session now?" -DefaultYes
        
        if ($activate) {
            Set-ActiveTask -TaskId $task.Id
            if ($isDryRun) {
                Write-Host "  [DRY RUN] Would activate session" -ForegroundColor Yellow
            } else {
                Write-Host "  ✓ Session activated" -ForegroundColor Green
            }
        } else {
            Write-Host "  Session not activated" -ForegroundColor Yellow
        }
        
        return $task
    } catch {
        Write-Host "  ✗ Failed to create session: $_" -ForegroundColor Red
        return $null
    }
}

# ═══════════════════════════════════════════════════════════════
#                     INITIALIZATION
# ═══════════════════════════════════════════════════════════════

function Initialize-TaskSystem {
    <#
    .SYNOPSIS
        Ensures the task system directories exist
    #>
    # Ensure .ralph directory exists
    $ralphDir = Join-Path $script:ProjectRoot '.ralph'
    if (-not (Test-Path $ralphDir)) {
        New-Item -ItemType Directory -Path $ralphDir -Force | Out-Null
    }
    
    # Ensure tasks directory exists
    if (-not (Test-Path $script:TasksRoot)) {
        New-Item -ItemType Directory -Path $script:TasksRoot -Force | Out-Null
    }
}

# ═══════════════════════════════════════════════════════════════
#                     SPECS CONFIGURATION
# ═══════════════════════════════════════════════════════════════

function Get-TaskConfig {
    <#
    .SYNOPSIS
        Gets the task configuration for a task
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Hashtable with task config or $null
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    if (-not $TaskId) {
        return $null
    }
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    $configFile = Join-Path $taskDir 'task.json'
    
    if (-not (Test-Path $configFile)) {
        return $null
    }
    
    try {
        return Get-Content $configFile -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        return $null
    }
}

function Set-TaskConfig {
    <#
    .SYNOPSIS
        Saves task configuration
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .PARAMETER Config
        Configuration hashtable to save
    #>
    param(
        [string]$TaskId = $null,
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    if (-not $TaskId) {
        throw "No active task to save configuration"
    }
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    $configFile = Join-Path $taskDir 'task.json'
    
    $Config | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
}

function Get-TaskSpecsConfig {
    <#
    .SYNOPSIS
        Gets the specs configuration for a task
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Hashtable with specsSource, specsFolder
    .NOTES
        specsSource values:
        - 'session' = session-based (.ralph/tasks/{id}/session-specs/)
        - 'global' = global folder (ralph/specs/)
        - 'custom' = custom folder path (specsFolder)
        - 'none' = no specs configured
    #>
    param(
        [string]$TaskId = $null
    )
    
    $config = Get-TaskConfig -TaskId $TaskId
    
    if (-not $config) {
        return @{
            specsSource = 'session'
            specsFolder = ''
        }
    }
    
    # Handle missing properties for backwards compatibility
    $source = 'session'
    $folder = ''
    
    if ($config -is [hashtable]) {
        if ($config.ContainsKey('specsSource')) { 
            $source = $config.specsSource
            # Migrate old values to new ones
            if ($source -eq 'default') { $source = 'session' }
            if ($source -eq 'shared') { $source = 'global' }
        }
        if ($config.ContainsKey('specsFolder')) { $folder = $config.specsFolder }
    } else {
        if ($null -ne $config.PSObject.Properties['specsSource']) { 
            $source = $config.specsSource
            if ($source -eq 'default') { $source = 'session' }
            if ($source -eq 'shared') { $source = 'global' }
        }
        if ($null -ne $config.PSObject.Properties['specsFolder']) { $folder = $config.specsFolder }
    }
    
    return @{
        specsSource = $source
        specsFolder = $folder
    }
}

function Set-TaskSpecsConfig {
    <#
    .SYNOPSIS
        Sets the specs configuration for a task
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .PARAMETER SpecsSource
        Source type: 'session', 'global', 'custom', or 'none'
    .PARAMETER SpecsFolder
        Custom folder path (only used if SpecsSource is 'custom')
    #>
    param(
        [string]$TaskId = $null,
        
        [ValidateSet('session', 'global', 'custom', 'none')]
        [string]$SpecsSource = 'session',
        
        [string]$SpecsFolder = ''
    )
    
    $config = Get-TaskConfig -TaskId $TaskId
    
    if (-not $config) {
        throw "Task not found"
    }
    
    # Convert to hashtable if needed
    if ($config -isnot [hashtable]) {
        $configHash = @{}
        $config.PSObject.Properties | ForEach-Object { $configHash[$_.Name] = $_.Value }
        $config = $configHash
    }
    
    $config.specsSource = $SpecsSource
    $config.specsFolder = $SpecsFolder
    
    Set-TaskConfig -TaskId $TaskId -Config $config
}

function Get-TaskReferencesConfig {
    <#
    .SYNOPSIS
        Gets the references configuration for a task
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        Hashtable with referencesSource, referencesFolder, referencesEnabled, referenceDirectories, referenceFiles
    .NOTES
        referencesSource values:
        - 'session' = session-based (.ralph/tasks/{id}/session-references/)
        - 'global' = global folder (ralph/references/)
        - 'custom' = custom folder path
        - 'none' = no references configured
    #>
    param(
        [string]$TaskId = $null
    )
    
    $config = Get-TaskConfig -TaskId $TaskId
    
    if (-not $config) {
        return @{
            referencesSource = 'session'
            referencesFolder = ''
            referencesEnabled = $true
            referenceDirectories = @()
            referenceFiles = @()
        }
    }
    
    # Extract values with defaults
    $source = 'session'
    $folder = ''
    $enabled = $true
    $dirs = @()
    $files = @()
    
    if ($config -is [hashtable]) {
        if ($config.ContainsKey('referencesSource')) { $source = $config.referencesSource }
        if ($config.ContainsKey('referencesFolder')) { $folder = $config.referencesFolder }
        if ($config.ContainsKey('referencesEnabled')) { $enabled = $config.referencesEnabled }
        if ($config.ContainsKey('referenceDirectories') -and $config.referenceDirectories) { $dirs = @($config.referenceDirectories) }
        if ($config.ContainsKey('referenceFiles') -and $config.referenceFiles) { $files = @($config.referenceFiles) }
    } else {
        if ($null -ne $config.PSObject.Properties['referencesSource']) { $source = $config.referencesSource }
        if ($null -ne $config.PSObject.Properties['referencesFolder']) { $folder = $config.referencesFolder }
        if ($null -ne $config.PSObject.Properties['referencesEnabled']) { $enabled = $config.referencesEnabled }
        if ($null -ne $config.PSObject.Properties['referenceDirectories'] -and $config.referenceDirectories) { $dirs = @($config.referenceDirectories) }
        if ($null -ne $config.PSObject.Properties['referenceFiles'] -and $config.referenceFiles) { $files = @($config.referenceFiles) }
    }
    
    return @{
        referencesSource = $source
        referencesFolder = $folder
        referencesEnabled = $enabled
        referenceDirectories = $dirs
        referenceFiles = $files
    }
}

function Set-TaskReferencesConfig {
    <#
    .SYNOPSIS
        Sets the references configuration for a task
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .PARAMETER ReferencesSource
        Source type: 'session', 'global', 'custom', or 'none'
    .PARAMETER ReferencesFolder
        Custom folder path (only used if ReferencesSource is 'custom')
    .PARAMETER ReferencesEnabled
        Whether references are active for building
    .PARAMETER ReferenceDirectories
        Array of additional reference directory paths
    .PARAMETER ReferenceFiles
        Array of individual reference file paths
    #>
    param(
        [string]$TaskId = $null,
        
        [ValidateSet('session', 'global', 'custom', 'none')]
        [string]$ReferencesSource = $null,
        
        [string]$ReferencesFolder = $null,
        
        [System.Nullable[bool]]$ReferencesEnabled = $null,
        
        [array]$ReferenceDirectories = $null,
        
        [array]$ReferenceFiles = $null
    )
    
    $config = Get-TaskConfig -TaskId $TaskId
    
    if (-not $config) {
        throw "Task not found"
    }
    
    # Convert to hashtable if needed
    if ($config -isnot [hashtable]) {
        $configHash = @{}
        $config.PSObject.Properties | ForEach-Object { $configHash[$_.Name] = $_.Value }
        $config = $configHash
    }
    
    # Only update provided parameters
    if ($null -ne $ReferencesSource) { $config.referencesSource = $ReferencesSource }
    if ($null -ne $ReferencesFolder) { $config.referencesFolder = $ReferencesFolder }
    if ($null -ne $ReferencesEnabled) { $config.referencesEnabled = $ReferencesEnabled }
    if ($null -ne $ReferenceDirectories) { $config.referenceDirectories = $ReferenceDirectories }
    if ($null -ne $ReferenceFiles) { $config.referenceFiles = $ReferenceFiles }
    
    Set-TaskConfig -TaskId $TaskId -Config $config
}

function Get-TaskReferencesFolder {
    <#
    .SYNOPSIS
        Gets the effective references folder for a task based on its configuration
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        String - Path to references folder, or $null if none
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    $refsConfig = Get-TaskReferencesConfig -TaskId $TaskId
    
    switch ($refsConfig.referencesSource) {
        'global' {
            return $script:GlobalReferencesDir
        }
        'custom' {
            if ($refsConfig.referencesFolder -and (Test-Path $refsConfig.referencesFolder)) {
                return $refsConfig.referencesFolder
            }
            # Fall back to session folder if custom doesn't exist
            return Get-SessionReferencesFolder -TaskId $TaskId
        }
        'none' {
            return $null
        }
        default {
            # 'session' - use session-references folder
            return Get-SessionReferencesFolder -TaskId $TaskId
        }
    }
}

function Get-TaskSpecsFolder {
    <#
    .SYNOPSIS
        Gets the effective specs folder for a task based on its configuration
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        String - Path to specs folder
    .NOTES
        specsSource values:
        - 'session' = session-based (.ralph/tasks/{id}/session-specs/)
        - 'global' = global folder (ralph/specs/)
        - 'custom' = custom folder path
        - 'none' = no specs configured
    #>
    param(
        [string]$TaskId = $null
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    $specsConfig = Get-TaskSpecsConfig -TaskId $TaskId
    
    switch ($specsConfig.specsSource) {
        'global' {
            return $script:GlobalSpecsDir
        }
        'custom' {
            if ($specsConfig.specsFolder -and (Test-Path $specsConfig.specsFolder)) {
                return $specsConfig.specsFolder
            }
            # Fall back to session folder if custom doesn't exist
            return Get-SessionSpecsFolder -TaskId $TaskId
        }
        'none' {
            return $null
        }
        default {
            # 'session' - use session-specs folder
            return Get-SessionSpecsFolder -TaskId $TaskId
        }
    }
}

function Get-TaskSpecsSummary {
    <#
    .SYNOPSIS
        Gets a summary of specs configuration for display
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        String - Human-readable summary
    #>
    param(
        [string]$TaskId = $null
    )
    
    $specsConfig = Get-TaskSpecsConfig -TaskId $TaskId
    $specsFolder = Get-TaskSpecsFolder -TaskId $TaskId
    
    if ($specsConfig.specsSource -eq 'none' -or -not $specsFolder) {
        return "Not configured"
    }
    
    if (-not (Test-Path $specsFolder)) {
        return "Folder not found"
    }
    
    # Count spec files (non-template .md files)
    $specFiles = @(Get-ChildItem -Path $specsFolder -Filter "*.md" -ErrorAction SilentlyContinue | 
                   Where-Object { -not $_.Name.StartsWith('_') })
    
    $count = $specFiles.Count
    
    if ($count -eq 0) {
        return "No specs"
    } elseif ($count -eq 1) {
        return "1 spec"
    } else {
        return "$count specs"
    }
}

function Get-TaskReferencesSummary {
    <#
    .SYNOPSIS
        Gets a summary of references configuration for display
    .PARAMETER TaskId
        Task ID (defaults to active task)
    .OUTPUTS
        String - Human-readable summary
    #>
    param(
        [string]$TaskId = $null
    )
    
    $refsConfig = Get-TaskReferencesConfig -TaskId $TaskId
    $refsFolder = Get-TaskReferencesFolder -TaskId $TaskId
    
    if ($refsConfig.referencesSource -eq 'none' -or -not $refsFolder) {
        return "Disabled"
    }
    
    if (-not (Test-Path $refsFolder)) {
        return "Folder not found"
    }
    
    # Count reference files
    $allFiles = @(Get-ChildItem -Path $refsFolder -File -ErrorAction SilentlyContinue | 
                  Where-Object { -not $_.Name.StartsWith('_') })
    
    $count = $allFiles.Count
    $enabledStr = if ($refsConfig.referencesEnabled) { "" } else { " (disabled)" }
    
    if ($count -eq 0) {
        return "No files$enabledStr"
    } elseif ($count -eq 1) {
        return "1 file$enabledStr"
    } else {
        return "$count files$enabledStr"
    }
}
