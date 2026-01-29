<#
.SYNOPSIS
    Path utilities for Ralph - cross-platform path normalization and validation

.DESCRIPTION
    Provides robust path handling including:
    - Path normalization (fixing common format issues)
    - Cross-platform path conversion
    - Path validation and existence checks
#>

# ═══════════════════════════════════════════════════════════════
#                     PATH NORMALIZATION
# ═══════════════════════════════════════════════════════════════

function Normalize-Path {
    <#
    .SYNOPSIS
        Normalizes a path to handle common format issues
    .DESCRIPTION
        Fixes common path problems:
        - "d:Temp" → "D:\Temp" (missing backslash after drive letter)
        - "d:/Temp" → "D:\Temp" (forward slashes on Windows)
        - "/c/Users" → "C:\Users" (Git Bash style paths)
        - Relative paths → Absolute paths
        - Trailing slashes/backslashes (removes them)
        - Environment variables expansion
    .PARAMETER Path
        The path to normalize
    .PARAMETER BasePath
        Base path for resolving relative paths (default: current location)
    .OUTPUTS
        Normalized path string
    .EXAMPLE
        Normalize-Path "d:Temp"
        Returns "D:\Temp"
    .EXAMPLE
        Normalize-Path "~/Documents"
        Returns "C:\Users\YourName\Documents" (expands ~)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$BasePath = ''
    )
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }
    
    # Trim whitespace
    $Path = $Path.Trim()
    
    # Expand environment variables
    $Path = [System.Environment]::ExpandEnvironmentVariables($Path)
    
    # Handle home directory (~)
    if ($Path -match '^~[/\\]?' -or $Path -eq '~') {
        $Path = $Path -replace '^~', $HOME
    }
    
    # Fix drive letter format: "d:Temp" → "d:\Temp"
    if ($Path -match '^([A-Za-z]):([^\\])') {
        $Path = $Path -replace '^([A-Za-z]):([^\\])', '$1:\$2'
    }
    
    # Convert forward slashes to backslashes on Windows
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or (-not $IsLinux -and -not $IsMacOS)) {
        $Path = $Path -replace '/', '\'
        
        # Handle Git Bash style paths: /c/Users → C:\Users
        if ($Path -match '^/([a-zA-Z])/(.+)$') {
            $drive = $Matches[1].ToUpper()
            $rest = $Matches[2]
            $Path = "${drive}:\${rest}"
        }
    }
    
    # Handle relative paths
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        $base = if ($BasePath) { $BasePath } else { Get-Location }
        $Path = Join-Path $base $Path
    }
    
    # Resolve to absolute path if it exists
    if (Test-Path -LiteralPath $Path -ErrorAction SilentlyContinue) {
        try {
            $Path = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
        } catch {
            # If Resolve-Path fails, use GetFullPath
            $Path = [System.IO.Path]::GetFullPath($Path)
        }
    } else {
        # Path doesn't exist yet, just normalize it
        try {
            $Path = [System.IO.Path]::GetFullPath($Path)
        } catch {
            # If GetFullPath fails, leave as-is
        }
    }
    
    # Remove trailing directory separators
    $Path = $Path.TrimEnd('\', '/')
    
    return $Path
}

function Test-PathExists {
    <#
    .SYNOPSIS
        Tests if a path exists after normalization
    .PARAMETER Path
        The path to test
    .PARAMETER Type
        Expected type: 'File', 'Directory', or 'Any'
    .PARAMETER Normalize
        If true, normalize the path first
    .OUTPUTS
        Boolean indicating if path exists and meets type requirement
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [ValidateSet('File', 'Directory', 'Any')]
        [string]$Type = 'Any',
        
        [switch]$Normalize
    )
    
    if ($Normalize) {
        $Path = Normalize-Path -Path $Path
    }
    
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    
    if ($Type -eq 'Any') {
        return $true
    }
    
    if ($Type -eq 'Directory') {
        return (Test-Path -LiteralPath $Path -PathType Container)
    }
    
    if ($Type -eq 'File') {
        return (Test-Path -LiteralPath $Path -PathType Leaf)
    }
    
    return $false
}

function ConvertTo-RelativePath {
    <#
    .SYNOPSIS
        Converts an absolute path to relative path from a base
    .PARAMETER Path
        The absolute path to convert
    .PARAMETER BasePath
        The base path (default: current location)
    .OUTPUTS
        Relative path string
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$BasePath = ''
    )
    
    $Path = Normalize-Path -Path $Path
    $base = if ($BasePath) { Normalize-Path -Path $BasePath } else { Get-Location }
    
    # Use Push-Location/Pop-Location to get relative path
    Push-Location $base
    try {
        $relative = Resolve-Path -Relative -LiteralPath $Path -ErrorAction SilentlyContinue
        if ($relative) {
            # Remove leading .\ or ./
            $relative = $relative -replace '^\.[/\\]', ''
            return $relative
        }
    } catch {
        # Fall back to manual calculation if Resolve-Path fails
    } finally {
        Pop-Location
    }
    
    # Fallback: return original path if conversion fails
    return $Path
}
