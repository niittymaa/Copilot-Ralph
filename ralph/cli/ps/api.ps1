<#
.SYNOPSIS
    Unified CLI Framework API for PowerShell

.DESCRIPTION
    Provides a clean, high-level API for CLI interactions:
    - ShowMenu(options) - Single-select menu
    - ShowMultiSelect(options) - Multi-select with checkboxes
    - PromptInput(label) - Text input with validation
    - Confirm(message) - Yes/No confirmation
    - ShowProgress(current, total) - Progress indicator
    - ShowSpinner(message) - Loading spinner
    
    This module loads and coordinates all other CLI modules.

.NOTES
    Part of the Ralph CLI Framework
    No external dependencies - uses only built-in PowerShell features
#>

# ═══════════════════════════════════════════════════════════════
#                    MODULE LOADING
# ═══════════════════════════════════════════════════════════════

$script:CLIModulePath = $PSScriptRoot

# Load dependent modules
$modules = @(
    'globalKeyHandler.ps1'
    'colorUtils.ps1'
    'keyReader.ps1'
    'screenManager.ps1'
    'menuRenderer.ps1'
    'multiSelect.ps1'
    'inputHandler.ps1'
)

foreach ($module in $modules) {
    $path = Join-Path $script:CLIModulePath $module
    if (Test-Path $path) {
        . $path
    }
}

# ═══════════════════════════════════════════════════════════════
#                    HIGH-LEVEL API
# ═══════════════════════════════════════════════════════════════

function Show-CLIMenu {
    <#
    .SYNOPSIS
        Shows an interactive single-select menu (CLI Framework)
    .DESCRIPTION
        Renamed from Show-Menu to avoid conflict with Ralph's menu system.
        Use Show-SingleSelectMenu for lower-level control.
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of options. Can be:
        - Array of strings
        - Array of hashtables with Text, Value, Hotkey, Description, Disabled keys
    .PARAMETER Description
        Optional description below title
    .PARAMETER DefaultIndex
        Initially selected index
    .OUTPUTS
        Selected value or $null if cancelled
    .EXAMPLE
        # Simple string array
        $choice = Show-CLIMenu -Title "Select color" -Options @('Red', 'Green', 'Blue')
        
        # With detailed options
        $choice = Show-CLIMenu -Title "Action" -Options @(
            @{ Text = "Create new"; Value = "create"; Hotkey = "C" }
            @{ Text = "Edit existing"; Value = "edit"; Hotkey = "E" }
            @{ Text = "Delete"; Value = "delete"; Hotkey = "D"; Description = "Cannot undo" }
        )
    #>
    param(
        [string]$Title = '',
        
        [Parameter(Mandatory)]
        [array]$Options,
        
        [string]$Description = '',
        [int]$DefaultIndex = 0
    )
    
    # Convert options to menu items
    $items = @()
    foreach ($opt in $Options) {
        if ($opt -is [string]) {
            $items += New-MenuItem -Text $opt -Value $opt
        } elseif ($opt -is [hashtable]) {
            $params = @{ Text = $opt.Text }
            if ($opt.Value) { $params.Value = $opt.Value }
            if ($opt.Hotkey) { $params.Hotkey = $opt.Hotkey }
            if ($opt.Description) { $params.Description = $opt.Description }
            if ($opt.Disabled) { $params.Disabled = $true }
            if ($opt.DisabledReason) { $params.DisabledReason = $opt.DisabledReason }
            if ($opt.Icon) { $params.Icon = $opt.Icon }
            $items += New-MenuItem @params
        }
    }
    
    return Show-SingleSelectMenu -Title $Title -Items $items -Description $Description -DefaultIndex $DefaultIndex -ShowHotkeys
}

