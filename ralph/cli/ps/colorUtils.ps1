<#
.SYNOPSIS
    ANSI Color Utilities for CLI Framework

.DESCRIPTION
    Provides cross-platform ANSI escape code support for:
    - Foreground and background colors (16-color, 256-color, RGB)
    - Text styles (bold, dim, italic, underline, strikethrough)
    - Color detection and terminal capability queries
    - Named color palettes and themes
    
    Works with Windows Terminal, PowerShell 7+, and standard terminals.

.NOTES
    Part of the Ralph CLI Framework
    No external dependencies - uses only built-in PowerShell features
#>

# ═══════════════════════════════════════════════════════════════
#                    ESCAPE CODE CONSTANTS
# ═══════════════════════════════════════════════════════════════

# ANSI escape sequence prefix
$script:ESC = [char]27
$script:CSI = "$([char]27)["

# Reset all attributes
$script:RESET = "${script:CSI}0m"

# ═══════════════════════════════════════════════════════════════
#                    BASIC COLORS (16-color)
# ═══════════════════════════════════════════════════════════════

# Foreground colors (30-37, 90-97)
$script:FG_COLORS = @{
    Black        = "${script:CSI}30m"
    Red          = "${script:CSI}31m"
    Green        = "${script:CSI}32m"
    Yellow       = "${script:CSI}33m"
    Blue         = "${script:CSI}34m"
    Magenta      = "${script:CSI}35m"
    Cyan         = "${script:CSI}36m"
    White        = "${script:CSI}37m"
    Default      = "${script:CSI}39m"
    # Bright/High-intensity colors
    BrightBlack  = "${script:CSI}90m"
    BrightRed    = "${script:CSI}91m"
    BrightGreen  = "${script:CSI}92m"
    BrightYellow = "${script:CSI}93m"
    BrightBlue   = "${script:CSI}94m"
    BrightMagenta= "${script:CSI}95m"
    BrightCyan   = "${script:CSI}96m"
    BrightWhite  = "${script:CSI}97m"
    # Aliases for compatibility
    Gray         = "${script:CSI}90m"
    DarkGray     = "${script:CSI}90m"
    LightGray    = "${script:CSI}37m"
    DarkRed      = "${script:CSI}31m"
    DarkGreen    = "${script:CSI}32m"
    DarkYellow   = "${script:CSI}33m"
    DarkBlue     = "${script:CSI}34m"
    DarkMagenta  = "${script:CSI}35m"
    DarkCyan     = "${script:CSI}36m"
}

# Background colors (40-47, 100-107)
$script:BG_COLORS = @{
    Black        = "${script:CSI}40m"
    Red          = "${script:CSI}41m"
    Green        = "${script:CSI}42m"
    Yellow       = "${script:CSI}43m"
    Blue         = "${script:CSI}44m"
    Magenta      = "${script:CSI}45m"
    Cyan         = "${script:CSI}46m"
    White        = "${script:CSI}47m"
    Default      = "${script:CSI}49m"
    BrightBlack  = "${script:CSI}100m"
    BrightRed    = "${script:CSI}101m"
    BrightGreen  = "${script:CSI}102m"
    BrightYellow = "${script:CSI}103m"
    BrightBlue   = "${script:CSI}104m"
    BrightMagenta= "${script:CSI}105m"
    BrightCyan   = "${script:CSI}106m"
    BrightWhite  = "${script:CSI}107m"
}

# ═══════════════════════════════════════════════════════════════
#                    TEXT STYLES
# ═══════════════════════════════════════════════════════════════

$script:STYLES = @{
    Bold          = "${script:CSI}1m"
    Dim           = "${script:CSI}2m"
    Italic        = "${script:CSI}3m"
    Underline     = "${script:CSI}4m"
    Blink         = "${script:CSI}5m"
    Reverse       = "${script:CSI}7m"
    Hidden        = "${script:CSI}8m"
    Strikethrough = "${script:CSI}9m"
    # Reset individual styles
    NoBold        = "${script:CSI}22m"
    NoDim         = "${script:CSI}22m"
    NoItalic      = "${script:CSI}23m"
    NoUnderline   = "${script:CSI}24m"
    NoBlink       = "${script:CSI}25m"
    NoReverse     = "${script:CSI}27m"
    NoHidden      = "${script:CSI}28m"
    NoStrikethrough = "${script:CSI}29m"
}

