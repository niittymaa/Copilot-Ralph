<#
.SYNOPSIS
    Project Boilerplate Wizard for Ralph Loop

.DESCRIPTION
    Interactive wizard to help users create project starter structures step by step.
    Features:
    - Target Platform selection (filters available stacks)
    - Preset tech stack combinations (React, Vue, Python, Node, etc.)
    - Custom mode for individual technology selection
    - Hello World goal definition for each configuration
    - Complete startup spec generation for Ralph

.NOTES
    Boilerplate definitions are stored in ralph/boilerplates/
    - platforms.yaml - Target platforms
    - stacks.yaml - Tech stack presets
    - technologies.yaml - Individual technologies for custom mode
#>

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:BoilerplatesDir = $null
$script:BoilerplatesProjectRoot = $null
$script:WizardState = $null

function Initialize-BoilerplateWizard {
    <#
    .SYNOPSIS
        Initializes the Boilerplate Wizard system
    .PARAMETER ProjectRoot
        Root directory of the project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    
    $script:BoilerplatesProjectRoot = $ProjectRoot
    $ralphDir = Join-Path $ProjectRoot 'ralph'
    $script:BoilerplatesDir = Join-Path $ralphDir 'boilerplates'
    
    Reset-WizardState
}

function Reset-WizardState {
    <#
    .SYNOPSIS
        Resets the wizard state to initial values
    #>
    $script:WizardState = @{
        Step = 'platform'
        Platform = $null
        Mode = $null  # 'preset' or 'custom'
        Stack = $null
        Technologies = @{}
        ProjectName = ''
        HelloWorld = $null
        History = [System.Collections.Generic.List[string]]::new()
    }
}

# ═══════════════════════════════════════════════════════════════
#                      YAML PARSING
# ═══════════════════════════════════════════════════════════════

function Read-BoilerplateYaml {
    <#
    .SYNOPSIS
        Reads and parses a boilerplate YAML file
    .PARAMETER FileName
        Name of the YAML file (without path)
    .OUTPUTS
        Parsed content as hashtable
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )
    
    $path = Join-Path $script:BoilerplatesDir $FileName
    
    if (-not (Test-Path $path)) {
        Write-Host "  Boilerplate file not found: $FileName" -ForegroundColor Red
        return $null
    }
    
    $content = Get-Content $path -Raw
    return ConvertFrom-SimpleYaml -Content $content
}

