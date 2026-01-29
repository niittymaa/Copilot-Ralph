<#
.SYNOPSIS
    Ralph Benchmark Tool - Quick quality assessment using standardized Tetris test

.DESCRIPTION
    Runs a benchmark experiment using the Tetris specification to measure Ralph's 
    code generation quality. Use this to:
    - Test changes to Ralph agents or core logic
    - Compare different model performance
    - Validate optimization improvements

.PARAMETER Model
    AI model to use (default: claude-sonnet-4.5)

.PARAMETER MaxIterations
    Maximum iterations per benchmark run (default: 15)

.PARAMETER KeepProject
    Keep the generated project after benchmark (for inspection)

.PARAMETER Compare
    Compare results with previous benchmark runs

.PARAMETER Quick
    Quick mode with fewer iterations (5) for faster feedback

.EXAMPLE
    .\benchmark.ps1
    Run standard benchmark with defaults

.EXAMPLE
    .\benchmark.ps1 -Model gpt-4.1 -KeepProject
    Benchmark with GPT-4.1 and keep the output

.EXAMPLE
    .\benchmark.ps1 -Quick
    Quick benchmark (5 iterations) for fast feedback

.EXAMPLE
    .\benchmark.ps1 -Compare
    Show comparison of all benchmark runs
#>

param(
    [string]$Model = "claude-sonnet-4.5",
    
    [int]$MaxIterations = 15,
    
    [switch]$KeepProject,
    
    [switch]$Compare,
    
    [switch]$Quick
)

$ErrorActionPreference = 'Stop'

# Setup paths
$script:OptimizerDir = $PSScriptRoot
$script:RalphRoot = Split-Path -Parent $script:OptimizerDir
$script:LibDir = Join-Path $script:OptimizerDir 'lib'
$script:ResultsDir = Join-Path $script:OptimizerDir 'results'
$script:BenchmarkFile = Join-Path $script:ResultsDir 'benchmarks.json'

# Source libraries
. (Join-Path $script:LibDir 'metrics.ps1')

# ═══════════════════════════════════════════════════════════════
#                    DISPLAY HELPERS
# ═══════════════════════════════════════════════════════════════

