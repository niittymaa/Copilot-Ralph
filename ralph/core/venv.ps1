<#
.SYNOPSIS
    Python virtual environment management for Ralph

.DESCRIPTION
    Provides functions to create, activate, and manage a Python venv
    that isolates Ralph's operations from the system Python.
    
    The venv is created at .ralph/venv/ in the project root.
#>

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:VenvDir = $null
$script:VenvActivated = $false

function Initialize-VenvPaths {
    param([string]$ProjectRoot)
    
    $script:RalphDir = Join-Path $ProjectRoot '.ralph'
    $script:VenvDir = Join-Path $RalphDir 'venv'
    $script:VenvPython = Join-Path $VenvDir 'Scripts\python.exe'
    $script:VenvPip = Join-Path $VenvDir 'Scripts\pip.exe'
    $script:VenvActivate = Join-Path $VenvDir 'Scripts\Activate.ps1'
}

# ═══════════════════════════════════════════════════════════════
#                        VENV FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Test-VenvExists {
    <#
    .SYNOPSIS
        Check if the venv already exists
    #>
    return (Test-Path $VenvPython)
}

function Test-PythonAvailable {
    <#
    .SYNOPSIS
        Check if Python 3 is available on the system
    .NOTES
        Checks python3 first for consistency with Bash implementation.
        This ensures Python 3 is preferred on systems with both Python 2 and 3.
    #>
    # Try python3 first (preferred)
    try {
        $version = python3 --version 2>&1
        if ($version -match 'Python 3\.\d+') {
            return $true
        }
    } catch {}
    
    # Fall back to python, but verify it's Python 3
    try {
        $version = python --version 2>&1
        if ($version -match 'Python 3\.\d+') {
            return $true
        }
    } catch {}
    
    return $false
}

function Get-PythonCommand {
    <#
    .SYNOPSIS
        Get the Python command to use (python3 or python)
    .NOTES
        Returns python3 if available, otherwise python (if it's Python 3).
        Consistent with Bash implementation.
    #>
    # Try python3 first (preferred)
    try {
        $null = python3 --version 2>&1
        return 'python3'
    } catch {}
    
    # Fall back to python, but verify it's Python 3
    try {
        $version = python --version 2>&1
        if ($version -match 'Python 3\.\d+') {
            return 'python'
        }
    } catch {}
    
    return $null
}

function Test-VenvNeeded {
    <#
    .SYNOPSIS
        Intelligently detect if the project needs a Python virtual environment
    
    .DESCRIPTION
        Checks for indicators that suggest Python package management is needed.
        Returns false for documentation-only projects, single HTML files, etc.
    
    .PARAMETER ProjectRoot
        Root directory of the project to analyze
    
    .OUTPUTS
        Boolean - true if project appears to need venv, false otherwise
    #>
    param(
        [string]$ProjectRoot = (Get-Location).Path
    )
    
    # Strong indicators that venv IS needed
    $pythonIndicators = @(
        'requirements.txt',
        'requirements-dev.txt',
        'requirements-test.txt',
        'Pipfile',
        'Pipfile.lock',
        'pyproject.toml',
        'setup.py',
        'setup.cfg',
        'poetry.lock',
        'conda.yaml',
        'environment.yml',
        'environment.yaml'
    )
    
    foreach ($file in $pythonIndicators) {
        if (Test-Path (Join-Path $ProjectRoot $file)) {
            return $true
        }
    }
    
    # Check for .py files in root or common directories
    $pyFiles = Get-ChildItem -Path $ProjectRoot -Filter '*.py' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pyFiles) { return $true }
    
    # Check common Python directories
    $pythonDirs = @('src', 'lib', 'app', 'scripts', 'tests', 'test')
    foreach ($dir in $pythonDirs) {
        $dirPath = Join-Path $ProjectRoot $dir
        if (Test-Path $dirPath) {
            $pyInDir = Get-ChildItem -Path $dirPath -Filter '*.py' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pyInDir) { return $true }
        }
    }
    
    # Check for Jupyter notebooks
    $notebooks = Get-ChildItem -Path $ProjectRoot -Filter '*.ipynb' -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($notebooks) { return $true }
    
    # If we get here, no Python indicators found
    return $false
}

