<#
.SYNOPSIS
    Fork and clone a Ralph instance for a new project.

.DESCRIPTION
    Creates a new Ralph-powered project by forking to GitHub or cloning locally.
    Automatically falls back to local-only mode if GitHub CLI is unavailable.

.PARAMETER Name
    Name for the fork (used as repo name and folder name).

.PARAMETER Path
    Custom path where the fork will be created. If not specified, uses .ralph\forks\.
    The path must be a valid directory or will be created.

.PARAMETER ForkFrom
    Override fork source: 'original', 'current', or a GitHub URL.

.PARAMETER LocalOnly
    Force local-only mode without pushing to GitHub.

.EXAMPLE
    .\fork.ps1 -Name my-project

.EXAMPLE
    .\fork.ps1 -Name my-project -Path "D:\Projects\my-project"
#>

[CmdletBinding()]
param(
    [string]$Name = "",
    [string]$Path = "",
    [string]$ForkFrom = "",
    [switch]$LocalOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Save parameters IMMEDIATELY before they can be polluted by sourcing other scripts
# The CLI framework sets $Name and $Path variables which collide with our parameters
$script:ForkName = $Name
$script:ForkPath = $Path
$script:ForkFrom_Param = $ForkFrom
$script:ForkLocalOnly = $LocalOnly

# Save PSScriptRoot early before it can be modified by sourcing other scripts
$script:ForkScriptRoot = $PSScriptRoot

# Constants
$OriginalRepoUrl = "https://github.com/niittymaa/Copilot-Ralph"
$OriginalOwner = "niittymaa"
$OriginalRepo = "Copilot-Ralph"

#region Helper Functions

function Write-Header { param([string]$Text); Write-Host "`n=== $Text ===`n" -ForegroundColor Cyan }
function Write-Step { param([int]$N, [int]$T, [string]$Text); Write-Host "[$N/$T] $Text" -ForegroundColor Cyan }
function Write-Info { param([string]$Text); Write-Host "  $Text" -ForegroundColor Gray }

# Load menu system for arrow navigation
$script:MenusLoaded = $false
$menusPath = Join-Path $script:ForkScriptRoot '..\core\menus.ps1'
if (Test-Path $menusPath) {
    . $menusPath
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if ($repoRoot) {
        Initialize-MenuSystem -ProjectRoot $repoRoot
        $script:MenusLoaded = $true
    }
}

function Test-GitHubAvailable {
    # Returns: $true if gh CLI installed and authenticated, $false otherwise
    try {
        $null = gh --version 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
        $null = gh auth status 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Get-RepoInfo {
    param([string]$Owner, [string]$Repo)
    try {
        $json = gh api "repos/$Owner/$Repo" 2>$null | ConvertFrom-Json
        return @{
            IsFork = $json.fork
            ParentOwner = if ($json.parent) { $json.parent.owner.login } else { $null }
            ParentRepo = if ($json.parent) { $json.parent.name } else { $null }
            ParentUrl = if ($json.parent) { $json.parent.html_url } else { $null }
        }
    } catch { return $null }
}

function Get-CurrentRepoInfo {
    $originUrl = git config --get remote.origin.url 2>$null
    if ($originUrl -and $originUrl -match "github\.com[:/]([^/]+)/([^/]+?)(\.git)?$") {
        return @{ Owner = $Matches[1]; Repo = $Matches[2]; Url = $originUrl }
    }
    return $null
}

function Get-AuthenticatedUser {
    try { (gh api user 2>$null | ConvertFrom-Json).login } catch { $null }
}

#endregion

#region Main Script

Write-Header "Ralph Fork Creator"

# Step 1: Check prerequisites and determine mode
Write-Step 1 6 "Checking prerequisites..."

$ghAvailable = Test-GitHubAvailable
$ghUser = $null

if ($LocalOnly) {
    Write-Info "Local-only mode: Forced by parameter"
} elseif (-not $ghAvailable) {
    Write-Host "  GitHub CLI not available - using local-only mode" -ForegroundColor Yellow
    $LocalOnly = $true
} else {
    $ghUser = Get-AuthenticatedUser
    if (-not $ghUser) {
        Write-Host "  Could not get GitHub user - using local-only mode" -ForegroundColor Yellow
        $LocalOnly = $true
    } else {
        Write-Info "GitHub: OK (logged in as $ghUser)"
    }
}

# Step 2: Detect current repository
Write-Step 2 6 "Analyzing current repository..."

$currentRepo = Get-CurrentRepoInfo
if (-not $currentRepo) {
    # If not in a git repo, we can still proceed with local clone from original
    Write-Info "Not in a git repository - will clone from original"
    $currentRepo = $null
    $isOriginal = $false
    $isFork = $false
    $repoDetails = $null
} else {
    Write-Info "Current repo: $($currentRepo.Owner)/$($currentRepo.Repo)"

    $isOriginal = ($currentRepo.Owner -eq $OriginalOwner -and $currentRepo.Repo -eq $OriginalRepo)
    $repoDetails = if (-not $LocalOnly) { Get-RepoInfo -Owner $currentRepo.Owner -Repo $currentRepo.Repo } else { $null }
    $isFork = $repoDetails -and $repoDetails.IsFork

    Write-Host ""
    if ($isOriginal) { Write-Host "This is the ORIGINAL Ralph repository." -ForegroundColor Green }
    elseif ($isFork) { Write-Host "This is a FORK of: $($repoDetails.ParentOwner)/$($repoDetails.ParentRepo)" -ForegroundColor Yellow }
    else { Write-Host "Standalone repository (not a fork)." -ForegroundColor Yellow }
}

# Step 3: Determine fork source
Write-Step 3 6 "Determining fork source..."

$forkSourceUrl = ""
$forkSourceOwner = ""
$forkSourceRepo = ""

if ($ForkFrom) {
    switch ($ForkFrom) {
        "original" {
            $forkSourceOwner = $OriginalOwner
            $forkSourceRepo = $OriginalRepo
            $forkSourceUrl = $OriginalRepoUrl
        }
        "current" {
            if (-not $currentRepo) {
                Write-Host "ERROR: Cannot use -ForkFrom 'current' when not in a git repository!" -ForegroundColor Red
                exit 1
            }
            $forkSourceOwner = $currentRepo.Owner
            $forkSourceRepo = $currentRepo.Repo
            $forkSourceUrl = "https://github.com/$($currentRepo.Owner)/$($currentRepo.Repo)"
        }
        default {
            if ($ForkFrom -match "github\.com[:/]([^/]+)/([^/]+?)(\.git)?$") {
                $forkSourceOwner = $Matches[1]
                $forkSourceRepo = $Matches[2]
                $forkSourceUrl = $ForkFrom
            } else {
                Write-Host "ERROR: Invalid ForkFrom. Use 'original', 'current', or GitHub URL." -ForegroundColor Red
                exit 1
            }
        }
    }
} elseif (-not $currentRepo) {
    # Not in a git repo - default to original
    $forkSourceOwner = $OriginalOwner
    $forkSourceRepo = $OriginalRepo
    $forkSourceUrl = $OriginalRepoUrl
} elseif ($isOriginal) {
    $forkSourceOwner = $OriginalOwner
    $forkSourceRepo = $OriginalRepo
    $forkSourceUrl = $OriginalRepoUrl
} elseif ($isFork -and -not $LocalOnly) {
    if ($script:MenusLoaded) {
        $choices = @(
            @{ Label = "Original: $($repoDetails.ParentOwner)/$($repoDetails.ParentRepo)"; Value = 'original'; Hotkey = '1'; Default = $true }
            @{ Label = "Current:  $($currentRepo.Owner)/$($currentRepo.Repo)"; Value = 'current'; Hotkey = '2' }
        )
        Write-Host "`nChoose fork source:" -ForegroundColor White
        $choice = Show-ArrowChoice -Title "Choose fork source" -NoBack -Choices $choices
        
        if ($choice -eq 'original') {
            $forkSourceOwner = $repoDetails.ParentOwner
            $forkSourceRepo = $repoDetails.ParentRepo
            $forkSourceUrl = $repoDetails.ParentUrl
        } else {
            $forkSourceOwner = $currentRepo.Owner
            $forkSourceRepo = $currentRepo.Repo
            $forkSourceUrl = "https://github.com/$($currentRepo.Owner)/$($currentRepo.Repo)"
        }
    } else {
        Write-Host "`nChoose fork source:" -ForegroundColor White
        Write-Host "  [1] Original: $($repoDetails.ParentOwner)/$($repoDetails.ParentRepo)" -ForegroundColor Cyan
        Write-Host "  [2] Current:  $($currentRepo.Owner)/$($currentRepo.Repo)" -ForegroundColor Cyan
        Write-Host ""
        do { $choice = Read-Host "Enter choice (1 or 2)" } while ($choice -notmatch "^[12]$")
        
        if ($choice -eq "1") {
            $forkSourceOwner = $repoDetails.ParentOwner
            $forkSourceRepo = $repoDetails.ParentRepo
            $forkSourceUrl = $repoDetails.ParentUrl
        } else {
            $forkSourceOwner = $currentRepo.Owner
            $forkSourceRepo = $currentRepo.Repo
            $forkSourceUrl = "https://github.com/$($currentRepo.Owner)/$($currentRepo.Repo)"
        }
    }
} else {
    $forkSourceOwner = $currentRepo.Owner
    $forkSourceRepo = $currentRepo.Repo
    $forkSourceUrl = "https://github.com/$($currentRepo.Owner)/$($currentRepo.Repo)"
}

# Ask for fork mode if not already determined
if (-not $LocalOnly -and $ghAvailable) {
    if ($script:MenusLoaded) {
        $choices = @(
            @{ Label = "GitHub fork: Create fork on GitHub"; Value = 'github'; Hotkey = '1'; Default = $true }
            @{ Label = "Local only:  Clone locally without GitHub"; Value = 'local'; Hotkey = '2' }
        )
        Write-Host "`nChoose fork mode:" -ForegroundColor White
        $choice = Show-ArrowChoice -Title "Choose fork mode" -NoBack -Choices $choices
        if ($choice -eq 'local') { $LocalOnly = $true }
    } else {
        Write-Host "`nChoose fork mode:" -ForegroundColor White
        Write-Host "  [1] GitHub fork: Create fork on GitHub" -ForegroundColor Cyan
        Write-Host "  [2] Local only:  Clone locally without GitHub" -ForegroundColor Cyan
        Write-Host ""
        do { $choice = Read-Host "Enter choice (1 or 2)" } while ($choice -notmatch "^[12]$")
        if ($choice -eq "2") { $LocalOnly = $true }
    }
}

Write-Info "Fork source: $forkSourceUrl$(if ($LocalOnly) { ' (local only)' })"

# Determine paths for auto-naming
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    $repoRoot = $repoRoot -replace '/', '\' # Convert Unix paths to Windows paths
    if (-not (Test-Path $repoRoot)) {
        # If git returned Unix-style path, convert it
        if ($repoRoot -match '^/([a-z])/(.*)$') {
            $repoRoot = "$($Matches[1].ToUpper()):\$($Matches[2])"
        }
    }
    $repoRoot = [System.IO.Path]::GetFullPath($repoRoot)
    $forksDir = Join-Path $repoRoot ".ralph\forks"
} else {
    # Not in a git repo - use current directory
    $repoRoot = (Get-Location).Path
    $forksDir = Join-Path $repoRoot ".ralph\forks"
}

# Ensure forks directory exists before using it
if (-not (Test-Path $forksDir)) {
    New-Item -ItemType Directory -Path $forksDir -Force | Out-Null
}

function Get-NextAvailableName {
    param([string]$BaseName, [string]$Dir)
    $candidate = $BaseName
    $counter = 2
    while (Test-Path (Join-Path $Dir $candidate)) {
        $candidate = "$BaseName-$counter"
        $counter++
    }
    return $candidate
}

function Test-ValidPath {
    param([string]$TestPath)
    if ([string]::IsNullOrWhiteSpace($TestPath)) { return $false }
    try {
        $null = [System.IO.Path]::GetFullPath($TestPath)
        # Check for invalid characters in path
        $invalidChars = [System.IO.Path]::GetInvalidPathChars()
        foreach ($char in $invalidChars) {
            if ($TestPath.Contains($char)) { return $false }
        }
        return $true
    } catch {
        return $false
    }
}

function Resolve-SmartPath {
    <#
    .SYNOPSIS
        Intelligently resolves various path formats to a full path
    .DESCRIPTION
        Handles formats like:
        - D:\Folder\Path (standard)
        - D:Folder (drive-relative, converts to D:\Folder)
        - D: (drive root, converts to D:\)
        - \Folder (root-relative)
        - Folder (relative to current directory)
        - ~/Folder (home directory on Unix-like systems)
    .OUTPUTS
        Full resolved path string, or $null if invalid
    #>
    param([string]$InputPath)
    
    if ([string]::IsNullOrWhiteSpace($InputPath)) { return $null }
    
    $path = $InputPath.Trim()
    
    # Handle drive-relative paths like "D:Folder" (no backslash after colon)
    # Convert to "D:\Folder"
    if ($path -match '^([A-Za-z]):([^\\].*)$') {
        $drive = $Matches[1]
        $remainder = $Matches[2]
        $path = "${drive}:\${remainder}"
    }
    # Handle bare drive like "D:" - convert to "D:\"
    elseif ($path -match '^([A-Za-z]):$') {
        $path = "${path}\"
    }
    
    # Now validate and get full path
    try {
        $fullPath = [System.IO.Path]::GetFullPath($path)
        
        # Check for invalid characters
        $invalidChars = [System.IO.Path]::GetInvalidPathChars()
        foreach ($char in $invalidChars) {
            if ($path.Contains($char)) { return $null }
        }
        
        return $fullPath
    } catch {
        return $null
    }
}

function Get-ForkLocation {
    <#
    .SYNOPSIS
        Prompts user for fork location with validation and retry logic
    .OUTPUTS
        Hashtable with Path, Name, and IsCustom properties
    #>
    param(
        [string]$DefaultDir,
        [string]$ProvidedPath = "",
        [string]$ProvidedName = ""
    )
    
    $defaultName = Get-NextAvailableName -BaseName "my-project" -Dir $DefaultDir
    $defaultPath = Join-Path $DefaultDir $defaultName
    
    # If path was provided via parameter, validate and process it
    if ($ProvidedPath) {
        $fullPath = Resolve-SmartPath -InputPath $ProvidedPath
        if ($fullPath) {
            # If path exists and is a directory, treat it as parent and append project name
            if (Test-Path $fullPath -PathType Container) {
                $projectName = if ($ProvidedName) { $ProvidedName } else { $defaultName }
                $safeName = $projectName -replace '[^a-zA-Z0-9_-]', '-'
                $fullPath = Join-Path $fullPath $safeName
            }
            
            $extractedName = if ($ProvidedName) { $ProvidedName } else { Split-Path -Leaf $fullPath }
            return @{ Path = $fullPath; Name = $extractedName; IsCustom = $true }
        }
        Write-Host "  Invalid path provided: $ProvidedPath" -ForegroundColor Yellow
    }
    
    # Interactive prompt loop
    Write-Host ""
    Write-Host "  Default location: $defaultPath" -ForegroundColor Gray
    Write-Host "  (You can specify a parent folder or full path, e.g., D:\Projects or D:Projects)" -ForegroundColor DarkGray
    Write-Host ""
    
    while ($true) {
        $userInput = Read-Host "  Enter location (Enter for default, or custom path)"
        
        # Empty input = use default
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            # If name was provided, use it with default directory
            if ($ProvidedName) {
                $safeName = $ProvidedName -replace '[^a-zA-Z0-9_-]', '-'
                $finalPath = Join-Path $DefaultDir $safeName
                return @{ Path = $finalPath; Name = $ProvidedName; IsCustom = $false }
            }
            return @{ Path = $defaultPath; Name = $defaultName; IsCustom = $false }
        }
        
        # Use smart path resolver
        $fullPath = Resolve-SmartPath -InputPath $userInput
        if (-not $fullPath) {
            Write-Host "  Invalid path format. Please try again." -ForegroundColor Yellow
            continue
        }
        
        # If path exists and is a directory, treat it as parent folder
        if (Test-Path $fullPath -PathType Container) {
            # Ask for project name to create subfolder
            $projectName = if ($ProvidedName) { 
                $ProvidedName 
            } else {
                $suggestedName = Get-NextAvailableName -BaseName "my-project" -Dir $fullPath
                $nameInput = Read-Host "  Enter project name (Enter for '$suggestedName')"
                if ([string]::IsNullOrWhiteSpace($nameInput)) { $suggestedName } else { $nameInput }
            }
            
            $safeName = $projectName -replace '[^a-zA-Z0-9_-]', '-'
            $fullPath = Join-Path $fullPath $safeName
            
            # Check if the final path already exists
            if (Test-Path $fullPath) {
                Write-Host "  Project folder already exists: $fullPath" -ForegroundColor Yellow
                Write-Host "  Please choose a different name or location." -ForegroundColor Gray
                continue
            }
            
            return @{ Path = $fullPath; Name = $projectName; IsCustom = $true }
        }
        
        # Path doesn't exist - check if it's a file that exists
        if (Test-Path $fullPath -PathType Leaf) {
            Write-Host "  A file already exists at: $fullPath" -ForegroundColor Yellow
            Write-Host "  Please choose a different location." -ForegroundColor Gray
            continue
        }
        
        # Path doesn't exist at all - use it as the full project path
        $extractedName = if ($ProvidedName) { $ProvidedName } else { Split-Path -Leaf $fullPath }
        return @{ Path = $fullPath; Name = $extractedName; IsCustom = $true }
    }
}

# Step 4: Get fork location
Write-Step 4 6 "Configuring fork location..."

$locationResult = Get-ForkLocation -DefaultDir $forksDir -ProvidedPath $script:ForkPath -ProvidedName $script:ForkName

# Validate the result immediately
if (-not $locationResult -or -not $locationResult.Path) {
    Write-Host "ERROR: Get-ForkLocation returned invalid result!" -ForegroundColor Red
    exit 1
}

$forkPath = $locationResult.Path
$Name = $locationResult.Name
$useCustomPath = $locationResult.IsCustom
$safeName = $Name -replace '[^a-zA-Z0-9_-]', '-'

Write-Info "Location: $forkPath"
Write-Info "Name: $Name"

if ($useCustomPath) {
    Write-Info "Using custom location"
} else {
    Write-Info "Using default .ralph/forks location"
}

# Step 5: Confirmation
Write-Host "`n========================================"  -ForegroundColor Yellow
Write-Host "FORK PLAN:" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "`nSource: $forkSourceUrl" -ForegroundColor Cyan
if ($LocalOnly) {
    Write-Host "Mode:   LOCAL ONLY" -ForegroundColor Yellow
    Write-Host "Local:  $forkPath" -ForegroundColor Cyan
} else {
    Write-Host "GitHub: github.com/$ghUser/$safeName" -ForegroundColor Cyan
    Write-Host "Local:  $forkPath" -ForegroundColor Cyan
}
Write-Host "`n========================================`n" -ForegroundColor Yellow

# Build confirmation message with details
$confirmTitle = "Confirm Fork"
if ($LocalOnly) {
    $confirmMessage = "Mode: LOCAL ONLY`nPath: $forkPath`n`nProceed with fork?"
} else {
    $confirmMessage = "Mode: GitHub Fork`nGitHub: github.com/$ghUser/$safeName`nPath: $forkPath`n`nProceed with fork?"
}

if ($script:MenusLoaded) {
    $confirmed = Show-ArrowConfirm -Title $confirmTitle -Message $confirmMessage -DefaultYes:$true
    if (-not $confirmed) {
        Write-Host "Aborted." -ForegroundColor Gray
        exit 0
    }
} else {
    $confirm = Read-Host "Proceed? ([Y]es/no)"
    if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = 'y' }
    if ($confirm -notmatch "^(y|yes)$") {
        Write-Host "Aborted." -ForegroundColor Gray
        exit 0
    }
}

