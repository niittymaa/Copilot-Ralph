<#
.SYNOPSIS
    Screen Manager Module for CLI Framework

.DESCRIPTION
    Provides terminal screen management capabilities:
    - Cursor positioning and visibility control
    - Screen clearing and region clearing
    - Viewport and scrolling management
    - Terminal size detection and resize handling
    - Flicker-free screen updates via buffering
    - Alternate screen buffer support
    
    Uses ANSI escape codes for cross-platform compatibility.

.NOTES
    Part of the Ralph CLI Framework
    No external dependencies
#>

# ═══════════════════════════════════════════════════════════════
#                    CONSTANTS
# ═══════════════════════════════════════════════════════════════

$script:ESC = [char]27
$script:CSI = "$([char]27)["

# ═══════════════════════════════════════════════════════════════
#                    TERMINAL SIZE
# ═══════════════════════════════════════════════════════════════

function Get-TerminalSize {
    <#
    .SYNOPSIS
        Gets the current terminal dimensions
    .OUTPUTS
        Hashtable with Width and Height properties
    #>
    
    try {
        return @{
            Width  = [Console]::WindowWidth
            Height = [Console]::WindowHeight
            BufferWidth = [Console]::BufferWidth
            BufferHeight = [Console]::BufferHeight
        }
    } catch {
        # Fallback for non-interactive sessions
        return @{
            Width  = 80
            Height = 24
            BufferWidth = 80
            BufferHeight = 24
        }
    }
}

function Watch-TerminalResize {
    <#
    .SYNOPSIS
        Monitors for terminal resize events
    .PARAMETER Callback
        ScriptBlock to call when resize is detected
    .PARAMETER CheckInterval
        Interval in milliseconds between size checks
    .OUTPUTS
        Job object that can be stopped to end monitoring
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Callback,
        
        [int]$CheckInterval = 100
    )
    
    $lastSize = Get-TerminalSize
    
    $job = Start-Job -ScriptBlock {
        param($interval, $lastWidth, $lastHeight)
        
        while ($true) {
            $current = @{
                Width = [Console]::WindowWidth
                Height = [Console]::WindowHeight
            }
            
            if ($current.Width -ne $lastWidth -or $current.Height -ne $lastHeight) {
                # Signal resize
                Write-Output "RESIZE:$($current.Width):$($current.Height)"
                $lastWidth = $current.Width
                $lastHeight = $current.Height
            }
            
            Start-Sleep -Milliseconds $interval
        }
    } -ArgumentList $CheckInterval, $lastSize.Width, $lastSize.Height
    
    return $job
}

# ═══════════════════════════════════════════════════════════════
#                    CURSOR CONTROL
# ═══════════════════════════════════════════════════════════════

function Set-CursorPosition {
    <#
    .SYNOPSIS
        Moves the cursor to specified position
    .PARAMETER X
        Column (1-based)
    .PARAMETER Y
        Row (1-based)
    #>
    param(
        [Parameter(Mandatory)]
        [int]$X,
        
        [Parameter(Mandatory)]
        [int]$Y
    )
    
    Write-Host "${script:CSI}${Y};${X}H" -NoNewline
}

function Move-CursorUp {
    <#
    .SYNOPSIS
        Moves cursor up by specified number of lines
    #>
    param([int]$Lines = 1)
    
    if ($Lines -gt 0) {
        Write-Host "${script:CSI}${Lines}A" -NoNewline
    }
}

function Move-CursorDown {
    <#
    .SYNOPSIS
        Moves cursor down by specified number of lines
    #>
    param([int]$Lines = 1)
    
    if ($Lines -gt 0) {
        Write-Host "${script:CSI}${Lines}B" -NoNewline
    }
}

function Move-CursorRight {
    <#
    .SYNOPSIS
        Moves cursor right by specified number of columns
    #>
    param([int]$Columns = 1)
    
    if ($Columns -gt 0) {
        Write-Host "${script:CSI}${Columns}C" -NoNewline
    }
}