function Write-BenchHeader {
    param([string]$Text)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-BenchInfo {
    param([string]$Text)
    Write-Host "  $Text" -ForegroundColor White
}

function Write-BenchSuccess {
    param([string]$Text)
    Write-Host "  ✓ $Text" -ForegroundColor Green
}

function Write-BenchWarning {
    param([string]$Text)
    Write-Host "  ⚠ $Text" -ForegroundColor Yellow
}

function Show-ScoreBar {
    param([int]$Score, [string]$Label, [int]$Width = 20)
    
    $filled = [Math]::Floor($Score / (100 / $Width))
    $empty = $Width - $filled
    $bar = ('█' * $filled) + ('░' * $empty)
    $color = if ($Score -ge 80) { 'Green' } elseif ($Score -ge 60) { 'Yellow' } else { 'Red' }
    
    Write-Host "  $($Label.PadRight(12)) " -NoNewline
    Write-Host "$bar" -NoNewline -ForegroundColor $color
    Write-Host " $Score" -ForegroundColor $color
}

function Show-ScoreChange {
    param([int]$Current, [int]$Previous, [string]$Label)
    
    $change = $Current - $Previous
    $changeStr = if ($change -gt 0) { "+$change" } elseif ($change -lt 0) { "$change" } else { "=" }
    $changeColor = if ($change -gt 0) { 'Green' } elseif ($change -lt 0) { 'Red' } else { 'DarkGray' }
    
    Write-Host "  $($Label.PadRight(12)) " -NoNewline
    Write-Host "$Current".PadLeft(3) -NoNewline -ForegroundColor White
    Write-Host " (" -NoNewline -ForegroundColor DarkGray
    Write-Host $changeStr -NoNewline -ForegroundColor $changeColor
    Write-Host ")" -ForegroundColor DarkGray
}

# ═══════════════════════════════════════════════════════════════
#                    BENCHMARK STORAGE
# ═══════════════════════════════════════════════════════════════

function Get-BenchmarkHistory {
    if (-not (Test-Path $script:BenchmarkFile)) {
        return @()
    }
    $content = Get-Content $script:BenchmarkFile -Raw
    if (-not $content) { return @() }
    return @(ConvertFrom-Json $content)
}

function Save-BenchmarkResult {
    param([hashtable]$Result)
    
    New-Item -ItemType Directory -Path $script:ResultsDir -Force | Out-Null
    
    $history = @(Get-BenchmarkHistory)
    $history += [PSCustomObject]$Result
    
    $history | ConvertTo-Json -Depth 10 | Set-Content $script:BenchmarkFile
}

function Get-LastBenchmark {
    $history = Get-BenchmarkHistory
    if ($history.Count -gt 0) {
        return $history[-1]
    }
    return $null
}

# ═══════════════════════════════════════════════════════════════
#                    COMPARE MODE
# ═══════════════════════════════════════════════════════════════

function Show-BenchmarkComparison {
    Write-BenchHeader "BENCHMARK HISTORY"
    
    $history = Get-BenchmarkHistory
    
    if ($history.Count -eq 0) {
        Write-BenchWarning "No benchmark history found. Run a benchmark first."
        return
    }
    
    Write-Host "  #   DATE                 MODEL                  OVERALL  STRUCT   CODE   QUALITY  EFFIC" -ForegroundColor DarkGray
    Write-Host "  ─────────────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    $i = 1
    foreach ($bench in $history) {
        $date = if ($bench.Timestamp) { $bench.Timestamp.Substring(0, 16) } else { "N/A" }
        $model = if ($bench.Model) { $bench.Model.Substring(0, [Math]::Min(20, $bench.Model.Length)) } else { "N/A" }
        
        $overall = if ($bench.Scores.Overall) { $bench.Scores.Overall } else { 0 }
        $struct = if ($bench.Scores.Structure) { $bench.Scores.Structure } else { 0 }
        $code = if ($bench.Scores.Code) { $bench.Scores.Code } else { 0 }
        $quality = if ($bench.Scores.Quality) { $bench.Scores.Quality } else { 0 }
        $effic = if ($bench.Scores.Efficiency) { $bench.Scores.Efficiency } else { 0 }
        
        $overallColor = if ($overall -ge 80) { 'Green' } elseif ($overall -ge 60) { 'Yellow' } else { 'Red' }
        
        Write-Host "  $($i.ToString().PadLeft(2))  " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($date.PadRight(20)) " -NoNewline -ForegroundColor White
        Write-Host "$($model.PadRight(22)) " -NoNewline -ForegroundColor Cyan
        Write-Host "$($overall.ToString().PadLeft(3))" -NoNewline -ForegroundColor $overallColor
        Write-Host "      $($struct.ToString().PadLeft(3))     $($code.ToString().PadLeft(3))      $($quality.ToString().PadLeft(3))     $($effic.ToString().PadLeft(3))" -ForegroundColor Gray
        
        $i++
    }
    
    Write-Host ""
    
    # Show best/worst
    $best = $history | Sort-Object { $_.Scores.Overall } -Descending | Select-Object -First 1
    $worst = $history | Sort-Object { $_.Scores.Overall } | Select-Object -First 1
    
    if ($history.Count -gt 1) {
        Write-Host "  Best:  $($best.Scores.Overall)/100 ($($best.Model))" -ForegroundColor Green
        Write-Host "  Worst: $($worst.Scores.Overall)/100 ($($worst.Model))" -ForegroundColor Red
        Write-Host "  Avg:   $([Math]::Round(($history | Measure-Object { $_.Scores.Overall } -Average).Average))/100" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                    RUN BENCHMARK
# ═══════════════════════════════════════════════════════════════

function Invoke-Benchmark {
    $startTime = Get-Date
    
    # Adjust iterations for quick mode
    $iterations = if ($Quick) { 5 } else { $MaxIterations }
    $modeLabel = if ($Quick) { "QUICK" } else { "STANDARD" }
    
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║            RALPH BENCHMARK - TETRIS TEST                  ║" -ForegroundColor Magenta
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    
    Write-BenchInfo "Mode: $modeLabel ($iterations iterations)"
    Write-BenchInfo "Model: $Model"
    Write-Host ""
    
    # Run the experiment
    $runnerScript = Join-Path $script:LibDir 'runner.ps1'
    $benchmarkName = "benchmark-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    Write-BenchInfo "Starting benchmark..."
    Write-Host ""
    
    $result = & pwsh -File $runnerScript `
        -ExperimentName $benchmarkName `
        -MaxIterations $iterations `
        -Model $Model `
        -KeepProject:$KeepProject
    
    $duration = (Get-Date) - $startTime
    
    # Get the latest experiment result
    $experimentsFile = Join-Path $script:ResultsDir "experiments.json"
    if (-not (Test-Path $experimentsFile)) {
        Write-BenchWarning "No results found"
        return
    }
    
    $experiments = @(Get-Content $experimentsFile -Raw | ConvertFrom-Json)
    $latest = $experiments | Where-Object { $_.Name -eq $benchmarkName } | Select-Object -First 1
    
    if (-not $latest) {
        Write-BenchWarning "Benchmark result not found"
        return
    }
    
    # Extract scores
    $scores = @{
        Overall = $latest.Metrics.OverallScore
        Structure = $latest.Metrics.CategoryScores.Structure
        Code = $latest.Metrics.CategoryScores.Code
        Quality = $latest.Metrics.CategoryScores.Quality
        Efficiency = $latest.Metrics.CategoryScores.Efficiency
    }
    
    # Save benchmark result
    $benchResult = @{
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Model = $Model
        Iterations = $iterations
        Mode = $modeLabel
        DurationMinutes = [Math]::Round($duration.TotalMinutes, 1)
        Scores = $scores
        ProjectPath = if ($KeepProject) { $latest.ProjectPath } else { $null }
    }
    Save-BenchmarkResult -Result $benchResult
    
    # Display results
    Write-BenchHeader "BENCHMARK RESULTS"
    
    Show-ScoreBar -Score $scores.Overall -Label "Overall"
    Show-ScoreBar -Score $scores.Structure -Label "Structure"
    Show-ScoreBar -Score $scores.Code -Label "Code"
    Show-ScoreBar -Score $scores.Quality -Label "Quality"
    Show-ScoreBar -Score $scores.Efficiency -Label "Efficiency"
    
    Write-Host ""
    Write-BenchInfo "Duration: $([Math]::Round($duration.TotalMinutes, 1)) minutes"
    Write-BenchInfo "Iterations: $iterations"
    
    # Compare with previous benchmark
    $history = Get-BenchmarkHistory
    if ($history.Count -gt 1) {
        $previous = $history[-2]  # Second to last (last is current)
        
        Write-Host ""
        Write-Host "  CHANGE FROM PREVIOUS" -ForegroundColor White
        Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkGray
        
        Show-ScoreChange -Current $scores.Overall -Previous $previous.Scores.Overall -Label "Overall"
        Show-ScoreChange -Current $scores.Structure -Previous $previous.Scores.Structure -Label "Structure"
        Show-ScoreChange -Current $scores.Code -Previous $previous.Scores.Code -Label "Code"
        Show-ScoreChange -Current $scores.Quality -Previous $previous.Scores.Quality -Label "Quality"
        Show-ScoreChange -Current $scores.Efficiency -Previous $previous.Scores.Efficiency -Label "Efficiency"
    }
    
    Write-Host ""
    
    # Grade
    $grade = switch ($scores.Overall) {
        { $_ -ge 90 } { "A+ (Excellent)" }
        { $_ -ge 80 } { "A  (Great)" }
        { $_ -ge 70 } { "B  (Good)" }
        { $_ -ge 60 } { "C  (Acceptable)" }
        { $_ -ge 50 } { "D  (Needs Work)" }
        default { "F  (Poor)" }
    }
    
    $gradeColor = switch ($scores.Overall) {
        { $_ -ge 80 } { 'Green' }
        { $_ -ge 60 } { 'Yellow' }
        default { 'Red' }
    }
    
    Write-Host "  GRADE: " -NoNewline -ForegroundColor White
    Write-Host $grade -ForegroundColor $gradeColor
    Write-Host ""
    
    if ($KeepProject) {
        Write-BenchSuccess "Project saved: $($latest.ProjectPath)"
    }
    
    return $benchResult
}

# ═══════════════════════════════════════════════════════════════
#                    MAIN
# ═══════════════════════════════════════════════════════════════

if ($Compare) {
    Show-BenchmarkComparison
} else {
    Invoke-Benchmark
}