function Show-MultiSelect {
    <#
    .SYNOPSIS
        Shows an interactive multi-select menu
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of options. Can be:
        - Array of strings
        - Array of hashtables with Text, Value, Checked, Disabled keys
    .PARAMETER Description
        Optional description
    .PARAMETER MinSelection
        Minimum selections required
    .PARAMETER MaxSelection
        Maximum selections allowed
    .OUTPUTS
        Array of selected values or $null if cancelled
    .EXAMPLE
        $selected = Show-MultiSelect -Title "Select features" -Options @(
            @{ Text = "Feature A"; Value = "a"; Checked = $true }
            @{ Text = "Feature B"; Value = "b" }
            @{ Text = "Feature C"; Value = "c" }
        )
    #>
    param(
        [string]$Title = '',
        
        [Parameter(Mandatory)]
        [array]$Options,
        
        [string]$Description = '',
        [int]$MinSelection = 0,
        [int]$MaxSelection = 0
    )
    
    # Convert options to multi-select items
    $items = @()
    foreach ($opt in $Options) {
        if ($opt -is [string]) {
            $items += New-MultiSelectItem -Text $opt -Value $opt
        } elseif ($opt -is [hashtable]) {
            $params = @{ Text = $opt.Text }
            if ($opt.Value) { $params.Value = $opt.Value }
            if ($opt.Checked) { $params.Checked = $true }
            if ($opt.Disabled) { $params.Disabled = $true }
            if ($opt.Group) { $params.Group = $opt.Group }
            $items += New-MultiSelectItem @params
        }
    }
    
    return Show-MultiSelectMenu -Title $Title -Items $items -Description $Description `
        -MinSelection $MinSelection -MaxSelection $MaxSelection -ShowHelp
}

function Prompt-Input {
    <#
    .SYNOPSIS
        Prompts for text input
    .PARAMETER Label
        Input label/prompt
    .PARAMETER Default
        Default value
    .PARAMETER Required
        If true, empty input not allowed
    .PARAMETER Masked
        If true, input is hidden (for passwords)
    .PARAMETER Type
        Input type: 'Text', 'Number', 'Password', 'Path'
    .PARAMETER Validation
        Hashtable with validation options (Pattern, Min, Max, MustExist, etc.)
    .OUTPUTS
        Entered value or $null if cancelled
    .EXAMPLE
        $name = Prompt-Input -Label "Enter your name" -Required
        $age = Prompt-Input -Label "Enter age" -Type Number -Validation @{ Min = 1; Max = 150 }
        $password = Prompt-Input -Label "Password" -Type Password -Validation @{ MinLength = 8 }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Label,
        
        [string]$Default = '',
        [switch]$Required,
        [switch]$Masked,
        [ValidateSet('Text', 'Number', 'Password', 'Path')]
        [string]$Type = 'Text',
        [hashtable]$Validation = @{}
    )
    
    switch ($Type) {
        'Number' {
            $params = @{ Prompt = $Label }
            if ($Default) { $params.Default = [double]$Default }
            if ($Validation.Min) { $params.Min = $Validation.Min }
            if ($Validation.Max) { $params.Max = $Validation.Max }
            if ($Validation.AllowDecimal) { $params.AllowDecimal = $true }
            return Read-NumberInput @params
        }
        'Password' {
            $params = @{ Prompt = $Label; Required = $Required }
            if ($Validation.MinLength) { $params.MinLength = $Validation.MinLength }
            return Read-PasswordInput @params
        }
        'Path' {
            $params = @{ Prompt = $Label; Default = $Default }
            if ($Validation.MustExist) { $params.MustExist = $true }
            if ($Validation.Type) { $params.Type = $Validation.Type }
            if ($Validation.BasePath) { $params.BasePath = $Validation.BasePath }
            return Read-PathInput @params
        }
        default {
            $params = @{ Prompt = $Label; Default = $Default; Required = $Required }
            if ($Validation.Pattern) { 
                $params.Pattern = $Validation.Pattern 
                $params.PatternMessage = if ($Validation.PatternMessage) { $Validation.PatternMessage } else { 'Invalid format' }
            }
            if ($Validation.MaxLength) { $params.MaxLength = $Validation.MaxLength }
            return Read-TextInput @params
        }
    }
}

function Show-Confirmation {
    <#
    .SYNOPSIS
        Shows a yes/no confirmation dialog
    .PARAMETER Message
        Confirmation message
    .PARAMETER DefaultYes
        If true, Enter defaults to Yes
    .PARAMETER Danger
        If true, requires typing confirmation text
    .PARAMETER ConfirmText
        Text to type for danger confirmations
    .OUTPUTS
        $true for yes, $false for no, $null if cancelled
    .EXAMPLE
        if (Show-Confirmation -Message "Proceed with installation?") {
            Install-Package
        }
        
        if (Show-Confirmation -Message "Delete all data?" -Danger -ConfirmText "DELETE") {
            Remove-AllData
        }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [switch]$DefaultYes,
        [switch]$Danger,
        [string]$ConfirmText = 'CONFIRM'
    )
    
    if ($Danger) {
        return Show-DangerConfirm -Message $Message -ConfirmText $ConfirmText
    } else {
        return Show-Confirm -Message $Message -DefaultYes:$DefaultYes
    }
}

# ═══════════════════════════════════════════════════════════════
#                    PROGRESS & SPINNERS
# ═══════════════════════════════════════════════════════════════

$script:SpinnerFrames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
$script:SpinnerIndex = 0
$script:SpinnerJob = $null

function Show-Progress {
    <#
    .SYNOPSIS
        Shows a progress bar
    .PARAMETER Current
        Current progress value
    .PARAMETER Total
        Total/maximum value
    .PARAMETER Label
        Optional label
    .PARAMETER Width
        Bar width in characters
    .PARAMETER ShowPercentage
        Show percentage text
    .PARAMETER ShowCount
        Show current/total count
    #>
    param(
        [Parameter(Mandatory)]
        [int]$Current,
        
        [Parameter(Mandatory)]
        [int]$Total,
        
        [string]$Label = '',
        [int]$Width = 40,
        [switch]$ShowPercentage,
        [switch]$ShowCount
    )
    
    $esc = [char]27
    $percent = if ($Total -gt 0) { [Math]::Min(100, [Math]::Floor(($Current / $Total) * 100)) } else { 0 }
    $filled = [Math]::Floor(($percent / 100) * $Width)
    $empty = $Width - $filled
    
    $bar = "${esc}[32m$('█' * $filled)${esc}[90m$('░' * $empty)${esc}[0m"
    
    $suffix = ''
    if ($ShowPercentage) {
        $suffix += " ${esc}[33m${percent}%${esc}[0m"
    }
    if ($ShowCount) {
        $suffix += " ${esc}[90m(${Current}/${Total})${esc}[0m"
    }
    
    # Clear line and write
    Write-Host "`r${esc}[K" -NoNewline
    
    if ($Label) {
        Write-Host "  ${Label} " -NoNewline
    }
    
    Write-Host "[$bar]$suffix" -NoNewline
}

function Complete-Progress {
    <#
    .SYNOPSIS
        Completes and clears progress display
    .PARAMETER Message
        Optional completion message
    #>
    param(
        [string]$Message = ''
    )
    
    $esc = [char]27
    Write-Host "`r${esc}[K" -NoNewline
    
    if ($Message) {
        Write-Host "  ${esc}[32m✓${esc}[0m $Message"
    } else {
        Write-Host ""
    }
}

function Start-CliSpinner {
    <#
    .SYNOPSIS
        Starts an animated CLI spinner
    .PARAMETER Message
        Message to show with spinner
    .OUTPUTS
        Spinner state object to pass to Stop-CliSpinner
    #>
    param(
        [string]$Message = 'Loading...'
    )
    
    $state = @{
        Message = $Message
        Running = $true
        StartTime = Get-Date
    }
    
    Hide-Cursor
    
    return $state
}

function Update-CliSpinner {
    <#
    .SYNOPSIS
        Updates CLI spinner animation frame
    .PARAMETER State
        Spinner state from Start-CliSpinner
    .PARAMETER Message
        Optional new message
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,
        
        [string]$Message = ''
    )
    
    if (-not $State.Running) { return }
    
    $esc = [char]27
    $frame = $script:SpinnerFrames[$script:SpinnerIndex]
    $script:SpinnerIndex = ($script:SpinnerIndex + 1) % $script:SpinnerFrames.Count
    
    $msg = if ($Message) { $Message } else { $State.Message }
    
    Write-Host "`r${esc}[K  ${esc}[36m${frame}${esc}[0m $msg" -NoNewline
}

