<#
.SYNOPSIS
    Preset management module for Ralph Loop

.DESCRIPTION
    Provides functions to discover, load, and apply presets.
    Presets are pre-configured task templates for common operations like:
    - Code refactoring
    - Security hardening
    - Codebase cleanup
    - Documentation generation
    - Project analysis

.NOTES
    Presets are stored as .md files in ralph/presets/
    Each preset contains a description and task template that Ralph follows.
#>

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:PresetsDir = $null
$script:PresetsProjectRoot = $null

function Initialize-PresetPaths {
    <#
    .SYNOPSIS
        Initializes paths for preset operations
    .PARAMETER ProjectRoot
        Root directory of the project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    
    $script:PresetsProjectRoot = $ProjectRoot
    $ralphDir = Join-Path $ProjectRoot 'ralph'
    $script:PresetsDir = Join-Path $ralphDir 'presets'
}

# ═══════════════════════════════════════════════════════════════
#                      PRESET OPERATIONS
# ═══════════════════════════════════════════════════════════════

function Get-AllPresets {
    <#
    .SYNOPSIS
        Discovers all available presets
    .OUTPUTS
        Array of preset info hashtables
    #>
    $presets = @()
    
    if (-not (Test-Path $script:PresetsDir)) {
        return $presets
    }
    
    $presetFiles = Get-ChildItem -Path $script:PresetsDir -Filter '*.md' -ErrorAction SilentlyContinue
    
    foreach ($file in $presetFiles) {
        $preset = Read-PresetFile -Path $file.FullName
        if ($preset) {
            $presets += $preset
        }
    }
    
    # Sort by priority (if defined) then by name
    $presets = $presets | Sort-Object -Property @{Expression = {$_.Priority}; Ascending = $true}, @{Expression = {$_.Name}; Ascending = $true}
    
    return $presets
}

function Read-PresetFile {
    <#
    .SYNOPSIS
        Reads and parses a preset file
    .PARAMETER Path
        Full path to the preset file
    .OUTPUTS
        Hashtable with preset info or $null if invalid
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        return $null
    }
    
    $content = Get-Content $Path -Raw
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    
    # Parse YAML frontmatter if present
    $name = $fileName
    $description = ''
    $category = 'General'
    $priority = 100
    $tags = @()
    $body = $content
    
    if ($content -match '(?s)^---\s*\n(.*?)\n---\s*\n(.*)$') {
        $frontmatter = $Matches[1]
        $body = $Matches[2].Trim()
        
        # Parse frontmatter fields
        if ($frontmatter -match 'name:\s*[''"]?([^''"}\n]+)[''"]?') {
            $name = $Matches[1].Trim()
        }
        if ($frontmatter -match 'description:\s*[''"]?([^''"}\n]+)[''"]?') {
            $description = $Matches[1].Trim()
        }
        if ($frontmatter -match 'category:\s*[''"]?([^''"}\n]+)[''"]?') {
            $category = $Matches[1].Trim()
        }
        if ($frontmatter -match 'priority:\s*(\d+)') {
            $priority = [int]$Matches[1]
        }
        if ($frontmatter -match 'tags:\s*\[([^\]]+)\]') {
            $tags = ($Matches[1] -split ',') | ForEach-Object { $_.Trim().Trim('"').Trim("'") }
        }
    }
    
    return @{
        Id          = $fileName
        Name        = $name
        Description = $description
        Category    = $category
        Priority    = $priority
        Tags        = $tags
        Body        = $body
        Path        = $Path
    }
}

function Get-PresetById {
    <#
    .SYNOPSIS
        Gets a specific preset by ID
    .PARAMETER PresetId
        Preset ID (filename without extension)
    .OUTPUTS
        Preset hashtable or $null
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PresetId
    )
    
    $presetPath = Join-Path $script:PresetsDir "$PresetId.md"
    
    if (-not (Test-Path $presetPath)) {
        return $null
    }
    
    return Read-PresetFile -Path $presetPath
}

function Show-PresetsMenu {
    <#
    .SYNOPSIS
        Interactive menu for selecting a preset
        Uses the new menu system with back navigation
    .OUTPUTS
        Selected preset ID or $null if cancelled
    #>
    Clear-Host
    
    $presets = @(Get-AllPresets)
    
    if ($presets.Count -eq 0) {
        Write-Host ""
        Write-Host "  No presets found in ralph/presets/" -ForegroundColor Yellow
        Write-Host "  Create .md files in that folder to add presets." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [Enter] Return to menu" -ForegroundColor Gray
        Read-Host | Out-Null
        return $null
    }
    
    # Build dynamic menu items grouped by category
    $items = @()
    $indexMap = @{}
    
    # Group by category
    $categories = $presets | Group-Object -Property Category | Sort-Object Name
    
    $index = 1
    foreach ($categoryGroup in $categories) {
        # Add category header as a separator with label
        $items += @{
            Key         = ''
            Label       = "─── $($categoryGroup.Name) ───"
            Action      = ''
            Description = ''
            Color       = 'Yellow'
            Separator   = $false
            Condition   = $null
            Submenu     = $null
            Disabled    = $true
        }
        
        foreach ($preset in $categoryGroup.Group) {
            $indexMap[$index] = $preset.Id
            $tagText = if ($preset.Tags.Count -gt 0) { " [$($preset.Tags -join ', ')]" } else { "" }
            
            $items += New-RalphMenuItem -Key "$index" -Label "$($preset.Name)$tagText" -Action 'select_preset' -Description $preset.Description -Color 'Cyan'
            $index++
        }
    }
    
    $menu = New-DynamicMenu -Id 'presets' -Title 'RALPH - PRESET SELECTION' -Items $items -Description 'Select a preset to apply to your session' -Color 'Cyan' -ShowBack $true
    
    $result = Show-Menu -Menu $menu
    
    switch ($result.Action) {
        'select_preset' {
            $selectedIndex = [int]$result.Key
            if ($indexMap.ContainsKey($selectedIndex)) {
                return $indexMap[$selectedIndex]
            }
            return $null
        }
        'select' {
            if ($indexMap.ContainsKey($result.Index)) {
                return $indexMap[$result.Index]
            }
            return $null
        }
        'quit' { return $null }
        'back' { return $null }
        default { return $null }
    }
}

