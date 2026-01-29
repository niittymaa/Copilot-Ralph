<#
.SYNOPSIS
    Comprehensive logging module for Ralph Loop

.DESCRIPTION
    Provides structured, file-based logging for all Ralph operations including:
    - User actions (menu selections, inputs)
    - AI/Copilot interactions (with prompt details)
    - Spec creation workflow
    - Reference management
    - Error tracking with stack traces
    
    Logs are stored in .ralph/logs/ with daily rotation.
    
    Log Tags:
    - [SETTINGS]   - Configuration and settings on startup
    - [SESSION]    - Session lifecycle events
    - [ERROR]      - Error events with stack traces
    - [WARNING]    - Warning events
    - [INFO]       - General informational messages
    - [DEBUG]      - Debug/verbose information (filtered by LogLevel)
    - [COPILOT]    - Copilot CLI invocations with details
    - [TASK]       - Task-related events
    - [BUILD]      - Build phase events
    - [PLAN]       - Planning phase events
    - [AGENT]      - Agent-related events
    - [USER]       - User actions (menu selections, inputs)
    - [SPEC]       - Spec creation events
    - [REFERENCE]  - Reference file operations

.NOTES
    This module should be sourced early in loop.ps1 initialization.
#>

# ═══════════════════════════════════════════════════════════════
#                     MODULE STATE
# ═══════════════════════════════════════════════════════════════

$script:LoggingEnabled = $true
$script:LogFilePath = $null
$script:LogsDir = $null
$script:LogSessionId = $null
$script:LogLevel = 'INFO'  # DEBUG, INFO, WARNING, ERROR

# Log level priorities (lower = more verbose)
$script:LogLevelPriority = @{
    'DEBUG'   = 0
    'INFO'    = 1
    'WARNING' = 2
    'ERROR'   = 3
}

# ═══════════════════════════════════════════════════════════════
#                     INITIALIZATION
# ═══════════════════════════════════════════════════════════════

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initializes the logging system and creates the log file for this session
    .PARAMETER ProjectRoot
        Root directory of the project
    .PARAMETER SessionId
        Optional session ID for log identification
    .PARAMETER LogLevel
        Minimum log level to record (DEBUG, INFO, WARNING, ERROR)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,
        
        [string]$SessionId = '',
        
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$LogLevel = 'INFO'
    )
    
    $script:LogLevel = $LogLevel
    
    # Create logs directory
    $script:LogsDir = Join-Path $ProjectRoot '.ralph\logs'
    if (-not (Test-Path $script:LogsDir)) {
        New-Item -ItemType Directory -Path $script:LogsDir -Force | Out-Null
    }
    
    # Create daily log file
    $today = Get-Date -Format 'yyyy-MM-dd'
    $script:LogFilePath = Join-Path $script:LogsDir "ralph-$today.log"
    $script:LogSessionId = if ($SessionId) { $SessionId } else { [guid]::NewGuid().ToString().Substring(0, 8) }
    
    # Write session start marker
    $separator = "═" * 80
    $sessionStart = @"

$separator
  RALPH SESSION STARTED
  Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  Session ID: $script:LogSessionId
  Log Level: $script:LogLevel
  Working Directory: $ProjectRoot
$separator

"@
    
    Add-Content -Path $script:LogFilePath -Value $sessionStart -Encoding UTF8
    
    return $script:LogFilePath
}

function Set-LogLevel {
    <#
    .SYNOPSIS
        Sets the minimum log level
    #>
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Level
    )
    $script:LogLevel = $Level
}

# ═══════════════════════════════════════════════════════════════
#                     CORE LOGGING
# ═══════════════════════════════════════════════════════════════

function Write-Log {
    <#
    .SYNOPSIS
        Writes a tagged log entry to the log file
    .PARAMETER Message
        The message to log
    .PARAMETER Tag
        The log tag
    .PARAMETER Level
        Log level for filtering (defaults based on tag)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('SETTINGS', 'SESSION', 'ERROR', 'WARNING', 'INFO', 'DEBUG', 'COPILOT', 'TASK', 'BUILD', 'PLAN', 'AGENT', 'USER', 'SPEC', 'REFERENCE')]
        [string]$Tag = 'INFO',
        
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Level = ''
    )
    
    if (-not $script:LoggingEnabled -or -not $script:LogFilePath) {
        return
    }
    
    # Determine effective log level
    $effectiveLevel = if ($Level) { 
        $Level 
    } elseif ($Tag -eq 'ERROR') { 
        'ERROR' 
    } elseif ($Tag -eq 'WARNING') { 
        'WARNING' 
    } elseif ($Tag -eq 'DEBUG') { 
        'DEBUG' 
    } else { 
        'INFO' 
    }
    
    # Filter by log level
    $msgPriority = $script:LogLevelPriority[$effectiveLevel]
    $currentPriority = $script:LogLevelPriority[$script:LogLevel]
    if ($msgPriority -lt $currentPriority) {
        return
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logEntry = "[$timestamp] [$Tag] $Message"
    
    try {
        Add-Content -Path $script:LogFilePath -Value $logEntry -Encoding UTF8
    }
    catch {
        # Silently fail if we can't write to log
    }
}

