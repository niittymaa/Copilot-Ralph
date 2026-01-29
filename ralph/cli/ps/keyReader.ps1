<#
.SYNOPSIS
    Key Reader Module for CLI Framework

.DESCRIPTION
    Provides cross-platform keyboard input handling using:
    - System.Console.ReadKey for direct key capture
    - Arrow key detection and translation
    - Modifier key support (Ctrl, Alt, Shift)
    - Non-blocking input detection
    - Input buffering and debouncing
    - Double CTRL+C detection for graceful exit
    
    No external dependencies - uses only built-in .NET/PowerShell features.

.NOTES
    Part of the Ralph CLI Framework
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
#                    KEY CODE CONSTANTS
# ═══════════════════════════════════════════════════════════════

# Named key constants for easy reference
$script:KEY_NAMES = @{
    # Navigation keys
    Up        = 'UpArrow'
    Down      = 'DownArrow'
    Left      = 'LeftArrow'
    Right     = 'RightArrow'
    Home      = 'Home'
    End       = 'End'
    PageUp    = 'PageUp'
    PageDown  = 'PageDown'
    
    # Action keys
    Enter     = 'Enter'
    Escape    = 'Escape'
    Space     = 'Spacebar'
    Tab       = 'Tab'
    Backspace = 'Backspace'
    Delete    = 'Delete'
    Insert    = 'Insert'
    
    # Function keys
    F1  = 'F1'
    F2  = 'F2'
    F3  = 'F3'
    F4  = 'F4'
    F5  = 'F5'
    F6  = 'F6'
    F7  = 'F7'
    F8  = 'F8'
    F9  = 'F9'
    F10 = 'F10'
    F11 = 'F11'
    F12 = 'F12'
}

# Reverse lookup for key detection
$script:KEY_LOOKUP = @{}
foreach ($name in $script:KEY_NAMES.Keys) {
    $script:KEY_LOOKUP[$script:KEY_NAMES[$name]] = $name
}

# ═══════════════════════════════════════════════════════════════
#                    KEY INPUT HANDLING
# ═══════════════════════════════════════════════════════════════

function Read-SingleKey {
    <#
    .SYNOPSIS
        Reads a single keypress from the console
    .PARAMETER NoEcho
        Don't display the pressed key
    .PARAMETER Timeout
        Timeout in milliseconds (0 = infinite)
    .OUTPUTS
        Hashtable with key information:
        - Key: The ConsoleKeyInfo object
        - Name: Friendly key name (e.g., "Up", "Enter", "A")
        - Char: The character (if printable)
        - IsSpecial: True if it's a special key (arrow, function, etc.)
        - Modifiers: Hashtable of modifier states (Ctrl, Alt, Shift)
    #>
    param(
        [switch]$NoEcho,
        [int]$Timeout = 0
    )
    
    # Check for timeout mode
    if ($Timeout -gt 0) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not [Console]::KeyAvailable) {
            if ($stopwatch.ElapsedMilliseconds -ge $Timeout) {
                return $null
            }
            Start-Sleep -Milliseconds 10
        }
    }
    
    # Read the key (intercept = don't echo; always intercept to prevent echo during menu navigation)
    $keyInfo = [Console]::ReadKey($true)
    
    # Build result
    $result = @{
        Key       = $keyInfo
        RawKey    = $keyInfo.Key.ToString()
        Char      = $keyInfo.KeyChar
        IsSpecial = $false
        Modifiers = @{
            Ctrl  = ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) -ne 0
            Alt   = ($keyInfo.Modifiers -band [ConsoleModifiers]::Alt) -ne 0
            Shift = ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) -ne 0
        }
        Name      = $null
    }
    
    # Determine friendly name
    $rawKey = $keyInfo.Key.ToString()
    
    if ($script:KEY_LOOKUP.ContainsKey($rawKey)) {
        $result.Name = $script:KEY_LOOKUP[$rawKey]
        $result.IsSpecial = $true
    } else {
        # For printable characters, use the character itself
        if ($keyInfo.KeyChar -and [char]::IsLetterOrDigit($keyInfo.KeyChar)) {
            $result.Name = $keyInfo.KeyChar.ToString().ToUpper()
        } elseif ($keyInfo.KeyChar -and -not [char]::IsControl($keyInfo.KeyChar)) {
            $result.Name = $keyInfo.KeyChar.ToString()
        } else {
            $result.Name = $rawKey
            $result.IsSpecial = $true
        }
    }
    
    return $result
}