function Move-CursorLeft {
    <#
    .SYNOPSIS
        Moves cursor left by specified number of columns
    #>
    param([int]$Columns = 1)
    
    if ($Columns -gt 0) {
        Write-Host "${script:CSI}${Columns}D" -NoNewline
    }
}

function Move-CursorToColumn {
    <#
    .SYNOPSIS
        Moves cursor to specified column on current line
    #>
    param([int]$Column = 1)
    
    Write-Host "${script:CSI}${Column}G" -NoNewline
}

function Save-CursorPosition {
    <#
    .SYNOPSIS
        Saves the current cursor position
    #>
    Write-Host "${script:CSI}s" -NoNewline
}

function Restore-CursorPosition {
    <#
    .SYNOPSIS
        Restores the previously saved cursor position
    #>
    Write-Host "${script:CSI}u" -NoNewline
}

function Hide-Cursor {
    <#
    .SYNOPSIS
        Hides the cursor
    #>
    Write-Host "${script:CSI}?25l" -NoNewline
}

function Show-Cursor {
    <#
    .SYNOPSIS
        Shows the cursor
    #>
    Write-Host "${script:CSI}?25h" -NoNewline
}

# ═══════════════════════════════════════════════════════════════
#                    SCREEN CLEARING
# ═══════════════════════════════════════════════════════════════

function Clear-Screen {
    <#
    .SYNOPSIS
        Clears the entire screen
    .PARAMETER ResetCursor
        If true, also moves cursor to top-left
    #>
    param(
        [switch]$ResetCursor
    )
    
    # Use .NET Console API for reliable clearing
    try {
        [Console]::Clear()
    } catch {
        # Fallback to ANSI if Console.Clear() fails (e.g., in redirected output)
        if ($ResetCursor) {
            Write-Host "${script:CSI}2J${script:CSI}H" -NoNewline
        } else {
            Write-Host "${script:CSI}2J" -NoNewline
        }
        [Console]::Out.Flush()
    }
}

function Clear-ScreenFromCursor {
    <#
    .SYNOPSIS
        Clears screen from cursor to end
    #>
    Write-Host "${script:CSI}0J" -NoNewline
}

function Clear-ScreenToCursor {
    <#
    .SYNOPSIS
        Clears screen from beginning to cursor
    #>
    Write-Host "${script:CSI}1J" -NoNewline
}

function Clear-Line {
    <#
    .SYNOPSIS
        Clears the current line
    #>
    Write-Host "${script:CSI}2K" -NoNewline
}

function Clear-LineFromCursor {
    <#
    .SYNOPSIS
        Clears from cursor to end of line
    #>
    Write-Host "${script:CSI}0K" -NoNewline
}

function Clear-LineToCursor {
    <#
    .SYNOPSIS
        Clears from beginning of line to cursor
    #>
    Write-Host "${script:CSI}1K" -NoNewline
}

function Clear-Lines {
    <#
    .SYNOPSIS
        Clears multiple lines starting from current position
    .PARAMETER Count
        Number of lines to clear
    #>
    param(
        [Parameter(Mandatory)]
        [int]$Count
    )
    
    for ($i = 0; $i -lt $Count; $i++) {
        Clear-Line
        if ($i -lt $Count - 1) {
            Move-CursorDown
            Move-CursorToColumn -Column 1
        }
    }
    
    # Return to starting position
    if ($Count -gt 1) {
        Move-CursorUp -Lines ($Count - 1)
    }
    Move-CursorToColumn -Column 1
}

# ═══════════════════════════════════════════════════════════════
#                    ALTERNATE SCREEN BUFFER
# ═══════════════════════════════════════════════════════════════

