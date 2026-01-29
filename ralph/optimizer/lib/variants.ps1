<#
.SYNOPSIS
    Agent variant generator for Ralph Optimization Framework

.DESCRIPTION
    Generates modified agent configurations to test different optimization hypotheses.
#>

# ═══════════════════════════════════════════════════════════════
#                    VARIANT DEFINITIONS
# ═══════════════════════════════════════════════════════════════

$script:VariantDefinitions = @{
    'structure-emphasis' = @{
        Description = "Stronger emphasis on file separation and directory structure"
        Modifications = @{
            'ralph.agent.md' = @{
                InsertAfter = "## Critical: Output Location Rules"
                Content = @"

### MANDATORY FILE SEPARATION

**You MUST create separate files:**
- HTML files for markup (.html)
- CSS files for styles (.css) 
- JavaScript files for logic (.js)

**NEVER put CSS or JavaScript inline in HTML files** (except minimal bootstrap).

Example structure for a game:
```
index.html      # Just HTML structure
styles.css      # All CSS
game.js         # All JavaScript
```

This is a **hard requirement**, not a suggestion.

"@
            }
            'ralph-planner.agent.md' = @{
                InsertAfter = "## Task Guidelines"
                Content = @"

### File Structure Tasks

ALWAYS include these tasks in your plan:
1. Create main HTML file with proper structure
2. Create CSS file for all styles
3. Create JavaScript file for main logic

Do NOT create tasks that put everything in one file.

"@
            }
        }
    }
    
    'test-emphasis' = @{
        Description = "Stronger emphasis on creating tests"
        Modifications = @{
            'ralph.agent.md' = @{
                InsertAfter = "## Phase 3: Implement"
                Content = @"

### Test Requirements

For every feature you implement, you SHOULD create tests:
- Unit tests for utility functions
- Integration tests for main features
- Create test files with `.test.js` or `.spec.js` suffix

Test creation is not optional - it's part of quality output.

"@
            }
            'ralph-planner.agent.md' = @{
                InsertAfter = "Good tasks:"
                Content = @"

**Test Tasks:**
Every plan MUST include at least one test task:
- "Create unit tests for [feature]"
- "Add integration tests for game loop"

Plans without test tasks are incomplete.

"@
            }
        }
    }
    
    'task-consolidation' = @{
        Description = "Emphasize larger, more consolidated tasks"
        Modifications = @{
            'ralph-planner.agent.md' = @{
                ReplaceSection = "## Task Guidelines"
                Content = @"
## Task Guidelines

Each task should be:
- **Feature-complete** - Implements a full, working feature
- **Substantial** - 100-500 lines of code
- **Self-contained** - Doesn't depend on future tasks

### Consolidation Rules

**COMBINE related work into single tasks:**
- Creating a class + its methods = ONE task
- Feature + its tests = ONE task
- Component + its styles = ONE task

**Target: 8-15 tasks for a typical project**

If you have 20+ tasks, you've over-split. Consolidate.

"@
            }
        }
    }
    
    'efficiency-focus' = @{
        Description = "Focus on reducing wasted iterations"
        Modifications = @{
            'ralph.agent.md' = @{
                InsertAfter = "## Phase 2: Investigate"
                Content = @"

### CRITICAL: Verify Before Implementing

Before writing ANY code:
1. Search for existing implementation: `grep -r "functionName" .`
2. Check if file exists: `ls -la path/to/file`
3. If feature exists, mark task [x] and STOP

**Wasted iterations hurt quality scores.** Don't re-implement existing work.

"@
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                    VARIANT GENERATION
# ═══════════════════════════════════════════════════════════════

function Get-AvailableVariants {
    <#
    .SYNOPSIS
        Lists all available variant definitions
    #>
    return $script:VariantDefinitions.Keys
}

function Get-VariantDescription {
    <#
    .SYNOPSIS
        Gets description for a variant
    #>
    param([string]$VariantName)
    
    if ($script:VariantDefinitions.ContainsKey($VariantName)) {
        return $script:VariantDefinitions[$VariantName].Description
    }
    return $null
}

function New-AgentVariant {
    <#
    .SYNOPSIS
        Creates a modified agent variant directory
    .PARAMETER VariantName
        Name of the variant to create
    .PARAMETER OutputPath
        Directory to create the variant in
    .PARAMETER BaseAgentsPath
        Path to base agents to modify (default: ralph/agents)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$VariantName,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [string]$BaseAgentsPath
    )
    
    if (-not $script:VariantDefinitions.ContainsKey($VariantName)) {
        throw "Unknown variant: $VariantName. Available: $($script:VariantDefinitions.Keys -join ', ')"
    }
    
    $variant = $script:VariantDefinitions[$VariantName]
    
    # Use default base agents if not specified
    if (-not $BaseAgentsPath) {
        $BaseAgentsPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "agents"
    }
    
    # Create output directory
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    
    # Copy base agents
    Copy-Item "$BaseAgentsPath\*" $OutputPath -Recurse -Force
    
    # Apply modifications
    foreach ($file in $variant.Modifications.Keys) {
        $filePath = Join-Path $OutputPath $file
        if (-not (Test-Path $filePath)) { continue }
        
        $mod = $variant.Modifications[$file]
        $content = Get-Content $filePath -Raw
        
        if ($mod.InsertAfter) {
            # Insert content after specified marker
            $pattern = [regex]::Escape($mod.InsertAfter)
            if ($content -match $pattern) {
                $content = $content -replace "($pattern)", "`$1`n$($mod.Content)"
            }
        }
        elseif ($mod.ReplaceSection) {
            # Replace entire section (from header to next ## header)
            $sectionPattern = "($([regex]::Escape($mod.ReplaceSection)))[\s\S]*?(?=\n## |\z)"
            $content = $content -replace $sectionPattern, $mod.Content
        }
        
        Set-Content $filePath $content
    }
    
    return $OutputPath
}

function New-CombinedVariant {
    <#
    .SYNOPSIS
        Creates a variant combining multiple modifications
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$VariantNames,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [string]$BaseAgentsPath
    )
    
    # Use default base agents if not specified
    if (-not $BaseAgentsPath) {
        $BaseAgentsPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "agents"
    }
    
    # Create output directory and copy base
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Copy-Item "$BaseAgentsPath\*" $OutputPath -Recurse -Force
    
    # Apply each variant's modifications
    foreach ($variantName in $VariantNames) {
        if (-not $script:VariantDefinitions.ContainsKey($variantName)) { continue }
        
        $variant = $script:VariantDefinitions[$variantName]
        
        foreach ($file in $variant.Modifications.Keys) {
            $filePath = Join-Path $OutputPath $file
            if (-not (Test-Path $filePath)) { continue }
            
            $mod = $variant.Modifications[$file]
            $content = Get-Content $filePath -Raw
            
            if ($mod.InsertAfter) {
                $pattern = [regex]::Escape($mod.InsertAfter)
                if ($content -match $pattern) {
                    $content = $content -replace "($pattern)", "`$1`n$($mod.Content)"
                }
            }
            elseif ($mod.ReplaceSection) {
                $sectionPattern = "($([regex]::Escape($mod.ReplaceSection)))[\s\S]*?(?=\n## |\z)"
                $content = $content -replace $sectionPattern, $mod.Content
            }
            
            Set-Content $filePath $content
        }
    }
    
    return $OutputPath
}

function New-VariantFromAnalysis {
    <#
    .SYNOPSIS
        Creates a variant targeting the weakest category from analysis
    #>
    param(
        [Parameter(Mandatory)]
        [string]$WeakestCategory,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [string]$BaseAgentsPath
    )
    
    $targetVariant = switch ($WeakestCategory) {
        'Structure' { 'structure-emphasis' }
        'Code' { 'efficiency-focus' }
        'Quality' { 'test-emphasis' }
        'Efficiency' { 'task-consolidation' }
        default { 'structure-emphasis' }
    }
    
    return New-AgentVariant -VariantName $targetVariant -OutputPath $OutputPath -BaseAgentsPath $BaseAgentsPath
}

# Functions are available when dot-sourced
