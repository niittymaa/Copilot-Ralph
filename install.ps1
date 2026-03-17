<#
.SYNOPSIS
    Install Ralph into any project with a single command.

.DESCRIPTION
    Downloads the Ralph autonomous AI coding agent framework into the current
    directory. Run this at the root of your project.

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
    Overwrite existing ralph/ folder without prompting
#>

[CmdletBinding()]
param(
    [string]$Branch = "main",
    [switch]$NoStart,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$RepoUrl = "https://github.com/niittymaa/Copilot-Ralph.git"
$RalphDir = Join-Path $PWD "ralph"
$RalphDataDir = Join-Path $PWD ".ralph"

# ═══════════════════════════════════════════════════════════════
#                     DISPLAY
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  RALPH INSTALLER - Autonomous AI Coding Agent" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════════
#                     PREREQUISITES
# ═══════════════════════════════════════════════════════════════

# Check git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: git is not installed or not in PATH" -ForegroundColor Red
    Write-Host "  Install git from https://git-scm.com/" -ForegroundColor Yellow
    exit 1
}

# Check copilot CLI (warn only)
if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-Host "  WARNING: GitHub Copilot CLI not found" -ForegroundColor Yellow
    Write-Host "  Install with: npm install -g @github/copilot" -ForegroundColor Gray
    Write-Host "  Then run: copilot auth" -ForegroundColor Gray
    Write-Host ""
}

# Check if ralph/ already exists
if (Test-Path $RalphDir) {
    if (-not $Force) {
        Write-Host "  ralph/ folder already exists in this directory." -ForegroundColor Yellow
        Write-Host ""
        $confirm = Read-Host "  Overwrite? (yes/[N]o)"
        if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = 'n' }
        if ($confirm -notmatch "^(y|yes)$") {
            Write-Host "  Cancelled." -ForegroundColor Gray
            exit 0
        }
    }
    Write-Host "  Removing existing ralph/ folder..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $RalphDir
}

# ═══════════════════════════════════════════════════════════════
#                     DOWNLOAD
# ═══════════════════════════════════════════════════════════════

Write-Host "  Downloading Ralph ($Branch)..." -ForegroundColor Cyan

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-install-$(Get-Random)"

try {
    # Clone with minimal data (shallow, sparse)
    git clone --depth 1 --branch $Branch --filter=blob:none --sparse $RepoUrl $TempDir 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone repository"
    }

    # Set up sparse checkout to only get ralph/ folder
    Push-Location $TempDir
    try {
        git sparse-checkout set ralph 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set up sparse checkout"
        }
    } finally {
        Pop-Location
    }

    # Copy ralph/ folder to target
    $SourceRalph = Join-Path $TempDir "ralph"
    if (-not (Test-Path $SourceRalph)) {
        throw "ralph/ folder not found in downloaded repository"
    }

    Copy-Item -Recurse -Force $SourceRalph $RalphDir
    Write-Host "  Downloaded ralph/ folder" -ForegroundColor Green

} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""

    # Fallback: full shallow clone
    Write-Host "  Trying fallback download method..." -ForegroundColor Yellow
    if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }

    git clone --depth 1 --branch $Branch $RepoUrl $TempDir 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to download Ralph" -ForegroundColor Red
        Write-Host "  Check your network connection and try again." -ForegroundColor Yellow
        exit 1
    }

    $SourceRalph = Join-Path $TempDir "ralph"
    Copy-Item -Recurse -Force $SourceRalph $RalphDir
    Write-Host "  Downloaded ralph/ folder (fallback method)" -ForegroundColor Green

} finally {
    # Clean up temp directory
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
    }
}

# ═══════════════════════════════════════════════════════════════
#                     SOURCE TRACKING
# ═══════════════════════════════════════════════════════════════

# Create .ralph/ directory and source.json for update tracking
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

# ═══════════════════════════════════════════════════════════════
#                     GITIGNORE
# ═══════════════════════════════════════════════════════════════

# Ensure .ralph/ is in .gitignore
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

# ═══════════════════════════════════════════════════════════════
#                     COMPLETE
# ═══════════════════════════════════════════════════════════════

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

# Start Ralph automatically unless -NoStart was specified
if (-not $NoStart) {
    Write-Host "  Starting Ralph..." -ForegroundColor Cyan
    Write-Host ""
    & (Join-Path $RalphDir "ralph.ps1")
}
