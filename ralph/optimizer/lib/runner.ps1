<#
.SYNOPSIS
    Experiment runner for Ralph Optimization Framework

.DESCRIPTION
    Runs a single optimization experiment:
    1. Creates fresh temp project
    2. Copies specified agent configuration
    3. Runs Ralph in auto mode
    4. Collects quality metrics
    5. Returns results
#>

param(
    [Parameter(Mandatory)]
    [string]$ExperimentName,
    
    [string]$AgentVariantPath,
    
    [string]$SpecPath,
    
    [int]$MaxIterations = 20,
    
    [string]$Model = "claude-sonnet-4.5",
    
    [switch]$KeepProject
)

$ErrorActionPreference = 'Stop'

# Get script directory for relative paths
$script:OptimizerDir = Split-Path -Parent $PSScriptRoot
$script:RalphRoot = Split-Path -Parent $script:OptimizerDir

# Source metrics library
. (Join-Path $script:OptimizerDir 'lib\metrics.ps1')

# ═══════════════════════════════════════════════════════════════
#                    EXPERIMENT SETUP
# ═══════════════════════════════════════════════════════════════

function New-ExperimentProject {
    <#
    .SYNOPSIS
        Creates a fresh project for the experiment
    #>
    param([string]$Name)
    
    $projectPath = Join-Path $env:TEMP "ralph-experiment-$Name-$([guid]::NewGuid().ToString().Substring(0,8))"
    New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
    
    Push-Location $projectPath
    try {
        # Initialize git
        git init --quiet
        git config user.email "experiment@ralph.local"
        git config user.name "Ralph Experiment"
        
        # Create README
        @"
# Experiment: $Name

This project was created by the Ralph Optimization Framework.
"@ | Set-Content "README.md"
        
        git add README.md
        git commit -m "Initial commit" --quiet
    } finally {
        Pop-Location
    }
    
    return $projectPath
}

function Copy-AgentVariant {
    <#
    .SYNOPSIS
        Copies agent variant files to the experiment project
    #>
    param(
        [string]$ProjectPath,
        [string]$VariantPath
    )
    
    # Create ralph/agents directory
    $agentsDir = Join-Path $ProjectPath "ralph\agents"
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
    
    if ($VariantPath -and (Test-Path $VariantPath)) {
        # Copy specific variant
        Copy-Item "$VariantPath\*" $agentsDir -Recurse -Force
    } else {
        # Copy current agents from Ralph
        $sourceAgents = Join-Path $script:RalphRoot "agents"
        Copy-Item "$sourceAgents\*" $agentsDir -Recurse -Force
    }
}

function Copy-Specification {
    <#
    .SYNOPSIS
        Copies specification to the experiment project
    #>
    param(
        [string]$ProjectPath,
        [string]$SpecPath
    )
    
    # Copy to ralph/specs/ for 'global' specsSource (this is where tasks.ps1 looks)
    $specsDir = Join-Path $ProjectPath "ralph\specs"
    New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
    
    if ($SpecPath -and (Test-Path $SpecPath)) {
        Copy-Item $SpecPath (Join-Path $specsDir "spec.md")
    } else {
        # Use baseline spec
        $baseline = Join-Path $script:OptimizerDir "config\baseline-spec.md"
        Copy-Item $baseline (Join-Path $specsDir "spec.md")
    }
}

function Copy-RalphCore {
    <#
    .SYNOPSIS
        Copies Ralph core files to experiment project
    #>
    param([string]$ProjectPath)
    
    $ralphDir = Join-Path $ProjectPath "ralph"
    New-Item -ItemType Directory -Path $ralphDir -Force | Out-Null
    
    # Copy core files
    $coreDirs = @('core', 'templates', 'scripts', 'cli', 'agents')
    foreach ($dir in $coreDirs) {
        $source = Join-Path $script:RalphRoot $dir
        if (Test-Path $source) {
            Copy-Item $source (Join-Path $ralphDir $dir) -Recurse -Force
        }
    }
    
    # Copy main scripts
    Copy-Item (Join-Path $script:RalphRoot "ralph.ps1") (Join-Path $ralphDir "ralph.ps1")
    Copy-Item (Join-Path $script:RalphRoot "ralph.sh") (Join-Path $ralphDir "ralph.sh") -ErrorAction SilentlyContinue
    
    # Copy AGENTS.md
    $agentsmd = Join-Path $script:RalphRoot "AGENTS.md"
    if (Test-Path $agentsmd) {
        Copy-Item $agentsmd (Join-Path $ralphDir "AGENTS.md")
    }
    
    # Copy config
    $configSource = Join-Path $script:RalphRoot "config.json"
    if (Test-Path $configSource) {
        Copy-Item $configSource (Join-Path $ralphDir "config.json")
    }
}