function Stop-CliSpinner {
    <#
    .SYNOPSIS
        Stops the CLI spinner
    .PARAMETER State
        Spinner state from Start-CliSpinner
    .PARAMETER Success
        If true, show success indicator
    .PARAMETER Message
        Final message
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,
        
        [switch]$Success,
        [string]$Message = ''
    )
    
    $State.Running = $false
    $esc = [char]27
    
    $duration = (Get-Date) - $State.StartTime
    $durationText = if ($duration.TotalSeconds -ge 60) {
        "{0:N1}m" -f $duration.TotalMinutes
    } else {
        "{0:N1}s" -f $duration.TotalSeconds
    }
    
    Write-Host "`r${esc}[K" -NoNewline
    
    $msg = if ($Message) { $Message } else { $State.Message }
    
    if ($Success) {
        Write-Host "  ${esc}[32m✓${esc}[0m $msg ${esc}[90m(${durationText})${esc}[0m"
    } else {
        Write-Host "  ${esc}[91m✗${esc}[0m $msg ${esc}[90m(${durationText})${esc}[0m"
    }
    
    Show-Cursor
}

# ═══════════════════════════════════════════════════════════════
#                    NOTIFICATIONS & MESSAGES
# ═══════════════════════════════════════════════════════════════

function Show-Message {
    <#
    .SYNOPSIS
        Shows a styled message
    .PARAMETER Message
        Message text
    .PARAMETER Type
        Message type: Info, Success, Warning, Error, Debug
    .PARAMETER Prefix
        Custom prefix icon
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Type = 'Info',
        
        [string]$Prefix = ''
    )
    
    $esc = [char]27
    
    $config = switch ($Type) {
        'Success' { @{ Icon = '✓'; Color = '32' } }
        'Warning' { @{ Icon = '⚠'; Color = '33' } }
        'Error'   { @{ Icon = '✗'; Color = '91' } }
        'Debug'   { @{ Icon = '●'; Color = '90' } }
        default   { @{ Icon = 'ℹ'; Color = '36' } }
    }
    
    $icon = if ($Prefix) { $Prefix } else { $config.Icon }
    
    Write-Host "  ${esc}[$($config.Color)m${icon}${esc}[0m $Message"
}

