<#
.SYNOPSIS
    Menu Renderer Module for CLI Framework

.DESCRIPTION
    Provides menu rendering capabilities:
    - Single-select menus with arrow navigation
    - Highlighted selection indicators
    - Keyboard shortcut display
    - Scrollable menus for large lists
    - Group/category headers
    - Separator support
    - Customizable styling and icons
    - Standardized return format with action/value
    
    Works with keyReader.ps1 and screenManager.ps1

.NOTES
    Part of the Ralph CLI Framework
    No external dependencies
#>

# ═══════════════════════════════════════════════════════════════
#                    GLOBAL KEY HANDLER INTEGRATION
# ═══════════════════════════════════════════════════════════════

# Load global key handler if available
$script:GlobalKeyHandlerLoaded = $false
$globalKeyHandlerPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'cli\ps\globalKeyHandler.ps1'
if (-not (Test-Path $globalKeyHandlerPath)) {
    $globalKeyHandlerPath = Join-Path $PSScriptRoot 'globalKeyHandler.ps1'
}

if (Test-Path $globalKeyHandlerPath) {
    try {
        . $globalKeyHandlerPath
        $script:GlobalKeyHandlerLoaded = $true
    } catch {
        $script:GlobalKeyHandlerLoaded = $false
    }
}

# ═══════════════════════════════════════════════════════════════
#                    CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:MenuConfig = @{
    # Selection indicators
    Indicator = @{
        Selected   = '❯'
        Unselected = ' '
        Check      = '◉'
        Uncheck    = '○'
    }
    
    # Colors (using ANSI-compatible names)
    Colors = @{
        Title          = 'Cyan'
        Description    = 'DarkGray'
        Selected       = 'BrightWhite'
        SelectedBg     = 'Blue'
        Normal         = 'White'
        Disabled       = 'DarkGray'
        Hotkey         = 'Yellow'
        Separator      = 'DarkGray'
        ScrollHint     = 'DarkGray'
        GroupHeader    = 'Magenta'
    }
    
    # Layout
    Layout = @{
        Indent         = 2
        ItemPadding    = 1
        HotkeyWidth    = 4
        MinWidth       = 20
        MaxWidth       = 80
    }
    
    # Scroll settings
    Scroll = @{
        IndicatorUp    = '▲ more above'
        IndicatorDown  = '▼ more below'
        Margin         = 2
    }
}

function Set-MenuConfig {
    <#
    .SYNOPSIS
        Updates menu configuration
    .PARAMETER Config
        Hashtable with configuration overrides
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    foreach ($key in $Config.Keys) {
        if ($script:MenuConfig.ContainsKey($key)) {
            if ($Config[$key] -is [hashtable] -and $script:MenuConfig[$key] -is [hashtable]) {
                foreach ($subkey in $Config[$key].Keys) {
                    $script:MenuConfig[$key][$subkey] = $Config[$key][$subkey]
                }
            } else {
                $script:MenuConfig[$key] = $Config[$key]
            }
        }
    }
}

function Get-MenuConfig {
    <#
    .SYNOPSIS
        Gets current menu configuration
    #>
    return $script:MenuConfig.Clone()
}

# ═══════════════════════════════════════════════════════════════
#                    MENU ITEM STRUCTURE
# ═══════════════════════════════════════════════════════════════

function New-MenuItem {
    <#
    .SYNOPSIS
        Creates a menu item
    .PARAMETER Text
        Display text
    .PARAMETER Value
        Value returned when selected
    .PARAMETER Hotkey
        Optional hotkey character
    .PARAMETER Description
        Optional description shown below text
    .PARAMETER Disabled
        If true, item cannot be selected
    .PARAMETER DisabledReason
        Reason shown when hovering disabled item
    .PARAMETER Icon
        Optional icon/emoji prefix
    .PARAMETER Group
        Group name for categorization
    .OUTPUTS
        Menu item hashtable
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        
        [object]$Value,
        [string]$Hotkey = '',
        [string]$Description = '',
        [switch]$Disabled,
        [string]$DisabledReason = '',
        [string]$Icon = '',
        [string]$Group = ''
    )
    
    return @{
        Type     = 'item'
        Text     = $Text
        Value    = if ($null -eq $Value) { $Text } else { $Value }
        Hotkey   = $Hotkey.ToUpper()
        Description = $Description
        Disabled = $Disabled
        DisabledReason = $DisabledReason
        Icon     = $Icon
        Group    = $Group
    }
}

