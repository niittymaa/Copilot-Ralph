<#
.SYNOPSIS
    Install, update, or uninstall Ralph in any project.

.DESCRIPTION
    Downloads the Ralph autonomous AI coding agent framework into the current
    directory. Run this at the root of your project.

    If Ralph is already installed, presents an interactive menu with options
    to fresh install, update, uninstall, or cancel.

    Usage:
        irm https://raw.githubusercontent.com/niittymaa/Copilot-Ralph/main/install.ps1 | iex

    Or with options:
        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/niittymaa/Copilot-Ralph/main/install.ps1))) -NoStart
        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/niittymaa/Copilot-Ralph/main/install.ps1))) -Branch develop

.PARAMETER Branch
    Branch to install from (default: main)

.PARAMETER NoStart
    Install only, don't start Ralph after installation

.PARAMETER Force
    Skip interactive prompts (use with -Action)

.PARAMETER Action
    Pre-select action when Ralph exists: 'fresh', 'update', 'uninstall'
    Useful for scripted/CI usage with -Force
#>

[CmdletBinding()]
param(
    [string]$Branch = "main",
    [switch]$NoStart,
    [switch]$Force,
    [ValidateSet('', 'fresh', 'update', 'uninstall')]
    [string]$Action = ''
)

$ErrorActionPreference = 'Stop'

$RepoUrl = "https://github.com/niittymaa/Copilot-Ralph.git"
$RalphDir = Join-Path $PWD "ralph"
$RalphDataDir = Join-Path $PWD ".ralph"
$GithubDir = Join-Path $PWD ".github"
$AgentsDir = Join-Path $GithubDir "agents"
$InstructionsDir = Join-Path $GithubDir "instructions"
$AgentsMdPath = Join-Path $PWD "AGENTS.md"

# Ralph agent files that get copied to .github/agents/
$RalphAgentFiles = @(
    "ralph.agent.md",
    "ralph-planner.agent.md",
    "ralph-spec-creator.agent.md",
    "ralph-agents-updater.agent.md"
)

# ═══════════════════════════════════════════════════════════════
#                     DISPLAY
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  RALPH INSTALLER - Autonomous AI Coding Agent" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════════
#                     DISCLAIMER
# ═══════════════════════════════════════════════════════════════

