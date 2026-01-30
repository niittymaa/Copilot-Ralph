<#
.SYNOPSIS
    Interrupt Handler Module for Ralph Loop

.DESCRIPTION
    Provides centralized interrupt handling with:
    - Three-option interrupt menu (Cancel/Finish Then Stop/Continue)
    - Global interrupt state management
    - Integration with build loop and Copilot execution

.NOTES
    Part of the Ralph CLI Framework
#>

# ═══════════════════════════════════════════════════════════════
#                    INTERRUPT STATE
# ═══════════════════════════════════════════════════════════════

# Interrupt state: 'none', 'stop-after-iteration', 'cancel-requested'
$script:InterruptState = 'none'

# Track if interrupt menu is currently showing (prevent re-entry)
$script:InterruptMenuActive = $false

# ═══════════════════════════════════════════════════════════════
#                    STATE MANAGEMENT
# ═══════════════════════════════════════════════════════════════

function Get-InterruptState {
    <#
    .SYNOPSIS
        Gets the current interrupt state
    .OUTPUTS
        'none', 'stop-after-iteration', or 'cancel-requested'
    #>
    return $script:InterruptState
}

function Set-InterruptState {
    <#
    .SYNOPSIS
        Sets the interrupt state
    .PARAMETER State
        New state: 'none', 'stop-after-iteration', 'cancel-requested'
    #>
    param(
        [ValidateSet('none', 'stop-after-iteration', 'cancel-requested')]
        [string]$State
    )
    $script:InterruptState = $State
}

function Reset-InterruptState {
    <#
    .SYNOPSIS
        Resets interrupt state to 'none'
    #>
    $script:InterruptState = 'none'
}

function Test-StopAfterIteration {
    <#
    .SYNOPSIS
        Checks if loop should stop after current iteration
    .OUTPUTS
        $true if stop-after-iteration was requested
    #>
    return $script:InterruptState -eq 'stop-after-iteration'
}

function Test-CancelRequested {
    <#
    .SYNOPSIS
        Checks if immediate cancel was requested
    .OUTPUTS
        $true if cancel was requested
    #>
    return $script:InterruptState -eq 'cancel-requested'
}

function Test-InterruptMenuActive {
    <#
    .SYNOPSIS
        Checks if interrupt menu is currently active
    .OUTPUTS
        $true if menu is showing (prevents re-entry)
    #>
    return $script:InterruptMenuActive
}

# ═══════════════════════════════════════════════════════════════
#                    INTERRUPT MENU
# ═══════════════════════════════════════════════════════════════

