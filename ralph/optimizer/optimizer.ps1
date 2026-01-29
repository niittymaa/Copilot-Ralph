<#
.SYNOPSIS
    Ralph Optimization Framework - Main Entry Point

.DESCRIPTION
    Runs iterative optimization experiments to find the best agent configuration.
    
    Workflow:
    1. Run baseline experiment
    2. Analyze results to find weakest category
    3. Generate variant targeting weak area
    4. Run experiment with variant
    5. Compare to best result
    6. Repeat until convergence or max iterations

.PARAMETER Mode
    Operation mode:
    - optimize: Run full optimization loop
    - analyze: Analyze existing results only
    - baseline: Run baseline experiment only
    - variant: Run specific variant experiment
    - report: Generate report from results

.PARAMETER VariantName
    Specific variant to test (for -Mode variant)

.PARAMETER MaxExperiments
    Maximum experiments to run in optimization loop

.PARAMETER MaxIterationsPerExperiment
    Maximum Ralph iterations per experiment

.PARAMETER Model
    AI model to use for experiments

.EXAMPLE
    .\optimizer.ps1 -Mode optimize -MaxExperiments 5
    
.EXAMPLE
    .\optimizer.ps1 -Mode baseline
    
.EXAMPLE
    .\optimizer.ps1 -Mode report
#>

param(
    [ValidateSet('optimize', 'analyze', 'baseline', 'variant', 'report', 'metrics')]
    [string]$Mode = 'optimize',
    
    [string]$VariantName,
    
    [int]$MaxExperiments = 5,
    
    [int]$MaxIterationsPerExperiment = 15,
    
    [string]$Model = "claude-sonnet-4.5",
    
    [string]$ProjectPath,
    
    [switch]$KeepProjects
)

$ErrorActionPreference = 'Stop'

# Setup paths
$script:OptimizerDir = $PSScriptRoot
$script:RalphRoot = Split-Path -Parent $script:OptimizerDir
$script:LibDir = Join-Path $script:OptimizerDir 'lib'
$script:ResultsDir = Join-Path $script:OptimizerDir 'results'
$script:VariantsDir = Join-Path $script:ResultsDir 'variants'

# Source libraries
. (Join-Path $script:LibDir 'metrics.ps1')
. (Join-Path $script:LibDir 'analyzer.ps1')
. (Join-Path $script:LibDir 'variants.ps1')

# ═══════════════════════════════════════════════════════════════
#                    DISPLAY HELPERS
# ═══════════════════════════════════════════════════════════════