function Show-Banner {
    <#
    .SYNOPSIS
        Shows a styled banner/header
    .PARAMETER Title
        Banner title
    .PARAMETER Subtitle
        Optional subtitle
    .PARAMETER Style
        Box style: Light, Heavy, Double, Rounded
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        
        [string]$Subtitle = '',
        [ValidateSet('Light', 'Heavy', 'Double', 'Rounded')]
        [string]$Style = 'Double'
    )
    
    $esc = [char]27
    $chars = Get-BoxChars -Style $Style
    $width = [Math]::Max($Title.Length, $Subtitle.Length) + 6
    $width = [Math]::Max($width, 40)
    
    Write-Host ""
    Write-Host "  ${esc}[36m$($chars.TopLeft)$($chars.Horizontal * ($width - 2))$($chars.TopRight)${esc}[0m"
    
    $titlePad = $width - 4 - $Title.Length
    $leftPad = [Math]::Floor($titlePad / 2)
    $rightPad = $titlePad - $leftPad
    Write-Host "  ${esc}[36m$($chars.Vertical)${esc}[0m$(' ' * ($leftPad + 1))${esc}[1m${esc}[97m${Title}${esc}[0m$(' ' * ($rightPad + 1))${esc}[36m$($chars.Vertical)${esc}[0m"
    
    if ($Subtitle) {
        $subPad = $width - 4 - $Subtitle.Length
        $leftPad = [Math]::Floor($subPad / 2)
        $rightPad = $subPad - $leftPad
        Write-Host "  ${esc}[36m$($chars.Vertical)${esc}[0m$(' ' * ($leftPad + 1))${esc}[90m${Subtitle}${esc}[0m$(' ' * ($rightPad + 1))${esc}[36m$($chars.Vertical)${esc}[0m"
    }
    
    Write-Host "  ${esc}[36m$($chars.BottomLeft)$($chars.Horizontal * ($width - 2))$($chars.BottomRight)${esc}[0m"
    Write-Host ""
}