# ═══════════════════════════════════════════════════════════════
#                     USER ACTION LOGGING
# ═══════════════════════════════════════════════════════════════

function Write-LogUserAction {
    <#
    .SYNOPSIS
        Logs user actions like menu selections and inputs
    .PARAMETER Action
        Type of action (MENU_SELECT, INPUT, CONFIRM, CANCEL, NAVIGATE)
    .PARAMETER Context
        Where the action occurred (menu name, prompt, etc.)
    .PARAMETER Selection
        What the user selected/entered
    .PARAMETER Value
        Alternative to Selection for data values
    .PARAMETER Details
        Optional additional details
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('MENU_SELECT', 'INPUT', 'CONFIRM', 'CANCEL', 'NAVIGATE', 'HOTKEY', 'BACK', 'QUIT')]
        [string]$Action,
        
        [Parameter(Mandatory)]
        [string]$Context,
        
        [string]$Selection = '',
        [string]$Value = '',
        [string]$Details = ''
    )
    
    $msg = "User $Action in [$Context]"
    if ($Selection) { $msg += " | Selected: '$Selection'" }
    if ($Value) { $msg += " | Value: $Value" }
    if ($Details) { $msg += " | $Details" }
    
    Write-Log -Message $msg -Tag USER
}

# ═══════════════════════════════════════════════════════════════
#                     SPEC CREATION LOGGING
# ═══════════════════════════════════════════════════════════════

function Write-LogSpecCreation {
    <#
    .SYNOPSIS
        Logs spec creation workflow events
    .PARAMETER Action
        Action type (STARTED, MODE_SELECTED, REFERENCES_LOADED, PROMPT_BUILT, AI_CALLED, COMPLETED, FAILED)
    .PARAMETER Mode
        Spec creation mode (interview, quick, from-references)
    .PARAMETER Details
        Additional details
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('STARTED', 'MODE_SELECTED', 'REFERENCES_LOADED', 'PROMPT_BUILT', 'AI_CALLED', 'AI_RETURNED', 'COMPLETED', 'FAILED', 'CANCELLED')]
        [string]$Action,
        
        [string]$Mode = '',
        [string]$Details = '',
        [int]$ReferenceCount = 0,
        [int]$PromptLength = 0
    )
    
    $msg = "Spec Creation $Action"
    if ($Mode) { $msg += " | Mode: $Mode" }
    if ($ReferenceCount -gt 0) { $msg += " | References: $ReferenceCount" }
    if ($PromptLength -gt 0) { $msg += " | PromptSize: $PromptLength chars (~$([Math]::Round($PromptLength / 4)) tokens)" }
    if ($Details) { $msg += " | $Details" }
    
    Write-Log -Message $msg -Tag SPEC
}

# ═══════════════════════════════════════════════════════════════
#                     REFERENCE LOGGING
# ═══════════════════════════════════════════════════════════════

function Write-LogReference {
    <#
    .SYNOPSIS
        Logs reference file operations
    .PARAMETER Action
        Action type (LOADED, ADDED, REMOVED, CLEARED, COPIED)
    .PARAMETER Details
        Details about the operation
    .PARAMETER FileCount
        Number of files involved
    .PARAMETER Source
        Source of references
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('LOADED', 'ADDED', 'REMOVED', 'CLEARED', 'COPIED', 'DIRECTORY_ADDED', 'FILE_ADDED', 'ANALYSIS_BUILT')]
        [string]$Action,
        
        [string]$Details = '',
        [int]$FileCount = 0,
        [string]$Source = ''
    )
    
    $msg = "Reference $Action"
    if ($FileCount -gt 0) { $msg += " | Files: $FileCount" }
    if ($Source) { $msg += " | Source: $Source" }
    if ($Details) { $msg += " | $Details" }
    
    Write-Log -Message $msg -Tag REFERENCE
}

# ═══════════════════════════════════════════════════════════════
#                     ENHANCED COPILOT LOGGING
# ═══════════════════════════════════════════════════════════════