# ═══════════════════════════════════════════════════════════════
#                    TERMINAL DETECTION
# ═══════════════════════════════════════════════════════════════

function Test-ColorSupport {
    <#
    .SYNOPSIS
        Detects if the terminal supports ANSI colors
    .OUTPUTS
        Hashtable with color support levels
    #>
    
    $support = @{
        Basic    = $false  # 16 colors
        Extended = $false  # 256 colors
        TrueColor = $false # RGB (16M colors)
        Styles   = $false  # Bold, italic, etc.
    }
    
    # Check for Windows Terminal or modern PowerShell
    if ($env:WT_SESSION -or $env:TERM_PROGRAM -eq 'vscode' -or $PSVersionTable.PSVersion.Major -ge 7) {
        $support.Basic = $true
        $support.Extended = $true
        $support.TrueColor = $true
        $support.Styles = $true
        return $support
    }
    
    # Check TERM environment variable
    $term = $env:TERM
    if ($term) {
        if ($term -match '256color|24bit|truecolor') {
            $support.Basic = $true
            $support.Extended = $true
            $support.TrueColor = $term -match '24bit|truecolor'
            $support.Styles = $true
        } elseif ($term -match 'xterm|vt100|screen|linux|ansi') {
            $support.Basic = $true
            $support.Styles = $true
        }
    }
    
    # Check COLORTERM
    if ($env:COLORTERM -eq 'truecolor' -or $env:COLORTERM -eq '24bit') {
        $support.TrueColor = $true
        $support.Extended = $true
        $support.Basic = $true
    }
    
    # Windows console detection
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        # Modern Windows 10+ consoles support colors
        $osVersion = [Environment]::OSVersion.Version
        if ($osVersion.Major -ge 10) {
            $support.Basic = $true
            $support.Extended = $true
            # Windows Terminal and new console host support true color
            if ($env:WT_SESSION -or $Host.Name -eq 'ConsoleHost') {
                $support.TrueColor = $true
            }
            $support.Styles = $true
        }
    }
    
    return $support
}

function Enable-VirtualTerminal {
    <#
    .SYNOPSIS
        Enables virtual terminal processing on Windows
    .DESCRIPTION
        Required for ANSI escape codes to work in legacy Windows consoles.
        Modern terminals (Windows Terminal, VS Code) don't need this.
    #>
    
    if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
        return $true
    }
    
    # Try to enable VT processing via .NET
    try {
        $kernel32 = Add-Type -Name 'Kernel32' -Namespace 'Win32' -PassThru -MemberDefinition @'
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern IntPtr GetStdHandle(int nStdHandle);
            
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
            
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        
        $STD_OUTPUT_HANDLE = -11
        $ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
        
        $handle = $kernel32::GetStdHandle($STD_OUTPUT_HANDLE)
        $mode = 0
        $null = $kernel32::GetConsoleMode($handle, [ref]$mode)
        $null = $kernel32::SetConsoleMode($handle, $mode -bor $ENABLE_VIRTUAL_TERMINAL_PROCESSING)
        
        return $true
    } catch {
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════
#                    COLOR FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Get-AnsiReset {
    <#
    .SYNOPSIS
        Returns the ANSI reset escape code
    #>
    return $script:RESET
}

function Get-AnsiForeground {
    <#
    .SYNOPSIS
        Gets foreground color escape code
    .PARAMETER Color
        Color name (Black, Red, Green, Yellow, Blue, Magenta, Cyan, White, etc.)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Color
    )
    
    if ($script:FG_COLORS.ContainsKey($Color)) {
        return $script:FG_COLORS[$Color]
    }
    return $script:FG_COLORS['Default']
}

function Get-AnsiBackground {
    <#
    .SYNOPSIS
        Gets background color escape code
    .PARAMETER Color
        Color name
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Color
    )
    
    if ($script:BG_COLORS.ContainsKey($Color)) {
        return $script:BG_COLORS[$Color]
    }
    return $script:BG_COLORS['Default']
}