function Test-KeyAvailable {
    <#
    .SYNOPSIS
        Checks if a key is available without blocking
    .OUTPUTS
        $true if a key is waiting to be read
    #>
    return [Console]::KeyAvailable
}

function Clear-InputBuffer {
    <#
    .SYNOPSIS
        Clears any pending key presses from the input buffer
    #>
    while ([Console]::KeyAvailable) {
        $null = [Console]::ReadKey($true)
    }
}

# ═══════════════════════════════════════════════════════════════
#                    KEY MATCHING
# ═══════════════════════════════════════════════════════════════

function Test-KeyMatch {
    <#
    .SYNOPSIS
        Tests if a key event matches a specified key pattern
    .PARAMETER KeyEvent
        Key event from Read-SingleKey
    .PARAMETER Pattern
        Key pattern to match (e.g., "Enter", "Ctrl+C", "Alt+F4", "Q")
    .OUTPUTS
        $true if the key matches the pattern
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$KeyEvent,
        
        [Parameter(Mandatory)]
        [string]$Pattern
    )
    
    if (-not $KeyEvent) { return $false }
    
    $parts = $Pattern -split '\+'
    
    $wantCtrl = $false
    $wantAlt = $false
    $wantShift = $false
    $keyName = $null
    
    foreach ($part in $parts) {
        switch ($part.ToLower()) {
            'ctrl'  { $wantCtrl = $true }
            'alt'   { $wantAlt = $true }
            'shift' { $wantShift = $true }
            default { $keyName = $part }
        }
    }
    
    # Check modifiers
    if ($wantCtrl -ne $KeyEvent.Modifiers.Ctrl) { return $false }
    if ($wantAlt -ne $KeyEvent.Modifiers.Alt) { return $false }
    if ($wantShift -ne $KeyEvent.Modifiers.Shift) { return $false }
    
    # Check key name (case-insensitive)
    if ($keyName) {
        if ($KeyEvent.Name -and $KeyEvent.Name.ToLower() -eq $keyName.ToLower()) {
            return $true
        }
        if ($KeyEvent.Char -and $KeyEvent.Char.ToString().ToLower() -eq $keyName.ToLower()) {
            return $true
        }
        if ($KeyEvent.RawKey -and $KeyEvent.RawKey.ToLower() -eq $keyName.ToLower()) {
            return $true
        }
    }
    
    return $false
}

function Get-KeyAction {
    <#
    .SYNOPSIS
        Maps a key event to an action based on a key binding table
    .PARAMETER KeyEvent
        Key event from Read-SingleKey
    .PARAMETER Bindings
        Hashtable of key patterns to action names
    .OUTPUTS
        Action name if matched, $null otherwise
    .EXAMPLE
        $bindings = @{
            'Enter' = 'select'
            'Escape' = 'cancel'
            'Up' = 'previous'
            'Down' = 'next'
            'Ctrl+C' = 'quit'
        }
        $action = Get-KeyAction -KeyEvent $key -Bindings $bindings
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$KeyEvent,
        
        [Parameter(Mandatory)]
        [hashtable]$Bindings
    )
    
    foreach ($pattern in $Bindings.Keys) {
        if (Test-KeyMatch -KeyEvent $KeyEvent -Pattern $pattern) {
            return $Bindings[$pattern]
        }
    }
    
    return $null
}

# ═══════════════════════════════════════════════════════════════
#                    SPECIALIZED READERS
# ═══════════════════════════════════════════════════════════════

