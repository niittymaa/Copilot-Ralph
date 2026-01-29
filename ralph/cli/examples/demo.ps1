<#
.SYNOPSIS
    PowerShell CLI Framework - Demo & Examples

.DESCRIPTION
    Demonstrates all features of the CLI framework:
    - Single-select menus
    - Multi-select menus
    - Text input
    - Confirmations
    - Progress bars
    - Spinners
    - Banners and messages

.NOTES
    Run this script to see all features in action.
    Part of the Ralph CLI Framework
#>

# Load the CLI framework
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cliPath = Join-Path (Split-Path -Parent $scriptDir) "ps\api.ps1"
. $cliPath

# ═══════════════════════════════════════════════════════════════
#                    DEMO FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Demo-Banner {
    Write-Host "`n" -NoNewline
    Show-Banner -Title "CLI Framework Demo" -Subtitle "PowerShell Edition" -Style Double
}

function Demo-SingleSelect {
    Write-Host "`n--- Single-Select Menu Demo ---" -ForegroundColor Cyan
    
    # Simple string array
    $color = Show-CLIMenu -Title "Choose a color" -Options @(
        'Red'
        'Green'
        'Blue'
        'Yellow'
    )
    
    if ($color) {
        Show-Message -Message "You selected: $color" -Type Success
    } else {
        Show-Message -Message "Selection cancelled" -Type Warning
    }
    
    # With detailed options
    $action = Show-CLIMenu -Title "Select an action" -Description "Choose what to do next" -Options @(
        @{ Text = "Create new project"; Value = "create"; Hotkey = "C"; Icon = "📁" }
        @{ Text = "Open existing project"; Value = "open"; Hotkey = "O"; Icon = "📂" }
        @{ Text = "Import from template"; Value = "import"; Hotkey = "I"; Icon = "📥" }
        @{ Text = "Exit"; Value = "exit"; Hotkey = "Q"; Icon = "🚪" }
    )
    
    if ($action) {
        Show-Message -Message "Action: $action" -Type Info
    }
}

function Demo-MultiSelect {
    Write-Host "`n--- Multi-Select Menu Demo ---" -ForegroundColor Cyan
    
    $features = Show-MultiSelect -Title "Select features to install" -Description "Use Space to toggle, Enter to confirm" -Options @(
        @{ Text = "Authentication"; Value = "auth"; Checked = $true }
        @{ Text = "Database ORM"; Value = "orm"; Checked = $true }
        @{ Text = "REST API"; Value = "api" }
        @{ Text = "GraphQL"; Value = "graphql" }
        @{ Text = "WebSocket support"; Value = "websocket" }
        @{ Text = "File uploads"; Value = "uploads" }
        @{ Text = "Email service"; Value = "email" }
        @{ Text = "Caching (Redis)"; Value = "cache" }
    )
    
    if ($features -and $features.Count -gt 0) {
        Show-Message -Message "Selected features: $($features -join ', ')" -Type Success
    } else {
        Show-Message -Message "No features selected" -Type Warning
    }
}

function Demo-Inputs {
    Write-Host "`n--- Input Demo ---" -ForegroundColor Cyan
    
    # Text input
    $name = Prompt-Input -Label "Enter your name" -Required
    if ($name) {
        Show-Message -Message "Hello, $name!" -Type Success
    }
    
    # Number input
    $age = Prompt-Input -Label "Enter your age" -Type Number -Validation @{ Min = 1; Max = 150 }
    if ($age) {
        Show-Message -Message "Age recorded: $age" -Type Info
    }
    
    # Password input
    $password = Prompt-Input -Label "Create a password" -Type Password -Validation @{ MinLength = 4 }
    if ($password) {
        Show-Message -Message "Password set (length: $($password.Length))" -Type Success
    }
}

function Demo-Confirmations {
    Write-Host "`n--- Confirmation Demo ---" -ForegroundColor Cyan
    
    # Simple confirmation
    $proceed = Show-Confirmation -Message "Do you want to continue?"
    if ($proceed) {
        Show-Message -Message "Continuing..." -Type Info
    } else {
        Show-Message -Message "Stopped" -Type Warning
    }
    
    # Danger confirmation
    $delete = Show-Confirmation -Message "This will delete all data. Are you sure?" -Danger -ConfirmText "DELETE"
    if ($delete) {
        Show-Message -Message "Deletion confirmed" -Type Error
    } else {
        Show-Message -Message "Deletion cancelled" -Type Success
    }
}

function Demo-Progress {
    Write-Host "`n--- Progress Demo ---" -ForegroundColor Cyan
    
    # Progress bar
    for ($i = 0; $i -le 100; $i += 5) {
        Show-Progress -Current $i -Total 100 -Label "Downloading" -ShowPercentage -ShowCount
        Start-Sleep -Milliseconds 100
    }
    Complete-Progress -Message "Download complete!"
    
    # Spinner
    $spinner = Start-CliSpinner -Message "Processing..."
    for ($i = 0; $i -lt 20; $i++) {
        Update-CliSpinner -State $spinner
        Start-Sleep -Milliseconds 100
    }
    Stop-CliSpinner -State $spinner -Success -Message "Processing complete!"
}

function Demo-Messages {
    Write-Host "`n--- Message Types Demo ---" -ForegroundColor Cyan
    
    Show-Message -Message "This is an info message" -Type Info
    Show-Message -Message "This is a success message" -Type Success
    Show-Message -Message "This is a warning message" -Type Warning
    Show-Message -Message "This is an error message" -Type Error
    Show-Message -Message "This is a debug message" -Type Debug
}

