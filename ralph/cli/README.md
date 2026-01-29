# Ralph CLI Framework

A fully modular, dependency-free CLI interaction framework that works in both **PowerShell** (7+) and **POSIX-compatible sh/bash** environments. No external packages, modules, or installers required.

## Features

- 🎯 **Single-select menus** with arrow-key navigation
- ☑️ **Multi-select menus** with spacebar toggling
- ⌨️ **Hotkey support** (e.g., press "q" to quit)
- 📜 **Scrollable menus** for large lists
- 🎨 **Full color support** (16-color, 256-color, RGB/TrueColor)
- ✨ **Clean redraws** without flickering
- 📝 **Text input** with validation
- 🔐 **Password input** with masking
- ✅ **Confirmation dialogs** (simple and danger modes)
- 📊 **Progress bars** and **spinners**
- 📋 **Wizards** for multi-step workflows
- 🖼️ **Banners** and styled messages
- 📏 **Dynamic terminal size** handling

## Installation

No installation required! Just copy the `cli` folder to your project.

```
ralph/cli/
├── ps/                    # PowerShell modules
│   ├── api.ps1           # Main entry point
│   ├── colorUtils.ps1    # ANSI color utilities
│   ├── keyReader.ps1     # Keyboard input handling
│   ├── screenManager.ps1 # Screen/cursor control
│   ├── menuRenderer.ps1  # Menu display
│   ├── multiSelect.ps1   # Multi-select functionality
│   └── inputHandler.ps1  # Text input & prompts
├── sh/                    # POSIX shell modules
│   ├── api.sh            # Main entry point
│   ├── colorUtils.sh     # ANSI color utilities
│   ├── keyReader.sh      # stty-based key reading
│   ├── screenManager.sh  # Screen/cursor control
│   ├── menuRenderer.sh   # Menu display
│   ├── multiSelect.sh    # Multi-select functionality
│   └── inputHandler.sh   # Text input & prompts
└── examples/
    ├── demo.ps1          # PowerShell demo
    └── demo.sh           # Shell demo
```

## Quick Start

### PowerShell

```powershell
# Load the framework
. ./ralph/cli/ps/api.ps1

# Show a menu with arrow-key navigation
$choice = Show-CLIMenu -Title "Select an option" -Options @(
    @{ Text = "Option 1"; Value = "opt1"; Hotkey = "1" }
    @{ Text = "Option 2"; Value = "opt2"; Hotkey = "2" }
    @{ Text = "Quit"; Value = "quit"; Hotkey = "Q" }
)

if ($choice -eq "quit") {
    exit
}
```

### POSIX Shell

```sh
#!/bin/sh

# Load the framework
. ./ralph/cli/sh/api.sh

# Show a menu
cli_menu_clear
cli_menu_add "Option 1" "opt1" "item" "1"
cli_menu_add "Option 2" "opt2" "item" "2"
cli_menu_add "Quit" "quit" "item" "Q"

cli_show_menu "Select an option"

if [ "$MENU_RESULT" = "quit" ]; then
    exit 0
fi
```

## API Reference

### PowerShell API

#### Show-CLIMenu
Display a single-select menu with arrow navigation.

```powershell
# Simple string options
$choice = Show-CLIMenu -Title "Pick a color" -Options @('Red', 'Green', 'Blue')

# Detailed options with hotkeys
$choice = Show-CLIMenu -Title "Action" -Options @(
    @{ Text = "Create"; Value = "create"; Hotkey = "C"; Description = "Create new item" }
    @{ Text = "Edit"; Value = "edit"; Hotkey = "E" }
    @{ Text = "Delete"; Value = "delete"; Hotkey = "D"; Disabled = $true; DisabledReason = "No items" }
)
```

#### Show-SingleSelectMenu
Lower-level menu display with full control over menu items.

```powershell
$items = @(
    New-MenuItem -Text "Option 1" -Value "opt1" -Hotkey "1"
    New-MenuItem -Text "Option 2" -Value "opt2" -Hotkey "2"
)
$result = Show-SingleSelectMenu -Title "Choose" -Items $items -ShowHotkeys
```

#### Show-MultiSelect
Display a multi-select menu with checkbox toggling.

```powershell
$selected = Show-MultiSelect -Title "Select features" -Options @(
    @{ Text = "Feature A"; Value = "a"; Checked = $true }
    @{ Text = "Feature B"; Value = "b" }
    @{ Text = "Feature C"; Value = "c" }
) -MinSelection 1 -MaxSelection 2
```

#### Prompt-Input
Prompt for user input with validation.