function New-ExperimentSession {
    <#
    .SYNOPSIS
        Creates a session programmatically (bypassing interactive menu)
    #>
    param(
        [string]$ProjectPath,
        [string]$SessionName
    )
    
    Push-Location $ProjectPath
    try {
        # Create .ralph directory structure
        $ralphDir = Join-Path $ProjectPath ".ralph"
        New-Item -ItemType Directory -Path $ralphDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ralphDir "tasks") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ralphDir "logs") -Force | Out-Null
        
        # Create .github directories
        $githubDir = Join-Path $ProjectPath ".github"
        New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $githubDir "instructions") -Force | Out-Null
        $githubAgentsDir = Join-Path $githubDir "agents"
        New-Item -ItemType Directory -Path $githubAgentsDir -Force | Out-Null
        
        # Copy agent files to .github/agents (required for Copilot CLI)
        $ralphAgentsDir = Join-Path $ProjectPath "ralph\agents"
        if (Test-Path $ralphAgentsDir) {
            Get-ChildItem $ralphAgentsDir -Filter "*.agent.md" | ForEach-Object {
                Copy-Item $_.FullName (Join-Path $githubAgentsDir $_.Name) -Force
            }
        }
        
        # Copy ralph.instructions.md
        $instructionsSource = Join-Path $ProjectPath "ralph\templates\ralph.instructions.md"
        if (Test-Path $instructionsSource) {
            Copy-Item $instructionsSource (Join-Path $githubDir "instructions\ralph.instructions.md")
        }
        
        # Create AGENTS.md from template
        $agentsTemplate = Join-Path $ProjectPath "ralph\templates\AGENTS.template.md"
        $agentsMd = Join-Path $ProjectPath "AGENTS.md"
        if ((Test-Path $agentsTemplate) -and -not (Test-Path $agentsMd)) {
            Copy-Item $agentsTemplate $agentsMd
        }
        
        # Create progress.txt
        @"
# Progress Tracker
Generated by Ralph Optimization Framework
"@ | Set-Content (Join-Path $ProjectPath "progress.txt") -Encoding UTF8
        
        # Generate task ID
        $slug = ($SessionName -replace '[^a-zA-Z0-9]+', '-' -replace '^-|-$', '').ToLower()
        $date = Get-Date -Format 'yyyyMMdd-HHmmss'
        $taskId = "$slug-$date"
        
        # Create task directory
        $taskDir = Join-Path $ralphDir "tasks\$taskId"
        New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
        
        # Create task.json - use 'global' for specs since specs/ folder exists at project root
        $config = @{
            id          = $taskId
            name        = $SessionName
            description = "Optimization experiment session"
            created     = (Get-Date).ToString('o')
            status      = 'active'
            specsSource = 'global'
            specsFolder = ''
            referencesSource = 'none'
            referencesFolder = ''
            referencesEnabled = $false
            referenceDirectories = @()
            referenceFiles = @()
        }
        $config | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $taskDir 'task.json') -Encoding UTF8
        
        # Create IMPLEMENTATION_PLAN.md
        @"
# Implementation Plan

## Tasks

*Planning phase will populate this file.*
"@ | Set-Content (Join-Path $taskDir 'IMPLEMENTATION_PLAN.md') -Encoding UTF8
        
        # Create memory.md at root .ralph level
        @"
# Session Memory

*Session memories will be stored here.*
"@ | Set-Content (Join-Path $ralphDir 'memory.md') -Encoding UTF8
        
        # Set this as the active task
        $activeTaskFile = Join-Path $ralphDir "active-task"
        $taskId | Set-Content $activeTaskFile -Encoding UTF8
        
        return $taskId
    } finally {
        Pop-Location
    }
}

# ═══════════════════════════════════════════════════════════════
#                    EXPERIMENT EXECUTION
# ═══════════════════════════════════════════════════════════════

function Invoke-Experiment {
    <#
    .SYNOPSIS
        Runs the full experiment
    #>
    param(
        [string]$Name,
        [string]$ProjectPath,
        [string]$SessionId,
        [int]$MaxIterations,
        [string]$Model
    )
    
    $startTime = Get-Date
    
    Push-Location $ProjectPath
    try {
        # Run Ralph in auto mode with the session, using AutoStart to bypass interactive menus
        $ralphScript = Join-Path $ProjectPath "ralph\ralph.ps1"
        
        $result = & pwsh -File $ralphScript -Mode auto -Session $SessionId -AutoStart -MaxIterations $MaxIterations -Model $Model 2>&1
        
        $exitCode = $LASTEXITCODE
        $duration = (Get-Date) - $startTime
        
        return @{
            Success = ($exitCode -eq 0)
            Duration = $duration
            Output = $result -join "`n"
            ExitCode = $exitCode
        }
    } finally {
        Pop-Location
    }
}

