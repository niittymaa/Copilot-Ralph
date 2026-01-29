<#
.SYNOPSIS
    Quality metrics collection for Ralph Optimization Framework

.DESCRIPTION
    Collects and scores output quality metrics from a Ralph-generated project.
    Used by the optimizer to compare different agent configurations.
#>

# ═══════════════════════════════════════════════════════════════
#                    STRUCTURE METRICS
# ═══════════════════════════════════════════════════════════════

function Get-FileSeparationScore {
    <#
    .SYNOPSIS
        Scores file separation (separate files vs monolithic)
    .PARAMETER ProjectPath
        Path to the project to analyze
    .OUTPUTS
        Score from 0-100
    #>
    param([string]$ProjectPath)
    
    $score = 0
    $extensions = @{}
    
    # Get all source files (exclude .ralph, ralph, .git, node_modules)
    $sourceFiles = Get-ChildItem $ProjectPath -Recurse -File | 
        Where-Object { 
            $_.FullName -notmatch '[\\/](\.ralph|ralph|\.git|node_modules)[\\/]' -and
            $_.Extension -in @('.html', '.htm', '.css', '.js', '.ts', '.jsx', '.tsx', '.py', '.go', '.rs')
        }
    
    foreach ($file in $sourceFiles) {
        $ext = $file.Extension.ToLower()
        if (-not $extensions.ContainsKey($ext)) {
            $extensions[$ext] = 0
        }
        $extensions[$ext]++
    }
    
    # Score based on file type diversity
    $typeCount = $extensions.Keys.Count
    
    if ($typeCount -ge 3) { $score = 100 }      # html + css + js = excellent
    elseif ($typeCount -eq 2) { $score = 70 }   # Two types = good
    elseif ($typeCount -eq 1) { $score = 30 }   # Monolithic = poor
    else { $score = 0 }                          # No source files
    
    # Bonus for separate test files
    $testFiles = Get-ChildItem $ProjectPath -Recurse -File | 
        Where-Object { $_.Name -match '\.(test|spec)\.(js|ts|py)$' -or $_.Name -match '_test\.(go|py)$' }
    
    if ($testFiles.Count -gt 0) {
        $score = [Math]::Min(100, $score + 10)
    }
    
    return @{
        Score = $score
        Details = @{
            FileTypes = $extensions
            TypeCount = $typeCount
            TestFiles = $testFiles.Count
        }
    }
}

function Get-DirectoryStructureScore {
    <#
    .SYNOPSIS
        Scores directory organization
    #>
    param([string]$ProjectPath)
    
    $score = 50  # Base score
    $bonusPatterns = @('src', 'lib', 'tests', 'test', 'public', 'assets', 'components', 'styles', 'css', 'js')
    $foundPatterns = @()
    
    $dirs = Get-ChildItem $ProjectPath -Directory | 
        Where-Object { $_.Name -notmatch '^(\.|ralph|node_modules)' }
    
    foreach ($dir in $dirs) {
        if ($dir.Name.ToLower() -in $bonusPatterns) {
            $foundPatterns += $dir.Name
            $score += 10
        }
    }
    
    $score = [Math]::Min(100, $score)
    
    return @{
        Score = $score
        Details = @{
            Directories = $dirs.Name
            BonusPatterns = $foundPatterns
        }
    }
}

