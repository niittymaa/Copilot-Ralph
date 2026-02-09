<#
.SYNOPSIS
    Ralph Loop - Autonomous AI coding agent orchestrator

.DESCRIPTION
    Runs GitHub Copilot CLI in a continuous loop, executing tasks from IMPLEMENTATION_PLAN.md.
    
    Auto-detects when planning is needed:
    - If no plan exists or plan has no tasks → runs planning first
    - Then proceeds to build mode automatically
    
    Uses `copilot -p` programmatic mode with custom agents in .github/agents/

.PARAMETER Mode
    Operation mode: 'auto' (default), 'plan', 'build', 'agents', or 'continue'
    - auto: Updates AGENTS.md, plans if needed, then builds (recommended for new projects)
    - continue: Continue existing project - shows spec menu to use existing or add new specs
    - plan: Only run planning, don't build
    - build: Only run building, skip planning
    - agents: Only update AGENTS.md from codebase analysis

.PARAMETER MaxIterations
    Maximum build iterations. Default: 0 (unlimited/infinite until all tasks complete)

.PARAMETER Delegate
    Hand off to Copilot coding agent (background execution)

.PARAMETER Manual
    Display prompts for copy/paste to Copilot Chat

.PARAMETER AutoStart
    Skip interactive menus and start immediately. Used for automation/optimization.
    Requires -Task to be specified with a valid task ID that has specs configured.

.PARAMETER Model
    AI model to use (e.g., 'claude-sonnet-4', 'gpt-4.1', 'claude-sonnet-4.5')
    If not specified, uses Copilot CLI default model

.PARAMETER Venv
    Python venv handling: 'auto' (default), 'skip', or 'reset'
    - auto: Create venv if needed, activate for all operations
    - skip: Don't use venv isolation
    - reset: Remove and recreate venv before running
#>

[CmdletBinding()]
param(
    [ValidateSet('auto', 'plan', 'build', 'agents', 'continue', 'sessions')]
    [string]$Mode = 'auto',
    
    [string]$Model = '',
    
    [int]$MaxIterations = 0,
    
    [string]$Agent = '',
    
    [switch]$Delegate,
    
    [switch]$Manual,
    
    [switch]$AutoStart,
    
    [switch]$ShowVerbose,
    
    [ValidateSet('auto', 'always', 'disabled', 'reset')]
    [string]$Venv = 'auto',
    
    [string]$Task = '',
    
    [ValidateSet('on', 'off', '')]
    [string]$Memory = '',
    
    [switch]$DryRun,
    
    [bool]$DeveloperMode = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# Path resolution:
# - CoreDir = ralph/core (where this script lives)
# - RalphDir = ralph (parent of core)
# - ProjectRoot = parent of ralph
$script:CoreDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RalphDir = Split-Path -Parent $script:CoreDir
$script:ProjectRoot = Split-Path -Parent $script:RalphDir
$script:AgentsDir = Join-Path $script:ProjectRoot '.github\agents'
$script:Iteration = 0
$script:SessionStart = Get-Date

# Retry configuration for network/transient errors
$script:RetryMaxAttempts = 3
$script:RetryDelaySeconds = 5
$script:RetryBackoffMultiplier = 2

# File paths - all ralph files in ralph/ folder
$script:PlanFile = Join-Path $script:RalphDir 'IMPLEMENTATION_PLAN.md'
$script:ProgressFile = Join-Path $script:RalphDir 'progress.txt'
$script:SpecsDir = Join-Path $script:RalphDir 'specs'

# Agent files (in .github/agents for Copilot CLI compatibility)
$script:AgentFiles = @{
    Build          = Join-Path $script:AgentsDir 'ralph.agent.md'
    Plan           = Join-Path $script:AgentsDir 'ralph-planner.agent.md'
    SpecCreator    = Join-Path $script:AgentsDir 'ralph-spec-creator.agent.md'
    AgentsUpdater  = Join-Path $script:AgentsDir 'ralph-agents-updater.agent.md'
}

# Completion signals
$script:Signals = @{
    Complete       = '<promise>COMPLETE</promise>'
    PlanDone       = '<promise>PLANNING_COMPLETE</promise>'
    SpecCreated    = '<promise>SPEC_CREATED</promise>'
    AgentsUpdated  = '<promise>AGENTS_UPDATED</promise>'
}

# Session statistics tracking
$script:SessionStats = @{
    CopilotCalls = @{
        Total           = 0
        Successful      = 0
        Failed          = 0
        Cancelled       = 0
        TotalDuration   = [TimeSpan]::Zero
        Phases          = @{
            AgentsUpdate = @{ Count = 0; Duration = [TimeSpan]::Zero }
            Planning     = @{ Count = 0; Duration = [TimeSpan]::Zero }
            Building     = @{ Count = 0; Duration = [TimeSpan]::Zero }
            SpecCreation = @{ Count = 0; Duration = [TimeSpan]::Zero }
        }
    }
    Files = @{
        CreatedCount  = 0
        ModifiedCount = 0
        DeletedCount  = 0
        Created       = @()
        Modified      = @()
        Deleted       = @()
        LinesAdded    = 0
        LinesRemoved  = 0
    }
    InitialGitStatus = $null
    InitialCommitSha = $null
}

# ═══════════════════════════════════════════════════════════════
#                     MODULE INITIALIZATION
# ═══════════════════════════════════════════════════════════════

# Source the path utilities module FIRST (many modules need path normalization)
$pathutilsScript = Join-Path $script:CoreDir 'pathutils.ps1'
if (Test-Path $pathutilsScript) {
    . $pathutilsScript
}

# Source the venv module
$venvScript = Join-Path $script:CoreDir 'venv.ps1'
if (Test-Path $venvScript) {
    . $venvScript
    Initialize-VenvPaths -ProjectRoot $script:ProjectRoot
}

# Source the spinner module
$spinnerScript = Join-Path $script:CoreDir 'spinner.ps1'
if (Test-Path $spinnerScript) {
    . $spinnerScript
}

# Source the interrupt handler module (for loop interrupt control)
$interruptHandlerScript = Join-Path $script:RalphDir 'cli\ps\interruptHandler.ps1'
if (Test-Path $interruptHandlerScript) {
    . $interruptHandlerScript
}

# Source the menus module FIRST (other modules depend on it)
$menusScript = Join-Path $script:CoreDir 'menus.ps1'
if (Test-Path $menusScript) {
    . $menusScript
    Initialize-MenuSystem -ProjectRoot $script:ProjectRoot
}

# Source the dry-run module EARLY (many functions will check it)
$dryrunScript = Join-Path $script:CoreDir 'dryrun.ps1'
if (Test-Path $dryrunScript) {
    . $dryrunScript
}

# Enable dry-run mode if parameter was passed
if ($DryRun) {
    Enable-DryRun
    # Dry-run indicator will be shown in menu headers automatically
}

# Source the GitHub auth module for account display/switching
$githubauthScript = Join-Path $script:CoreDir 'github-auth.ps1'
if (Test-Path $githubauthScript) {
    . $githubauthScript
}

# Source the presets module (before tasks, as tasks can use presets)
$presetsScript = Join-Path $script:CoreDir 'presets.ps1'
if (Test-Path $presetsScript) {
    . $presetsScript
    Initialize-PresetPaths -ProjectRoot $script:ProjectRoot
}

# Source the boilerplate wizard module
$boilerplateScript = Join-Path $script:CoreDir 'boilerplate.ps1'
if (Test-Path $boilerplateScript) {
    . $boilerplateScript
    Initialize-BoilerplateWizard -ProjectRoot $script:ProjectRoot
}

# Source the tasks module for multi-task support
$tasksScript = Join-Path $script:CoreDir 'tasks.ps1'
if (Test-Path $tasksScript) {
    . $tasksScript
    Initialize-TaskPaths -ProjectRoot $script:ProjectRoot
    Initialize-TaskSystem
    
    # If Task parameter is provided, switch to that task
    if ($Task -and (Test-TaskExists -TaskId $Task)) {
        Set-ActiveTask -TaskId $Task
    }
}

# Source the memory module for cross-session learnings
$memoryScript = Join-Path $script:CoreDir 'memory.ps1'
if (Test-Path $memoryScript) {
    . $memoryScript
    Initialize-MemorySystem -ProjectRoot $script:ProjectRoot
    
    # Handle Memory parameter if passed
    if ($Memory -eq 'on') {
        Set-MemoryEnabled -Enabled $true
    } elseif ($Memory -eq 'off') {
        Set-MemoryEnabled -Enabled $false
    }
}

# Import statistics module
$statisticsScript = Join-Path $script:CoreDir 'statistics.ps1'
if (Test-Path $statisticsScript) {
    . $statisticsScript
}

# Source the update module for Ralph self-updates
$updateScript = Join-Path $script:CoreDir 'update.ps1'
if (Test-Path $updateScript) {
    . $updateScript
}

# Import display module
$displayScript = Join-Path $script:CoreDir 'display.ps1'
if (Test-Path $displayScript) {
    . $displayScript
}

# Import logging module for file-based logging
$loggingScript = Join-Path $script:CoreDir 'logging.ps1'
if (Test-Path $loggingScript) {
    . $loggingScript
    # Initialize with DEBUG level for comprehensive logging during development
    Initialize-Logging -ProjectRoot $script:ProjectRoot -LogLevel 'DEBUG'
}

# Import error handling module
$errorsScript = Join-Path $script:CoreDir 'errors.ps1'
if (Test-Path $errorsScript) {
    . $errorsScript
}

# Import checkpoint module
$checkpointScript = Join-Path $script:CoreDir 'checkpoint.ps1'
if (Test-Path $checkpointScript) {
    . $checkpointScript
}

# Import recovery module
$recoveryScript = Join-Path $script:CoreDir 'recovery.ps1'
if (Test-Path $recoveryScript) {
    . $recoveryScript
}

# Import initialization module
$initializationScript = Join-Path $script:CoreDir 'initialization.ps1'
if (Test-Path $initializationScript) {
    . $initializationScript
}

# Import specs module
$specsScript = Join-Path $script:CoreDir 'specs.ps1'
if (Test-Path $specsScript) {
    . $specsScript
}

# Import references module for multi-source file handling
$referencesScript = Join-Path $script:CoreDir 'references.ps1'
if (Test-Path $referencesScript) {
    . $referencesScript
    Initialize-ReferencePaths -ProjectRoot $script:ProjectRoot -RalphDir $script:RalphDir
}

# Function to update file paths based on active task
function Update-TaskContext {
    <#
    .SYNOPSIS
        Updates script-level file paths based on the currently active task
    .DESCRIPTION
        If no task is active, paths are set to $null (requiring task creation)
        In dry-run mode with simulated session, creates temporary paths for demonstration
    #>
    param(
        [string]$TaskId = ''
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    $script:CurrentTaskId = $TaskId
    
    if ($TaskId) {
        # Check if this is a dry-run simulated session
        if ($TaskId -eq "[DRY-RUN-SIMULATED-SESSION]" -or $TaskId.StartsWith("[DRY")) {
            # In dry-run mode with simulated session, use project-level specs for demo
            $script:PlanFile = Join-Path $script:ProjectRoot 'IMPLEMENTATION_PLAN.md'
            $script:ProgressFile = Join-Path $script:ProjectRoot 'progress.txt'
            $script:SpecsDir = Join-Path $script:ProjectRoot 'specs'
        } else {
            $taskDir = Get-TaskDirectory -TaskId $TaskId
            $taskProjectRoot = Split-Path -Parent (Split-Path -Parent $taskDir) # Get project root from .ralph/tasks/taskid
            
            $script:PlanFile = Get-TaskPlanFile -TaskId $TaskId
            $script:ProgressFile = Get-TaskProgressFile -TaskId $TaskId
            $script:SpecsDir = Get-TaskSpecsDir -TaskId $TaskId
            
            # Re-initialize reference paths for this task's project
            # Note: RalphDir (.ralph) is internal, references go in ralph/ (user folder)
            if (Get-Command Initialize-ReferencePaths -ErrorAction SilentlyContinue) {
                Initialize-ReferencePaths -ProjectRoot $taskProjectRoot
            }
        }
    } else {
        # No active task - paths are null (will require session creation)
        $script:PlanFile = $null
        $script:ProgressFile = $null
        $script:SpecsDir = $null
    }
}

# Initialize task context (sets file paths based on active task)
Update-TaskContext

# Verbose mode flag - use ShowVerbose parameter
$script:VerboseMode = $ShowVerbose.IsPresent
$script:DeveloperMode = $DeveloperMode

# Effective max iterations (set during build phase)
$script:EffectiveMaxIterations = 0

# ═══════════════════════════════════════════════════════════════
#                         UTILITIES
# ═══════════════════════════════════════════════════════════════

# Available models with their multipliers
$script:AvailableModels = @(
    @{ Name = 'claude-sonnet-4.5'; Display = 'Claude Sonnet 4.5'; Multiplier = '1x'; Default = $true }
    @{ Name = 'claude-haiku-4.5'; Display = 'Claude Haiku 4.5'; Multiplier = '0.33x'; Default = $false }
    @{ Name = 'claude-opus-4.6'; Display = 'Claude Opus 4.6'; Multiplier = '3x'; Default = $false }
    @{ Name = 'claude-opus-4.6-fast'; Display = 'Claude Opus 4.6 (fast)'; Multiplier = '3x'; Default = $false }
    @{ Name = 'claude-opus-4.5'; Display = 'Claude Opus 4.5'; Multiplier = '3x'; Default = $false }
    @{ Name = 'claude-sonnet-4'; Display = 'Claude Sonnet 4'; Multiplier = '1x'; Default = $false }
    @{ Name = 'gpt-5.2-codex'; Display = 'GPT-5.2-Codex'; Multiplier = '1x'; Default = $false }
    @{ Name = 'gpt-5.1-codex-max'; Display = 'GPT-5.1-Codex-Max'; Multiplier = '1x'; Default = $false }
    @{ Name = 'gpt-5.1-codex'; Display = 'GPT-5.1-Codex'; Multiplier = '1x'; Default = $false }
    @{ Name = 'gpt-5.2'; Display = 'GPT-5.2'; Multiplier = '1x'; Default = $false }
    @{ Name = 'gpt-5.1'; Display = 'GPT-5.1'; Multiplier = '1x'; Default = $false }
    @{ Name = 'gpt-5'; Display = 'GPT-5'; Multiplier = '1x'; Default = $false }
    @{ Name = 'gpt-5.1-codex-mini'; Display = 'GPT-5.1-Codex-Mini'; Multiplier = '0.33x'; Default = $false }
    @{ Name = 'gpt-5-mini'; Display = 'GPT-5 mini'; Multiplier = '0x'; Default = $false }
    @{ Name = 'gpt-4.1'; Display = 'GPT-4.1'; Multiplier = '0x'; Default = $false }
    @{ Name = 'gemini-3-pro-preview'; Display = 'Gemini 3 Pro (Preview)'; Multiplier = '1x'; Default = $false }
)

# Default model for Ralph
$script:DefaultModel = 'claude-sonnet-4.5'

function Show-ModelMenu {
    # Uses the new menu system for model selection
    Clear-HostConditional
    
    $currentModel = if ($script:Model) { $script:Model } else { $script:DefaultModel }
    
    return Show-ModelSelectionMenu -Models $AvailableModels -CurrentModel $currentModel
}

# Show-ConfigurationMenu removed - replaced with Home menu navigation
# Old function was here at lines 333-365


function Show-IterationPrompt {
    <#
    .SYNOPSIS
        Prompts user to confirm iteration settings before building.
        Returns the number of iterations (0 = unlimited).
        Now uses arrow navigation menu.
    #>
    param(
        [int]$CurrentMax = 0,
        [int]$PendingTasks = 0
    )
    
    # Use the centralized arrow navigation menu
    return Show-IterationMenu -PendingTasks $PendingTasks -CurrentMax $CurrentMax
}

function Test-CopilotCLI {
    # Auto-detect dry-run mode
    if (Test-DryRunEnabled) {
        return Test-CopilotCLIDryRun
    }
    
    try {
        $version = copilot --version 2>$null
        if ($version) {
            Write-Ralph "Copilot CLI: $version" -Type info
            return $true
        }
    } catch {}
    
    Write-Ralph "Copilot CLI not found. Install: npm install -g @github/copilot" -Type error
    return $false
}

function Get-CurrentBranch {
    try {
        return git branch --show-current 2>$null
    } catch {
        return "unknown"
    }
}

function Get-TaskStats {
    if (-not $PlanFile -or -not (Test-Path $PlanFile)) {
        return @{ Total = 0; Completed = 0; Pending = 0 }
    }
    
    $content = Get-Content $PlanFile -Raw
    $pending = ([regex]::Matches($content, '- \[ \]')).Count
    $completed = ([regex]::Matches($content, '- \[x\]')).Count
    
    return @{
        Total     = $pending + $completed
        Completed = $completed
        Pending   = $pending
    }
}

# ═══════════════════════════════════════════════════════════════
#                    COPILOT CLI INTEGRATION
# ═══════════════════════════════════════════════════════════════

function Get-AgentPrompt {
    param([string]$AgentPath)
    
    if (-not (Test-Path $AgentPath)) {
        Write-Ralph "Agent file not found: $AgentPath" -Type error
        return $null
    }
    
    Write-VerboseOutput "Loading agent: $AgentPath" -Category "Agent"
    
    $content = Get-Content $AgentPath -Raw
    
    # Strip YAML frontmatter if present
    if ($content -match '(?s)^---\s*\n.*?\n---\s*\n(.*)$') {
        $prompt = $Matches[1].Trim()
    } else {
        $prompt = $content.Trim()
    }
    
    Write-VerboseOutput "Prompt length: $($prompt.Length) chars" -Category "Agent"
    return $prompt
}

function Build-TaskPrompt {
    <#
    .SYNOPSIS
        Builds a complete prompt with task injection for the build agent.
    .DESCRIPTION
        Combines the base agent prompt with the specific task to work on,
        ensuring the AI focuses only on the assigned task.
        Also includes reference materials if configured.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$BasePrompt,
        
        [Parameter(Mandatory)]
        [string]$Task
    )
    
    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($BasePrompt)) {
        Write-Ralph "Error: Base prompt is empty" -Type error
        return $null
    }
    
    if ([string]::IsNullOrWhiteSpace($Task)) {
        Write-Ralph "Error: Task is empty" -Type error
        return $null
    }
    
    # Load references for the current task context
    $referenceSection = ""
    $activeTaskId = $null
    if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
        $activeTaskId = Get-ActiveTaskId
    }
    if ($activeTaskId -and (Get-Command Load-SessionReferences -ErrorAction SilentlyContinue)) {
        Load-SessionReferences -TaskId $activeTaskId | Out-Null
    }
    
    $allRefs = @()
    if (Get-Command Get-AllSessionReferences -ErrorAction SilentlyContinue) {
        $allRefs = @(Get-AllSessionReferences)
    }
    
    if ($allRefs.Count -gt 0 -and (Get-Command Build-ReferenceAnalysisPrompt -ErrorAction SilentlyContinue)) {
        $referencePrompt = Build-ReferenceAnalysisPrompt -References $allRefs
        
        # Categorize for informational logging
        $imageRefs = @($allRefs | Where-Object { $_.IsImage })
        $textRefs = @($allRefs | Where-Object { -not $_.IsImage })
        
        if ($imageRefs.Count -gt 0 -or $textRefs.Count -gt 0) {
            Write-VerboseOutput "Including $($allRefs.Count) reference file(s) in task prompt" -Category "References"
        }
        
        $referenceSection = @"

## REFERENCE MATERIALS (USE AS SOURCE OF TRUTH)

The user has provided reference materials. These define how the result should look and work.
**References are the visual contract** - your implementation should match them.

$referencePrompt

## HOW TO USE REFERENCES

1. **Image mockups/wireframes**: These show the EXACT layout, styling, and components to implement
   - Match the visual structure precisely
   - Include all components visible in the mockup
   - Use the styling (colors, spacing, typography) shown
   - If the mockup shows a button, implement that button

2. **Text/documentation references**: These provide technical details and constraints
   - Follow specifications exactly
   - Implement features as described

3. **For your current task**: Check if any reference applies to what you're building
   - If implementing UI: Look at mockups for exact layout
   - If implementing features: Check documentation for requirements

**CRITICAL**: The user provided these references because they want the result to MATCH them.
Don't improvise when a reference shows exactly what to build.

"@
    }
    
    # Build the combined prompt with task injection and references
    $taskPrompt = @"