if (-not $Force) {
    Write-Host "  ┌─────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │                    ⚠️  DISCLAIMER                       │" -ForegroundColor Yellow
    Write-Host "  │                                                         │" -ForegroundColor Yellow
    Write-Host "  │  Ralph is an autonomous AI coding agent that modifies   │" -ForegroundColor Yellow
    Write-Host "  │  your codebase. By installing, you acknowledge:         │" -ForegroundColor Yellow
    Write-Host "  │                                                         │" -ForegroundColor Yellow
    Write-Host "  │  • Ralph will read, write, and delete files in your     │" -ForegroundColor Yellow
    Write-Host "  │    project directory autonomously                       │" -ForegroundColor Yellow
    Write-Host "  │  • By default, Ralph has unrestricted filesystem        │" -ForegroundColor Yellow
    Write-Host "  │    access (configurable in ralph/config.json)           │" -ForegroundColor Yellow
    Write-Host "  │  • Continuous AI loops consume significant tokens       │" -ForegroundColor Yellow
    Write-Host "  │  • Always use Git version control and review changes    │" -ForegroundColor Yellow
    Write-Host "  │                                                         │" -ForegroundColor Yellow
    Write-Host "  │  USE AT YOUR OWN RISK. The authors assume no           │" -ForegroundColor Yellow
    Write-Host "  │  responsibility for any damage, data loss, or           │" -ForegroundColor Yellow
    Write-Host "  │  unintended modifications caused by this software.      │" -ForegroundColor Yellow
    Write-Host "  │                                                         │" -ForegroundColor Yellow
    Write-Host "  │  Requires: GitHub Copilot CLI + active subscription     │" -ForegroundColor Yellow
    Write-Host "  └─────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""
    $accept = Read-Host "  Accept and continue? (yes/[N]o)"
    if ([string]::IsNullOrWhiteSpace($accept)) { $accept = 'n' }
    if ($accept -notmatch "^(y|yes)$") {
        Write-Host "  Installation cancelled." -ForegroundColor Gray
        exit 0
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                     PREREQUISITES
# ═══════════════════════════════════════════════════════════════

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: git is not installed or not in PATH" -ForegroundColor Red
    Write-Host "  Install git from https://git-scm.com/" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-Host "  WARNING: GitHub Copilot CLI not found" -ForegroundColor Yellow
    Write-Host "  Install with: npm install -g @github/copilot" -ForegroundColor Gray
    Write-Host "  Then run: copilot auth" -ForegroundColor Gray
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                     HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Get-RalphFilesList {
    <#
    .SYNOPSIS
        Scans for all Ralph-related files without removing anything.
        Returns a list of items with path, description, and category.
    .PARAMETER IncludeRalphData
        If true, includes .ralph/ runtime data in the list
    #>
    param([switch]$IncludeRalphData)

    $files = @()

    # ralph/ folder (framework)
    if (Test-Path $RalphDir) {
        $size = (Get-ChildItem $RalphDir -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($size / 1MB, 1)
        $files += @{ Path = "ralph/"; Description = "Framework ($sizeMB MB)"; Category = "framework" }
    }

    # .ralph/ folder (runtime data)
    if ($IncludeRalphData -and (Test-Path $RalphDataDir)) {
        $details = @()
        $tasksDir = Join-Path $RalphDataDir "tasks"
        if (Test-Path $tasksDir) {
            $sessionCount = @(Get-ChildItem -Directory $tasksDir -ErrorAction SilentlyContinue).Count
            if ($sessionCount -gt 0) { $details += "$sessionCount session(s)" }
        }
        if (Test-Path (Join-Path $RalphDataDir "memory.md")) { $details += "memory" }
        if (Test-Path (Join-Path $RalphDataDir "venv")) { $details += "venv" }
        if (Test-Path (Join-Path $RalphDataDir "logs")) { $details += "logs" }
        $desc = if ($details.Count -gt 0) { "Runtime data: " + ($details -join ", ") } else { "Runtime data" }
        $files += @{ Path = ".ralph/"; Description = $desc; Category = "runtime" }
    }

    # .github/agents/ - only Ralph agent files
    if (Test-Path $AgentsDir) {
        foreach ($agentFile in $RalphAgentFiles) {
            $path = Join-Path $AgentsDir $agentFile
            if (Test-Path $path) {
                $files += @{ Path = ".github/agents/$agentFile"; Description = "Ralph agent prompt"; Category = "agents" }
            }
        }
    }

    # .github/instructions/ralph.instructions.md - only the Ralph file
    $ralphInstructions = Join-Path $InstructionsDir "ralph.instructions.md"
    if (Test-Path $ralphInstructions) {
        $files += @{ Path = ".github/instructions/ralph.instructions.md"; Description = "Ralph Copilot config"; Category = "instructions" }
    }

    # AGENTS.md (only if Ralph-generated)
    if (Test-Path $AgentsMdPath) {
        $content = Get-Content $AgentsMdPath -Raw -ErrorAction SilentlyContinue
        if ($content -and ($content -match "ralph" -or $content -match "Ralph")) {
            $files += @{ Path = "AGENTS.md"; Description = "Project guide (Ralph-generated)"; Category = "agents-md" }
        }
    }

    return $files
}

function Show-AffectedFiles {
    <#
    .SYNOPSIS
        Displays what files will be affected, grouped by category
    #>
    param(
        [array]$FilesList,
        [string]$ActionLabel = "WILL BE REMOVED"
    )

    Write-Host ""
    Write-Host "  The following Ralph files $ActionLabel`:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($item in $FilesList) {
        Write-Host "    $($item.Path)" -ForegroundColor White -NoNewline
        Write-Host "  ($($item.Description))" -ForegroundColor DarkGray
    }

    # Show what will NOT be touched
    $preserved = @()
    if (Test-Path $AgentsDir) {
        $nonRalphAgents = Get-ChildItem $AgentsDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $RalphAgentFiles }
        foreach ($file in $nonRalphAgents) {
            $preserved += ".github/agents/$($file.Name)"
        }
    }
    if (Test-Path $InstructionsDir) {
        $nonRalphInstructions = Get-ChildItem $InstructionsDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "ralph.instructions.md" }
        foreach ($file in $nonRalphInstructions) {
            $preserved += ".github/instructions/$($file.Name)"
        }
    }

    if ($preserved.Count -gt 0) {
        Write-Host ""
        Write-Host "  The following non-Ralph files will NOT be touched:" -ForegroundColor Green
        foreach ($item in $preserved) {
            Write-Host "    $item" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

function Remove-RalphFiles {
    <#
    .SYNOPSIS
        Removes only Ralph-related files from the project.
        Never removes non-Ralph files from .github/.
    .PARAMETER IncludeRalphData
        If true, also removes .ralph/ (sessions, memory, logs, cache)
    #>
    param([switch]$IncludeRalphData)

    $removed = @()

    # ralph/ folder (framework)
    if (Test-Path $RalphDir) {
        Remove-Item -Recurse -Force $RalphDir
        $removed += "ralph/"
    }

    # .ralph/ folder (runtime: sessions, memory, venv, logs, caches)
    if ($IncludeRalphData -and (Test-Path $RalphDataDir)) {
        Remove-Item -Recurse -Force $RalphDataDir
        $removed += ".ralph/"
    }

    # .github/agents/ - only Ralph agent files
    if (Test-Path $AgentsDir) {
        foreach ($agentFile in $RalphAgentFiles) {
            $path = Join-Path $AgentsDir $agentFile
            if (Test-Path $path) {
                Remove-Item -Force $path
                $removed += ".github/agents/$agentFile"
            }
        }
    }

    # .github/instructions/ralph.instructions.md - only the Ralph file
    $ralphInstructions = Join-Path $InstructionsDir "ralph.instructions.md"
    if (Test-Path $ralphInstructions) {
        Remove-Item -Force $ralphInstructions
        $removed += ".github/instructions/ralph.instructions.md"
    }

    # AGENTS.md (only if Ralph-generated)
    if (Test-Path $AgentsMdPath) {
        $content = Get-Content $AgentsMdPath -Raw -ErrorAction SilentlyContinue
        if ($content -and ($content -match "ralph" -or $content -match "Ralph")) {
            Remove-Item -Force $AgentsMdPath
            $removed += "AGENTS.md"
        }
    }

    return $removed
}

function Install-RalphFromRemote {
    <#
    .SYNOPSIS
        Downloads and installs ralph/ folder from the repository
    #>
    Write-Host "  Downloading Ralph ($Branch)..." -ForegroundColor Cyan

    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-install-$(Get-Random)"

    try {
        $env:GIT_TERMINAL_PROMPT = "0"
        git clone --depth 1 --branch $Branch --filter=blob:none --sparse --quiet --no-progress $RepoUrl $TempDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone repository"
        }

        Push-Location $TempDir
        try {
            git sparse-checkout set ralph 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to set up sparse checkout"
            }
        } finally {
            Pop-Location
        }

        $SourceRalph = Join-Path $TempDir "ralph"
        if (-not (Test-Path $SourceRalph)) {
            throw "ralph/ folder not found in downloaded repository"
        }

        Copy-Item -Recurse -Force $SourceRalph $RalphDir
        Write-Host "  Downloaded ralph/ folder" -ForegroundColor Green

    } catch {
        Write-Host "  Trying fallback download method..." -ForegroundColor Yellow
        if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }

        git clone --depth 1 --branch $Branch --quiet --no-progress $RepoUrl $TempDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERROR: Failed to download Ralph" -ForegroundColor Red
            Write-Host "  Check your network connection and try again." -ForegroundColor Yellow
            exit 1
        }

        $SourceRalph = Join-Path $TempDir "ralph"
        Copy-Item -Recurse -Force $SourceRalph $RalphDir
        Write-Host "  Downloaded ralph/ folder (fallback method)" -ForegroundColor Green

    } finally {
        if (Test-Path $TempDir) {
            Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
        }
    }
}

