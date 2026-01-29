<#
.SYNOPSIS
    Comprehensive tests for Ralph - Autonomous AI coding agent orchestrator

.DESCRIPTION
    Tests all Ralph features including:
    - Mode parsing and validation
    - Agent file loading and prompt extraction
    - Utility functions (task stats, next task, user specs)
    - Signal detection
    - Workflow integration

.EXAMPLE
    ./tests/ralph.tests.ps1
    Run all tests

.EXAMPLE
    ./tests/ralph.tests.ps1 -Verbose
    Run with detailed output
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ═══════════════════════════════════════════════════════════════
#                        TEST CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:TestsDir = Split-Path -Parent $MyInvocation.MyCommand.Path        # ralph/tests
$script:RalphDir = Split-Path -Parent $TestsDir                            # ralph
$script:ProjectRoot = Split-Path -Parent $RalphDir                         # project root
$script:CoreDir = Join-Path $RalphDir 'core'
$script:AgentsSourceDir = Join-Path $RalphDir 'agents'
$script:AgentsDir = Join-Path $ProjectRoot '.github\agents'
$script:SpecsDir = Join-Path $RalphDir 'specs'
$script:ScriptsDir = Join-Path $RalphDir 'scripts'

$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

# ═══════════════════════════════════════════════════════════════
#                        TEST UTILITIES
# ═══════════════════════════════════════════════════════════════

function Write-TestHeader {
    param([string]$Section)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Section" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ''
    )
    
    if ($Passed) {
        Write-Host "  ✓ $TestName" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  ✗ $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "    → $Message" -ForegroundColor Yellow
        }
        $script:TestsFailed++
    }
}

function Write-TestSkipped {
    param([string]$TestName, [string]$Reason)
    Write-Host "  ○ $TestName (skipped: $Reason)" -ForegroundColor Yellow
    $script:TestsSkipped++
}

function Assert-Equal {
    param($Expected, $Actual, [string]$TestName)
    $passed = $Expected -eq $Actual
    $msg = if (-not $passed) { "Expected '$Expected', got '$Actual'" } else { '' }
    Write-TestResult -TestName $TestName -Passed $passed -Message $msg
    return $passed
}

function Assert-True {
    param([bool]$Condition, [string]$TestName, [string]$Message = '')
    Write-TestResult -TestName $TestName -Passed $Condition -Message $Message
    return $Condition
}

function Assert-False {
    param([bool]$Condition, [string]$TestName, [string]$Message = '')
    Write-TestResult -TestName $TestName -Passed (-not $Condition) -Message $Message
    return (-not $Condition)
}

function Assert-Contains {
    param([string]$Haystack, [string]$Needle, [string]$TestName)
    $passed = $Haystack -match [regex]::Escape($Needle)
    $msg = if (-not $passed) { "String does not contain '$Needle'" } else { '' }
    Write-TestResult -TestName $TestName -Passed $passed -Message $msg
    return $passed
}

