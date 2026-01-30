<#
.SYNOPSIS
    Global Keyboard Handler for Ralph CLI Framework

.DESCRIPTION
    Provides centralized keyboard event handling with:
    - Double CTRL+C detection for graceful exit
    - ESC triggers interrupt menu with 3 options
    - Consistent key action mapping
    - Global exit management
    - Integration with interrupt handler

.NOTES
    Part of the Ralph CLI Framework
    Follows CLI best practices for keyboard handling
#>

# ═══════════════════════════════════════════════════════════════
#                    GLOBAL STATE
# ═══════════════════════════════════════════════════════════════

$script:LastCtrlCTime = [DateTime]::MinValue
$script:CtrlCThresholdMs = 2000  # 2 seconds to press CTRL+C twice
$script:ExitRequested = $false

# ═══════════════════════════════════════════════════════════════
#                    INTERRUPT HANDLER INTEGRATION
# ═══════════════════════════════════════════════════════════════

# Load interrupt handler if available
$script:InterruptHandlerLoaded = $false
$interruptHandlerPath = Join-Path $PSScriptRoot 'interruptHandler.ps1'
if (Test-Path $interruptHandlerPath) {
    try {
        . $interruptHandlerPath
        $script:InterruptHandlerLoaded = $true
    } catch {
        $script:InterruptHandlerLoaded = $false
    }
}

# ═══════════════════════════════════════════════════════════════
#                    CTRL+C HANDLER
# ═══════════════════════════════════════════════════════════════

function Initialize-GlobalKeyHandler {
    <#
    .SYNOPSIS
        Initializes the global keyboard handler
    .DESCRIPTION
        Sets up CTRL+C handling to require double-press for exit.
        First CTRL+C is available for copy operations.
        Also initializes interrupt handler state.
    #>
    param()
    
    # Allow CTRL+C to be captured by our handler
    [Console]::TreatControlCAsInput = $true
    
    # Reset state
    $script:LastCtrlCTime = [DateTime]::MinValue
    $script:ExitRequested = $false
    
    # Reset interrupt handler state if available
    if ($script:InterruptHandlerLoaded -and (Get-Command Reset-InterruptState -ErrorAction SilentlyContinue)) {
        Reset-InterruptState
    }
    
    Write-Verbose "Global keyboard handler initialized"
}

function Reset-CtrlCHandler {
    <#
    .SYNOPSIS
        Resets CTRL+C handler to default behavior
    #>
    [Console]::TreatControlCAsInput = $false
    $script:ExitRequested = $false
    
    # Reset interrupt handler state if available
    if ($script:InterruptHandlerLoaded -and (Get-Command Reset-InterruptState -ErrorAction SilentlyContinue)) {
        Reset-InterruptState
    }
}

function Test-DoubleCtrlC {
    <#
    .SYNOPSIS
        Tests if CTRL+C was pressed twice within threshold
    .DESCRIPTION
        First press: Returns 'cancel' (allows menu cancel/clipboard copy)
        Second press (within 2s): Returns 'force-exit' (terminates app)
    .OUTPUTS
        'cancel' or 'force-exit'
    #>
    param()
    
    $now = [DateTime]::Now
    $elapsed = ($now - $script:LastCtrlCTime).TotalMilliseconds
    
    if ($elapsed -le $script:CtrlCThresholdMs) {
        # Second CTRL+C within threshold - force exit
        $script:ExitRequested = $true
        return 'force-exit'
    } else {
        # First CTRL+C - just cancel
        $script:LastCtrlCTime = $now
        return 'cancel'
    }
}

function Test-ExitRequested {
    <#
    .SYNOPSIS
        Checks if exit has been requested
    .OUTPUTS
        $true if CTRL+C was pressed twice
    #>
    return $script:ExitRequested
}

function Invoke-ForceExit {
    <#
    .SYNOPSIS
        Handles forced exit with cleanup
    .PARAMETER Message
        Optional exit message
    .PARAMETER ExitCode
        Exit code (default 0)
    #>
    param(
        [string]$Message = "Exiting Ralph...",
        [int]$ExitCode = 0
    )
    
    $esc = [char]27
    Write-Host ""
    Write-Host "${esc}[33m${Message}${esc}[0m"
    
    # Cleanup
    Reset-CtrlCHandler
    Show-Cursor
    
    exit $ExitCode
}

# ═══════════════════════════════════════════════════════════════
#                    KEY ACTION STANDARDIZATION
# ═══════════════════════════════════════════════════════════════

$script:StandardKeyActions = @{
    # Navigation
    'up'       = 'navigate-up'
    'down'     = 'navigate-down'
    'left'     = 'navigate-left'
    'right'    = 'navigate-right'
    'home'     = 'navigate-home'
    'end'      = 'navigate-end'
    'pageup'   = 'navigate-pageup'
    'pagedown' = 'navigate-pagedown'
    
    # Selection
    'select'   = 'action-select'
    'space'    = 'action-toggle'
    'enter'    = 'action-select'
    
    # Control
    'cancel'   = 'action-cancel'      # ESC key
    'quit'     = 'action-force-exit'  # CTRL+C twice
    'back'     = 'action-back'        # Menu item only
}

function Get-StandardAction {
    <#
    .SYNOPSIS
        Converts raw key action to standardized action
    .PARAMETER RawAction
        Raw action from key reader
    .OUTPUTS
        Standardized action string
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RawAction
    )
    
    if ($script:StandardKeyActions.ContainsKey($RawAction)) {
        return $script:StandardKeyActions[$RawAction]
    }
    
    return "action-$RawAction"
}

function New-KeyResult {
    <#
    .SYNOPSIS
        Creates standardized key result hashtable
    .PARAMETER Action
        Action type: 'select', 'cancel', 'back', 'force-exit', 'navigate-*'
    .PARAMETER Value
        Optional value (for selections)
    .PARAMETER Key
        Optional key name
    .OUTPUTS
        Standardized result hashtable
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Action,
        
        [object]$Value = $null,
        [string]$Key = ''
    )
    
    return @{
        Action = $Action
        Value  = $Value
        Key    = $Key
    }
}

# ═══════════════════════════════════════════════════════════════
#                    EXPORT
# ═══════════════════════════════════════════════════════════════

if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Initialize-GlobalKeyHandler'
        'Reset-CtrlCHandler'
        'Test-DoubleCtrlC'
        'Test-ExitRequested'
        'Invoke-ForceExit'
        'Get-StandardAction'
        'New-KeyResult'
    )
}