function ConvertFrom-SimpleYaml {
    <#
    .SYNOPSIS
        Simple YAML parser for boilerplate files
    .PARAMETER Content
        YAML content string
    .OUTPUTS
        Parsed structure
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )
    
    $result = @{}
    $currentArray = $null
    $currentArrayName = ''
    $currentItem = $null
    $inMultiline = $false
    $multilineKey = ''
    $multilineValue = @()
    
    $lines = $Content -split "`n"
    
    foreach ($line in $lines) {
        $trimmed = $line.TrimEnd()
        
        # Skip comments and empty lines
        if ($trimmed -match '^\s*#' -or [string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        
        # Top-level array start (e.g., "platforms:")
        if ($trimmed -match '^(\w+):\s*$') {
            $key = $Matches[1]
            if ($currentArrayName -and $currentArray) {
                if ($currentItem) {
                    $currentArray += $currentItem
                }
                $result[$currentArrayName] = $currentArray
            }
            $currentArrayName = $key
            $currentArray = @()
            $currentItem = $null
            continue
        }
        
        # Array item start (e.g., "  - id: web")
        if ($trimmed -match '^\s*-\s+(\w+):\s*(.*)$') {
            if ($currentItem) {
                $currentArray += $currentItem
            }
            $currentItem = @{}
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            $currentItem[$key] = Parse-YamlValue -Value $value
            continue
        }
        
        # Array item property (e.g., "    name: Web Application")
        if ($currentItem -and $trimmed -match '^\s{2,}(\w+):\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            $currentItem[$key] = Parse-YamlValue -Value $value
            continue
        }
        
        # Nested object start (e.g., "    hello_world:")
        if ($currentItem -and $trimmed -match '^\s{2,}(\w+):\s*$') {
            $key = $Matches[1]
            $currentItem[$key] = @{}
            continue
        }
        
        # Nested property (e.g., "      title: Task Manager")
        if ($currentItem -and $trimmed -match '^\s{4,}(\w+):\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            
            # Find parent key
            $parentKey = ($currentItem.Keys | Where-Object { $currentItem[$_] -is [hashtable] }) | Select-Object -Last 1
            if ($parentKey) {
                $currentItem[$parentKey][$key] = Parse-YamlValue -Value $value
            }
            continue
        }
        
        # Array within nested object (success_criteria)
        if ($currentItem -and $trimmed -match '^\s{6,}-\s+(.+)$') {
            $arrayValue = $Matches[1].Trim()
            
            # Find parent nested object and its array key
            $parentKey = ($currentItem.Keys | Where-Object { $currentItem[$_] -is [hashtable] }) | Select-Object -Last 1
            if ($parentKey) {
                $nestedObj = $currentItem[$parentKey]
                $arrayKey = ($nestedObj.Keys | Where-Object { $nestedObj[$_] -is [array] }) | Select-Object -Last 1
                if ($arrayKey) {
                    $nestedObj[$arrayKey] += $arrayValue
                }
            }
            continue
        }
    }
    
    # Add last item and array
    if ($currentItem) {
        $currentArray += $currentItem
    }
    if ($currentArrayName -and $currentArray) {
        $result[$currentArrayName] = $currentArray
    }
    
    return $result
}

function Parse-YamlValue {
    <#
    .SYNOPSIS
        Parses a YAML value string into appropriate type
    #>
    param([string]$Value)
    
    $Value = $Value.Trim()
    
    # Boolean
    if ($Value -eq 'true') { return $true }
    if ($Value -eq 'false') { return $false }
    
    # Number
    if ($Value -match '^\d+$') { return [int]$Value }
    
    # Array (inline)
    if ($Value -match '^\[(.+)\]$') {
        $items = $Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") }
        return @($items)
    }
    
    # Empty array start
    if ($Value -eq '' -or $Value -eq '[]') { return @() }
    
    # String (remove quotes)
    return $Value.Trim('"').Trim("'")
}

# ═══════════════════════════════════════════════════════════════
#                      DATA ACCESS
# ═══════════════════════════════════════════════════════════════

function Get-Platforms {
    <#
    .SYNOPSIS
        Gets all available target platforms
    .OUTPUTS
        Array of platform hashtables
    #>
    $data = Read-BoilerplateYaml -FileName 'platforms.yaml'
    if ($data -and $data.platforms) {
        return $data.platforms | Sort-Object { $_.order }
    }
    return @()
}

function Get-TechStacks {
    <#
    .SYNOPSIS
        Gets all tech stack presets
    .PARAMETER Platform
        Optional platform filter
    .OUTPUTS
        Array of stack hashtables
    #>
    param([string]$Platform = '')
    
    $data = Read-BoilerplateYaml -FileName 'stacks.yaml'
    if (-not $data -or -not $data.stacks) {
        return @()
    }
    
    $stacks = $data.stacks
    
    if ($Platform) {
        $stacks = $stacks | Where-Object { $_.platforms -contains $Platform }
    }
    
    return $stacks
}

function Get-Technologies {
    <#
    .SYNOPSIS
        Gets all individual technologies
    .PARAMETER Category
        Optional category filter
    .PARAMETER Platform
        Optional platform filter
    .OUTPUTS
        Array of technology hashtables
    #>
    param(
        [string]$Category = '',
        [string]$Platform = ''
    )
    
    $data = Read-BoilerplateYaml -FileName 'technologies.yaml'
    if (-not $data -or -not $data.technologies) {
        return @()
    }
    
    $techs = $data.technologies
    
    if ($Category) {
        $techs = $techs | Where-Object { $_.category -eq $Category }
    }
    
    if ($Platform) {
        $techs = $techs | Where-Object { $_.platforms -contains $Platform }
    }
    
    return $techs
}

function Get-TechnologyCategories {
    <#
    .SYNOPSIS
        Gets technology category definitions
    .OUTPUTS
        Array of category hashtables
    #>
    $data = Read-BoilerplateYaml -FileName 'technologies.yaml'
    if ($data -and $data.categories) {
        return $data.categories
    }
    return @()
}

# ═══════════════════════════════════════════════════════════════
#                      WIZARD DISPLAY
# ═══════════════════════════════════════════════════════════════

function Show-WizardHeader {
    <#
    .SYNOPSIS
        Shows consistent wizard header
    #>
    param(
        [string]$Title,
        [string]$Step = '',
        [string]$Description = ''
    )
    
    Clear-Host
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  🏗️  PROJECT Boilerplate Wizard" -ForegroundColor White
    if ($Step) {
        Write-Host "  $Step" -ForegroundColor Gray
    }
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    if ($Title) {
        Write-Host "  $Title" -ForegroundColor Cyan
    }
    if ($Description) {
        Write-Host "  $Description" -ForegroundColor Gray
    }
    Write-Host ""
}

function Show-WizardFooter {
    <#
    .SYNOPSIS
        Shows consistent wizard footer with navigation
    #>
    param(
        [bool]$ShowBack = $true,
        [bool]$ShowQuit = $true
    )
    
    Write-Host ""
    $options = @()
    if ($ShowBack -and $script:WizardState.History.Count -gt 0) {
        $options += "[B] Back"
    }
    if ($ShowQuit) {
        $options += "[Q] Cancel wizard"
    }
    
    if ($options.Count -gt 0) {
        Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "  $($options -join '  |  ')" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Show-SelectionList {
    <#
    .SYNOPSIS
        Shows a numbered selection list with icons
    .PARAMETER Items
        Array of items with 'name', 'description', 'icon' properties
    .PARAMETER Title
        Title for the list
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        
        [string]$Title = ''
    )
    
    if ($Title) {
        Write-Host "  $Title" -ForegroundColor Yellow
        Write-Host ""
    }
    
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $num = $i + 1
        $icon = if ($item.icon) { $item.icon } else { "•" }
        $name = $item.name
        
        Write-Host "  [$num] $icon $name" -ForegroundColor Cyan
        
        if ($item.description) {
            Write-Host "      $($item.description)" -ForegroundColor Gray
        }
    }
}

function Get-WizardSelection {
    <#
    .SYNOPSIS
        Gets user selection from numbered list using arrow navigation
    .PARAMETER MaxIndex
        Maximum valid index
    .PARAMETER AllowBack
        Allow B for back navigation
    .OUTPUTS
        Selection result hashtable
    #>
    param(
        [int]$MaxIndex,
        [bool]$AllowBack = $true
    )
    
    $input = Read-MenuInput -Prompt "  Select option"
    
    if ($input.Type -eq 'escape') {
        if ($AllowBack -and $script:WizardState.History.Count -gt 0) {
            return @{ Action = 'back' }
        }
        return @{ Action = 'quit' }
    }
    
    $choice = $input.Value
    
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return @{ Action = 'invalid' }
    }
    
    $choiceUpper = $choice.ToUpper()
    
    if ($choiceUpper -eq 'Q') {
        return @{ Action = 'quit' }
    }
    
    if ($choiceUpper -eq 'B' -and $AllowBack -and $script:WizardState.History.Count -gt 0) {
        return @{ Action = 'back' }
    }
    
    $index = 0
    if ([int]::TryParse($choice, [ref]$index)) {
        if ($index -ge 1 -and $index -le $MaxIndex) {
            return @{ Action = 'select'; Index = $index - 1 }
        }
    }
    
    Write-Host "  Invalid option. Please try again." -ForegroundColor Red
    return @{ Action = 'invalid' }
}