$BasePrompt
$referenceSection
## YOUR ASSIGNED TASK FOR THIS ITERATION

**DO NOT search for tasks in IMPLEMENTATION_PLAN.md.** Your task has already been selected for you:

``````
$Task
``````

Focus ONLY on implementing this specific task. When complete, mark it as done in the plan and update progress.txt.
"@
    
    Write-VerboseOutput "Task prompt built: $($taskPrompt.Length) chars (task: $($Task.Substring(0, [Math]::Min(50, $Task.Length)))...)" -Category "Agent"
    return $taskPrompt
}

function Test-TransientErrorLegacy {
    <#
    .SYNOPSIS
        Determines if an error is transient and should be retried (legacy fallback)
    #>
    param([string]$ErrorMessage)
    
    $transientPatterns = @(
        'network',
        'connection',
        'timeout',
        'temporarily unavailable',
        'service unavailable',
        'socket',
        'dns',
        'host not found',
        'unable to connect',
        'connection refused',
        'network unreachable',
        'ECONNRESET',
        'ETIMEDOUT',
        'ENOTFOUND',
        'rate limit',
        '429',
        '502',
        '503',
        '504'
    )
    
    foreach ($pattern in $transientPatterns) {
        if ($ErrorMessage -match $pattern) {
            return $true
        }
    }
    return $false
}

function Invoke-Copilot {
    param(
        [string]$Prompt,
        [switch]$AllowAllTools,
        [string]$SpinnerMessage = "Copilot working... (V=verbose)",
        [string]$Phase = 'building',
        [int]$Iteration = 0,
        [string]$CurrentTask = ''
    )
    
    # AUTO-DETECT DRY-RUN MODE - redirect to mock function
    if (Test-DryRunEnabled) {
        return Invoke-CopilotDryRun -Prompt $Prompt -AllowAllTools:$AllowAllTools -SpinnerMessage $SpinnerMessage
    }
    
    # Retry loop for transient errors (network issues, rate limits, etc.)
    $attempt = 0
    $delay = $script:RetryDelaySeconds
    
    while ($attempt -lt $script:RetryMaxAttempts) {
        $attempt++
        $result = Invoke-CopilotInternal -Prompt $Prompt -AllowAllTools:$AllowAllTools -SpinnerMessage $SpinnerMessage
        
        # If successful or cancelled, return immediately
        if ($result.Success -or $result.Cancelled) {
            return $result
        }
        
        # Use new error classification system if available
        if (Get-Command Get-ErrorClassification -ErrorAction SilentlyContinue) {
            # Guard against empty output (e.g. Copilot crash with no stderr)
            $errorMsg = if ([string]::IsNullOrWhiteSpace($result.Output)) { "Copilot exited with code $($result.ExitCode) and no output" } else { $result.Output }
            $errorInfo = Get-ErrorClassification -ErrorMessage $errorMsg
            
            # Fatal errors - stop immediately, return to menu
            # NOTE: Do NOT save checkpoint here - checkpoint is saved AFTER successful iterations
            # The last valid checkpoint already exists from the previous completed iteration
            if ($errorInfo.Type -eq 'Fatal') {
                # Log the fatal error
                if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                    Write-Log -Tag 'ERROR' -Message "Fatal error: $($errorInfo.Message) - $($errorInfo.OriginalMessage)"
                }
                
                # Display user-friendly error
                if (Get-Command Show-RalphError -ErrorAction SilentlyContinue) {
                    Show-RalphError -ErrorInfo $errorInfo -ShowResume:$errorInfo.CanResume
                }
                
                # Mark result with fatal flag
                $result.FatalError = $true
                $result.ErrorInfo = $errorInfo
                return $result
            }
            
            # Critical errors - also stop but may be resumable after service recovers
            # NOTE: Do NOT save checkpoint here - last completed checkpoint is already valid
            if ($errorInfo.Type -eq 'Critical') {
                # Log the critical error
                if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                    Write-Log -Tag 'ERROR' -Message "Critical error: $($errorInfo.Message) - $($errorInfo.OriginalMessage)"
                }
                
                # Display user-friendly error
                if (Get-Command Show-RalphError -ErrorAction SilentlyContinue) {
                    Show-RalphError -ErrorInfo $errorInfo -ShowResume:$errorInfo.CanResume
                }
                
                # Mark result with critical flag
                $result.CriticalError = $true
                $result.ErrorInfo = $errorInfo
                return $result
            }
            
            # Transient error - retry if we have attempts left
            if ($errorInfo.Type -eq 'Transient' -and $attempt -lt $script:RetryMaxAttempts) {
                $retryDelay = if ($errorInfo.RetryAfter) { $errorInfo.RetryAfter } else { $delay }
                Write-Ralph "Transient error (attempt $attempt/$($script:RetryMaxAttempts)): $($errorInfo.Message)" -Type warning
                Write-Ralph "Retrying in $retryDelay seconds..." -Type info
                Start-Sleep -Seconds $retryDelay
                $delay = $delay * $script:RetryBackoffMultiplier
                continue
            }
        } else {
            # Fallback to old transient error check
            if (-not (Test-TransientErrorLegacy -ErrorMessage $result.Output)) {
                return $result
            }
            
            # Transient error - retry if we have attempts left
            if ($attempt -lt $script:RetryMaxAttempts) {
                Write-Ralph "Transient error detected (attempt $attempt/$($script:RetryMaxAttempts)): $($result.Output)" -Type warning
                Write-Ralph "Retrying in $delay seconds..." -Type info
                Start-Sleep -Seconds $delay
                $delay = $delay * $script:RetryBackoffMultiplier
                continue
            }
        }
        
        # If we're here, either not transient or retries exhausted
        break
    }
    
    # All retries exhausted
    Write-Ralph "All $($script:RetryMaxAttempts) retry attempts exhausted" -Type error
    return $result
}