function Get-AnsiStyle {
    <#
    .SYNOPSIS
        Gets style escape code
    .PARAMETER Style
        Style name (Bold, Dim, Italic, Underline, etc.)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Style
    )
    
    if ($script:STYLES.ContainsKey($Style)) {
        return $script:STYLES[$Style]
    }
    return ''
}

function Get-Ansi256Color {
    <#
    .SYNOPSIS
        Gets 256-color foreground escape code
    .PARAMETER ColorIndex
        Color index (0-255)
    .PARAMETER Background
        If true, returns background color instead
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int]$ColorIndex,
        
        [switch]$Background
    )
    
    $code = if ($Background) { 48 } else { 38 }
    return "${script:CSI}${code};5;${ColorIndex}m"
}

function Get-AnsiRgbColor {
    <#
    .SYNOPSIS
        Gets RGB true color escape code
    .PARAMETER Red
        Red component (0-255)
    .PARAMETER Green
        Green component (0-255)
    .PARAMETER Blue
        Blue component (0-255)
    .PARAMETER Background
        If true, returns background color instead
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int]$Red,
        
        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int]$Green,
        
        [Parameter(Mandatory)]
        [ValidateRange(0, 255)]
        [int]$Blue,
        
        [switch]$Background
    )
    
    $code = if ($Background) { 48 } else { 38 }
    return "${script:CSI}${code};2;${Red};${Green};${Blue}m"
}

function Get-AnsiHexColor {
    <#
    .SYNOPSIS
        Gets RGB color from hex string
    .PARAMETER Hex
        Hex color string (e.g., "#FF5500" or "FF5500")
    .PARAMETER Background
        If true, returns background color
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Hex,
        
        [switch]$Background
    )
    
    $hex = $Hex -replace '^#', ''
    
    if ($hex.Length -eq 3) {
        $hex = "$($hex[0])$($hex[0])$($hex[1])$($hex[1])$($hex[2])$($hex[2])"
    }
    
    if ($hex.Length -ne 6) {
        return ''
    }
    
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
    
    return Get-AnsiRgbColor -Red $r -Green $g -Blue $b -Background:$Background
}

# ═══════════════════════════════════════════════════════════════
#                    TEXT FORMATTING
# ═══════════════════════════════════════════════════════════════

function Format-AnsiText {
    <#
    .SYNOPSIS
        Formats text with ANSI escape codes
    .PARAMETER Text
        Text to format
    .PARAMETER ForegroundColor
        Foreground color name
    .PARAMETER BackgroundColor
        Background color name
    .PARAMETER Bold
        Apply bold style
    .PARAMETER Dim
        Apply dim style
    .PARAMETER Italic
        Apply italic style
    .PARAMETER Underline
        Apply underline style
    .PARAMETER Strikethrough
        Apply strikethrough style
    .PARAMETER NoReset
        Don't append reset code at end
    .OUTPUTS
        Formatted string with ANSI codes
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        
        [string]$ForegroundColor,
        [string]$BackgroundColor,
        [switch]$Bold,
        [switch]$Dim,
        [switch]$Italic,
        [switch]$Underline,
        [switch]$Strikethrough,
        [switch]$NoReset
    )
    
    $prefix = ''
    
    # Apply styles
    if ($Bold) { $prefix += $script:STYLES['Bold'] }
    if ($Dim) { $prefix += $script:STYLES['Dim'] }
    if ($Italic) { $prefix += $script:STYLES['Italic'] }
    if ($Underline) { $prefix += $script:STYLES['Underline'] }
    if ($Strikethrough) { $prefix += $script:STYLES['Strikethrough'] }
    
    # Apply colors
    if ($ForegroundColor) {
        $prefix += Get-AnsiForeground -Color $ForegroundColor
    }
    if ($BackgroundColor) {
        $prefix += Get-AnsiBackground -Color $BackgroundColor
    }
    
    $suffix = if ($NoReset) { '' } else { $script:RESET }
    
    return "${prefix}${Text}${suffix}"
}

# ═══════════════════════════════════════════════════════════════
#                    GRADIENT & EFFECTS
# ═══════════════════════════════════════════════════════════════