function Apply-Preset {
    <#
    .SYNOPSIS
        Applies a preset to a task session
    .DESCRIPTION
        Creates or updates the task's spec file with preset content
    .PARAMETER PresetId
        Preset ID to apply
    .PARAMETER TaskSpecsDir
        Task's specs directory
    .PARAMETER TaskName
        Name of the task (for spec file naming)
    .OUTPUTS
        $true if successful, $false otherwise
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PresetId,
        
        [Parameter(Mandatory)]
        [string]$TaskSpecsDir,
        
        [string]$TaskName = 'preset-task'
    )
    
    $preset = Get-PresetById -PresetId $PresetId
    
    if (-not $preset) {
        Write-Host "  Preset '$PresetId' not found" -ForegroundColor Red
        return $false
    }
    
    # Ensure specs directory exists
    if (-not (Test-Path $TaskSpecsDir)) {
        New-Item -ItemType Directory -Path $TaskSpecsDir -Force | Out-Null
    }
    
    # Create spec file from preset
    $specFileName = "$($preset.Id)-spec.md"
    $specPath = Join-Path $TaskSpecsDir $specFileName
    
    # Generate spec content from preset
    $specContent = @"
# $($preset.Name)

## Overview

$($preset.Description)

## Requirements

$($preset.Body)

---
Generated from preset: $($preset.Id)
Applied: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    $specContent | Set-Content $specPath -Encoding UTF8
    
    Write-Host "  ✓ Applied preset: $($preset.Name)" -ForegroundColor Green
    Write-Host "    Created: $specFileName" -ForegroundColor Gray
    
    return $true
}

function New-TaskFromPreset {
    <#
    .SYNOPSIS
        Creates a new task session from a preset
    .DESCRIPTION
        Combines task creation with preset application
    .PARAMETER PresetId
        Preset ID to use
    .PARAMETER TaskName
        Optional task name (defaults to preset name)
    .OUTPUTS
        Task info hashtable or $null if failed
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PresetId,
        
        [string]$TaskName = ''
    )
    
    $preset = Get-PresetById -PresetId $PresetId
    
    if (-not $preset) {
        Write-Host "  Preset '$PresetId' not found" -ForegroundColor Red
        return $null
    }
    
    # Use preset name if task name not provided
    if (-not $TaskName) {
        $TaskName = $preset.Name
    }
    
    # Create the task (requires tasks.ps1 to be loaded)
    # New-Task is dry-run protected - will return simulated task in dry-run mode
    $task = New-Task -Name $TaskName -Description $preset.Description
    
    if (-not $task) {
        Write-Host "  Failed to create task" -ForegroundColor Red
        return $null
    }
    
    # Check if this is a dry-run result
    $isDryRun = $task.IsDryRun -eq $true
    
    if ($isDryRun) {
        # In dry-run mode, record the preset application action
        if (Get-Command Add-DryRunAction -ErrorAction SilentlyContinue) {
            $presetContent = if ($preset.Path -and (Test-Path $preset.Path)) { Get-Content $preset.Path -Raw } else { "" }
            $contentPreview = if ($presetContent.Length -gt 200) { $presetContent.Substring(0, 200) } else { $presetContent }
            Add-DryRunAction -Type 'File_Write' -Description "Apply preset: $PresetId to session $($task.Id)" -Details @{
                Preset      = $PresetId
                PresetName  = $preset.Name
                TaskId      = $task.Id
                SpecContent = $contentPreview
            }
        }
        Write-Host "  [DRY RUN] Would apply preset '$($preset.Name)' to session" -ForegroundColor Yellow
    } else {
        # Apply the preset to the task
        $specsDir = Join-Path $task.Directory 'specs'
        $applied = Apply-Preset -PresetId $PresetId -TaskSpecsDir $specsDir -TaskName $TaskName
        
        if (-not $applied) {
            Write-Host "  Warning: Task created but preset application failed" -ForegroundColor Yellow
        }
        
        # Set this as the active task
        Set-ActiveTask -TaskId $task.Id
    }
    
    return $task
}