function Show-Table {
    <#
    .SYNOPSIS
        Shows data in a table format
    .PARAMETER Data
        Array of hashtables or objects
    .PARAMETER Columns
        Array of column names to display
    .PARAMETER Headers
        Hashtable mapping column names to display headers
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Data,
        
        [string[]]$Columns,
        [hashtable]$Headers = @{}
    )
    
    if ($Data.Count -eq 0) { return }
    
    $esc = [char]27
    
    # Auto-detect columns if not specified
    if (-not $Columns) {
        $first = $Data[0]
        if ($first -is [hashtable]) {
            $Columns = @($first.Keys)
        } else {
            $Columns = @($first.PSObject.Properties.Name)
        }
    }
    
    # Calculate column widths
    $widths = @{}
    foreach ($col in $Columns) {
        $header = if ($Headers[$col]) { $Headers[$col] } else { $col }
        $widths[$col] = $header.Length
        
        foreach ($row in $Data) {
            $value = if ($row -is [hashtable]) { $row[$col] } else { $row.$col }
            $valueStr = if ($null -eq $value) { '' } else { $value.ToString() }
            $widths[$col] = [Math]::Max($widths[$col], $valueStr.Length)
        }
    }
    
    # Header row
    $headerLine = "  "
    $separatorLine = "  "
    foreach ($col in $Columns) {
        $header = if ($Headers[$col]) { $Headers[$col] } else { $col }
        $headerLine += "${esc}[1m${esc}[36m$($header.PadRight($widths[$col]))${esc}[0m  "
        $separatorLine += "$('─' * $widths[$col])  "
    }
    
    Write-Host $headerLine
    Write-Host "${esc}[90m${separatorLine}${esc}[0m"
    
    # Data rows
    foreach ($row in $Data) {
        $line = "  "
        foreach ($col in $Columns) {
            $value = if ($row -is [hashtable]) { $row[$col] } else { $row.$col }
            $valueStr = if ($null -eq $value) { '' } else { $value.ToString() }
            $line += "$($valueStr.PadRight($widths[$col]))  "
        }
        Write-Host $line
    }
    
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                    WIZARD/STEP SYSTEM
# ═══════════════════════════════════════════════════════════════