function Set-RalphSourceTracking {
    if (-not (Test-Path $RalphDataDir)) {
        New-Item -ItemType Directory -Path $RalphDataDir -Force | Out-Null
    }

    $sourceJson = @{
        url = $RepoUrl
        branch = $Branch
        installed = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        method = "installer"
    } | ConvertTo-Json -Depth 2

    Set-Content -Path (Join-Path $RalphDataDir "source.json") -Value $sourceJson -Encoding UTF8
    Write-Host "  Created .ralph/source.json (for updates)" -ForegroundColor Green
}

function Set-RalphGitignore {
    $gitignorePath = Join-Path $PWD ".gitignore"
    $ralphIgnoreEntry = ".ralph/"
    $configIgnoreEntry = "ralph/config.json"

    if (Test-Path $gitignorePath) {
        $gitignoreContent = Get-Content $gitignorePath -Raw
        $entriesToAdd = @()

        if ($gitignoreContent -notmatch [regex]::Escape($ralphIgnoreEntry)) {
            $entriesToAdd += $ralphIgnoreEntry
        }
        if ($gitignoreContent -notmatch [regex]::Escape($configIgnoreEntry)) {
            $entriesToAdd += $configIgnoreEntry
        }

        if ($entriesToAdd.Count -gt 0) {
            $addition = "`n`n# Ralph runtime files`n" + ($entriesToAdd -join "`n") + "`n"
            Add-Content -Path $gitignorePath -Value $addition -Encoding UTF8
            Write-Host "  Updated .gitignore" -ForegroundColor Green
        }
    } else {
        @"
# Ralph runtime files
.ralph/
ralph/config.json
"@ | Set-Content $gitignorePath -Encoding UTF8
        Write-Host "  Created .gitignore" -ForegroundColor Green
    }
}