function Read-NavigationKey {
    <#
    .SYNOPSIS
        Reads a navigation key (arrow keys, enter, escape)
    .PARAMETER AllowChars
        Optional string of allowed character keys (e.g., "qhy" for quit/help/yes)
    .PARAMETER Timeout
        Timeout in milliseconds (0 = infinite)
    .OUTPUTS
        Action string: 'up', 'down', 'left', 'right', 'select', 'cancel', 'home', 'end',
        or the pressed character if in AllowChars
    #>
    param(
        [string]$AllowChars = '',
        [int]$Timeout = 0
    )
    
    $key = Read-SingleKey -NoEcho -Timeout $Timeout
    
    if (-not $key) { return $null }
    
    # Navigation keys
    switch ($key.Name) {
        'Up'       { return 'up' }
        'Down'     { return 'down' }
        'Left'     { return 'left' }
        'Right'    { return 'right' }
        'Enter'    { return 'select' }
        'Escape'   { return 'cancel' }
        'Home'     { return 'home' }
        'End'      { return 'end' }
        'PageUp'   { return 'pageup' }
        'PageDown' { return 'pagedown' }
        'Space'    { return 'space' }
        'Tab'      { return 'tab' }
    }
    
    # Ctrl+C handling with double-press detection
    if ($key.Modifiers.Ctrl -and $key.Char -eq [char]3) {
        if ($script:GlobalKeyHandlerLoaded) {
            $result = Test-DoubleCtrlC
            if ($result -eq 'force-exit') {
                return 'force-exit'
            }
        }
        return 'cancel'
    }
    
    # Check allowed characters
    if ($AllowChars -and $key.Char) {
        $charLower = $key.Char.ToString().ToLower()
        if ($AllowChars.ToLower().Contains($charLower)) {
            return $charLower
        }
    }
    
    # Return character if printable
    if ($key.Char -and -not [char]::IsControl($key.Char)) {
        return $key.Char.ToString().ToLower()
    }
    
    return $null
}

function Read-Confirmation {
    <#
    .SYNOPSIS
        Reads a yes/no confirmation
    .PARAMETER DefaultYes
        If true, pressing Enter defaults to Yes
    .OUTPUTS
        $true for yes, $false for no, $null for cancel
    #>
    param(
        [switch]$DefaultYes
    )
    
    while ($true) {
        $key = Read-SingleKey -NoEcho
        
        if (-not $key) { continue }
        
        $char = $key.Char.ToString().ToLower()
        
        switch ($char) {
            'y' { return $true }
            'n' { return $false }
        }
        
        switch ($key.Name) {
            'Enter' { return $DefaultYes }
            'Escape' { return $null }
        }
        
        # Ctrl+C
        if ($key.Modifiers.Ctrl -and $key.Char -eq [char]3) {
            return $null
        }
    }
}