function Write-LogCopilotCall {
    <#
    .SYNOPSIS
        Logs a Copilot CLI invocation with full details
    .PARAMETER Action
        Action type (START, SUCCESS, FAILURE, CANCELLED)
    .PARAMETER Phase
        Current phase (SpecCreation, Planning, Building)
    .PARAMETER Model
        Model being used
    .PARAMETER PromptLength
        Length of the prompt in characters
    .PARAMETER Duration
        Optional duration for completed calls
    .PARAMETER Output
        Optional output/error message
    .PARAMETER ExitCode
        Process exit code
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('START', 'SUCCESS', 'FAILURE', 'CANCELLED', 'TIMEOUT')]
        [string]$Action,
        
        [string]$Phase = '',
        [string]$Model = '',
        [int]$PromptLength = 0,
        [double]$Duration = 0,
        [string]$Output = '',
        [int]$ExitCode = 0
    )
    
    $msg = "Copilot CLI $Action"
    if ($Phase) { $msg += " | Phase: $Phase" }
    if ($Model) { $msg += " | Model: $Model" }
    if ($PromptLength -gt 0) { $msg += " | PromptSize: $PromptLength chars (~$([Math]::Round($PromptLength / 4)) tokens)" }
    if ($Duration -gt 0) { $msg += " | Duration: $($Duration.ToString('F2'))s" }
    if ($ExitCode -ne 0) { $msg += " | ExitCode: $ExitCode" }
    
    Write-Log -Message $msg -Tag COPILOT
    
    # Log output for both success and failures (truncated) - important for debugging
    if ($Output) {
        $truncated = if ($Output.Length -gt 2000) { $Output.Substring(0, 2000) + "... [truncated]" } else { $Output }
        $lines = $truncated -split "`n" | Select-Object -First 30
        foreach ($line in $lines) {
            if ($line.Trim()) {
                Write-Log -Message "  > $($line.Trim())" -Tag COPILOT -Level DEBUG
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                     EXISTING LOGGING FUNCTIONS (ENHANCED)
# ═══════════════════════════════════════════════════════════════

function Write-LogSettings {
    <#
    .SYNOPSIS
        Logs current Ralph settings at session start
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings
    )
    
    Write-Log -Message "=== CURRENT SETTINGS ===" -Tag SETTINGS
    
    foreach ($key in $Settings.Keys | Sort-Object) {
        $value = $Settings[$key]
        if ($null -eq $value) {
            $value = "(null)"
        }
        elseif ($value -is [bool]) {
            $value = if ($value) { "True" } else { "False" }
        }
        elseif ($value -is [array]) {
            $value = $value -join ', '
        }
        elseif ($value -is [SecureString]) {
            $value = "***"
        }
        Write-Log -Message "  $key`: $value" -Tag SETTINGS
    }
    
    Write-Log -Message "=== END SETTINGS ===" -Tag SETTINGS
}

function Write-LogError {
    <#
    .SYNOPSIS
        Logs an error with full details and stack trace
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [System.Management.Automation.ErrorRecord]$Exception,
        [string]$Context = ''
    )
    
    $fullMsg = $Message
    if ($Context) { $fullMsg = "[$Context] $Message" }
    
    Write-Log -Message $fullMsg -Tag ERROR
    
    if ($Exception) {
        Write-Log -Message "  Exception Type: $($Exception.Exception.GetType().FullName)" -Tag ERROR
        Write-Log -Message "  Exception Message: $($Exception.Exception.Message)" -Tag ERROR
        
        if ($Exception.InvocationInfo) {
            Write-Log -Message "  Script: $($Exception.InvocationInfo.ScriptName)" -Tag ERROR
            Write-Log -Message "  Line: $($Exception.InvocationInfo.ScriptLineNumber)" -Tag ERROR
            Write-Log -Message "  Command: $($Exception.InvocationInfo.Line.Trim())" -Tag ERROR
        }
        
        if ($Exception.ScriptStackTrace) {
            Write-Log -Message "  Stack Trace:" -Tag ERROR
            $stackLines = $Exception.ScriptStackTrace -split "`n"
            foreach ($line in $stackLines | Select-Object -First 10) {
                Write-Log -Message "    $line" -Tag ERROR
            }
        }
    }
}

function Write-LogWarning {
    <#
    .SYNOPSIS
        Logs a warning message
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Context = ''
    )
    
    $fullMsg = if ($Context) { "[$Context] $Message" } else { $Message }
    Write-Log -Message $fullMsg -Tag WARNING
}

