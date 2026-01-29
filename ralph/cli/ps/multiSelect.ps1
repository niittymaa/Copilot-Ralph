<#
.SYNOPSIS
    Multi-Select Module for CLI Framework

.DESCRIPTION
    Provides multi-selection capabilities:
    - Checkbox-style selection with spacebar toggle
    - Select all / deselect all functionality
    - Required minimum/maximum selection enforcement
    - Group selection (select all in group)
    - Search/filter within list
    - Batch operations
    
    Works with menuRenderer.ps1 and keyReader.ps1

.NOTES
    Part of the Ralph CLI Framework
    No external dependencies
#>

# ═══════════════════════════════════════════════════════════════
#                    CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:MultiSelectConfig = @{
    Indicators = @{
        Checked   = '[✓]'
        Unchecked = '[ ]'
        Focused   = '❯'
        Unfocused = ' '
    }
    
    Colors = @{
        Checked   = 'Green'
        Unchecked = 'White'
        Focused   = 'Cyan'
        Disabled  = 'DarkGray'
        Counter   = 'Yellow'
    }
    
    Layout = @{
        Indent = 2
    }
}

# ═══════════════════════════════════════════════════════════════
#                    MULTI-SELECT ITEM
# ═══════════════════════════════════════════════════════════════

function New-MultiSelectItem {
    <#
    .SYNOPSIS
        Creates a multi-select item
    .PARAMETER Text
        Display text
    .PARAMETER Value
        Value returned when selected
    .PARAMETER Checked
        Initially checked state
    .PARAMETER Disabled
        Cannot be toggled
    .PARAMETER Group
        Optional group name
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        
        [object]$Value,
        [switch]$Checked,
        [switch]$Disabled,
        [string]$Group = ''
    )
    
    return @{
        Text     = $Text
        Value    = if ($null -eq $Value) { $Text } else { $Value }
        Checked  = [bool]$Checked
        Disabled = [bool]$Disabled
        Group    = $Group
    }
}

# ═══════════════════════════════════════════════════════════════
#                    RENDERING
# ═══════════════════════════════════════════════════════════════

function Format-MultiSelectItem {
    <#
    .SYNOPSIS
        Formats a multi-select item for display
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Item,
        
        [switch]$IsFocused,
        [switch]$ShowGroup
    )
    
    $config = $script:MultiSelectConfig
    $esc = [char]27
    $indent = ' ' * $config.Layout.Indent
    
    # Focus indicator
    $focus = if ($IsFocused) { 
        "${esc}[36m$($config.Indicators.Focused)${esc}[0m" 
    } else { 
        $config.Indicators.Unfocused 
    }
    
    # Checkbox
    if ($Item.Disabled) {
        $checkbox = "${esc}[90m$($config.Indicators.Unchecked)${esc}[0m"
    } elseif ($Item.Checked) {
        $checkbox = "${esc}[32m$($config.Indicators.Checked)${esc}[0m"
    } else {
        $checkbox = $config.Indicators.Unchecked
    }
    
    # Text
    if ($Item.Disabled) {
        $text = "${esc}[90m$($Item.Text)${esc}[0m"
    } elseif ($IsFocused) {
        $text = "${esc}[1m${esc}[97m$($Item.Text)${esc}[0m"
    } else {
        $text = $Item.Text
    }
    
    # Group prefix
    $groupPrefix = ''
    if ($ShowGroup -and $Item.Group) {
        $groupPrefix = "${esc}[90m[$($Item.Group)]${esc}[0m "
    }
    
    return "${indent}${focus} ${checkbox} ${groupPrefix}${text}"
}

function Format-SelectionCounter {
    <#
    .SYNOPSIS
        Formats selection counter display
    #>
    param(
        [int]$Selected,
        [int]$Total,
        [int]$Min = 0,
        [int]$Max = 0
    )
    
    $esc = [char]27
    $indent = ' ' * $script:MultiSelectConfig.Layout.Indent
    
    $counter = "${indent}${esc}[33m${Selected}${esc}[0m/${Total} selected"
    
    if ($Min -gt 0 -and $Selected -lt $Min) {
        $counter += " ${esc}[91m(min: ${Min})${esc}[0m"
    } elseif ($Max -gt 0 -and $Selected -gt $Max) {
        $counter += " ${esc}[91m(max: ${Max})${esc}[0m"
    }
    
    return $counter
}

# ═══════════════════════════════════════════════════════════════
#                    MULTI-SELECT MENU
# ═══════════════════════════════════════════════════════════════

