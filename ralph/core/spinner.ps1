<#
.SYNOPSIS
    Animated spinner and progress indicator for Ralph Loop

.DESCRIPTION
    Provides visual feedback during long-running operations:
    - Animated spinner for "working" state
    - Progress dots for ongoing operations
    - Braille animation patterns
    - Status line updates without scrolling
#>

# ═══════════════════════════════════════════════════════════════
#                    SPINNER CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:SpinnerActive = $false
$script:SpinnerMessage = ""
$script:SpinnerStartTime = $null
$script:SpinnerFrameIndex = 0

# Spinner animation frames (multiple styles available)
$script:SpinnerStyles = @{
    Dots    = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    Line    = @('|', '/', '-', '\')
    Circle  = @('◐', '◓', '◑', '◒')
    Arrows  = @('←', '↖', '↑', '↗', '→', '↘', '↓', '↙')
    Bounce  = @('⠁', '⠂', '⠄', '⠂')
    Grow    = @('▁', '▂', '▃', '▄', '▅', '▆', '▇', '█', '▇', '▆', '▅', '▄', '▃', '▂')
    Pulse   = @('█', '▓', '▒', '░', '▒', '▓')
}

# Default style
$script:SpinnerFrames = $script:SpinnerStyles.Dots

# ═══════════════════════════════════════════════════════════════
#                    SPINNER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Set-SpinnerStyle {
    <#
    .SYNOPSIS
        Sets the spinner animation style
    .PARAMETER Style
        One of: Dots, Line, Circle, Arrows, Bounce, Grow, Pulse
    #>
    param(
        [ValidateSet('Dots', 'Line', 'Circle', 'Arrows', 'Bounce', 'Grow', 'Pulse')]
        [string]$Style = 'Dots'
    )
    
    $script:SpinnerFrames = $script:SpinnerStyles[$Style]
}

function Write-SpinnerFrame {
    <#
    .SYNOPSIS
        Writes a single spinner frame with elapsed time
    #>
    if (-not $script:SpinnerActive) { return }
    
    $frame = $script:SpinnerFrames[$script:SpinnerFrameIndex % $script:SpinnerFrames.Count]
    $elapsed = [int]((Get-Date) - $script:SpinnerStartTime).TotalSeconds
    $minutes = [int][math]::Floor($elapsed / 60)
    $seconds = [int]($elapsed % 60)
    $time = "{0:D2}:{1:D2}" -f $minutes, $seconds
    
    # Build status line with ANSI codes
    $cyan = "$([char]27)[36m"
    $gray = "$([char]27)[90m"
    $reset = "$([char]27)[0m"
    
    $status = "`r  $cyan$frame$reset $($script:SpinnerMessage) $gray[$time]$reset  "
    Write-Host $status -NoNewline
    
    $script:SpinnerFrameIndex++
}

function Stop-Spinner {
    <#
    .SYNOPSIS
        Stops the spinner and optionally shows a completion message
    .PARAMETER FinalMessage
        Optional message to display when spinner stops
    .PARAMETER Success
        If true, shows green checkmark; if false, shows red X
    #>
    param(
        [string]$FinalMessage = "",
        [bool]$Success = $true
    )
    
    if (-not $script:SpinnerActive) { return }
    
    $script:SpinnerActive = $false
    
    # Clear the spinner line
    Write-Host "`r$(' ' * 80)`r" -NoNewline
    
    # Show cursor again
    Write-Host "$([char]27)[?25h" -NoNewline
    
    if ($FinalMessage) {
        $green = "$([char]27)[32m"
        $red = "$([char]27)[31m"
        $reset = "$([char]27)[0m"
        $icon = if ($Success) { "$green✓$reset" } else { "$red✗$reset" }
        Write-Host "  $icon $FinalMessage"
    }
}