function Enter-AlternateScreen {
    <#
    .SYNOPSIS
        Switches to alternate screen buffer (preserves main screen content)
    #>
    Write-Host "${script:CSI}?1049h" -NoNewline
    Clear-Screen -ResetCursor
}

function Exit-AlternateScreen {
    <#
    .SYNOPSIS
        Returns to main screen buffer
    #>
    Write-Host "${script:CSI}?1049l" -NoNewline
}

# ═══════════════════════════════════════════════════════════════
#                    SCROLLING
# ═══════════════════════════════════════════════════════════════

function Set-ScrollRegion {
    <#
    .SYNOPSIS
        Sets the scrolling region
    .PARAMETER Top
        Top row of scroll region (1-based)
    .PARAMETER Bottom
        Bottom row of scroll region (1-based)
    #>
    param(
        [Parameter(Mandatory)]
        [int]$Top,
        
        [Parameter(Mandatory)]
        [int]$Bottom
    )
    
    Write-Host "${script:CSI}${Top};${Bottom}r" -NoNewline
}

function Reset-ScrollRegion {
    <#
    .SYNOPSIS
        Resets scroll region to full screen
    #>
    $size = Get-TerminalSize
    Write-Host "${script:CSI}1;$($size.Height)r" -NoNewline
}

function Scroll-Up {
    <#
    .SYNOPSIS
        Scrolls content up by specified lines
    #>
    param([int]$Lines = 1)
    
    if ($Lines -gt 0) {
        Write-Host "${script:CSI}${Lines}S" -NoNewline
    }
}

function Scroll-Down {
    <#
    .SYNOPSIS
        Scrolls content down by specified lines
    #>
    param([int]$Lines = 1)
    
    if ($Lines -gt 0) {
        Write-Host "${script:CSI}${Lines}T" -NoNewline
    }
}

# ═══════════════════════════════════════════════════════════════
#                    BUFFERED RENDERING
# ═══════════════════════════════════════════════════════════════

$script:RenderBuffer = [System.Text.StringBuilder]::new()
$script:BufferingEnabled = $false

function Start-BufferedRender {
    <#
    .SYNOPSIS
        Starts buffered rendering mode for flicker-free updates
    .DESCRIPTION
        All output is collected in a buffer and rendered at once
        when Stop-BufferedRender is called.
    #>
    $script:RenderBuffer.Clear() | Out-Null
    $script:BufferingEnabled = $true
    Hide-Cursor
}

function Write-Buffered {
    <#
    .SYNOPSIS
        Writes content to the render buffer or screen
    .PARAMETER Text
        Text to write
    .PARAMETER NoNewline
        Don't add newline at end
    #>
    param(
        [string]$Text,
        [switch]$NoNewline
    )
    
    if ($script:BufferingEnabled) {
        $script:RenderBuffer.Append($Text) | Out-Null
        if (-not $NoNewline) {
            $script:RenderBuffer.AppendLine() | Out-Null
        }
    } else {
        if ($NoNewline) {
            Write-Host $Text -NoNewline
        } else {
            Write-Host $Text
        }
    }
}

function Stop-BufferedRender {
    <#
    .SYNOPSIS
        Flushes the render buffer to screen
    .PARAMETER ShowCursor
        Show cursor after rendering (default: true)
    #>
    param(
        [switch]$HideCursor
    )
    
    if ($script:BufferingEnabled) {
        Write-Host $script:RenderBuffer.ToString() -NoNewline
        $script:RenderBuffer.Clear() | Out-Null
        $script:BufferingEnabled = $false
    }
    
    if (-not $HideCursor) {
        Show-Cursor
    }
}

# ═══════════════════════════════════════════════════════════════
#                    VIEWPORT MANAGEMENT
# ═══════════════════════════════════════════════════════════════