# ═══════════════════════════════════════════════════════════════
#                    MAIN
# ═══════════════════════════════════════════════════════════════

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RALPH OPTIMIZATION EXPERIMENT: $ExperimentName" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create fresh project
Write-Host "[1/6] Creating experiment project..." -ForegroundColor Yellow
$projectPath = New-ExperimentProject -Name $ExperimentName
Write-Host "  Project: $projectPath" -ForegroundColor Gray

# Step 2: Copy Ralph files
Write-Host "[2/6] Setting up Ralph..." -ForegroundColor Yellow
Copy-RalphCore -ProjectPath $projectPath
Copy-AgentVariant -ProjectPath $projectPath -VariantPath $AgentVariantPath
Copy-Specification -ProjectPath $projectPath -SpecPath $SpecPath
Write-Host "  Ralph configured" -ForegroundColor Gray

# Step 3: Create session
Write-Host "[3/6] Creating session..." -ForegroundColor Yellow
$sessionId = New-ExperimentSession -ProjectPath $projectPath -SessionName $ExperimentName
Write-Host "  Session: $sessionId" -ForegroundColor Gray

# Step 4: Run experiment
Write-Host "[4/6] Running Ralph (max $MaxIterations iterations)..." -ForegroundColor Yellow
$runResult = Invoke-Experiment -Name $ExperimentName -ProjectPath $projectPath -SessionId $sessionId -MaxIterations $MaxIterations -Model $Model
Write-Host "  Duration: $($runResult.Duration.TotalMinutes.ToString('F1')) minutes" -ForegroundColor Gray
Write-Host "  Success: $($runResult.Success)" -ForegroundColor $(if ($runResult.Success) { 'Green' } else { 'Red' })

# Step 5: Collect metrics
Write-Host "[5/6] Collecting quality metrics..." -ForegroundColor Yellow
$metrics = Get-ProjectQualityScore -ProjectPath $projectPath
Write-Host "  Overall Score: $($metrics.OverallScore)/100" -ForegroundColor $(
    if ($metrics.OverallScore -ge 80) { 'Green' }
    elseif ($metrics.OverallScore -ge 60) { 'Yellow' }
    else { 'Red' }
)

# Step 6: Store results
Write-Host "[6/6] Storing results..." -ForegroundColor Yellow
$experiment = @{
    Name = $ExperimentName
    Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    ProjectPath = $projectPath
    AgentVariant = if ($AgentVariantPath) { Split-Path -Leaf $AgentVariantPath } else { "baseline" }
    MaxIterations = $MaxIterations
    Model = $Model
    RunResult = @{
        Success = $runResult.Success
        DurationMinutes = [Math]::Round($runResult.Duration.TotalMinutes, 2)
        ExitCode = $runResult.ExitCode
    }
    Metrics = $metrics
}

# Save to results file
$resultsFile = Join-Path $script:OptimizerDir "results\experiments.json"
$existingResults = @()
if (Test-Path $resultsFile) {
    $existingResults = @(Get-Content $resultsFile -Raw | ConvertFrom-Json)
}
$existingResults += $experiment
$existingResults | ConvertTo-Json -Depth 10 | Set-Content $resultsFile

Write-Host "  Saved to: $resultsFile" -ForegroundColor Gray

# Cleanup
if (-not $KeepProject) {
    Write-Host ""
    Write-Host "Cleaning up experiment project..." -ForegroundColor DarkGray
    Remove-Item $projectPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  EXPERIMENT COMPLETE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Overall Score: $($metrics.OverallScore)/100" -ForegroundColor White
Write-Host "  Structure:     $($metrics.CategoryScores.Structure)/100" -ForegroundColor Gray
Write-Host "  Code:          $($metrics.CategoryScores.Code)/100" -ForegroundColor Gray
Write-Host "  Quality:       $($metrics.CategoryScores.Quality)/100" -ForegroundColor Gray
Write-Host "  Efficiency:    $($metrics.CategoryScores.Efficiency)/100" -ForegroundColor Gray
Write-Host ""

# Return experiment data for pipeline use
return $experiment