function Demo-Table {
    Write-Host "`n--- Table Demo ---" -ForegroundColor Cyan
    
    $data = @(
        @{ Name = "Alice"; Role = "Developer"; Status = "Active" }
        @{ Name = "Bob"; Role = "Designer"; Status = "Active" }
        @{ Name = "Charlie"; Role = "Manager"; Status = "Away" }
        @{ Name = "Diana"; Role = "DevOps"; Status = "Active" }
    )
    
    Show-Table -Data $data -Columns @('Name', 'Role', 'Status')
}

function Demo-Wizard {
    Write-Host "`n--- Wizard Demo ---" -ForegroundColor Cyan
    
    $result = Show-Wizard -Title "Project Setup Wizard" -Steps @(
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
            Options = @("Web Application", "API Service", "CLI Tool", "Library")
        }
        @{
            Name = "features"
            Type = "multiselect"
            Prompt = "Select features"
            Options = @(
                @{ Text = "TypeScript"; Value = "ts"; Checked = $true }
                @{ Text = "Testing"; Value = "test" }
                @{ Text = "Docker"; Value = "docker" }
                @{ Text = "CI/CD"; Value = "ci" }
            )
        }
        @{
            Name = "confirm"
            Type = "confirm"
            Prompt = "Create project with these settings?"
        }
    )
    
    if ($result) {
        Show-Banner -Title "Wizard Complete" -Style Rounded
        Write-Host "  Results:" -ForegroundColor Cyan
        $result.GetEnumerator() | ForEach-Object {
            $value = if ($_.Value -is [array]) { $_.Value -join ', ' } else { $_.Value }
            Write-Host "    $($_.Key): $value"
        }
    } else {
        Show-Message -Message "Wizard cancelled" -Type Warning
    }
}

function Demo-Colors {
    Write-Host "`n--- Color Demo ---" -ForegroundColor Cyan
    
    # Basic colors
    Write-Host "`n  Basic Foreground Colors:"
    foreach ($color in @('Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White')) {
        $code = Get-AnsiForeground -Color $color
        Write-Host "  $code$color$(Get-AnsiReset)" -NoNewline
        Write-Host " " -NoNewline
    }
    Write-Host ""
    
    # Bright colors
    Write-Host "`n  Bright Foreground Colors:"
    foreach ($color in @('BrightBlack', 'BrightRed', 'BrightGreen', 'BrightYellow', 'BrightBlue', 'BrightMagenta', 'BrightCyan', 'BrightWhite')) {
        $code = Get-AnsiForeground -Color $color
        Write-Host "  $code$color$(Get-AnsiReset)" -NoNewline
        Write-Host " " -NoNewline
    }
    Write-Host ""
    
    # Styles
    Write-Host "`n  Text Styles:"
    Write-Host "  $(Get-AnsiStyle -Style Bold)Bold$(Get-AnsiReset) " -NoNewline
    Write-Host "  $(Get-AnsiStyle -Style Dim)Dim$(Get-AnsiReset) " -NoNewline
    Write-Host "  $(Get-AnsiStyle -Style Italic)Italic$(Get-AnsiReset) " -NoNewline
    Write-Host "  $(Get-AnsiStyle -Style Underline)Underline$(Get-AnsiReset) " -NoNewline
    Write-Host "  $(Get-AnsiStyle -Style Strikethrough)Strikethrough$(Get-AnsiReset)"
    
    # Gradient
    Write-Host "`n  Gradient Text:"
    $gradient = Get-GradientText -Text "Hello, World! This is a gradient effect!" -StartColor @{R=255; G=0; B=128} -EndColor @{R=0; G=255; B=255}
    Write-Host "  $gradient"
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                    MAIN DEMO
# ═══════════════════════════════════════════════════════════════

function Run-Demo {
    Clear-Host
    Demo-Banner
    
    $demos = @(
        @{ Text = "Single-Select Menu"; Value = "single" }
        @{ Text = "Multi-Select Menu"; Value = "multi" }
        @{ Text = "Input Fields"; Value = "input" }
        @{ Text = "Confirmations"; Value = "confirm" }
        @{ Text = "Progress & Spinners"; Value = "progress" }
        @{ Text = "Messages"; Value = "messages" }
        @{ Text = "Tables"; Value = "table" }
        @{ Text = "Wizard"; Value = "wizard" }
        @{ Text = "Colors & Styles"; Value = "colors" }
        @{ Text = "Run All Demos"; Value = "all"; Hotkey = "A" }
        @{ Text = "Exit"; Value = "exit"; Hotkey = "Q" }
    )
    
    while ($true) {
        $choice = Show-CLIMenu -Title "Select a demo" -Options $demos
        
        switch ($choice) {
            "single"   { Demo-SingleSelect }
            "multi"    { Demo-MultiSelect }
            "input"    { Demo-Inputs }
            "confirm"  { Demo-Confirmations }
            "progress" { Demo-Progress }
            "messages" { Demo-Messages }
            "table"    { Demo-Table }
            "wizard"   { Demo-Wizard }
            "colors"   { Demo-Colors }
            "all" {
                Demo-SingleSelect
                Demo-MultiSelect
                Demo-Inputs
                Demo-Confirmations
                Demo-Progress
                Demo-Messages
                Demo-Table
                Demo-Colors
            }
            "exit"     { 
                Show-Message -Message "Goodbye!" -Type Info
                return 
            }
            default    { return }
        }
        
        Write-Host "`nPress any key to continue..." -ForegroundColor DarkGray
        $null = Read-SingleKey -NoEcho
    }
}

# Run the demo
Run-Demo