function Write-LogDebug {
    <#
    .SYNOPSIS
        Logs a debug message (only if LogLevel is DEBUG)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Context = ''
    )
    
    $fullMsg = if ($Context) { "[$Context] $Message" } else { $Message }
    Write-Log -Message $fullMsg -Tag DEBUG -Level DEBUG
}

function Write-LogInfo {
    <#
    .SYNOPSIS
        Logs an info message
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Context = ''
    )
    
    $fullMsg = if ($Context) { "[$Context] $Message" } else { $Message }
    Write-Log -Message $fullMsg -Tag INFO
}

function Write-LogTask {
    <#
    .SYNOPSIS
        Logs task-related events
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('STARTED', 'COMPLETED', 'FAILED', 'SKIPPED', 'CREATED', 'DELETED', 'SWITCHED')]
        [string]$Action,
        
        [Parameter(Mandatory)]
        [string]$TaskName,
        
        [string]$Details = ''
    )
    
    $msg = "Task $Action`: $TaskName"
    if ($Details) { $msg += " | $Details" }
    
    Write-Log -Message $msg -Tag TASK
}

function Write-LogSession {
    <#
    .SYNOPSIS
        Logs session lifecycle events
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('STARTED', 'ENDED', 'SWITCHED', 'CREATED', 'DELETED', 'RESUMED')]
        [string]$Action,
        
        [string]$SessionName = '',
        [string]$Details = ''
    )
    
    $msg = "Session $Action"
    if ($SessionName) { $msg += ": $SessionName" }
    if ($Details) { $msg += " | $Details" }
    
    Write-Log -Message $msg -Tag SESSION
}

function Write-LogBuild {
    <#
    .SYNOPSIS
        Logs build phase events
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('STARTED', 'COMPLETED', 'ITERATION', 'FAILED', 'CANCELLED', 'PAUSED')]
        [string]$Action,
        
        [int]$Iteration = 0,
        [string]$Details = ''
    )
    
    $msg = "Build $Action"
    if ($Iteration -gt 0) { $msg += " | Iteration: $Iteration" }
    if ($Details) { $msg += " | $Details" }
    
    Write-Log -Message $msg -Tag BUILD
}

function Write-LogPlan {
    <#
    .SYNOPSIS
        Logs planning phase events
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('STARTED', 'COMPLETED', 'FAILED', 'CANCELLED')]
        [string]$Action,
        
        [int]$TaskCount = 0,
        [string]$Details = ''
    )
    
    $msg = "Planning $Action"
    if ($TaskCount -gt 0) { $msg += " | Tasks created: $TaskCount" }
    if ($Details) { $msg += " | $Details" }
    
    Write-Log -Message $msg -Tag PLAN
}

function Write-LogAgent {
    <#
    .SYNOPSIS
        Logs agent-related events
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('REPAIRED', 'UPDATED', 'MISSING', 'LOADED')]
        [string]$Action,
        
        [Parameter(Mandatory)]
        [string]$AgentName,
        
        [string]$Details = ''
    )
    
    $msg = "Agent $Action`: $AgentName"
    if ($Details) { $msg += " | $Details" }
    
    Write-Log -Message $msg -Tag AGENT
}

# ═══════════════════════════════════════════════════════════════
#                     SESSION MANAGEMENT
# ═══════════════════════════════════════════════════════════════

function Close-Logging {
    <#
    .SYNOPSIS
        Closes the logging session with a summary
    #>
    param(
        [hashtable]$Stats
    )
    
    if (-not $script:LogFilePath) { return }
    
    Write-Log -Message "=== SESSION SUMMARY ===" -Tag SESSION
    
    if ($Stats) {
        if ($Stats.CopilotCalls) {
            Write-Log -Message "  Copilot Calls: $($Stats.CopilotCalls.Total) total, $($Stats.CopilotCalls.Successful) successful, $($Stats.CopilotCalls.Failed) failed" -Tag SESSION
        }
        if ($Stats.Files) {
            Write-Log -Message "  Files: $($Stats.Files.CreatedCount) created, $($Stats.Files.ModifiedCount) modified, $($Stats.Files.DeletedCount) deleted" -Tag SESSION
        }
    }
    
    $separator = "═" * 80
    $sessionEnd = @"

$separator
  RALPH SESSION ENDED
  Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  Session ID: $script:LogSessionId
$separator

"@
    
    Add-Content -Path $script:LogFilePath -Value $sessionEnd -Encoding UTF8
}

function Get-LogFilePath {
    return $script:LogFilePath
}

function Get-LogsDirectory {
    return $script:LogsDir
}

function Get-LogSessionId {
    return $script:LogSessionId
}
