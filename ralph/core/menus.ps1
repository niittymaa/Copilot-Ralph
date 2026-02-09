<#
.SYNOPSIS
    Centralized menu system for Ralph Loop CLI

.DESCRIPTION
    Provides a unified, configurable menu system with:
    - YAML-based menu definitions (externalized from code)
    - Navigation stack (back navigation support)
    - Consistent UX across all menus
    - Keyboard shortcut handling
    - Context-aware menu rendering

.NOTES
    Menu definitions are loaded from ralph/menus/*.yaml
    Navigation stack allows returning to previous menus with 'B' key
#>

# Helper function to conditionally clear screen
function Clear-HostConditional {
    <#
    .SYNOPSIS
        Clears the host screen unless developer mode is enabled
    .DESCRIPTION
        In developer mode, screen is not cleared so history can be scrolled
        If DeveloperMode is not set, defaults to clearing screen
    #>
    $devMode = if (Get-Variable -Name 'DeveloperMode' -Scope Script -ErrorAction SilentlyContinue) {
        $script:DeveloperMode
    } else {
        $false
    }
    
    if (-not $devMode) {
        Clear-Host
    } else {
        Write-Host ""
        Write-Host ("═" * 80) -ForegroundColor DarkGray
        Write-Host ""
    }
}

function Get-ActiveModes {
    <#
    .SYNOPSIS
        Gets list of currently active modes for display
    .DESCRIPTION
        Returns array of mode names that are currently active (Dry-Run, Developer, Verbose, etc.)
        Makes it easy to display a consolidated mode indicator
    .OUTPUTS
        Array of active mode names
    #>
    $modes = @()
    
    # Check Dry-Run mode
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        $modes += "DRY-RUN"
    }
    
    # Check Developer mode
    $devMode = if (Get-Variable -Name 'DeveloperMode' -Scope Script -ErrorAction SilentlyContinue) {
        $script:DeveloperMode
    } else {
        $false
    }
    if ($devMode) {
        $modes += "DEVELOPER"
    }
    
    # Check Verbose mode
    $verboseMode = if (Get-Variable -Name 'VerboseMode' -Scope Script -ErrorAction SilentlyContinue) {
        $script:VerboseMode
    } else {
        $false
    }
    if ($verboseMode) {
        $modes += "VERBOSE"
    }
    
    return $modes
}

function Show-ModeIndicator {
    <#
    .SYNOPSIS
        Displays a consolidated indicator for all active modes
    .DESCRIPTION
        Shows a prominent banner with all active modes (Dry-Run, Developer, Verbose)
        Replaces individual mode indicators with one unified display
    #>
    $modes = Get-ActiveModes
    
    if ($modes.Count -eq 0) {
        return  # No modes active, nothing to show
    }
    
    # Build mode text
    $modeText = $modes -join " | "
    $message = "  $modeText MODE"
    if ($modes.Count -gt 1) {
        $message += "S"
    }
    $message += " ACTIVE  "
    
    # Calculate width for box (centered text)
    $boxWidth = [Math]::Max($message.Length + 4, 60)
    $padding = [Math]::Floor(($boxWidth - $message.Length) / 2)
    $paddedMessage = (" " * $padding) + $message + (" " * $padding)
    
    # Ensure exact width
    if ($paddedMessage.Length -lt $boxWidth) {
        $paddedMessage += " " * ($boxWidth - $paddedMessage.Length)
    }
    
    # Display the banner
    Write-Host ""
    Write-Host ("┏" + ("━" * ($boxWidth - 2)) + "┓") -ForegroundColor Yellow
    Write-Host ("┃" + $paddedMessage.Substring(0, $boxWidth - 2) + "┃") -ForegroundColor Black -BackgroundColor Yellow
    Write-Host ("┗" + ("━" * ($boxWidth - 2)) + "┛") -ForegroundColor Yellow
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                    CLI FRAMEWORK LOADING
# ═══════════════════════════════════════════════════════════════

# Load the CLI framework for arrow-key navigation menus
$script:CLIFrameworkLoaded = $false
$cliApiPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'ralph\cli\ps\api.ps1'
if (-not $cliApiPath) {
    $cliApiPath = Join-Path $PSScriptRoot '..\cli\ps\api.ps1'
}

if (Test-Path $cliApiPath) {
    try {
        . $cliApiPath
        $script:CLIFrameworkLoaded = $true
    } catch {
        # CLI framework not available, fall back to text-based input
        $script:CLIFrameworkLoaded = $false
    }
}

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:MenusDir = $null
$script:MenusProjectRoot = $null
$script:NavigationStack = [System.Collections.Generic.Stack[hashtable]]::new()
$script:MenuCache = @{}
$script:MenuContext = @{}
$script:UseArrowNavigation = $true  # Enable arrow-key navigation by default

function Initialize-MenuSystem {
    <#
    .SYNOPSIS
        Initializes the menu system paths
    .PARAMETER ProjectRoot
        Root directory of the project
    .PARAMETER DisableArrowNavigation
        If set, falls back to text-based input (hotkey selection)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,
        
        [switch]$DisableArrowNavigation
    )
    
    $script:MenusProjectRoot = $ProjectRoot
    $ralphDir = Join-Path $ProjectRoot 'ralph'
    $script:MenusDir = Join-Path $ralphDir 'menus'
    $script:NavigationStack.Clear()
    $script:MenuCache.Clear()
    $script:MenuContext = @{}
    
    # Load CLI framework if not already loaded
    if (-not $script:CLIFrameworkLoaded) {
        $cliApiPath = Join-Path $ralphDir 'cli\ps\api.ps1'
        if (Test-Path $cliApiPath) {
            try {
                . $cliApiPath
                $script:CLIFrameworkLoaded = $true
            } catch {
                $script:CLIFrameworkLoaded = $false
            }
        }
    }
    
    # Set arrow navigation mode
    $script:UseArrowNavigation = $script:CLIFrameworkLoaded -and (-not $DisableArrowNavigation)
}

# ═══════════════════════════════════════════════════════════════
#                     NAVIGATION STACK
# ═══════════════════════════════════════════════════════════════

function Push-MenuState {
    <#
    .SYNOPSIS
        Pushes current menu state onto navigation stack
    .PARAMETER MenuId
        ID of the current menu
    .PARAMETER Context
        Additional context data for the menu
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MenuId,
        
        [hashtable]$Context = @{}
    )
    
    $state = @{
        MenuId  = $MenuId
        Context = $Context.Clone()
        Time    = Get-Date
    }
    
    $script:NavigationStack.Push($state)
}

function Pop-MenuState {
    <#
    .SYNOPSIS
        Pops the previous menu state from navigation stack
    .OUTPUTS
        Previous menu state hashtable or $null if stack is empty
    #>
    if ($script:NavigationStack.Count -gt 0) {
        return $script:NavigationStack.Pop()
    }
    return $null
}

function Get-NavigationDepth {
    <#
    .SYNOPSIS
        Returns current navigation depth
    #>
    return $script:NavigationStack.Count
}

function Clear-NavigationStack {
    <#
    .SYNOPSIS
        Clears the navigation stack
    #>
    $script:NavigationStack.Clear()
}

function Get-NavigationBreadcrumb {
    <#
    .SYNOPSIS
        Returns breadcrumb trail for current navigation
    .OUTPUTS
        Array of menu IDs from root to current
    #>
    $breadcrumb = @()
    $items = $script:NavigationStack.ToArray()
    [Array]::Reverse($items)
    
    foreach ($item in $items) {
        $breadcrumb += $item.MenuId
    }
    
    return $breadcrumb
}

# ═══════════════════════════════════════════════════════════════
#                     MENU LOADING
# ═══════════════════════════════════════════════════════════════

function Read-MenuFile {
    <#
    .SYNOPSIS
        Reads and parses a menu YAML file
    .PARAMETER Path
        Full path to the menu file
    .OUTPUTS
        Menu definition hashtable or $null if invalid
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        return $null
    }
    
    $content = Get-Content $Path -Raw
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    
    # Parse YAML-style frontmatter and content
    $menu = @{
        Id          = $fileName
        Title       = $fileName
        Description = ''
        Color       = 'Cyan'
        Items       = @()
        Context     = @{}
        ShowBack    = $true
        ShowQuit    = $true
        Path        = $Path
    }
    
    # Parse frontmatter
    if ($content -match '(?s)^---\s*\n(.*?)\n---\s*\n(.*)$') {
        $frontmatter = $Matches[1]
        $body = $Matches[2].Trim()
        
        if ($frontmatter -match 'id:\s*[''"]?([^''"}\n]+)[''"]?') {
            $menu.Id = $Matches[1].Trim()
        }
        if ($frontmatter -match 'title:\s*[''"]?([^''"}\n]+)[''"]?') {
            $menu.Title = $Matches[1].Trim()
        }
        if ($frontmatter -match 'description:\s*[''"]?([^''"}\n]+)[''"]?') {
            $menu.Description = $Matches[1].Trim()
        }
        if ($frontmatter -match 'color:\s*[''"]?([^''"}\n]+)[''"]?') {
            $menu.Color = $Matches[1].Trim()
        }
        if ($frontmatter -match 'show_back:\s*(true|false)') {
            $menu.ShowBack = $Matches[1] -eq 'true'
        }
        if ($frontmatter -match 'show_quit:\s*(true|false)') {
            $menu.ShowQuit = $Matches[1] -eq 'true'
        }
        
        # Parse menu items from body
        $menu.Items = @(Parse-MenuItems -Content $body)
    }
    
    return $menu
}

function Parse-MenuItems {
    <#
    .SYNOPSIS
        Parses menu items from YAML-like content
    .PARAMETER Content
        Menu body content
    .OUTPUTS
        Array of menu item hashtables
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )
    
    $items = @()
    $lines = $Content -split "`n"
    $currentItem = $null
    
    foreach ($line in $lines) {
        $line = $line.TrimEnd()
        
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') {
            continue
        }
        
        # New item starts with "- key:"
        if ($line -match '^\s*-\s*key:\s*[''"]?([^''"]+)[''"]?\s*$') {
            if ($currentItem) {
                $items += $currentItem
            }
            $currentItem = @{
                Key         = $Matches[1].Trim()
                Label       = ''
                Action      = ''
                Description = ''
                Color       = 'White'
                Condition   = $null
                Submenu     = $null
                Separator   = $false
                Disabled    = $false
            }
        }
        elseif ($currentItem) {
            # Parse item properties
            if ($line -match '^\s+label:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $currentItem.Label = $Matches[1].Trim()
            }
            elseif ($line -match '^\s+action:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $currentItem.Action = $Matches[1].Trim()
            }
            elseif ($line -match '^\s+description:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $currentItem.Description = $Matches[1].Trim()
            }
            elseif ($line -match '^\s+color:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $currentItem.Color = $Matches[1].Trim()
            }
            elseif ($line -match '^\s+submenu:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $currentItem.Submenu = $Matches[1].Trim()
            }
            elseif ($line -match '^\s+condition:\s*[''"]?([^''"]+)[''"]?\s*$') {
                $currentItem.Condition = $Matches[1].Trim()
            }
            elseif ($line -match '^\s+separator:\s*(true|false)') {
                $currentItem.Separator = $Matches[1] -eq 'true'
            }
            elseif ($line -match '^\s+disabled:\s*(true|false)') {
                $currentItem.Disabled = $Matches[1] -eq 'true'
            }
        }
        # Separator-only item
        elseif ($line -match '^\s*-\s*separator:\s*true\s*$') {
            $items += @{ Separator = $true; Disabled = $false }
        }
    }
    
    # Add last item
    if ($currentItem) {
        $items += $currentItem
    }
    
    return $items
}

function Get-Menu {
    <#
    .SYNOPSIS
        Gets a menu definition by ID
    .PARAMETER MenuId
        Menu ID to load
    .PARAMETER NoCache
        Skip cache and reload from file
    .OUTPUTS
        Menu definition hashtable or $null
    #>
    param(
        [Parameter(Mandatory)]
        [string]$MenuId,
        
        [switch]$NoCache
    )
    
    # Check cache first
    if (-not $NoCache -and $script:MenuCache.ContainsKey($MenuId)) {
        return $script:MenuCache[$MenuId]
    }
    
    $menuPath = Join-Path $script:MenusDir "$MenuId.yaml"
    
    if (-not (Test-Path $menuPath)) {
        return $null
    }
    
    $menu = Read-MenuFile -Path $menuPath
    
    if ($menu) {
        $script:MenuCache[$MenuId] = $menu
    }
    
    return $menu
}

function Get-AllMenus {
    <#
    .SYNOPSIS
        Gets all available menu definitions
    .OUTPUTS
        Array of menu definition hashtables
    #>
    $menus = @()
    
    if (-not (Test-Path $script:MenusDir)) {
        return $menus
    }
    
    $menuFiles = Get-ChildItem -Path $script:MenusDir -Filter '*.yaml' -ErrorAction SilentlyContinue
    
    foreach ($file in $menuFiles) {
        $menu = Read-MenuFile -Path $file.FullName
        if ($menu) {
            $menus += $menu
        }
    }
    
    return $menus
}

# ═══════════════════════════════════════════════════════════════
#                     CONTEXT MANAGEMENT
# ═══════════════════════════════════════════════════════════════

function Set-MenuContext {
    <#
    .SYNOPSIS
        Sets context data for menu rendering
    .PARAMETER Key
        Context key
    .PARAMETER Value
        Context value
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        
        [object]$Value
    )
    
    $script:MenuContext[$Key] = $Value
}

function Get-MenuContext {
    <#
    .SYNOPSIS
        Gets context data for menu rendering
    .PARAMETER Key
        Context key
    .OUTPUTS
        Context value or $null
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )
    
    if ($script:MenuContext.ContainsKey($Key)) {
        return $script:MenuContext[$Key]
    }
    return $null
}

function Clear-MenuContext {
    <#
    .SYNOPSIS
        Clears all menu context
    #>
    $script:MenuContext.Clear()
}

# ═══════════════════════════════════════════════════════════════
#                     MENU RENDERING
# ═══════════════════════════════════════════════════════════════

function Show-MenuHeader {
    <#
    .SYNOPSIS
        Renders a consistent menu header
    .PARAMETER Title
        Menu title
    .PARAMETER Description
        Optional description
    .PARAMETER Color
        Header color (default: Cyan)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        
        [string]$Description = '',
        
        [string]$Color = 'Cyan'
    )
    
    Write-Host ""
    
    # Show consolidated mode indicator if any modes are active
    Show-ModeIndicator
    
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $Color
    Write-Host "  $Title" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor $Color
    
    if ($Description) {
        Write-Host ""
        Write-Host "  $Description" -ForegroundColor Gray
    }
    
    Write-Host ""
}

function Show-MenuBreadcrumb {
    <#
    .SYNOPSIS
        Shows breadcrumb navigation trail with current location
    .PARAMETER CurrentMenuId
        ID of the current menu being displayed
    #>
    param(
        [string]$CurrentMenuId = ''
    )
    
    # Build breadcrumb trail
    $breadcrumb = @()
    $items = $script:NavigationStack.ToArray()
    [Array]::Reverse($items)
    
    # Start with Home icon
    if ($breadcrumb.Count -eq 0 -and [string]::IsNullOrEmpty($CurrentMenuId)) {
        $breadcrumb += "Home"
    } else {
        $breadcrumb += "🏠 Home"
    }
    
    # Add navigation stack items with friendly names
    foreach ($item in $items) {
        $menuName = Get-FriendlyMenuName -MenuId $item.MenuId
        $breadcrumb += $menuName
    }
    
    # Add current menu if provided
    if (-not [string]::IsNullOrEmpty($CurrentMenuId)) {
        $menuName = Get-FriendlyMenuName -MenuId $CurrentMenuId
        $breadcrumb += $menuName
    }
    
    # Display breadcrumb
    $trail = $breadcrumb -join ' > '
    Write-Host ""
    Write-Host "  📍 $trail" -ForegroundColor DarkCyan
    Write-Host ""
}

function Get-FriendlyMenuName {
    <#
    .SYNOPSIS
        Converts menu ID to friendly display name
    #>
    param(
        [string]$MenuId
    )
    
    $nameMap = @{
        'home'        = 'Home'
        'workspace'   = 'Workspace'
        'projects'    = 'Projects'
        'settings'    = 'Settings'
        'tasks'       = 'Tasks'
        'spec-mode'   = 'Spec Mode'
        'presets'     = 'Presets'
        'references'  = 'References'
    }
    
    if ($nameMap.ContainsKey($MenuId)) {
        return $nameMap[$MenuId]
    }
    
    # Fallback: capitalize first letter
    return $MenuId.Substring(0,1).ToUpper() + $MenuId.Substring(1)
}

function Show-MenuItems {
    <#
    .SYNOPSIS
        Renders menu items
    .PARAMETER Items
        Array of menu item hashtables
    .PARAMETER Context
        Optional context for conditional items
    .OUTPUTS
        Hashtable mapping keys to items
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        
        [hashtable]$Context = @{}
    )
    
    $keyMap = @{}
    
    foreach ($item in $Items) {
        # Handle separators
        if ($item.Separator) {
            Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor Gray
            continue
        }
        
        # Check condition if present
        if ($item.Condition) {
            $conditionMet = Invoke-MenuCondition -Condition $item.Condition -Context $Context
            if (-not $conditionMet) {
                continue
            }
        }
        
        $key = $item.Key
        $label = $item.Label
        $color = $item.Color
        
        # Resolve dynamic labels
        if ($label -match '\{\{([^}]+)\}\}') {
            $label = Resolve-MenuTemplate -Template $label -Context $Context
        }
        
        # Handle disabled items (display only, no key binding)
        if ($item.Disabled -or ([string]::IsNullOrEmpty($key) -and [string]::IsNullOrEmpty($item.Action))) {
            Write-Host "  $label" -ForegroundColor DarkGray
            continue
        }
        
        Write-Host "  [$key] $label" -ForegroundColor $color
        
        if ($item.Description) {
            $desc = Resolve-MenuTemplate -Template $item.Description -Context $Context
            Write-Host "      $desc" -ForegroundColor Gray
        }
        
        $keyMap[$key.ToUpper()] = $item
    }
    
    return $keyMap
}

function Show-MenuFooter {
    <#
    .SYNOPSIS
        Renders menu footer with navigation options
    .PARAMETER ShowBack
        Show back navigation option
    .PARAMETER ShowQuit
        Show quit option
    .PARAMETER ShowEsc
        Show ESC key hint
    #>
    param(
        [bool]$ShowBack = $true,
        [bool]$ShowQuit = $true,
        [bool]$ShowEsc = $false
    )
    
    Write-Host ""
    
    $navOptions = @()
    
    if ($ShowEsc) {
        # ESC is for cancel only, not navigation
        $navOptions += "ESC = Cancel"
    }
    
    if ($ShowBack -and (Get-NavigationDepth) -gt 0) {
        $navOptions += "[B] Back"
    }
    
    if ($ShowQuit) {
        $navOptions += "[Q] Quit"
    }
    
    if ($navOptions.Count -gt 0) {
        Write-Host "  ────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  $($navOptions -join '  |  ')" -ForegroundColor DarkGray
    }
    
    Write-Host ""
}

function Invoke-MenuCondition {
    <#
    .SYNOPSIS
        Evaluates a menu item condition
    .PARAMETER Condition
        Condition string to evaluate
    .PARAMETER Context
        Context for condition evaluation
    .OUTPUTS
        $true if condition is met, $false otherwise
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Condition,
        
        [hashtable]$Context = @{}
    )
    
    # Built-in conditions
    switch -Wildcard ($Condition) {
        'has_sessions' {
            $sessions = Get-MenuContext -Key 'Sessions'
            return ($sessions -and $sessions.Count -gt 0)
        }
        'has_projects' {
            $projects = Get-MenuContext -Key 'Projects'
            return ($projects -and $projects.Count -gt 0)
        }
        'has_active_session' {
            $activeId = Get-MenuContext -Key 'ActiveSessionId'
            return (-not [string]::IsNullOrEmpty($activeId))
        }
        'has_active_project' {
            $activeId = Get-MenuContext -Key 'ActiveProjectId'
            return (-not [string]::IsNullOrEmpty($activeId))
        }
        'has_specs' {
            $specs = Get-MenuContext -Key 'Specs'
            return ($specs -and $specs.Count -gt 0)
        }
        'has_pending_tasks' {
            $stats = Get-MenuContext -Key 'TaskStats'
            return ($stats -and $stats.Pending -gt 0)
        }
        'no_sessions' {
            $sessions = Get-MenuContext -Key 'Sessions'
            return (-not $sessions -or $sessions.Count -eq 0)
        }
        'no_projects' {
            $projects = Get-MenuContext -Key 'Projects'
            return (-not $projects -or $projects.Count -eq 0)
        }
        'has_references' {
            $refs = Get-MenuContext -Key 'References'
            return ($refs -and $refs.Count -gt 0)
        }
        default {
            # Try to evaluate as PowerShell expression in context
            try {
                $result = Invoke-Expression $Condition
                return [bool]$result
            } catch {
                return $true  # Default to showing item if condition fails
            }
        }
    }
}

function Resolve-MenuTemplate {
    <#
    .SYNOPSIS
        Resolves template placeholders in menu text
    .PARAMETER Template
        Template string with {{placeholder}} syntax
    .PARAMETER Context
        Context for placeholder resolution
    .OUTPUTS
        Resolved string
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Template,
        
        [hashtable]$Context = @{}
    )
    
    $result = $Template
    
    # Replace {{key}} placeholders
    while ($result -match '\{\{([^}]+)\}\}') {
        $placeholder = $Matches[1]
        $value = ''
        
        # Check context first
        if ($Context.ContainsKey($placeholder)) {
            $value = $Context[$placeholder]
        }
        # Then check menu context
        else {
            $contextValue = Get-MenuContext -Key $placeholder
            if ($contextValue) {
                $value = $contextValue
            }
        }
        
        $result = $result -replace [regex]::Escape("{{$placeholder}}"), $value
    }
    
    return $result
}

# ═══════════════════════════════════════════════════════════════
#                     MENU EXECUTION
# ═══════════════════════════════════════════════════════════════

function Read-MenuInput {
    <#
    .SYNOPSIS
        Reads user input with support for ESC key to go back
    .PARAMETER Prompt
        The prompt to display
    .OUTPUTS
        Hashtable with Type ('text', 'escape', 'enter') and Value
    #>
    param(
        [string]$Prompt = "  Select option"
    )
    
    Write-Host "${Prompt}: " -NoNewline
    
    $inputBuffer = ""
    
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
        # ESC key (VirtualKeyCode 27)
        if ($key.VirtualKeyCode -eq 27) {
            Write-Host ""  # New line after ESC
            return @{ Type = 'escape'; Value = $null }
        }
        
        # Enter key
        if ($key.VirtualKeyCode -eq 13) {
            Write-Host ""  # New line after Enter
            return @{ Type = 'text'; Value = $inputBuffer }
        }
        
        # Backspace
        if ($key.VirtualKeyCode -eq 8) {
            if ($inputBuffer.Length -gt 0) {
                $inputBuffer = $inputBuffer.Substring(0, $inputBuffer.Length - 1)
                # Erase character from display
                Write-Host "`b `b" -NoNewline
            }
            continue
        }
        
        # Regular character (printable)
        if ($key.Character -match '[\x20-\x7E]') {
            $inputBuffer += $key.Character
            Write-Host $key.Character -NoNewline
        }
    }
}

function Show-Menu {
    <#
    .SYNOPSIS
        Displays a menu and handles user selection
    .DESCRIPTION
        When CLI framework is available, uses arrow-key navigation.
        Falls back to hotkey-based selection otherwise.
    .PARAMETER MenuId
        ID of the menu to display (loads from file)
    .PARAMETER Menu
        Direct menu definition (alternative to MenuId)
    .PARAMETER Context
        Additional context for rendering
    .PARAMETER ForceHotkeys
        Force hotkey-based selection even if arrow navigation is available
    .OUTPUTS
        Hashtable with Action and any additional data
    #>
    param(
        [string]$MenuId = '',
        
        [hashtable]$Menu = $null,
        
        [hashtable]$Context = @{},
        
        [switch]$ForceHotkeys
    )
    
    # Load menu from file or use provided
    if (-not $Menu) {
        if (-not $MenuId) {
            Write-Host "  Error: No menu specified" -ForegroundColor Red
            return @{ Action = 'error' }
        }
        
        $Menu = Get-Menu -MenuId $MenuId
        
        if (-not $Menu) {
            Write-Host "  Error: Menu '$MenuId' not found" -ForegroundColor Red
            return @{ Action = 'error' }
        }
    }
    
    # Use arrow-key navigation if CLI framework is available
    if ($script:UseArrowNavigation -and $script:CLIFrameworkLoaded -and (-not $ForceHotkeys)) {
        return Show-MenuWithArrowNavigation -Menu $Menu -Context $Context
    }
    
    # Fall back to hotkey-based selection
    return Show-MenuWithHotkeys -Menu $Menu -Context $Context
}

function Show-MenuWithArrowNavigation {
    <#
    .SYNOPSIS
        Shows menu with arrow-key navigation using CLI framework
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Menu,
        
        [hashtable]$Context = @{}
    )
    
    # Build menu items for CLI framework
    $cliItems = @()
    $itemMap = @{}  # Maps CLI item values back to original menu items
    $itemIndex = 0
    
    foreach ($item in $Menu.Items) {
        # Skip separators - add as separator in CLI format
        if ($item.Separator) {
            $cliItems += New-MenuSeparator -Text ''
            continue
        }
        
        # Check for disabled items or category headers (items with no Key and no Action) - make non-selectable
        if ($item.Disabled -or ([string]::IsNullOrEmpty($item.Key) -and [string]::IsNullOrEmpty($item.Action))) {
            $label = $item.Label
            if ($label -match '\{\{([^}]+)\}\}') {
                $label = Resolve-MenuTemplate -Template $label -Context $Context
            }
            $cliItems += New-MenuHeader -Text $label
            continue
        }
        
        # Check condition
        if ($item.Condition) {
            $conditionMet = Invoke-MenuCondition -Condition $item.Condition -Context $Context
            if (-not $conditionMet) {
                continue
            }
        }
        
        $label = $item.Label
        if ($label -match '\{\{([^}]+)\}\}') {
            $label = Resolve-MenuTemplate -Template $label -Context $Context
        }
        
        $description = ''
        if ($item.Description) {
            $description = Resolve-MenuTemplate -Template $item.Description -Context $Context
        }
        
        $value = "item_$itemIndex"
        $itemMap[$value] = $item
        
        $cliItems += New-MenuItem -Text $label -Value $value -Hotkey $item.Key -Description $description
        $itemIndex++
    }
    
    # Add navigation items
    if ($Menu.ShowBack -and (Get-NavigationDepth) -gt 0) {
        $cliItems += New-MenuSeparator
        $cliItems += New-MenuItem -Text "← Back" -Value "__back__" -Hotkey "B"
    }
    
    if ($Menu.ShowQuit) {
        if (-not ($Menu.ShowBack -and (Get-NavigationDepth) -gt 0)) {
            $cliItems += New-MenuSeparator
        }
        $cliItems += New-MenuItem -Text "Quit" -Value "__quit__" -Hotkey "Q"
    }
    
    # Build breadcrumb for display
    $breadcrumb = @()
    $items = $script:NavigationStack.ToArray()
    [Array]::Reverse($items)
    
    # Start with Home
    $breadcrumb += "🏠 Home"
    
    # Add navigation stack items
    foreach ($item in $items) {
        $menuName = Get-FriendlyMenuName -MenuId $item.MenuId
        $breadcrumb += $menuName
    }
    
    # Add current menu
    if (-not [string]::IsNullOrEmpty($Menu.Id)) {
        $menuName = Get-FriendlyMenuName -MenuId $Menu.Id
        $breadcrumb += $menuName
    }
    
    $breadcrumbText = "📍 " + ($breadcrumb -join ' > ')
    
    # Prepend breadcrumb to title
    $displayTitle = $breadcrumbText + "`n" + $Menu.Title
    
    # Display menu with arrow navigation
    $description = if ($Menu.Description) { $Menu.Description } else { "Use ↑↓ to navigate, Enter to select" }
    $selected = Show-SingleSelectMenu -Title $displayTitle -Items $cliItems -Description $description -ShowHotkeys
    
    # Log menu display
    $menuId = if ($Menu.Id) { $Menu.Id } else { 'UnnamedMenu' }
    
    # Handle cancellation (ESC = cancel operation, NOT automatic back)
    # Back navigation should ONLY be via menu item selection
    if ($null -eq $selected) {
        # ESC was pressed - return cancel action
        # Caller decides what to do (might exit or show menu again)
        if (Get-Command Write-LogUserAction -ErrorAction SilentlyContinue) {
            Write-LogUserAction -Action 'CANCEL' -Context $menuId -Details "User pressed ESC"
        }
        return @{ Action = 'cancel' }
    }
    
    # Handle navigation items
    if ($selected -eq '__back__') {
        if (Get-Command Write-LogUserAction -ErrorAction SilentlyContinue) {
            Write-LogUserAction -Action 'BACK' -Context $menuId -Selection 'Back'
        }
        $previousState = Pop-MenuState
        return @{ Action = 'back'; PreviousMenu = $previousState.MenuId; Context = $previousState.Context }
    }
    
    if ($selected -eq '__quit__') {
        if (Get-Command Write-LogUserAction -ErrorAction SilentlyContinue) {
            Write-LogUserAction -Action 'QUIT' -Context $menuId -Selection 'Quit'
        }
        return @{ Action = 'quit' }
    }
    
    # Handle regular item selection
    if ($itemMap.ContainsKey($selected)) {
        $selectedItem = $itemMap[$selected]
        
        # Log the selection
        if (Get-Command Write-LogUserAction -ErrorAction SilentlyContinue) {
            $selectedLabel = if ($selectedItem.Label) { $selectedItem.Label } else { $selectedItem.Action }
            Write-LogUserAction -Action 'MENU_SELECT' -Context $menuId -Selection $selectedLabel -Details "Action: $($selectedItem.Action)"
        }
        
        $result = @{
            Action = $selectedItem.Action
            Key    = $selectedItem.Key
        }
        
        # Handle submenu navigation
        if ($selectedItem.Submenu) {
            Push-MenuState -MenuId $Menu.Id -Context $Context
            $result.Action = 'submenu'
            $result.Submenu = $selectedItem.Submenu
        }
        
        return $result
    }
    
    return @{ Action = 'invalid' }
}

function Show-MenuWithHotkeys {
    <#
    .SYNOPSIS
        Shows menu with traditional hotkey-based selection (fallback)
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Menu,
        
        [hashtable]$Context = @{}
    )
    
    # Render menu
    Show-MenuHeader -Title $Menu.Title -Description $Menu.Description -Color $Menu.Color
    
    # Always show breadcrumb
    Show-MenuBreadcrumb -CurrentMenuId $Menu.Id
    
    $keyMap = Show-MenuItems -Items $Menu.Items -Context $Context
    Show-MenuFooter -ShowBack $Menu.ShowBack -ShowQuit $Menu.ShowQuit -ShowEsc $true
    
    # Get user input with ESC support
    $input = Read-MenuInput -Prompt "  Select option"
    
    # Handle ESC key - cancel operation (not automatic back)
    # Back should only be via 'B' hotkey or menu item
    if ($input.Type -eq 'escape') {
        return @{ Action = 'cancel' }
    }
    
    $choice = $input.Value
    
    # Handle empty input
    if ([string]::IsNullOrWhiteSpace($choice)) {
        # Check for default action
        $defaultItem = $Menu.Items | Where-Object { $_.Key -eq 'Enter' -or $_.Key -eq '' } | Select-Object -First 1
        if ($defaultItem) {
            return @{ Action = $defaultItem.Action }
        }
        return @{ Action = 'default' }
    }
    
    $choiceUpper = $choice.ToUpper()
    
    # Handle navigation keys
    if ($choiceUpper -eq 'B' -and $Menu.ShowBack -and (Get-NavigationDepth) -gt 0) {
        $previousState = Pop-MenuState
        return @{ Action = 'back'; PreviousMenu = $previousState.MenuId; Context = $previousState.Context }
    }
    
    if ($choiceUpper -eq 'Q' -and $Menu.ShowQuit) {
        return @{ Action = 'quit' }
    }
    
    # Check for matching menu item
    if ($keyMap.ContainsKey($choiceUpper)) {
        $selectedItem = $keyMap[$choiceUpper]
        
        $result = @{
            Action = $selectedItem.Action
            Key    = $selectedItem.Key
        }
        
        # Handle submenu navigation
        if ($selectedItem.Submenu) {
            Push-MenuState -MenuId $Menu.Id -Context $Context
            $result.Action = 'submenu'
            $result.Submenu = $selectedItem.Submenu
        }
        
        return $result
    }
    
    # Check for numeric input (dynamic list items)
    $numericValue = 0
    if ([int]::TryParse($choice, [ref]$numericValue)) {
        return @{ Action = 'select'; Index = $numericValue; Value = $choice }
    }
    
    # Invalid input
    Write-Host "  Invalid option: $choice" -ForegroundColor Red
    return @{ Action = 'invalid' }
}

function Invoke-MenuLoop {
    <#
    .SYNOPSIS
        Runs a menu loop until user exits or action completes
    .PARAMETER StartMenu
        Initial menu ID to display
    .PARAMETER Context
        Initial context
    .PARAMETER ActionHandler
        Scriptblock to handle menu actions
    .OUTPUTS
        Final action result
    #>
    param(
        [Parameter(Mandatory)]
        [string]$StartMenu,
        
        [hashtable]$Context = @{},
        
        [scriptblock]$ActionHandler = $null
    )
    
    Clear-NavigationStack
    $currentMenuId = $StartMenu
    $currentContext = $Context.Clone()
    
    while ($true) {
        $result = Show-Menu -MenuId $currentMenuId -Context $currentContext
        
        switch ($result.Action) {
            'quit' {
                return @{ Action = 'quit' }
            }
            'back' {
                if ($result.PreviousMenu) {
                    $currentMenuId = $result.PreviousMenu
                    $currentContext = $result.Context
                } else {
                    # No previous menu, treat as quit
                    return @{ Action = 'quit' }
                }
            }
            'submenu' {
                $currentMenuId = $result.Submenu
            }
            'invalid' {
                # Stay on current menu
                continue
            }
            'error' {
                return @{ Action = 'error' }
            }
            default {
                # Handle action with provided handler or return result
                if ($ActionHandler) {
                    $handlerResult = & $ActionHandler $result $currentContext
                    
                    if ($handlerResult.Continue) {
                        # Update context if provided
                        if ($handlerResult.Context) {
                            $currentContext = $handlerResult.Context
                        }
                        # Change menu if specified
                        if ($handlerResult.NextMenu) {
                            Push-MenuState -MenuId $currentMenuId -Context $currentContext
                            $currentMenuId = $handlerResult.NextMenu
                        }
                        continue
                    } else {
                        return $handlerResult
                    }
                } else {
                    return $result
                }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                     DYNAMIC MENU BUILDERS
# ═══════════════════════════════════════════════════════════════

function New-DynamicMenu {
    <#
    .SYNOPSIS
        Creates a dynamic menu from runtime data
    .PARAMETER Id
        Menu ID
    .PARAMETER Title
        Menu title
    .PARAMETER Items
        Array of item definitions
    .PARAMETER Description
        Optional description
    .PARAMETER Color
        Header color
    .PARAMETER ShowBack
        Show back option
    .PARAMETER ShowQuit
        Show quit option
    .OUTPUTS
        Menu definition hashtable
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [string]$Title,
        
        [array]$Items = @(),
        
        [string]$Description = '',
        
        [string]$Color = 'Cyan',
        
        [bool]$ShowBack = $true,
        
        [bool]$ShowQuit = $true
    )
    
    return @{
        Id          = $Id
        Title       = $Title
        Description = $Description
        Color       = $Color
        Items       = $Items
        ShowBack    = $ShowBack
        ShowQuit    = $ShowQuit
    }
}

function New-RalphMenuItem {
    <#
    .SYNOPSIS
        Creates a new Ralph menu item (for YAML-style menus)
    .DESCRIPTION
        This creates menu items in Ralph's internal format.
        For CLI framework menus, use New-MenuItem instead.
    .PARAMETER Key
        Keyboard key/shortcut
    .PARAMETER Label
        Display label
    .PARAMETER Action
        Action identifier
    .PARAMETER Description
        Optional description
    .PARAMETER Color
        Display color
    .PARAMETER Submenu
        Submenu to navigate to
    .PARAMETER Condition
        Condition for visibility
    .PARAMETER Disabled
        Whether item is disabled (display only)
    .OUTPUTS
        Menu item hashtable
    #>
    param(
        [AllowEmptyString()]
        [string]$Key = '',
        
        [Parameter(Mandatory)]
        [string]$Label,
        
        [string]$Action = '',
        
        [string]$Description = '',
        
        [string]$Color = 'White',
        
        [string]$Submenu = $null,
        
        [string]$Condition = $null,
        
        [switch]$Disabled
    )
    
    return @{
        Key         = $Key
        Label       = $Label
        Action      = $Action
        Description = $Description
        Color       = $Color
        Submenu     = $Submenu
        Condition   = $Condition
        Separator   = $false
        Disabled    = $Disabled.IsPresent
    }
}

function New-RalphMenuSeparator {
    <#
    .SYNOPSIS
        Creates a Ralph menu separator (for YAML-style menus)
    .OUTPUTS
        Separator item hashtable
    #>
    return @{ Separator = $true }
}

# ═══════════════════════════════════════════════════════════════
#                     BUILT-IN MENUS
# ═══════════════════════════════════════════════════════════════

function Show-SpecCreationMenu {
    <#
    .SYNOPSIS
        Shows spec creation menu
    .PARAMETER HasExistingSpecs
        Whether existing specs exist
    .OUTPUTS
        Action result hashtable
    #>
    param(
        [bool]$HasExistingSpecs = $false
    )
    
    $items = @()
    
    if ($HasExistingSpecs) {
        $items += New-RalphMenuItem -Key '1' -Label 'Use existing specs' -Action 'use-existing' -Color 'Green'
        $items += New-RalphMenuItem -Key '2' -Label 'Create new spec with Ralph' -Action 'create-new' -Color 'Yellow'
    } else {
        $items += New-RalphMenuItem -Key '1' -Label 'Create spec (interview mode)' -Action 'interview' -Description 'Ralph asks questions' -Color 'Green'
        $items += New-RalphMenuItem -Key '2' -Label 'Quick spec' -Action 'quick' -Description 'Describe in one prompt' -Color 'Yellow'
    }
    
    $title = if ($HasExistingSpecs) { 'RALPH - SPECIFICATION SETUP' } else { 'RALPH - CREATE SPECIFICATION' }
    
    $menu = New-DynamicMenu -Id 'spec' -Title $title -Items $items -Color 'Magenta'
    
    return Show-Menu -Menu $menu
}

function Show-ModelSelectionMenu {
    <#
    .SYNOPSIS
        Shows AI model selection menu
    .PARAMETER Models
        Array of available model hashtables
    .PARAMETER CurrentModel
        Currently selected model name
    .OUTPUTS
        Selected model name or $null
    #>
    param(
        [array]$Models = @(),
        [string]$CurrentModel = ''
    )
    
    $items = @()
    
    for ($i = 0; $i -lt $Models.Count; $i++) {
        $m = $Models[$i]
        $num = $i + 1
        $indicator = if ($m.Name -eq $CurrentModel) { " ✓" } else { "" }
        $defaultTag = if ($m.Default) { " (default)" } else { "" }
        $color = if ($m.Name -eq $CurrentModel) { 'Green' } else { 'White' }
        
        $items += New-RalphMenuItem -Key "$num" -Label "$($m.Display) $($m.Multiplier)$defaultTag$indicator" -Action 'select_model' -Color $color
    }
    
    $items += New-RalphMenuSeparator
    $items += New-RalphMenuItem -Key 'Enter' -Label "Keep current ($CurrentModel)" -Action 'keep' -Color 'Gray'
    
    $menu = New-DynamicMenu -Id 'model' -Title 'SELECT AI MODEL' -Items $items -Color 'Magenta' -ShowBack $false
    
    $result = Show-Menu -Menu $menu
    
    if ($result.Action -eq 'select_model') {
        $index = [int]$result.Key - 1
        if ($index -ge 0 -and $index -lt $Models.Count) {
            return $Models[$index].Name
        }
    }
    
    return $CurrentModel
}

function Show-ConfirmMenu {
    <#
    .SYNOPSIS
        Shows a confirmation menu with arrow navigation
    .PARAMETER Title
        Confirmation title
    .PARAMETER Message
        Confirmation message
    .PARAMETER ConfirmLabel
        Label for confirm option
    .PARAMETER CancelLabel
        Label for cancel option
    .PARAMETER DefaultYes
        If true, Yes is pre-selected
    .OUTPUTS
        $true if confirmed, $false otherwise
    #>
    param(
        [string]$Title = 'Confirm Action',
        [string]$Message = 'Are you sure?',
        [string]$ConfirmLabel = 'Yes, proceed',
        [string]$CancelLabel = 'No, cancel',
        [switch]$DefaultYes
    )
    
    $items = @(
        New-RalphMenuItem -Key 'Y' -Label $ConfirmLabel -Action 'confirm' -Color 'Green'
        New-RalphMenuItem -Key 'N' -Label $CancelLabel -Action 'cancel' -Color 'Red'
    )
    
    $menu = New-DynamicMenu -Id 'confirm' -Title $Title -Items $items -Description $Message -ShowBack $false -ShowQuit $false
    
    $result = Show-Menu -Menu $menu
    
    return ($result.Action -eq 'confirm')
}

# ═══════════════════════════════════════════════════════════════
#                     UNIFIED INPUT COMPONENTS
# ═══════════════════════════════════════════════════════════════

function Show-ArrowConfirm {
    <#
    .SYNOPSIS
        Shows a Yes/No confirmation with arrow navigation
    .PARAMETER Message
        The confirmation message
    .PARAMETER Title
        Optional title for the confirmation
    .PARAMETER DefaultYes
        If true, Yes is pre-selected (default index 0)
    .PARAMETER YesLabel
        Custom label for Yes option
    .PARAMETER NoLabel
        Custom label for No option
    .PARAMETER AllowBack
        Allow ESC to go back (returns $null)
    .OUTPUTS
        $true for Yes, $false for No, $null if cancelled/back
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$Title = '',
        [switch]$DefaultYes,
        [string]$YesLabel = 'Yes',
        [string]$NoLabel = 'No',
        [switch]$AllowBack
    )
    
    if ($script:UseArrowNavigation -and $script:CLIFrameworkLoaded) {
        $items = @(
            New-MenuItem -Text $YesLabel -Value 'yes' -Hotkey 'Y'
            New-MenuItem -Text $NoLabel -Value 'no' -Hotkey 'N'
        )
        
        $defaultIndex = if ($DefaultYes) { 0 } else { 1 }
        $displayTitle = if ($Title) { $Title } else { 'Confirm' }
        
        $result = Show-SingleSelectMenu -Title $displayTitle -Items $items -Description $Message -DefaultIndex $defaultIndex -ShowHotkeys
        
        if ($null -eq $result) {
            if ($AllowBack) { return $null }
            return $false
        }
        
        return ($result -eq 'yes')
    } else {
        # Fallback to text-based confirmation
        Write-Host ""
        Write-Host "  $Message" -ForegroundColor Yellow
        $hint = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
        Write-Host "  $hint " -NoNewline
        
        $input = Read-MenuInput -Prompt ""
        if ($input.Type -eq 'escape') {
            if ($AllowBack) { return $null }
            return $false
        }
        
        $value = $input.Value
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $DefaultYes
        }
        
        return ($value.ToUpper() -eq 'Y')
    }
}

function Show-ArrowChoice {
    <#
    .SYNOPSIS
        Shows a multi-choice menu with arrow navigation (replaces "Select 1/2" patterns)
    .PARAMETER Title
        Menu title
    .PARAMETER Message
        Description/message
    .PARAMETER Choices
        Array of choice definitions. Each can be:
        - String: Used as both label and value
        - Hashtable: { Label, Value, Hotkey, Description, Default }
    .PARAMETER NoBack
        Hide the back option (back is shown by default)
    .PARAMETER AllowBack
        (Deprecated) Kept for backward compatibility, back is now shown by default
    .OUTPUTS
        Selected value or $null if cancelled/back
    .EXAMPLE
        $mode = Show-ArrowChoice -Title "Select Mode" -Choices @(
            @{ Label = "Isolated - Session has own specs/"; Value = "isolated"; Hotkey = "1"; Default = $true }
            @{ Label = "Shared - Uses ralph/specs/ folder"; Value = "shared"; Hotkey = "2" }
        )
    #>
    param(
        [string]$Title = 'Select Option',
        [string]$Message = '',
        
        [Parameter(Mandatory)]
        [array]$Choices,
        
        [switch]$AllowBack,  # Kept for backward compatibility
        [switch]$NoBack      # New: explicitly hide back option
    )
    
    # Back is shown by default unless -NoBack is specified
    $showBack = -not $NoBack
    
    if ($script:UseArrowNavigation -and $script:CLIFrameworkLoaded) {
        $items = @()
        $defaultIndex = 0
        $valueMap = @{}
        $index = 0
        
        foreach ($choice in $Choices) {
            if ($choice -is [string]) {
                $items += New-MenuItem -Text $choice -Value "choice_$index"
                $valueMap["choice_$index"] = $choice
            } else {
                $hotkey = if ($choice -is [hashtable] -and $choice.ContainsKey('Hotkey')) { $choice.Hotkey } elseif ($choice.PSObject.Properties['Hotkey']) { $choice.Hotkey } else { '' }
                $desc = if ($choice -is [hashtable] -and $choice.ContainsKey('Description')) { $choice.Description } elseif ($choice.PSObject.Properties['Description']) { $choice.Description } else { '' }
                $label = if ($choice -is [hashtable] -and $choice.ContainsKey('Label')) { $choice.Label } elseif ($choice.PSObject.Properties['Label']) { $choice.Label } else { $choice.ToString() }
                $value = if ($choice -is [hashtable] -and $choice.ContainsKey('Value')) { $choice.Value } elseif ($choice.PSObject.Properties['Value']) { $choice.Value } else { $choice.ToString() }
                $items += New-MenuItem -Text $label -Value "choice_$index" -Hotkey $hotkey -Description $desc
                $valueMap["choice_$index"] = $value
                
                # Check if Default property exists and is true
                if (($choice -is [hashtable] -and $choice.ContainsKey('Default') -and $choice.Default) -or ($choice -isnot [hashtable] -and $choice.PSObject.Properties['Default'] -and $choice.Default)) {
                    $defaultIndex = $index
                }
            }
            $index++
        }
        
        if ($showBack) {
            $items += New-MenuSeparator
            $items += New-MenuItem -Text "← Back" -Value "__back__" -Hotkey "B"
        }
        
        $result = Show-SingleSelectMenu -Title $Title -Items $items -Description $Message -DefaultIndex $defaultIndex -ShowHotkeys
        
        if ($null -eq $result -or $result -eq '__back__') {
            return $null
        }
        
        if ($valueMap.ContainsKey($result)) {
            return $valueMap[$result]
        }
        
        return $null
    } else {
        # Fallback to text-based selection
        Clear-HostConditional
        
        Write-Host ""
        if ($Title) {
            Write-Host "  $Title" -ForegroundColor Cyan
        }
        if ($Message) {
            Write-Host "  $Message" -ForegroundColor Gray
        }
        Write-Host ""
        
        $index = 1
        $keyMap = @{}
        foreach ($choice in $Choices) {
            $label = if ($choice -is [string]) { $choice } elseif ($choice -is [hashtable] -and $choice.ContainsKey('Label')) { $choice.Label } elseif ($choice.PSObject.Properties['Label']) { $choice.Label } else { $choice.ToString() }
            $hotkey = if ($choice -is [hashtable] -and $choice.ContainsKey('Hotkey')) { $choice.Hotkey } elseif ($choice -isnot [hashtable] -and $choice.PSObject.Properties['Hotkey']) { $choice.Hotkey } else { $index.ToString() }
            Write-Host "  [$hotkey] $label" -ForegroundColor White
            $keyMap[$hotkey.ToUpper()] = if ($choice -is [string]) { $choice } elseif ($choice -is [hashtable] -and $choice.ContainsKey('Value')) { $choice.Value } elseif ($choice.PSObject.Properties['Value']) { $choice.Value } else { $choice.ToString() }
            $index++
        }
        
        # Show back option in fallback mode too
        if ($showBack) {
            Write-Host ""
            Write-Host "  [B] ← Back" -ForegroundColor DarkGray
        }
        
        Write-Host ""
        $input = Read-MenuInput -Prompt "  Select"
        
        if ($input.Type -eq 'escape') {
            return $null
        }
        
        $key = $input.Value.ToUpper()
        
        # Handle back selection
        if ($showBack -and $key -eq 'B') {
            return $null
        }
        
        if ($keyMap.ContainsKey($key)) {
            return $keyMap[$key]
        }
        
        # Return first option as default if empty
        if ([string]::IsNullOrWhiteSpace($input.Value)) {
            $firstChoice = $Choices[0]
            return if ($firstChoice -is [string]) { $firstChoice } else { $firstChoice.Value }
        }
        
        return $null
    }
}

function Show-ArrowTextInput {
    <#
    .SYNOPSIS
        Shows a text input prompt with ESC support
    .PARAMETER Prompt
        The prompt text
    .PARAMETER Default
        Default value
    .PARAMETER Required
        If true, empty input is not allowed
    .PARAMETER AllowBack
        Allow ESC to go back
    .OUTPUTS
        Hashtable with: Type (text/back), Value
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        
        [string]$Default = '',
        [switch]$Required,
        [switch]$AllowBack
    )
    
    Write-Host ""
    Write-Host "  $Prompt" -NoNewline -ForegroundColor Cyan
    if ($Default) {
        Write-Host " (default: $Default)" -NoNewline -ForegroundColor DarkGray
    }
    Write-Host ": " -NoNewline
    
    while ($true) {
        $input = Read-MenuInput -Prompt ""
        
        if ($input.Type -eq 'escape') {
            if ($AllowBack) {
                return @{ Type = 'back'; Value = $null }
            }
            continue
        }
        
        $value = $input.Value
        if ([string]::IsNullOrWhiteSpace($value) -and $Default) {
            $value = $Default
        }
        
        if ($Required -and [string]::IsNullOrWhiteSpace($value)) {
            Write-Host "  This field is required" -ForegroundColor Red
            Write-Host "  $Prompt`: " -NoNewline
            continue
        }
        
        return @{ Type = 'text'; Value = $value }
    }
}

function Show-IterationMenu {
    <#
    .SYNOPSIS
        Shows iteration settings menu with arrow navigation
    .PARAMETER PendingTasks
        Number of pending tasks
    .PARAMETER CurrentMax
        Current max iterations setting
    .OUTPUTS
        Number of iterations (0 = unlimited, -1 = cancelled)
    #>
    param(
        [int]$PendingTasks = 0,
        [int]$CurrentMax = 0
    )
    
    $message = "Pending tasks: $PendingTasks. By default, Ralph runs until ALL tasks complete."
    
    $result = Show-ArrowChoice -Title "BUILD ITERATION SETTINGS" -Message $message -AllowBack -Choices @(
        @{ Label = "Run until complete (unlimited) - RECOMMENDED"; Value = "unlimited"; Hotkey = "U"; Default = $true }
        @{ Label = "Specify maximum iteration count"; Value = "custom"; Hotkey = "N" }
        @{ Label = "Cancel and exit"; Value = "quit"; Hotkey = "Q" }
    )
    
    if ($null -eq $result -or $result -eq 'quit') {
        return -1
    }
    
    if ($result -eq 'unlimited') {
        Write-Host ""
        Write-Host "  → Running until all tasks complete (unlimited)" -ForegroundColor Green
        return 0
    }
    
    if ($result -eq 'custom') {
        Write-Host ""
        $input = Show-ArrowTextInput -Prompt "Enter max iterations (0 = unlimited)" -Default "0"
        
        if ($input.Type -eq 'back') {
            return Show-IterationMenu -PendingTasks $PendingTasks -CurrentMax $CurrentMax
        }
        
        $iterCount = 0
        if ([int]::TryParse($input.Value, [ref]$iterCount) -and $iterCount -ge 0) {
            if ($iterCount -eq 0) {
                Write-Host "  → Running until all tasks complete (unlimited)" -ForegroundColor Green
            } else {
                Write-Host "  → Maximum $iterCount iteration(s)" -ForegroundColor Yellow
            }
            return $iterCount
        } else {
            Write-Host "  Invalid input. Using unlimited iterations." -ForegroundColor Yellow
            return 0
        }
    }
    
    return 0
}

function Show-DangerConfirmMenu {
    <#
    .SYNOPSIS
        Shows a dangerous action confirmation (requires typing confirmation text)
    .PARAMETER Title
        Title of the confirmation
    .PARAMETER Message
        Warning message
    .PARAMETER ConfirmText
        Text that must be typed to confirm
    .OUTPUTS
        $true if confirmed, $false otherwise
    #>
    param(
        [string]$Title = 'Dangerous Action',
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$ConfirmText = 'DELETE'
    )
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  ⚠ $Title" -ForegroundColor Red
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Type '$ConfirmText' to confirm: " -NoNewline
    
    $input = Read-MenuInput -Prompt ""
    
    if ($input.Type -eq 'escape') {
        Write-Host "  Cancelled" -ForegroundColor Gray
        return $false
    }
    
    if ($input.Value -eq $ConfirmText) {
        return $true
    }
    
    Write-Host "  Confirmation text did not match. Cancelled." -ForegroundColor Yellow
    return $false
}

function Show-DeleteConfirmMenu {
    <#
    .SYNOPSIS
        Shows a delete confirmation menu with arrow navigation
    .PARAMETER ItemName
        Name of the item to delete
    .PARAMETER ItemType
        Type of item (e.g., "session", "file")
    .OUTPUTS
        $true if confirmed, $false otherwise
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ItemName,
        [string]$ItemType = 'item'
    )
    
    return Show-DangerConfirmMenu -Title "Delete $ItemType" -Message "Delete $ItemType '$ItemName'? This cannot be undone." -ConfirmText "yes"
}

function Show-ListSelectionMenu {
    <#
    .SYNOPSIS
        Shows a list selection menu with arrow navigation
    .PARAMETER Title
        Menu title
    .PARAMETER Items
        Array of items to select from. Each can be:
        - String: Used as both label and value
        - Hashtable: { Label, Value, Description, Icon }
    .PARAMETER AllowBack
        Show back option
    .PARAMETER AllowDelete
        Show delete option for each item
    .PARAMETER EmptyMessage
        Message to show if list is empty
    .OUTPUTS
        Hashtable with: Action (select/delete/back), Value, Index
    #>
    param(
        [string]$Title = 'Select Item',
        
        [array]$Items = @(),
        
        [switch]$AllowBack,
        [switch]$AllowDelete,
        [string]$EmptyMessage = 'No items available'
    )
    
    if ($Items.Count -eq 0) {
        Write-Host ""
        Write-Host "  $EmptyMessage" -ForegroundColor Yellow
        Write-Host ""
        if ($AllowBack) {
            Write-Host "  Press any key to go back..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        return @{ Action = 'back'; Value = $null; Index = -1 }
    }
    
    if ($script:UseArrowNavigation -and $script:CLIFrameworkLoaded) {
        $menuItems = @()
        $valueMap = @{}
        
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            $num = $i + 1
            
            if ($item -is [string]) {
                $menuItems += New-MenuItem -Text $item -Value "item_$i" -Hotkey "$num"
                $valueMap["item_$i"] = $item
            } else {
                # Handle hashtable items
                $label = if ($item -is [hashtable] -and $item.ContainsKey('Label')) { $item.Label } elseif ($item.PSObject.Properties['Label']) { $item.Label } else { $item.ToString() }
                $desc = if ($item -is [hashtable] -and $item.ContainsKey('Description')) { $item.Description } elseif ($item.PSObject.Properties['Description']) { $item.Description } else { '' }
                $icon = if ($item -is [hashtable] -and $item.ContainsKey('Icon')) { $item.Icon } elseif ($item.PSObject.Properties['Icon']) { $item.Icon } else { '' }
                $menuItems += New-MenuItem -Text $label -Value "item_$i" -Hotkey "$num" -Description $desc -Icon $icon
                $valueMap["item_$i"] = if ($item -is [hashtable] -and $item.ContainsKey('Value')) { $item.Value } elseif ($item.PSObject.Properties['Value']) { $item.Value } else { $item }
            }
        }
        
        if ($AllowDelete) {
            $menuItems += New-MenuSeparator
            $menuItems += New-MenuItem -Text "Delete an item" -Value "__delete__" -Hotkey "D"
        }
        
        if ($AllowBack) {
            if (-not $AllowDelete) {
                $menuItems += New-MenuSeparator
            }
            $menuItems += New-MenuItem -Text "← Back" -Value "__back__" -Hotkey "B"
        }
        
        $result = Show-SingleSelectMenu -Title $Title -Items $menuItems -ShowHotkeys
        
        if ($null -eq $result) {
            return @{ Action = 'back'; Value = $null; Index = -1 }
        }
        
        if ($result -eq '__back__') {
            return @{ Action = 'back'; Value = $null; Index = -1 }
        }
        
        if ($result -eq '__delete__') {
            return @{ Action = 'delete'; Value = $null; Index = -1 }
        }
        
        if ($result -match '^item_(\d+)$') {
            $index = [int]$Matches[1]
            return @{ Action = 'select'; Value = $valueMap[$result]; Index = $index }
        }
        
        return @{ Action = 'back'; Value = $null; Index = -1 }
    } else {
        # Fallback to text-based selection
        Write-Host ""
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host ""
        
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]
            $num = $i + 1
            $label = if ($item -is [string]) { $item } elseif ($item -is [hashtable] -and $item.ContainsKey('Label')) { $item.Label } elseif ($item.PSObject.Properties['Label']) { $item.Label } else { $item.ToString() }
            Write-Host "  [$num] $label" -ForegroundColor White
        }
        
        Write-Host ""
        if ($AllowDelete) {
            Write-Host "  [D] Delete an item" -ForegroundColor Yellow
        }
        if ($AllowBack) {
            Write-Host "  [B] Back" -ForegroundColor DarkGray
        }
        Write-Host ""
        
        $input = Read-MenuInput -Prompt "  Select"
        
        if ($input.Type -eq 'escape' -or $input.Value.ToUpper() -eq 'B') {
            return @{ Action = 'back'; Value = $null; Index = -1 }
        }
        
        if ($AllowDelete -and $input.Value.ToUpper() -eq 'D') {
            return @{ Action = 'delete'; Value = $null; Index = -1 }
        }
        
        $index = 0
        if ([int]::TryParse($input.Value, [ref]$index) -and $index -ge 1 -and $index -le $Items.Count) {
            $item = $Items[$index - 1]
            $value = if ($item -is [string]) { $item } elseif ($item -is [hashtable] -and $item.ContainsKey('Value')) { $item.Value } elseif ($item.PSObject.Properties['Value']) { $item.Value } else { $item }
            return @{ Action = 'select'; Value = $value; Index = $index - 1 }
        }
        
        return @{ Action = 'invalid'; Value = $null; Index = -1 }
    }
}

# ═══════════════════════════════════════════════════════════════
#                     REFERENCE MENU FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Show-ReferencesMenu {
    <#
    .SYNOPSIS
        Shows the main references management menu with detailed file counts
    .PARAMETER HasReferences
        Whether references are already configured
    .PARAMETER ReferenceCount
        Number of registered reference files
    .PARAMETER DirectorySummaries
        Array of directory info with file summaries
    .PARAMETER FileSummaries
        Array of file info objects
    .PARAMETER CategorySummary
        Hashtable with counts by category
    .OUTPUTS
        Action result hashtable
    #>
    param(
        [bool]$HasReferences = $false,
        [int]$ReferenceCount = 0,
        [array]$DirectorySummaries = @(),
        [array]$FileSummaries = @(),
        [hashtable]$CategorySummary = @{}
    )
    
    $items = @()
    
    if ($HasReferences) {
        # Build a summary string showing what's loaded
        $summaryParts = @()
        if ($CategorySummary['Image']) { $summaryParts += "$($CategorySummary['Image']) images" }
        if ($CategorySummary['Text'] -or $CategorySummary['Markdown']) { 
            $textCount = [int]($CategorySummary['Text']) + [int]($CategorySummary['Markdown'])
            if ($textCount -gt 0) { $summaryParts += "$textCount text" }
        }
        if ($CategorySummary['StructuredData']) { $summaryParts += "$($CategorySummary['StructuredData']) data" }
        if ($CategorySummary['Code']) { $summaryParts += "$($CategorySummary['Code']) code" }
        if ($CategorySummary['Other']) { $summaryParts += "$($CategorySummary['Other']) other" }
        
        $summaryStr = if ($summaryParts.Count -gt 0) { $summaryParts -join ', ' } else { "$ReferenceCount files" }
        
        $items += New-RalphMenuItem -Key 'Enter' -Label "Continue with current references ($summaryStr)" -Action 'continue' -Color 'Green'
        $items += New-RalphMenuSeparator
    }
    
    $items += New-RalphMenuItem -Key '1' -Label 'Use default references folder' -Action 'use-default-reference' -Description "Load files from ralph/references/" -Color 'Cyan'
    
    # Show registered directories with file counts
    if ($DirectorySummaries.Count -gt 0) {
        foreach ($dir in $DirectorySummaries) {
            $items += New-RalphMenuItem -Key '' -Label "   📁 $($dir.ShortPath): $($dir.Summary.FormattedSummary)" -Action '' -Color 'DarkGray' -Disabled
        }
    }
    
    $items += New-RalphMenuItem -Key '2' -Label 'Add custom reference folder' -Action 'add-directory' -Description 'Add your own folder with reference materials' -Color 'Yellow'
    
    if ($HasReferences) {
        $items += New-RalphMenuSeparator
        $items += New-RalphMenuItem -Key '3' -Label 'View current references' -Action 'view-references' -Description 'List all registered files' -Color 'White'
        $items += New-RalphMenuItem -Key '4' -Label 'Remove reference folder' -Action 'remove-reference' -Description 'Remove a reference folder' -Color 'DarkYellow'
        $items += New-RalphMenuItem -Key '5' -Label 'Clear all references' -Action 'clear-references' -Description 'Remove all registered references' -Color 'Red'
    }
    
    $items += New-RalphMenuSeparator
    $items += New-RalphMenuItem -Key 'I' -Label 'Reference file types' -Action 'show-types' -Description 'How different file types are handled' -Color 'Gray'
    
    $description = if ($HasReferences) { "$ReferenceCount files registered" } else { "Add reference materials (images, docs, etc.)" }
    
    $menu = New-DynamicMenu -Id 'references' -Title 'RALPH - REFERENCE FILES' -Items $items -Description $description -Color 'Magenta' -ShowBack $true -ShowQuit $false
    
    return Show-Menu -Menu $menu
}

function Show-ReferenceConfirmationMenu {
    <#
    .SYNOPSIS
        Shows confirmation menu with list of all reference files
    .PARAMETER References
        Array of reference file info objects
    .OUTPUTS
        Boolean - true to proceed, false to cancel/modify
    #>
    param(
        [Parameter(Mandatory)]
        [array]$References
    )
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  REFERENCE FILES CONFIRMATION" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    
    # Group by category
    $byCategory = @{}
    foreach ($ref in $References) {
        $cat = $ref.Category
        if (-not $byCategory.ContainsKey($cat)) {
            $byCategory[$cat] = @()
        }
        $byCategory[$cat] += $ref
    }
    
    # Display grouped references
    foreach ($cat in $byCategory.Keys | Sort-Object) {
        $icon = switch ($cat) {
            'Image' { '🖼️ ' }
            'StructuredData' { '📊' }
            'Code' { '💻' }
            'Markdown' { '📝' }
            'Other' { '📎' }
            default { '📄' }
        }
        Write-Host "  $icon $cat ($($byCategory[$cat].Count) files)" -ForegroundColor Cyan
        
        foreach ($ref in $byCategory[$cat]) {
            $sizeMB = [math]::Round($ref.Size / 1KB, 1)
            Write-Host "     • $($ref.Name) ($sizeMB KB)" -ForegroundColor White
        }
        Write-Host ""
    }
    
    Write-Host "  Total: $($References.Count) files" -ForegroundColor Gray
    Write-Host ""
    
    return Show-ArrowConfirm -Message "Proceed with these reference files?" -DefaultYes
}

function Show-SupportedFileTypesMenu {
    <#
    .SYNOPSIS
        Displays file type handling information
    #>
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  REFERENCE FILE TYPES" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "  ✅ ALL file types are accepted" -ForegroundColor Green
    Write-Host "     Put anything in the references folder — files, subfolders," -ForegroundColor Gray
    Write-Host "     entire codebases. Ralph will explore everything." -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  📄 Text & Markdown" -ForegroundColor Yellow
    Write-Host "     .md, .txt, .text, .markdown — inlined into prompt" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  📊 Structured Data" -ForegroundColor Yellow
    Write-Host "     .json, .yaml, .yml, .toml, .xml, .csv, .ini — parsed and inlined" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  💻 Code" -ForegroundColor Yellow
    Write-Host "     .ps1, .py, .js, .ts, .cs, .java, .go, .rb, .php, etc. — inlined as code" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  🖼️  Images" -ForegroundColor Yellow
    Write-Host "     .png, .jpg, .jpeg, .gif, .webp, .bmp, .svg — analyzed visually" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  📎 Other files" -ForegroundColor Yellow
    Write-Host "     Any other extension — read as text, Ralph explores as needed" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  📁 Subfolders" -ForegroundColor Yellow
    Write-Host "     Fully supported — add entire projects or codebases as references." -ForegroundColor Gray
    Write-Host "     For large reference sets, Ralph explores directories on demand" -ForegroundColor Gray
    Write-Host "     instead of reading everything upfront." -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Show-RemoveReferenceMenu {
    <#
    .SYNOPSIS
        Shows a menu to select and remove reference directories or files
    .PARAMETER DirectorySummaries
        Array of directory info with file summaries
    .PARAMETER FileSummaries
        Array of file info objects
    .OUTPUTS
        Hashtable with Type (directory/file) and Path, or $null if cancelled
    #>
    param(
        [array]$DirectorySummaries = @(),
        [array]$FileSummaries = @()
    )
    
    $items = @()
    $keyIndex = 1
    $pathMap = @{}
    
    # Add directories
    if ($DirectorySummaries.Count -gt 0) {
        foreach ($dir in $DirectorySummaries) {
            $key = "$keyIndex"
            $items += New-RalphMenuItem -Key $key -Label "📁 $($dir.ShortPath)" -Action "remove-dir-$keyIndex" -Description $dir.Summary.FormattedSummary -Color 'Yellow'
            $pathMap["remove-dir-$keyIndex"] = @{ Type = 'directory'; Path = $dir.Path }
            $keyIndex++
        }
    }
    
    # Add files
    if ($FileSummaries.Count -gt 0) {
        if ($DirectorySummaries.Count -gt 0) {
            $items += New-RalphMenuSeparator
        }
        
        foreach ($file in $FileSummaries) {
            $key = "$keyIndex"
            $icon = switch ($file.Category) {
                'Image' { '🖼️' }
                'StructuredData' { '📊' }
                'Code' { '💻' }
                default { '📄' }
            }
            $items += New-RalphMenuItem -Key $key -Label "$icon $($file.ShortPath)" -Action "remove-file-$keyIndex" -Description $file.SizeFormatted -Color 'Yellow'
            $pathMap["remove-file-$keyIndex"] = @{ Type = 'file'; Path = $file.Path }
            $keyIndex++
        }
    }
    
    if ($items.Count -eq 0) {
        Write-Host ""
        Write-Host "  No references to remove." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $null
    }
    
    $items += New-RalphMenuSeparator
    $items += New-RalphMenuItem -Key 'Esc' -Label 'Cancel' -Action 'cancel' -Color 'Gray'
    
    $menu = New-DynamicMenu -Id 'remove-reference' -Title 'REMOVE REFERENCE' -Items $items -Description 'Select a directory or file to remove' -Color 'DarkYellow'
    
    $result = Show-Menu -Menu $menu
    
    if ($result.Action -eq 'cancel' -or $result.Action -eq 'back') {
        return $null
    }
    
    if ($pathMap.ContainsKey($result.Action)) {
        return $pathMap[$result.Action]
    }
    
    return $null
}

function Show-DirectoryBrowser {
    <#
    .SYNOPSIS
        Shows a directory browser/selector
    .PARAMETER StartPath
        Starting directory path
    .PARAMETER Title
        Browser title
    .OUTPUTS
        Selected directory path or $null
    #>
    param(
        [string]$StartPath = '',
        [string]$Title = 'Select Directory'
    )
    
    if (-not $StartPath -or -not (Test-Path $StartPath)) {
        $StartPath = Get-Location
    }
    
    $currentPath = $StartPath
    
    while ($true) {
        Write-Host ""
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host "  Current: $currentPath" -ForegroundColor Gray
        Write-Host ""
        
        # Get subdirectories
        $dirs = @(Get-ChildItem -Path $currentPath -Directory -ErrorAction SilentlyContinue | Select-Object -First 20)
        
        $items = @()
        
        # Add parent directory option if not at root
        $parent = Split-Path $currentPath -Parent
        if ($parent) {
            $items += @{ Label = "📁 .. (Parent Directory)"; Value = "__parent__" }
        }
        
        # Add subdirectories
        foreach ($dir in $dirs) {
            $items += @{ Label = "📁 $($dir.Name)"; Value = $dir.FullName }
        }
        
        # Add select current option
        $items += @{ Label = "✓ Select this directory"; Value = "__select__" }
        
        $result = Show-ListSelectionMenu -Title "" -Items $items -AllowBack
        
        if ($result.Action -eq 'back') {
            return $null
        }
        
        if ($result.Action -eq 'select') {
            if ($result.Value -eq '__parent__') {
                $currentPath = $parent
            } elseif ($result.Value -eq '__select__') {
                return $currentPath
            } else {
                $currentPath = $result.Value
            }
        }
    }
}

function Show-FileBrowser {
    <#
    .SYNOPSIS
        Shows a file browser/selector with multi-select support
    .PARAMETER StartPath
        Starting directory path
    .PARAMETER Title
        Browser title
    .PARAMETER Extensions
        Array of allowed extensions (e.g., @('.md', '.txt'))
    .OUTPUTS
        Array of selected file paths or $null
    #>
    param(
        [string]$StartPath = '',
        [string]$Title = 'Select Files',
        [array]$Extensions = @()
    )
    
    if (-not $StartPath -or -not (Test-Path $StartPath)) {
        $StartPath = Get-Location
    }
    
    $currentPath = $StartPath
    $selectedFiles = @()
    
    while ($true) {
        Write-Host ""
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host "  Current: $currentPath" -ForegroundColor Gray
        if ($selectedFiles.Count -gt 0) {
            Write-Host "  Selected: $($selectedFiles.Count) files" -ForegroundColor Green
        }
        Write-Host ""
        
        # Get files and directories
        $dirs = @(Get-ChildItem -Path $currentPath -Directory -ErrorAction SilentlyContinue | Select-Object -First 15)
        $files = @(Get-ChildItem -Path $currentPath -File -ErrorAction SilentlyContinue | Where-Object {
            if ($Extensions.Count -gt 0) {
                $_.Extension.ToLower() -in $Extensions
            } else {
                $true
            }
        } | Select-Object -First 20)
        
        $items = @()
        
        # Parent directory
        $parent = Split-Path $currentPath -Parent
        if ($parent) {
            $items += @{ Label = "📁 .. (Parent Directory)"; Value = "__parent__" }
        }
        
        # Subdirectories
        foreach ($dir in $dirs) {
            $items += @{ Label = "📁 $($dir.Name)"; Value = "dir:$($dir.FullName)" }
        }
        
        # Files
        foreach ($file in $files) {
            $isSelected = $file.FullName -in $selectedFiles
            $marker = if ($isSelected) { "✓" } else { " " }
            $sizeMB = [math]::Round($file.Length / 1KB, 1)
            $items += @{ Label = "$marker 📄 $($file.Name) ($sizeMB KB)"; Value = "file:$($file.FullName)" }
        }
        
        if ($selectedFiles.Count -gt 0) {
            $items += @{ Label = "━━━━━━━━━━━━━━━━━━━━"; Value = "__sep__" }
            $items += @{ Label = "✓ Done - Use selected files ($($selectedFiles.Count))"; Value = "__done__" }
        }
        
        $result = Show-ListSelectionMenu -Title "" -Items $items -AllowBack
        
        if ($result.Action -eq 'back') {
            if ($selectedFiles.Count -gt 0) {
                # Confirm before losing selection
                $confirm = Show-ArrowConfirm -Message "Discard $($selectedFiles.Count) selected files?" -DefaultYes:$false
                if (-not $confirm) {
                    continue
                }
            }
            return $null
        }
        
        if ($result.Action -eq 'select') {
            $value = $result.Value
            
            if ($value -eq '__parent__') {
                $currentPath = $parent
            } elseif ($value -eq '__done__') {
                return $selectedFiles
            } elseif ($value -eq '__sep__') {
                continue
            } elseif ($value.StartsWith('dir:')) {
                $currentPath = $value.Substring(4)
            } elseif ($value.StartsWith('file:')) {
                $filePath = $value.Substring(5)
                if ($filePath -in $selectedFiles) {
                    $selectedFiles = @($selectedFiles | Where-Object { $_ -ne $filePath })
                } else {
                    $selectedFiles += $filePath
                }
            }
        }
    }
}

function Show-PathInputMenu {
    <#
    .SYNOPSIS
        Shows a path input with validation
    .PARAMETER Title
        Input title
    .PARAMETER Type
        'directory' or 'file'
    .PARAMETER MustExist
        If true, path must exist
    .OUTPUTS
        Entered path or $null
    #>
    param(
        [string]$Title = 'Enter path',
        [ValidateSet('directory', 'file')]
        [string]$Type = 'directory',
        [switch]$MustExist
    )
    
    while ($true) {
        $result = Show-ArrowTextInput -Prompt $Title -AllowBack
        
        if ($result.Type -eq 'back') {
            return $null
        }
        
        $path = $result.Value
        
        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-Host "  Path cannot be empty" -ForegroundColor Red
            continue
        }
        
        # Normalize path (handles "d:Temp" → "D:\Temp" and other common issues)
        $path = Normalize-Path -Path $path
        
        if ($MustExist -and -not (Test-Path $path)) {
            Write-Host "  Path does not exist: $path" -ForegroundColor Red
            Write-Host "  (normalized from: $($result.Value))" -ForegroundColor DarkGray
            continue
        }
        
        if ($MustExist) {
            $item = Get-Item $path
            if ($Type -eq 'directory' -and -not $item.PSIsContainer) {
                Write-Host "  Path is not a directory: $path" -ForegroundColor Red
                continue
            }
            if ($Type -eq 'file' -and $item.PSIsContainer) {
                Write-Host "  Path is not a file: $path" -ForegroundColor Red
                continue
            }
        }
        
        return $path
    }
}

# ═══════════════════════════════════════════════════════════════
#                     SESSIONS HOME MENU
# ═══════════════════════════════════════════════════════════════

function Show-SessionsHomeMenu {
    <#
    .SYNOPSIS
        Shows main sessions home menu - lists all sessions
    .PARAMETER Sessions
        Array of session hashtables
    .PARAMETER ActiveSessionId
        Currently active session ID
    .PARAMETER GitHubAccount
        GitHub account display string
    .OUTPUTS
        Hashtable with Action and optional SessionId
    #>
    param(
        [array]$Sessions = @(),
        [string]$ActiveSessionId = '',
        [string]$GitHubAccount = ''
    )
    
    # Build dynamic items for session list
    $items = @()
    
    # Show GitHub account info at top (if logged in)
    if ($GitHubAccount -and $GitHubAccount -ne 'Not logged in') {
        $items += New-RalphMenuItem -Key '' -Label "👤 $GitHubAccount" -Action '' -Color 'DarkCyan' -Disabled
        $items += New-RalphMenuSeparator
    }
    
    # Add session list if any exist
    if ($Sessions.Count -gt 0) {
        $index = 1
        foreach ($session in $Sessions) {
            $marker = if ($session.Id -eq $ActiveSessionId) { "►" } else { " " }
            $statsText = "[$($session.Stats.Completed)/$($session.Stats.Total) done]"
            $color = if ($session.Id -eq $ActiveSessionId) { 'Green' } else { 'White' }
            
            # Check for recovery checkpoint
            $recoveryIndicator = ""
            if ((Get-Command Test-SessionNeedsRecovery -ErrorAction SilentlyContinue) -and 
                (Test-SessionNeedsRecovery -TaskId $session.Id)) {
                $recoveryIndicator = " ⚠️"  # Indicates session has interrupted checkpoint
                $color = 'Yellow'
            }
            
            $items += New-RalphMenuItem -Key "$index" -Label "$marker $($session.Name) $statsText$recoveryIndicator" -Action 'select-session' -Description $session.Description -Color $color
            $index++
        }
        
        $items += New-RalphMenuSeparator
    }
    
    # Add action items
    $items += New-RalphMenuItem -Key 'N' -Label '🆕 New session' -Action 'new-session' -Color 'Green' -Description 'Create a new session'
    
    if ($Sessions.Count -gt 0) {
        $items += New-RalphMenuItem -Key 'D' -Label '🗑️  Delete session' -Action 'delete-session' -Color 'Yellow' -Description 'Remove a session'
    }
    
    # Add separator before update
    $items += New-RalphMenuSeparator
    
    # Update Ralph option
    $items += New-RalphMenuItem -Key 'U' -Label '📦 Update Ralph' -Action 'update-ralph' -Color 'Cyan' -Description 'Check for and apply updates'
    
    # Create menu
    $description = if ($Sessions.Count -eq 0) { 'No sessions yet - create one to start' } else { "$($Sessions.Count) session(s) available" }
    $menu = New-DynamicMenu -Id 'sessions-home' -Title '🏠 RALPH' -Items $items -Description $description -Color 'Magenta'
    
    return Show-Menu -Menu $menu
}

function Show-SessionHomeMenu {
    <#
    .SYNOPSIS
        Shows session-specific home menu with settings
    .PARAMETER SessionId
        Session ID
    .PARAMETER SessionName
        Session name for display
    .PARAMETER SpecsSummary
        Summary text for specs configuration
    .PARAMETER ReferencesSummary
        Summary text for references configuration
    .PARAMETER CurrentModel
        Current AI model name
    .PARAMETER VerboseStatus
        Verbose mode status string
    .PARAMETER MaxIterations
        Current max iterations setting
    .PARAMETER HasSpecs
        Whether specs are configured
    .PARAMETER HasReferences
        Whether references are configured
    .PARAMETER GitHubAccount
        Current GitHub account display string (e.g., "username@github.com")
    .PARAMETER HasMultipleAccounts
        Whether multiple GitHub accounts are available for switching
    .PARAMETER CheckpointIteration
        If resuming from checkpoint, the last completed iteration number (0 = no checkpoint)
    .OUTPUTS
        Hashtable with Action
    #>
    param(
        [string]$SessionId,
        [string]$SessionName,
        [string]$SpecsSummary = 'Not configured',
        [string]$ReferencesSummary = 'Not configured',
        [string]$CurrentModel = 'default',
        [string]$VerboseStatus = 'OFF',
        [string]$VenvStatus = 'AUTO',
        [string]$MaxIterations = 'unlimited',
        [bool]$HasSpecs = $false,
        [bool]$HasReferences = $false,
        [string]$GitHubAccount = '',
        [bool]$HasMultipleAccounts = $false,
        [int]$CheckpointIteration = 0
    )
    
    $items = @()
    
    # Settings overview in grey at the top - compact single line
    $refsIcon = if ($HasReferences) { '✓' } else { '·' }
    $specsIcon = if ($HasSpecs) { '✓' } else { '·' }
    $modelIcon = if ($CurrentModel -ne 'default') { '✓' } else { '·' }
    $verboseIcon = if ($VerboseStatus -eq 'ON') { '✓' } else { '·' }
    $venvIcon = if ($VenvStatus -ne 'DISABLED') { '✓' } else { '·' }
    $iterIcon = if ($MaxIterations -ne 'unlimited') { '✓' } else { '·' }
    
    # Build status line with GitHub account info
    $statusLine = "$refsIcon Refs: $ReferencesSummary  $specsIcon Specs: $SpecsSummary  $modelIcon $CurrentModel  $verboseIcon Verbose:$VerboseStatus  $venvIcon Env:$VenvStatus  $iterIcon Iterations:$MaxIterations"
    $items += New-RalphMenuItem -Key '' -Label $statusLine -Action '' -Color 'Gray' -Disabled
    
    # GitHub account display line (if authenticated)
    if ($GitHubAccount) {
        $accountIcon = '👤'
        $accountLine = "$accountIcon Account: $GitHubAccount (using tokens)"
        $items += New-RalphMenuItem -Key '' -Label $accountLine -Action '' -Color 'DarkCyan' -Disabled
    }
    
    $items += New-RalphMenuSeparator
    
    # Start Ralph - show checkpoint info if resuming
    if ($CheckpointIteration -gt 0) {
        $startLabel = "🚀 Start Ralph (Continue from iteration $CheckpointIteration)"
        $startDesc = "Resume building from last completed checkpoint"
        $items += New-RalphMenuItem -Key 'Enter' -Label $startLabel -Action 'start' -Description $startDesc -Color 'Yellow'
    } else {
        $items += New-RalphMenuItem -Key 'Enter' -Label '🚀 Start Ralph' -Action 'start' -Description 'Begin building with current settings' -Color 'Green'
    }
    
    $items += New-RalphMenuSeparator
    
    # References configuration - show checkmark if configured
    $refsMarker = if ($HasReferences) { '✓ ' } else { '  ' }
    $refsColor = if ($HasReferences) { 'Green' } else { 'White' }
    $items += New-RalphMenuItem -Key 'R' -Label "${refsMarker}📚 References" -Action 'references' -Description 'Configure reference files for this session' -Color $refsColor
    
    # Specs configuration - show checkmark if configured
    $specsMarker = if ($HasSpecs) { '✓ ' } else { '  ' }
    $specsColor = if ($HasSpecs) { 'Green' } else { 'White' }
    $items += New-RalphMenuItem -Key 'S' -Label "${specsMarker}📝 Specs" -Action 'specs-settings' -Description 'Configure specifications for this session' -Color $specsColor
    
    $items += New-RalphMenuSeparator
    
    # Session settings - show checkmarks for non-default values
    $modelMarker = if ($CurrentModel -ne 'default') { '✓ ' } else { '  ' }
    $modelColor = if ($CurrentModel -ne 'default') { 'Green' } else { 'Cyan' }
    $items += New-RalphMenuItem -Key 'M' -Label "${modelMarker}🤖 AI Model" -Action 'change-model' -Description 'Change the AI model' -Color $modelColor
    
    # GitHub Account - only show switch option if multiple accounts
    if ($HasMultipleAccounts) {
        $items += New-RalphMenuItem -Key 'A' -Label "  👤 Switch GitHub Account" -Action 'switch-account' -Description 'Change which account uses tokens' -Color 'Cyan'
    }
    
    $verboseMarker = if ($VerboseStatus -eq 'ON') { '✓ ' } else { '  ' }
    $verboseColor = if ($VerboseStatus -eq 'ON') { 'Green' } else { 'Yellow' }
    $items += New-RalphMenuItem -Key 'V' -Label "${verboseMarker}📊 Verbose mode" -Action 'toggle-verbose' -Description 'Show detailed output' -Color $verboseColor
    
    # Venv menu item - show different colors based on mode
    $venvMarker = if ($VenvStatus -ne 'DISABLED') { '✓ ' } else { '  ' }
    $venvColor = switch ($VenvStatus) {
        'AUTO' { 'Green' }
        'ALWAYS' { 'Cyan' }
        'DISABLED' { 'Yellow' }
        default { 'White' }
    }
    $venvDesc = switch ($VenvStatus) {
        'AUTO' { 'Detect if project needs venv' }
        'ALWAYS' { 'Always create venv' }
        'DISABLED' { 'Install to system (not recommended)' }
        default { 'Configure virtual environment' }
    }
    $items += New-RalphMenuItem -Key 'E' -Label "${venvMarker}🐍 Venv: $VenvStatus" -Action 'toggle-venv' -Description $venvDesc -Color $venvColor
    
    $iterMarker = if ($MaxIterations -ne 'unlimited') { '✓ ' } else { '  ' }
    $iterColor = if ($MaxIterations -ne 'unlimited') { 'Green' } else { 'White' }
    $items += New-RalphMenuItem -Key 'I' -Label "${iterMarker}🔄 Max iterations" -Action 'set-iterations' -Description 'Set build iteration limit' -Color $iterColor
    
    # Create menu
    $title = "📂 SESSION: $SessionName"
    $menu = New-DynamicMenu -Id 'session' -Title $title -Items $items -Description 'Configure session settings before starting' -Color 'Cyan'
    
    return Show-Menu -Menu $menu
}

function Show-GitHubAccountMenu {
    <#
    .SYNOPSIS
        Shows GitHub account selection menu for switching accounts
    .PARAMETER Accounts
        Array of account hashtables from Get-GitHubAccounts
    .PARAMETER CurrentAccount
        Currently active account display string
    .OUTPUTS
        Hashtable with Action and optional Account (selected account info)
    #>
    param(
        [array]$Accounts = @(),
        [string]$CurrentAccount = ''
    )
    
    $items = @()
    
    # Show current account info
    if ($CurrentAccount) {
        $items += New-RalphMenuItem -Key '' -Label "Current: $CurrentAccount (using tokens)" -Action '' -Color 'Cyan' -Disabled
        $items += New-RalphMenuSeparator
    }
    
    if ($Accounts.Count -eq 0) {
        $items += New-RalphMenuItem -Key '' -Label 'No GitHub accounts configured' -Action '' -Color 'Yellow' -Disabled
        $items += New-RalphMenuSeparator
        $items += New-RalphMenuItem -Key 'L' -Label '🔑 Login to GitHub' -Action 'login' -Color 'Green' -Description 'Authenticate with GitHub CLI'
    } else {
        # List all accounts with numbers
        $index = 1
        foreach ($account in $Accounts) {
            $marker = if ($account.Active) { '✓ ' } else { '  ' }
            $color = if ($account.Active) { 'Green' } else { 'White' }
            $desc = if ($account.Active) { 'Currently active' } else { 'Switch to this account' }
            
            $items += New-RalphMenuItem -Key "$index" -Label "${marker}$($account.Display)" -Action 'select' -Color $color -Description $desc
            $index++
        }
        
        $items += New-RalphMenuSeparator
        $items += New-RalphMenuItem -Key 'L' -Label '➕ Add another account' -Action 'login' -Color 'Yellow' -Description 'Login to additional GitHub account'
    }
    
    $menu = New-DynamicMenu -Id 'github-account' -Title '👤 GITHUB ACCOUNT' -Items $items -Description 'Select which GitHub account to use for Copilot' -Color 'Cyan' -ShowBack $true
    
    $result = Show-Menu -Menu $menu
    
    # If user selected an account by number, attach the account info
    if ($result.Action -eq 'select' -and $result.Key -match '^\d+$') {
        $selectedIndex = [int]$result.Key - 1
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $Accounts.Count) {
            $result.Account = $Accounts[$selectedIndex]
        }
    }
    
    return $result
}

function Show-SpecsSettingsMenu {
    <#
    .SYNOPSIS
        Shows specs configuration menu for a session
    .PARAMETER SpecsSummary
        Current specs summary text
    .PARAMETER HasSpecs
        Whether specs are configured
    .PARAMETER SpecsFolder
        Current specs folder path
    .PARAMETER SpecsSource
        Current specs source: 'session', 'global', 'custom', or 'none'
    .OUTPUTS
        Hashtable with Action
    #>
    param(
        [string]$SpecsSummary = 'Not configured',
        [bool]$HasSpecs = $false,
        [string]$SpecsFolder = '',
        [string]$SpecsSource = 'none'
    )
    
    $items = @()
    
    # Continue with current specs
    if ($HasSpecs) {
        $items += New-RalphMenuItem -Key 'Enter' -Label "Continue with current specs ($SpecsSummary)" -Action 'continue' -Color 'Green'
        $items += New-RalphMenuSeparator
    }
    
    # Spec folder configuration - show checkmarks for selected option
    $sessionMarker = if ($SpecsSource -eq 'session') { '✓ ' } else { '  ' }
    $globalMarker = if ($SpecsSource -eq 'global') { '✓ ' } else { '  ' }
    $customMarker = if ($SpecsSource -eq 'custom') { '✓ ' } else { '  ' }
    $sessionColor = if ($SpecsSource -eq 'session') { 'Green' } else { 'Cyan' }
    $globalColor = if ($SpecsSource -eq 'global') { 'Green' } else { 'Blue' }
    $customColor = if ($SpecsSource -eq 'custom') { 'Green' } else { 'Yellow' }
    
    $items += New-RalphMenuItem -Key '1' -Label "${sessionMarker}Use session specs folder" -Action 'use-session' -Description "Use session's own session-specs/ directory" -Color $sessionColor
    $items += New-RalphMenuItem -Key '2' -Label "${globalMarker}Use global specs folder" -Action 'use-global' -Description 'Use ralph/specs/ shared across sessions' -Color $globalColor
    $items += New-RalphMenuItem -Key '3' -Label "${customMarker}Set custom spec folder" -Action 'set-custom-folder' -Description 'Use a custom directory for specs' -Color $customColor
    
    if ($HasSpecs) {
        $items += New-RalphMenuItem -Key '4' -Label '  Clear specs' -Action 'clear-specs' -Description 'Remove all spec configuration' -Color 'Red'
    }
    
    $items += New-RalphMenuSeparator
    
    # Spec creation
    $items += New-RalphMenuItem -Key '5' -Label '✨ Build spec from prompt' -Action 'build-prompt' -Description 'Create spec from a single description' -Color 'Green'
    $items += New-RalphMenuItem -Key '6' -Label '💬 Build spec via interview' -Action 'build-interview' -Description 'Ralph asks questions to create spec' -Color 'Green'
    $items += New-RalphMenuItem -Key '7' -Label '📄 Build spec from references' -Action 'build-from-references' -Description 'Create spec from images/text files' -Color 'Magenta'
    
    $items += New-RalphMenuSeparator
    
    # Templates: Presets and Boilerplates
    $items += New-RalphMenuItem -Key '8' -Label '📦 Apply preset template' -Action 'apply-preset' -Description 'Use a pre-configured task template' -Color 'Cyan'
    $items += New-RalphMenuItem -Key '9' -Label '🚀 New project boilerplate' -Action 'boilerplate-wizard' -Description 'Create project starter structure' -Color 'Yellow'
    
    $items += New-RalphMenuSeparator
    
    # View specs
    if ($HasSpecs) {
        $items += New-RalphMenuItem -Key 'V' -Label 'View current specs' -Action 'view-specs' -Description 'List configured spec files' -Color 'White'
    }
    
    if ($SpecsFolder -and (Test-Path $SpecsFolder)) {
        $folderDisplay = if ($SpecsFolder.Length -gt 40) { "..." + $SpecsFolder.Substring($SpecsFolder.Length - 37) } else { $SpecsFolder }
        $items += New-RalphMenuItem -Key '' -Label "   📁 $folderDisplay" -Action '' -Color 'DarkGray' -Disabled
    }
    
    $description = if ($HasSpecs) { $SpecsSummary } else { 'Configure specifications for this session' }
    
    $menu = New-DynamicMenu -Id 'specs-settings' -Title '📝 RALPH - SPECS CONFIGURATION' -Items $items -Description $description -Color 'Magenta' -ShowBack $true -ShowQuit $false
    
    return Show-Menu -Menu $menu
}

function Show-SessionEndMenu {
    <#
    .SYNOPSIS
        Shows a post-session menu after build completes or pauses
    .DESCRIPTION
        Displays options for the user after a Ralph session ends:
        - Continue building (if tasks remain)
        - Back to session home
        - Quit
    .PARAMETER TasksRemaining
        Number of pending tasks (0 means all complete)
    .PARAMETER TasksTotal
        Total number of tasks
    .PARAMETER SessionCompleted
        Whether the session completed successfully (all tasks done)
    .OUTPUTS
        Hashtable with Action property: 'continue', 'back', 'quit'
    #>
    param(
        [int]$TasksRemaining = 0,
        [int]$TasksTotal = 0,
        [switch]$SessionCompleted
    )
    
    $items = @()
    
    # Build status message
    if ($SessionCompleted -or $TasksRemaining -eq 0) {
        $statusMessage = "✓ All $TasksTotal tasks completed successfully!"
        $statusColor = 'Green'
    } else {
        $statusMessage = "◐ $($TasksTotal - $TasksRemaining)/$TasksTotal tasks completed ($TasksRemaining remaining)"
        $statusColor = 'Yellow'
    }
    
    # Continue option - only if tasks remain
    if ($TasksRemaining -gt 0) {
        $items += New-RalphMenuItem -Key 'C' -Label "Continue building ($TasksRemaining tasks remaining)" -Action 'continue' -Color 'Green' -Description 'Resume building from where you left off'
        $items += New-RalphMenuSeparator
    }
    
    # Back to session home
    $items += New-RalphMenuItem -Key 'B' -Label 'Back to session home' -Action 'back' -Color 'Cyan' -Description 'Return to session configuration'
    
    # Quit
    $items += New-RalphMenuItem -Key 'Q' -Label 'Quit Ralph' -Action 'quit' -Color 'Red' -Description 'Exit to command line'
    
    $menu = New-DynamicMenu -Id 'session-end' -Title '📋 SESSION SUMMARY' -Items $items -Description $statusMessage -Color $statusColor -ShowBack $false -ShowQuit $false
    
    return Show-Menu -Menu $menu
}