function Write-OptHeader {
    param([string]$Text)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-OptInfo {
    param([string]$Text)
    Write-Host "  $Text" -ForegroundColor White
}

function Write-OptSuccess {
    param([string]$Text)
    Write-Host "  ✓ $Text" -ForegroundColor Green
}

function Write-OptWarning {
    param([string]$Text)
    Write-Host "  ⚠ $Text" -ForegroundColor Yellow
}

function Write-OptError {
    param([string]$Text)
    Write-Host "  ✗ $Text" -ForegroundColor Red
}

function Show-ScoreBar {
    param([int]$Score, [string]$Label)
    
    $filled = [Math]::Floor($Score / 5)
    $empty = 20 - $filled
    $bar = ('█' * $filled) + ('░' * $empty)
    $color = if ($Score -ge 80) { 'Green' } elseif ($Score -ge 60) { 'Yellow' } else { 'Red' }
    
    Write-Host "  $($Label.PadRight(12)) " -NoNewline
    Write-Host "$bar" -NoNewline -ForegroundColor $color
    Write-Host " $Score" -ForegroundColor $color
}

# ═══════════════════════════════════════════════════════════════
#                    MODE: METRICS
# ═══════════════════════════════════════════════════════════════

function Invoke-MetricsMode {
    param([string]$Path)
    
    Write-OptHeader "QUALITY METRICS ANALYSIS"
    
    if (-not $Path -or -not (Test-Path $Path)) {
        Write-OptError "Provide a valid project path with -ProjectPath"
        return
    }
    
    Write-OptInfo "Analyzing: $Path"
    Write-Host ""
    
    $metrics = Get-ProjectQualityScore -ProjectPath $Path
    
    Write-Host "  SCORES" -ForegroundColor White
    Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkGray
    Show-ScoreBar -Score $metrics.OverallScore -Label "Overall"
    Show-ScoreBar -Score $metrics.CategoryScores.Structure -Label "Structure"
    Show-ScoreBar -Score $metrics.CategoryScores.Code -Label "Code"
    Show-ScoreBar -Score $metrics.CategoryScores.Quality -Label "Quality"
    Show-ScoreBar -Score $metrics.CategoryScores.Efficiency -Label "Efficiency"
    
    Write-Host ""
    Write-Host "  DETAILS" -ForegroundColor White
    Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkGray
    
    $m = $metrics.Metrics
    Write-OptInfo "File Types: $($m.FileSeparation.Details.TypeCount) ($($m.FileSeparation.Details.FileTypes.Keys -join ', '))"
    Write-OptInfo "Modules: $($m.ModuleCount.Details.Count) files"
    Write-OptInfo "Total Lines: $($m.CodeMetrics.Details.TotalLines)"
    Write-OptInfo "Functions: $($m.CodeMetrics.Details.FunctionCount)"
    Write-OptInfo "Avg Function Length: $($m.CodeMetrics.Details.AvgFunctionLength) lines"
    Write-OptInfo "Test Files: $($m.TestMetrics.Details.TestFileCount)"
    Write-OptInfo "Commits: $($m.Efficiency.Details.Commits)"
    Write-OptInfo "Task Completion: $($m.Efficiency.Details.CompletedTasks)/$($m.Efficiency.Details.TotalTasks)"
    
    return $metrics
}

# ═══════════════════════════════════════════════════════════════
#                    MODE: BASELINE
# ═══════════════════════════════════════════════════════════════

function Invoke-BaselineMode {
    Write-OptHeader "BASELINE EXPERIMENT"
    
    Write-OptInfo "Running baseline experiment with current agents..."
    Write-OptInfo "Max iterations: $MaxIterationsPerExperiment"
    Write-OptInfo "Model: $Model"
    Write-Host ""
    
    $runnerScript = Join-Path $script:LibDir 'runner.ps1'
    $result = & pwsh -File $runnerScript `
        -ExperimentName "baseline" `
        -MaxIterations $MaxIterationsPerExperiment `
        -Model $Model `
        -KeepProject:$KeepProjects
    
    return $result
}

# ═══════════════════════════════════════════════════════════════
#                    MODE: VARIANT
# ═══════════════════════════════════════════════════════════════

function Invoke-VariantMode {
    param([string]$Variant)
    
    Write-OptHeader "VARIANT EXPERIMENT: $Variant"
    
    if (-not $Variant) {
        Write-OptError "Specify variant with -VariantName"
        Write-OptInfo "Available variants:"
        foreach ($v in (Get-AvailableVariants)) {
            $desc = Get-VariantDescription -VariantName $v
            Write-OptInfo "  - ${v}: $desc"
        }
        return
    }
    
    # Create variant directory
    New-Item -ItemType Directory -Path $script:VariantsDir -Force | Out-Null
    $variantPath = Join-Path $script:VariantsDir $Variant
    
    Write-OptInfo "Generating variant: $Variant"
    New-AgentVariant -VariantName $Variant -OutputPath $variantPath | Out-Null
    Write-OptSuccess "Variant created at: $variantPath"
    
    Write-Host ""
    Write-OptInfo "Running experiment..."
    
    $runnerScript = Join-Path $script:LibDir 'runner.ps1'
    $result = & pwsh -File $runnerScript `
        -ExperimentName $Variant `
        -AgentVariantPath $variantPath `
        -MaxIterations $MaxIterationsPerExperiment `
        -Model $Model `
        -KeepProject:$KeepProjects
    
    return $result
}

# ═══════════════════════════════════════════════════════════════
#                    MODE: ANALYZE
# ═══════════════════════════════════════════════════════════════

function Invoke-AnalyzeMode {
    Write-OptHeader "EXPERIMENT ANALYSIS"
    
    $experiments = Get-ExperimentResults
    
    if ($experiments.Count -eq 0) {
        Write-OptWarning "No experiments found. Run some experiments first."
        return
    }
    
    Write-OptInfo "Loaded $($experiments.Count) experiment(s)"
    Write-Host ""
    
    $best = Get-BestExperiment -Experiments $experiments
    $baseline = Get-BaselineExperiment -Experiments $experiments
    
    Write-Host "  EXPERIMENT SUMMARY" -ForegroundColor White
    Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkGray
    
    foreach ($exp in ($experiments | Sort-Object { $_.Metrics.OverallScore } -Descending)) {
        $indicator = ""
        if ($exp.Name -eq $best.Name) { $indicator = " ★ BEST" }
        elseif ($exp.AgentVariant -eq 'baseline') { $indicator = " (baseline)" }
        
        $color = if ($exp.Metrics.OverallScore -ge 80) { 'Green' } 
                 elseif ($exp.Metrics.OverallScore -ge 60) { 'Yellow' }
                 else { 'Red' }
        
        Write-Host "  $($exp.Name.PadRight(20)) " -NoNewline
        Write-Host "$($exp.Metrics.OverallScore.ToString().PadLeft(3))/100" -NoNewline -ForegroundColor $color
        Write-Host $indicator -ForegroundColor Cyan
    }
    
    Write-Host ""
    
    if ($best -and $baseline -and $best.Name -ne $baseline.Name) {
        $comparison = Compare-Experiments -Experiment1 $baseline -Experiment2 $best
        Write-OptSuccess "Improvement over baseline: $($comparison.ImprovementPercent)%"
    }
    
    $weakest = Get-WeakestCategory -Experiment $best
    Write-OptWarning "Weakest category: $($weakest.Name) ($($weakest.Score)/100)"
    
    return $experiments
}

# ═══════════════════════════════════════════════════════════════
#                    MODE: REPORT
# ═══════════════════════════════════════════════════════════════

function Invoke-ReportMode {
    Write-OptHeader "GENERATING REPORT"
    
    $experiments = Get-ExperimentResults
    $report = New-ExperimentReport -Experiments $experiments
    
    $reportPath = Join-Path $script:ResultsDir "report.md"
    $report | Set-Content $reportPath
    
    Write-OptSuccess "Report saved to: $reportPath"
    Write-Host ""
    Write-Host $report
    
    return $reportPath
}

# ═══════════════════════════════════════════════════════════════
#                    MODE: OPTIMIZE
# ═══════════════════════════════════════════════════════════════

function Invoke-OptimizeMode {
    Write-OptHeader "RALPH OPTIMIZATION LOOP"
    
    Write-OptInfo "Max experiments: $MaxExperiments"
    Write-OptInfo "Max iterations per experiment: $MaxIterationsPerExperiment"
    Write-OptInfo "Model: $Model"
    Write-Host ""
    
    $experiments = @()
    $bestScore = 0
    $noImprovementCount = 0
    $convergenceThreshold = 3  # Stop after 3 experiments with no improvement
    
    for ($i = 1; $i -le $MaxExperiments; $i++) {
        Write-OptHeader "OPTIMIZATION ITERATION $i/$MaxExperiments"
        
        if ($i -eq 1) {
            # First run: baseline
            Write-OptInfo "Running baseline experiment..."
            $result = Invoke-BaselineMode
        } else {
            # Subsequent runs: target weakest category
            $allExperiments = Get-ExperimentResults
            $best = Get-BestExperiment -Experiments $allExperiments
            $weakest = Get-WeakestCategory -Experiment $best
            
            Write-OptInfo "Best score so far: $($best.Metrics.OverallScore)/100"
            Write-OptInfo "Targeting weakest category: $($weakest.Name)"
            
            # Create variant targeting weak area
            New-Item -ItemType Directory -Path $script:VariantsDir -Force | Out-Null
            $variantPath = Join-Path $script:VariantsDir "iteration-$i"
            
            New-VariantFromAnalysis `
                -WeakestCategory $weakest.Name `
                -OutputPath $variantPath | Out-Null
            
            Write-OptInfo "Created targeted variant"
            
            # Run experiment
            $runnerScript = Join-Path $script:LibDir 'runner.ps1'
            $result = & pwsh -File $runnerScript `
                -ExperimentName "iteration-$i-$($weakest.Name.ToLower())" `
                -AgentVariantPath $variantPath `
                -MaxIterations $MaxIterationsPerExperiment `
                -Model $Model `
                -KeepProject:$KeepProjects
        }
        
        # Check for improvement
        $allExperiments = Get-ExperimentResults
        $currentBest = Get-BestExperiment -Experiments $allExperiments
        
        if ($currentBest.Metrics.OverallScore -gt $bestScore) {
            $improvement = $currentBest.Metrics.OverallScore - $bestScore
            $bestScore = $currentBest.Metrics.OverallScore
            $noImprovementCount = 0
            Write-OptSuccess "New best score: $bestScore (+$improvement)"
        } else {
            $noImprovementCount++
            Write-OptWarning "No improvement ($noImprovementCount/$convergenceThreshold)"
        }
        
        # Check convergence
        if ($noImprovementCount -ge $convergenceThreshold) {
            Write-OptInfo "Converged - no improvement for $convergenceThreshold experiments"
            break
        }
        
        if ($bestScore -ge 90) {
            Write-OptSuccess "Reached target score (90+)"
            break
        }
    }
    
    # Final report
    Write-OptHeader "OPTIMIZATION COMPLETE"
    
    $allExperiments = Get-ExperimentResults
    $best = Get-BestExperiment -Experiments $allExperiments
    $baseline = Get-BaselineExperiment -Experiments $allExperiments
    
    Write-Host "  FINAL RESULTS" -ForegroundColor White
    Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkGray
    Show-ScoreBar -Score $best.Metrics.OverallScore -Label "Best"
    if ($baseline) {
        Show-ScoreBar -Score $baseline.Metrics.OverallScore -Label "Baseline"
    }
    
    Write-Host ""
    Write-OptInfo "Best configuration: $($best.AgentVariant)"
    Write-OptInfo "Total experiments: $($allExperiments.Count)"
    
    if ($baseline -and $best.Name -ne $baseline.Name) {
        $comparison = Compare-Experiments -Experiment1 $baseline -Experiment2 $best
        Write-OptSuccess "Total improvement: $($comparison.ImprovementPercent)%"
    }
    
    # Generate report
    $reportPath = Invoke-ReportMode
    
    return $best
}

# ═══════════════════════════════════════════════════════════════
#                    MAIN
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║       RALPH OPTIMIZATION FRAMEWORK                        ║" -ForegroundColor Magenta
Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

switch ($Mode) {
    'optimize' { Invoke-OptimizeMode }
    'baseline' { Invoke-BaselineMode }
    'variant'  { Invoke-VariantMode -Variant $VariantName }
    'analyze'  { Invoke-AnalyzeMode }
    'report'   { Invoke-ReportMode }
    'metrics'  { Invoke-MetricsMode -Path $ProjectPath | Out-Null }
}
