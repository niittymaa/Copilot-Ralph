<#
.SYNOPSIS
    Ralph - Autonomous AI coding agent orchestrator for GitHub Copilot CLI

.DESCRIPTION
    Entry point for the Ralph Loop system. Self-contained in the ralph/ folder.
    
    On first run, automatically sets up the target project:
    - Creates .github/instructions/ralph.instructions.md (Ralph config)
    - Creates .github/agents/ with agent files
    - Creates ralph/specs/ folder with template
    - Creates .ralph/ cache folder
    - Optionally creates AGENTS.md (prompts user)
    
    By default, Ralph auto-detects what's needed:
    - If no plan or no pending tasks → runs planning first
    - Then proceeds to build mode automatically

.PARAMETER Mode
    Operation mode: 'auto' (default), 'plan', 'build', 'agents', 'continue', 'sessions', or 'benchmark'
    - auto: Shows session menu, plans if needed, then builds (recommended)
    - continue: Continue existing project - shows spec menu to use existing or add new specs
    - plan: Only run planning, don't build
    - build: Only run building, skip planning
    - agents: Only update AGENTS.md from codebase analysis
    - sessions: Session management - list, switch, create, or delete sessions
    - benchmark: Run Tetris benchmark to test Ralph quality (use with -Quick for faster results)

.PARAMETER Model
    AI model to use (e.g., 'claude-sonnet-4', 'gpt-4.1', 'claude-sonnet-4.5')
    If not specified, uses Copilot CLI default model

.PARAMETER MaxIterations
    Maximum build iterations. Default: 0 (unlimited - runs until all tasks complete)

.PARAMETER Agent
    Custom agent file to use

.PARAMETER Delegate
    Hand off to Copilot coding agent (background execution)

.PARAMETER Manual
    Display prompts for copy/paste to Copilot Chat

.PARAMETER AutoStart
    Skip interactive menus and start building immediately.
    Requires -Session to be specified with a valid session ID that has specs configured.
    Used for automation/optimization experiments.

.PARAMETER ShowVerbose
    Enable verbose mode - shows detailed output including Copilot CLI responses,
    file operations, and internal state changes

.PARAMETER Venv
    Python venv handling: 'auto' (default), 'skip', or 'reset'
    - auto: Create venv if needed, activate for all operations
    - skip: Don't use venv isolation
    - reset: Remove and recreate venv before running

.PARAMETER Session
    Session ID to switch to before running. Use with any mode to work on a specific session.

.PARAMETER NewSession
    Create a new session with the given name and switch to it.

.PARAMETER ListModels
    Display available AI models and exit

.PARAMETER Memory
    Cross-session memory control: 'on', 'off', or 'status'
    - on: Enable memory system (records learnings across sessions)
    - off: Disable memory system
    - status: Show current memory status and exit

.PARAMETER DryRun
    Preview mode - shows what Ralph would do without making any changes
    - NO AI tokens spent (completely free)
    - NO files modified
    - Shows detailed preview of all operations
    Perfect for testing and understanding the system

.EXAMPLE
    ./ralph/ralph.ps1
    Auto mode: shows session menu, plans if needed, then builds

.EXAMPLE
    ./ralph/ralph.ps1 -Model claude-sonnet-4
    Run with Claude Sonnet 4 model

.EXAMPLE
    ./ralph/ralph.ps1 -Mode sessions
    Interactive session management menu

.EXAMPLE
    ./ralph/ralph.ps1 -Memory status
    Show memory system status

.EXAMPLE
    ./ralph/ralph.ps1 -DryRun
    Preview what Ralph would do without making changes (FREE - no AI tokens)

.EXAMPLE
    ./ralph/ralph.ps1 -DryRun -Mode plan
    Preview the planning phase without executing
#>

[CmdletBinding()]
param(
    [ValidateSet('auto', 'plan', 'build', 'agents', 'continue', 'sessions', 'benchmark')]
    [string]$Mode = 'auto',
    
    [string]$Model = '',
    
    [switch]$ListModels,
    
    [int]$MaxIterations = 0,
    
    [string]$Agent = '',
    
    [switch]$Delegate,
    
    [switch]$Manual,
    
    [switch]$AutoStart,
    
    [string]$Session = '',
    
    [string]$NewSession = '',
    
    [switch]$ShowVerbose,
    
    [ValidateSet('auto', 'skip', 'reset')]
    [string]$Venv = 'auto',
    
    [ValidateSet('on', 'off', 'status', '')]
    [string]$Memory = '',
    
    [switch]$DryRun,
    
    [switch]$Quick
)