# ═══════════════════════════════════════════════════════════════
#                      WIZARD STEPS
# ═══════════════════════════════════════════════════════════════

function Invoke-PlatformStep {
    <#
    .SYNOPSIS
        Step 1: Select target platform
    #>
    $platforms = Get-Platforms
    
    if ($platforms.Count -eq 0) {
        Write-Host "  No platforms found. Check ralph/boilerplates/platforms.yaml" -ForegroundColor Red
        return @{ Action = 'error' }
    }
    
    Show-WizardHeader -Title "What type of project do you want to create?" -Step "Step 1 of 4: Target Platform"
    
    Show-SelectionList -Items $platforms
    Show-WizardFooter -ShowBack $false
    
    $result = Get-WizardSelection -MaxIndex $platforms.Count -AllowBack $false
    
    switch ($result.Action) {
        'select' {
            $script:WizardState.Platform = $platforms[$result.Index]
            $script:WizardState.History.Add('platform')
            return @{ Action = 'next'; NextStep = 'mode' }
        }
        'quit' { return @{ Action = 'quit' } }
        default { return @{ Action = 'retry' } }
    }
}

function Invoke-ModeStep {
    <#
    .SYNOPSIS
        Step 2: Choose preset or custom mode
    #>
    $platform = $script:WizardState.Platform
    $stacks = Get-TechStacks -Platform $platform.id
    
    Show-WizardHeader -Title "How would you like to configure your $($platform.name)?" -Step "Step 2 of 4: Configuration Mode"
    
    Write-Host "  Platform: $($platform.icon) $($platform.name)" -ForegroundColor Green
    Write-Host ""
    
    $modes = @(
        @{
            name = "Preset Stack ($($stacks.Count) available)"
            description = "Choose from popular, battle-tested tech combinations"
            icon = "📦"
            id = 'preset'
        },
        @{
            name = "Custom Configuration"
            description = "Pick technologies one by one for full control"
            icon = "🔧"
            id = 'custom'
        }
    )
    
    Show-SelectionList -Items $modes
    Show-WizardFooter
    
    $result = Get-WizardSelection -MaxIndex $modes.Count
    
    switch ($result.Action) {
        'select' {
            $script:WizardState.Mode = $modes[$result.Index].id
            $script:WizardState.History.Add('mode')
            if ($modes[$result.Index].id -eq 'preset') {
                return @{ Action = 'next'; NextStep = 'preset' }
            } else {
                return @{ Action = 'next'; NextStep = 'custom' }
            }
        }
        'back' { 
            $script:WizardState.History.RemoveAt($script:WizardState.History.Count - 1)
            return @{ Action = 'next'; NextStep = 'platform' } 
        }
        'quit' { return @{ Action = 'quit' } }
        default { return @{ Action = 'retry' } }
    }
}