function New-Viewport {
    <#
    .SYNOPSIS
        Creates a viewport for scrollable content
    .PARAMETER Items
        Total number of items
    .PARAMETER VisibleHeight
        Number of visible rows
    .PARAMETER StartIndex
        Initial scroll position
    .OUTPUTS
        Viewport state hashtable
    #>
    param(
        [Parameter(Mandatory)]
        [int]$Items,
        
        [Parameter(Mandatory)]
        [int]$VisibleHeight,
        
        [int]$StartIndex = 0
    )
    
    return @{
        Items = $Items
        VisibleHeight = $VisibleHeight
        ScrollOffset = [Math]::Max(0, [Math]::Min($StartIndex, $Items - $VisibleHeight))
        SelectedIndex = $StartIndex
    }
}

function Update-Viewport {
    <#
    .SYNOPSIS
        Updates viewport state based on new selection
    .PARAMETER Viewport
        Current viewport state
    .PARAMETER SelectedIndex
        New selected index
    .PARAMETER ScrollMargin
        Lines to keep visible above/below selection
    .OUTPUTS
        Updated viewport state
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Viewport,
        
        [Parameter(Mandatory)]
        [int]$SelectedIndex,
        
        [int]$ScrollMargin = 2
    )
    
    $viewport.SelectedIndex = $SelectedIndex
    
    # Ensure selection is within bounds
    $viewport.SelectedIndex = [Math]::Max(0, [Math]::Min($viewport.SelectedIndex, $viewport.Items - 1))
    
    # Scroll up if needed
    if ($viewport.SelectedIndex -lt $viewport.ScrollOffset + $ScrollMargin) {
        $viewport.ScrollOffset = [Math]::Max(0, $viewport.SelectedIndex - $ScrollMargin)
    }
    
    # Scroll down if needed
    $bottomMargin = $viewport.ScrollOffset + $viewport.VisibleHeight - $ScrollMargin - 1
    if ($viewport.SelectedIndex -gt $bottomMargin) {
        $viewport.ScrollOffset = [Math]::Min(
            $viewport.Items - $viewport.VisibleHeight,
            $viewport.SelectedIndex - $viewport.VisibleHeight + $ScrollMargin + 1
        )
    }
    
    # Ensure scroll offset is valid
    $viewport.ScrollOffset = [Math]::Max(0, $viewport.ScrollOffset)
    
    return $viewport
}

function Get-ViewportRange {
    <#
    .SYNOPSIS
        Gets the visible range of items in viewport
    .PARAMETER Viewport
        Viewport state
    .OUTPUTS
        Hashtable with Start and End indices (inclusive)
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Viewport
    )
    
    $start = $Viewport.ScrollOffset
    $end = [Math]::Min($start + $Viewport.VisibleHeight - 1, $Viewport.Items - 1)
    
    return @{
        Start = $start
        End = $end
        IsScrolledFromTop = $start -gt 0
        IsScrolledFromBottom = $end -lt ($Viewport.Items - 1)
    }
}

# ═══════════════════════════════════════════════════════════════
#                    BOX DRAWING
# ═══════════════════════════════════════════════════════════════

$script:BOX_CHARS = @{
    Light = @{
        TopLeft     = '┌'
        TopRight    = '┐'
        BottomLeft  = '└'
        BottomRight = '┘'
        Horizontal  = '─'
        Vertical    = '│'
        TeeLeft     = '├'
        TeeRight    = '┤'
        TeeTop      = '┬'
        TeeBottom   = '┴'
        Cross       = '┼'
    }
    Heavy = @{
        TopLeft     = '┏'
        TopRight    = '┓'
        BottomLeft  = '┗'
        BottomRight = '┛'
        Horizontal  = '━'
        Vertical    = '┃'
        TeeLeft     = '┣'
        TeeRight    = '┫'
        TeeTop      = '┳'
        TeeBottom   = '┻'
        Cross       = '╋'
    }
    Double = @{
        TopLeft     = '╔'
        TopRight    = '╗'
        BottomLeft  = '╚'
        BottomRight = '╝'
        Horizontal  = '═'
        Vertical    = '║'
        TeeLeft     = '╠'
        TeeRight    = '╣'
        TeeTop      = '╦'
        TeeBottom   = '╩'
        Cross       = '╬'
    }
    Rounded = @{
        TopLeft     = '╭'
        TopRight    = '╮'
        BottomLeft  = '╰'
        BottomRight = '╯'
        Horizontal  = '─'
        Vertical    = '│'
        TeeLeft     = '├'
        TeeRight    = '┤'
        TeeTop      = '┬'
        TeeBottom   = '┴'
        Cross       = '┼'
    }
}