function Get-ModuleCount {
    <#
    .SYNOPSIS
        Counts distinct source code modules
    #>
    param([string]$ProjectPath)
    
    $sourceFiles = Get-ChildItem $ProjectPath -Recurse -File | 
        Where-Object { 
            $_.FullName -notmatch '[\\/](\.ralph|ralph|\.git|node_modules)[\\/]' -and
            $_.Extension -in @('.js', '.ts', '.jsx', '.tsx', '.py', '.go', '.rs', '.cs', '.java')
        }
    
    $count = $sourceFiles.Count
    
    # Score: 0 files = 0, 1 file = 20, 3 files = 60, 5+ files = 100
    $score = switch ($count) {
        0 { 0 }
        1 { 20 }
        2 { 40 }
        3 { 60 }
        4 { 80 }
        default { 100 }
    }
    
    return @{
        Score = $score
        Details = @{
            Count = $count
            Files = $sourceFiles.Name
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                    CODE METRICS
# ═══════════════════════════════════════════════════════════════

function Get-CodeMetrics {
    <#
    .SYNOPSIS
        Analyzes code quality metrics
    #>
    param([string]$ProjectPath)
    
    $totalLines = 0
    $totalCommentLines = 0
    $functionCount = 0
    $functionLengths = @()
    
    $sourceFiles = Get-ChildItem $ProjectPath -Recurse -File | 
        Where-Object { 
            $_.FullName -notmatch '[\\/](\.ralph|ralph|\.git|node_modules)[\\/]' -and
            $_.Extension -in @('.js', '.ts', '.jsx', '.tsx', '.py', '.go', '.html', '.css')
        }
    
    foreach ($file in $sourceFiles) {
        $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        $totalLines += $content.Count
        
        # Count comments (simplified - JS/TS/CSS style)
        foreach ($line in $content) {
            if ($line -match '^\s*(//|/\*|\*|#|<!--)') {
                $totalCommentLines++
            }
        }
        
        # Count functions (simplified regex)
        $fileContent = $content -join "`n"
        $functionMatches = [regex]::Matches($fileContent, '(function\s+\w+|const\s+\w+\s*=\s*(async\s*)?\(|class\s+\w+|def\s+\w+)')
        $functionCount += $functionMatches.Count
    }
    
    # Calculate scores
    $commentRatio = if ($totalLines -gt 0) { $totalCommentLines / $totalLines } else { 0 }
    $avgFunctionLength = if ($functionCount -gt 0) { $totalLines / $functionCount } else { 0 }
    
    # Comment ratio score (ideal: 0.05-0.20)
    $commentScore = switch ($true) {
        ($commentRatio -ge 0.05 -and $commentRatio -le 0.20) { 100; break }
        ($commentRatio -gt 0.20) { 80; break }  # Over-commented
        ($commentRatio -gt 0.02) { 60; break }
        ($commentRatio -gt 0) { 30; break }
        default { 10 }
    }
    
    # Function length score (ideal: 20-30 lines)
    $lengthScore = switch ($true) {
        ($avgFunctionLength -le 30) { 100; break }
        ($avgFunctionLength -le 50) { 80; break }
        ($avgFunctionLength -le 100) { 50; break }
        default { 20 }
    }
    
    return @{
        Score = [int](($commentScore + $lengthScore) / 2)
        Details = @{
            TotalLines = $totalLines
            CommentLines = $totalCommentLines
            CommentRatio = [Math]::Round($commentRatio, 3)
            FunctionCount = $functionCount
            AvgFunctionLength = [Math]::Round($avgFunctionLength, 1)
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                    QUALITY METRICS
# ═══════════════════════════════════════════════════════════════

function Get-TestMetrics {
    <#
    .SYNOPSIS
        Analyzes test coverage
    #>
    param([string]$ProjectPath)
    
    $testFiles = Get-ChildItem $ProjectPath -Recurse -File | 
        Where-Object { 
            $_.Name -match '\.(test|spec)\.(js|ts|py)$' -or 
            $_.Name -match '_test\.(go|py)$' -or
            $_.Name -match '^test_.*\.py$' -or
            $_.FullName -match '[\\/]tests?[\\/]'
        }
    
    $testLines = 0
    foreach ($file in $testFiles) {
        $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
        if ($content) { $testLines += $content.Count }
    }
    
    # Get production code lines
    $prodFiles = Get-ChildItem $ProjectPath -Recurse -File | 
        Where-Object { 
            $_.FullName -notmatch '[\\/](\.ralph|ralph|\.git|node_modules|tests?)[\\/]' -and
            $_.Extension -in @('.js', '.ts', '.py', '.go') -and
            $_.Name -notmatch '\.(test|spec)\.'
        }
    
    $prodLines = 0
    foreach ($file in $prodFiles) {
        $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
        if ($content) { $prodLines += $content.Count }
    }
    
    $testRatio = if ($prodLines -gt 0) { $testLines / $prodLines } else { 0 }
    
    # Test file count score
    $fileScore = switch ($testFiles.Count) {
        0 { 0 }
        1 { 50 }
        2 { 75 }
        default { 100 }
    }
    
    # Test ratio score (ideal: 0.2-0.5)
    $ratioScore = switch ($true) {
        ($testRatio -ge 0.2) { 100; break }
        ($testRatio -ge 0.1) { 70; break }
        ($testRatio -gt 0) { 40; break }
        default { 0 }
    }
    
    return @{
        Score = [int](($fileScore * 0.6) + ($ratioScore * 0.4))
        Details = @{
            TestFileCount = $testFiles.Count
            TestFiles = $testFiles.Name
            TestLines = $testLines
            ProdLines = $prodLines
            TestRatio = [Math]::Round($testRatio, 3)
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                    EFFICIENCY METRICS
# ═══════════════════════════════════════════════════════════════

function Get-EfficiencyMetrics {
    <#
    .SYNOPSIS
        Analyzes iteration efficiency
    #>
    param([string]$ProjectPath)
    
    Push-Location $ProjectPath
    try {
        # Count commits
        $commits = (git log --oneline 2>$null).Count
        
        # Get task stats from implementation plan
        $planPath = Get-ChildItem $ProjectPath -Recurse -Filter "IMPLEMENTATION_PLAN.md" | Select-Object -First 1
        $completedTasks = 0
        $totalTasks = 0
        
        if ($planPath) {
            $planContent = Get-Content $planPath.FullName -Raw
            $completedTasks = ([regex]::Matches($planContent, '- \[x\]')).Count
            $totalTasks = $completedTasks + ([regex]::Matches($planContent, '- \[ \]')).Count
        }
        
        $completionRate = if ($totalTasks -gt 0) { $completedTasks / $totalTasks } else { 0 }
        $iterationsPerTask = if ($completedTasks -gt 0) { $commits / $completedTasks } else { 0 }
        
        # Completion rate score
        $completionScore = [int]($completionRate * 100)
        
        # Iterations per task score (ideal: 1.0-1.5)
        $efficiencyScore = switch ($true) {
            ($iterationsPerTask -eq 0) { 0; break }
            ($iterationsPerTask -le 1.2) { 100; break }
            ($iterationsPerTask -le 1.5) { 80; break }
            ($iterationsPerTask -le 2.0) { 60; break }
            ($iterationsPerTask -le 3.0) { 40; break }
            default { 20 }
        }
        
        return @{
            Score = [int](($completionScore * 0.6) + ($efficiencyScore * 0.4))
            Details = @{
                Commits = $commits
                CompletedTasks = $completedTasks
                TotalTasks = $totalTasks
                CompletionRate = [Math]::Round($completionRate, 2)
                IterationsPerTask = [Math]::Round($iterationsPerTask, 2)
            }
        }
    } finally {
        Pop-Location
    }
}

# ═══════════════════════════════════════════════════════════════
#                    AGGREGATE SCORING
# ═══════════════════════════════════════════════════════════════

function Get-ProjectQualityScore {
    <#
    .SYNOPSIS
        Collects all metrics and calculates weighted quality score
    .PARAMETER ProjectPath
        Path to the project to analyze
    .OUTPUTS
        Hashtable with overall score and detailed breakdown
    #>
    param([string]$ProjectPath)
    
    if (-not (Test-Path $ProjectPath)) {
        throw "Project path does not exist: $ProjectPath"
    }
    
    # Collect all metrics
    $fileSep = Get-FileSeparationScore -ProjectPath $ProjectPath
    $dirStruct = Get-DirectoryStructureScore -ProjectPath $ProjectPath
    $moduleCount = Get-ModuleCount -ProjectPath $ProjectPath
    $codeMetrics = Get-CodeMetrics -ProjectPath $ProjectPath
    $testMetrics = Get-TestMetrics -ProjectPath $ProjectPath
    $efficiency = Get-EfficiencyMetrics -ProjectPath $ProjectPath
    
    # Calculate category scores (0-100)
    $structureScore = [int](($fileSep.Score * 0.4) + ($dirStruct.Score * 0.3) + ($moduleCount.Score * 0.3))
    $codeScore = $codeMetrics.Score
    $qualityScore = $testMetrics.Score
    $efficiencyScore = $efficiency.Score
    
    # Weighted overall score
    $weights = @{
        Structure = 0.40
        Code = 0.30
        Quality = 0.20
        Efficiency = 0.10
    }
    
    $overallScore = [int](
        ($structureScore * $weights.Structure) +
        ($codeScore * $weights.Code) +
        ($qualityScore * $weights.Quality) +
        ($efficiencyScore * $weights.Efficiency)
    )
    
    return @{
        OverallScore = $overallScore
        CategoryScores = @{
            Structure = $structureScore
            Code = $codeScore
            Quality = $qualityScore
            Efficiency = $efficiencyScore
        }
        Metrics = @{
            FileSeparation = $fileSep
            DirectoryStructure = $dirStruct
            ModuleCount = $moduleCount
            CodeMetrics = $codeMetrics
            TestMetrics = $testMetrics
            Efficiency = $efficiency
        }
        Weights = $weights
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
}

# Functions are available when dot-sourced