# Step 6: Execute
Write-Header "Creating Fork"

# Validate fork path
if ([string]::IsNullOrWhiteSpace($forkPath)) {
    Write-Host "ERROR: Fork path is empty!" -ForegroundColor Red
    exit 1
}

if (Test-Path $forkPath -PathType Leaf) {
    Write-Host "ERROR: Fork path points to an existing file: $forkPath" -ForegroundColor Red
    exit 1
}

if (Test-Path $forkPath -PathType Container) {
    $items = Get-ChildItem -Path $forkPath -Force
    if ($items.Count -gt 0) {
        Write-Host "ERROR: Fork path already exists and is not empty: $forkPath" -ForegroundColor Red
        exit 1
    }
}

# Ensure parent directory exists
if ($useCustomPath) {
    $parentDir = Split-Path -Parent $forkPath
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
} else {
    # Ensure forks directory exists
    if (-not (Test-Path $forksDir)) {
        New-Item -ItemType Directory -Path $forksDir -Force | Out-Null
    }
}

if ($LocalOnly) {
    Write-Step 1 3 "Cloning repository locally..."
    Write-Info "Source: $forkSourceUrl"
    Write-Info "Target: $forkPath"
    $cloneOutput = git clone $forkSourceUrl $forkPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nERROR: Failed to clone repository!" -ForegroundColor Red
        Write-Host "Git error output:" -ForegroundColor Yellow
        $cloneOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        exit 1
    }
    
    Write-Step 2 3 "Creating fresh git repository..."
    # Remove original git history to create independent repository
    $gitDir = Join-Path $forkPath ".git"
    if (Test-Path $gitDir) {
        Remove-Item -Path $gitDir -Recurse -Force
    }
    
    # Initialize new empty git repository
    Push-Location $forkPath
    git init 2>$null | Out-Null
    git add -A 2>$null | Out-Null
    git commit -m "Initial commit from Ralph template" 2>$null | Out-Null
    Pop-Location
    Write-Info "Created new independent git repository"
    
    Write-Step 3 3 "Saving source configuration..."
    # Save source configuration (for reference, not as git remote)
    $ralphDir = Join-Path $forkPath ".ralph"
    if (-not (Test-Path $ralphDir)) {
        New-Item -ItemType Directory -Path $ralphDir -Force | Out-Null
    }
    
    $sourceConfig = @{
        url = $forkSourceUrl
        owner = $forkSourceOwner
        repo = $forkSourceRepo
        type = "local-copy"
        created = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    } | ConvertTo-Json -Depth 5
    
    $configPath = Join-Path $ralphDir "source.json"
    $sourceConfig | Set-Content $configPath -Encoding UTF8
    Write-Info "Source info saved: .ralph/source.json"
} else {
    Write-Step 1 4 "Creating fork on GitHub..."
    $forkResult = gh repo fork "$forkSourceOwner/$forkSourceRepo" --fork-name $safeName --clone=false 2>&1
    if ($LASTEXITCODE -ne 0) {
        $existingRepo = Get-RepoInfo -Owner $ghUser -Repo $safeName
        if (-not $existingRepo) {
            Write-Host "ERROR: Failed to create fork: $forkResult" -ForegroundColor Red
            exit 1
        }
        Write-Host "  Fork already exists, continuing..." -ForegroundColor Yellow
    }
    
    Write-Step 2 4 "Cloning fork locally..."
    Write-Info "Cloning: https://github.com/$ghUser/$safeName.git"
    $cloneOutput = git clone "https://github.com/$ghUser/$safeName.git" $forkPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nERROR: Failed to clone fork!" -ForegroundColor Red
        Write-Host "Git error output:" -ForegroundColor Yellow
        $cloneOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        exit 1
    }
    
    Write-Step 3 4 "Setting up upstream remote..."
    Push-Location $forkPath
    git remote add upstream $forkSourceUrl 2>$null
    Pop-Location
    Write-Info "Origin: https://github.com/$ghUser/$safeName (your fork - push here)"
    Write-Info "Upstream: $forkSourceUrl (read-only, for pulling updates)"
    
    Write-Step 4 4 "Saving fork configuration..."
    $ralphDir = Join-Path $forkPath ".ralph"
    if (-not (Test-Path $ralphDir)) {
        New-Item -ItemType Directory -Path $ralphDir -Force | Out-Null
    }
    
    $forkConfig = @{
        origin = "https://github.com/$ghUser/$safeName"
        upstream = $forkSourceUrl
        upstreamOwner = $forkSourceOwner
        upstreamRepo = $forkSourceRepo
        type = "github-fork"
        created = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    } | ConvertTo-Json -Depth 5
    
    $configPath = Join-Path $ralphDir "upstream.json"
    $forkConfig | Set-Content $configPath -Encoding UTF8
    Write-Info "Fork config saved: .ralph/upstream.json"
}

