<#
.SYNOPSIS
    GitHub authentication helpers for Ralph

.DESCRIPTION
    Shows which GitHub account Ralph (Copilot CLI) is using for token consumption.
    Supports account switching if multiple accounts are configured.

.NOTES
    Relies on `gh` CLI being installed and authenticated
#>

function Test-GitHubCLIInstalled {
    try {
        $null = Get-Command 'gh' -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-GitHubAccountDisplay {
    <#
    .SYNOPSIS
        Gets the current GitHub account username for display
    .OUTPUTS
        Username string, or "Not logged in"
    #>
    if (-not (Test-GitHubCLIInstalled)) {
        return "Not logged in"
    }
    
    try {
        $output = gh auth status 2>&1 | Out-String
        
        if ($output -match 'You are not logged into any GitHub hosts') {
            return "Not logged in"
        }
        
        # Format: "Logged in to github.com account USERNAME (keyring)"
        if ($output -match 'Logged in to\s+(\S+)\s+account\s+(\S+)') {
            $hostName = $matches[1]
            $userName = $matches[2]
            if ($hostName -eq 'github.com') {
                return $userName
            } else {
                return "$userName@$hostName"
            }
        }
        
        if ($LASTEXITCODE -eq 0) { return "Logged in" }
    } catch { }
    
    return "Not logged in"
}

function Test-MultipleGitHubAccounts {
    <#
    .SYNOPSIS
        Checks if multiple GitHub accounts are configured
    #>
    try {
        $output = gh auth status 2>&1 | Out-String
        $found = [regex]::Matches($output, 'Logged in to')
        return ($found.Count -gt 1)
    } catch {
        return $false
    }
}

function Get-GitHubAccounts {
    <#
    .SYNOPSIS
        Gets all configured GitHub accounts for switching menu
    .OUTPUTS
        Array of @{ Username, Host, Active, Display }
    #>
    $accounts = @()
    if (-not (Test-GitHubCLIInstalled)) { return $accounts }
    
    try {
        $output = gh auth status 2>&1 | Out-String
        if ($output -match 'You are not logged into any GitHub hosts') { return $accounts }
        
        # Parse "Logged in to HOST account USERNAME" lines
        $regexMatches = [regex]::Matches($output, 'Logged in to\s+(\S+)\s+account\s+(\S+)')
        foreach ($m in $regexMatches) {
            $accounts += @{
                Username = $m.Groups[2].Value
                Host     = $m.Groups[1].Value
                Active   = $true
                Display  = "$($m.Groups[2].Value)@$($m.Groups[1].Value)"
            }
        }
    } catch { }
    
    return $accounts
}

function Switch-GitHubAccount {
    param(
        [string]$Username,
        [string]$Hostname = 'github.com'
    )
    if (-not $Username -or -not (Test-GitHubCLIInstalled)) { return $false }
    
    try {
        gh auth switch --hostname $Hostname --user $Username 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Invoke-GitHubLogin {
    if (-not (Test-GitHubCLIInstalled)) {
        Write-Host "  GitHub CLI (gh) not installed. Get it from: https://cli.github.com" -ForegroundColor Red
        return $false
    }
    gh auth login
    return ($LASTEXITCODE -eq 0)
}