function Get-PythonCommand {
    <#
    .SYNOPSIS
        Get the Python command to use (python or python3)
    #>
    try {
        $null = python --version 2>&1
        return 'python'
    } catch {}
    
    try {
        $null = python3 --version 2>&1
        return 'python3'
    } catch {}
    
    return $null
}

function New-RalphVenv {
    <#
    .SYNOPSIS
        Create the Python virtual environment
    
    .PARAMETER Force
        Recreate the venv even if it exists (with confirmation)
    
    .PARAMETER SkipConfirm
        Skip confirmation when Force is used
    #>
    param(
        [switch]$Force,
        [switch]$SkipConfirm
    )
    
    if (-not $VenvDir) {
        Write-Host "[venv] Error: Venv paths not initialized" -ForegroundColor Red
        return $false
    }
    
    # Check if venv already exists
    if ((Test-VenvExists) -and -not $Force) {
        Write-Host "[venv] Virtual environment exists at $VenvDir" -ForegroundColor Gray
        return $true
    }
    
    # Check Python availability
    $pythonCmd = Get-PythonCommand
    if (-not $pythonCmd) {
        Write-Host "[venv] Python not found. Install Python to enable venv isolation." -ForegroundColor Yellow
        return $false
    }
    
    # Ensure .ralph directory exists
    if (-not (Test-Path $RalphDir)) {
        New-Item -ItemType Directory -Path $RalphDir -Force | Out-Null
    }
    
    # Remove existing venv if Force (with confirmation)
    if ($Force -and (Test-Path $VenvDir)) {
        if (-not $SkipConfirm) {
            Write-Host ""
            Write-Host "  Existing virtual environment found at:" -ForegroundColor Yellow
            Write-Host "  $VenvDir" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  This will remove it and create a new one." -ForegroundColor Yellow
            Write-Host "  Any custom packages you installed will be lost." -ForegroundColor Yellow
            Write-Host ""
            
            $confirmed = Show-DangerConfirmMenu -Title "Reset Virtual Environment" -Message "Remove and recreate the virtual environment?" -ConfirmText "yes"
            if (-not $confirmed) {
                Write-Host "  Cancelled." -ForegroundColor Gray
                return $false
            }
            Write-Host ""
        }
        Write-Host "[venv] Removing existing virtual environment..." -ForegroundColor Yellow
        Remove-Item -Path $VenvDir -Recurse -Force
    }
    
    # Create the venv
    Write-Host "[venv] Creating virtual environment at $VenvDir..." -ForegroundColor Cyan
    
    try {
        & $pythonCmd -m venv $VenvDir 2>&1 | Out-Null
        
        if (Test-VenvExists) {
            Write-Host "[venv] Virtual environment created successfully" -ForegroundColor Green
            
            # Upgrade pip in the venv
            Write-Host "[venv] Upgrading pip..." -ForegroundColor Gray
            & $VenvPython -m pip install --upgrade pip --quiet 2>&1 | Out-Null
            
            return $true
        } else {
            Write-Host "[venv] Failed to create virtual environment" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[venv] Error creating virtual environment: $_" -ForegroundColor Red
        return $false
    }
}

function Enable-RalphVenv {
    <#
    .SYNOPSIS
        Activate the virtual environment for the current session
    #>
    # In dry-run mode, skip venv creation but pretend it's active
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        Write-Host "[venv] [DRY RUN] Would activate virtual environment" -ForegroundColor Yellow
        if (Get-Command Add-DryRunAction -ErrorAction SilentlyContinue) {
            Add-DryRunAction -Type 'Other' -Description "Activate Python virtual environment"
        }
        return $true
    }
    
    if (-not $VenvDir) {
        Write-Host "[venv] Error: Venv paths not initialized" -ForegroundColor Red
        return $false
    }
    
    if (-not (Test-VenvExists)) {
        Write-Host "[venv] Virtual environment not found. Creating..." -ForegroundColor Yellow
        if (-not (New-RalphVenv)) {
            return $false
        }
    }
    
    if ($script:VenvActivated) {
        return $true
    }
    
    # Set environment variables to use the venv
    $env:VIRTUAL_ENV = $VenvDir
    $env:PATH = "$(Join-Path $VenvDir 'Scripts');$env:PATH"
    
    # Unset PYTHONHOME if set
    if ($env:PYTHONHOME) {
        Remove-Item Env:\PYTHONHOME -ErrorAction SilentlyContinue
    }
    
    $script:VenvActivated = $true
    Write-Host "[venv] Activated virtual environment" -ForegroundColor Green
    
    return $true
}