```powershell
# Text input
$name = Prompt-Input -Label "Enter your name" -Required

# Number input
$age = Prompt-Input -Label "Enter age" -Type Number -Validation @{ Min = 1; Max = 150 }

# Password input
$password = Prompt-Input -Label "Password" -Type Password -Validation @{ MinLength = 8 }

# Path input
$file = Prompt-Input -Label "Select file" -Type Path -Validation @{ MustExist = $true; Type = "File" }
```

#### Show-Confirmation
Display a yes/no confirmation dialog.

```powershell
# Simple confirmation
if (Show-Confirmation -Message "Delete this file?") {
    Remove-Item $file
}

# Danger confirmation (requires typing)
if (Show-Confirmation -Message "Delete all data?" -Danger -ConfirmText "DELETE") {
    Clear-Database
}
```

#### Show-Progress / Start-Spinner
Display progress indicators.

```powershell
# Progress bar
for ($i = 0; $i -le 100; $i += 10) {
    Show-Progress -Current $i -Total 100 -Label "Loading" -ShowPercentage
    Start-Sleep -Milliseconds 100
}
Complete-Progress -Message "Done!"

# Spinner
$spinner = Start-Spinner -Message "Processing..."
# ... do work ...
Stop-Spinner -State $spinner -Success -Message "Complete!"
```

#### Show-Wizard
Run a multi-step wizard.

```powershell
$result = Show-Wizard -Title "Setup" -Steps @(
    @{ Name = "name"; Type = "input"; Prompt = "Project name"; Required = $true }
    @{ Name = "type"; Type = "select"; Prompt = "Type"; Options = @("Web", "API", "CLI") }
    @{ Name = "confirm"; Type = "confirm"; Prompt = "Create project?" }
)
```

#### Show-Banner / Show-Message / Show-Table
Display styled output.

```powershell
Show-Banner -Title "My Application" -Subtitle "v1.0.0" -Style Double

Show-Message -Message "Operation successful" -Type Success

Show-Table -Data @(
    @{ Name = "Alice"; Role = "Developer" }
    @{ Name = "Bob"; Role = "Designer" }
) -Columns @('Name', 'Role')
```

### POSIX Shell API

#### Menu Functions

```sh
# Clear and build menu
cli_menu_clear
cli_menu_add "Option text" "return_value" "item" "H"  # H = hotkey
cli_menu_separator
cli_menu_header "Section Title"
cli_menu_add "Another option" "value2"

# Show menu - result in $MENU_RESULT
cli_show_menu "Menu Title" "Optional description"

# Quick menu from arguments
cli_quick_menu "Title" "Option 1" "Option 2" "Option 3"
```

#### Multi-Select Functions

```sh
# Build multi-select
cli_ms_clear
cli_ms_add "Feature A" "a" "true"   # pre-checked
cli_ms_add "Feature B" "b" "false"
cli_ms_add "Feature C" "c"

# Show - results in $MS_RESULT (space-separated)
cli_show_multiselect "Select features" "" 1 3  # min=1, max=3

# Quick multi-select
cli_quick_multiselect "Title" "Option 1" "Option 2" "Option 3"
```

#### Input Functions

```sh
# Text input - result in $INPUT_RESULT
cli_input_text "Enter name" "default" "true"  # required=true

# Password input
cli_input_password "Enter password" "true" "8"  # required, min 8 chars

# Number input
cli_input_number "Enter age" "25" "1" "150"  # default=25, min=1, max=150

# Path input
cli_input_path "Select file" "" "true" "file"  # must_exist, type=file
```

#### Confirmation Functions

```sh
# Simple confirmation (returns 0=yes, 1=no, 2=cancel)
cli_confirm "Proceed?" "true"  # default yes

# Danger confirmation
cli_danger_confirm "Delete everything?" "DELETE"
```

#### Choice Function

```sh
# Single character choice - result in $CHOICE_RESULT
cli_choice "Action?" "A:Add" "E:Edit" "D:Delete"
```

#### Display Functions

```sh
# Banner
cli_api_banner "Title" "Subtitle" "double"

# Messages
cli_msg_info "Information"
cli_msg_success "Success!"
cli_msg_warning "Warning..."
cli_msg_error "Error!"

# Table
cli_api_table "Name,Role" "Alice,Developer" "Bob,Designer"

# Progress
cli_progress 50 100 "Loading"
cli_progress_done "Complete!"

# Spinner
cli_spinner "Processing..."
cli_spinner_done "Done!" "true"
```

## Module Architecture

### PowerShell Modules

