<#
.SYNOPSIS
    Reset Ralph state files for a fresh start
    
.DESCRIPTION
    Resets IMPLEMENTATION_PLAN.md and progress.txt to their initial state.
    Use this after creating a new project from the template.
    
.PARAMETER Force
    Skip confirmation prompt
    
.EXAMPLE
    ./ralph/init.ps1
    Reset state files with confirmation
    
.EXAMPLE
    ./ralph/init.ps1 -Force
    Reset state files without confirmation
#>

[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Path resolution - init.ps1 is in ralph/ folder
$RalphDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $RalphDir
$TemplatesDir = Join-Path $RalphDir 'templates'

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  RALPH - INITIALIZE PROJECT" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# File paths - all ralph files in ralph/ folder
$planFile = Join-Path $RalphDir "IMPLEMENTATION_PLAN.md"
$progressFile = Join-Path $RalphDir "progress.txt"
$specsDir = Join-Path $RalphDir "specs"
$instructionsDir = Join-Path $ProjectRoot ".github\instructions"

if (-not $Force) {
    Write-Host "This will reset the following files:" -ForegroundColor Yellow
    Write-Host "  - ralph/IMPLEMENTATION_PLAN.md" -ForegroundColor White
    Write-Host "  - ralph/progress.txt" -ForegroundColor White
    Write-Host ""
    
    # Load menu system for arrow confirmation
    $menusPath = Join-Path $PSScriptRoot 'core\menus.ps1'
    if (Test-Path $menusPath) {
        . $menusPath
        Initialize-MenuSystem -ProjectRoot $ProjectRoot
        
        $confirmed = Show-ArrowConfirm -Message "Continue with reset?" -DefaultYes:$false
        if (-not $confirmed) {
            Write-Host "Cancelled." -ForegroundColor Gray
            exit 0
        }
    } else {
        # Fallback to text-based confirmation
        Write-Host "Continue? (yes/[N]o): " -NoNewline
        $confirm = Read-Host
        if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = 'n' }
        if ($confirm -notmatch "^(y|yes)$") {
            Write-Host "Cancelled." -ForegroundColor Gray
            exit 0
        }
    }
}

# Reset IMPLEMENTATION_PLAN.md
@"
# Implementation Plan

## Overview

Run ``./ralph/ralph.ps1`` to auto-generate tasks from ralph/specs/* and start building.

## Tasks

### High Priority
- [ ] Create feature specifications in ralph/specs/
- [ ] Run Ralph (./ralph/ralph.ps1)

### Medium Priority
(Generated from specs)

### Low Priority
(Generated from specs)

## Completed

(Completed tasks are marked with [x])
"@ | Set-Content $planFile -Encoding UTF8
Write-Host "Reset: IMPLEMENTATION_PLAN.md" -ForegroundColor Green

# Reset progress.txt
@"
# Ralph Progress Log

## Codebase Patterns
(Add reusable patterns here)

---
Initialized: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Set-Content $progressFile -Encoding UTF8
Write-Host "Reset: progress.txt" -ForegroundColor Green

# Ensure specs directory exists
if (-not (Test-Path $specsDir)) {
    New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
    Write-Host "Created: ralph/specs/" -ForegroundColor Green
}

# Create example template if specs is empty
$specFiles = Get-ChildItem -Path $specsDir -Filter "*.md" -ErrorAction SilentlyContinue
$templateFiles = @($specFiles | Where-Object { $_.Name.StartsWith('_') })
$userSpecs = @($specFiles | Where-Object { -not $_.Name.StartsWith('_') })

if ($userSpecs.Count -eq 0 -and $templateFiles.Count -eq 0) {
    # Copy template from ralph/templates/
    $srcTemplate = Join-Path $TemplatesDir "spec.template.md"
    $destTemplate = Join-Path $specsDir "_example.template.md"
    if (Test-Path $srcTemplate) {
        Copy-Item $srcTemplate $destTemplate
        Write-Host "Created: ralph/specs/_example.template.md (template)" -ForegroundColor Green
    }
}

# Ensure .github/instructions/ralph.instructions.md exists
if (-not (Test-Path $instructionsDir)) {
    $githubDir = Join-Path $ProjectRoot ".github"
    if (-not (Test-Path $githubDir)) {
        New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $instructionsDir -Force | Out-Null
}

$ralphInstructionsPath = Join-Path $instructionsDir "ralph.instructions.md"
if (-not (Test-Path $ralphInstructionsPath)) {
    $srcInstructions = Join-Path $TemplatesDir "ralph.instructions.md"
    if (Test-Path $srcInstructions) {
        Copy-Item $srcInstructions $ralphInstructionsPath
        Write-Host "Created: .github/instructions/ralph.instructions.md" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "  PROJECT INITIALIZED!" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Create ralph/specs/*.md with your requirements"
Write-Host "  2. Run: ./ralph/ralph.ps1" -ForegroundColor Cyan
Write-Host "     (Auto-plans if needed, then builds)"
Write-Host ""
Write-Host "Optional: Edit AGENTS.md with your project's build/test commands" -ForegroundColor Gray
Write-Host ""