function Get-BoxChars {
    <#
    .SYNOPSIS
        Gets box drawing character set
    .PARAMETER Style
        Box style (Light, Heavy, Double, Rounded)
    #>
    param(
        [ValidateSet('Light', 'Heavy', 'Double', 'Rounded')]
        [string]$Style = 'Light'
    )
    
    return $script:BOX_CHARS[$Style]
}

function Draw-Box {
    <#
    .SYNOPSIS
        Draws a box at current cursor position
    .PARAMETER Width
        Box width
    .PARAMETER Height
        Box height
    .PARAMETER Style
        Box style
    .PARAMETER Title
        Optional title for top border
    #>
    param(
        [Parameter(Mandatory)]
        [int]$Width,
        
        [Parameter(Mandatory)]
        [int]$Height,
        
        [ValidateSet('Light', 'Heavy', 'Double', 'Rounded')]
        [string]$Style = 'Light',
        
        [string]$Title = ''
    )
    
    $chars = Get-BoxChars -Style $Style
    
    # Top border
    $topLine = $chars.TopLeft
    if ($Title) {
        $maxTitleLen = $Width - 4
        if ($Title.Length -gt $maxTitleLen) {
            $Title = $Title.Substring(0, $maxTitleLen - 3) + '...'
        }
        $topLine += $chars.Horizontal + " $Title "
        $remaining = $Width - $Title.Length - 4
        $topLine += ($chars.Horizontal * $remaining)
    } else {
        $topLine += ($chars.Horizontal * ($Width - 2))
    }
    $topLine += $chars.TopRight
    
    Write-Host $topLine
    
    # Side borders
    for ($i = 0; $i -lt $Height - 2; $i++) {
        Write-Host "$($chars.Vertical)$(' ' * ($Width - 2))$($chars.Vertical)"
    }
    
    # Bottom border
    $bottomLine = $chars.BottomLeft + ($chars.Horizontal * ($Width - 2)) + $chars.BottomRight
    Write-Host $bottomLine
}

# ═══════════════════════════════════════════════════════════════
#                    EXPORT
# ═══════════════════════════════════════════════════════════════

# Export functions if loaded as module (not when dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Get-TerminalSize'
        'Watch-TerminalResize'
        'Set-CursorPosition'
        'Move-CursorUp'
        'Move-CursorDown'
        'Move-CursorLeft'
        'Move-CursorRight'
        'Move-CursorToColumn'
        'Save-CursorPosition'
        'Restore-CursorPosition'
        'Hide-Cursor'
        'Show-Cursor'
        'Clear-Screen'
        'Clear-ScreenFromCursor'
        'Clear-ScreenToCursor'
        'Clear-Line'
        'Clear-LineFromCursor'
        'Clear-LineToCursor'
        'Clear-Lines'
        'Enter-AlternateScreen'
        'Exit-AlternateScreen'
        'Set-ScrollRegion'
        'Reset-ScrollRegion'
        'Scroll-Up'
        'Scroll-Down'
        'Start-BufferedRender'
        'Write-Buffered'
        'Stop-BufferedRender'
        'New-Viewport'
        'Update-Viewport'
        'Get-ViewportRange'
        'Get-BoxChars'
        'Draw-Box'
    ) -Variable @(
        'BOX_CHARS'
    )
}