$ErrorActionPreference = 'Stop'

# ═══════════════════════════════════════════════════════════════
#                     PATH RESOLUTION
# ═══════════════════════════════════════════════════════════════

# Ralph folder (where this script lives)
$script:RalphDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# Project root (parent of ralph folder)
$script:ProjectRoot = Split-Path -Parent $script:RalphDir
# Core scripts location
$script:CoreDir = Join-Path $script:RalphDir 'core'
# Templates location
$script:TemplatesDir = Join-Path $script:RalphDir 'templates'
# Agent source files
$script:AgentSourceDir = Join-Path $script:RalphDir 'agents'

# ═══════════════════════════════════════════════════════════════
#                     GLOBAL KEYBOARD HANDLER
# ═══════════════════════════════════════════════════════════════

# Load and initialize global keyboard handler for CTRL+C double-press detection
$globalKeyHandlerPath = Join-Path $script:RalphDir 'cli\ps\globalKeyHandler.ps1'
if (Test-Path $globalKeyHandlerPath) {
    try {
        . $globalKeyHandlerPath
        Initialize-GlobalKeyHandler
        Write-Verbose "Global keyboard handler initialized (CTRL+C double-press enabled)"
    } catch {
        Write-Verbose "Could not initialize global keyboard handler: $_"
    }
} else {
    # Fallback: Use default PowerShell CTRL+C behavior
    [Console]::TreatControlCAsInput = $false
    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        [Console]::CursorVisible = $true
    }
}

# ═══════════════════════════════════════════════════════════════
#                     CONFIGURATION
# ═══════════════════════════════════════════════════════════════

function Get-RalphConfig {
    <#
    .SYNOPSIS
        Loads Ralph configuration from ralph/config.json
    .DESCRIPTION
        Returns configuration settings including developer_mode, verbose_mode, venv_mode.
        Creates default config if it doesn't exist.
    .OUTPUTS
        Hashtable with configuration settings
    #>
    $configPath = Join-Path $script:RalphDir 'config.json'
    
    # Create default config if it doesn't exist
    if (-not (Test-Path $configPath)) {
        $defaultConfig = @{
            developer_mode = $false
            verbose_mode = $true
            venv_mode = 'auto'
        }
        $defaultConfig | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
        return $defaultConfig
    }
    
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
        return $config
    } catch {
        Write-Warning "Failed to load config.json, using defaults: $_"
        return @{
            developer_mode = $false
            verbose_mode = $true
            venv_mode = 'auto'
        }
    }
}

# Load configuration early
$script:RalphConfig = Get-RalphConfig

# ═══════════════════════════════════════════════════════════════
#                     AUTO-SETUP FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Initialize-RalphCache {
    <#
    .SYNOPSIS
        Creates .ralph/ cache folder for session management
        
    .DESCRIPTION
        Only creates the minimal structure needed for session/task management.
        Full project setup (specs, agents, instructions) is deferred until
        the build process actually starts.
    #>
    $ralphCacheDir = Join-Path $ProjectRoot '.ralph'
    if (-not (Test-Path $ralphCacheDir)) {
        New-Item -ItemType Directory -Path $ralphCacheDir -Force | Out-Null
    }
}

# ═══════════════════════════════════════════════════════════════
#                     LIST MODELS
# ═══════════════════════════════════════════════════════════════

