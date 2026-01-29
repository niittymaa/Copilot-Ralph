<#
.SYNOPSIS
    Resets this fork to match the original upstream repository.

.DESCRIPTION
    This script performs a hard reset of the current fork to match the upstream
    repository exactly. WARNING: This will permanently delete all local changes!

    The script automatically:
    - Finds the git repository root (works from any subdirectory)
    - Detects if the repository is a fork
    - Shows what will happen and asks for confirmation

.PARAMETER Branch
    The branch to reset. Default is 'main'.

.PARAMETER UpstreamUrl
    The upstream repository URL. Default is the original Ralph repository.

.PARAMETER Force
    Skip confirmation prompt.

.EXAMPLE
    .\reset-to-upstream.ps1
    .\reset-to-upstream.ps1 -Branch main -Force
#>

[CmdletBinding()]
param(
    [string]$Branch = "main",
    [string]$UpstreamUrl = "",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Save parameters IMMEDIATELY before they can be polluted by sourcing other scripts
# The CLI framework may set variables that collide with our parameters
$script:ResetBranch = $Branch
$script:ResetUpstreamUrl = $UpstreamUrl
$script:ResetForce = $Force

Write-Host "=== Fork Reset Script ===" -ForegroundColor Cyan
Write-Host ""

# Find git repository root (works from any subdirectory)
try {
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        throw "Not in a git repository"
    }
} catch {
    Write-Host "ERROR: Not in a git repository!" -ForegroundColor Red
    Write-Host "Please run this script from within a git repository." -ForegroundColor Gray
    exit 1
}

# Check if this is a local copy (has source.json instead of upstream.json)
$sourceConfigPath = Join-Path $repoRoot ".ralph\source.json"
if (Test-Path $sourceConfigPath) {
    try {
        $sourceConfig = Get-Content $sourceConfigPath -Raw | ConvertFrom-Json
        if ($sourceConfig.type -eq "local-copy") {
            Write-Host "ERROR: This is a local copy, not a fork!" -ForegroundColor Red
            Write-Host ""
            Write-Host "Local copies have their own independent git repository and" -ForegroundColor Yellow
            Write-Host "cannot be reset to upstream. They are not connected to the" -ForegroundColor Yellow
            Write-Host "original repository." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Source was: $($sourceConfig.url)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Options:" -ForegroundColor White
            Write-Host "  1. Use 'git reset --hard HEAD' to undo local changes" -ForegroundColor Cyan
            Write-Host "  2. Create a new fork if you need upstream sync capability" -ForegroundColor Cyan
            exit 1
        }
    } catch {
        # Ignore parse errors, continue with normal flow
    }
}

# Try to load upstream configuration if not provided
if ([string]::IsNullOrWhiteSpace($script:ResetUpstreamUrl)) {
    $configPath = Join-Path $repoRoot ".ralph\upstream.json"
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            # Handle both old format (url) and new format (upstream)
            $script:ResetUpstreamUrl = if ($config.upstream) { $config.upstream } else { $config.url }
            Write-Host "Loaded upstream from config: $script:ResetUpstreamUrl" -ForegroundColor Gray
        } catch {
            Write-Host "Warning: Could not read upstream config" -ForegroundColor Yellow
        }
    }
    
    # Fallback to default if still not set
    if ([string]::IsNullOrWhiteSpace($script:ResetUpstreamUrl)) {
        $script:ResetUpstreamUrl = "https://github.com/niittymaa/Copilot-Ralph.git"
        Write-Host "Using default upstream: $script:ResetUpstreamUrl" -ForegroundColor Yellow
    }
}

# Load menu system for arrow navigation
$script:MenusLoaded = $false
$menusPath = Join-Path $repoRoot 'ralph\core\menus.ps1'
if (Test-Path $menusPath) {
    . $menusPath
    Initialize-MenuSystem -ProjectRoot $repoRoot
    $script:MenusLoaded = $true
}

# Change to repository root
$originalLocation = Get-Location
Set-Location $repoRoot
Write-Host "Repository root: $repoRoot" -ForegroundColor Gray
Write-Host ""

# Get current origin URL (may not exist for local-only clones)
$originUrl = git config --get remote.origin.url 2>$null
$hasOrigin = [bool]$originUrl