| Module | Purpose |
|--------|---------|
| `colorUtils.ps1` | ANSI escape code generation, color palettes, gradients |
| `keyReader.ps1` | Console.ReadKey wrapper, key matching, input buffering |
| `screenManager.ps1` | Cursor control, screen clearing, viewports, box drawing |
| `menuRenderer.ps1` | Menu item formatting, single-select rendering |
| `multiSelect.ps1` | Checkbox items, group selection |
| `inputHandler.ps1` | Text/number/password input, confirmations, search |
| `api.ps1` | High-level unified API, wizards, progress |

### POSIX Shell Modules

| Module | Purpose |
|--------|---------|
| `colorUtils.sh` | ANSI escape sequences, color functions |
| `keyReader.sh` | stty-based raw input, escape sequence parsing |
| `screenManager.sh` | Cursor/screen control, viewport management |
| `menuRenderer.sh` | Menu storage and rendering |
| `multiSelect.sh` | Multi-select functionality |
| `inputHandler.sh` | Input prompts, confirmations, messages |
| `api.sh` | Unified API, wizard support |

## Keyboard Controls

### Menu Navigation

| Key | Action |
|-----|--------|
| ↑ / ↓ | Move selection |
| Enter | Select/confirm |
| Escape | Cancel |
| Home | Jump to first item |
| End | Jump to last item |
| Page Up/Down | Jump by page |
| [Hotkey] | Direct selection |

### Multi-Select

| Key | Action |
|-----|--------|
| Space | Toggle current item |
| A | Select all |
| N | Deselect all |
| Enter | Confirm selection |

## Terminal Compatibility

### Tested Environments

- ✅ Windows Terminal
- ✅ PowerShell 7+
- ✅ VS Code Terminal
- ✅ Linux terminals (xterm, GNOME Terminal, Konsole)
- ✅ macOS Terminal.app, iTerm2
- ✅ tmux / screen
- ⚠️ Windows Console Host (basic support)
- ⚠️ PowerShell 5.1 (limited color support)

### Color Support Detection

The framework automatically detects terminal capabilities:

```powershell
# PowerShell
$support = Test-ColorSupport
# Returns: @{ Basic = $true; Extended = $true; TrueColor = $true; Styles = $true }
```

```sh
# Shell
if cli_test_color_support; then
    echo "Colors supported"
fi

if cli_test_truecolor_support; then
    echo "24-bit color supported"
fi
```

## Running the Demos

### PowerShell

```powershell
cd ralph/cli/examples
./demo.ps1
```

### POSIX Shell

```sh
cd ralph/cli/examples
chmod +x demo.sh
./demo.sh
```

## Extending the Framework

### Adding Custom Menu Items (PowerShell)

```powershell
# Use New-MenuItem for full control
$items = @(
    New-MenuItem -Text "Custom Item" -Value "custom" -Hotkey "C" -Icon "🔧" -Description "A custom action"
    New-MenuSeparator -Text "Advanced"
    New-MenuHeader -Text "Admin Options"
    New-MenuItem -Text "Settings" -Value "settings" -Disabled -DisabledReason "Requires admin"
)

Show-SingleSelectMenu -Title "Options" -Items $items
```

### Adding Custom Styles

```powershell
# Configure menu appearance
Set-MenuConfig -Config @{
    Indicator = @{
        Selected = '▶'
        Unselected = ' '
    }
    Colors = @{
        Selected = 'BrightCyan'
        Normal = 'White'
    }
}
```

### Custom Validators (PowerShell)

```powershell
$email = Prompt-Input -Label "Email" -Validation @{
    Pattern = '^[\w.-]+@[\w.-]+\.\w+$'
    PatternMessage = 'Please enter a valid email address'
}
```

## Best Practices

1. **Always handle cancellation** - Check for `$null` returns from menus/inputs
2. **Use descriptive hotkeys** - Match first letter or obvious abbreviation
3. **Provide defaults** - Make common choices easy
4. **Show progress** - Use spinners/progress for operations > 1 second
5. **Validate input** - Use validation options to catch errors early
6. **Clean up** - The framework handles cursor visibility automatically

## Troubleshooting

### Colors not displaying correctly

1. Check terminal color support: `$env:COLORTERM` should be `truecolor` or `24bit`
2. On Windows, ensure Windows Terminal or modern console is used
3. Try enabling virtual terminal: `Enable-VirtualTerminal`

### Arrow keys not working

1. Ensure terminal is in interactive mode
2. For POSIX shell, check that stty is available
3. Some remote terminals may not pass escape sequences correctly

### Flickering on redraw

1. The framework uses buffered rendering - ensure you're using the API functions
2. Avoid mixing raw Write-Host with framework functions during menu display

## License

Part of the Ralph CLI Framework. MIT License.