function Show-Wizard {
    <#
    .SYNOPSIS
        Runs a multi-step wizard
    .PARAMETER Title
        Wizard title
    .PARAMETER Steps
        Array of step definitions
    .OUTPUTS
        Hashtable of collected values, or $null if cancelled
    .EXAMPLE
        $result = Show-Wizard -Title "Setup Wizard" -Steps @(
            @{
                Name = "name"
                Type = "input"
                Prompt = "Project name"
                Required = $true
            }
            @{
                Name = "type"
                Type = "select"
                Prompt = "Project type"
                Options = @("Web", "API", "CLI")
            }
            @{
                Name = "features"
                Type = "multiselect"
                Prompt = "Select features"
                Options = @("Auth", "Database", "API", "Tests")
            }
            @{
                Name = "confirm"
                Type = "confirm"
                Prompt = "Create project?"
            }
        )
    #>
    param(
        [string]$Title = 'Wizard',
        
        [Parameter(Mandatory)]
        [array]$Steps
    )
    
    $esc = [char]27
    $results = @{}
    $currentStep = 0
    
    while ($currentStep -lt $Steps.Count) {
        $step = $Steps[$currentStep]
        
        # Show progress
        Write-Host ""
        Write-Host "  ${esc}[90mStep $($currentStep + 1) of $($Steps.Count)${esc}[0m"
        
        $value = $null
        
        switch ($step.Type) {
            'input' {
                $params = @{ Label = $step.Prompt }
                if ($step.Default) { $params.Default = $step.Default }
                if ($step.Required) { $params.Required = $true }
                if ($step.Validation) { $params.Validation = $step.Validation }
                $value = Prompt-Input @params
            }
            'select' {
                $value = Show-CLIMenu -Title $step.Prompt -Options $step.Options
            }
            'multiselect' {
                $value = Show-MultiSelect -Title $step.Prompt -Options $step.Options
            }
            'confirm' {
                $value = Show-Confirmation -Message $step.Prompt -DefaultYes:($step.DefaultYes)
            }
            'number' {
                $params = @{ Label = $step.Prompt; Type = 'Number' }
                if ($step.Validation) { $params.Validation = $step.Validation }
                $value = Prompt-Input @params
            }
            'password' {
                $params = @{ Label = $step.Prompt; Type = 'Password' }
                if ($step.Validation) { $params.Validation = $step.Validation }
                $value = Prompt-Input @params
            }
        }
        
        # Handle cancellation
        if ($null -eq $value -and $step.Type -ne 'confirm') {
            # Ask to go back or cancel
            $action = Read-Choice -Prompt "Cancelled" -Choices @{
                'B' = 'Go back'
                'C' = 'Cancel wizard'
            } -Default 'B'
            
            if ($action -eq 'B' -and $currentStep -gt 0) {
                $currentStep--
                continue
            } else {
                return $null
            }
        }
        
        # Store result
        if ($step.Name) {
            $results[$step.Name] = $value
        }
        
        # Handle confirm step returning false
        if ($step.Type -eq 'confirm' -and $value -eq $false) {
            if ($step.OnNo -eq 'cancel') {
                return $null
            } elseif ($step.OnNo -eq 'back' -and $currentStep -gt 0) {
                $currentStep--
                continue
            }
        }
        
        $currentStep++
    }
    
    return $results
}

# ═══════════════════════════════════════════════════════════════
#                    INITIALIZATION
# ═══════════════════════════════════════════════════════════════

# Enable virtual terminal for Windows
$null = Enable-VirtualTerminal

# ═══════════════════════════════════════════════════════════════
#                    EXPORT
# ═══════════════════════════════════════════════════════════════

# Export functions if loaded as module (not when dot-sourced)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        # Core API
        'Show-CLIMenu'
        'Show-MultiSelect'
        'Prompt-Input'
        'Show-Confirmation'
        
        # Progress
        'Show-Progress'
        'Complete-Progress'
        'Start-CliSpinner'
        'Update-CliSpinner'
        'Stop-CliSpinner'
        
        # Messages
        'Show-Message'
        'Show-Banner'
        'Show-Table'
        
        # Wizard
        'Show-Wizard'
        
        # Re-export from submodules for direct access
        'New-MenuItem'
        'New-MenuSeparator'
        'New-MenuHeader'
        'New-MultiSelectItem'
        'Show-SingleSelectMenu'
        'Show-MultiSelectMenu'
        'Read-Choice'
        'Read-SearchInput'
        'Hide-Cursor'
        'Show-Cursor'
        'Clear-Screen'
        'Get-TerminalSize'
        'Format-AnsiText'
        'Get-GradientText'
    )
}