Write-Header "Success!"
Write-Host "Location: $forkPath" -ForegroundColor Green
if (-not $LocalOnly) { Write-Host "GitHub:   https://github.com/$ghUser/$safeName" -ForegroundColor Cyan }

# Post-fork action menu
function Show-PostForkActions {
    param(
        [string]$ProjectPath,
        [string]$ProjectName
    )
    
    $ralphScript = Join-Path $ProjectPath "ralph\ralph.ps1"
    
    if ($script:MenusLoaded) {
        $choices = @(
            @{ Label = "Open in VS Code"; Value = 'vscode'; Hotkey = '1'; Default = $true }
            @{ Label = "Open folder in Explorer"; Value = 'explorer'; Hotkey = '2' }
            @{ Label = "Open new terminal here"; Value = 'terminal'; Hotkey = '3' }
            @{ Label = "Open new terminal and start Ralph"; Value = 'ralph'; Hotkey = '4' }
            @{ Label = "Open all (VS Code + Explorer + Terminal)"; Value = 'all'; Hotkey = '5' }
            @{ Label = "Do nothing (exit)"; Value = 'none'; Hotkey = '6' }
        )
        
        Write-Host ""
        $action = Show-ArrowChoice -Title "What would you like to do next?" -NoBack -Choices $choices
    } else {
        Write-Host ""
        Write-Host "What would you like to do next?" -ForegroundColor White
        Write-Host "  [1] Open in VS Code" -ForegroundColor Cyan
        Write-Host "  [2] Open folder in Explorer" -ForegroundColor Cyan
        Write-Host "  [3] Open new terminal here" -ForegroundColor Cyan
        Write-Host "  [4] Open new terminal and start Ralph" -ForegroundColor Cyan
        Write-Host "  [5] Open all (VS Code + Explorer + Terminal)" -ForegroundColor Cyan
        Write-Host "  [6] Do nothing (exit)" -ForegroundColor Cyan
        Write-Host ""
        
        do { 
            $choice = Read-Host "Enter choice (1-6)" 
        } while ($choice -notmatch "^[1-6]$")
        
        $action = switch ($choice) {
            '1' { 'vscode' }
            '2' { 'explorer' }
            '3' { 'terminal' }
            '4' { 'ralph' }
            '5' { 'all' }
            '6' { 'none' }
        }
    }
    
    # Track if we should exit the terminal after completion
    $exitAfter = $false
    
    switch ($action) {
        'vscode' {
            Write-Host "`nOpening in VS Code..." -ForegroundColor Gray
            code $ProjectPath
            $exitAfter = $true
        }
        'explorer' {
            Write-Host "`nOpening folder in Explorer..." -ForegroundColor Gray
            Start-Process explorer.exe -ArgumentList $ProjectPath
            $exitAfter = $true
        }
        'terminal' {
            Write-Host "`nOpening new terminal at: $ProjectPath" -ForegroundColor Gray
            $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
            Start-Process $shell -WorkingDirectory $ProjectPath
            $exitAfter = $true
        }
        'ralph' {
            Write-Host "`nOpening new terminal and starting Ralph..." -ForegroundColor Gray
            $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
            Start-Process $shell -WorkingDirectory $ProjectPath -ArgumentList "-NoExit", "-Command", "& '$ralphScript'"
            $exitAfter = $true
        }
        'all' {
            Write-Host "`nOpening VS Code..." -ForegroundColor Gray
            code $ProjectPath
            Write-Host "Opening folder in Explorer..." -ForegroundColor Gray
            Start-Process explorer.exe -ArgumentList $ProjectPath
            Write-Host "Opening new terminal..." -ForegroundColor Gray
            $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
            Start-Process $shell -WorkingDirectory $ProjectPath
            $exitAfter = $true
        }
        'none' {
            Write-Host "`nDone! To start Ralph later, run:" -ForegroundColor Gray
            Write-Host "  cd `"$ProjectPath`" && ./ralph/ralph.ps1" -ForegroundColor Yellow
        }
        default {
            Write-Host "`nDone! To start Ralph later, run:" -ForegroundColor Gray
            Write-Host "  cd `"$ProjectPath`" && ./ralph/ralph.ps1" -ForegroundColor Yellow
        }
    }
    
    return $exitAfter
}

$shouldExit = Show-PostForkActions -ProjectPath $forkPath -ProjectName $Name

if ($shouldExit) {
    Write-Host "`nClosing this terminal..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 500
    exit 0
}

Write-Host ""

#endregion