if ($ListModels) {
    Write-Host ""
    Write-Host "Available AI Models for GitHub Copilot CLI:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Anthropic Claude:" -ForegroundColor White
    Write-Host "    claude-sonnet-4.5    - Claude Sonnet 4.5 (recommended)" -ForegroundColor Gray
    Write-Host "    claude-sonnet-4      - Claude Sonnet 4" -ForegroundColor Gray
    Write-Host "    claude-haiku-4.5     - Claude Haiku 4.5 (fast/cheap)" -ForegroundColor Gray
    Write-Host "    claude-opus-4.5      - Claude Opus 4.5 (premium)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  OpenAI GPT:" -ForegroundColor White
    Write-Host "    gpt-5.2-codex        - GPT-5.2 Codex" -ForegroundColor Gray
    Write-Host "    gpt-5.1-codex-max    - GPT-5.1 Codex Max" -ForegroundColor Gray
    Write-Host "    gpt-5.1-codex        - GPT-5.1 Codex" -ForegroundColor Gray
    Write-Host "    gpt-5.1-codex-mini   - GPT-5.1 Codex Mini (fast/cheap)" -ForegroundColor Gray
    Write-Host "    gpt-5.2              - GPT-5.2" -ForegroundColor Gray
    Write-Host "    gpt-5.1              - GPT-5.1" -ForegroundColor Gray
    Write-Host "    gpt-5                - GPT-5" -ForegroundColor Gray
    Write-Host "    gpt-5-mini           - GPT-5 Mini (fast/cheap)" -ForegroundColor Gray
    Write-Host "    gpt-4.1              - GPT-4.1 (fast/cheap)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Google Gemini:" -ForegroundColor White
    Write-Host "    gemini-3-pro-preview - Gemini 3 Pro (preview)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Usage: ./ralph/ralph.ps1 -Model <model-name>" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# ═══════════════════════════════════════════════════════════════
#                     MEMORY MANAGEMENT
# ═══════════════════════════════════════════════════════════════

# Source memory module
$memoryScript = Join-Path $CoreDir 'memory.ps1'
if (Test-Path $memoryScript) {
    . $memoryScript
    Initialize-MemorySystem -ProjectRoot $script:ProjectRoot
}

# Handle -Memory parameter
if ($Memory) {
    switch ($Memory.ToLower()) {
        'on' {
            Set-MemoryEnabled -Enabled $true
            Write-Host ""
            Write-Host "  ✓ Memory system ENABLED" -ForegroundColor Green
            Write-Host "    Learnings will be recorded across sessions." -ForegroundColor Gray
            Write-Host "    File: .ralph/memory.md" -ForegroundColor Gray
            Write-Host ""
            exit 0
        }
        'off' {
            Set-MemoryEnabled -Enabled $false
            Write-Host ""
            Write-Host "  ✓ Memory system DISABLED" -ForegroundColor Yellow
            Write-Host "    Learnings will not be recorded." -ForegroundColor Gray
            Write-Host ""
            exit 0
        }
        'status' {
            Show-MemoryStatus
            exit 0
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                     MINIMAL SETUP
# ═══════════════════════════════════════════════════════════════

# Only create .ralph/ cache folder (needed for session management)
# Full project setup is deferred until build process starts
Initialize-RalphCache

# ═══════════════════════════════════════════════════════════════
#                     DRY-RUN MODULE
# ═══════════════════════════════════════════════════════════════

# Source the dry-run module early (needed for session mode too)
$dryrunScript = Join-Path $CoreDir 'dryrun.ps1'
if (Test-Path $dryrunScript) {
    . $dryrunScript
}

# Enable dry-run mode if parameter was passed
if ($DryRun) {
    Enable-DryRun
}

# ═══════════════════════════════════════════════════════════════
#                     GITHUB AUTH MODULE
# ═══════════════════════════════════════════════════════════════

# Source the GitHub auth module for account display/switching
$githubauthScript = Join-Path $CoreDir 'github-auth.ps1'
if (Test-Path $githubauthScript) {
    . $githubauthScript
}

# ═══════════════════════════════════════════════════════════════
#                     CORE SCRIPT VALIDATION
# ═══════════════════════════════════════════════════════════════

$loopScript = Join-Path $CoreDir 'loop.ps1'
if (-not (Test-Path $loopScript)) {
    Write-Host "Error: Ralph core not found at $loopScript" -ForegroundColor Red
    Write-Host "Ensure the ralph/core/ directory contains loop.ps1" -ForegroundColor Yellow
    exit 1
}

# ═══════════════════════════════════════════════════════════════
#                     UPDATE CHECK ON STARTUP
# ═══════════════════════════════════════════════════════════════

# Source update module and show notification if updates available
# Only check in interactive modes (not AutoStart, not benchmark)
if (-not $AutoStart -and $Mode -notin 'benchmark') {
    $updateScript = Join-Path $CoreDir 'update.ps1'
    if (Test-Path $updateScript) {
        . $updateScript
        # Silent check - just show notification, don't block
        $null = Show-UpdateNotification -ProjectRoot $script:ProjectRoot
    }
}

# ═══════════════════════════════════════════════════════════════
#                     BENCHMARK MODE
# ═══════════════════════════════════════════════════════════════

if ($Mode -eq 'benchmark') {
    $benchmarkScript = Join-Path $script:RalphDir 'optimizer\benchmark.ps1'
    if (-not (Test-Path $benchmarkScript)) {
        Write-Host "Error: Benchmark script not found at $benchmarkScript" -ForegroundColor Red
        exit 1
    }
    
    $benchParams = @{}
    if ($Model) { $benchParams.Model = $Model }
    if ($MaxIterations -gt 0) { $benchParams.MaxIterations = $MaxIterations }
    if ($Quick) { $benchParams.Quick = $true }
    
    & $benchmarkScript @benchParams
    exit $LASTEXITCODE
}

# ═══════════════════════════════════════════════════════════════
#                     SESSION MANAGEMENT
# ═══════════════════════════════════════════════════════════════

if ($Mode -eq 'sessions' -or $NewSession -or $Session) {
    # Source menus module FIRST (tasks module depends on it)
    $menusScript = Join-Path $CoreDir 'menus.ps1'
    if (-not (Test-Path $menusScript)) {
        Write-Host "Error: Menus module not found at $menusScript" -ForegroundColor Red
        exit 1
    }
    . $menusScript
    Initialize-MenuSystem -ProjectRoot $script:ProjectRoot
    
    # Source tasks module for standalone session operations
    $tasksScript = Join-Path $CoreDir 'tasks.ps1'
    if (-not (Test-Path $tasksScript)) {
        Write-Host "Error: Tasks module not found at $tasksScript" -ForegroundColor Red
        exit 1
    }
    . $tasksScript
    Initialize-TaskPaths -ProjectRoot $script:ProjectRoot
    Initialize-TaskSystem
    
    # Handle -NewSession parameter
    if ($NewSession) {
        Write-Host ""
        Write-Host "Creating new session: $NewSession" -ForegroundColor Cyan
        try {
            $task = New-Task -Name $NewSession
            Set-ActiveTask -TaskId $task.Id
            Write-Host "Session created and activated: $($task.Id)" -ForegroundColor Green
            Write-Host "Directory: $($task.Directory)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Run './ralph/ralph.ps1' to start working on this session." -ForegroundColor Yellow
            exit 0
        } catch {
            Write-Host "Failed to create session: $_" -ForegroundColor Red
            exit 1
        }
    }
    
    # Handle -Session parameter (switch to existing session)
    if ($Session) {
        if (-not (Test-TaskExists -TaskId $Session)) {
            Write-Host "Error: Session '$Session' does not exist" -ForegroundColor Red
            Write-Host "Use './ralph/ralph.ps1 -Mode sessions' to see available sessions." -ForegroundColor Yellow
            exit 1
        }
        Set-ActiveTask -TaskId $Session
        Write-Host "Switched to session: $Session" -ForegroundColor Green
        
        # Continue with normal operation if other mode wasn't 'sessions'
        if ($Mode -eq 'sessions') {
            exit 0
        }
    }
    
    # Interactive session management menu
    if ($Mode -eq 'sessions') {
        while ($true) {
            $sessions = @(Get-AllTasks)
            $activeId = Get-ActiveTaskId
            $result = Show-SessionsHomeMenu -Sessions $sessions -ActiveSessionId $activeId
            
            switch ($result.Action) {
                'select-session' {
                    $index = [int]$result.Key - 1
                    if ($index -ge 0 -and $index -lt $sessions.Count) {
                        Set-ActiveTask -TaskId $sessions[$index].Id
                        Write-Host ""
                        Write-Host "Switched to session: $($sessions[$index].Name)" -ForegroundColor Green
                    }
                    continue
                }
                'new-session' {
                    $newTask = New-TaskInteractive
                    if ($newTask -is [hashtable] -and $newTask.Action -eq 'back') {
                        continue  # Go back to session menu
                    }
                    if ($newTask) {
                        Write-Host ""
                        Write-Host "Run './ralph/ralph.ps1' to start working on this session." -ForegroundColor Yellow
                    }
                    continue
                }
                'delete-session' {
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
                                Write-Host "  Session deleted." -ForegroundColor Green
                            }
                        }
                    }
                    continue
                }
                'quit' {
                    exit 0
                }
                'back' {
                    exit 0
                }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                     INVOKE CORE LOOP
# ═══════════════════════════════════════════════════════════════

$params = @{
    Mode = $Mode
    MaxIterations = $MaxIterations
    Venv = $Venv
    DeveloperMode = $script:RalphConfig.developer_mode
}

if ($Model) { $params.Model = $Model }
if ($Agent) { $params.Agent = $Agent }
if ($Delegate) { $params.Delegate = $true }
if ($Manual) { $params.Manual = $true }
if ($AutoStart) { $params.AutoStart = $true }
if ($ShowVerbose) { $params.ShowVerbose = $true }
if ($Session) { $params.Task = $Session }
if ($DryRun) { $params.DryRun = $true }

& $loopScript @params