function Invoke-PresetStep {
    <#
    .SYNOPSIS
        Step 3a: Select preset tech stack
    #>
    $platform = $script:WizardState.Platform
    $stacks = Get-TechStacks -Platform $platform.id
    
    Show-WizardHeader -Title "Select a tech stack for your $($platform.name)" -Step "Step 3 of 4: Tech Stack"
    
    # Group by category
    $categories = $stacks | Group-Object { $_.category } | Sort-Object Name
    
    $flatList = @()
    foreach ($cat in $categories) {
        Write-Host "  ─── $($cat.Name) ───" -ForegroundColor Yellow
        foreach ($stack in $cat.Group) {
            $flatList += $stack
            $num = $flatList.Count
            Write-Host "  [$num] $($stack.icon) $($stack.name)" -ForegroundColor Cyan
            Write-Host "      $($stack.description)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Show-WizardFooter
    
    $result = Get-WizardSelection -MaxIndex $flatList.Count
    
    switch ($result.Action) {
        'select' {
            $script:WizardState.Stack = $flatList[$result.Index]
            $script:WizardState.HelloWorld = $flatList[$result.Index].hello_world
            $script:WizardState.History.Add('preset')
            return @{ Action = 'next'; NextStep = 'review' }
        }
        'back' {
            $script:WizardState.History.RemoveAt($script:WizardState.History.Count - 1)
            return @{ Action = 'next'; NextStep = 'mode' }
        }
        'quit' { return @{ Action = 'quit' } }
        default { return @{ Action = 'retry' } }
    }
}

function Invoke-CustomStep {
    <#
    .SYNOPSIS
        Step 3b: Custom technology selection (multi-step)
    #>
    $platform = $script:WizardState.Platform
    $categories = Get-TechnologyCategories
    
    # Get required categories
    $requiredCats = $categories | Where-Object { $_.required -eq $true }
    $optionalCats = $categories | Where-Object { $_.required -ne $true }
    
    # Process each category
    $allCats = @($requiredCats) + @($optionalCats)
    $currentCatIndex = 0
    
    foreach ($cat in $allCats) {
        $techs = Get-Technologies -Category $cat.id -Platform $platform.id
        
        if ($techs.Count -eq 0) {
            continue
        }
        
        $required = if ($cat.required) { " (required)" } else { " (optional - Enter to skip)" }
        
        Show-WizardHeader -Title "Select $($cat.name)$required" -Step "Step 3 of 4: Custom Configuration" -Description $cat.description
        
        Write-Host "  Platform: $($platform.icon) $($platform.name)" -ForegroundColor Green
        Write-Host "  Current selections:" -ForegroundColor Gray
        foreach ($key in $script:WizardState.Technologies.Keys) {
            $val = $script:WizardState.Technologies[$key]
            if ($val) {
                Write-Host "    • $key`: $($val.name)" -ForegroundColor DarkGray
            }
        }
        Write-Host ""
        
        Show-SelectionList -Items $techs
        Show-WizardFooter
        
        while ($true) {
            $result = Get-WizardSelection -MaxIndex $techs.Count
            
            switch ($result.Action) {
                'select' {
                    $script:WizardState.Technologies[$cat.id] = $techs[$result.Index]
                    break
                }
                'back' {
                    $script:WizardState.History.RemoveAt($script:WizardState.History.Count - 1)
                    return @{ Action = 'next'; NextStep = 'mode' }
                }
                'quit' { return @{ Action = 'quit' } }
                'invalid' {
                    if (-not $cat.required) {
                        # Skip optional category
                        break
                    }
                    continue
                }
            }
            break
        }
    }
    
    # Create custom hello world based on selections
    $script:WizardState.HelloWorld = @{
        title = "Custom Project Starter"
        description = "Create a working foundation with your selected technologies properly configured and integrated."
        success_criteria = @(
            "Project structure follows best practices"
            "All selected technologies are properly configured"
            "Development server or build works"
            "Basic example code demonstrates each technology"
        )
    }
    
    $script:WizardState.History.Add('custom')
    return @{ Action = 'next'; NextStep = 'review' }
}

function Invoke-ReviewStep {
    <#
    .SYNOPSIS
        Step 4: Review and confirm configuration
    #>
    $platform = $script:WizardState.Platform
    $mode = $script:WizardState.Mode
    $stack = $script:WizardState.Stack
    $helloWorld = $script:WizardState.HelloWorld
    
    Show-WizardHeader -Title "Review Your Project Configuration" -Step "Step 4 of 4: Confirmation"
    
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║  Project Boilerplate SUMMARY                                ║" -ForegroundColor Green
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "  📋 Platform: $($platform.icon) $($platform.name)" -ForegroundColor Cyan
    Write-Host ""
    
    if ($mode -eq 'preset' -and $stack) {
        Write-Host "  📦 Tech Stack: $($stack.icon) $($stack.name)" -ForegroundColor Cyan
        Write-Host "     $($stack.description)" -ForegroundColor Gray
        Write-Host ""
        
        if ($stack.technologies) {
            Write-Host "  🛠️  Technologies:" -ForegroundColor Yellow
            foreach ($key in $stack.technologies.Keys) {
                $techs = $stack.technologies[$key]
                if ($techs) {
                    $techList = if ($techs -is [array]) { $techs -join ', ' } else { $techs }
                    Write-Host "     • $key`: $techList" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "  🔧 Custom Configuration:" -ForegroundColor Cyan
        foreach ($key in $script:WizardState.Technologies.Keys) {
            $tech = $script:WizardState.Technologies[$key]
            if ($tech) {
                Write-Host "     • $key`: $($tech.icon) $($tech.name)" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host ""
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  🎯 Hello World Goal:" -ForegroundColor Yellow
    Write-Host "     $($helloWorld.title)" -ForegroundColor White
    Write-Host ""
    Write-Host "     $($helloWorld.description)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ✅ Success Criteria:" -ForegroundColor Yellow
    foreach ($criterion in $helloWorld.success_criteria) {
        Write-Host "     • $criterion" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    $choice = Show-ArrowChoice -Title "Confirm Selection" -AllowBack -Choices @(
        @{ Label = "Confirm and generate project spec"; Value = "confirm"; Hotkey = "C"; Default = $true }
        @{ Label = "Edit project name"; Value = "edit"; Hotkey = "E" }
        @{ Label = "Go back and modify"; Value = "back"; Hotkey = "B" }
        @{ Label = "Cancel wizard"; Value = "quit"; Hotkey = "Q" }
    )
    
    switch ($choice) {
        'confirm' {
            return @{ Action = 'confirm' }
        }
        'edit' {
            $nameInput = Show-ArrowTextInput -Prompt "Enter project name" -Default $script:WizardState.ProjectName -AllowBack
            if ($nameInput.Type -ne 'back' -and -not [string]::IsNullOrWhiteSpace($nameInput.Value)) {
                $script:WizardState.ProjectName = $nameInput.Value
            }
            return @{ Action = 'retry' }
        }
        'back' {
            if ($script:WizardState.History.Count -gt 0) {
                $script:WizardState.History.RemoveAt($script:WizardState.History.Count - 1)
            }
            $prevStep = if ($mode -eq 'preset') { 'preset' } else { 'mode' }
            return @{ Action = 'next'; NextStep = $prevStep }
        }
        'quit' {
            return @{ Action = 'quit' }
        }
        default {
            return @{ Action = 'retry' }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                      SPEC GENERATION
# ═══════════════════════════════════════════════════════════════

function New-BoilerplateSpec {
    <#
    .SYNOPSIS
        Generates the project specification for Ralph
    .OUTPUTS
        Spec content string
    #>
    $platform = $script:WizardState.Platform
    $mode = $script:WizardState.Mode
    $stack = $script:WizardState.Stack
    $helloWorld = $script:WizardState.HelloWorld
    $projectName = $script:WizardState.ProjectName
    
    if (-not $projectName) {
        if ($stack) {
            $projectName = "$($stack.id)-starter"
        } else {
            $projectName = "custom-$($platform.id)-project"
        }
    }
    
    # Build technology list
    $techList = @()
    if ($mode -eq 'preset' -and $stack -and $stack.technologies) {
        foreach ($key in $stack.technologies.Keys) {
            $techs = $stack.technologies[$key]
            if ($techs -is [array]) {
                $techList += $techs
            } else {
                $techList += $techs
            }
        }
    } else {
        foreach ($tech in $script:WizardState.Technologies.Values) {
            if ($tech) {
                $techList += $tech.name
            }
        }
    }
    
    $techString = $techList -join ', '
    
    # Build success criteria
    $criteriaList = ""
    foreach ($criterion in $helloWorld.success_criteria) {
        $criteriaList += "- [ ] $criterion`n"
    }
    
    # Generate spec content
    $stackDesc = if ($stack) { "$($stack.icon) $($stack.name) - $($stack.description)" } else { "Custom Configuration" }
    
    $spec = @"
# $projectName

## Overview

Create a complete, working project starter/skeleton using the following configuration:

- **Platform**: $($platform.icon) $($platform.name)
- **Stack**: $stackDesc
- **Technologies**: $techString

This is a **Project Boilerplate** - the goal is to create a minimal but complete working project that serves as a perfect starting point for development.

## Hello World Goal

**$($helloWorld.title)**

$($helloWorld.description)

## Acceptance Criteria

$criteriaList
## Technical Requirements

### Project Structure

Create a clean, industry-standard project structure with:

- Proper folder organization following conventions for the selected stack
- Configuration files (.gitignore, editor config, etc.)
- Package management setup (package.json, requirements.txt, go.mod, etc.)
- README.md with setup instructions

### Code Quality

- All code must be properly typed (where applicable)
- Linting and formatting configured and passing
- No console errors or warnings
- Clean, readable code following best practices

### Development Experience

- Development server or watch mode working
- Build/compile command working (if applicable)
- Clear error messages for common issues
- Hot reload where supported

### Testing Setup

- Testing framework configured
- At least one example test passing
- Test command in package scripts

## Implementation Guidelines

1. **Start with project initialization** using the appropriate package manager or CLI tool
2. **Install all dependencies** before writing code
3. **Configure tooling** (linting, formatting, TypeScript, etc.) early
4. **Build the Hello World feature** as described above
5. **Verify everything works** with a clean install/build
6. **Document setup steps** in README.md

## Success Validation

Before marking complete, verify:

1. Fresh clone + install + run works
2. All acceptance criteria are met
3. No build warnings or errors
4. Code follows established conventions
5. README accurately describes setup process

---

*Generated by Ralph Boilerplate Wizard*
*Platform: $($platform.name) | Stack: $(if ($stack) { $stack.name } else { 'Custom' })*
"@
    
    return $spec
}

# ═══════════════════════════════════════════════════════════════
#                      DRY-RUN SUPPORT
# ═══════════════════════════════════════════════════════════════

function Start-BoilerplateWizardDryRun {
    <#
    .SYNOPSIS
        Dry-run version of the Boilerplate Wizard
    .DESCRIPTION
        Shows what the wizard would do without user interaction.
        Simulates selecting a popular stack for preview purposes.
    .PARAMETER ProjectRoot
        Root directory of the project
    .OUTPUTS
        Simulated result hashtable
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    
    Initialize-BoilerplateWizard -ProjectRoot $ProjectRoot
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  [DRY RUN] BOILERPLATE WIZARD - PREVIEW" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  In normal mode, the Boilerplate Wizard would:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Ask you to select a target platform" -ForegroundColor Gray
    Write-Host "     (Web, API, CLI, Desktop, Mobile, Full-Stack, Library)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  2. Let you choose between:" -ForegroundColor Gray
    Write-Host "     • Preset Stack - Pre-configured tech combinations" -ForegroundColor DarkGray
    Write-Host "     • Custom Mode - Pick technologies one by one" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  3. Select specific technologies with descriptions" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. Review your configuration and confirm" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  5. Generate a project spec with Hello World goal" -ForegroundColor Gray
    Write-Host ""
    
    # Get sample data to show
    $platforms = Get-Platforms
    $stacks = Get-TechStacks
    
    Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Available Platforms: $($platforms.Count)" -ForegroundColor Yellow
    foreach ($p in $platforms | Select-Object -First 4) {
        Write-Host "    • $($p.icon) $($p.name)" -ForegroundColor DarkGray
    }
    if ($platforms.Count -gt 4) {
        Write-Host "    • ... and $($platforms.Count - 4) more" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "  Available Tech Stacks: $($stacks.Count)" -ForegroundColor Yellow
    foreach ($s in $stacks | Select-Object -First 4) {
        Write-Host "    • $($s.icon) $($s.name)" -ForegroundColor DarkGray
    }
    if ($stacks.Count -gt 4) {
        Write-Host "    • ... and $($stacks.Count - 4) more" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "  [DRY RUN] Wizard would wait for user input here." -ForegroundColor Yellow
    Write-Host "  [DRY RUN] Simulating selection of React + TypeScript stack..." -ForegroundColor Yellow
    Write-Host ""
    
    # Return simulated result
    return @{
        Spec = "[DRY RUN] Would generate project specification here"
        ProjectName = "react-typescript-starter"
        Platform = "Web Application"
        Stack = "React + TypeScript"
        HelloWorld = "Task Manager App"
    }
}

# ═══════════════════════════════════════════════════════════════
#                      MAIN WIZARD LOOP
# ═══════════════════════════════════════════════════════════════

function Start-BoilerplateWizard {
    <#
    .SYNOPSIS
        Main entry point for the Boilerplate Wizard
    .PARAMETER ProjectRoot
        Root directory of the project
    .OUTPUTS
        Hashtable with result (spec content and metadata) or $null if cancelled
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )
    
    # Check for dry-run mode
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        return Start-BoilerplateWizardDryRun -ProjectRoot $ProjectRoot
    }
    
    Initialize-BoilerplateWizard -ProjectRoot $ProjectRoot
    Reset-WizardState
    
    $currentStep = 'platform'
    
    while ($true) {
        $result = switch ($currentStep) {
            'platform' { Invoke-PlatformStep }
            'mode' { Invoke-ModeStep }
            'preset' { Invoke-PresetStep }
            'custom' { Invoke-CustomStep }
            'review' { Invoke-ReviewStep }
            default { 
                Write-Host "  Unknown step: $currentStep" -ForegroundColor Red
                @{ Action = 'quit' }
            }
        }
        
        switch ($result.Action) {
            'next' {
                $currentStep = $result.NextStep
            }
            'retry' {
                # Stay on current step
            }
            'confirm' {
                # Generate spec and return
                $spec = New-BoilerplateSpec
                
                $projectName = $script:WizardState.ProjectName
                if (-not $projectName) {
                    if ($script:WizardState.Stack) {
                        $projectName = "$($script:WizardState.Stack.id)-starter"
                    } else {
                        $projectName = "custom-project"
                    }
                }
                
                return @{
                    Spec = $spec
                    ProjectName = $projectName
                    Platform = $script:WizardState.Platform.name
                    Stack = if ($script:WizardState.Stack) { $script:WizardState.Stack.name } else { 'Custom' }
                    HelloWorld = $script:WizardState.HelloWorld.title
                }
            }
            'quit' {
                return $null
            }
            'error' {
                return $null
            }
        }
    }
}
