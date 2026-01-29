<#
.SYNOPSIS
    Error classification and handling module for Ralph Loop

.DESCRIPTION
    Provides centralized error handling with:
    - Error classification (fatal, transient, critical)
    - User-friendly error messages
    - Integration with checkpoint/recovery system
    
    Error Types:
    - FATAL: Cannot continue, must return to menu (quota, auth)
    - TRANSIENT: Retry with backoff (network, rate limits)
    - CRITICAL: System-level issues (server down, service unavailable)

.NOTES
    This module should be sourced early in loop.ps1 initialization.
#>

# ═══════════════════════════════════════════════════════════════
#                     ERROR TYPES
# ═══════════════════════════════════════════════════════════════

# Error type enumeration
$script:ErrorTypes = @{
    Fatal     = 'Fatal'      # Non-recoverable, must stop
    Transient = 'Transient'  # Can retry with backoff
    Critical  = 'Critical'   # System-level, stop with message
    Unknown   = 'Unknown'    # Unclassified error
}

# Error patterns for classification
$script:ErrorPatterns = @{
    # Fatal errors - cannot continue without user action
    Fatal = @(
        @{ Pattern = 'CAPIError.*402'; Message = 'Token quota exhausted'; CanResume = $true }
        @{ Pattern = 'no quota'; Message = 'Token quota exhausted'; CanResume = $true }
        @{ Pattern = 'quota.*exceeded'; Message = 'Token quota exceeded'; CanResume = $true }
        @{ Pattern = 'insufficient.*quota'; Message = 'Insufficient token quota'; CanResume = $true }
        @{ Pattern = 'billing.*required'; Message = 'Billing issue - payment required'; CanResume = $true }
        @{ Pattern = '401.*unauthorized'; Message = 'Authentication failed'; CanResume = $false }
        @{ Pattern = 'authentication.*failed'; Message = 'Authentication failed'; CanResume = $false }
        @{ Pattern = 'invalid.*token'; Message = 'Invalid authentication token'; CanResume = $false }
        @{ Pattern = 'access.*denied'; Message = 'Access denied'; CanResume = $false }
        @{ Pattern = '403.*forbidden'; Message = 'Access forbidden'; CanResume = $false }
    )
    
    # Transient errors - can retry
    Transient = @(
        @{ Pattern = 'network'; Message = 'Network error'; RetryAfter = 5 }
        @{ Pattern = 'connection'; Message = 'Connection error'; RetryAfter = 5 }
        @{ Pattern = 'timeout'; Message = 'Request timeout'; RetryAfter = 10 }
        @{ Pattern = 'temporarily unavailable'; Message = 'Service temporarily unavailable'; RetryAfter = 15 }
        @{ Pattern = 'socket'; Message = 'Socket error'; RetryAfter = 5 }
        @{ Pattern = 'dns'; Message = 'DNS resolution failed'; RetryAfter = 5 }
        @{ Pattern = 'host not found'; Message = 'Host not found'; RetryAfter = 5 }
        @{ Pattern = 'unable to connect'; Message = 'Unable to connect'; RetryAfter = 5 }
        @{ Pattern = 'connection refused'; Message = 'Connection refused'; RetryAfter = 5 }
        @{ Pattern = 'network unreachable'; Message = 'Network unreachable'; RetryAfter = 10 }
        @{ Pattern = 'ECONNRESET'; Message = 'Connection reset'; RetryAfter = 5 }
        @{ Pattern = 'ETIMEDOUT'; Message = 'Connection timed out'; RetryAfter = 10 }
        @{ Pattern = 'ENOTFOUND'; Message = 'DNS lookup failed'; RetryAfter = 5 }
        @{ Pattern = 'rate limit'; Message = 'Rate limit exceeded'; RetryAfter = 30 }
        @{ Pattern = '429'; Message = 'Too many requests'; RetryAfter = 30 }
    )
    
    # Critical errors - system-level issues
    Critical = @(
        @{ Pattern = '500'; Message = 'Server internal error'; CanResume = $true }
        @{ Pattern = '502'; Message = 'Bad gateway'; CanResume = $true }
        @{ Pattern = '503'; Message = 'Service unavailable'; CanResume = $true }
        @{ Pattern = '504'; Message = 'Gateway timeout'; CanResume = $true }
        @{ Pattern = 'service.*down'; Message = 'Service is down'; CanResume = $true }
        @{ Pattern = 'server.*unavailable'; Message = 'Server unavailable'; CanResume = $true }
        @{ Pattern = 'maintenance'; Message = 'Service under maintenance'; CanResume = $true }
    )
}

