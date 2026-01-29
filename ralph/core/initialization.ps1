<#
.SYNOPSIS
    Initialization module for Ralph Loop

.DESCRIPTION
    Provides file and state initialization functions including:
    - Progress file initialization
    - Plan file initialization
    - Ralph instructions setup
    - State reset functionality

.NOTES
    This module is sourced by loop.ps1 and requires:
    - $script:ProgressFile to be defined
    - $script:PlanFile to be defined
    - $script:ProjectRoot to be defined
    - $script:RalphDir to be defined
    - Write-Ralph function to be available
#>

# ═══════════════════════════════════════════════════════════════
#                    FILE INITIALIZATION
# ═══════════════════════════════════════════════════════════════

function Initialize-ProgressFile {
    <#
    .SYNOPSIS
        Creates progress.txt if it doesn't exist
    .DESCRIPTION
        Initializes the progress log file for codebase patterns and notes
        In DRY-RUN mode: Only logs what would be created
    #>
    if (-not $ProgressFile) { return }  # No active task yet
    if (-not (Test-Path $ProgressFile)) {
        # DRY-RUN: Log but don't create
        if (Test-DryRunEnabled) {
            Add-DryRunAction -Type 'File_Write' -Description "Create progress.txt" -Details @{
                File = $ProgressFile
            }
            Write-VerboseOutput "Would create: $ProgressFile" -Category "DryRun"
            return
        }
        
        # Real mode: Create file
        @"
# Ralph Progress Log

## Codebase Patterns
(Add reusable patterns here)

---
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Set-Content $ProgressFile -Encoding UTF8
        Write-Ralph "Created progress.txt" -Type info
    }
}

function Initialize-PlanFile {
    <#
    .SYNOPSIS
        Creates IMPLEMENTATION_PLAN.md if it doesn't exist
    .DESCRIPTION
        Initializes the implementation plan file with empty structure
        In DRY-RUN mode: Only logs what would be created
    #>
    if (-not $PlanFile) { return }  # No active task yet
    if (-not (Test-Path $PlanFile)) {
        # DRY-RUN: Log but don't create
        if (Test-DryRunEnabled) {
            Add-DryRunAction -Type 'File_Write' -Description "Create IMPLEMENTATION_PLAN.md" -Details @{
                File = $PlanFile
            }
            Write-VerboseOutput "Would create: $PlanFile" -Category "DryRun"
            return
        }
        
        # Real mode: Create file
        @"
# Implementation Plan

## Tasks

(No tasks yet - planning phase will populate this)

---
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Set-Content $PlanFile -Encoding UTF8
        Write-Ralph "Created IMPLEMENTATION_PLAN.md" -Type info
    }
}

function Initialize-RalphInstructions {
    <#
    .SYNOPSIS
        Ensures .github/instructions/ralph.instructions.md exists
    .DESCRIPTION
        Creates Ralph instructions file for Copilot CLI if missing.
        Uses template if available, otherwise creates inline.
        In DRY-RUN mode: Only logs what would be created
    #>
    $instructionsDir = Join-Path $script:ProjectRoot '.github\instructions'
    $ralphInstructionsPath = Join-Path $instructionsDir 'ralph.instructions.md'
    
    if (-not (Test-Path $ralphInstructionsPath)) {
        # DRY-RUN: Log but don't create
        if (Test-DryRunEnabled) {
            Add-DryRunAction -Type 'File_Write' -Description "Create .github/instructions/ralph.instructions.md" -Details @{
                File = $ralphInstructionsPath
            }
            Write-VerboseOutput "Would create: $ralphInstructionsPath" -Category "DryRun"
            return
        }
        
        # Real mode: Ensure directories exist
        $githubDir = Join-Path $script:ProjectRoot '.github'
        if (-not (Test-Path $githubDir)) {
            New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
        }
        if (-not (Test-Path $instructionsDir)) {
            New-Item -ItemType Directory -Path $instructionsDir -Force | Out-Null
        }
        
        # Copy from template
        $templatePath = Join-Path $script:RalphDir 'templates\ralph.instructions.md'
        if (Test-Path $templatePath) {
            Copy-Item $templatePath $ralphInstructionsPath
            Write-Ralph "Created .github/instructions/ralph.instructions.md" -Type info
        } else {
            # Create inline if template missing
            @"
---
description: 'Ralph orchestrator instructions - AI coding agent configuration'
applyTo: '**/*'
---

# Ralph Instructions

This project uses Ralph - an autonomous AI coding agent orchestrator.

## Completion Patterns

- ``<promise>COMPLETE</promise>`` - Task completed
- ``<promise>PLANNING_COMPLETE</promise>`` - Planning phase done
- ``<promise>SPEC_CREATED</promise>`` - Specification created

## Task Format

- Pending: ``- [ ] Task description``
- Complete: ``- [x] Task description``
"@ | Set-Content $ralphInstructionsPath -Encoding UTF8
            Write-Ralph "Created .github/instructions/ralph.instructions.md" -Type info
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                     STATE MANAGEMENT
# ═══════════════════════════════════════════════════════════════

function Reset-RalphState {
    <#
    .SYNOPSIS
        Resets Ralph state files for a fresh start
    .DESCRIPTION
        Clears IMPLEMENTATION_PLAN.md and progress.txt while preserving
        their structure. Useful for starting a new task iteration.
    #>
    if (-not $ProgressFile -or -not $PlanFile) {
        Write-Ralph "No active task to reset" -Type warning
        return
    }
    
    Write-Ralph "Resetting Ralph state for fresh start..." -Type info
    
    # Reset progress file
    @"
# Ralph Progress Log

## Codebase Patterns
(Add reusable patterns here)

---
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Set-Content $ProgressFile -Encoding UTF8
    Write-Ralph "Reset progress.txt" -Type info
    
    # Reset plan file
    @"
# Implementation Plan

## Tasks

(No tasks yet - planning phase will populate this)

---
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Set-Content $PlanFile -Encoding UTF8
    Write-Ralph "Reset IMPLEMENTATION_PLAN.md" -Type info
    
    Write-Ralph "State reset complete. Ready for fresh start!" -Type success
}