function New-MenuSeparator {
    <#
    .SYNOPSIS
        Creates a menu separator
    .PARAMETER Text
        Optional separator label
    #>
    param(
        [string]$Text = ''
    )
    
    return @{
        Type = 'separator'
        Text = $Text
    }
}

function New-MenuHeader {
    <#
    .SYNOPSIS
        Creates a group header
    .PARAMETER Text
        Header text
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )
    
    return @{
        Type = 'header'
        Text = $Text
    }
}

# ═══════════════════════════════════════════════════════════════
#                    RENDERING HELPERS
# ═══════════════════════════════════════════════════════════════

function Format-MenuTitle {
    <#
    .SYNOPSIS
        Formats menu title with improved spacing
    .PARAMETER Title
        Menu title
    .PARAMETER Description
        Optional description
    .PARAMETER Compact
        Use compact spacing (less blank lines)
    #>
    param(
        [string]$Title,
        [string]$Description = '',
        [switch]$Compact
    )
    
    $output = ''
    $indent = ' ' * $script:MenuConfig.Layout.Indent
    
    # Don't add top spacing - keep it compact
    
    # Build list of active modes
    $activeModes = @()
    
    # Check Dry-Run mode
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        $activeModes += "DRY-RUN"
    }
    
    # Check Developer mode
    $isDeveloper = if (Get-Variable -Name 'DeveloperMode' -Scope Script -ErrorAction SilentlyContinue) { 
        $script:DeveloperMode 
    } else { 
        $false 
    }
    if ($isDeveloper) {
        $activeModes += "DEVELOPER"
    }
    
    # Check Verbose mode
    $isVerbose = if (Get-Variable -Name 'VerboseMode' -Scope Script -ErrorAction SilentlyContinue) { 
        $script:VerboseMode 
    } else { 
        $false 
    }
    if ($isVerbose) {
        $activeModes += "VERBOSE"
    }
    
    # Show consolidated mode indicator if any modes are active
    if ($activeModes.Count -gt 0) {
        $modeText = $activeModes -join " | "
        $message = "  $modeText MODE"
        if ($activeModes.Count -gt 1) {
            $message += "S"
        }
        $message += " ACTIVE  "
        
        # Calculate width for box (centered text)
        $boxWidth = [Math]::Max($message.Length + 4, 60)
        $padding = [Math]::Floor(($boxWidth - $message.Length) / 2)
        $paddedMessage = (" " * $padding) + $message + (" " * $padding)
        
        # Ensure exact width
        if ($paddedMessage.Length -lt $boxWidth) {
            $paddedMessage += " " * ($boxWidth - $paddedMessage.Length)
        }
        
        $output += "$([char]27)[33m"  # Yellow foreground
        $output += "┏" + ("━" * ($boxWidth - 2)) + "┓"
        $output += "$([char]27)[0m`n"
        $output += "$([char]27)[30;43m"  # Black on yellow background
        $output += "┃" + $paddedMessage.Substring(0, $boxWidth - 2) + "┃"
        $output += "$([char]27)[0m`n"
        $output += "$([char]27)[33m"  # Yellow foreground
        $output += "┗" + ("━" * ($boxWidth - 2)) + "┛"
        $output += "$([char]27)[0m`n`n"
    }
    
    if ($Title) {
        $titleColor = $script:MenuConfig.Colors.Title
        $output += "${indent}"
        $output += "$([char]27)[1m"  # Bold
        $output += "$([char]27)[36m" # Cyan
        $output += $Title
        $output += "$([char]27)[0m"  # Reset
        $output += "`n"
    }
    
    if ($Description) {
        # Handle multi-line descriptions - ensure each line is indented
        $descriptionLines = $Description -split "`n"
        foreach ($line in $descriptionLines) {
            $output += "${indent}"
            $output += "$([char]27)[90m" # Dark gray
            $output += $line
            $output += "$([char]27)[0m"
            $output += "`n"
        }
    }
    
    # Add spacing after title/description (not excessive)
    if ($Title -or $Description) {
        $output += "`n"
    }
    
    return $output
}