function Show-InterruptMenu {
    <#
    .SYNOPSIS
        Shows the interrupt options menu
    .DESCRIPTION
        Displays a menu with 3 options:
        1. Cancel Instantly - Kill process, exit loop now
        2. Finish Iteration, Then Stop - Complete current task, then stop
        3. Continue - Resume without interruption
    .PARAMETER Context
        Optional context string (e.g., "Copilot is running", "Build iteration 3")
    .OUTPUTS
        'cancel', 'stop-after', or 'continue'
    #>
    param(
        [string]$Context = 'Operation in progress'
    )
    
    # Prevent re-entry
    if ($script:InterruptMenuActive) {
        return 'continue'
    }
    
    $script:InterruptMenuActive = $true
    
    try {
        # Save cursor state
        Write-Host "$([char]27)[?25h" -NoNewline  # Show cursor
        
        # Clear any pending input
        while ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
        }
        
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host "  │             INTERRUPT DETECTED                  │" -ForegroundColor Yellow
        Write-Host "  ├─────────────────────────────────────────────────┤" -ForegroundColor Yellow
        Write-Host "  │  $($Context.PadRight(45))│" -ForegroundColor Gray
        Write-Host "  └─────────────────────────────────────────────────┘" -ForegroundColor Yellow
        Write-Host ""
        
        # Menu options with visual indicator
        $selectedIndex = 2  # Default to "Continue"
        $options = @(
            @{ Label = "Cancel Instantly"; Desc = "Kill process, exit loop now"; Value = 'cancel' }
            @{ Label = "Finish This Iteration, Then Stop"; Desc = "Complete current task, then stop"; Value = 'stop-after' }
            @{ Label = "Continue"; Desc = "Resume without interruption"; Value = 'continue' }
        )
        
        function Render-InterruptMenu {
            param([int]$Selected)
            
            # Move cursor up to redraw menu (3 options + spacing)
            Write-Host "$([char]27)[5A" -NoNewline
            
            for ($i = 0; $i -lt $options.Count; $i++) {
                $opt = $options[$i]
                $prefix = if ($i -eq $Selected) { "  ►" } else { "   " }
                $color = if ($i -eq $Selected) { "Cyan" } else { "Gray" }
                $descColor = if ($i -eq $Selected) { "DarkCyan" } else { "DarkGray" }
                
                # Clear line first
                Write-Host "$([char]27)[2K" -NoNewline
                Write-Host "$prefix [$($i + 1)] $($opt.Label)" -ForegroundColor $color
                Write-Host "$([char]27)[2K" -NoNewline
                Write-Host "       $($opt.Desc)" -ForegroundColor $descColor
            }
            Write-Host ""
        }
        
        # Initial render
        Write-Host ""  # Option 1 line
        Write-Host ""  # Option 1 desc
        Write-Host ""  # Option 2 line
        Write-Host ""  # Option 2 desc
        Write-Host ""  # Option 3 line
        Write-Host ""  # Option 3 desc
        Write-Host ""  # Spacing
        
        Render-InterruptMenu -Selected $selectedIndex
        
        Write-Host "  Use ↑/↓ arrows and Enter to select, or press 1/2/3" -ForegroundColor DarkGray
        
        # Read input
        while ($true) {
            $key = [Console]::ReadKey($true)
            
            switch ($key.Key) {
                'UpArrow' {
                    if ($selectedIndex -gt 0) {
                        $selectedIndex--
                        Render-InterruptMenu -Selected $selectedIndex
                    }
                }
                'DownArrow' {
                    if ($selectedIndex -lt ($options.Count - 1)) {
                        $selectedIndex++
                        Render-InterruptMenu -Selected $selectedIndex
                    }
                }
                'Enter' {
                    $result = $options[$selectedIndex].Value
                    Write-Host ""
                    Write-Host "  → Selected: $($options[$selectedIndex].Label)" -ForegroundColor Green
                    Write-Host ""
                    
                    # Update state based on selection
                    if ($result -eq 'stop-after') {
                        $script:InterruptState = 'stop-after-iteration'
                    } elseif ($result -eq 'cancel') {
                        $script:InterruptState = 'cancel-requested'
                    }
                    
                    return $result
                }
                'Escape' {
                    # ESC again = continue
                    Write-Host ""
                    Write-Host "  → Continuing..." -ForegroundColor Green
                    Write-Host ""
                    return 'continue'
                }
                'D1' { 
                    # Press 1
                    $script:InterruptState = 'cancel-requested'
                    Write-Host ""
                    Write-Host "  → Selected: Cancel Instantly" -ForegroundColor Yellow
                    Write-Host ""
                    return 'cancel'
                }
                'D2' {
                    # Press 2
                    $script:InterruptState = 'stop-after-iteration'
                    Write-Host ""
                    Write-Host "  → Selected: Finish This Iteration, Then Stop" -ForegroundColor Cyan
                    Write-Host ""
                    return 'stop-after'
                }
                'D3' {
                    # Press 3
                    Write-Host ""
                    Write-Host "  → Continuing..." -ForegroundColor Green
                    Write-Host ""
                    return 'continue'
                }
            }
            
            # Also handle numpad
            if ($key.KeyChar -eq '1') {
                $script:InterruptState = 'cancel-requested'
                Write-Host ""
                Write-Host "  → Selected: Cancel Instantly" -ForegroundColor Yellow
                Write-Host ""
                return 'cancel'
            }
            if ($key.KeyChar -eq '2') {
                $script:InterruptState = 'stop-after-iteration'
                Write-Host ""
                Write-Host "  → Selected: Finish This Iteration, Then Stop" -ForegroundColor Cyan
                Write-Host ""
                return 'stop-after'
            }
            if ($key.KeyChar -eq '3') {
                Write-Host ""
                Write-Host "  → Continuing..." -ForegroundColor Green
                Write-Host ""
                return 'continue'
            }
        }
    } finally {
        $script:InterruptMenuActive = $false
    }
}

function Show-StopAfterIterationBanner {
    <#
    .SYNOPSIS
        Shows a banner indicating loop will stop after current iteration
    #>
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │  ℹ️  Loop will stop after this iteration        │" -ForegroundColor Cyan
    Write-Host "  │     (Press ESC again to cancel immediately)     │" -ForegroundColor DarkCyan
    Write-Host "  └─────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                    EXPORT
# ═══════════════════════════════════════════════════════════════

if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Get-InterruptState'
        'Set-InterruptState'
        'Reset-InterruptState'
        'Test-StopAfterIteration'
        'Test-CancelRequested'
        'Test-InterruptMenuActive'
        'Show-InterruptMenu'
        'Show-StopAfterIterationBanner'
    )
}
