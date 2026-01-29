<#
.SYNOPSIS
    Experiment analysis tools for Ralph Optimization Framework

.DESCRIPTION
    Compares experiment results and generates analysis reports.
#>

# ═══════════════════════════════════════════════════════════════
#                    RESULTS LOADING
# ═══════════════════════════════════════════════════════════════

function Get-ExperimentResults {
    <#
    .SYNOPSIS
        Loads all experiment results
    #>
    param([string]$ResultsPath)
    
    if (-not $ResultsPath) {
        $ResultsPath = Join-Path (Split-Path -Parent $PSScriptRoot) "results\experiments.json"
    }
    
    if (-not (Test-Path $ResultsPath)) {
        return @()
    }
    
    return @(Get-Content $ResultsPath -Raw | ConvertFrom-Json)
}

function Get-BestExperiment {
    <#
    .SYNOPSIS
        Returns the experiment with highest overall score
    #>
    param([array]$Experiments)
    
    if ($Experiments.Count -eq 0) { return $null }
    
    return $Experiments | Sort-Object { $_.Metrics.OverallScore } -Descending | Select-Object -First 1
}

function Get-BaselineExperiment {
    <#
    .SYNOPSIS
        Returns the baseline experiment (first one, or one named 'baseline')
    #>
    param([array]$Experiments)
    
    $baseline = $Experiments | Where-Object { $_.Name -eq 'baseline' -or $_.AgentVariant -eq 'baseline' } | Select-Object -First 1
    if ($baseline) { return $baseline }
    
    return $Experiments | Select-Object -First 1
}

# ═══════════════════════════════════════════════════════════════
#                    COMPARISON
# ═══════════════════════════════════════════════════════════════

function Compare-Experiments {
    <#
    .SYNOPSIS
        Compares two experiments and returns delta analysis
    #>
    param(
        [Parameter(Mandatory)]$Experiment1,
        [Parameter(Mandatory)]$Experiment2
    )
    
    $m1 = $Experiment1.Metrics
    $m2 = $Experiment2.Metrics
    
    return @{
        OverallDelta = $m2.OverallScore - $m1.OverallScore
        CategoryDeltas = @{
            Structure = $m2.CategoryScores.Structure - $m1.CategoryScores.Structure
            Code = $m2.CategoryScores.Code - $m1.CategoryScores.Code
            Quality = $m2.CategoryScores.Quality - $m1.CategoryScores.Quality
            Efficiency = $m2.CategoryScores.Efficiency - $m1.CategoryScores.Efficiency
        }
        Improved = ($m2.OverallScore - $m1.OverallScore) -gt 0
        ImprovementPercent = if ($m1.OverallScore -gt 0) {
            [Math]::Round((($m2.OverallScore - $m1.OverallScore) / $m1.OverallScore) * 100, 1)
        } else { 0 }
    }
}

function Get-WeakestCategory {
    <#
    .SYNOPSIS
        Returns the category with lowest score
    #>
    param($Experiment)
    
    $categories = $Experiment.Metrics.CategoryScores
    $weakest = @{
        Name = 'Structure'
        Score = $categories.Structure
    }
    
    if ($categories.Code -lt $weakest.Score) {
        $weakest = @{ Name = 'Code'; Score = $categories.Code }
    }
    if ($categories.Quality -lt $weakest.Score) {
        $weakest = @{ Name = 'Quality'; Score = $categories.Quality }
    }
    if ($categories.Efficiency -lt $weakest.Score) {
        $weakest = @{ Name = 'Efficiency'; Score = $categories.Efficiency }
    }
    
    return $weakest
}

# ═══════════════════════════════════════════════════════════════
#                    REPORT GENERATION
# ═══════════════════════════════════════════════════════════════

function New-ExperimentReport {
    <#
    .SYNOPSIS
        Generates a markdown report of experiment results
    #>
    param([array]$Experiments)
    
    if ($Experiments.Count -eq 0) {
        return "# No Experiments Found`n`nRun experiments first."
    }
    
    $best = Get-BestExperiment -Experiments $Experiments
    $baseline = Get-BaselineExperiment -Experiments $Experiments
    
    $report = @"
# Ralph Optimization Report

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Total Experiments: $($Experiments.Count)

## Summary

| Metric | Best Score | Baseline Score | Delta |
|--------|------------|----------------|-------|
"@
    
    if ($best -and $baseline) {
        $comparison = Compare-Experiments -Experiment1 $baseline -Experiment2 $best
        
        $report += @"

| Overall | $($best.Metrics.OverallScore) | $($baseline.Metrics.OverallScore) | $($comparison.OverallDelta) |
| Structure | $($best.Metrics.CategoryScores.Structure) | $($baseline.Metrics.CategoryScores.Structure) | $($comparison.CategoryDeltas.Structure) |
| Code | $($best.Metrics.CategoryScores.Code) | $($baseline.Metrics.CategoryScores.Code) | $($comparison.CategoryDeltas.Code) |
| Quality | $($best.Metrics.CategoryScores.Quality) | $($baseline.Metrics.CategoryScores.Quality) | $($comparison.CategoryDeltas.Quality) |
| Efficiency | $($best.Metrics.CategoryScores.Efficiency) | $($baseline.Metrics.CategoryScores.Efficiency) | $($comparison.CategoryDeltas.Efficiency) |

## Best Configuration

- **Experiment**: $($best.Name)
- **Agent Variant**: $($best.AgentVariant)
- **Overall Score**: $($best.Metrics.OverallScore)/100
- **Improvement over baseline**: $($comparison.ImprovementPercent)%

"@
    }
    
    $report += @"

## All Experiments

| Name | Variant | Score | Structure | Code | Quality | Efficiency |
|------|---------|-------|-----------|------|---------|------------|
"@
    
    foreach ($exp in ($Experiments | Sort-Object { $_.Metrics.OverallScore } -Descending)) {
        $m = $exp.Metrics
        $report += "| $($exp.Name) | $($exp.AgentVariant) | $($m.OverallScore) | $($m.CategoryScores.Structure) | $($m.CategoryScores.Code) | $($m.CategoryScores.Quality) | $($m.CategoryScores.Efficiency) |`n"
    }
    
    # Add recommendations
    if ($best) {
        $weakest = Get-WeakestCategory -Experiment $best
        $report += @"

## Recommendations

Based on the best experiment, the weakest area is **$($weakest.Name)** (score: $($weakest.Score)).

### Suggested Improvements

"@
        
        switch ($weakest.Name) {
            'Structure' {
                $report += @"
- Add more explicit file separation guidance to agents
- Emphasize creating separate .js/.css/.html files
- Add directory structure examples to planner agent
"@
            }
            'Code' {
                $report += @"
- Add function length guidelines to build agent
- Emphasize code modularity and smaller functions
- Add commenting guidelines
"@
            }
            'Quality' {
                $report += @"
- Add stronger test creation emphasis
- Include test file requirements in task descriptions
- Add test coverage targets to planner
"@
            }
            'Efficiency' {
                $report += @"
- Improve task granularity guidance
- Reduce overlapping tasks in planner
- Add better gap analysis instructions
"@
            }
        }
    }
    
    return $report
}

# Functions are available when dot-sourced