# ═══════════════════════════════════════════════════════════════
#                     ERROR CLASSIFICATION
# ═══════════════════════════════════════════════════════════════

function Get-ErrorClassification {
    <#
    .SYNOPSIS
        Classifies an error message and returns detailed error info
    .PARAMETER ErrorMessage
        The error message to classify
    .OUTPUTS
        Hashtable with: Type, Message, CanResume, RetryAfter, OriginalMessage
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ErrorMessage
    )
    
    $errorLower = $ErrorMessage.ToLower()
    
    # Check fatal errors first (highest priority)
    foreach ($pattern in $script:ErrorPatterns.Fatal) {
        if ($errorLower -match $pattern.Pattern) {
            return @{
                Type            = $script:ErrorTypes.Fatal
                Message         = $pattern.Message
                CanResume       = $pattern.CanResume
                RetryAfter      = $null
                OriginalMessage = $ErrorMessage
            }
        }
    }
    
    # Check transient errors
    foreach ($pattern in $script:ErrorPatterns.Transient) {
        if ($errorLower -match $pattern.Pattern) {
            return @{
                Type            = $script:ErrorTypes.Transient
                Message         = $pattern.Message
                CanResume       = $true
                RetryAfter      = $pattern.RetryAfter
                OriginalMessage = $ErrorMessage
            }
        }
    }
    
    # Check critical errors
    foreach ($pattern in $script:ErrorPatterns.Critical) {
        if ($errorLower -match $pattern.Pattern) {
            return @{
                Type            = $script:ErrorTypes.Critical
                Message         = $pattern.Message
                CanResume       = $pattern.CanResume
                RetryAfter      = $null
                OriginalMessage = $ErrorMessage
            }
        }
    }
    
    # Unknown error type
    return @{
        Type            = $script:ErrorTypes.Unknown
        Message         = 'An unexpected error occurred'
        CanResume       = $true
        RetryAfter      = $null
        OriginalMessage = $ErrorMessage
    }
}

function Test-FatalError {
    <#
    .SYNOPSIS
        Quick check if an error is fatal (non-recoverable)
    .PARAMETER ErrorMessage
        The error message to check
    .OUTPUTS
        Boolean - true if error is fatal
    #>
    param([string]$ErrorMessage)
    
    $classification = Get-ErrorClassification -ErrorMessage $ErrorMessage
    return $classification.Type -eq $script:ErrorTypes.Fatal
}

function Test-TransientError {
    <#
    .SYNOPSIS
        Quick check if an error is transient (can retry)
    .PARAMETER ErrorMessage
        The error message to check
    .OUTPUTS
        Boolean - true if error is transient
    #>
    param([string]$ErrorMessage)
    
    $classification = Get-ErrorClassification -ErrorMessage $ErrorMessage
    return $classification.Type -eq $script:ErrorTypes.Transient
}

function Test-CriticalError {
    <#
    .SYNOPSIS
        Quick check if an error is critical (system-level)
    .PARAMETER ErrorMessage
        The error message to check
    .OUTPUTS
        Boolean - true if error is critical
    #>
    param([string]$ErrorMessage)
    
    $classification = Get-ErrorClassification -ErrorMessage $ErrorMessage
    return $classification.Type -eq $script:ErrorTypes.Critical
}

# ═══════════════════════════════════════════════════════════════
#                     ERROR DISPLAY
# ═══════════════════════════════════════════════════════════════

