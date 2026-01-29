<#
.SYNOPSIS
    Cross-session memory system for Ralph Loop

.DESCRIPTION
    Provides persistent memory storage that accumulates learnings across all sessions.
    Memory entries are stored in .ralph/memory.md and can be toggled ON/OFF via CLI.
    
    Memory types:
    - patterns: Code patterns and conventions discovered
    - commands: Build/test/lint commands that work
    - gotchas: Common pitfalls and how to avoid them
    - decisions: Architectural decisions and rationale

.NOTES
    Memory file: .ralph/memory.md
    Settings file: .ralph/settings.json
#>

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:Memory_MemoryFile = $null
$script:Memory_SettingsFile = $null
$script:Memory_ProjectRoot = $null
$script:Memory_MemoryEnabled = $true

function Initialize-MemorySystem {
    <#
    .SYNOPSIS
        Initializes the memory system paths and loads settings
    .PARAMETER ProjectRoot
        Root directory of the project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    
    $script:Memory_ProjectRoot = $ProjectRoot
    $ralphDir = Join-Path $ProjectRoot '.ralph'
    $script:Memory_MemoryFile = Join-Path $ralphDir 'memory.md'
    $script:Memory_SettingsFile = Join-Path $ralphDir 'settings.json'
    
    # Ensure .ralph directory exists
    if (-not (Test-Path $ralphDir)) {
        New-Item -ItemType Directory -Path $ralphDir -Force | Out-Null
    }
    
    # Load settings
    $script:Memory_MemoryEnabled = Get-MemorySetting
    
    # Create memory file if it doesn't exist and memory is enabled
    if ($script:Memory_MemoryEnabled -and -not (Test-Path $script:Memory_MemoryFile)) {
        Initialize-MemoryFile
    }
}

# ═══════════════════════════════════════════════════════════════
#                     SETTINGS MANAGEMENT
# ═══════════════════════════════════════════════════════════════

function Get-RalphSettings {
    <#
    .SYNOPSIS
        Gets all Ralph settings from settings.json
    .OUTPUTS
        Hashtable with settings
    #>
    if (-not (Test-Path $script:Memory_SettingsFile)) {
        return @{
            memory = @{
                enabled = $true
            }
        }
    }
    
    try {
        $content = Get-Content $script:Memory_SettingsFile -Raw | ConvertFrom-Json -AsHashtable
        return $content
    } catch {
        return @{
            memory = @{
                enabled = $true
            }
        }
    }
}

function Save-RalphSettings {
    <#
    .SYNOPSIS
        Saves Ralph settings to settings.json
    .PARAMETER Settings
        Hashtable of settings to save
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings
    )
    
    $ralphDir = Split-Path $script:Memory_SettingsFile -Parent
    if (-not (Test-Path $ralphDir)) {
        New-Item -ItemType Directory -Path $ralphDir -Force | Out-Null
    }
    
    $Settings | ConvertTo-Json -Depth 10 | Set-Content $script:Memory_SettingsFile -Encoding UTF8
}

function Get-MemorySetting {
    <#
    .SYNOPSIS
        Gets the memory enabled/disabled setting
    .OUTPUTS
        Boolean - true if memory is enabled
    #>
    $settings = Get-RalphSettings
    
    if ($settings.memory -and $null -ne $settings.memory.enabled) {
        return $settings.memory.enabled
    }
    
    return $true  # Default to enabled
}

function Set-MemoryEnabled {
    <#
    .SYNOPSIS
        Enables or disables the memory system
    .PARAMETER Enabled
        Whether memory should be enabled
    #>
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled
    )
    
    $settings = Get-RalphSettings
    
    if (-not $settings.memory) {
        $settings.memory = @{}
    }
    
    $settings.memory.enabled = $Enabled
    Save-RalphSettings -Settings $settings
    
    $script:Memory_MemoryEnabled = $Enabled
    
    # Create memory file if enabling and it doesn't exist
    if ($Enabled -and -not (Test-Path $script:Memory_MemoryFile)) {
        Initialize-MemoryFile
    }
}

function Test-MemoryEnabled {
    <#
    .SYNOPSIS
        Checks if memory system is currently enabled
    .OUTPUTS
        Boolean
    #>
    return $script:Memory_MemoryEnabled
}

function Get-VenvModeSetting {
    <#
    .SYNOPSIS
        Gets the venv mode setting
    .OUTPUTS
        String - 'auto' (default), 'always', or 'disabled'
    #>
    $settings = Get-RalphSettings
    
    if ($settings -and $settings.ContainsKey('venv') -and $settings.venv -and $settings.venv.mode) {
        $mode = $settings.venv.mode
        # Migrate old 'skip' to 'disabled'
        if ($mode -eq 'skip') { return 'disabled' }
        return $mode
    }
    
    return 'auto'  # Default to auto
}