function Invoke-CopilotInternal {
    param(
        [string]$Prompt,
        [switch]$AllowAllTools,
        [string]$SpinnerMessage = "Copilot working... (V=verbose)"
    )
    
    $currentModel = $script:Model
    $modelInfo = if ($currentModel) { " (model: $currentModel)" } else { "" }
    $promptLength = $Prompt.Length
    
    Write-VerboseOutput "Prompt preview: $($Prompt.Substring(0, [Math]::Min(100, $Prompt.Length)))..." -Category "Copilot"
    Write-VerboseOutput "AllowAllTools: $($AllowAllTools.IsPresent)" -Category "Copilot"
    Write-VerboseOutput "Prompt length: $promptLength chars" -Category "Copilot"
    
    # Log Copilot call start
    if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
        Write-LogCopilotCall -Action START -Model $currentModel -PromptLength $promptLength
    }
    
    $cliArgs = @('-p', $Prompt)
    if ($AllowAllTools) {
        $cliArgs += '--allow-all-tools'
    }
    if ($currentModel) {
        $cliArgs += @('--model', $currentModel)
    }
    
    if ($script:VerboseMode) {
        Write-Ralph "Invoking Copilot CLI$modelInfo..." -Type info
    }
    
    $startTime = Get-Date
    
    # Execute Copilot CLI - let it run as long as it needs
    if ($script:VerboseMode) {
        # Verbose mode: stream output to console in real-time using Start-Process (avoids Job encoding issues)
        Write-Host "  ┌─ Copilot CLI Output ──────────────────────────────" -ForegroundColor DarkCyan
        Write-Host "  │ (ESC=interrupt menu, Ctrl+C×2=exit, V=toggle verbose)" -ForegroundColor DarkGray
        
        # Create temp directory for prompt file
        $tempDir = Join-Path $env:TEMP "ralph-copilot"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        $promptFile = Join-Path $tempDir "prompt-$([guid]::NewGuid().ToString('N').Substring(0,8)).txt"
        
        try {
            # Write prompt to temp file to avoid command line length issues
            $Prompt | Out-File -FilePath $promptFile -Encoding UTF8 -NoNewline
            
            # Build copilot command
            $copilotCmd = "copilot -p '@$promptFile'"
            if ($AllowAllTools) {
                $copilotCmd += ' --allow-all-tools'
            }
            if ($currentModel) {
                $copilotCmd += " --model $currentModel"
            }
            
            # Start copilot through powershell.exe with redirected output
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "powershell.exe"
            $processInfo.Arguments = "-ExecutionPolicy Bypass -NoProfile -Command `"& $copilotCmd`""
            $processInfo.UseShellExecute = $false
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.CreateNoWindow = $true
            $processInfo.WorkingDirectory = (Get-Location).Path
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            
            # Start the process
            $process.Start() | Out-Null
            
            $outputLines = @()
            
            # Read output in real-time while process is running
            while (-not $process.HasExited) {
                # Check for keyboard input (ESC or Ctrl+C)
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    # ESC key - show interrupt menu with 3 options
                    if ($key.Key -eq [ConsoleKey]::Escape) {
                        Write-Host ""
                        Write-Host "  │ [Paused]" -ForegroundColor Yellow
                        
                        # Use interrupt menu if available, otherwise fall back to simple confirm
                        if (Get-Command Show-InterruptMenu -ErrorAction SilentlyContinue) {
                            $interruptResult = Show-InterruptMenu -Context "Copilot is processing (Iteration $Iteration)"
                            
                            switch ($interruptResult) {
                                'cancel' {
                                    # Cancel instantly
                                    try { $process.Kill() } catch {}
                                    Write-Host "  └─ Cancelled by user ────────────────────────────────" -ForegroundColor Yellow
                                    $duration = (Get-Date) - $startTime
                                    
                                    # Cleanup temp file
                                    Remove-Item $promptFile -ErrorAction SilentlyContinue
                                    
                                    # Log cancellation
                                    if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
                                        Write-LogCopilotCall -Action CANCELLED -Model $currentModel -PromptLength $promptLength -Duration $duration.TotalSeconds
                                    }
                                    
                                    return @{
                                        Success   = $false
                                        Output    = "Operation cancelled by user"
                                        Raw       = $null
                                        Duration  = $duration
                                        Cancelled = $true
                                    }
                                }
                                'stop-after' {
                                    # Finish this iteration, then stop - show banner and continue
                                    Write-Host "  │ Loop will stop after this iteration completes" -ForegroundColor Cyan
                                    Write-Host "  │ Resuming..." -ForegroundColor Gray
                                }
                                'continue' {
                                    # Continue without interruption
                                    Write-Host "  │ Resuming..." -ForegroundColor Gray
                                }
                            }
                        } else {
                            # Fallback to simple confirm
                            $confirmCancel = Show-ArrowConfirm -Message "Cancel and return to menu?" -DefaultYes
                            if ($confirmCancel) {
                                try { $process.Kill() } catch {}
                                Write-Host "  └─ Cancelled by user ────────────────────────────────" -ForegroundColor Yellow
                                $duration = (Get-Date) - $startTime
                                
                                # Cleanup temp file
                                Remove-Item $promptFile -ErrorAction SilentlyContinue
                                
                                # Log cancellation
                                if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
                                    Write-LogCopilotCall -Action CANCELLED -Model $currentModel -PromptLength $promptLength -Duration $duration.TotalSeconds
                                }
                                
                                return @{
                                    Success   = $false
                                    Output    = "Operation cancelled by user"
                                    Raw       = $null
                                    Duration  = $duration
                                    Cancelled = $true
                                }
                            } else {
                                Write-Host "  │ Resuming..." -ForegroundColor Gray
                            }
                        }
                    }
                    
                    # Ctrl+C detection
                    if ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
                        if (Get-Command Test-DoubleCtrlC -ErrorAction SilentlyContinue) {
                            $ctrlCResult = Test-DoubleCtrlC
                            if ($ctrlCResult -eq 'force-exit') {
                                try { $process.Kill() } catch {}
                                Write-Host "  └──────────────────────────────────────────────────────" -ForegroundColor DarkCyan
                                Remove-Item $promptFile -ErrorAction SilentlyContinue
                                Invoke-ForceExit -Message "Exiting Ralph (Ctrl+C pressed twice)"
                            } else {
                                Write-Host "  │ [Press Ctrl+C again within 2s to exit]" -ForegroundColor Yellow
                            }
                        }
                    }
                    
                    # V key - toggle verbose mode
                    if ($key.Key -eq [ConsoleKey]::V -and -not ($key.Modifiers -band [ConsoleModifiers]::Control)) {
                        $script:VerboseMode = -not $script:VerboseMode
                        $verboseStatus = if ($script:VerboseMode) { "ON" } else { "OFF" }
                        Write-Host "  │ [Verbose mode: $verboseStatus (takes effect next iteration)]" -ForegroundColor Cyan
                    }
                }
                
                # Read available output lines (non-blocking via Peek)
                while (-not $process.StandardOutput.EndOfStream -and $process.StandardOutput.Peek() -ge 0) {
                    $line = $process.StandardOutput.ReadLine()
                    if ($line -and $line.Trim()) {
                        $displayLine = if ($line.Length -gt 100) { $line.Substring(0, 97) + "..." } else { $line }
                        Write-Host "  │ $displayLine" -ForegroundColor DarkGray
                        $outputLines += $line
                    }
                }
                
                Start-Sleep -Milliseconds 100
            }
            
            # Read remaining output after process exits
            $remainingOutput = $process.StandardOutput.ReadToEnd()
            if ($remainingOutput) {
                foreach ($line in ($remainingOutput -split "`n")) {
                    if ($line -and $line.Trim()) {
                        $displayLine = if ($line.Length -gt 100) { $line.Substring(0, 97) + "..." } else { $line }
                        Write-Host "  │ $displayLine" -ForegroundColor DarkGray
                        $outputLines += $line
                    }
                }
            }
            
            $duration = (Get-Date) - $startTime
            $exitCode = $process.ExitCode
            Write-Host "  └─ Completed in $([math]::Round($duration.TotalSeconds, 1))s ────────────────────" -ForegroundColor DarkCyan
            
            # Cleanup temp file
            Remove-Item $promptFile -ErrorAction SilentlyContinue
            
            $success = ($exitCode -eq 0)
            $result = $outputLines -join "`n"
            
            Write-VerboseOutput "Duration: $([math]::Round($duration.TotalSeconds, 1))s" -Category "Copilot"
            Write-VerboseOutput "Output length: $($result.Length) chars" -Category "Copilot"
            Write-VerboseOutput "Exit code: $exitCode" -Category "Copilot"
            
            # Log Copilot result
            if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
                $action = if ($success) { 'SUCCESS' } else { 'FAILURE' }
                Write-LogCopilotCall -Action $action -Model $currentModel -PromptLength $promptLength -Duration $duration.TotalSeconds -Output $result
            }
            
            return @{
                Success   = $success
                Output    = $result
                Raw       = $outputLines
                Duration  = $duration
                Cancelled = $false
                ExitCode  = $exitCode
            }
        } catch {
            Write-Host "  └──────────────────────────────────────────────────────" -ForegroundColor DarkCyan
            Write-Ralph "Copilot CLI error: $_" -Type error
            
            if ($process -and -not $process.HasExited) {
                try { $process.Kill() } catch {}
            }
            
            # Cleanup temp file
            Remove-Item $promptFile -ErrorAction SilentlyContinue
            
            $duration = (Get-Date) - $startTime
            
            # Log Copilot error
            if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
                Write-LogCopilotCall -Action FAILURE -Model $currentModel -PromptLength $promptLength -Duration $duration.TotalSeconds -Output $_.Exception.Message
            }
            
            return @{
                Success   = $false
                Output    = $_.Exception.Message
                Raw       = $null
                Duration  = $duration
                Cancelled = $false
                ExitCode  = -1
            }
        }
    } else {
        # Non-verbose mode: use spinner with Start-Process (avoids Job encoding issues)
        $script:SpinnerActive = $true
        $script:SpinnerMessage = $SpinnerMessage
        $script:SpinnerStartTime = $startTime
        $script:SpinnerFrameIndex = 0
        
        Write-Host "$([char]27)[?25l" -NoNewline  # Hide cursor
        
        # Create temp directory for prompt file
        $tempDir = Join-Path $env:TEMP "ralph-copilot"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        $promptFile = Join-Path $tempDir "prompt-$([guid]::NewGuid().ToString('N').Substring(0,8)).txt"
        
        try {
            # Write prompt to temp file to avoid command line length issues
            $Prompt | Out-File -FilePath $promptFile -Encoding UTF8 -NoNewline
            
            # Build copilot command
            $copilotCmd = "copilot -p '@$promptFile'"
            if ($AllowAllTools) {
                $copilotCmd += ' --allow-all-tools'
            }
            if ($currentModel) {
                $copilotCmd += " --model $currentModel"
            }
            
            # Start copilot through powershell.exe (avoids Job encoding issues)
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "powershell.exe"
            $processInfo.Arguments = "-ExecutionPolicy Bypass -NoProfile -Command `"& $copilotCmd`""
            $processInfo.UseShellExecute = $false
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.CreateNoWindow = $true
            $processInfo.WorkingDirectory = (Get-Location).Path
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            
            # Start the process
            $process.Start() | Out-Null
            
            # Read output asynchronously while showing spinner
            $outputTask = $process.StandardOutput.ReadToEndAsync()
            $errorTask = $process.StandardError.ReadToEndAsync()
            
            while (-not $process.HasExited) {
                Write-SpinnerFrame
                
                # Check for keyboard input (ESC or Ctrl+C)
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    # ESC key - show interrupt menu with 3 options
                    if ($key.Key -eq [ConsoleKey]::Escape) {
                        Stop-Spinner -FinalMessage "" -Success $false
                        Write-Host ""
                        
                        # Use interrupt menu if available, otherwise fall back to simple confirm
                        if (Get-Command Show-InterruptMenu -ErrorAction SilentlyContinue) {
                            $interruptResult = Show-InterruptMenu -Context "Copilot is processing (Iteration $Iteration)"
                            
                            switch ($interruptResult) {
                                'cancel' {
                                    # Cancel instantly
                                    try { $process.Kill() } catch {}
                                    Write-Host "  Cancelled by user" -ForegroundColor Yellow
                                    Write-Host "$([char]27)[?25h" -NoNewline  # Show cursor
                                    $duration = (Get-Date) - $startTime
                                    
                                    # Cleanup
                                    Remove-Item $promptFile -ErrorAction SilentlyContinue
                                    
                                    # Log cancellation
                                    if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
                                        Write-LogCopilotCall -Action CANCELLED -Model $currentModel -PromptLength $promptLength -Duration $duration.TotalSeconds
                                    }
                                    
                                    return @{
                                        Success   = $false
                                        Output    = "Operation cancelled by user"
                                        Raw       = $null
                                        Duration  = $duration
                                        Cancelled = $true
                                    }
                                }
                                'stop-after' {
                                    # Finish this iteration, then stop - show message and continue
                                    Write-Host "  Loop will stop after this iteration completes" -ForegroundColor Cyan
                                    # Resume spinner
                                    $script:SpinnerActive = $true
                                    $script:SpinnerMessage = "Copilot working... (stopping after this)"
                                    Write-Host "$([char]27)[?25l" -NoNewline  # Hide cursor again
                                }
                                'continue' {
                                    # Continue without interruption - resume spinner
                                    $script:SpinnerActive = $true
                                    Write-Host "$([char]27)[?25l" -NoNewline  # Hide cursor again
                                }
                            }
                        } else {
                            # Fallback to simple confirm
                            $confirmCancel = Show-ArrowConfirm -Message "Cancel current operation?" -DefaultYes
                            if ($confirmCancel) {
                                try { $process.Kill() } catch {}
                                Write-Host "  Cancelled by user" -ForegroundColor Yellow
                                Write-Host "$([char]27)[?25h" -NoNewline  # Show cursor
                                $duration = (Get-Date) - $startTime
                                
                                # Cleanup
                                Remove-Item $promptFile -ErrorAction SilentlyContinue
                                
                                # Log cancellation
                                if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
                                    Write-LogCopilotCall -Action CANCELLED -Model $currentModel -PromptLength $promptLength -Duration $duration.TotalSeconds
                                }
                                
                                return @{
                                    Success   = $false
                                    Output    = "Operation cancelled by user"
                                    Raw       = $null
                                    Duration  = $duration
                                    Cancelled = $true
                                }
                            } else {
                                # Resume spinner
                                $script:SpinnerActive = $true
                                Write-Host "$([char]27)[?25l" -NoNewline  # Hide cursor again
                            }
                        }
                    }
                    
                    # Ctrl+C detection
                    if ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
                        if (Get-Command Test-DoubleCtrlC -ErrorAction SilentlyContinue) {
                            $ctrlCResult = Test-DoubleCtrlC
                            if ($ctrlCResult -eq 'force-exit') {
                                try { $process.Kill() } catch {}
                                Stop-Spinner -FinalMessage "" -Success $false
                                Remove-Item $promptFile -ErrorAction SilentlyContinue
                                Invoke-ForceExit -Message "Exiting Ralph (Ctrl+C pressed twice)"
                            } else {
                                # Show hint about double Ctrl+C inline with spinner
                                $script:SpinnerMessage = "Copilot working... (Ctrl+C again to exit)"
                            }
                        }
                    }
                    
                    # V key - toggle verbose mode
                    if ($key.Key -eq [ConsoleKey]::V -and -not ($key.Modifiers -band [ConsoleModifiers]::Control)) {
                        $script:VerboseMode = -not $script:VerboseMode
                        $verboseStatus = if ($script:VerboseMode) { "ON" } else { "OFF" }
                        $script:SpinnerMessage = "Copilot working... (Verbose: $verboseStatus)"
                    }
                }
                
                Start-Sleep -Milliseconds 100
            }
            
            # Wait for output tasks to complete
            $output = $outputTask.GetAwaiter().GetResult()
            $errorOutput = $errorTask.GetAwaiter().GetResult()
            
            $duration = (Get-Date) - $startTime
            $exitCode = $process.ExitCode
            
            # Cleanup temp file
            Remove-Item $promptFile -ErrorAction SilentlyContinue
            
            # Combine output (errors typically go to stderr for copilot stats)
            $result = $output.Trim()
            
            # Success = exit code is 0
            $success = ($exitCode -eq 0)
            
            Stop-Spinner -FinalMessage "Completed in $([math]::Round($duration.TotalSeconds, 1))s" -Success $success
            
            Write-VerboseOutput "Duration: $([math]::Round($duration.TotalSeconds, 1))s" -Category "Copilot"
            Write-VerboseOutput "Output length: $($result.Length) chars" -Category "Copilot"
            Write-VerboseOutput "Exit code: $exitCode" -Category "Copilot"
            
            # Log Copilot result with exit code
            if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
                $action = if ($success) { 'SUCCESS' } else { 'FAILURE' }
                Write-LogCopilotCall -Action $action -Model $currentModel -PromptLength $promptLength -Duration $duration.TotalSeconds -Output $result -ExitCode $exitCode
            }
            
            # Also log the full output for debugging when it fails
            if (-not $success -and (Get-Command Write-LogDebug -ErrorAction SilentlyContinue)) {
                Write-LogDebug -Message "Copilot CLI failed with exit code $exitCode" -Context 'CopilotCLI'
                Write-LogDebug -Message "Stderr: $errorOutput" -Context 'CopilotCLI'
            }
            
            return @{
                Success   = $success
                Output    = $result
                Raw       = $null
                Duration  = $duration
                Cancelled = $false
                ExitCode  = $exitCode
            }
        } catch {
            Stop-Spinner -FinalMessage "Error: $_" -Success $false
            
            if ($process -and -not $process.HasExited) {
                try { $process.Kill() } catch {}
            }
            
            # Cleanup
            Remove-Item $promptFile -ErrorAction SilentlyContinue
            
            $duration = (Get-Date) - $startTime
            
            # Log Copilot error
            if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
                Write-LogCopilotCall -Action FAILURE -Model $currentModel -PromptLength $promptLength -Duration $duration.TotalSeconds -Output $_.Exception.Message
            }
            
            return @{
                Success   = $false
                Output    = $_.Exception.Message
                Raw       = $null
                Duration  = $duration
                Cancelled = $false
                ExitCode  = -1
            }
        }
    }
}

function Invoke-CopilotDelegate {
    param([string]$Task)
    
    Write-Ralph "Delegating to Copilot coding agent..." -Type info
    Write-Ralph "Task: $Task" -Type task
    
    return Invoke-Copilot -Prompt "/delegate $Task"
}

function Repair-MissingAgentFile {
    <#
    .SYNOPSIS
        Automatically repairs missing agent files by copying from ralph/agents/
    
    .DESCRIPTION
        When an agent file is missing from .github/agents/, this function
        automatically copies it from the ralph/agents/ source directory.
        This allows Ralph to self-heal when agent files are missing.
    
    .PARAMETER AgentPath
        Full path to the expected agent file location in .github/agents/
    
    .RETURNS
        $true if repair succeeded, $false otherwise
    #>
    param([string]$AgentPath)
    
    $agentFileName = Split-Path -Leaf $AgentPath
    $agentSourceDir = Join-Path (Split-Path $script:CoreDir -Parent) 'agents'
    $sourcePath = Join-Path $agentSourceDir $agentFileName
    
    # Check if source file exists
    if (-not (Test-Path $sourcePath)) {
        Write-VerboseOutput "Cannot repair: Source file not found at $sourcePath" -Category "Repair"
        return $false
    }
    
    # Ensure .github/agents directory exists
    $agentsDir = Split-Path -Parent $AgentPath
    if (-not (Test-Path $agentsDir)) {
        $githubDir = Split-Path -Parent $agentsDir
        if (-not (Test-Path $githubDir)) {
            New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
        }
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
    }
    
    # Copy the file
    try {
        Copy-Item $sourcePath $AgentPath -Force
        Write-Ralph "Auto-recovered missing agent: $agentFileName" -Type success
        Write-VerboseOutput "Copied from: $sourcePath" -Category "Repair"
        # Log agent repair
        if (Get-Command Write-LogAgent -ErrorAction SilentlyContinue) {
            Write-LogAgent -Action REPAIRED -AgentName $agentFileName -Details "Copied from ralph/agents/"
        }
        return $true
    } catch {
        Write-VerboseOutput "Failed to copy agent file: $_" -Category "Repair"
        if (Get-Command Write-LogError -ErrorAction SilentlyContinue) {
            Write-LogError -Message "Failed to repair agent: $agentFileName" -Exception $_
        }
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════
#                     AGENTS.MD UPDATE PHASE
# ═══════════════════════════════════════════════════════════════

function Invoke-AgentsUpdate {
    Write-Ralph "AGENTS.MD UPDATE PHASE [$Mode]" -Type header
    
    $agentPath = $AgentFiles.AgentsUpdater
    if (-not (Test-Path $agentPath)) {
        Write-Ralph "Agents updater not found: $agentPath" -Type warning
        
        # Attempt automatic repair
        if (Repair-MissingAgentFile -AgentPath $agentPath) {
            # Repair succeeded, continue
        } else {
            return $false
        }
    }
    
    $agentPrompt = Get-AgentPrompt -AgentPath $agentPath
    if (-not $agentPrompt) { return $false }
    
    Write-Ralph "Analyzing codebase and updating AGENTS.md..." -Type info
    
    if ($Manual) {
        Write-Ralph "Copy this prompt to Copilot Chat:" -Type warning
        Write-Host ""
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        Write-Host $agentPrompt
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        Write-Host ""
        Write-Ralph "Press ENTER when AGENTS.md update complete" -Type warning
        Read-Host | Out-Null
        return $true
    }
    
    $result = Invoke-Copilot -Prompt $agentPrompt -AllowAllTools
    Update-CopilotStats -Result $result -Phase 'AgentsUpdate'
    
    if (-not $result.Success) {
        Write-Ralph "AGENTS.md update failed: $($result.Output)" -Type error
        return $false
    }
    
    if ($result.Output -match [regex]::Escape($Signals.AgentsUpdated)) {
        Write-Ralph "AGENTS.md updated!" -Type success
    }
    
    return $true
}

# ═══════════════════════════════════════════════════════════════
#                      PROJECT SETUP
# ═══════════════════════════════════════════════════════════════

function Invoke-ProjectSetup {
    <#
    .SYNOPSIS
        Sets up project structure when build process actually starts
        
    .DESCRIPTION
        Creates .github/instructions/, .github/agents/ folders.
        Specs are already in ralph/specs/.
        Only called when user confirms to start the build process,
        not during session selection or wizard configuration.
        
        Idempotent - skips items that already exist.
    #>
    
    # Check what needs to be created
    $setupActions = @()
    
    $instructionsDir = Join-Path $script:ProjectRoot '.github\instructions'
    $ralphInstructionsPath = Join-Path $instructionsDir 'ralph.instructions.md'
    if (-not (Test-Path $ralphInstructionsPath)) {
        $setupActions += '.github/instructions/ralph.instructions.md'
    }
    
    $githubAgentsDir = Join-Path $script:ProjectRoot '.github\agents'
    if (-not (Test-Path $githubAgentsDir)) {
        $setupActions += '.github/agents/'
    }
    
    # Nothing to create
    if ($setupActions.Count -eq 0) {
        return $true
    }
    
    # DRY-RUN MODE
    if (Test-DryRunEnabled) {
        Write-Host ""
        Write-Host "  [DRY RUN] Would create project structure:" -ForegroundColor Yellow
        foreach ($action in $setupActions) {
            Write-Host "    • $action" -ForegroundColor Gray
        }
        Write-Host ""
        return $true
    }
    
    # Show what will be created and confirm
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  RALPH - PROJECT SETUP" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Ralph will create the following project files:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($action in $setupActions) {
        Write-Host "    • $action" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  These files are needed for Ralph to plan and build your project." -ForegroundColor Gray
    Write-Host ""
    
    $proceed = Show-ArrowConfirm -Message "Proceed with setup?" -DefaultYes
    
    if (-not $proceed) {
        Write-Ralph "Setup cancelled." -Type warning
        return $false
    }
    
    Write-Host ""
    
    # Create .github/instructions/ with ralph.instructions.md
    if (-not (Test-Path $ralphInstructionsPath)) {
        $githubDir = Join-Path $script:ProjectRoot '.github'
        if (-not (Test-Path $githubDir)) {
            New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
        }
        if (-not (Test-Path $instructionsDir)) {
            New-Item -ItemType Directory -Path $instructionsDir -Force | Out-Null
        }
        $templatesDir = Join-Path (Split-Path $script:CoreDir -Parent) 'templates'
        $templatePath = Join-Path $templatesDir 'ralph.instructions.md'
        if (Test-Path $templatePath) {
            Copy-Item $templatePath $ralphInstructionsPath
            Write-Host "  ✓ Created .github/instructions/ralph.instructions.md" -ForegroundColor Green
        }
    }
    
    # Create .github/agents/ and copy agent files
    if (-not (Test-Path $githubAgentsDir)) {
        $githubDir = Join-Path $script:ProjectRoot '.github'
        if (-not (Test-Path $githubDir)) {
            New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
        }
        New-Item -ItemType Directory -Path $githubAgentsDir -Force | Out-Null
        
        $agentSourceDir = Join-Path (Split-Path $script:CoreDir -Parent) 'agents'
        $agentFiles = Get-ChildItem -Path $agentSourceDir -Filter '*.agent.md' -ErrorAction SilentlyContinue
        foreach ($file in $agentFiles) {
            Copy-Item $file.FullName (Join-Path $githubAgentsDir $file.Name)
        }
        Write-Host "  ✓ Created .github/agents/ with $($agentFiles.Count) agent files" -ForegroundColor Green
    }
    
    # Offer AGENTS.md creation
    $agentsMdPath = Join-Path $script:ProjectRoot 'AGENTS.md'
    if (-not (Test-Path $agentsMdPath)) {
        Write-Host ""
        Write-Host "  Note: No AGENTS.md found in project root." -ForegroundColor Yellow
        Write-Host "  This file helps Ralph understand your build/test commands." -ForegroundColor Gray
        Write-Host ""
        
        $createAgents = Show-ArrowConfirm -Message "Create AGENTS.md?" -DefaultYes
        
        if ($createAgents) {
            $templatesDir = Join-Path (Split-Path $script:CoreDir -Parent) 'templates'
            $templatePath = Join-Path $templatesDir 'AGENTS.template.md'
            if (Test-Path $templatePath) {
                Copy-Item $templatePath $agentsMdPath
                Write-Host "  ✓ Created AGENTS.md" -ForegroundColor Green
            }
        } else {
            Write-Host "  ⊘ Skipped AGENTS.md" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "  Setup complete!" -ForegroundColor Green
    Write-Host ""
    
    return $true
}

# ═══════════════════════════════════════════════════════════════
#                     REFERENCE WORKFLOW
# ═══════════════════════════════════════════════════════════════

function Start-ReferenceWorkflow {
    <#
    .SYNOPSIS
        Complete workflow for setting up a session with reference files
    .DESCRIPTION
        Guides user through:
        1. Selecting reference sources (default spec folder, custom directories, files)
        2. Confirming the file list
        3. Creating a session with references
        4. Optional: Running analysis on references
    .OUTPUTS
        Session info hashtable or $null if cancelled
    #>
    
    # Clear any existing session references
    Clear-SessionReferences
    
    # Show the main references menu loop
    while ($true) {
        $summary = Get-ReferenceSummary
        
        # Get detailed summaries for display
        $dirSummaries = @(Get-RegisteredDirectoriesWithSummary)
        $fileSummaries = @(Get-RegisteredFilesWithInfo)
        
        # HasRefs should be true if we have files OR registered directories/files (even if empty)
        $hasRefs = ($summary.TotalFiles -gt 0) -or ($dirSummaries.Count -gt 0) -or ($fileSummaries.Count -gt 0)
        
        $result = Show-ReferencesMenu -HasReferences $hasRefs -ReferenceCount $summary.TotalFiles `
            -DirectorySummaries $dirSummaries -FileSummaries $fileSummaries -CategorySummary $summary.ByCategory
        
        # Check action and handle appropriately
        $action = $result.Action
        
        switch ($action) {
            'continue' {
                # User wants to proceed with current references - exit the while loop
                break
            }
            'use-default-reference' {
                # Add the default reference folder (inside ralph/, NOT .ralph/)
                $userRalphDir = Join-Path $script:ProjectRoot 'ralph'
                $defaultDir = Join-Path $userRalphDir 'references'
                
                # DEBUG: Show what path we're checking
                Write-Host ""
                Write-Host "  [DEBUG] Looking for references at: $defaultDir" -ForegroundColor DarkYellow
                Write-Host "  [DEBUG] Project Root: $script:ProjectRoot" -ForegroundColor DarkYellow
                Write-Host "  [DEBUG] User Ralph Dir: $userRalphDir" -ForegroundColor DarkYellow
                
                if (-not (Test-Path $defaultDir)) {
                    New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null
                    Write-Host "  ✓ Created ralph/references/ directory" -ForegroundColor Green
                }
                
                # DEBUG: Show what files exist
                $allFilesInDir = @(Get-ChildItem -Path $defaultDir -File -ErrorAction SilentlyContinue)
                Write-Host "  [DEBUG] Files in directory: $($allFilesInDir.Count)" -ForegroundColor DarkYellow
                foreach ($f in $allFilesInDir) {
                    Write-Host "    - $($f.Name) (starts with _: $($f.Name.StartsWith('_')))" -ForegroundColor DarkGray
                }
                Write-Host ""
                
                $result = Add-ReferenceDirectory -Directory $defaultDir -FolderType 'reference'
                if ($result.Success) {
                    $dirSummary = Get-DirectoryFileSummary -Directory $defaultDir -FolderType 'reference'
                    
                    # Debug: Check what files exist
                    $allFiles = @(Get-ChildItem -Path $defaultDir -File -ErrorAction SilentlyContinue)
                    $nonTemplateFiles = @($allFiles | Where-Object { -not $_.Name.StartsWith('_') })
                    
                    if ($dirSummary.TotalFiles -gt 0) {
                        Write-Host "  ✓ Added ralph/references/ ($($dirSummary.FormattedSummary))" -ForegroundColor Green
                    } else {
                        # Check if there are any files at all
                        if ($nonTemplateFiles.Count -gt 0) {
                            Write-Host "  ⚠ Added ralph/references/ - found $($nonTemplateFiles.Count) file(s) but they may not be supported types" -ForegroundColor Yellow
                            Write-Host "     Supported: .png, .jpg, .md, .txt, .json, .yaml, .ps1, .py, .js, .ts, etc." -ForegroundColor DarkGray
                        } elseif ($allFiles.Count -gt 0) {
                            Write-Host "  ⚠ Added ralph/references/ (only template files found - add your reference files here)" -ForegroundColor Yellow
                        } else {
                            Write-Host "  ⚠ Added ralph/references/ (empty - add reference files here)" -ForegroundColor Yellow
                        }
                        Write-Host "     You can add images, docs, code samples, etc." -ForegroundColor DarkGray
                    }
                } else {
                    Write-Host "  ✗ Failed to add ralph/references/" -ForegroundColor Red
                }
                Write-Host ""
                Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                continue
            }
            'add-directory' {
                # Let user add a directory
                Write-Host ""
                Write-Host "  Enter directory path (relative or absolute)" -ForegroundColor Cyan
                Write-Host "  Examples: ./docs, ./references, ../shared-specs, C:\Projects\Specs" -ForegroundColor Gray
                
                $dirPath = Show-PathInputMenu -Title "Directory path" -Type 'directory' -MustExist
                
                if ($dirPath) {
                    # First validate and show what we found
                    $dirSummary = Get-DirectoryFileSummary -Directory $dirPath
                    
                    if (-not $dirSummary.Valid) {
                        Write-Host "  ✗ Invalid path: $($dirSummary.Error)" -ForegroundColor Red
                    } elseif ($dirSummary.TotalFiles -eq 0) {
                        Write-Host "  ⚠ Directory found but no supported files detected" -ForegroundColor Yellow
                        $addAnyway = Show-ArrowConfirm -Message "Add empty directory anyway?"
                        if ($addAnyway) {
                            $result = Add-ReferenceDirectory -Directory $dirPath
                            if ($result.Success) {
                                Write-Host "  ✓ Added empty directory ($($result.FolderType) folder)" -ForegroundColor Green
                                if ($result.Warning) {
                                    Write-Host "  ℹ️  $($result.Warning)" -ForegroundColor Yellow
                                }
                            }
                        }
                    } else {
                        $result = Add-ReferenceDirectory -Directory $dirPath
                        if ($result.Success) {
                            Write-Host "  ✓ Added directory ($($result.FolderType) folder): $($dirSummary.FormattedSummary)" -ForegroundColor Green
                            if ($result.Warning) {
                                Write-Host "  ℹ️  $($result.Warning)" -ForegroundColor Yellow
                            }
                        }
                    }
                }
                Write-Host ""
                Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                continue
            }
            'view-references' {
                # Show detailed reference list
                Show-ReferenceSummary
                $refs = Get-AllSessionReferences
                if ($refs.Count -gt 0) {
                    Write-Host "  Files:" -ForegroundColor Cyan
                    foreach ($ref in $refs) {
                        $sizeMB = [math]::Round($ref.Size / 1KB, 1)
                        Write-Host "    • $($ref.RelativePath) ($sizeMB KB)" -ForegroundColor White
                    }
                }
                Write-Host ""
                Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                continue
            }
            'remove-reference' {
                # Show remove reference menu
                $toRemove = Show-RemoveReferenceMenu -DirectorySummaries $dirSummaries -FileSummaries $fileSummaries
                
                if ($toRemove) {
                    if ($toRemove.Type -eq 'directory') {
                        Remove-ReferenceDirectory -Directory $toRemove.Path
                        Write-Host "  ✓ Removed directory" -ForegroundColor Green
                    } elseif ($toRemove.Type -eq 'file') {
                        Remove-ReferenceFile -FilePath $toRemove.Path
                        Write-Host "  ✓ Removed file" -ForegroundColor Green
                    }
                    Write-Host ""
                    Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                }
                continue
            }
            'clear-references' {
                $confirm = Show-ArrowConfirm -Message "Clear all registered references?"
                if ($confirm) {
                    Clear-SessionReferences
                    Write-Host "  ✓ Cleared all references" -ForegroundColor Green
                }
                continue
            }
            'show-types' {
                Show-SupportedFileTypesMenu
                continue
            }
            'back' {
                return $null
            }
            'quit' {
                return $null
            }
        }
        
        # If action was 'continue', break out of the menu loop
        if ($action -eq 'continue') {
            break
        }
    }
    
    # Check if we have any references
    $allRefs = Get-AllSessionReferences
    
    if ($allRefs.Count -eq 0) {
        Write-Host ""
        Write-Host "  No reference files selected." -ForegroundColor Yellow
        Write-Host "  Would you like to:" -ForegroundColor Gray
        
        $action = Show-ArrowChoice -Title "" -NoBack -Choices @(
            @{ Label = "Go back and add references"; Value = "back" }
            @{ Label = "Create empty session anyway"; Value = "empty" }
            @{ Label = "Cancel"; Value = "cancel" }
        )
        
        if ($action -eq 'back') {
            return Start-ReferenceWorkflow  # Recurse to start over
        } elseif ($action -ne 'empty') {
            return $null
        }
    }
    
    # Show confirmation with file list
    if ($allRefs.Count -gt 0) {
        $confirmed = Show-ReferenceConfirmationMenu -References $allRefs
        if (-not $confirmed) {
            return Start-ReferenceWorkflow  # Recurse to let user modify
        }
    }
    
    # Create a new session with these references
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  CREATE SESSION FROM REFERENCES" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    
    $nameInput = Show-ArrowTextInput -Prompt "Session name" -Required -AllowBack
    if ($nameInput.Type -eq 'back') {
        return Start-ReferenceWorkflow
    }
    $sessionName = $nameInput.Value
    
    $descInput = Show-ArrowTextInput -Prompt "Description (optional)" -AllowBack
    if ($descInput.Type -eq 'back') {
        return Start-ReferenceWorkflow
    }
    $description = $descInput.Value
    
    # Create the session
    Write-Host ""
    Write-Host "  Creating session..." -ForegroundColor Gray
    
    if (Test-DryRunEnabled) {
        Add-DryRunAction -Type 'Task' -Description "Create session from references: $sessionName" -Details @{
            ReferenceCount = $allRefs.Count
            ImageCount = ($allRefs | Where-Object { $_.IsImage }).Count
            TextCount = ($allRefs | Where-Object { -not $_.IsImage }).Count
        }
        
        Write-Host ""
        Write-Host "  [DRY RUN] Would create session:" -ForegroundColor Yellow
        Write-Host "     Name: $sessionName" -ForegroundColor Cyan
        Write-Host "     References: $($allRefs.Count) files" -ForegroundColor Gray
        Write-Host ""
        
        return @{
            IsDryRun = $true
            Id = "[DRY-RUN-REF-SESSION]"
            Name = $sessionName
            Description = $description
        }
    }
    
    try {
        $newTask = New-Task -Name $sessionName -Description $description
        
        if (-not $newTask) {
            Write-Host "  ✗ Failed to create session" -ForegroundColor Red
            return $null
        }
        
        # Save references to the task configuration
        Save-SessionReferences -TaskId $newTask.Id
        
        # Activate the session
        Set-ActiveTask -TaskId $newTask.Id
        
        Write-Host ""
        Write-Host "  ✅ Session created!" -ForegroundColor Green
        Write-Host "     Session: $($newTask.Id)" -ForegroundColor Cyan
        Write-Host "     References: $($allRefs.Count) files" -ForegroundColor Gray
        
        # Show image analysis preview if images are included
        $imageRefs = @($allRefs | Where-Object { $_.IsImage })
        if ($imageRefs.Count -gt 0) {
            Write-Host ""
            Write-Host "  🖼️  $($imageRefs.Count) image(s) detected" -ForegroundColor Magenta
            Write-Host "     Ralph will analyze these for UI structure and UX flows" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "  Ralph will now analyze all references and create a plan..." -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -Seconds 2
        
        return $newTask
    } catch {
        Write-Host "  ✗ Error creating session: $_" -ForegroundColor Red
        return $null
    }
}

# ═══════════════════════════════════════════════════════════════
#                   REFERENCE SETTINGS WORKFLOW
# ═══════════════════════════════════════════════════════════════

function Start-ReferenceSettingsWorkflow {
    <#
    .SYNOPSIS
        Workflow for configuring references for an existing session
    .PARAMETER TaskId
        Task ID to configure
    #>
    param(
        [string]$TaskId
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    # Push navigation state so Back button appears
    Push-MenuState -MenuId 'session-home' -Context @{ TaskId = $TaskId }
    
    # Ensure task is configured to use session references
    $refsConfig = Get-TaskReferencesConfig -TaskId $TaskId
    if ($refsConfig.referencesSource -eq 'none') {
        Set-TaskReferencesConfig -TaskId $TaskId -ReferencesSource 'session'
    }
    
    # Get the session references folder
    $sessionRefsFolder = Get-SessionReferencesFolder -TaskId $TaskId
    if (-not (Test-Path $sessionRefsFolder)) {
        New-Item -ItemType Directory -Path $sessionRefsFolder -Force | Out-Null
    }
    
    # Load existing session references into memory (for backward compatibility)
    if (Get-Command Load-SessionReferences -ErrorAction SilentlyContinue) {
        Load-SessionReferences -TaskId $TaskId | Out-Null
    }
    
    # Show references menu loop
    while ($true) {
        $summary = Get-ReferenceSummary
        $dirSummaries = @(Get-RegisteredDirectoriesWithSummary)
        $fileSummaries = @(Get-RegisteredFilesWithInfo)
        $hasRefs = ($summary.TotalFiles -gt 0) -or ($dirSummaries.Count -gt 0) -or ($fileSummaries.Count -gt 0)
        
        $result = Show-ReferencesMenu -HasReferences $hasRefs -ReferenceCount $summary.TotalFiles `
            -DirectorySummaries $dirSummaries -FileSummaries $fileSummaries -CategorySummary $summary.ByCategory
        
        switch ($result.Action) {
            'continue' {
                # Copy only explicit files to session-references folder
                # Directory-sourced files are already accessible via referenceDirectories in task.json
                $allRefs = @(Get-AllSessionReferences)
                $explicitRefs = @($allRefs | Where-Object { $_.Source -eq 'Explicit' })
                if ($explicitRefs.Count -gt 0) {
                    Write-Host ""
                    Write-Host "  Copying references to session folder..." -ForegroundColor Cyan
                    
                    foreach ($ref in $explicitRefs) {
                        $destFile = Join-Path $sessionRefsFolder $ref.Name
                        if (-not (Test-Path $destFile)) {
                            Copy-Item -Path $ref.Path -Destination $destFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                
                if ($allRefs.Count -gt 0) {
                    # Ensure referencesSource is set to 'session'
                    Set-TaskReferencesConfig -TaskId $TaskId -ReferencesSource 'session'
                    Write-Host "  ✓ References configured" -ForegroundColor Green
                }
                
                # Pop navigation state before returning
                Pop-MenuState
                return
            }
            'back' {
                # Copy only explicit files to session-references folder
                # Directory-sourced files are already accessible via referenceDirectories in task.json
                $allRefs = @(Get-AllSessionReferences)
                $explicitRefs = @($allRefs | Where-Object { $_.Source -eq 'Explicit' })
                if ($explicitRefs.Count -gt 0) {
                    foreach ($ref in $explicitRefs) {
                        $destFile = Join-Path $sessionRefsFolder $ref.Name
                        if (-not (Test-Path $destFile)) {
                            Copy-Item -Path $ref.Path -Destination $destFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                
                if ($allRefs.Count -gt 0) {
                    # Ensure referencesSource is set to 'session'
                    Set-TaskReferencesConfig -TaskId $TaskId -ReferencesSource 'session'
                }
                
                # Pop navigation state before returning
                Pop-MenuState
                return
            }
            'use-default-reference' {
                $userRalphDir = Join-Path $script:ProjectRoot 'ralph'
                $defaultDir = Join-Path $userRalphDir 'references'
                if (-not (Test-Path $defaultDir)) {
                    New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null
                }
                $addResult = Add-ReferenceDirectory -Directory $defaultDir -FolderType 'reference'
                if ($addResult.Success) {
                    Write-Host "  ✓ Added ralph/references/" -ForegroundColor Green
                }
                Start-Sleep -Seconds 1
            }
            'add-directory' {
                $dirPath = Show-PathInputMenu -Title "Reference directory path" -Type 'directory' -MustExist
                if ($dirPath) {
                    $addResult = Add-ReferenceDirectory -Directory $dirPath -FolderType 'reference'
                    if ($addResult.Success) {
                        Write-Host "  ✓ Added $dirPath" -ForegroundColor Green
                    }
                    Start-Sleep -Seconds 1
                }
            }
            'clear-references' {
                Clear-SessionReferences
                # Also clear the session-references folder
                if (Test-Path $sessionRefsFolder) {
                    Get-ChildItem -Path $sessionRefsFolder -File | Remove-Item -Force -ErrorAction SilentlyContinue
                }
                # Persist cleared state to task.json
                if (Get-Command Save-SessionReferences -ErrorAction SilentlyContinue) {
                    Save-SessionReferences -TaskId $TaskId | Out-Null
                }
                Write-Host "  ✓ References cleared" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            'view-references' {
                $allRefs = @(Get-AllSessionReferences)
                Write-Host ""
                Write-Host "  Current references:" -ForegroundColor Cyan
                foreach ($ref in $allRefs) {
                    Write-Host "    • $($ref.Name)" -ForegroundColor White
                }
                Write-Host ""
                Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
            'show-types' {
                Show-SupportedFileTypesMenu
                Write-Host ""
                Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
            default {
                continue
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                   SPECS SETTINGS WORKFLOW
# ═══════════════════════════════════════════════════════════════

function Start-SpecsSettingsWorkflow {
    <#
    .SYNOPSIS
        Workflow for configuring specs for an existing session
    .PARAMETER TaskId
        Task ID to configure
    #>
    param(
        [string]$TaskId
    )
    
    if (-not $TaskId) {
        $TaskId = Get-ActiveTaskId
    }
    
    # Push navigation state so Back button appears
    Push-MenuState -MenuId 'session-home' -Context @{ TaskId = $TaskId }
    
    # Show specs settings menu loop
    while ($true) {
        $specsConfig = Get-TaskSpecsConfig -TaskId $TaskId
        $specsSummary = Get-TaskSpecsSummary -TaskId $TaskId
        $specsFolder = Get-TaskSpecsFolder -TaskId $TaskId
        $specsSource = $specsConfig.specsSource
        $hasSpecs = $specsSource -ne 'none' -and $specsSummary -ne "Not configured" -and $specsSummary -ne "No specs"
        
        $result = Show-SpecsSettingsMenu -SpecsSummary $specsSummary -HasSpecs $hasSpecs -SpecsFolder $specsFolder -SpecsSource $specsSource
        
        switch ($result.Action) {
            'continue' {
                # Pop navigation state before returning
                Pop-MenuState
                return
            }
            'back' {
                # Pop navigation state before returning
                Pop-MenuState
                return
            }
            'use-session' {
                # Use session's specs folder
                Set-TaskSpecsConfig -TaskId $TaskId -SpecsSource 'session' -SpecsFolder ''
                
                # Ensure the folder exists
                $sessionSpecsFolder = Get-SessionSpecsFolder -TaskId $TaskId
                if ($sessionSpecsFolder -and -not (Test-Path $sessionSpecsFolder)) {
                    New-Item -ItemType Directory -Path $sessionSpecsFolder -Force | Out-Null
                }
                
                # Update script-level SpecsDir for immediate use
                $script:SpecsDir = $sessionSpecsFolder
                
                Write-Host "  ✓ Using session specs folder: $sessionSpecsFolder" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            'use-global' {
                # Use global specs folder (ralph/specs/)
                Set-TaskSpecsConfig -TaskId $TaskId -SpecsSource 'global' -SpecsFolder ''
                
                # Ensure the global folder exists
                $globalSpecsDir = Get-GlobalSpecsFolder
                if (-not (Test-Path $globalSpecsDir)) {
                    New-Item -ItemType Directory -Path $globalSpecsDir -Force | Out-Null
                }
                
                # Update script-level SpecsDir for immediate use
                $script:SpecsDir = $globalSpecsDir
                
                Write-Host "  ✓ Using global specs folder: $globalSpecsDir" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            'set-custom-folder' {
                $customPath = Show-PathInputMenu -Title "Custom specs folder path" -Type 'directory' -MustExist
                if ($customPath) {
                    Set-TaskSpecsConfig -TaskId $TaskId -SpecsSource 'custom' -SpecsFolder $customPath
                    
                    # Update script-level SpecsDir for immediate use
                    $script:SpecsDir = $customPath
                    
                    Write-Host "  ✓ Set custom specs folder: $customPath" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }
            }
            'clear-specs' {
                Set-TaskSpecsConfig -TaskId $TaskId -SpecsSource 'none' -SpecsFolder ''
                $script:SpecsDir = $null
                Write-Host "  ✓ Specs configuration cleared" -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            'build-prompt' {
                # Quick spec creation
                $quickResult = Invoke-SpecCreation -SpecMode 'quick'
                if ($quickResult) {
                    Write-Host "  ✓ Spec created" -ForegroundColor Green
                }
                Start-Sleep -Seconds 1
            }
            'build-interview' {
                # Interview spec creation
                $interviewResult = Invoke-SpecCreation -SpecMode 'interview'
                if ($interviewResult) {
                    Write-Host "  ✓ Spec created" -ForegroundColor Green
                }
                Start-Sleep -Seconds 1
            }
            'build-from-references' {
                # Build spec from reference files (images, text)
                # Log action entry
                if (Get-Command Write-LogUserAction -ErrorAction SilentlyContinue) {
                    Write-LogUserAction -Action 'MENU_SELECT' -Context 'SpecMenu' -Selection 'build-from-references'
                }
                
                # Check for references using the unified Get-AllSessionReferences function
                # which checks session-references folder AND registered directories
                $allRefs = @()
                if (Get-Command Load-SessionReferences -ErrorAction SilentlyContinue) {
                    Load-SessionReferences -TaskId $TaskId | Out-Null
                }
                if (Get-Command Get-AllSessionReferences -ErrorAction SilentlyContinue) {
                    $allRefs = @(Get-AllSessionReferences)
                }
                
                # Log reference count
                if (Get-Command Write-LogDebug -ErrorAction SilentlyContinue) {
                    Write-LogDebug -Message "build-from-references: Found $($allRefs.Count) references" -Context 'SpecCreation'
                }
                
                if ($allRefs.Count -eq 0) {
                    Write-Host ""
                    Write-Host "  ⚠ No references found for this session" -ForegroundColor Yellow
                    Write-Host "    Add references first, then use this option to convert them to specs" -ForegroundColor DarkGray
                    Write-Host ""
                    Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    
                    if (Get-Command Write-LogWarning -ErrorAction SilentlyContinue) {
                        Write-LogWarning -Message "build-from-references aborted: No references found" -Context 'SpecCreation'
                    }
                } else {
                    # Create spec from references
                    if (Get-Command Write-LogInfo -ErrorAction SilentlyContinue) {
                        Write-LogInfo -Message "Starting spec creation from $($allRefs.Count) references" -Context 'SpecCreation'
                    }
                    
                    $refResult = Invoke-SpecCreation -SpecMode 'from-references'
                    
                    if ($refResult) {
                        Write-Host "  ✓ Spec created from references" -ForegroundColor Green
                        if (Get-Command Write-LogInfo -ErrorAction SilentlyContinue) {
                            Write-LogInfo -Message "Spec creation from references SUCCEEDED" -Context 'SpecCreation'
                        }
                    } else {
                        if (Get-Command Write-LogWarning -ErrorAction SilentlyContinue) {
                            Write-LogWarning -Message "Spec creation from references FAILED or was cancelled" -Context 'SpecCreation'
                        }
                    }
                    Start-Sleep -Seconds 1
                }
            }
            'view-specs' {
                $specsFolder = Get-TaskSpecsFolder -TaskId $TaskId
                if ($specsFolder -and (Test-Path $specsFolder)) {
                    $specFiles = @(Get-ChildItem -Path $specsFolder -Filter "*.md" -ErrorAction SilentlyContinue |
                                   Where-Object { -not $_.Name.StartsWith('_') })
                    
                    Write-Host ""
                    Write-Host "  Specs in ${specsFolder}:" -ForegroundColor Cyan
                    if ($specFiles.Count -eq 0) {
                        Write-Host "    (no spec files)" -ForegroundColor DarkGray
                    } else {
                        foreach ($spec in $specFiles) {
                            Write-Host "    • $($spec.Name)" -ForegroundColor White
                        }
                    }
                } else {
                    Write-Host ""
                    Write-Host "  No specs folder configured" -ForegroundColor Yellow
                }
                Write-Host ""
                Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
            'apply-preset' {
                # Show preset selection menu and apply selected preset
                if (Get-Command Show-PresetsMenu -ErrorAction SilentlyContinue) {
                    $presetId = Show-PresetsMenu
                    if ($presetId) {
                        # Get specs folder for this task
                        $specsFolder = Get-TaskSpecsFolder -TaskId $TaskId
                        if (-not $specsFolder) {
                            # If no specs folder configured, use session specs
                            Set-TaskSpecsConfig -TaskId $TaskId -SpecsSource 'session' -SpecsFolder ''
                            $specsFolder = Get-SessionSpecsFolder -TaskId $TaskId
                            if ($specsFolder -and -not (Test-Path $specsFolder)) {
                                New-Item -ItemType Directory -Path $specsFolder -Force | Out-Null
                            }
                        }
                        
                        if ($specsFolder) {
                            $applied = Apply-Preset -PresetId $presetId -TaskSpecsDir $specsFolder
                            if ($applied) {
                                Write-Host "  ✓ Preset applied successfully" -ForegroundColor Green
                            } else {
                                Write-Host "  ✗ Failed to apply preset" -ForegroundColor Red
                            }
                        } else {
                            Write-Host "  ✗ Could not determine specs folder" -ForegroundColor Red
                        }
                        Start-Sleep -Seconds 2
                    }
                } else {
                    Write-Host "  ⚠ Presets module not loaded" -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
            }
            'boilerplate-wizard' {
                # Start the boilerplate wizard
                if (Get-Command Start-BoilerplateWizard -ErrorAction SilentlyContinue) {
                    $wizardResult = Start-BoilerplateWizard -ProjectRoot $script:ProjectRoot
                    if ($wizardResult) {
                        # Wizard completed, check if it created a spec
                        if ($wizardResult.SpecPath -and (Test-Path $wizardResult.SpecPath)) {
                            Write-Host "  ✓ Boilerplate spec created: $($wizardResult.SpecPath)" -ForegroundColor Green
                            
                            # Configure specs to use the folder where the spec was created
                            $specFolder = Split-Path $wizardResult.SpecPath -Parent
                            Set-TaskSpecsConfig -TaskId $TaskId -SpecsSource 'custom' -SpecsFolder $specFolder
                            $script:SpecsDir = $specFolder
                        }
                        Start-Sleep -Seconds 2
                    }
                } else {
                    Write-Host "  ⚠ Boilerplate wizard module not loaded" -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
            }
            default {
                continue
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                        PLANNING PHASE
# ═══════════════════════════════════════════════════════════════

function Invoke-Planning {
    Write-Ralph "PLANNING PHASE [$Mode]" -Type header
    
    # Log planning start
    if (Get-Command Write-LogPlan -ErrorAction SilentlyContinue) {
        Write-LogPlan -Action STARTED
    }
    
    $agentPath = $AgentFiles.Plan
    if (-not (Test-Path $agentPath)) {
        Write-Ralph "Planning agent not found: $agentPath" -Type error
        
        # Attempt automatic repair
        if (Repair-MissingAgentFile -AgentPath $agentPath) {
            # Repair succeeded, continue
        } else {
            return $false
        }
    }
    
    $agentPrompt = Get-AgentPrompt -AgentPath $agentPath
    if (-not $agentPrompt) { return $false }
    
    # Check if we have reference files to include in planning
    $activeTaskId = Get-ActiveTaskId
    if ($activeTaskId -and (Get-Command Load-SessionReferences -ErrorAction SilentlyContinue)) {
        Load-SessionReferences -TaskId $activeTaskId | Out-Null
    }
    
    $allRefs = @()
    if (Get-Command Get-AllSessionReferences -ErrorAction SilentlyContinue) {
        $allRefs = @(Get-AllSessionReferences)
    }
    
    # Check if user has actual spec files in the specs directory
    $hasUserSpecs = $false
    if (Get-Command Get-UserSpecs -ErrorAction SilentlyContinue) {
        $userSpecs = @(Get-UserSpecs)
        $hasUserSpecs = ($userSpecs.Count -gt 0)
    }
    
    # Build reference context for the planning prompt
    if ($allRefs.Count -gt 0) {
        Write-Ralph "Found $($allRefs.Count) reference files to analyze" -Type info
        
        # Build the reference analysis section
        $referencePrompt = Build-ReferenceAnalysisPrompt -References $allRefs
        
        # Check for images that need special analysis
        $imageRefs = @($allRefs | Where-Object { $_.IsImage })
        if ($imageRefs.Count -gt 0) {
            Write-Ralph "Including $($imageRefs.Count) image(s) for UI/UX analysis" -Type info
        }
        
        # Determine if this is a reference-only session (no user specs in specs folder)
        $isReferenceOnly = (-not $hasUserSpecs)
        
        # Append reference content to the planning prompt
        if ($isReferenceOnly) {
            # Reference-only mode: Ralph needs to extract requirements from references
            $agentPrompt = $agentPrompt + @"

## REFERENCE FILES FOR THIS SESSION (NO EXPLICIT SPECS PROVIDED)

You have been provided with reference materials but NO explicit specification files.
Your task is to ANALYZE the references and EXTRACT requirements to create a complete implementation plan.

$referencePrompt

## REFERENCE-ONLY MODE INSTRUCTIONS

Since no explicit specs were provided, you must:

1. **Extract Requirements from References**:
   - For images: Analyze UI structure, components, layouts, and implied functionality
   - For documentation: Extract features, constraints, and technical requirements
   - For code samples: Identify patterns, libraries, and architectural approaches
   - For data files: Understand data structures and schema requirements

2. **Create Implied Specifications**:
   - Document the UI/UX requirements you identify from visual references
   - List all functional requirements implied by the references
   - Note technical stack and architecture requirements
   - Identify user stories and use cases from the materials

3. **Build Comprehensive Plan**:
   - Organize tasks to build what the references show/describe
   - Prioritize UX-critical features first
   - Include both frontend and backend tasks as needed
   - Reference specific visual elements from images in task descriptions

4. **Generate Missing Specs**:
   - Create specification files in the specs/ folder based on your analysis
   - Document your understanding of the requirements
   - Include acceptance criteria for each feature
   - Add technical notes and constraints

**Important**: You are working from references alone. Be thorough in analyzing them to ensure
nothing is missed. When in doubt, extract MORE requirements rather than fewer.

"@
        } else {
            # SPECS + REFERENCES mode: Both exist, references supplement and clarify specs
            $agentPrompt = $agentPrompt + @"

## REFERENCE FILES FOR THIS SESSION (SUPPLEMENTING SPECS)

You have BOTH specification files AND reference materials. The references provide visual/detailed
context that supplements the written specs. **USE BOTH** to create the most complete plan.

$referencePrompt

## SPECS + REFERENCES MODE INSTRUCTIONS

You have written specifications AND visual/supplementary references. Handle them as follows:

1. **Specs define WHAT to build** - Read specs first to understand requirements
2. **References show HOW it should look/work** - Use images, mockups, examples as visual source of truth

### Reference Priority Rules:

- **If a mockup shows UI details not in specs**: Include those details in your tasks
- **If specs describe a feature visible in mockups**: Use the mockup as the implementation guide
- **If references show more components than specs mention**: Include ALL visible components
- **References are the visual contract** - The final product should match the mockups

### For Each Image Reference:
- Identify ALL UI components visible
- Note exact layouts, spacing, and structure
- Extract color schemes, typography, styling
- Map user interaction flows
- List every button, form, card, and element

### When Creating Tasks:
- Reference specific visual elements: "Create header with logo on left, nav on right (as shown in mockup)"
- Include styling requirements from images
- Mention specific components visible in references
- Ensure tasks cover EVERYTHING visible in mockups, even if not explicitly in specs

### Important:
The user provided references because they want the result to MATCH those references.
Don't treat mockups as optional - they define the expected outcome.

"@
        }
    }
    
    Write-Ralph "Analyzing specs and creating implementation plan..." -Type info
    
    # Save checkpoint before planning
    if (Get-Command Save-PhaseCheckpoint -ErrorAction SilentlyContinue) {
        Save-PhaseCheckpoint -Phase 'planning'
    }
    
    if ($Manual) {
        Write-Ralph "Copy this prompt to Copilot Chat:" -Type warning
        Write-Host ""
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        Write-Host $agentPrompt
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        Write-Host ""
        Write-Ralph "Press ENTER when planning complete" -Type warning
        Read-Host | Out-Null
        return $true
    }
    
    $result = Invoke-Copilot -Prompt $agentPrompt -AllowAllTools -Phase 'planning'
    Update-CopilotStats -Result $result -Phase 'Planning'
    
    # Check if user cancelled (null-safe property access)
    if ($result -and $result.ContainsKey('Cancelled') -and $result.Cancelled) {
        Write-Ralph "Planning cancelled - returning to menu" -Type warning
        return @{ Cancelled = $true }
    }
    
    # Check for fatal errors (quota exhausted, auth issues)
    if ($result -and $result.ContainsKey('FatalError') -and $result.FatalError) {
        Write-Ralph "Fatal error occurred during planning - returning to menu" -Type error
        if (Get-Command Write-LogPlan -ErrorAction SilentlyContinue) {
            $errorMsg = if ($result.ContainsKey('ErrorInfo') -and $result.ErrorInfo -and $result.ErrorInfo.ContainsKey('Message')) { $result.ErrorInfo.Message } else { "Fatal error" }
            Write-LogPlan -Action FAILED -Details "Fatal: $errorMsg"
        }
        Write-Host ""
        Write-Host "  Press any key to return to menu..." -ForegroundColor DarkGray
        $null = [Console]::ReadKey($true)
        return @{ FatalError = $true; ErrorInfo = if ($result.ContainsKey('ErrorInfo')) { $result.ErrorInfo } else { $null } }
    }
    
    # Check for critical errors (server down, service unavailable)
    if ($result -and $result.ContainsKey('CriticalError') -and $result.CriticalError) {
        Write-Ralph "Critical error occurred during planning - returning to menu" -Type error
        if (Get-Command Write-LogPlan -ErrorAction SilentlyContinue) {
            $errorMsg = if ($result.ContainsKey('ErrorInfo') -and $result.ErrorInfo -and $result.ErrorInfo.ContainsKey('Message')) { $result.ErrorInfo.Message } else { "Critical error" }
            Write-LogPlan -Action FAILED -Details "Critical: $errorMsg"
        }
        Write-Host ""
        Write-Host "  Press any key to return to menu..." -ForegroundColor DarkGray
        $null = [Console]::ReadKey($true)
        return @{ CriticalError = $true; ErrorInfo = if ($result.ContainsKey('ErrorInfo')) { $result.ErrorInfo } else { $null } }
    }
    
    if (-not $result.Success) {
        Write-Ralph "Planning failed: $($result.Output)" -Type error
        if (Get-Command Write-LogPlan -ErrorAction SilentlyContinue) {
            Write-LogPlan -Action FAILED -Details $result.Output
        }
        return $false
    }
    
    if ($result.Output -match [regex]::Escape($Signals.PlanDone)) {
        Write-Ralph "Planning complete!" -Type success
    }
    
    # Verify tasks were created
    $stats = Get-TaskStats
    if ($stats.Pending -gt 0) {
        Write-Ralph "Created $($stats.Pending) tasks" -Type success
        if (Get-Command Write-LogPlan -ErrorAction SilentlyContinue) {
            Write-LogPlan -Action COMPLETED -TaskCount $stats.Pending
        }
        return $true
    } else {
        Write-Ralph "No tasks created. Check ralph/specs/ for valid specifications." -Type warning
        if (Get-Command Write-LogPlan -ErrorAction SilentlyContinue) {
            Write-LogPlan -Action COMPLETED -TaskCount 0 -Details "No tasks created"
        }
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════
#                        BUILDING PHASE
# ═══════════════════════════════════════════════════════════════

function Invoke-Building {
    Write-Ralph "BUILDING PHASE" -Type header
    
    # Log build start
    if (Get-Command Write-LogBuild -ErrorAction SilentlyContinue) {
        Write-LogBuild -Action STARTED
    }
    
    # In dry-run mode, limit iterations to 1 for preview
    if (Test-DryRunEnabled) {
        Write-Host "  [DRY RUN] Simulating single build iteration for preview" -ForegroundColor Yellow
        Write-Host ""
    }
    
    $agentPath = if ($Agent) { $Agent } else { $AgentFiles.Build }
    
    if (-not (Test-Path $agentPath)) {
        Write-Ralph "Build agent not found: $agentPath" -Type error
        
        # Attempt automatic repair (skip if using custom agent path)
        if (-not $Agent) {
            if (Repair-MissingAgentFile -AgentPath $agentPath) {
                # Repair succeeded, continue
            } else {
                return
            }
        } else {
            return
        }
    }
    
    $agentPrompt = Get-AgentPrompt -AgentPath $agentPath
    if (-not $agentPrompt) { return }
    
    $stats = Get-TaskStats
    Write-Ralph "Tasks: $($stats.Pending) pending, $($stats.Completed)/$($stats.Total) complete" -Type info
    
    # Use the iteration setting from session config (no prompt - settings only)
    $effectiveMaxIterations = $MaxIterations
    $script:EffectiveMaxIterations = $effectiveMaxIterations
    
    if (Test-DryRunEnabled) {
        # Dry-run: limit to 1 iteration
        $effectiveMaxIterations = 1
        $script:EffectiveMaxIterations = 1
    }
    
    # Check if resuming from checkpoint
    # NOTE: Checkpoint.iteration is the last COMPLETED iteration
    # So if checkpoint shows iteration 5, iterations 1-5 are done, start at 6
    if ((Get-Command Test-ResumeMode -ErrorAction SilentlyContinue) -and (Test-ResumeMode)) {
        $lastCompletedIteration = Get-ResumeIteration
        if ($lastCompletedIteration -gt 0) {
            Write-Ralph "Last completed iteration: $lastCompletedIteration" -Type info
            Write-Ralph "Resuming from iteration $($lastCompletedIteration + 1)..." -Type info
            $script:Iteration = $lastCompletedIteration  # Will be incremented to lastCompleted+1 at loop start
        }
        # Clear resume mode after using it
        if (Get-Command Clear-Recovery -ErrorAction SilentlyContinue) {
            Clear-Recovery -KeepCheckpoint  # Keep checkpoint until we make progress
        }
    }
    
    # Save phase checkpoint at build start
    if (Get-Command Save-PhaseCheckpoint -ErrorAction SilentlyContinue) {
        Save-PhaseCheckpoint -Phase 'building'
    }
    
    # Reset interrupt state at start of build loop
    if (Get-Command Reset-InterruptState -ErrorAction SilentlyContinue) {
        Reset-InterruptState
    }
    
    Write-Host ""
    
    while ($true) {
        # Check iteration limit
        if ($effectiveMaxIterations -gt 0 -and $Iteration -ge $effectiveMaxIterations) {
            if (Test-DryRunEnabled) {
                Write-Ralph "Dry-run iteration complete (limited to 1 for preview)" -Type info
            } else {
                Write-Ralph "Reached max iterations: $effectiveMaxIterations" -Type warning
            }
            break
        }
        
        $script:Iteration++
        
        # Get current task
        $task = Get-NextTask
        if (-not $task) {
            Write-Ralph "All tasks completed!" -Type success
            if (Get-Command Write-LogBuild -ErrorAction SilentlyContinue) {
                Write-LogBuild -Action COMPLETED -Iteration $script:Iteration -Details "All tasks completed"
            }
            break
        }
        
        Write-Ralph "BUILD ITERATION $Iteration [$Mode]" -Type header
        Write-Ralph "Task: $task" -Type task
        
        # Log iteration start
        if (Get-Command Write-LogBuild -ErrorAction SilentlyContinue) {
            Write-LogBuild -Action ITERATION -Iteration $script:Iteration -Details $task
        }
        
        # Handle delegate mode
        if ($Delegate) {
            Invoke-CopilotDelegate -Task $task | Out-Null
            Write-Ralph "Delegated to Copilot coding agent. Check GitHub for PR." -Type success
            break
        }
        
        # Build task-injected prompt (used by both manual and programmatic modes)
        $taskPrompt = Build-TaskPrompt -BasePrompt $agentPrompt -Task $task
        if (-not $taskPrompt) {
            Write-Ralph "Failed to build task prompt" -Type error
            break
        }
        
        # Manual mode
        if ($Manual) {
            Write-Ralph "Copy this prompt to Copilot Chat:" -Type warning
            Write-Host ""
            Write-Host ("-" * 60) -ForegroundColor DarkGray
            Write-Host $taskPrompt
            Write-Host ("-" * 60) -ForegroundColor DarkGray
            Write-Host ""
            Write-Ralph "Press ENTER when task complete, 'q' to quit" -Type warning
            $userInput = Read-Host
            if ($userInput -eq 'q') { break }
            continue
        }
        
        # Programmatic mode - NO checkpoint here, only save AFTER successful completion
        $result = Invoke-Copilot -Prompt $taskPrompt -AllowAllTools -Phase 'building' -Iteration $script:Iteration -CurrentTask $task
        Update-CopilotStats -Result $result -Phase 'Building'
        
        # Check if user cancelled (null-safe property access)
        if ($result -and $result.ContainsKey('Cancelled') -and $result.Cancelled) {
            Write-Ralph "Operation cancelled - returning to menu" -Type warning
            return @{ Cancelled = $true }
        }
        
        # Check for fatal errors (quota exhausted, auth issues)
        if ($result -and $result.ContainsKey('FatalError') -and $result.FatalError) {
            Write-Ralph "Fatal error occurred - returning to menu" -Type error
            if (Get-Command Write-LogBuild -ErrorAction SilentlyContinue) {
                $errorMsg = if ($result.ContainsKey('ErrorInfo') -and $result.ErrorInfo -and $result.ErrorInfo.ContainsKey('Message')) { $result.ErrorInfo.Message } else { "Fatal error" }
                Write-LogBuild -Action FAILED -Iteration $script:Iteration -Details "Fatal: $errorMsg"
            }
            Write-Host ""
            Write-Host "  Press any key to return to menu..." -ForegroundColor DarkGray
            $null = [Console]::ReadKey($true)
            return @{ FatalError = $true; ErrorInfo = if ($result.ContainsKey('ErrorInfo')) { $result.ErrorInfo } else { $null } }
        }
        
        # Check for critical errors (server down, service unavailable)
        if ($result -and $result.ContainsKey('CriticalError') -and $result.CriticalError) {
            Write-Ralph "Critical error occurred - returning to menu" -Type error
            if (Get-Command Write-LogBuild -ErrorAction SilentlyContinue) {
                $errorMsg = if ($result.ContainsKey('ErrorInfo') -and $result.ErrorInfo -and $result.ErrorInfo.ContainsKey('Message')) { $result.ErrorInfo.Message } else { "Critical error" }
                Write-LogBuild -Action FAILED -Iteration $script:Iteration -Details "Critical: $errorMsg"
            }
            Write-Host ""
            Write-Host "  Press any key to return to menu..." -ForegroundColor DarkGray
            $null = [Console]::ReadKey($true)
            return @{ CriticalError = $true; ErrorInfo = if ($result.ContainsKey('ErrorInfo')) { $result.ErrorInfo } else { $null } }
        }
        
        if (-not $result.Success) {
            Write-Ralph "Build iteration failed" -Type error
            if (Get-Command Write-LogBuild -ErrorAction SilentlyContinue) {
                Write-LogBuild -Action FAILED -Iteration $script:Iteration -Details $result.Output
            }
            
            # Ask user what to do instead of silently ending the session
            $failureAction = $null
            try {
                $errorDetail = if ([string]::IsNullOrWhiteSpace($result.Output)) { "Copilot exited with no output" } else { 
                    $truncated = if ($result.Output.Length -gt 200) { $result.Output.Substring(0, 200) + "..." } else { $result.Output }
                    $truncated
                }
                Write-Host ""
                Write-Host "  ⚠️  Build iteration $($script:Iteration) failed" -ForegroundColor Yellow
                Write-Host "     $errorDetail" -ForegroundColor DarkGray
                Write-Host ""
                
                if (Get-Command Show-ArrowChoice -ErrorAction SilentlyContinue) {
                    $failureAction = Show-ArrowChoice -Title "What would you like to do?" -NoBack -Choices @(
                        @{ Label = "Retry this task"; Value = "retry"; Default = $true }
                        @{ Label = "Skip this task and continue"; Value = "skip" }
                        @{ Label = "Stop and return to menu"; Value = "stop" }
                    )
                }
            } catch {
                if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                    Write-Log -Tag 'WARN' -Message "Build failure menu error, stopping: $_"
                }
            }
            
            if ($failureAction -eq 'retry') {
                Write-Ralph "Retrying task..." -Type info
                # Decrement iteration so retry uses same iteration number
                $script:Iteration--
                Start-Sleep -Seconds 2
                continue
            } elseif ($failureAction -eq 'skip') {
                Write-Ralph "Skipping task and continuing..." -Type warning
                # Mark the task as skipped in the plan file so Get-NextTask advances
                if (Test-Path $PlanFile) {
                    $escapedTask = [regex]::Escape($task)
                    $planContent = Get-Content $PlanFile -Raw
                    $planContent = $planContent -replace "(?m)^(\s*)-\s*\[\s*\]\s*$escapedTask", '$1- [x] (SKIPPED) ' + $task
                    $planContent | Set-Content $PlanFile -NoNewline
                }
                Start-Sleep -Seconds 1
                continue
            }
            # 'stop' or $null (menu failed) — break to end session
            break
        }
        
        # SUCCESS - Task completed, NOW save checkpoint (at completed state)
        # This checkpoint represents the last COMPLETED iteration
        if (Get-Command Save-IterationCheckpoint -ErrorAction SilentlyContinue) {
            Save-IterationCheckpoint -Iteration $script:Iteration -CurrentTask $task
        }
        
        # Check for completion signal - but VERIFY with actual task count
        # The agent may include the signal string in explanatory text (e.g., "I should NOT output <promise>COMPLETE</promise>")
        # which would cause false-positive detection. Task count is the source of truth.
        if ($result.Output -match [regex]::Escape($Signals.Complete)) {
            $verifyStats = Get-TaskStats
            if ($verifyStats.Pending -eq 0) {
                Write-Ralph "ALL TASKS COMPLETED!" -Type success
                if (Get-Command Write-LogBuild -ErrorAction SilentlyContinue) {
                    Write-LogBuild -Action COMPLETED -Iteration $script:Iteration -Details "All tasks completed"
                }
                # Save completion checkpoint and clear it
                if (Get-Command Save-CompletionCheckpoint -ErrorAction SilentlyContinue) {
                    Save-CompletionCheckpoint
                }
                break
            } else {
                # False positive - agent mentioned signal in explanation but tasks remain
                Write-VerboseOutput "Completion signal detected but $($verifyStats.Pending) tasks remain - continuing" -Category "Build"
            }
        }
        
        # Check if user requested to stop after this iteration
        if ((Get-Command Test-StopAfterIteration -ErrorAction SilentlyContinue) -and (Test-StopAfterIteration)) {
            Write-Ralph "Stopping loop as requested (completed iteration $Iteration)" -Type info
            if (Get-Command Write-LogBuild -ErrorAction SilentlyContinue) {
                Write-LogBuild -Action STOPPED -Iteration $script:Iteration -Details "User requested stop after iteration"
            }
            # Reset the interrupt state for next run
            if (Get-Command Reset-InterruptState -ErrorAction SilentlyContinue) {
                Reset-InterruptState
            }
            break
        }
        
        Start-Sleep -Seconds 2
    }
    
    # Check if all tasks are done at the end of the loop
    $finalStats = Get-TaskStats
    if ($finalStats.Pending -eq 0 -and $finalStats.Total -gt 0) {
        # Save completion checkpoint
        if (Get-Command Save-CompletionCheckpoint -ErrorAction SilentlyContinue) {
            Save-CompletionCheckpoint
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                        MAIN ENTRY
# ═══════════════════════════════════════════════════════════════

function Start-RalphLoop {
    # Set default model if not specified
    if ([string]::IsNullOrWhiteSpace($Model)) {
        $script:Model = $script:DefaultModel
    } else {
        $script:Model = $Model
    }
    
    # ═══════════════════════════════════════════════════════════════
    # PHASE 1: SESSIONS HOME - Select or create session
    # ═══════════════════════════════════════════════════════════════
    
    # Skip session selection if coming from ralph.ps1 with -Task parameter
    if (-not $Task -and $Mode -in 'auto', 'continue') {
        :sessionsHomeLoop while ($true) {
            $sessions = @(Get-AllTasks)
            $activeId = Get-ActiveTaskId
            
            # Get GitHub account and update status for display in menu
            $gitHubAccount = ''
            if (Get-Command -Name 'Get-GitHubAccountDisplay' -ErrorAction SilentlyContinue) {
                $gitHubAccount = Get-GitHubAccountDisplay
            }
            
            $sessionResult = Show-SessionsHomeMenu -Sessions $sessions -ActiveSessionId $activeId `
                -GitHubAccount $gitHubAccount
            
            switch ($sessionResult.Action) {
                'quit' {
                    Write-Ralph "Exiting Ralph." -Type info
                    return
                }
                'back' {
                    Write-Ralph "Exiting Ralph." -Type info
                    return
                }
                'new-session' {
                    # Create new session with simplified wizard
                    $newTask = New-TaskInteractive
                    if ($newTask -is [hashtable] -and $newTask.ContainsKey('Action') -and $newTask.Action -eq 'back') {
                        continue sessionsHomeLoop
                    }
                    if (-not $newTask) {
                        continue sessionsHomeLoop
                    }
                    # Session created and activated, proceed to session home
                    Update-TaskContext
                    break sessionsHomeLoop
                }
                'select-session' {
                    # User selected a session by number
                    $index = [int]$sessionResult.Key - 1
                    if ($index -ge 0 -and $index -lt $sessions.Count) {
                        $selectedTaskId = $sessions[$index].Id
                        Set-ActiveTask -TaskId $selectedTaskId
                        Update-TaskContext
                        
                        # Check if session needs recovery (has interrupted checkpoint)
                        if ((Get-Command Test-SessionNeedsRecovery -ErrorAction SilentlyContinue) -and 
                            (Test-SessionNeedsRecovery -TaskId $selectedTaskId)) {
                            
                            $recoveryInfo = Get-RecoveryInfo -TaskId $selectedTaskId
                            if ($recoveryInfo) {
                                $recoveryChoice = Show-RecoveryPrompt -TaskId $selectedTaskId -RecoveryInfo $recoveryInfo
                                
                                switch ($recoveryChoice) {
                                    'resume' {
                                        # Restore state from checkpoint
                                        $restoration = Invoke-Recovery -TaskId $selectedTaskId
                                        if ($restoration.Success) {
                                            Write-Host ""
                                            Write-Host "  ✓ Resuming from checkpoint..." -ForegroundColor Green
                                            Write-Host "    Phase: $($restoration.Phase)" -ForegroundColor Gray
                                            if ($restoration.Iteration -gt 0) {
                                                Write-Host "    Starting at iteration: $($restoration.Iteration)" -ForegroundColor Gray
                                            }
                                            Start-Sleep -Seconds 2
                                            # Continue to session home, which will handle resume
                                        }
                                    }
                                    'restart' {
                                        # Clear checkpoint and start fresh
                                        if (Get-Command Clear-Recovery -ErrorAction SilentlyContinue) {
                                            Clear-Recovery -TaskId $selectedTaskId
                                        }
                                        Write-Host ""
                                        Write-Host "  ✓ Starting fresh..." -ForegroundColor Green
                                        Start-Sleep -Seconds 1
                                    }
                                    'cancel' {
                                        # User wants to go back to session list
                                        continue sessionsHomeLoop
                                    }
                                }
                            }
                        }
                        
                        break sessionsHomeLoop
                    }
                    continue sessionsHomeLoop
                }
                'delete-session' {
                    # Show session list for deletion
                    if ($sessions.Count -gt 0) {
                        $sessionItems = @()
                        foreach ($s in $sessions) {
                            $marker = if ($s.Id -eq $activeId) { "► " } else { "" }
                            $sessionItems += @{
                                Label = "${marker}$($s.Name)"
                                Value = $s.Id
                                Description = $s.Description
                            }
                        }
                        
                        $selectResult = Show-ListSelectionMenu -Title "Select Session to Delete" -Items $sessionItems -AllowBack
                        
                        if ($selectResult.Action -eq 'select' -and $selectResult.Value) {
                            $confirmed = Show-DeleteConfirmMenu -ItemName $selectResult.Value -ItemType "session"
                            if ($confirmed) {
                                Remove-Task -TaskId $selectResult.Value
                                Write-Host "  ✓ Session deleted." -ForegroundColor Green
                                Start-Sleep -Seconds 1
                            }
                        }
                    }
                    continue sessionsHomeLoop
                }
                'update-ralph' {
                    # Check for and apply Ralph updates
                    Write-Host ""
                    Write-Host "  ═══════════════════════════════════════════" -ForegroundColor Cyan
                    Write-Host "  📦 RALPH UPDATE" -ForegroundColor Cyan
                    Write-Host "  ═══════════════════════════════════════════" -ForegroundColor Cyan
                    Write-Host ""
                    
                    $updateResult = Invoke-RalphUpdate -ProjectRoot $script:ProjectRoot
                    
                    if ($updateResult.Error) {
                        Write-Host "  Error: $($updateResult.Error)" -ForegroundColor Red
                    }
                    
                    Write-Host ""
                    Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                    $null = [Console]::ReadKey($true)
                    continue sessionsHomeLoop
                }
                default {
                    continue sessionsHomeLoop
                }
            }
        }
    }
    
    # Ensure we have an active task
    $activeTaskId = Get-ActiveTaskId
    if (-not $activeTaskId) {
        if (Test-DryRunEnabled) {
            $activeTaskId = "[DRY-RUN-SIMULATED-SESSION]"
            Write-Host "  [DRY RUN] Simulating active session for demonstration" -ForegroundColor Yellow
        } else {
            Write-Ralph "No active session. Please create one to continue." -Type error
            return
        }
    }
    
    # Get task info for display
    $activeTask = Get-AllTasks | Where-Object { $_.Id -eq $activeTaskId } | Select-Object -First 1
    $sessionName = if ($activeTask) { $activeTask.Name } else { $activeTaskId }
    
    # ═══════════════════════════════════════════════════════════════
    # AUTOSTART MODE - Skip interactive menus for automation
    # ═══════════════════════════════════════════════════════════════
    
    if ($AutoStart -and $Task) {
        # Verify we have specs configured
        $specsConfig = Get-TaskSpecsConfig -TaskId $activeTaskId
        $specsSummary = Get-TaskSpecsSummary -TaskId $activeTaskId
        $hasSpecs = $specsConfig.specsSource -ne 'none' -and $specsSummary -ne "Not configured" -and $specsSummary -ne "No specs"
        
        if (-not $hasSpecs) {
            Write-Ralph "AutoStart requires specs to be configured for task: $activeTaskId" -Type error
            return
        }
        
        Write-Ralph "AutoStart mode: skipping interactive menus..." -Type info
        # Fall through to build phase (skip the session home menu loop)
    }
    else {
    
    # ═══════════════════════════════════════════════════════════════
    # PHASE 2: SESSION HOME - Configure session settings, then start
    # ═══════════════════════════════════════════════════════════════
    
    :sessionHomeLoop while ($true) {
        # Get current configuration summaries
        $specsConfig = Get-TaskSpecsConfig -TaskId $activeTaskId
        $refsConfig = Get-TaskReferencesConfig -TaskId $activeTaskId
        $specsSummary = Get-TaskSpecsSummary -TaskId $activeTaskId
        $refsSummary = Get-TaskReferencesSummary -TaskId $activeTaskId
        
        # Determine if specs/refs are configured
        $hasSpecs = $specsConfig.specsSource -ne 'none' -and $specsSummary -ne "Not configured" -and $specsSummary -ne "No specs"
        
        # Check if references are configured - need actual files/dirs registered
        $refsFolder = Get-TaskReferencesFolder -TaskId $activeTaskId
        $hasRefsFiles = $refsFolder -and (Test-Path $refsFolder) -and 
                         @(Get-ChildItem -Path $refsFolder -File -ErrorAction SilentlyContinue | 
                           Where-Object { -not $_.Name.StartsWith('_') }).Count -gt 0
        $hasRefsDirs = $refsConfig.referenceDirectories -and $refsConfig.referenceDirectories.Count -gt 0
        $hasRefsCustomFiles = $refsConfig.referenceFiles -and $refsConfig.referenceFiles.Count -gt 0
        $hasReferences = $hasRefsFiles -or $hasRefsDirs -or $hasRefsCustomFiles
        
        # Get model display name
        $modelInfo = $AvailableModels | Where-Object { $_.Name -eq $script:Model } | Select-Object -First 1
        $currentModel = if ($modelInfo) { $modelInfo.Display } else { $script:Model }
        
        # Get verbose status
        $verboseStatus = if ($script:VerboseMode) { "ON" } else { "OFF" }
        
        # Get venv mode status
        $venvMode = Get-VenvModeSetting
        $venvStatus = $venvMode.ToUpper()
        
        # Get iterations display
        $iterDisplay = if ($MaxIterations -eq 0) { "unlimited" } else { "$MaxIterations" }
        
        # Get GitHub account info (for showing which account is using tokens)
        $gitHubAccount = ''
        $hasMultipleAccounts = $false
        if (Get-Command -Name 'Get-GitHubAccountDisplay' -ErrorAction SilentlyContinue) {
            $gitHubAccount = Get-GitHubAccountDisplay
            $hasMultipleAccounts = Test-MultipleGitHubAccounts
        }
        
        # Get checkpoint info for resume display
        $checkpointIteration = 0
        if ((Get-Command Get-Checkpoint -ErrorAction SilentlyContinue) -and 
            (Get-Command Test-SessionNeedsRecovery -ErrorAction SilentlyContinue)) {
            if (Test-SessionNeedsRecovery -TaskId $activeTaskId) {
                $checkpoint = Get-Checkpoint -TaskId $activeTaskId
                if ($checkpoint -and $checkpoint.iteration) {
                    $checkpointIteration = $checkpoint.iteration
                }
            }
        }
        
        $sessionHomeResult = Show-SessionHomeMenu -SessionId $activeTaskId -SessionName $sessionName `
            -SpecsSummary $specsSummary -ReferencesSummary $refsSummary `
            -CurrentModel $currentModel -VerboseStatus $verboseStatus -VenvStatus $venvStatus -MaxIterations $iterDisplay `
            -HasSpecs $hasSpecs -HasReferences $hasReferences `
            -GitHubAccount $gitHubAccount -HasMultipleAccounts $hasMultipleAccounts `
            -CheckpointIteration $checkpointIteration
        
        switch ($sessionHomeResult.Action) {
            'start' {
                # Check if we have at least specs OR references configured
                if (-not $hasSpecs -and -not $hasReferences) {
                    # Force spec creation - user must provide input
                    $specMode = Show-ArrowChoice -Title "⚠️  No specification found" -Message "Ralph needs a spec to understand what to build. Please create one first." -AllowBack -Choices @(
                        @{ Label = "Interview mode (Ralph asks questions)"; Value = "interview"; Hotkey = "1"; Default = $true }
                        @{ Label = "Quick mode (describe in one prompt)"; Value = "quick"; Hotkey = "2" }
                        @{ Label = "Add references first (images, docs, examples)"; Value = "references"; Hotkey = "3" }
                    )
                    
                    if ($specMode -eq 'references') {
                        Start-ReferenceSettingsWorkflow -TaskId $activeTaskId
                        continue sessionHomeLoop
                    } elseif ($specMode) {
                        $specResult = Invoke-SpecCreation -SpecMode $specMode
                        Clear-HostConditional
                        
                        # Re-check after spec creation
                        $specsConfig = Get-TaskSpecsConfig -TaskId $activeTaskId
                        $specsSummary = Get-TaskSpecsSummary -TaskId $activeTaskId
                        $hasSpecs = $specsConfig.specsSource -ne 'none' -and $specsSummary -ne "Not configured" -and $specsSummary -ne "No specs"
                        
                        if (-not $hasSpecs) {
                            Write-Host "  ℹ️  Spec creation was not completed. Please try again." -ForegroundColor Yellow
                            Start-Sleep -Seconds 2
                            continue sessionHomeLoop
                        }
                    } else {
                        continue sessionHomeLoop
                    }
                } elseif (-not $hasSpecs -and $hasReferences) {
                    # Has references but no specs - offer to build spec from references
                    $specMode = Show-ArrowChoice -Title "⚠️  No specification found" -Message "You have references configured. Create a spec from them or provide one manually." -AllowBack -Choices @(
                        @{ Label = "Interview mode (Ralph asks questions)"; Value = "interview"; Hotkey = "1"; Default = $true }
                        @{ Label = "Quick mode (describe in one prompt)"; Value = "quick"; Hotkey = "2" }
                        @{ Label = "Build spec from references"; Value = "from-references"; Hotkey = "3" }
                    )
                    
                    if ($specMode) {
                        $specResult = Invoke-SpecCreation -SpecMode $specMode
                        Clear-HostConditional
                        
                        # Re-check after spec creation
                        $specsConfig = Get-TaskSpecsConfig -TaskId $activeTaskId
                        $specsSummary = Get-TaskSpecsSummary -TaskId $activeTaskId
                        $hasSpecs = $specsConfig.specsSource -ne 'none' -and $specsSummary -ne "Not configured" -and $specsSummary -ne "No specs"
                        
                        if (-not $hasSpecs) {
                            Write-Host "  ℹ️  Spec creation was not completed. Please try again." -ForegroundColor Yellow
                            Start-Sleep -Seconds 2
                            continue sessionHomeLoop
                        }
                    } else {
                        continue sessionHomeLoop
                    }
                }
                
                # User clicked Start Ralph - proceed to build
                break sessionHomeLoop
            }
            'back' {
                # Go back to sessions home
                Start-RalphLoop
                return
            }
            'references' {
                # Show references configuration menu
                Start-ReferenceSettingsWorkflow -TaskId $activeTaskId
                continue sessionHomeLoop
            }
            'specs-settings' {
                # Show specs configuration menu
                Start-SpecsSettingsWorkflow -TaskId $activeTaskId
                continue sessionHomeLoop
            }
            'change-model' {
                $newModel = Show-ModelMenu
                if ($newModel) {
                    $script:Model = $newModel
                }
                continue sessionHomeLoop
            }
            'toggle-verbose' {
                $script:VerboseMode = -not $script:VerboseMode
                continue sessionHomeLoop
            }
            'toggle-venv' {
                # Cycle venv mode: auto → always → disabled → auto
                $currentMode = Get-VenvModeSetting
                $newMode = switch ($currentMode) {
                    'auto' { 'always' }
                    'always' { 'disabled' }
                    default { 'auto' }
                }
                Set-VenvMode -Mode $newMode
                
                # Show confirmation message with mode description
                $modeDesc = switch ($newMode) {
                    'auto' { "AUTO (detect if project needs venv)" }
                    'always' { "ALWAYS (always create venv)" }
                    'disabled' { "DISABLED (install to system - not recommended)" }
                }
                Write-Host ""
                Write-Host "  ✓ Virtual environment mode: $modeDesc" -ForegroundColor Green
                Write-Host "  ℹ️  Change will take effect on next Ralph start" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                continue sessionHomeLoop
            }
            'set-iterations' {
                $stats = Get-TaskStats
                $newMax = Show-IterationMenu -PendingTasks $stats.Pending -CurrentMax $MaxIterations
                if ($null -ne $newMax) {
                    $MaxIterations = $newMax
                }
                continue sessionHomeLoop
            }
            'switch-account' {
                # Show GitHub account switching menu (only available if multiple accounts)
                if (Get-Command -Name 'Get-GitHubAccounts' -ErrorAction SilentlyContinue) {
                    $accounts = Get-GitHubAccounts
                    $currentDisplay = Get-GitHubAccountDisplay
                    $accountResult = Show-GitHubAccountMenu -Accounts $accounts -CurrentAccount $currentDisplay
                    
                    if ($accountResult.Action -eq 'select' -and $accountResult.Account) {
                        $success = Switch-GitHubAccount -Username $accountResult.Account.Username -Hostname $accountResult.Account.Host
                        if ($success) {
                            Write-Host ""
                            Write-Host "  ✓ Switched to: $($accountResult.Account.Display)" -ForegroundColor Green
                        } else {
                            Write-Host ""
                            Write-Host "  ✗ Failed to switch account" -ForegroundColor Red
                        }
                        Start-Sleep -Seconds 1
                    } elseif ($accountResult.Action -eq 'login') {
                        Write-Host ""
                        Invoke-GitHubLogin
                        Write-Host ""
                        Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    }
                }
                continue sessionHomeLoop
            }
            'quit' {
                return
            }
            default {
                continue sessionHomeLoop
            }
        }
    }
    
    } # End of else block for non-AutoStart mode
    
    # ═══════════════════════════════════════════════════════════════
    # PHASE 3: BUILD PHASE - Execute the actual work
    # ═══════════════════════════════════════════════════════════════
    
    # Clear screen before starting build phase
    Clear-HostConditional
    Write-Host ""
    
    $modeText = switch ($Mode) {
        'auto'     { 'AUTO (agents, plan if needed, then build)' }
        'continue' { 'CONTINUE PROJECT' }
        'plan'     { 'PLAN ONLY' }
        'build'    { 'BUILD ONLY' }
        'agents'   { 'AGENTS.MD UPDATE ONLY' }
    }
    
    Write-Ralph "RALPH LOOP - $modeText" -Type header
    
    # Show current session
    Write-Host "  Session: " -NoNewline -ForegroundColor White
    if ($activeTask) {
        Write-Host "$sessionName" -ForegroundColor Green
        Write-Host "           ($activeTaskId)" -ForegroundColor DarkGray
    } else {
        Write-Host $activeTaskId -ForegroundColor Cyan
    }
    
    # Check prerequisites
    if (-not (Test-CopilotCLI)) { return }
    
    $branch = Get-CurrentBranch
    Write-Host "  Branch: $branch" -ForegroundColor White
    $iterDisplay = if ($MaxIterations -eq 0) { "unlimited (until complete)" } else { "$MaxIterations" }
    Write-Host "  Max iterations: $iterDisplay" -ForegroundColor White
    
    # Show model
    $modelInfo = $AvailableModels | Where-Object { $_.Name -eq $script:Model } | Select-Object -First 1
    $modelDisplay = if ($modelInfo) { "$($modelInfo.Display) ($($modelInfo.Multiplier))" } else { $script:Model }
    Write-Host "  Model: " -NoNewline -ForegroundColor White
    Write-Host $modelDisplay -ForegroundColor Green
    
    # Show verbose mode status
    Write-Host "  Verbose: " -NoNewline -ForegroundColor White
    if ($script:VerboseMode) {
        Write-Host "ON" -ForegroundColor Cyan
    } else {
        Write-Host "OFF" -ForegroundColor DarkGray
    }
    
    # Setup Python venv isolation
    # Check if venv mode is overridden in settings (persisted preference)
    $venvMode = Get-VenvModeSetting
    # Allow settings to override unless reset was explicitly requested
    if ($Venv -ne 'reset') {
        $Venv = $venvMode
    }
    
    $venvScript = Join-Path $script:CoreDir 'venv.ps1'
    if (Test-Path $venvScript) {
        switch ($Venv) {
            'disabled' {
                Write-Host "  Venv: DISABLED (installing to system)" -ForegroundColor Yellow
            }
            'always' {
                Write-Host "  Venv mode: always" -ForegroundColor White
                if (Enable-RalphVenv) {
                    Write-Host "  Venv: ACTIVE" -ForegroundColor Green
                } else {
                    Write-Host "  Venv: Not available (Python not found)" -ForegroundColor Yellow
                }
            }
            'reset' {
                Write-Host "  Venv mode: reset" -ForegroundColor White
                Remove-RalphVenv | Out-Null
                if (Enable-RalphVenv) {
                    Write-Host "  Venv: RECREATED" -ForegroundColor Green
                } else {
                    Write-Host "  Venv: Not available (Python not found)" -ForegroundColor Yellow
                }
            }
            default {
                # 'auto' mode - intelligently detect if venv is needed
                Write-Host "  Venv mode: auto" -ForegroundColor White
                if (Test-VenvNeeded -ProjectRoot $script:ProjectRoot) {
                    if (Enable-RalphVenv) {
                        Write-Host "  Venv: ACTIVE (Python project detected)" -ForegroundColor Green
                    } else {
                        Write-Host "  Venv: Not available (Python not found)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  Venv: SKIPPED (no Python dependencies detected)" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "  Venv: Module not found" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # Re-initialize context in case task changed
    Update-TaskContext
    
    # Initialize required files if missing
    Initialize-RalphInstructions
    Initialize-ProgressFile
    Initialize-PlanFile
    
    # Initialize session statistics tracking
    Initialize-SessionStats
    
    # Log current settings at session start
    if (Get-Command Write-LogSettings -ErrorAction SilentlyContinue) {
        Write-LogSession -Action STARTED -SessionName $sessionName -Details "Mode: $Mode"
        Write-LogSettings -Settings @{
            Mode = $Mode
            Model = $script:Model
            MaxIterations = if ($MaxIterations -eq 0) { "unlimited" } else { $MaxIterations }
            VerboseMode = $script:VerboseMode
            DeveloperMode = $script:DeveloperMode
            Venv = $Venv
            DryRun = (Test-DryRunEnabled)
            Branch = $branch
            SessionId = $activeTaskId
            SessionName = $sessionName
            ProjectRoot = $script:ProjectRoot
        }
    }
    
    # Check if specs are configured - prompt if not
    $specsConfig = Get-TaskSpecsConfig -TaskId $activeTaskId
    $specsSummary = Get-TaskSpecsSummary -TaskId $activeTaskId
    
    # Handle all cases where specs are missing or not configured
    if ($specsSummary -in @("No specs", "Not configured", "Folder not found")) {
        Write-Host ""
        Write-Host "  ⚠️  No specifications configured for this session" -ForegroundColor Yellow
        Write-Host "     Create specs before building, or Ralph will need to create them first." -ForegroundColor Gray
        Write-Host ""
        
        $createNow = Show-ArrowConfirm -Message "Create a spec now?" -DefaultYes
        if ($createNow) {
            # Check if there are active references
            $hasReferences = $false
            if ($activeTaskId -and (Get-Command Load-SessionReferences -ErrorAction SilentlyContinue)) {
                Load-SessionReferences -TaskId $activeTaskId | Out-Null
                if (Get-Command Get-AllSessionReferences -ErrorAction SilentlyContinue) {
                    $allRefs = @(Get-AllSessionReferences)
                    $hasReferences = ($allRefs.Count -gt 0)
                }
            }
            
            # Build choice list based on whether references exist
            $choices = @(
                @{ Label = "Interview mode (Ralph asks questions)"; Value = "interview"; Hotkey = "1"; Default = $true }
                @{ Label = "Quick mode (describe in one prompt)"; Value = "quick"; Hotkey = "2" }
            )
            
            if ($hasReferences) {
                $choices += @{ Label = "Build spec from references"; Value = "from-references"; Hotkey = "3" }
            }
            
            $specMode = Show-ArrowChoice -Title "Select Spec Creation Mode" -AllowBack -Choices $choices
            
            if ($specMode) {
                $specResult = Invoke-SpecCreation -SpecMode $specMode
                Clear-HostConditional
            }
        }
    }
    
    # Determine what to do based on mode
    switch ($Mode) {
        'agents' {
            Invoke-AgentsUpdate | Out-Null
        }
        'plan' {
            if (-not (Test-HasUserSpecs)) {
                Write-Ralph "No specs found. Create specs first or use auto mode." -Type warning
                return
            }
            # Setup project structure before planning
            if (-not (Invoke-ProjectSetup)) {
                return
            }
            Invoke-Planning | Out-Null
        }
        'build' {
            $stats = Get-TaskStats
            if ($stats.Pending -eq 0) {
                if ($stats.Total -eq 0) {
                    Write-Ralph "No tasks found. Run with -Mode auto or -Mode plan first." -Type warning
                } else {
                    Write-Ralph "All $($stats.Total) tasks already completed!" -Type success
                }
                return
            }
            # Setup project structure before building
            if (-not (Invoke-ProjectSetup)) {
                return
            }
            $buildResult = Invoke-Building
            if ($buildResult -is [hashtable] -and $buildResult.ContainsKey('Cancelled') -and $buildResult.Cancelled) {
                # User cancelled - go back to session home
                Start-RalphLoop
                return
            }
        }
        { $_ -in 'auto', 'continue' } {
            # Setup project structure before auto/continue mode
            if (-not (Invoke-ProjectSetup)) {
                return
            }
            
            # Auto/Continue mode: update AGENTS.md, plan if needed, then build
            Invoke-AgentsUpdate | Out-Null
            
            if (Test-NeedsPlanning) {
                $stats = Get-TaskStats
                if ($stats.Total -eq 0) {
                    Write-Ralph "No existing plan. Running planning phase..." -Type info
                } else {
                    Write-Ralph "All tasks complete. Re-running planning to find new work..." -Type info
                }
                
                $planResult = Invoke-Planning
                if ($planResult -is [hashtable] -and $planResult.ContainsKey('Cancelled') -and $planResult.Cancelled) {
                    # User cancelled during planning - go back to session home
                    Start-RalphLoop
                    return
                }
                if (-not $planResult) {
                    Write-Ralph "Planning did not create tasks. Nothing to build." -Type warning
                    return
                }
            }
            
            $buildResult = Invoke-Building
            if ($buildResult -is [hashtable] -and $buildResult.ContainsKey('Cancelled') -and $buildResult.Cancelled) {
                # User cancelled - go back to session home
                Start-RalphLoop
                return
            }
        }
    }
    
    # Show comprehensive session summary
    Show-SessionSummary -Iterations $Iteration -StartTime $SessionStart
    
    # Close logging session with summary
    if (Get-Command Close-Logging -ErrorAction SilentlyContinue) {
        Close-Logging -Stats $script:SessionStats
    }
    
    # Show dry-run summary if applicable
    if (Test-DryRunEnabled) {
        Show-DryRunSummary
    }
    
    # Show post-session menu for user to choose next action
    # Skip if running with -Task parameter (one-shot mode) or in dry-run mode
    if (-not $Task -and -not (Test-DryRunEnabled)) {
        $taskStats = Get-TaskStats
        :sessionEndLoop while ($true) {
            $endMenuResult = Show-SessionEndMenu -TasksRemaining $taskStats.Pending -TasksTotal $taskStats.Total -SessionCompleted:($taskStats.Pending -eq 0)
            
            switch ($endMenuResult.Action) {
                'continue' {
                    # Resume building - reset iteration counter for new session
                    $script:Iteration = 0
                    $script:SessionStart = Get-Date
                    $buildResult = Invoke-Building
                    if ($buildResult -is [hashtable] -and $buildResult.ContainsKey('Cancelled') -and $buildResult.Cancelled) {
                        # User cancelled during building - show summary again
                        $taskStats = Get-TaskStats
                        Show-SessionSummary -Iterations $Iteration -StartTime $script:SessionStart
                        continue sessionEndLoop
                    }
                    # Building completed - refresh stats and show summary again
                    $taskStats = Get-TaskStats
                    Show-SessionSummary -Iterations $Iteration -StartTime $script:SessionStart
                    continue sessionEndLoop
                }
                'back' {
                    # Return to session home - restart the loop
                    Start-RalphLoop
                    return
                }
                'quit' {
                    Write-Ralph "Exiting Ralph." -Type info
                    break sessionEndLoop
                }
                default {
                    # ESC or unknown - treat as quit
                    Write-Ralph "Exiting Ralph." -Type info
                    break sessionEndLoop
                }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                         ENTRY POINT
# ═══════════════════════════════════════════════════════════════

try {
    Start-RalphLoop
}
catch {
    Write-Host ""
    Write-Host "FATAL ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    
    # Log fatal error if logging is available
    if (Get-Command Write-LogError -ErrorAction SilentlyContinue) {
        Write-LogError -Message "FATAL ERROR: $_" -Exception $_
    }
    
    exit 1
}