function Disable-RalphVenv {
    <#
    .SYNOPSIS
        Deactivate the virtual environment
    #>
    if ($script:VenvActivated -and $env:VIRTUAL_ENV) {
        # Remove venv Scripts from PATH
        $venvScripts = Join-Path $VenvDir 'Scripts'
        $env:PATH = ($env:PATH -split ';' | Where-Object { $_ -ne $venvScripts }) -join ';'
        
        Remove-Item Env:\VIRTUAL_ENV -ErrorAction SilentlyContinue
        $script:VenvActivated = $false
        
        Write-Host "[venv] Deactivated virtual environment" -ForegroundColor Gray
    }
}

function Remove-RalphVenv {
    <#
    .SYNOPSIS
        Remove the virtual environment completely
    .PARAMETER Force
        Skip confirmation prompt
    #>
    param(
        [switch]$Force
    )
    
    if (-not $VenvDir) {
        Write-Host "[venv] Error: Venv paths not initialized" -ForegroundColor Red
        return $false
    }
    
    # Deactivate first
    Disable-RalphVenv
    
    if (Test-Path $VenvDir) {
        # Confirm before removing (unless Force)
        if (-not $Force) {
            Write-Host ""
            Write-Host "  This will remove the Python virtual environment at:" -ForegroundColor Yellow
            Write-Host "  $VenvDir" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  Any custom packages you installed will be lost." -ForegroundColor Yellow
            Write-Host ""
            
            $confirmed = Show-DangerConfirmMenu -Title "Remove Virtual Environment" -Message "Remove the virtual environment?" -ConfirmText "yes"
            if (-not $confirmed) {
                Write-Host "  Cancelled." -ForegroundColor Gray
                return $false
            }
            Write-Host ""
        }
        
        Write-Host "[venv] Removing virtual environment..." -ForegroundColor Yellow
        Remove-Item -Path $VenvDir -Recurse -Force
        Write-Host "[venv] Virtual environment removed" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[venv] No virtual environment to remove" -ForegroundColor Gray
        return $true
    }
}

function Get-VenvInfo {
    <#
    .SYNOPSIS
        Get information about the current venv state
    #>
    $info = @{
        Exists    = Test-VenvExists
        Activated = $script:VenvActivated
        Path      = $VenvDir
        Python    = $null
        Packages  = @()
    }
    
    if ($info.Exists) {
        try {
            $info.Python = & $VenvPython --version 2>&1
            $packages = & $VenvPip list --format=freeze 2>&1
            $info.Packages = $packages -split "`n" | Where-Object { $_ }
        } catch {}
    }
    
    return $info
}

function Show-VenvStatus {
    <#
    .SYNOPSIS
        Display current venv status
    #>
    $info = Get-VenvInfo
    
    Write-Host ""
    Write-Host "Virtual Environment Status" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Path:      $($info.Path)" -ForegroundColor White
    Write-Host "  Exists:    $($info.Exists)" -ForegroundColor $(if ($info.Exists) { 'Green' } else { 'Yellow' })
    Write-Host "  Activated: $($info.Activated)" -ForegroundColor $(if ($info.Activated) { 'Green' } else { 'Gray' })
    
    if ($info.Python) {
        Write-Host "  Python:    $($info.Python)" -ForegroundColor White
    }
    
    if ($info.Packages.Count -gt 0) {
        Write-Host "  Packages:  $($info.Packages.Count) installed" -ForegroundColor White
    }
    Write-Host ""
}

# Export functions when loaded as a module (silently skip when dot-sourced)
if ($MyInvocation.Line -match 'Import-Module') {
    Export-ModuleMember -Function @(
        'Initialize-VenvPaths',
        'Test-VenvExists',
        'Test-VenvNeeded',
        'Test-PythonAvailable',
        'New-RalphVenv',
        'Enable-RalphVenv',
        'Disable-RalphVenv',
        'Remove-RalphVenv',
        'Get-VenvInfo',
        'Show-VenvStatus'
    )
}