function Read-LineInput {
    <#
    .SYNOPSIS
        Reads a line of text with basic editing support
    .PARAMETER Prompt
        Optional prompt text
    .PARAMETER Default
        Default value
    .PARAMETER MaxLength
        Maximum input length
    .PARAMETER Mask
        Character to display instead of actual input (for passwords)
    .OUTPUTS
        The entered text or $null if cancelled
    #>
    param(
        [string]$Prompt = '',
        [string]$Default = '',
        [int]$MaxLength = 1000,
        [string]$Mask = ''
    )
    
    if ($Prompt) {
        Write-Host $Prompt -NoNewline
    }
    
    $buffer = [System.Text.StringBuilder]::new($Default)
    $cursor = $buffer.Length
    
    # Display initial value
    if ($Default) {
        $display = if ($Mask) { $Mask * $Default.Length } else { $Default }
        Write-Host $display -NoNewline
    }
    
    while ($true) {
        $key = Read-SingleKey -NoEcho
        
        if (-not $key) { continue }
        
        switch ($key.Name) {
            'Enter' {
                Write-Host ''
                return $buffer.ToString()
            }
            'Escape' {
                Write-Host ''
                return $null
            }
            'Backspace' {
                if ($cursor -gt 0) {
                    $buffer.Remove($cursor - 1, 1)
                    $cursor--
                    # Redraw line
                    Write-Host "`b `b" -NoNewline
                }
            }
            'Delete' {
                if ($cursor -lt $buffer.Length) {
                    $buffer.Remove($cursor, 1)
                    # Redraw from cursor
                    $remaining = $buffer.ToString().Substring($cursor)
                    $display = if ($Mask) { $Mask * $remaining.Length } else { $remaining }
                    Write-Host "$display " -NoNewline
                    Write-Host ("`b" * ($remaining.Length + 1)) -NoNewline
                }
            }
            'Left' {
                if ($cursor -gt 0) {
                    $cursor--
                    Write-Host "`b" -NoNewline
                }
            }
            'Right' {
                if ($cursor -lt $buffer.Length) {
                    $char = if ($Mask) { $Mask } else { $buffer[$cursor] }
                    Write-Host $char -NoNewline
                    $cursor++
                }
            }
            'Home' {
                Write-Host ("`b" * $cursor) -NoNewline
                $cursor = 0
            }
            'End' {
                $remaining = $buffer.ToString().Substring($cursor)
                $display = if ($Mask) { $Mask * $remaining.Length } else { $remaining }
                Write-Host $display -NoNewline
                $cursor = $buffer.Length
            }
            default {
                # Insert printable character
                if ($key.Char -and -not [char]::IsControl($key.Char)) {
                    if ($buffer.Length -lt $MaxLength) {
                        $buffer.Insert($cursor, $key.Char)
                        $cursor++
                        
                        $display = if ($Mask) { $Mask } else { $key.Char }
                        Write-Host $display -NoNewline
                        
                        # Redraw remaining chars if inserting in middle
                        if ($cursor -lt $buffer.Length) {
                            $remaining = $buffer.ToString().Substring($cursor)
                            $display = if ($Mask) { $Mask * $remaining.Length } else { $remaining }
                            Write-Host $display -NoNewline
                            Write-Host ("`b" * $remaining.Length) -NoNewline
                        }
                    }
                }
            }
        }
        
        # Ctrl+C with double-press detection
        if ($key.Modifiers.Ctrl -and $key.Char -eq [char]3) {
            if ($script:GlobalKeyHandlerLoaded) {
                $result = Test-DoubleCtrlC
                if ($result -eq 'force-exit') {
                    Write-Host ''
                    Invoke-ForceExit
                }
            }
            Write-Host ''
            return $null
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                    DEBOUNCING
# ═══════════════════════════════════════════════════════════════

$script:LastKeyTime = [DateTime]::MinValue
$script:DebounceMs = 50

function Set-KeyDebounce {
    <#
    .SYNOPSIS
        Sets the key debounce interval
    .PARAMETER Milliseconds
        Minimum time between key presses
    #>
    param(
        [int]$Milliseconds = 50
    )
    
    $script:DebounceMs = $Milliseconds
}

function Test-KeyDebounced {
    <#
    .SYNOPSIS
        Checks if enough time has passed since last key press
    .OUTPUTS
        $true if debounce period has elapsed
    #>
    $now = [DateTime]::Now
    $elapsed = ($now - $script:LastKeyTime).TotalMilliseconds
    
    if ($elapsed -ge $script:DebounceMs) {
        $script:LastKeyTime = $now
        return $true
    }
    
    return $false
}

# ═══════════════════════════════════════════════════════════════
#                    EXPORT
# ═══════════════════════════════════════════════════════════════

# Export functions if loaded as module (not when dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Read-SingleKey'
        'Test-KeyAvailable'
        'Clear-InputBuffer'
        'Test-KeyMatch'
        'Get-KeyAction'
        'Read-NavigationKey'
        'Read-Confirmation'
        'Read-LineInput'
        'Set-KeyDebounce'
        'Test-KeyDebounced'
    ) -Variable @(
        'KEY_NAMES'
    )
}