if ($hasOrigin) {
    # Detect if this looks like a fork (origin differs from upstream)
    $isFork = $originUrl -ne $script:ResetUpstreamUrl
    Write-Host "Current origin:  $originUrl" -ForegroundColor Gray
    Write-Host "Upstream target: $script:ResetUpstreamUrl" -ForegroundColor Gray
    Write-Host ""

    if ($isFork) {
        Write-Host "FORK DETECTED" -ForegroundColor Cyan
        Write-Host "This repository appears to be a fork of the upstream repository." -ForegroundColor Gray
    } else {
        Write-Host "NOTE: Origin URL matches upstream URL." -ForegroundColor Yellow
        Write-Host "This may be the original repository, not a fork." -ForegroundColor Yellow
    }
} else {
    Write-Host "LOCAL-ONLY CLONE DETECTED" -ForegroundColor Cyan
    Write-Host "No 'origin' remote found. Will reset to upstream without pushing." -ForegroundColor Gray
    Write-Host "Upstream target: $script:ResetUpstreamUrl" -ForegroundColor Gray
}
Write-Host ""

# Check for local changes
$hasChanges = $false
$status = git status --porcelain 2>$null
if ($status) {
    $hasChanges = $true
    Write-Host "UNCOMMITTED CHANGES DETECTED:" -ForegroundColor Yellow
    git status --short
    Write-Host ""
}

# Explain what will happen
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "WHAT WILL HAPPEN:" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Add/update 'upstream' remote pointing to:" -ForegroundColor White
Write-Host "  $script:ResetUpstreamUrl" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Fetch latest code from upstream" -ForegroundColor White
Write-Host ""
Write-Host "3. HARD RESET '$script:ResetBranch' branch to match upstream/$script:ResetBranch" -ForegroundColor White
Write-Host "  - ALL uncommitted changes will be DELETED" -ForegroundColor Red
Write-Host "  - ALL commits not in upstream will be DELETED" -ForegroundColor Red
Write-Host "  - Your local branch will be IDENTICAL to upstream" -ForegroundColor Red
Write-Host ""
if ($hasOrigin) {
    Write-Host "4. FORCE PUSH to origin (GitHub)" -ForegroundColor White
    Write-Host "  - Your fork's history will be OVERWRITTEN" -ForegroundColor Red
    Write-Host "  - This cannot be undone!" -ForegroundColor Red
    Write-Host ""
} else {
    Write-Host "4. (Skipped) No origin remote - no push will be performed" -ForegroundColor Gray
    Write-Host ""
}
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

if (-not $script:ResetForce) {
    if ($script:MenusLoaded) {
        $confirmed = Show-DangerConfirmMenu -Title "Reset Fork to Upstream" -Message "This will PERMANENTLY DELETE all local changes. Reset fork to upstream?" -ConfirmText "yes"
        if (-not $confirmed) {
            Write-Host "Aborted. No changes made." -ForegroundColor Gray
            Set-Location $originalLocation
            exit 0
        }
    } else {
        Write-Host "Type 'yes' to confirm you understand and want to proceed." -ForegroundColor White
        $confirm = Read-Host "Reset fork to upstream? (yes/[N]o)"
        if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = 'n' }
        if ($confirm -notmatch "^(y|yes)$") {
            Write-Host "Aborted. No changes made." -ForegroundColor Gray
            Set-Location $originalLocation
            exit 0
        }
    }
}

Write-Host ""
Write-Host "Proceeding with reset..." -ForegroundColor Cyan
Write-Host ""

# Step 1: Add upstream if not exists
Write-Host "[1/5] Checking upstream remote..." -ForegroundColor Cyan
$upstreamExists = git remote | Where-Object { $_ -eq "upstream" }

if (-not $upstreamExists) {
    Write-Host "  Adding upstream: $script:ResetUpstreamUrl" -ForegroundColor Gray
    git remote add upstream $script:ResetUpstreamUrl
} else {
    Write-Host "  Upstream already exists, updating URL..." -ForegroundColor Gray
    git remote set-url upstream $script:ResetUpstreamUrl
}

# Step 2: Fetch upstream
Write-Host "[2/5] Fetching upstream..." -ForegroundColor Cyan
git fetch upstream

# Step 3: Checkout branch
Write-Host "[3/5] Checking out $script:ResetBranch..." -ForegroundColor Cyan
git checkout $script:ResetBranch

# Step 4: Hard reset to upstream
Write-Host "[4/5] Resetting to upstream/$script:ResetBranch..." -ForegroundColor Cyan
git reset --hard "upstream/$script:ResetBranch"

# Step 5: Force push (only if origin exists)
if ($hasOrigin) {
    Write-Host "[5/5] Force pushing to origin..." -ForegroundColor Cyan
    git push --force
} else {
    Write-Host "[5/5] Skipping push (no origin remote)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== SUCCESS ===" -ForegroundColor Green
Write-Host "Fork has been reset to match upstream!" -ForegroundColor Green
Write-Host ""
Write-Host "Your repository is now identical to:" -ForegroundColor Gray
Write-Host "$script:ResetUpstreamUrl" -ForegroundColor Cyan

# Return to original location
Set-Location $originalLocation