function Set-VenvMode {
    <#
    .SYNOPSIS
        Sets the venv mode setting
    .PARAMETER Mode
        Venv mode: 'auto', 'always', or 'disabled'
        - auto: Intelligently detect if project needs venv (default)
        - always: Always create venv regardless of project type
        - disabled: Never create venv, install to system (not recommended)
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('auto', 'always', 'disabled')]
        [string]$Mode
    )
    
    $settings = Get-RalphSettings
    
    if (-not $settings) {
        $settings = @{}
    }
    
    if (-not $settings.ContainsKey('venv')) {
        $settings.venv = @{}
    }
    
    $settings.venv.mode = $Mode
    Save-RalphSettings -Settings $settings
}

function Test-VenvEnabled {
    <#
    .SYNOPSIS
        Checks if venv could be used (not disabled)
    .OUTPUTS
        Boolean - true if venv mode is 'auto' or 'always'
    #>
    $mode = Get-VenvModeSetting
    return $mode -ne 'disabled'
}

# ═══════════════════════════════════════════════════════════════
#                     MEMORY FILE OPERATIONS
# ═══════════════════════════════════════════════════════════════

function Initialize-MemoryFile {
    <#
    .SYNOPSIS
        Creates the initial memory.md file structure
    #>
    $template = @"
# Ralph Memory

> Cross-session learnings that persist across all Ralph sessions.
> This file is automatically managed by Ralph. You can also edit it manually.

---

## Patterns

> Code patterns, conventions, and best practices discovered in this codebase.

<!-- Add patterns here -->

---

## Commands

> Build, test, lint, and other commands that work for this project.

<!-- Add commands here -->

---

## Gotchas

> Common pitfalls, edge cases, and things to watch out for.

<!-- Add gotchas here -->

---

## Decisions

> Architectural decisions, design choices, and their rationale.

<!-- Add decisions here -->

---

*Last updated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")*
"@
    
    $template | Set-Content $script:Memory_MemoryFile -Encoding UTF8
}

function Get-MemoryContent {
    <#
    .SYNOPSIS
        Gets the current memory file content
    .OUTPUTS
        String - Memory file content or empty string if disabled/missing
    #>
    if (-not $script:Memory_MemoryEnabled) {
        return ''
    }
    
    if (-not (Test-Path $script:Memory_MemoryFile)) {
        return ''
    }
    
    return Get-Content $script:Memory_MemoryFile -Raw
}

function Get-MemorySection {
    <#
    .SYNOPSIS
        Gets a specific section from memory
    .PARAMETER Section
        Section name (Patterns, Commands, Gotchas, Decisions)
    .OUTPUTS
        String - Section content
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Patterns', 'Commands', 'Gotchas', 'Decisions')]
        [string]$Section
    )
    
    $content = Get-MemoryContent
    if (-not $content) {
        return ''
    }
    
    # Extract section content between headers
    $pattern = "(?ms)^## $Section\s*\n.*?(?=^---|\z)"
    if ($content -match $pattern) {
        return $Matches[0].Trim()
    }
    
    return ''
}

function Add-MemoryEntry {
    <#
    .SYNOPSIS
        Adds an entry to a memory section
    .PARAMETER Section
        Section to add to (Patterns, Commands, Gotchas, Decisions)
    .PARAMETER Entry
        The entry text to add
    .PARAMETER Source
        Optional source/context for the entry
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Patterns', 'Commands', 'Gotchas', 'Decisions')]
        [string]$Section,
        
        [Parameter(Mandatory)]
        [string]$Entry,
        
        [string]$Source = ''
    )
    
    if (-not $script:Memory_MemoryEnabled) {
        return $false
    }
    
    if (-not (Test-Path $script:Memory_MemoryFile)) {
        Initialize-MemoryFile
    }
    
    $content = Get-Content $script:Memory_MemoryFile -Raw
    
    # Format the entry
    $timestamp = Get-Date -Format "yyyy-MM-dd"
    $sourceText = if ($Source) { " *(from: $Source)*" } else { '' }
    $formattedEntry = "- $Entry$sourceText [$timestamp]"
    
    # Find the section and insert after the comment line
    $sectionPattern = "(?ms)(## $Section\s*\n.*?)(<!-- Add .* here -->)"
    
    if ($content -match $sectionPattern) {
        $beforeComment = $Matches[1]
        $comment = $Matches[2]
        
        # Check if entry already exists (avoid duplicates)
        if ($content -like "*$Entry*") {
            return $false
        }
        
        $newContent = $content -replace [regex]::Escape($beforeComment + $comment), "$beforeComment$formattedEntry`n`n$comment"
        
        # Update last updated timestamp
        $newContent = $newContent -replace '\*Last updated:.*\*', "*Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')*"
        
        $newContent | Set-Content $script:Memory_MemoryFile -Encoding UTF8
        return $true
    }
    
    return $false
}