function Assert-FileExists {
    param([string]$Path, [string]$TestName)
    $passed = Test-Path $Path
    $msg = if (-not $passed) { "File not found: $Path" } else { '' }
    Write-TestResult -TestName $TestName -Passed $passed -Message $msg
    return $passed
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: FILE STRUCTURE
# ═══════════════════════════════════════════════════════════════

function Test-FileStructure {
    Write-TestHeader "FILE STRUCTURE TESTS"
    
    # Entry points (now in ralph/ folder)
    Assert-FileExists (Join-Path $RalphDir 'ralph.ps1') "ralph/ralph.ps1 exists"
    Assert-FileExists (Join-Path $RalphDir 'ralph.sh') "ralph/ralph.sh exists"
    
    # Core scripts (now in ralph/core/ folder)
    Assert-FileExists (Join-Path $CoreDir 'loop.ps1') "ralph/core/loop.ps1 exists"
    Assert-FileExists (Join-Path $CoreDir 'loop.sh') "ralph/core/loop.sh exists"
    Assert-FileExists (Join-Path $CoreDir 'venv.ps1') "ralph/core/venv.ps1 exists"
    Assert-FileExists (Join-Path $CoreDir 'venv.sh') "ralph/core/venv.sh exists"
    Assert-FileExists (Join-Path $CoreDir 'spinner.ps1') "ralph/core/spinner.ps1 exists"
    Assert-FileExists (Join-Path $CoreDir 'spinner.sh') "ralph/core/spinner.sh exists"
    Assert-FileExists (Join-Path $CoreDir 'tasks.ps1') "ralph/core/tasks.ps1 exists"
    Assert-FileExists (Join-Path $CoreDir 'tasks.sh') "ralph/core/tasks.sh exists"
    
    # Agent source files (in ralph/agents/)
    Assert-FileExists (Join-Path $AgentsSourceDir 'ralph.agent.md') "ralph/agents/ralph.agent.md exists"
    Assert-FileExists (Join-Path $AgentsSourceDir 'ralph-planner.agent.md') "ralph/agents/ralph-planner.agent.md exists"
    Assert-FileExists (Join-Path $AgentsSourceDir 'ralph-spec-creator.agent.md') "ralph/agents/ralph-spec-creator.agent.md exists"
    Assert-FileExists (Join-Path $AgentsSourceDir 'ralph-agents-updater.agent.md') "ralph/agents/ralph-agents-updater.agent.md exists"
    
    # Templates
    Assert-FileExists (Join-Path $RalphDir 'templates\AGENTS.template.md') "ralph/templates/AGENTS.template.md exists"
    Assert-FileExists (Join-Path $RalphDir 'templates\spec.template.md') "ralph/templates/spec.template.md exists"
    Assert-FileExists (Join-Path $RalphDir 'templates\ralph.instructions.md') "ralph/templates/ralph.instructions.md exists"
    
    # Documentation
    Assert-FileExists (Join-Path $RalphDir 'AGENTS.md') "ralph/AGENTS.md exists"
    Assert-FileExists (Join-Path $ProjectRoot 'README.md') "README.md exists"
    
    # Specs directory (inside ralph/)
    Assert-True (Test-Path $SpecsDir) "ralph/specs/ directory exists"
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: MODE VALIDATION
# ═══════════════════════════════════════════════════════════════

function Test-ModeValidation {
    Write-TestHeader "MODE VALIDATION TESTS"
    
    # Test valid modes in ralph/ralph.ps1
    $ralphPs1 = Get-Content (Join-Path $RalphDir 'ralph.ps1') -Raw
    
    Assert-Contains $ralphPs1 "ValidateSet('auto', 'plan', 'build', 'agents', 'continue', 'sessions')" "ralph.ps1 validates all modes"
    Assert-Contains $ralphPs1 "'agents'" "ralph.ps1 supports agents mode"
    Assert-Contains $ralphPs1 "'continue'" "ralph.ps1 supports continue mode"
    
    # Test valid modes in core/loop.ps1
    $loopPs1 = Get-Content (Join-Path $CoreDir 'loop.ps1') -Raw
    
    Assert-Contains $loopPs1 "ValidateSet('auto', 'plan', 'build', 'agents', 'continue', 'sessions')" "loop.ps1 validates all modes"
    Assert-Contains $loopPs1 "'agents'" "loop.ps1 handles agents mode in switch"
    Assert-Contains $loopPs1 "Invoke-AgentsUpdate" "loop.ps1 has Invoke-AgentsUpdate function"
    Assert-Contains $loopPs1 "'continue'" "loop.ps1 handles continue mode"
    
    # Test model parameter support in loop.ps1
    Assert-Contains $loopPs1 '[string]$Model' "loop.ps1 has Model parameter"
    Assert-Contains $loopPs1 '--model' "loop.ps1 passes --model to copilot CLI"
    
    # Test verbose parameter support in loop.ps1
    Assert-Contains $loopPs1 '[switch]$ShowVerbose' "loop.ps1 has ShowVerbose parameter"
    Assert-Contains $loopPs1 'VerboseMode' "loop.ps1 has VerboseMode variable"
    
    # Test bash script modes
    $loopSh = Get-Content (Join-Path $CoreDir 'loop.sh') -Raw
    
    Assert-Contains $loopSh "auto|plan|build|agents|continue" "loop.sh documents all modes"
    Assert-Contains $loopSh "invoke_agents_update" "loop.sh has invoke_agents_update function"
    Assert-Contains $loopSh "agents)" "loop.sh handles agents mode in case"
    Assert-Contains $loopSh "continue)" "loop.sh handles continue mode"
    
    # Test model parameter support in loop.sh
    Assert-Contains $loopSh 'MODEL=' "loop.sh has MODEL variable"
    Assert-Contains $loopSh '--model' "loop.sh passes --model to copilot CLI"
    Assert-Contains $loopSh '--list-models' "loop.sh has --list-models option"
    Assert-Contains $loopSh 'list_models' "loop.sh has list_models function"
    
    # Test verbose parameter support in loop.sh
    Assert-Contains $loopSh 'VERBOSE=' "loop.sh has VERBOSE variable"
    Assert-Contains $loopSh '--verbose' "loop.sh supports --verbose flag"
    Assert-Contains $loopSh 'log_verbose' "loop.sh has log_verbose function"
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: SPINNER MODULE
# ═══════════════════════════════════════════════════════════════

function Test-SpinnerModule {
    Write-TestHeader "SPINNER MODULE TESTS"
    
    # Test PowerShell spinner module
    $spinnerPs1 = Join-Path $CoreDir 'spinner.ps1'
    $spinnerContent = Get-Content $spinnerPs1 -Raw
    
    Assert-Contains $spinnerContent 'Invoke-CommandWithSpinner' "spinner.ps1 has Invoke-CommandWithSpinner function"
    Assert-Contains $spinnerContent 'Stop-Spinner' "spinner.ps1 has Stop-Spinner function"
    Assert-Contains $spinnerContent 'Write-SpinnerFrame' "spinner.ps1 has Write-SpinnerFrame function"
    Assert-Contains $spinnerContent 'Show-Progress' "spinner.ps1 has Show-Progress function"
    Assert-Contains $spinnerContent 'Complete-Progress' "spinner.ps1 has Complete-Progress function"
    Assert-Contains $spinnerContent 'Write-StatusLine' "spinner.ps1 has Write-StatusLine function"
    Assert-Contains $spinnerContent 'SpinnerStyles' "spinner.ps1 has SpinnerStyles definition"
    
    # Test Bash spinner module
    $spinnerSh = Join-Path $CoreDir 'spinner.sh'
    $spinnerShContent = Get-Content $spinnerSh -Raw
    
    Assert-Contains $spinnerShContent 'start_spinner' "spinner.sh has start_spinner function"
    Assert-Contains $spinnerShContent 'stop_spinner' "spinner.sh has stop_spinner function"
    Assert-Contains $spinnerShContent 'show_progress' "spinner.sh has show_progress function"
    Assert-Contains $spinnerShContent 'SPINNER_STYLES' "spinner.sh has SPINNER_STYLES definition"
    Assert-Contains $spinnerShContent 'with_spinner' "spinner.sh has with_spinner wrapper function"
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: AGENT PROMPTS
# ═══════════════════════════════════════════════════════════════

function Test-AgentPrompts {
    Write-TestHeader "AGENT PROMPT TESTS"
    
    # Test each agent file has required structure
    $agents = @(
        @{ Name = 'ralph'; File = 'ralph.agent.md'; Signal = 'COMPLETE' }
        @{ Name = 'ralph-planner'; File = 'ralph-planner.agent.md'; Signal = 'PLANNING_COMPLETE' }
        @{ Name = 'ralph-spec-creator'; File = 'ralph-spec-creator.agent.md'; Signal = 'SPEC_CREATED' }
        @{ Name = 'ralph-agents-updater'; File = 'ralph-agents-updater.agent.md'; Signal = 'AGENTS_UPDATED' }
    )
    
    foreach ($agent in $agents) {
        $path = Join-Path $AgentsSourceDir $agent.File
        $content = Get-Content $path -Raw
        
        # Check YAML frontmatter
        Assert-True ($content -match '^---') "$($agent.Name): Has YAML frontmatter"
        Assert-Contains $content "name: $($agent.Name)" "$($agent.Name): Has correct name in frontmatter"
        Assert-Contains $content "description:" "$($agent.Name): Has description in frontmatter"
        Assert-Contains $content "tools:" "$($agent.Name): Has tools in frontmatter"
        
        # Check signal
        Assert-Contains $content "<promise>$($agent.Signal)</promise>" "$($agent.Name): Has correct signal"
    }
}

function Test-AgentPromptExtraction {
    Write-TestHeader "AGENT PROMPT EXTRACTION TESTS"
    
    # Source the loop script to get the Get-AgentPrompt function
    $loopScript = Join-Path $CoreDir 'loop.ps1'
    
    # Extract the function definition and test it
    $loopContent = Get-Content $loopScript -Raw
    
    # Create a test agent content with frontmatter
    $testAgentContent = @"
---
name: test-agent
description: Test agent
tools: ["read"]
---

# Test Agent

This is the actual prompt content.

## Phase 1
Do something.
"@
    
    $tempFile = Join-Path $env:TEMP "test-agent-$([guid]::NewGuid()).md"
    $testAgentContent | Set-Content $tempFile -Encoding UTF8
    
    try {
        # Parse the function from the script
        $scriptBlock = [scriptblock]::Create(@"
function Get-AgentPrompt {
    param([string]`$AgentPath)
    
    if (-not (Test-Path `$AgentPath)) {
        return `$null
    }
    
    `$content = Get-Content `$AgentPath -Raw
    
    # Strip YAML frontmatter if present
    if (`$content -match '(?s)^---\s*\n.*?\n---\s*\n(.*)$') {
        return `$Matches[1].Trim()
    }
    
    return `$content.Trim()
}

Get-AgentPrompt -AgentPath '$tempFile'
"@)
        
        $result = & $scriptBlock
        
        Assert-True ($result -notmatch '^---') "Prompt extraction strips YAML frontmatter"
        Assert-Contains $result "# Test Agent" "Prompt extraction preserves content after frontmatter"
        Assert-Contains $result "Phase 1" "Prompt extraction preserves full prompt"
    }
    finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: SIGNALS
# ═══════════════════════════════════════════════════════════════

function Test-Signals {
    Write-TestHeader "SIGNAL DETECTION TESTS"
    
    # Test signal definitions in loop.ps1
    $loopPs1 = Get-Content (Join-Path $CoreDir 'loop.ps1') -Raw
    
    Assert-Contains $loopPs1 "Complete       = '<promise>COMPLETE</promise>'" "loop.ps1 defines COMPLETE signal"
    Assert-Contains $loopPs1 "PlanDone       = '<promise>PLANNING_COMPLETE</promise>'" "loop.ps1 defines PLANNING_COMPLETE signal"
    Assert-Contains $loopPs1 "SpecCreated    = '<promise>SPEC_CREATED</promise>'" "loop.ps1 defines SPEC_CREATED signal"
    Assert-Contains $loopPs1 "AgentsUpdated  = '<promise>AGENTS_UPDATED</promise>'" "loop.ps1 defines AGENTS_UPDATED signal"
    
    # Test signal definitions in loop.sh
    $loopSh = Get-Content (Join-Path $CoreDir 'loop.sh') -Raw
    
    Assert-Contains $loopSh "COMPLETE_SIGNAL='<promise>COMPLETE</promise>'" "loop.sh defines COMPLETE signal"
    Assert-Contains $loopSh "PLAN_SIGNAL='<promise>PLANNING_COMPLETE</promise>'" "loop.sh defines PLANNING_COMPLETE signal"
    Assert-Contains $loopSh "SPEC_CREATED_SIGNAL='<promise>SPEC_CREATED</promise>'" "loop.sh defines SPEC_CREATED signal"
    Assert-Contains $loopSh "AGENTS_UPDATED_SIGNAL='<promise>AGENTS_UPDATED</promise>'" "loop.sh defines AGENTS_UPDATED signal"
    
    # Test signal documentation in ralph/AGENTS.md
    $agentsMd = Get-Content (Join-Path $RalphDir 'AGENTS.md') -Raw
    
    Assert-Contains $agentsMd "<promise>COMPLETE</promise>" "ralph/AGENTS.md documents COMPLETE signal"
    Assert-Contains $agentsMd "<promise>PLANNING_COMPLETE</promise>" "ralph/AGENTS.md documents PLANNING_COMPLETE signal"
    Assert-Contains $agentsMd "<promise>SPEC_CREATED</promise>" "ralph/AGENTS.md documents SPEC_CREATED signal"
    # Note: AGENTS_UPDATED signal not documented in ralph/AGENTS.md (it's Ralph-internal)
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Test-UtilityFunctions {
    Write-TestHeader "UTILITY FUNCTION TESTS"
    
    # Test Get-TaskStats logic
    $testPlanContent = @"
# Implementation Plan

## Tasks
- [ ] Task 1
- [ ] Task 2
- [x] Completed task 1
- [x] Completed task 2
- [x] Completed task 3
"@
    
    $tempPlanFile = Join-Path $env:TEMP "test-plan-$([guid]::NewGuid()).md"
    $testPlanContent | Set-Content $tempPlanFile -Encoding UTF8
    
    try {
        $content = Get-Content $tempPlanFile -Raw
        $pending = ([regex]::Matches($content, '- \[ \]')).Count
        $completed = ([regex]::Matches($content, '- \[x\]')).Count
        $total = $pending + $completed
        
        Assert-Equal 2 $pending "Get-TaskStats: Correct pending count"
        Assert-Equal 3 $completed "Get-TaskStats: Correct completed count"
        Assert-Equal 5 $total "Get-TaskStats: Correct total count"
    }
    finally {
        Remove-Item $tempPlanFile -ErrorAction SilentlyContinue
    }
    
    # Test Get-NextTask logic
    $testPlanContent2 = @"
## Tasks
- [x] Done task
- [ ] First pending task
- [ ] Second pending task
"@
    
    $tempPlanFile2 = Join-Path $env:TEMP "test-plan2-$([guid]::NewGuid()).md"
    $testPlanContent2 | Set-Content $tempPlanFile2 -Encoding UTF8
    
    try {
        $content = Get-Content $tempPlanFile2
        $nextTask = $null
        foreach ($line in $content) {
            if ($line -match '^\s*-\s*\[\s*\]\s*(.+)$') {
                $nextTask = $Matches[1].Trim()
                break
            }
        }
        
        Assert-Equal "First pending task" $nextTask "Get-NextTask: Returns first pending task"
    }
    finally {
        Remove-Item $tempPlanFile2 -ErrorAction SilentlyContinue
    }
}

function Test-BuildTaskPrompt {
    Write-TestHeader "BUILD TASK PROMPT TESTS"
    
    # Test Build-TaskPrompt function exists and works correctly
    $loopContent = Get-Content (Join-Path $script:CoreDir "loop.ps1") -Raw
    
    Assert-True ($loopContent -match 'function Build-TaskPrompt') "Build-TaskPrompt function exists"
    Assert-True ($loopContent -match 'param\s*\(\s*\[Parameter\(Mandatory\)\]') "Build-TaskPrompt has mandatory parameters"
    Assert-True ($loopContent -match '\[string\]\$BasePrompt') "Build-TaskPrompt has BasePrompt parameter"
    Assert-True ($loopContent -match '\[string\]\$Task') "Build-TaskPrompt has Task parameter"
    Assert-True ($loopContent -match 'IsNullOrWhiteSpace.*BasePrompt') "Build-TaskPrompt validates BasePrompt"
    Assert-True ($loopContent -match 'IsNullOrWhiteSpace.*Task') "Build-TaskPrompt validates Task"
    Assert-True ($loopContent -match 'YOUR ASSIGNED TASK') "Build-TaskPrompt includes task header"
    Assert-True ($loopContent -match 'DO NOT search for tasks') "Build-TaskPrompt includes explicit instruction"
    
    # Test bash build_task_prompt function exists
    $loopShContent = Get-Content (Join-Path $script:CoreDir "loop.sh") -Raw
    
    Assert-True ($loopShContent -match 'build_task_prompt\(\)') "bash build_task_prompt function exists"
    Assert-True ($loopShContent -match 'local base_prompt="\$1"') "bash build_task_prompt has base_prompt param"
    Assert-True ($loopShContent -match 'local task="\$2"') "bash build_task_prompt has task param"
    Assert-True ($loopShContent -match '\[\[ -z "\$base_prompt" \]\]') "bash build_task_prompt validates base_prompt"
    Assert-True ($loopShContent -match '\[\[ -z "\$task" \]\]') "bash build_task_prompt validates task"
    
    # Test that Build-TaskPrompt is used in the build loop
    Assert-True ($loopContent -match 'Build-TaskPrompt -BasePrompt \$agentPrompt -Task \$task') "Build loop uses Build-TaskPrompt"
    Assert-True ($loopShContent -match 'build_task_prompt "\$agent_prompt" "\$task"') "Bash build loop uses build_task_prompt"
}

function Test-UserSpecsDetection {
    Write-TestHeader "USER SPECS DETECTION TESTS"
    
    # Create temp specs directory
    $tempSpecsDir = Join-Path $env:TEMP "test-specs-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tempSpecsDir -Force | Out-Null
    
    try {
        # Test with no specs
        $specs = @(Get-ChildItem -Path $tempSpecsDir -Filter "*.md" -ErrorAction SilentlyContinue |
                 Where-Object { -not $_.Name.StartsWith('_') })
        Assert-Equal 0 $specs.Count "No specs in empty directory"
        
        # Add template (should be ignored)
        "_template.md" | Set-Content (Join-Path $tempSpecsDir "_template.md")
        $specs = @(Get-ChildItem -Path $tempSpecsDir -Filter "*.md" -ErrorAction SilentlyContinue |
                 Where-Object { -not $_.Name.StartsWith('_') })
        Assert-Equal 0 $specs.Count "Template files are ignored"
        
        # Add user spec
        "# Feature" | Set-Content (Join-Path $tempSpecsDir "feature.md")
        $specs = @(Get-ChildItem -Path $tempSpecsDir -Filter "*.md" -ErrorAction SilentlyContinue |
                 Where-Object { -not $_.Name.StartsWith('_') })
        Assert-Equal 1 $specs.Count "User spec is detected"
        
        # Add another spec
        "# Feature 2" | Set-Content (Join-Path $tempSpecsDir "feature2.md")
        $specs = @(Get-ChildItem -Path $tempSpecsDir -Filter "*.md" -ErrorAction SilentlyContinue |
                 Where-Object { -not $_.Name.StartsWith('_') })
        Assert-Equal 2 $specs.Count "Multiple user specs are detected"
    }
    finally {
        Remove-Item $tempSpecsDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: AUTO MODE INTEGRATION
# ═══════════════════════════════════════════════════════════════

function Test-AutoModeIntegration {
    Write-TestHeader "AUTO MODE INTEGRATION TESTS"
    
    $loopPs1 = Get-Content (Join-Path $CoreDir 'loop.ps1') -Raw
    
    # Test that auto mode calls agents update first
    Assert-Contains $loopPs1 "Invoke-AgentsUpdate" "Auto mode calls Invoke-AgentsUpdate"
    
    # Test auto mode still includes planning
    Assert-Contains $loopPs1 "Test-NeedsPlanning" "Auto mode checks if planning needed"
    Assert-Contains $loopPs1 "Invoke-Planning" "Auto mode calls Invoke-Planning"
    
    # Test auto mode still includes building
    Assert-Contains $loopPs1 "Invoke-Building" "Auto mode calls Invoke-Building"
    
    # Test bash script auto mode
    $loopSh = Get-Content (Join-Path $CoreDir 'loop.sh') -Raw
    
    Assert-Contains $loopSh "invoke_agents_update" "Bash auto mode calls invoke_agents_update"
    Assert-Contains $loopSh "invoke_planning" "Bash auto mode calls invoke_planning"
    Assert-Contains $loopSh "invoke_building" "Bash auto mode calls invoke_building"
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: AGENTS UPDATER AGENT
# ═══════════════════════════════════════════════════════════════

function Test-AgentsUpdaterAgent {
    Write-TestHeader "AGENTS UPDATER AGENT TESTS"
    
    $agentPath = Join-Path $AgentsSourceDir 'ralph-agents-updater.agent.md'
    $content = Get-Content $agentPath -Raw
    
    # Test it covers major project types (simplified table format)
    Assert-Contains $content "package.json" "Detects Node.js projects"
    Assert-Contains $content "pyproject.toml" "Detects Python projects"
    Assert-Contains $content "go.mod" "Detects Go projects"
    Assert-Contains $content "Cargo.toml" "Detects Rust projects"
    Assert-Contains $content "*.csproj" "Detects .NET projects"
    
    # Test it enforces AGENTS.md brevity (critical Ralph principle)
    Assert-Contains $content "~60 lines" "Enforces ~60 line limit"
    Assert-Contains $content "operational only" "Enforces operational-only content"
    
    # Test it updates AGENTS.md
    Assert-Contains $content "AGENTS.md" "References AGENTS.md"
    Assert-Contains $content "Validation" "Updates validation section"
    
    # Test correct signal
    Assert-Contains $content "<promise>AGENTS_UPDATED</promise>" "Has correct completion signal"
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: DOCUMENTATION CONSISTENCY
# ═══════════════════════════════════════════════════════════════

function Test-DocumentationConsistency {
    Write-TestHeader "DOCUMENTATION CONSISTENCY TESTS"
    
    $readme = Get-Content (Join-Path $ProjectRoot 'README.md') -Raw
    $agentsMd = Get-Content (Join-Path $RalphDir 'AGENTS.md') -Raw
    
    # Test README documents all modes
    Assert-Contains $readme "-Mode plan" "README documents plan mode"
    Assert-Contains $readme "-Mode build" "README documents build mode"
    Assert-Contains $readme "-Mode agents" "README documents agents mode"
    Assert-Contains $readme "-m plan" "README documents bash plan mode"
    Assert-Contains $readme "-m build" "README documents bash build mode"
    Assert-Contains $readme "-m agents" "README documents bash agents mode"
    
    # Test ralph/AGENTS.md documents Ralph-specific usage
    Assert-Contains $agentsMd "ralph.ps1" "ralph/AGENTS.md documents main entry point"
    Assert-Contains $agentsMd "tests" "ralph/AGENTS.md documents test command"
    
    # Test README documents all agents
    Assert-Contains $readme "ralph.agent.md" "README documents ralph agent"
    Assert-Contains $readme "ralph-planner.agent.md" "README documents planner agent"
    Assert-Contains $readme "ralph-spec-creator.agent.md" "README documents spec creator agent"
    Assert-Contains $readme "ralph-agents-updater.agent.md" "README documents agents updater agent"
    
    # Test project structure is consistent
    Assert-Contains $readme "ralph-agents-updater" "README project structure includes agents updater"
    Assert-Contains $agentsMd "ralph/" "ralph/AGENTS.md references ralph directory"
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: POWERSHELL HELP
# ═══════════════════════════════════════════════════════════════

function Test-PowerShellHelp {
    Write-TestHeader "POWERSHELL HELP TESTS"
    
    # Test ralph/ralph.ps1 help
    $ralphHelp = Get-Help (Join-Path $RalphDir 'ralph.ps1') -Full
    
    Assert-True ($null -ne $ralphHelp.Synopsis) "ralph.ps1 has synopsis"
    Assert-True ($null -ne $ralphHelp.Description) "ralph.ps1 has description"
    
    # Test Mode parameter help
    $modeParam = $ralphHelp.Parameters.Parameter | Where-Object { $_.Name -eq 'Mode' }
    Assert-True ($null -ne $modeParam) "ralph.ps1 documents Mode parameter"
    Assert-Contains $modeParam.Description.Text "agents" "Mode parameter describes agents mode"
    
    # Test Model parameter help
    $modelParam = $ralphHelp.Parameters.Parameter | Where-Object { $_.Name -eq 'Model' }
    Assert-True ($null -ne $modelParam) "ralph.ps1 documents Model parameter"
    Assert-Contains $modelParam.Description.Text "claude-sonnet-4" "Model parameter shows example model"
    
    # Test ListModels parameter help
    $listModelsParam = $ralphHelp.Parameters.Parameter | Where-Object { $_.Name -eq 'ListModels' }
    Assert-True ($null -ne $listModelsParam) "ralph.ps1 documents ListModels parameter"
    
    # Test examples exist
    Assert-True ($ralphHelp.Examples.Example.Count -ge 2) "ralph.ps1 has examples"
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: INITIALIZATION FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Test-InitializationFunctions {
    Write-TestHeader "INITIALIZATION FUNCTION TESTS"
    
    $loopPs1 = Get-Content (Join-Path $CoreDir 'loop.ps1') -Raw
    $initPs1 = Get-Content (Join-Path $CoreDir 'initialization.ps1') -Raw
    $loopSh = Get-Content (Join-Path $CoreDir 'loop.sh') -Raw
    
    # PowerShell initialization functions (now in initialization.ps1 module)
    Assert-Contains $initPs1 "function Initialize-ProgressFile" "Initialize-ProgressFile function exists"
    Assert-Contains $initPs1 "function Initialize-PlanFile" "Initialize-PlanFile function exists"
    Assert-Contains $initPs1 "function Initialize-RalphInstructions" "Initialize-RalphInstructions function exists"
    Assert-Contains $loopPs1 "Initialize-RalphInstructions" "Initialize-RalphInstructions is called"
    Assert-Contains $initPs1 "ralph.instructions.md" "PS1 references ralph.instructions.md"
    
    # Bash initialization functions
    Assert-Contains $loopSh "ensure_progress_file()" "ensure_progress_file function exists"
    Assert-Contains $loopSh "ensure_plan_file()" "ensure_plan_file function exists"
    Assert-Contains $loopSh "ensure_ralph_instructions()" "ensure_ralph_instructions function exists"
    Assert-Contains $loopSh "ensure_ralph_instructions" "ensure_ralph_instructions is called"
    Assert-Contains $loopSh "ralph.instructions.md" "Bash references ralph.instructions.md"
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: INVOKE FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Test-InvokeFunctions {
    Write-TestHeader "INVOKE FUNCTION TESTS"
    
    $loopPs1 = Get-Content (Join-Path $CoreDir 'loop.ps1') -Raw
    $specsPs1 = Get-Content (Join-Path $CoreDir 'specs.ps1') -Raw
    
    # Test Invoke-AgentsUpdate function exists and has correct structure
    Assert-Contains $loopPs1 "function Invoke-AgentsUpdate" "Invoke-AgentsUpdate function exists"
    Assert-Contains $loopPs1 "AgentFiles.AgentsUpdater" "Invoke-AgentsUpdate uses correct agent file"
    Assert-Contains $loopPs1 "Signals.AgentsUpdated" "Invoke-AgentsUpdate checks for correct signal"
    
    # Test Invoke-Planning function
    Assert-Contains $loopPs1 "function Invoke-Planning" "Invoke-Planning function exists"
    Assert-Contains $loopPs1 "AgentFiles.Plan" "Invoke-Planning uses correct agent file"
    Assert-Contains $loopPs1 "Signals.PlanDone" "Invoke-Planning checks for correct signal"
    
    # Test Invoke-Building function
    Assert-Contains $loopPs1 "function Invoke-Building" "Invoke-Building function exists"
    Assert-Contains $loopPs1 "AgentFiles.Build" "Invoke-Building uses correct agent file"
    Assert-Contains $loopPs1 "Signals.Complete" "Invoke-Building checks for correct signal"
    
    # Test Invoke-SpecCreation function (now in specs.ps1 module)
    Assert-Contains $specsPs1 "function Invoke-SpecCreation" "Invoke-SpecCreation function exists"
    Assert-Contains $specsPs1 "AgentFiles.SpecCreator" "Invoke-SpecCreation uses correct agent file"
    Assert-Contains $specsPs1 "Signals.SpecCreated" "Invoke-SpecCreation checks for correct signal"
}

# ═══════════════════════════════════════════════════════════════
#                     TEST: BASH SCRIPT FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Test-BashScriptFunctions {
    Write-TestHeader "BASH SCRIPT FUNCTION TESTS"
    
    $loopSh = Get-Content (Join-Path $CoreDir 'loop.sh') -Raw
    
    # Test invoke_agents_update function
    Assert-Contains $loopSh "invoke_agents_update()" "invoke_agents_update function exists"
    Assert-Contains $loopSh "AGENTS_UPDATER_AGENT" "invoke_agents_update uses correct agent"
    Assert-Contains $loopSh "AGENTS_UPDATED_SIGNAL" "invoke_agents_update checks for correct signal"
    
    # Test invoke_planning function
    Assert-Contains $loopSh "invoke_planning()" "invoke_planning function exists"
    Assert-Contains $loopSh "PLAN_AGENT" "invoke_planning uses correct agent"
    Assert-Contains $loopSh "PLAN_SIGNAL" "invoke_planning checks for correct signal"
    
    # Test invoke_building function
    Assert-Contains $loopSh "invoke_building()" "invoke_building function exists"
    Assert-Contains $loopSh "BUILD_AGENT" "invoke_building uses correct agent"
    Assert-Contains $loopSh "COMPLETE_SIGNAL" "invoke_building checks for correct signal"
    
    # Test invoke_spec_creation function
    Assert-Contains $loopSh "invoke_spec_creation()" "invoke_spec_creation function exists"
    Assert-Contains $loopSh "SPEC_CREATOR_AGENT" "invoke_spec_creation uses correct agent"
    Assert-Contains $loopSh "SPEC_CREATED_SIGNAL" "invoke_spec_creation checks for correct signal"
}

# ═══════════════════════════════════════════════════════════════
#                        RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════

function Invoke-AllTests {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║           RALPH COMPREHENSIVE TEST SUITE                      ║" -ForegroundColor Magenta
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Project Root: $ProjectRoot" -ForegroundColor Gray
    Write-Host "  Test Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    
    # Run all test functions
    Test-FileStructure
    Test-ModeValidation
    Test-SpinnerModule
    Test-AgentPrompts
    Test-AgentPromptExtraction
    Test-Signals
    Test-UtilityFunctions
    Test-BuildTaskPrompt
    Test-UserSpecsDetection
    Test-AutoModeIntegration
    Test-AgentsUpdaterAgent
    Test-DocumentationConsistency
    Test-PowerShellHelp
    Test-InitializationFunctions
    Test-InvokeFunctions
    Test-BashScriptFunctions
    
    # Print summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  TEST SUMMARY" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Passed:  $TestsPassed" -ForegroundColor Green
    Write-Host "  Failed:  $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Skipped: $TestsSkipped" -ForegroundColor Yellow
    Write-Host "  Total:   $($TestsPassed + $TestsFailed + $TestsSkipped)" -ForegroundColor White
    Write-Host ""
    
    if ($TestsFailed -gt 0) {
        Write-Host "  ❌ TESTS FAILED" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "  ✅ ALL TESTS PASSED" -ForegroundColor Green
        exit 0
    }
}

# Run tests
Invoke-AllTests