function Show-RalphError {
    <#
    .SYNOPSIS
        Displays a user-friendly error message with recovery options
    .PARAMETER ErrorInfo
        Hashtable from Get-ErrorClassification
    .PARAMETER ShowResume
        Whether to show resume information
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ErrorInfo,
        
        [switch]$ShowResume
    )
    
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║                     RALPH STOPPED                         ║" -ForegroundColor Red
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    # Error type indicator
    $typeColor = switch ($ErrorInfo.Type) {
        'Fatal'     { 'Red' }
        'Transient' { 'Yellow' }
        'Critical'  { 'Magenta' }
        default     { 'Gray' }
    }
    
    Write-Host "  Error Type: " -NoNewline -ForegroundColor Gray
    Write-Host $ErrorInfo.Type.ToUpper() -ForegroundColor $typeColor
    Write-Host ""
    
    # Main error message
    Write-Host "  ⛔ $($ErrorInfo.Message)" -ForegroundColor Red
    Write-Host ""
    
    # Original error details (truncated if too long)
    if ($ErrorInfo.OriginalMessage -and $ErrorInfo.OriginalMessage.Length -gt 0) {
        $truncated = if ($ErrorInfo.OriginalMessage.Length -gt 200) {
            $ErrorInfo.OriginalMessage.Substring(0, 200) + "..."
        } else {
            $ErrorInfo.OriginalMessage
        }
        Write-Host "  Details: $truncated" -ForegroundColor DarkGray
        Write-Host ""
    }
    
    # Recovery guidance based on error type
    Write-Host "  ───────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    switch ($ErrorInfo.Type) {
        'Fatal' {
            if ($ErrorInfo.Message -match 'quota|token') {
                Write-Host "  💡 How to resolve:" -ForegroundColor Cyan
                Write-Host "     1. Get more tokens or upgrade your plan" -ForegroundColor Gray
                Write-Host "     2. Wait for your quota to reset" -ForegroundColor Gray
                Write-Host "     3. Check your billing at github.com/settings/copilot" -ForegroundColor Gray
            } elseif ($ErrorInfo.Message -match 'auth') {
                Write-Host "  💡 How to resolve:" -ForegroundColor Cyan
                Write-Host "     1. Re-authenticate with: gh auth login" -ForegroundColor Gray
                Write-Host "     2. Check your GitHub Copilot subscription" -ForegroundColor Gray
            }
        }
        'Critical' {
            Write-Host "  💡 This appears to be a service issue." -ForegroundColor Cyan
            Write-Host "     The service may be temporarily unavailable." -ForegroundColor Gray
            Write-Host "     Please try again in a few minutes." -ForegroundColor Gray
        }
        'Transient' {
            Write-Host "  💡 This error may be temporary." -ForegroundColor Cyan
            Write-Host "     Ralph will retry automatically if possible." -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    
    # Resume information
    if ($ShowResume -and $ErrorInfo.CanResume) {
        Write-Host "  ✓ Your progress has been saved." -ForegroundColor Green
        Write-Host "    You can resume from where you left off after resolving the issue." -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "  ───────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function Format-ErrorForLog {
    <#
    .SYNOPSIS
        Formats error information for log file
    .PARAMETER ErrorInfo
        Hashtable from Get-ErrorClassification
    .OUTPUTS
        Formatted string for logging
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ErrorInfo
    )
    
    return "[ERROR:$($ErrorInfo.Type)] $($ErrorInfo.Message) | Original: $($ErrorInfo.OriginalMessage)"
}

# ═══════════════════════════════════════════════════════════════
#                     ERROR RESULT WRAPPER
# ═══════════════════════════════════════════════════════════════

function New-ErrorResult {
    <#
    .SYNOPSIS
        Creates a standardized error result object
    .DESCRIPTION
        Used to wrap Copilot results with error information for consistent handling
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ErrorInfo,
        
        [hashtable]$OriginalResult = $null,
        
        [string]$Phase = '',
        
        [int]$Iteration = 0
    )
    
    return @{
        Success       = $false
        Error         = $ErrorInfo
        OriginalResult = $OriginalResult
        Phase         = $Phase
        Iteration     = $Iteration
        Timestamp     = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        ShouldStop    = $ErrorInfo.Type -in @('Fatal', 'Critical')
        CanResume     = $ErrorInfo.CanResume
    }
}

# ═══════════════════════════════════════════════════════════════
#                     EXPORTS
# ═══════════════════════════════════════════════════════════════

# Export error types for external use
function Get-ErrorTypes {
    return $script:ErrorTypes
}