function Format-MenuItem {
    <#
    .SYNOPSIS
        Formats a single menu item for display
    .PARAMETER Item
        Menu item hashtable
    .PARAMETER IsSelected
        Whether this item is currently selected
    .PARAMETER Index
        Item index (for numbering)
    .PARAMETER ShowIndex
        Whether to show index numbers
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Item,
        
        [switch]$IsSelected,
        [int]$Index = -1,
        [switch]$ShowIndex
    )
    
    $config = $script:MenuConfig
    $indent = ' ' * $config.Layout.Indent
    $output = ''
    $esc = [char]27
    
    # Handle different item types
    switch ($Item.Type) {
        'separator' {
            # Add blank line before separator for visual grouping
            $output = "`n"
            
            if ($Item.Text) {
                $line = "─── $($Item.Text) "
                $remaining = 40 - $line.Length
                if ($remaining -gt 0) {
                    $line += '─' * $remaining
                }
                $output += "${indent}${esc}[90m${line}${esc}[0m"
            } else {
                $output += "${indent}${esc}[90m$('─' * 40)${esc}[0m"
            }
            return $output
        }
        
        'header' {
            # Don't add blank line before header - causes unwanted spacing
            $output = "${indent}${esc}[1m${esc}[35m$($Item.Text)${esc}[0m"
            return $output
        }
    }
    
    # Regular item
    $indicator = if ($IsSelected) { $config.Indicator.Selected } else { $config.Indicator.Unselected }
    
    # Build the line
    $line = $indent
    
    # Selection indicator
    if ($IsSelected) {
        $line += "${esc}[36m${indicator}${esc}[0m "  # Cyan indicator
    } else {
        $line += "$indicator "
    }
    
    # Hotkey
    if ($Item.Hotkey) {
        if ($Item.Disabled) {
            $line += "${esc}[90m[$($Item.Hotkey)]${esc}[0m "
        } else {
            $line += "${esc}[33m[$($Item.Hotkey)]${esc}[0m "
        }
    }
    
    # Icon
    if ($Item.Icon) {
        $line += "$($Item.Icon) "
    }
    
    # Index (optional)
    if ($ShowIndex -and $Index -ge 0) {
        $line += "${esc}[90m$($Index + 1).${esc}[0m "
    }
    
    # Main text
    if ($Item.Disabled) {
        $line += "${esc}[90m${esc}[9m$($Item.Text)${esc}[0m"  # Dim + strikethrough
        if ($Item.DisabledReason -and $IsSelected) {
            $line += " ${esc}[90m($($Item.DisabledReason))${esc}[0m"
        }
    } elseif ($IsSelected) {
        $line += "${esc}[1m${esc}[97m$($Item.Text)${esc}[0m"  # Bold + bright white
    } else {
        $line += $Item.Text
    }
    
    return $line
}

function Format-ScrollIndicator {
    <#
    .SYNOPSIS
        Formats scroll indicator
    .PARAMETER Direction
        'up' or 'down'
    #>
    param(
        [ValidateSet('up', 'down')]
        [string]$Direction
    )
    
    $config = $script:MenuConfig
    $indent = ' ' * ($config.Layout.Indent + 2)
    $esc = [char]27
    
    $text = if ($Direction -eq 'up') {
        $config.Scroll.IndicatorUp
    } else {
        $config.Scroll.IndicatorDown
    }
    
    return "${indent}${esc}[90m${text}${esc}[0m"
}

# ═══════════════════════════════════════════════════════════════
#                    MENU RENDERING
# ═══════════════════════════════════════════════════════════════

