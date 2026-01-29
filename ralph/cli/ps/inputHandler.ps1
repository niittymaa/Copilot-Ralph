<#
.SYNOPSIS
    Input Handler Module for CLI Framework

.DESCRIPTION
    Provides high-level input handling:
    - Text input with validation
    - Password/masked input
    - Confirmation dialogs
    - Number input with range validation
    - Path input with auto-completion hints
    - Search/filter input with real-time matching
    
    Works with keyReader.ps1 and screenManager.ps1

.NOTES
    Part of the Ralph CLI Framework
    No external dependencies
#>

# ═══════════════════════════════════════════════════════════════
#                    TEXT INPUT
# ═══════════════════════════════════════════════════════════════

function Read-TextInput {
    <#
    .SYNOPSIS
        Reads text input with optional validation
    .PARAMETER Prompt
        Prompt text to display
    .PARAMETER Default
        Default value
    .PARAMETER Required
        If true, empty input is not allowed
    .PARAMETER MaxLength
        Maximum input length
    .PARAMETER Pattern
        Regex pattern for validation
    .PARAMETER PatternMessage
        Message to show if pattern doesn't match
    .PARAMETER Placeholder
        Placeholder text shown when empty
    .OUTPUTS
        Entered text or $null if cancelled
    #>
    param(
        [string]$Prompt = 'Enter value',
        [string]$Default = '',
        [switch]$Required,
        [int]$MaxLength = 1000,
        [string]$Pattern = '',
        [string]$PatternMessage = 'Invalid input format',
        [string]$Placeholder = ''
    )
    
    $esc = [char]27
    $indent = '  '
    
    # Display prompt
    Write-Host ""
    Write-Host "${indent}${esc}[36m${Prompt}${esc}[0m" -NoNewline
    
    if ($Default) {
        Write-Host " ${esc}[90m(default: ${Default})${esc}[0m" -NoNewline
    }
    
    Write-Host ":"
    Write-Host "${indent}" -NoNewline
    
    while ($true) {
        $input = Read-LineInput -Default $Default -MaxLength $MaxLength
        
        if ($null -eq $input) {
            return $null  # Cancelled
        }
        
        # Use default if empty
        if ([string]::IsNullOrWhiteSpace($input) -and $Default) {
            $input = $Default
        }
        
        # Validate required
        if ($Required -and [string]::IsNullOrWhiteSpace($input)) {
            Write-Host "${indent}${esc}[91mThis field is required${esc}[0m"
            Write-Host "${indent}" -NoNewline
            continue
        }
        
        # Validate pattern
        if ($Pattern -and $input -and $input -notmatch $Pattern) {
            Write-Host "${indent}${esc}[91m${PatternMessage}${esc}[0m"
            Write-Host "${indent}" -NoNewline
            continue
        }
        
        return $input
    }
}

function Read-PasswordInput {
    <#
    .SYNOPSIS
        Reads password input with masking
    .PARAMETER Prompt
        Prompt text
    .PARAMETER MaskChar
        Character to display instead of input
    .PARAMETER Required
        If true, empty input is not allowed
    .PARAMETER MinLength
        Minimum password length
    .OUTPUTS
        Entered password or $null if cancelled
    #>
    param(
        [string]$Prompt = 'Enter password',
        [string]$MaskChar = '*',
        [switch]$Required,
        [int]$MinLength = 0
    )
    
    $esc = [char]27
    $indent = '  '
    
    Write-Host ""
    Write-Host "${indent}${esc}[36m${Prompt}${esc}[0m:"
    Write-Host "${indent}" -NoNewline
    
    while ($true) {
        $input = Read-LineInput -Mask $MaskChar
        
        if ($null -eq $input) {
            return $null  # Cancelled
        }
        
        # Validate required
        if ($Required -and [string]::IsNullOrWhiteSpace($input)) {
            Write-Host "${indent}${esc}[91mPassword is required${esc}[0m"
            Write-Host "${indent}" -NoNewline
            continue
        }
        
        # Validate length
        if ($MinLength -gt 0 -and $input.Length -lt $MinLength) {
            Write-Host "${indent}${esc}[91mPassword must be at least ${MinLength} characters${esc}[0m"
            Write-Host "${indent}" -NoNewline
            continue
        }
        
        return $input
    }
}