function Show-InstallSuccess {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "  RALPH INSTALLED SUCCESSFULLY!" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Commands:" -ForegroundColor Yellow
    Write-Host "    ./ralph/ralph.ps1            # Start Ralph (PowerShell)" -ForegroundColor White
    Write-Host "    ./ralph/ralph.sh             # Start Ralph (Bash)" -ForegroundColor White
    Write-Host "    ./ralph/ralph.ps1 -Update    # Update Ralph later" -ForegroundColor White
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#                     EXISTING INSTALLATION DETECTED
# ═══════════════════════════════════════════════════════════════

$selectedAction = "install"

if (Test-Path $RalphDir) {
    # Detect what Ralph files exist
    $hasRalphData = Test-Path $RalphDataDir
    $hasAgents = (Test-Path $AgentsDir) -and ($RalphAgentFiles | Where-Object { Test-Path (Join-Path $AgentsDir $_) })
    $hasInstructions = Test-Path (Join-Path $InstructionsDir "ralph.instructions.md")
    $hasAgentsMd = Test-Path $AgentsMdPath

    Write-Host "  Ralph is already installed in this project." -ForegroundColor Yellow
    Write-Host ""

    # Show what exists
    Write-Host "  Detected files:" -ForegroundColor Gray
    Write-Host "    ralph/                          (framework)" -ForegroundColor White
    if ($hasRalphData) {
        $sessionCount = 0
        $tasksDir = Join-Path $RalphDataDir "tasks"
        if (Test-Path $tasksDir) {
            $sessionCount = @(Get-ChildItem -Directory $tasksDir -ErrorAction SilentlyContinue).Count
        }
        $dataInfo = "runtime data"
        if ($sessionCount -gt 0) { $dataInfo += ", $sessionCount session(s)" }
        Write-Host "    .ralph/                         ($dataInfo)" -ForegroundColor White
    }
    if ($hasAgents) { Write-Host "    .github/agents/ralph*.agent.md  (agent prompts)" -ForegroundColor White }
    if ($hasInstructions) { Write-Host "    .github/instructions/           (Copilot config)" -ForegroundColor White }
    if ($hasAgentsMd) { Write-Host "    AGENTS.md                       (project guide)" -ForegroundColor White }
    Write-Host ""

    if ($Force -and $Action) {
        $selectedAction = $Action
    } else {
        Write-Host "  What would you like to do?" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "    [1] Fresh install    - Remove all Ralph files, install clean" -ForegroundColor White
        Write-Host "                           (removes Ralph sessions, cache, memory)" -ForegroundColor DarkGray
        Write-Host "                           (your project source code is not affected)" -ForegroundColor DarkGray
        Write-Host "    [2] Update Ralph     - Update framework only, keep your data" -ForegroundColor White
        Write-Host "                           (preserves sessions, specs, memory)" -ForegroundColor DarkGray
        Write-Host "    [3] Uninstall Ralph  - Remove all Ralph files from project" -ForegroundColor White
        Write-Host "                           (removes ralph/, .ralph/, agents, configs)" -ForegroundColor DarkGray
        Write-Host "    [4] Cancel           - Exit without changes" -ForegroundColor White
        Write-Host ""

        do {
            $choice = Read-Host "  Enter choice (1-4)"
        } while ($choice -notmatch '^[1-4]$')

        switch ($choice) {
            '1' { $selectedAction = "fresh" }
            '2' { $selectedAction = "update" }
            '3' { $selectedAction = "uninstall" }
            '4' {
                Write-Host ""
                Write-Host "  Cancelled. No changes made." -ForegroundColor Gray
                exit 0
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                     EXECUTE ACTION
# ═══════════════════════════════════════════════════════════════

switch ($selectedAction) {

    "install" {
        # Fresh install (no existing Ralph)
        Install-RalphFromRemote
        Set-RalphSourceTracking
        Set-RalphGitignore
        Show-InstallSuccess

        if (-not $NoStart) {
            Write-Host "  Starting Ralph..." -ForegroundColor Cyan
            Start-Sleep -Milliseconds 1500
            Clear-Host
            & (Join-Path $RalphDir "ralph.ps1")
        }
    }

    "fresh" {
        # Fresh install - scan, preview, confirm, wipe everything, reinstall
        $affectedFiles = Get-RalphFilesList -IncludeRalphData
        Show-AffectedFiles -FilesList $affectedFiles -ActionLabel "will be REMOVED for fresh install"

        if (-not $Force) {
            $confirm = Read-Host "  Proceed with fresh install? (yes/[N]o)"
            if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = 'n' }
            if ($confirm -notmatch "^(y|yes)$") {
                Write-Host "  Cancelled. No changes made." -ForegroundColor Gray
                exit 0
            }
        }

        Write-Host ""
        Write-Host "  Removing all Ralph files..." -ForegroundColor Yellow
        $removed = Remove-RalphFiles -IncludeRalphData
        foreach ($item in $removed) {
            Write-Host "    Removed: $item" -ForegroundColor DarkGray
        }
        Write-Host ""

        Install-RalphFromRemote
        Set-RalphSourceTracking
        Set-RalphGitignore
        Show-InstallSuccess

        if (-not $NoStart) {
            Write-Host "  Starting Ralph..." -ForegroundColor Cyan
            Start-Sleep -Milliseconds 1500
            Clear-Host
            & (Join-Path $RalphDir "ralph.ps1")
        }
    }

    "update" {
        # Update - only replace ralph/ folder, keep everything else
        Write-Host "  Updating Ralph framework..." -ForegroundColor Cyan

        # Back up user specs if they exist in ralph/specs/ (non-template files)
        $specsBackup = $null
        $specsDir = Join-Path $RalphDir "specs"
        if (Test-Path $specsDir) {
            $userSpecs = Get-ChildItem -Path $specsDir -Filter "*.md" -ErrorAction SilentlyContinue |
                Where-Object { -not $_.Name.StartsWith('_') }
            if ($userSpecs -and $userSpecs.Count -gt 0) {
                $specsBackup = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-specs-backup-$(Get-Random)"
                New-Item -ItemType Directory -Path $specsBackup -Force | Out-Null
                foreach ($spec in $userSpecs) {
                    Copy-Item $spec.FullName $specsBackup
                }
                Write-Host "  Backed up $($userSpecs.Count) user spec(s)" -ForegroundColor Gray
            }
        }

        # Back up config.json if it exists
        $configBackup = $null
        $configPath = Join-Path $RalphDir "config.json"
        if (Test-Path $configPath) {
            $configBackup = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-config-backup-$(Get-Random).json"
            Copy-Item $configPath $configBackup
            Write-Host "  Backed up config.json" -ForegroundColor Gray
        }

        # Remove and re-download ralph/ only
        Remove-Item -Recurse -Force $RalphDir
        Install-RalphFromRemote

        # Restore user specs
        if ($specsBackup -and (Test-Path $specsBackup)) {
            $restoredSpecs = Get-ChildItem $specsBackup -Filter "*.md"
            foreach ($spec in $restoredSpecs) {
                Copy-Item $spec.FullName (Join-Path $RalphDir "specs")
            }
            Remove-Item -Recurse -Force $specsBackup
            Write-Host "  Restored $($restoredSpecs.Count) user spec(s)" -ForegroundColor Green
        }

        # Restore config.json
        if ($configBackup -and (Test-Path $configBackup)) {
            Copy-Item $configBackup $configPath
            Remove-Item -Force $configBackup
            Write-Host "  Restored config.json" -ForegroundColor Green
        }

        Set-RalphSourceTracking

        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Write-Host "  RALPH UPDATED SUCCESSFULLY!" -ForegroundColor White
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Your sessions, memory, and cache are preserved." -ForegroundColor Gray
        Write-Host ""

        if (-not $NoStart) {
            Write-Host "  Starting Ralph..." -ForegroundColor Cyan
            Start-Sleep -Milliseconds 1500
            Clear-Host
            & (Join-Path $RalphDir "ralph.ps1")
        }
    }

    "uninstall" {
        # Scan and show exactly what will be removed
        $affectedFiles = Get-RalphFilesList -IncludeRalphData
        Show-AffectedFiles -FilesList $affectedFiles -ActionLabel "will be PERMANENTLY REMOVED"

        if (-not $Force) {
            Write-Host "  Your project source code will NOT be touched." -ForegroundColor Gray
            $confirm = Read-Host "  Type 'uninstall' to confirm"
            if ($confirm -ne 'uninstall') {
                Write-Host "  Cancelled. No changes made." -ForegroundColor Gray
                exit 0
            }
        }

        Write-Host ""
        Write-Host "  Uninstalling Ralph..." -ForegroundColor Yellow
        $removed = Remove-RalphFiles -IncludeRalphData
        foreach ($item in $removed) {
            Write-Host "    Removed: $item" -ForegroundColor DarkGray
        }

        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
        Write-Host "  RALPH UNINSTALLED" -ForegroundColor White
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  All Ralph files have been removed from this project." -ForegroundColor Gray
        Write-Host "  Your project source code is untouched." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  To reinstall, run:" -ForegroundColor Gray
        Write-Host "    irm https://raw.githubusercontent.com/niittymaa/Copilot-Ralph/main/install.ps1 | iex" -ForegroundColor Cyan
        Write-Host ""
    }
}