function Get-MemoryStats {
    <#
    .SYNOPSIS
        Gets statistics about the memory file
    .OUTPUTS
        Hashtable with counts per section
    #>
    $stats = @{
        Enabled = $script:Memory_MemoryEnabled
        Patterns = 0
        Commands = 0
        Gotchas = 0
        Decisions = 0
        Total = 0
    }
    
    if (-not $script:Memory_MemoryEnabled -or -not (Test-Path $script:Memory_MemoryFile)) {
        return $stats
    }
    
    $content = Get-Content $script:Memory_MemoryFile -Raw
    
    # Count entries (lines starting with "- " in each section)
    foreach ($section in @('Patterns', 'Commands', 'Gotchas', 'Decisions')) {
        $sectionContent = Get-MemorySection -Section $section
        $count = ([regex]::Matches($sectionContent, '(?m)^- ')).Count
        $stats[$section] = $count
        $stats.Total += $count
    }
    
    return $stats
}

function Get-MemoryFilePath {
    <#
    .SYNOPSIS
        Gets the path to the memory file
    .OUTPUTS
        String - Full path to memory.md
    #>
    return $script:Memory_MemoryFile
}

function Show-MemoryStatus {
    <#
    .SYNOPSIS
        Displays current memory system status
    #>
    $stats = Get-MemoryStats
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  RALPH MEMORY SYSTEM" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    
    if ($stats.Enabled) {
        Write-Host "  Status: " -NoNewline -ForegroundColor Gray
        Write-Host "ENABLED" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Memory entries:" -ForegroundColor Gray
        Write-Host "    Patterns:  $($stats.Patterns)" -ForegroundColor Cyan
        Write-Host "    Commands:  $($stats.Commands)" -ForegroundColor Cyan
        Write-Host "    Gotchas:   $($stats.Gotchas)" -ForegroundColor Cyan
        Write-Host "    Decisions: $($stats.Decisions)" -ForegroundColor Cyan
        Write-Host "    ─────────────" -ForegroundColor DarkGray
        Write-Host "    Total:     $($stats.Total)" -ForegroundColor White
        Write-Host ""
        Write-Host "  File: $($script:Memory_MemoryFile)" -ForegroundColor DarkGray
    } else {
        Write-Host "  Status: " -NoNewline -ForegroundColor Gray
        Write-Host "DISABLED" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Memory is not being recorded." -ForegroundColor Gray
        Write-Host "  Enable with: ./ralph.ps1 -Memory on" -ForegroundColor Gray
    }
    
    Write-Host ""
}

function Clear-Memory {
    <#
    .SYNOPSIS
        Clears all memory entries (resets to template)
    .PARAMETER Force
        Skip confirmation
    #>
    param(
        [switch]$Force
    )
    
    if (-not $Force) {
        $confirmed = Show-DangerConfirmMenu -Title "Clear Memory" -Message "Clear all memory entries? This cannot be undone." -ConfirmText "yes"
        if (-not $confirmed) {
            Write-Host "  Cancelled." -ForegroundColor Gray
            return $false
        }
    }
    
    Initialize-MemoryFile
    Write-Host "  Memory cleared." -ForegroundColor Green
    return $true
}

# ═══════════════════════════════════════════════════════════════
#                     MENU INTEGRATION
# ═══════════════════════════════════════════════════════════════

function Show-MemoryMenu {
    <#
    .SYNOPSIS
        Interactive menu for memory management with arrow navigation
    .OUTPUTS
        Action result
    #>
    $stats = Get-MemoryStats
    $statusText = if ($stats.Enabled) { "ON ($($stats.Total) entries)" } else { "OFF" }
    
    # Build menu items dynamically based on state
    $menuItems = @()
    
    if ($stats.Enabled) {
        $menuItems += @{ Label = "Toggle memory OFF"; Value = "toggle"; Hotkey = "T" }
        $menuItems += @{ Label = "View memory file"; Value = "view"; Hotkey = "V" }
        $menuItems += @{ Label = "Show statistics"; Value = "stats"; Hotkey = "S" }
        $menuItems += @{ Label = "Clear all memory"; Value = "clear"; Hotkey = "C"; Description = "Cannot be undone" }
    } else {
        $menuItems += @{ Label = "Toggle memory ON"; Value = "toggle"; Hotkey = "T" }
    }
    
    $choice = Show-ArrowChoice -Title "RALPH MEMORY" -Message "Status: $statusText" -Choices $menuItems -AllowBack
    
    switch ($choice) {
        'toggle' {
            Set-MemoryEnabled -Enabled (-not $stats.Enabled)
            $newStatus = if (Test-MemoryEnabled) { "enabled" } else { "disabled" }
            Write-Host "  Memory $newStatus." -ForegroundColor Green
            return @{ Action = 'toggle' }
        }
        'view' {
            if ($stats.Enabled -and (Test-Path $script:Memory_MemoryFile)) {
                Write-Host ""
                Write-Host (Get-Content $script:Memory_MemoryFile -Raw) -ForegroundColor Gray
                Write-Host ""
                Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
            return @{ Action = 'view' }
        }
        'stats' {
            Show-MemoryStatus
            Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return @{ Action = 'stats' }
        }
        'clear' {
            if ($stats.Enabled) {
                Clear-Memory
            }
            return @{ Action = 'clear' }
        }
        default {
            return @{ Action = 'back' }
        }
    }
}