function Get-GradientText {
    <#
    .SYNOPSIS
        Creates gradient text effect using RGB colors
    .PARAMETER Text
        Text to apply gradient to
    .PARAMETER StartColor
        Starting RGB color as hashtable @{R=255; G=0; B=0}
    .PARAMETER EndColor
        Ending RGB color as hashtable @{R=0; G=0; B=255}
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        
        [Parameter(Mandatory)]
        [hashtable]$StartColor,
        
        [Parameter(Mandatory)]
        [hashtable]$EndColor
    )
    
    $result = ''
    $length = $Text.Length
    
    if ($length -eq 0) { return '' }
    
    for ($i = 0; $i -lt $length; $i++) {
        $ratio = if ($length -gt 1) { $i / ($length - 1) } else { 0 }
        
        $r = [int]($StartColor.R + ($EndColor.R - $StartColor.R) * $ratio)
        $g = [int]($StartColor.G + ($EndColor.G - $StartColor.G) * $ratio)
        $b = [int]($StartColor.B + ($EndColor.B - $StartColor.B) * $ratio)
        
        $colorCode = Get-AnsiRgbColor -Red $r -Green $g -Blue $b
        $result += "${colorCode}$($Text[$i])"
    }
    
    return $result + $script:RESET
}

# ═══════════════════════════════════════════════════════════════
#                    COLOR PALETTES
# ═══════════════════════════════════════════════════════════════

$script:PALETTES = @{
    Default = @{
        Primary   = 'Cyan'
        Secondary = 'Magenta'
        Success   = 'Green'
        Warning   = 'Yellow'
        Error     = 'Red'
        Info      = 'Blue'
        Muted     = 'DarkGray'
        Highlight = 'BrightWhite'
    }
    Ocean = @{
        Primary   = 'Cyan'
        Secondary = 'Blue'
        Success   = 'Green'
        Warning   = 'Yellow'
        Error     = 'Red'
        Info      = 'BrightCyan'
        Muted     = 'DarkCyan'
        Highlight = 'BrightWhite'
    }
    Forest = @{
        Primary   = 'Green'
        Secondary = 'Yellow'
        Success   = 'BrightGreen'
        Warning   = 'Yellow'
        Error     = 'Red'
        Info      = 'Cyan'
        Muted     = 'DarkGreen'
        Highlight = 'BrightWhite'
    }
    Sunset = @{
        Primary   = 'Magenta'
        Secondary = 'Yellow'
        Success   = 'Green'
        Warning   = 'BrightYellow'
        Error     = 'BrightRed'
        Info      = 'BrightMagenta'
        Muted     = 'DarkMagenta'
        Highlight = 'BrightWhite'
    }
}

$script:CurrentPalette = 'Default'

function Set-ColorPalette {
    <#
    .SYNOPSIS
        Sets the active color palette
    .PARAMETER Name
        Palette name (Default, Ocean, Forest, Sunset)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    if ($script:PALETTES.ContainsKey($Name)) {
        $script:CurrentPalette = $Name
    }
}

function Get-PaletteColor {
    <#
    .SYNOPSIS
        Gets a color from the current palette
    .PARAMETER Role
        Color role (Primary, Secondary, Success, Warning, Error, Info, Muted, Highlight)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Role
    )
    
    $palette = $script:PALETTES[$script:CurrentPalette]
    if ($palette.ContainsKey($Role)) {
        return $palette[$Role]
    }
    return 'White'
}

# ═══════════════════════════════════════════════════════════════
#                    INITIALIZATION
# ═══════════════════════════════════════════════════════════════

# Auto-enable virtual terminal on Windows
$null = Enable-VirtualTerminal

# Export functions if loaded as module (not when dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Test-ColorSupport'
        'Enable-VirtualTerminal'
        'Get-AnsiReset'
        'Get-AnsiForeground'
        'Get-AnsiBackground'
        'Get-AnsiStyle'
        'Get-Ansi256Color'
        'Get-AnsiRgbColor'
        'Get-AnsiHexColor'
        'Format-AnsiText'
        'Get-GradientText'
        'Set-ColorPalette'
        'Get-PaletteColor'
    ) -Variable @(
        'ESC'
        'CSI'
        'RESET'
        'FG_COLORS'
        'BG_COLORS'
        'STYLES'
        'PALETTES'
    )
}