function Show-MultiSelectMenu {
    <#
    .SYNOPSIS
        Displays an interactive multi-select menu
    .PARAMETER Title
        Menu title
    .PARAMETER Items
        Array of multi-select items (use New-MultiSelectItem)
    .PARAMETER Description
        Optional description
    .PARAMETER MinSelection
        Minimum required selections (0 = no minimum)
    .PARAMETER MaxSelection
        Maximum allowed selections (0 = no maximum)
    .PARAMETER DefaultIndex
        Initially focused index
    .PARAMETER PageSize
        Number of visible items (0 = auto)
    .PARAMETER ShowHelp
        Show keyboard hints
    .PARAMETER AllowEmpty
        Allow confirming with no selections
    .OUTPUTS
        Array of selected values, or $null if cancelled
    .EXAMPLE
        $items = @(
            New-MultiSelectItem -Text "Feature A" -Value "a" -Checked
            New-MultiSelectItem -Text "Feature B" -Value "b"
            New-MultiSelectItem -Text "Feature C" -Value "c"
        )
        $selected = Show-MultiSelectMenu -Title "Select features" -Items $items
    #>
    param(
        [string]$Title = '',
        
        [Parameter(Mandatory)]
        [array]$Items,
        
        [string]$Description = '',
        [int]$MinSelection = 0,
        [int]$MaxSelection = 0,
        [int]$DefaultIndex = 0,
        [int]$PageSize = 0,
        [switch]$ShowHelp,
        [switch]$AllowEmpty
    )
    
    # Make a mutable copy of items
    $menuItems = @()
    foreach ($item in $Items) {
        $menuItems += @{
            Text     = $item.Text
            Value    = $item.Value
            Checked  = $item.Checked
            Disabled = $item.Disabled
            Group    = $item.Group
        }
    }
    
    # Find selectable indices
    $selectableIndices = @()
    for ($i = 0; $i -lt $menuItems.Count; $i++) {
        if (-not $menuItems[$i].Disabled) {
            $selectableIndices += $i
        }
    }
    
    if ($selectableIndices.Count -eq 0) {
        Write-Host "No selectable items" -ForegroundColor Red
        return $null
    }
    
    # Initialize
    $currentIndex = [Math]::Max(0, [Math]::Min($DefaultIndex, $menuItems.Count - 1))
    if ($menuItems[$currentIndex].Disabled) {
        $currentIndex = $selectableIndices[0]
    }
    
    # Calculate visible height
    $termSize = Get-TerminalSize
    $visibleHeight = if ($PageSize -gt 0) {
        [Math]::Min($PageSize, $menuItems.Count)
    } else {
        [Math]::Min($menuItems.Count, $termSize.Height - 10)
    }
    
    # Create viewport
    $viewport = New-Viewport -Items $menuItems.Count -VisibleHeight $visibleHeight -StartIndex $currentIndex
    
    # Check for groups
    $hasGroups = ($menuItems | Where-Object { $_.Group } | Measure-Object).Count -gt 0
    
    $esc = [char]27
    $firstRender = $true
    $result = $null
    $cancelled = $false
    
    Hide-Cursor
    
    try {
        while ($true) {
            # Count selections
            $selectedCount = ($menuItems | Where-Object { $_.Checked }).Count
            $totalCount = ($menuItems | Where-Object { -not $_.Disabled }).Count
            
            # Calculate lines
            $totalLines = 0
            if ($Title) { $totalLines += 2 }
            if ($Description) { $totalLines += 1 }
            $totalLines += 2  # Counter + blank
            $totalLines += $visibleHeight + 2  # Items + scroll indicators
            if ($ShowHelp) { $totalLines += 2 }
            
            # Redraw
            if (-not $firstRender) {
                Move-CursorUp -Lines $totalLines
            }
            $firstRender = $false
            
            # Update viewport
            $viewport = Update-Viewport -Viewport $viewport -SelectedIndex $currentIndex
            $range = Get-ViewportRange -Viewport $viewport
            
            # Title
            if ($Title) {
                Write-Host (Format-MenuTitle -Title $Title -Description $Description) -NoNewline
            }
            
            # Counter
            Write-Host (Format-SelectionCounter -Selected $selectedCount -Total $totalCount -Min $MinSelection -Max $MaxSelection)
            Write-Host ""
            
            # Scroll up indicator
            if ($range.IsScrolledFromTop) {
                Write-Host (Format-ScrollIndicator -Direction 'up')
            } else {
                Write-Host ''
            }
            
            # Render items
            for ($i = $range.Start; $i -le $range.End; $i++) {
                $isFocused = ($i -eq $currentIndex)
                Write-Host (Format-MultiSelectItem -Item $menuItems[$i] -IsFocused:$isFocused -ShowGroup:$hasGroups)
            }
            
            # Scroll down indicator
            if ($range.IsScrolledFromBottom) {
                Write-Host (Format-ScrollIndicator -Direction 'down')
            } else {
                Write-Host ''
            }
            
            # Help
            if ($ShowHelp) {
                $indent = ' ' * $script:MultiSelectConfig.Layout.Indent
                Write-Host ""
                Write-Host "${indent}${esc}[90m↑↓ Move  Space Toggle  A Select all  N Deselect all  Enter Confirm  Esc Cancel${esc}[0m"
            }
            
            # Read key
            $action = Read-NavigationKey -AllowChars 'an'
            
            switch ($action) {
                'up' {
                    $idx = [Array]::IndexOf($selectableIndices, $currentIndex)
                    if ($idx -gt 0) {
                        $currentIndex = $selectableIndices[$idx - 1]
                    } else {
                        $currentIndex = $selectableIndices[-1]
                    }
                }
                'down' {
                    $idx = [Array]::IndexOf($selectableIndices, $currentIndex)
                    if ($idx -lt $selectableIndices.Count - 1) {
                        $currentIndex = $selectableIndices[$idx + 1]
                    } else {
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
                'space' {
                    # Toggle current item
                    if (-not $menuItems[$currentIndex].Disabled) {
                        $newState = -not $menuItems[$currentIndex].Checked
                        
                        # Check max limit
                        if ($newState -and $MaxSelection -gt 0) {
                            if ($selectedCount -ge $MaxSelection) {
                                continue  # Can't select more
                            }
                        }
                        
                        $menuItems[$currentIndex].Checked = $newState
                    }
                }
                'a' {
                    # Select all
                    $canSelectCount = if ($MaxSelection -gt 0) { $MaxSelection } else { $totalCount }
                    $selected = 0
                    foreach ($item in $menuItems) {
                        if (-not $item.Disabled -and $selected -lt $canSelectCount) {
                            $item.Checked = $true
                            $selected++
                        }
                    }
                }
                'n' {
                    # Deselect all
                    foreach ($item in $menuItems) {
                        if (-not $item.Disabled) {
                            $item.Checked = $false
                        }
                    }
                }
                'select' {
                    # Validate selection
                    $selectedCount = ($menuItems | Where-Object { $_.Checked }).Count
                    
                    if ($MinSelection -gt 0 -and $selectedCount -lt $MinSelection) {
                        # Not enough selected - show warning and continue
                        continue
                    }
                    
                    if (-not $AllowEmpty -and $selectedCount -eq 0) {
                        continue
                    }
                    
                    # Return selected values
                    $result = @($menuItems | Where-Object { $_.Checked } | ForEach-Object { $_.Value })
                    break
                }
                'cancel' {
                    $cancelled = $true
                    break
                }
            }
            
            if ($cancelled) { break }
        }
    } finally {
        Show-Cursor
    }
    
    if ($cancelled) {
        return $null
    }
    
    return $result
}

function Show-QuickMultiSelect {
    <#
    .SYNOPSIS
        Shows a simple multi-select from string array
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of option strings
    .PARAMETER DefaultSelected
        Array of initially selected options
    .OUTPUTS
        Array of selected strings or $null
    #>
    param(
        [string]$Title = 'Select options',
        
        [Parameter(Mandatory)]
        [string[]]$Options,
        
        [string[]]$DefaultSelected = @()
    )
    
    $items = @()
    foreach ($opt in $Options) {
        $checked = $DefaultSelected -contains $opt
        $items += New-MultiSelectItem -Text $opt -Value $opt -Checked:$checked
    }
    
    return Show-MultiSelectMenu -Title $Title -Items $items -ShowHelp
}

# ═══════════════════════════════════════════════════════════════
#                    GROUP OPERATIONS
# ═══════════════════════════════════════════════════════════════

function Get-ItemsByGroup {
    <#
    .SYNOPSIS
        Gets items belonging to a specific group
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        
        [Parameter(Mandatory)]
        [string]$Group
    )
    
    return @($Items | Where-Object { $_.Group -eq $Group })
}

function Set-GroupChecked {
    <#
    .SYNOPSIS
        Sets checked state for all items in a group
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        
        [Parameter(Mandatory)]
        [string]$Group,
        
        [Parameter(Mandatory)]
        [bool]$Checked
    )
    
    foreach ($item in $Items) {
        if ($item.Group -eq $Group -and -not $item.Disabled) {
            $item.Checked = $Checked
        }
    }
}

function Get-SelectedValues {
    <#
    .SYNOPSIS
        Gets values of all checked items
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Items
    )
    
    return @($Items | Where-Object { $_.Checked } | ForEach-Object { $_.Value })
}

function Get-SelectedCount {
    <#
    .SYNOPSIS
        Gets count of checked items
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Items
    )
    
    return ($Items | Where-Object { $_.Checked }).Count
}

# ═══════════════════════════════════════════════════════════════
#                    EXPORT
# ═══════════════════════════════════════════════════════════════

# Export functions if loaded as module (not when dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'New-MultiSelectItem'
        'Format-MultiSelectItem'
        'Format-SelectionCounter'
        'Show-MultiSelectMenu'
        'Show-QuickMultiSelect'
        'Get-ItemsByGroup'
        'Set-GroupChecked'
        'Get-SelectedValues'
        'Get-SelectedCount'
    )
}