function Invoke-CommandWithSpinner {
    <#
    .SYNOPSIS
        Executes a command with an animated spinner
    .DESCRIPTION
        Runs the command as a background job while displaying an animated spinner.
        This allows the spinner to animate while the command executes.
    .PARAMETER Command
        The command/executable to run
    .PARAMETER Arguments
        Array of arguments for the command
    .PARAMETER Message
        Message to display next to the spinner
    .OUTPUTS
        Hashtable with Success, Output, Duration
    #>
    param(
        [string]$Command,
        [string[]]$Arguments,
        [string]$Message = "Working..."
    )
    
    # Hide cursor
    Write-Host "$([char]27)[?25l" -NoNewline
    
    # Initialize spinner state
    $script:SpinnerActive = $true
    $script:SpinnerMessage = $Message
    $script:SpinnerStartTime = Get-Date
    $script:SpinnerFrameIndex = 0
    
    # Build command string for the job
    $argString = ($Arguments | ForEach-Object { 
        if ($_ -match '\s') { "`"$_`"" } else { $_ }
    }) -join ' '
    
    # Start the command as a background job
    $job = Start-Job -ScriptBlock {
        param($cmd, $args)
        try {
            $output = & $cmd @args 2>&1
            @{
                Success = $true
                Output = ($output | Out-String).Trim()
            }
        }
        catch {
            @{
                Success = $false
                Output = $_.ToString()
            }
        }
    } -ArgumentList $Command, $Arguments
    
    # Animate spinner while job runs
    while ($job.State -eq 'Running') {
        Write-SpinnerFrame
        Start-Sleep -Milliseconds 100
    }
    
    # Get job result
    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force
    
    $duration = (Get-Date) - $script:SpinnerStartTime
    
    # Stop spinner with result
    if ($result.Success) {
        Stop-Spinner -FinalMessage "Completed in $([math]::Round($duration.TotalSeconds, 1))s" -Success $true
    } else {
        Stop-Spinner -FinalMessage "Failed after $([math]::Round($duration.TotalSeconds, 1))s" -Success $false
    }
    
    return @{
        Success  = $result.Success
        Output   = $result.Output
        Duration = $duration
    }
}

function Show-Progress {
    <#
    .SYNOPSIS
        Shows a progress bar with percentage
    .PARAMETER Current
        Current progress value
    .PARAMETER Total
        Total value for 100%
    .PARAMETER Message
        Optional message to display
    #>
    param(
        [int]$Current,
        [int]$Total,
        [string]$Message = ""
    )
    
    $percent = if ($Total -gt 0) { [math]::Round(($Current / $Total) * 100) } else { 0 }
    $barWidth = 30
    $filled = [math]::Round(($percent / 100) * $barWidth)
    $empty = $barWidth - $filled
    
    $bar = "█" * $filled + "░" * $empty
    $status = "`r  $([char]27)[36m[$bar]$([char]27)[0m $percent% $Message  "
    
    Write-Host $status -NoNewline
}

function Complete-Progress {
    <#
    .SYNOPSIS
        Completes and clears the progress bar
    .PARAMETER Message
        Final message to display
    #>
    param([string]$Message = "Done")
    
    Write-Host "`r$(' ' * 80)`r" -NoNewline
    Write-Host "  $([char]27)[32m✓$([char]27)[0m $Message"
}

# ═══════════════════════════════════════════════════════════════
#                    STATUS LINE FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Write-StatusLine {
    <#
    .SYNOPSIS
        Writes a status line that can be updated in place
    .PARAMETER Message
        Status message to display
    .PARAMETER Type
        Type of status: info, success, warning, working
    #>
    param(
        [string]$Message,
        [ValidateSet('info', 'success', 'warning', 'working')]
        [string]$Type = 'info'
    )
    
    $icon = switch ($Type) {
        'success' { "$([char]27)[32m✓$([char]27)[0m" }
        'warning' { "$([char]27)[33m!$([char]27)[0m" }
        'working' { "$([char]27)[36m●$([char]27)[0m" }
        default   { "$([char]27)[90m→$([char]27)[0m" }
    }
    
    Write-Host "`r$(' ' * 80)`r  $icon $Message" -NoNewline
    
    if ($Type -ne 'working') {
        Write-Host ""  # New line for non-working status
    }
}

function Clear-StatusLine {
    <#
    .SYNOPSIS
        Clears the current status line
    #>
    Write-Host "`r$(' ' * 80)`r" -NoNewline
}

# ═══════════════════════════════════════════════════════════════
#                    ACTIVITY INDICATOR
# ═══════════════════════════════════════════════════════════════

$script:ActivityDots = 0
$script:ActivityMax = 5

function Show-Activity {
    <#
    .SYNOPSIS
        Shows animated dots to indicate activity
    .PARAMETER Message
        Base message (dots are appended)
    #>
    param([string]$Message = "Working")
    
    $script:ActivityDots = ($script:ActivityDots + 1) % ($script:ActivityMax + 1)
    $dots = "." * $script:ActivityDots
    $padding = " " * ($script:ActivityMax - $script:ActivityDots)
    
    Write-Host "`r  $([char]27)[36m●$([char]27)[0m $Message$dots$padding" -NoNewline
}

function Reset-Activity {
    <#
    .SYNOPSIS
        Resets the activity indicator
    #>
    $script:ActivityDots = 0
    Clear-StatusLine
}

# Note: When dot-sourced (. spinner.ps1), all functions are automatically available.
# Export-ModuleMember is only needed when using Import-Module.