function Show-SingleSelectMenu {
    <#
    .SYNOPSIS
        Displays an interactive single-select menu
    .PARAMETER Title
        Menu title
    .PARAMETER Items
        Array of menu items (use New-MenuItem to create)
    .PARAMETER Description
        Optional description under title
    .PARAMETER DefaultIndex
        Initially selected index
    .PARAMETER ShowHotkeys
        Show hotkey hints at bottom
    .PARAMETER PageSize
        Number of visible items (0 = auto)
    .PARAMETER ShowIndex
        Show item numbers
    .PARAMETER ReturnStandardFormat
        Return hashtable with Action/Value instead of just value
    .OUTPUTS
        If ReturnStandardFormat: hashtable with Action ('select' or 'cancel') and Value
        Otherwise: selected item value, or $null if cancelled
    .EXAMPLE
        $items = @(
            New-MenuItem -Text "Option 1" -Value "opt1" -Hotkey "1"
            New-MenuItem -Text "Option 2" -Value "opt2" -Hotkey "2"
            New-MenuItem -Text "Quit" -Value "quit" -Hotkey "Q"
        )
        $result = Show-SingleSelectMenu -Title "Choose an option" -Items $items
    #>
    param(
        [string]$Title = '',
        
        [Parameter(Mandatory)]
        [array]$Items,
        
        [string]$Description = '',
        [int]$DefaultIndex = 0,
        [switch]$ShowHotkeys,
        [int]$PageSize = 0,
        [switch]$ShowIndex,
        [switch]$ReturnStandardFormat
    )
    
    # Filter to only selectable items
    $selectableIndices = @()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($Items[$i].Type -eq 'item' -and -not $Items[$i].Disabled) {
            $selectableIndices += $i
        }
    }
    
    if ($selectableIndices.Count -eq 0) {
        Write-Host "No selectable items in menu" -ForegroundColor Red
        return $null
    }
    
    # Initialize selection
    $currentIndex = [Math]::Max(0, [Math]::Min($DefaultIndex, $Items.Count - 1))
    if ($Items[$currentIndex].Type -ne 'item' -or $Items[$currentIndex].Disabled) {
        $currentIndex = $selectableIndices[0]
    }
    
    # Calculate visible items
    $termSize = Get-TerminalSize
    $visibleHeight = if ($PageSize -gt 0) {
        [Math]::Min($PageSize, $Items.Count)
    } else {
        [Math]::Min($Items.Count, $termSize.Height - 8)
    }
    
    # Create viewport for scrolling
    $viewport = New-Viewport -Items $Items.Count -VisibleHeight $visibleHeight -StartIndex $currentIndex
    
    # Render loop
    $esc = [char]27
    $result = $null
    $actionType = 'cancel'
    
    # Hide cursor during menu
    Hide-Cursor
    
    try {
        while ($true) {
            # Clear screen and reset cursor for clean redraw
            Clear-Screen -ResetCursor
            
            # Update viewport
            $viewport = Update-Viewport -Viewport $viewport -SelectedIndex $currentIndex
            $range = Get-ViewportRange -Viewport $viewport
            
            # Render title
            if ($Title -or $Description) {
                Write-Host (Format-MenuTitle -Title $Title -Description $Description) -NoNewline
            }
            
            # Scroll up indicator
            if ($range.IsScrolledFromTop) {
                Write-Host (Format-ScrollIndicator -Direction 'up')
            } else {
                Write-Host ''
            }
            
            # Render visible items
            for ($i = $range.Start; $i -le $range.End; $i++) {
                $isSelected = ($i -eq $currentIndex)
                Write-Host (Format-MenuItem -Item $Items[$i] -IsSelected:$isSelected -Index $i -ShowIndex:$ShowIndex)
            }
            
            # Scroll down indicator
            if ($range.IsScrolledFromBottom) {
                Write-Host (Format-ScrollIndicator -Direction 'down')
            } else {
                Write-Host ''
            }
            
            # Hotkey hints
            if ($ShowHotkeys) {
                $indent = ' ' * $script:MenuConfig.Layout.Indent
                Write-Host ""
                Write-Host "${indent}${esc}[90m↑↓ Navigate  Enter Select  Esc Cancel${esc}[0m"
            }
            
            # Read key - filter to items that have Hotkey property and non-empty value
            $action = Read-NavigationKey -AllowChars ($Items | Where-Object { $_.ContainsKey('Hotkey') -and $_.Hotkey } | ForEach-Object { $_.Hotkey.ToLower() })
            
            # Handle force exit
            if ($action -eq 'force-exit') {
                Show-Cursor
                if ($script:GlobalKeyHandlerLoaded) {
                    Invoke-ForceExit
                } else {
                    exit 0
                }
            }
            
            switch ($action) {
                'up' {
                    # Find previous selectable item
                    $idx = [Array]::IndexOf($selectableIndices, $currentIndex)
                    if ($idx -gt 0) {
                        $currentIndex = $selectableIndices[$idx - 1]
                    } elseif ($idx -eq 0) {
                        # Wrap to bottom
                        $currentIndex = $selectableIndices[-1]
                    }
                }
                'down' {
                    # Find next selectable item
                    $idx = [Array]::IndexOf($selectableIndices, $currentIndex)
                    if ($idx -lt $selectableIndices.Count - 1) {
                        $currentIndex = $selectableIndices[$idx + 1]
                    } elseif ($idx -eq $selectableIndices.Count - 1) {
                        # Wrap to top
                        $currentIndex = $selectableIndices[0]
                    }
                }
                'home' {
                    $currentIndex = $selectableIndices[0]
                }
                'end' {
                    $currentIndex = $selectableIndices[-1]
                }
                'pageup' {
                    $idx = [Array]::IndexOf($selectableIndices, $currentIndex)
                    $newIdx = [Math]::Max(0, $idx - $visibleHeight)
                    $currentIndex = $selectableIndices[$newIdx]
                }
                'pagedown' {
                    $idx = [Array]::IndexOf($selectableIndices, $currentIndex)
                    $newIdx = [Math]::Min($selectableIndices.Count - 1, $idx + $visibleHeight)
                    $currentIndex = $selectableIndices[$newIdx]
                }
                'select' {
                    $result = $Items[$currentIndex].Value
                    $actionType = 'select'
                    break
                }
                'cancel' {
                    $result = $null
                    $actionType = 'cancel'
                    break
                }
                default {
                    # Check for hotkey match
                    if ($action -and $action.Length -eq 1) {
                        $hotkey = $action.ToUpper()
                        $matchingItem = $Items | Where-Object { 
                            $_.Type -eq 'item' -and $_.ContainsKey('Hotkey') -and $_.Hotkey -eq $hotkey -and -not $_.Disabled 
                        } | Select-Object -First 1
                        
                        if ($matchingItem) {
                            $result = $matchingItem.Value
                            $actionType = 'select'
                            break
                        }
                    }
                }
            }
            
            # Check if we should exit
            if ($null -ne $result -or $action -eq 'cancel' -or $action -eq 'select') {
                break
            }
        }
    } finally {
        Show-Cursor
    }
    
    # Return in requested format
    if ($ReturnStandardFormat) {
        if ($script:GlobalKeyHandlerLoaded) {
            return New-KeyResult -Action $actionType -Value $result
        } else {
            return @{ Action = $actionType; Value = $result }
        }
    }
    
    return $result
}

function Show-QuickMenu {
    <#
    .SYNOPSIS
        Shows a simple menu from string array
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of option strings
    .PARAMETER DefaultIndex
        Initially selected index
    .OUTPUTS
        Selected option string or $null
    #>
    param(
        [string]$Title = 'Select an option',
        
        [Parameter(Mandatory)]
        [string[]]$Options,
        
        [int]$DefaultIndex = 0
    )
    
    $items = @()
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $items += New-MenuItem -Text $Options[$i] -Value $Options[$i]
    }
    
    return Show-SingleSelectMenu -Title $Title -Items $items -DefaultIndex $DefaultIndex
}

# ═══════════════════════════════════════════════════════════════
#                    EXPORT
# ═══════════════════════════════════════════════════════════════

# Export functions if loaded as module (not when dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Set-MenuConfig'
        'Get-MenuConfig'
        'New-MenuItem'
        'New-MenuSeparator'
        'New-MenuHeader'
        'Format-MenuTitle'
        'Format-MenuItem'
        'Format-ScrollIndicator'
        'Show-SingleSelectMenu'
        'Show-QuickMenu'
    )
}