# ═══════════════════════════════════════════════════════════════
#                    NUMBER INPUT
# ═══════════════════════════════════════════════════════════════

function Read-NumberInput {
    <#
    .SYNOPSIS
        Reads numeric input with range validation
    .PARAMETER Prompt
        Prompt text
    .PARAMETER Default
        Default value
    .PARAMETER Min
        Minimum allowed value
    .PARAMETER Max
        Maximum allowed value
    .PARAMETER AllowDecimal
        Allow decimal numbers
    .OUTPUTS
        Number or $null if cancelled
    #>
    param(
        [string]$Prompt = 'Enter number',
        [double]$Default = 0,
        [double]$Min = [double]::MinValue,
        [double]$Max = [double]::MaxValue,
        [switch]$AllowDecimal
    )
    
    $esc = [char]27
    $indent = '  '
    
    # Build range hint
    $rangeHint = ''
    if ($Min -ne [double]::MinValue -and $Max -ne [double]::MaxValue) {
        $rangeHint = " (${Min}-${Max})"
    } elseif ($Min -ne [double]::MinValue) {
        $rangeHint = " (min: ${Min})"
    } elseif ($Max -ne [double]::MaxValue) {
        $rangeHint = " (max: ${Max})"
    }
    
    Write-Host ""
    Write-Host "${indent}${esc}[36m${Prompt}${esc}[0m${esc}[90m${rangeHint}${esc}[0m"
    
    if ($Default -ne 0) {
        Write-Host "${indent}${esc}[90m(default: ${Default})${esc}[0m"
    }
    
    Write-Host "${indent}" -NoNewline
    
    while ($true) {
        $input = Read-LineInput -Default $Default.ToString()
        
        if ($null -eq $input) {
            return $null
        }
        
        # Use default if empty
        if ([string]::IsNullOrWhiteSpace($input)) {
            return $Default
        }
        
        # Parse number
        $number = 0.0
        $parsed = if ($AllowDecimal) {
            [double]::TryParse($input, [ref]$number)
        } else {
            $intValue = 0
            $result = [int]::TryParse($input, [ref]$intValue)
            $number = $intValue
            $result
        }
        
        if (-not $parsed) {
            Write-Host "${indent}${esc}[91mPlease enter a valid number${esc}[0m"
            Write-Host "${indent}" -NoNewline
            continue
        }
        
        # Validate range
        if ($number -lt $Min) {
            Write-Host "${indent}${esc}[91mValue must be at least ${Min}${esc}[0m"
            Write-Host "${indent}" -NoNewline
            continue
        }
        
        if ($number -gt $Max) {
            Write-Host "${indent}${esc}[91mValue must be at most ${Max}${esc}[0m"
            Write-Host "${indent}" -NoNewline
            continue
        }
        
        if ($AllowDecimal) {
            return $number
        } else {
            return [int]$number
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                    CONFIRMATION
# ═══════════════════════════════════════════════════════════════

function Show-Confirm {
    <#
    .SYNOPSIS
        Shows a yes/no confirmation prompt
    .PARAMETER Message
        Confirmation message
    .PARAMETER DefaultYes
        If true, Enter defaults to Yes
    .PARAMETER YesText
        Custom text for Yes option
    .PARAMETER NoText
        Custom text for No option
    .OUTPUTS
        $true for yes, $false for no, $null if cancelled
    .EXAMPLE
        if (Show-Confirm -Message "Delete file?" -DefaultYes:$false) {
            Remove-Item $path
        }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [switch]$DefaultYes,
        [string]$YesText = 'Yes',
        [string]$NoText = 'No'
    )
    
    $esc = [char]27
    $indent = '  '
    
    # Highlight default option
    $yesHint = if ($DefaultYes) { "${esc}[1mY${esc}[0m" } else { 'y' }
    $noHint = if (-not $DefaultYes) { "${esc}[1mN${esc}[0m" } else { 'n' }
    
    Write-Host ""
    Write-Host "${indent}${esc}[33m${Message}${esc}[0m [${yesHint}/${noHint}] " -NoNewline
    
    $result = Read-Confirmation -DefaultYes:$DefaultYes
    
    if ($null -eq $result) {
        Write-Host "${esc}[90m(cancelled)${esc}[0m"
    } elseif ($result) {
        Write-Host "${esc}[32m${YesText}${esc}[0m"
    } else {
        Write-Host "${esc}[91m${NoText}${esc}[0m"
    }
    
    return $result
}

function Show-DangerConfirm {
    <#
    .SYNOPSIS
        Shows a dangerous action confirmation requiring typed confirmation
    .PARAMETER Message
        Warning message
    .PARAMETER ConfirmText
        Text that must be typed to confirm
    .OUTPUTS
        $true if confirmed, $false otherwise
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$ConfirmText = 'DELETE'
    )
    
    $esc = [char]27
    $indent = '  '
    
    Write-Host ""
    Write-Host "${indent}${esc}[91m⚠ WARNING${esc}[0m"
    Write-Host "${indent}${Message}"
    Write-Host ""
    Write-Host "${indent}Type ${esc}[1m${ConfirmText}${esc}[0m to confirm: " -NoNewline
    
    $input = Read-LineInput
    
    if ($input -eq $ConfirmText) {
        Write-Host "${indent}${esc}[32mConfirmed${esc}[0m"
        return $true
    } else {
        Write-Host "${indent}${esc}[33mCancelled${esc}[0m"
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════
#                    CHOICE INPUT
# ═══════════════════════════════════════════════════════════════

function Read-Choice {
    <#
    .SYNOPSIS
        Reads a single character choice from a set of options
    .PARAMETER Prompt
        Prompt text
    .PARAMETER Choices
        Hashtable of character => description
    .PARAMETER Default
        Default choice character
    .OUTPUTS
        Selected character or $null if cancelled
    .EXAMPLE
        $choice = Read-Choice -Prompt "Action?" -Choices @{
            'A' = 'Add new'
            'E' = 'Edit existing'
            'D' = 'Delete'
            'Q' = 'Quit'
        } -Default 'A'
    #>
    param(
        [string]$Prompt = 'Choose',
        
        [Parameter(Mandatory)]
        [hashtable]$Choices,
        
        [string]$Default = ''
    )
    
    $esc = [char]27
    $indent = '  '
    
    Write-Host ""
    Write-Host "${indent}${esc}[36m${Prompt}${esc}[0m"
    
    # Display choices
    foreach ($key in $Choices.Keys | Sort-Object) {
        $isDefault = ($key.ToUpper() -eq $Default.ToUpper())
        $keyDisplay = if ($isDefault) { "${esc}[1m${esc}[33m[${key}]${esc}[0m" } else { "${esc}[33m[${key}]${esc}[0m" }
        Write-Host "${indent}  ${keyDisplay} $($Choices[$key])"
    }
    
    # Build allowed chars
    $allowedChars = ($Choices.Keys | ForEach-Object { $_.ToLower() }) -join ''
    
    Write-Host ""
    Write-Host "${indent}Choice: " -NoNewline
    
    while ($true) {
        $key = Read-SingleKey -NoEcho
        
        if (-not $key) { continue }
        
        $char = $key.Char.ToString().ToUpper()
        
        # Check for Enter (use default)
        if ($key.Name -eq 'Enter' -and $Default) {
            Write-Host "${esc}[33m${Default}${esc}[0m"
            return $Default.ToUpper()
        }
        
        # Check for Escape
        if ($key.Name -eq 'Escape') {
            Write-Host "${esc}[90m(cancelled)${esc}[0m"
            return $null
        }
        
        # Check if valid choice
        if ($Choices.Keys -contains $char) {
            Write-Host "${esc}[33m${char}${esc}[0m"
            return $char
        }
        
        # Invalid key - ignore and continue
    }
}

# ═══════════════════════════════════════════════════════════════
#                    PATH INPUT
# ═══════════════════════════════════════════════════════════════

function Read-PathInput {
    <#
    .SYNOPSIS
        Reads a file or directory path with validation
    .PARAMETER Prompt
        Prompt text
    .PARAMETER Default
        Default path
    .PARAMETER MustExist
        Path must exist
    .PARAMETER Type
        'File', 'Directory', or 'Any'
    .PARAMETER BasePath
        Base path for relative paths
    .OUTPUTS
        Path string or $null if cancelled
    #>
    param(
        [string]$Prompt = 'Enter path',
        [string]$Default = '',
        [switch]$MustExist,
        [ValidateSet('File', 'Directory', 'Any')]
        [string]$Type = 'Any',
        [string]$BasePath = ''
    )
    
    $esc = [char]27
    $indent = '  '
    
    Write-Host ""
    Write-Host "${indent}${esc}[36m${Prompt}${esc}[0m"
    
    if ($Default) {
        Write-Host "${indent}${esc}[90m(default: ${Default})${esc}[0m"
    }
    
    if ($BasePath) {
        Write-Host "${indent}${esc}[90mBase: ${BasePath}${esc}[0m"
    }
    
    Write-Host "${indent}" -NoNewline
    
    while ($true) {
        $input = Read-LineInput -Default $Default
        
        if ($null -eq $input) {
            return $null
        }
        
        # Use default if empty
        if ([string]::IsNullOrWhiteSpace($input) -and $Default) {
            $input = $Default
        }
        
        if ([string]::IsNullOrWhiteSpace($input)) {
            return ''
        }
        
        # Normalize path (handles "d:Temp" → "D:\Temp" and other common issues)
        $originalInput = $input
        $fullPath = Normalize-Path -Path $input -BasePath $BasePath
        
        # Show normalization if path was changed
        if ($fullPath -ne $input -and $fullPath -ne $originalInput) {
            Write-Host "${indent}${esc}[90m→ Normalized to: ${fullPath}${esc}[0m"
        }
        
        # Validate existence
        if ($MustExist) {
            $exists = Test-Path $fullPath
            
            if (-not $exists) {
                Write-Host "${indent}${esc}[91mPath does not exist: ${fullPath}${esc}[0m"
                Write-Host "${indent}" -NoNewline
                continue
            }
            
            # Validate type
            if ($Type -eq 'File' -and (Test-Path $fullPath -PathType Container)) {
                Write-Host "${indent}${esc}[91mPath must be a file, not a directory${esc}[0m"
                Write-Host "${indent}" -NoNewline
                continue
            }
            
            if ($Type -eq 'Directory' -and (Test-Path $fullPath -PathType Leaf)) {
                Write-Host "${indent}${esc}[91mPath must be a directory, not a file${esc}[0m"
                Write-Host "${indent}" -NoNewline
                continue
            }
        }
        
        return $fullPath
    }
}

# ═══════════════════════════════════════════════════════════════
#                    SEARCH INPUT
# ═══════════════════════════════════════════════════════════════

function Read-SearchInput {
    <#
    .SYNOPSIS
        Reads search input with real-time filtering
    .PARAMETER Prompt
        Prompt text
    .PARAMETER Items
        Array of searchable items (strings or objects with Name property)
    .PARAMETER MaxResults
        Maximum results to display
    .PARAMETER MinChars
        Minimum characters before searching
    .OUTPUTS
        Selected item or $null if cancelled
    #>
    param(
        [string]$Prompt = 'Search',
        
        [Parameter(Mandatory)]
        [array]$Items,
        
        [int]$MaxResults = 10,
        [int]$MinChars = 1
    )
    
    $esc = [char]27
    $indent = '  '
    
    Write-Host ""
    Write-Host "${indent}${esc}[36m${Prompt}${esc}[0m ${esc}[90m(type to filter, arrows to select)${esc}[0m"
    Write-Host "${indent}> " -NoNewline
    
    $query = ''
    $selectedIndex = 0
    $matches = @()
    $lastMatchCount = 0
    
    Hide-Cursor
    
    try {
        while ($true) {
            # Find matches
            if ($query.Length -ge $MinChars) {
                $matches = @($Items | Where-Object {
                    $name = if ($_ -is [string]) { $_ } else { $_.Name }
                    $name -like "*$query*"
                } | Select-Object -First $MaxResults)
            } else {
                $matches = @()
            }
            
            # Clear previous results
            if ($lastMatchCount -gt 0) {
                for ($i = 0; $i -lt $lastMatchCount; $i++) {
                    Write-Host ""
                    Clear-Line
                    Move-CursorUp
                }
            }
            
            # Display matches
            for ($i = 0; $i -lt $matches.Count; $i++) {
                $name = if ($matches[$i] -is [string]) { $matches[$i] } else { $matches[$i].Name }
                $prefix = if ($i -eq $selectedIndex) { "${esc}[36m❯${esc}[0m" } else { ' ' }
                $text = if ($i -eq $selectedIndex) { "${esc}[1m${name}${esc}[0m" } else { $name }
                Write-Host "`n${indent}  ${prefix} ${text}" -NoNewline
            }
            
            # Show count
            if ($query.Length -ge $MinChars) {
                $totalMatches = ($Items | Where-Object {
                    $name = if ($_ -is [string]) { $_ } else { $_.Name }
                    $name -like "*$query*"
                }).Count
                
                if ($totalMatches -gt $MaxResults) {
                    Write-Host "`n${indent}  ${esc}[90m... and $($totalMatches - $MaxResults) more${esc}[0m" -NoNewline
                    $lastMatchCount = $matches.Count + 1
                } else {
                    $lastMatchCount = $matches.Count
                }
            } else {
                $lastMatchCount = 0
            }
            
            # Move back to input line
            if ($lastMatchCount -gt 0) {
                Move-CursorUp -Lines $lastMatchCount
            }
            Move-CursorToColumn -Column ($indent.Length + 3 + $query.Length)
            
            # Read key
            $key = Read-SingleKey -NoEcho
            
            if (-not $key) { continue }
            
            switch ($key.Name) {
                'Enter' {
                    if ($matches.Count -gt 0 -and $selectedIndex -lt $matches.Count) {
                        # Move cursor down past results
                        Move-CursorDown -Lines ($lastMatchCount + 1)
                        Write-Host ""
                        Show-Cursor
                        return $matches[$selectedIndex]
                    }
                }
                'Escape' {
                    Move-CursorDown -Lines ($lastMatchCount + 1)
                    Write-Host ""
                    Show-Cursor
                    return $null
                }
                'Up' {
                    if ($selectedIndex -gt 0) {
                        $selectedIndex--
                    }
                }
                'Down' {
                    if ($selectedIndex -lt $matches.Count - 1) {
                        $selectedIndex++
                    }
                }
                'Backspace' {
                    if ($query.Length -gt 0) {
                        $query = $query.Substring(0, $query.Length - 1)
                        Write-Host "`b `b" -NoNewline
                        $selectedIndex = 0
                    }
                }
                default {
                    # Add character to query
                    if ($key.Char -and -not [char]::IsControl($key.Char)) {
                        $query += $key.Char
                        Write-Host $key.Char -NoNewline
                        $selectedIndex = 0
                    }
                }
            }
        }
    } finally {
        Show-Cursor
    }
}

# ═══════════════════════════════════════════════════════════════
#                    EXPORT
# ═══════════════════════════════════════════════════════════════

# Export functions if loaded as module (not when dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Read-TextInput'
        'Read-PasswordInput'
        'Read-NumberInput'
        'Show-Confirm'
        'Show-DangerConfirm'
        'Read-Choice'
        'Read-PathInput'
        'Read-SearchInput'
    )
}
