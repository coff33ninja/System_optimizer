#Requires -Version 5.1
<#
.SYNOPSIS
    Logging Module - System Optimizer
.DESCRIPTION
    Provides centralized logging functionality for all System Optimizer components.
    Supports colored console output, file logging with rotation, and structured log entries.

Exported Functions:
    Initialize-Logging      - Initialize logging for a component
    Remove-OldLogs          - Clean up logs older than retention period
    Write-OptLog            - Write log entry with timestamp and level
    Write-OptError          - Write error log with exception details
    Write-OptCommand        - Log command execution
    Write-OptSection        - Write section header
    Start-OptOperation      - Begin logged operation
    Complete-OptOperation   - Complete logged operation
    Get-OptLogPath          - Get current log file path
    Get-OptLogFiles         - List available log files
    Show-OptRecentLogs      - Display recent log entries
    Export-OptLogSummary    - Export log summary to file
    Complete-Logging        - Finalize logging session

Log Levels:
    INFO     - General information
    SUCCESS  - Successful operations
    WARNING  - Warnings and non-critical issues
    ERROR    - Errors and failures
    SECTION  - Section headers
    DEBUG    - Debug information (verbose mode)

Log Location:
    C:\System_Optimizer\Logs\

Retention:
    30 days (configurable)

Version: 1.0.0
#>

# Global log settings
$script:LogDir = "C:\System_Optimizer\Logs"
$script:LogRetentionDays = 30

# Initialize logging for a specific component
function Initialize-Logging {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComponentName,
        [string]$CustomLogDir = $null
    )

    # Use custom dir if provided
    if ($CustomLogDir) {
        $script:LogDir = $CustomLogDir
    }

    # Ensure log directory exists
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    # Create log file with component name and timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $script:CurrentLogFile = "$LogDir\${ComponentName}_$timestamp.log"
    $script:ComponentName = $ComponentName

    # Write header
    $header = @"
================================================================================
SYSTEM OPTIMIZER LOG - $ComponentName
================================================================================
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell: $($PSVersionTable.PSVersion)
================================================================================

"@
    Add-Content -Path $CurrentLogFile -Value $header

    # Cleanup old logs
    Remove-OldLogs

    return $CurrentLogFile
}

# Remove logs older than retention period
function Remove-OldLogs {
    $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
    Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# Main logging function
function Write-OptLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "ERROR", "WARNING", "SECTION", "DEBUG")]
        [string]$Type = "INFO",
        [switch]$NoConsole,
        [switch]$NoFile
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $shortTime = Get-Date -Format "HH:mm:ss"

    # Format log message
    $logMessage = "[$timestamp] [$Type] $Message"

    # Write to file
    if (-not $NoFile -and $CurrentLogFile) {
        Add-Content -Path $CurrentLogFile -Value $logMessage -ErrorAction SilentlyContinue
    }

    # Write to console with colors
    if (-not $NoConsole) {
        switch ($Type) {
            "SUCCESS" {
                Write-Host "[$shortTime] [OK] " -ForegroundColor Green -NoNewline
                Write-Host $Message
            }
            "ERROR" {
                Write-Host "[$shortTime] [X] " -ForegroundColor Red -NoNewline
                Write-Host $Message
            }
            "WARNING" {
                Write-Host "[$shortTime] [!] " -ForegroundColor Yellow -NoNewline
                Write-Host $Message
            }
            "SECTION" {
                Write-Host ""
                Write-Host "[$shortTime] === " -ForegroundColor Cyan -NoNewline
                Write-Host $Message -ForegroundColor Cyan -NoNewline
                Write-Host " ===" -ForegroundColor Cyan
            }
            "DEBUG" {
                if ($env:SYSTEM_OPTIMIZER_DEBUG -eq "1") {
                    Write-Host "[$shortTime] [DBG] " -ForegroundColor Magenta -NoNewline
                    Write-Host $Message -ForegroundColor DarkGray
                }
            }
            default {
                Write-Host "[$shortTime] [-] " -ForegroundColor Gray -NoNewline
                Write-Host $Message
            }
        }
    }
}

# Log an error with exception details
function Write-OptError {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
    )

    Write-OptLog $Message "ERROR"

    if ($ErrorRecord) {
        $errorDetails = @"
    Exception: $($ErrorRecord.Exception.Message)
    Category: $($ErrorRecord.CategoryInfo.Category)
    Target: $($ErrorRecord.TargetObject)
    Script: $($ErrorRecord.InvocationInfo.ScriptName):$($ErrorRecord.InvocationInfo.ScriptLineNumber)
"@
        Write-OptLog $errorDetails "DEBUG"
        Add-Content -Path $CurrentLogFile -Value $errorDetails -ErrorAction SilentlyContinue
    }
}

# Log command execution with result
function Write-OptCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [int]$ExitCode = 0,
        [string]$Output = ""
    )

    $status = if ($ExitCode -eq 0) { "SUCCESS" } else { "ERROR" }
    Write-OptLog "Command: $Command" "DEBUG"
    Write-OptLog "Exit Code: $ExitCode" $status

    if ($Output -and $env:SYSTEM_OPTIMIZER_DEBUG -eq "1") {
        Add-Content -Path $CurrentLogFile -Value "    Output: $Output" -ErrorAction SilentlyContinue
    }
}

# Log a section start
function Write-OptSection {
    param([Parameter(Mandatory=$true)][string]$SectionName)
    Write-OptLog $SectionName "SECTION"
}

# Log operation start/end with timing
function Start-OptOperation {
    param([Parameter(Mandatory=$true)][string]$OperationName)
    $script:OperationStart = Get-Date
    $script:OperationName = $OperationName
    Write-OptLog "Starting: $OperationName" "INFO"
}

function Complete-OptOperation {
    param(
        [bool]$Success = $true,
        [string]$Message = ""
    )

    $duration = (Get-Date) - $OperationStart
    $durationStr = "{0:mm}m {0:ss}s" -f $duration

    if ($Success) {
        $msg = if ($Message) { "$OperationName completed: $Message ($durationStr)" } else { "$OperationName completed ($durationStr)" }
        Write-OptLog $msg "SUCCESS"
    } else {
        $msg = if ($Message) { "$OperationName failed: $Message ($durationStr)" } else { "$OperationName failed ($durationStr)" }
        Write-OptLog $msg "ERROR"
    }
}

# Get current log file path
function Get-OptLogPath {
    return $CurrentLogFile
}

# Get all log files
function Get-OptLogFiles {
    param([string]$ComponentFilter = "*")

    Get-ChildItem -Path $LogDir -Filter "${ComponentFilter}*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
}

# View recent log entries
function Show-OptRecentLogs {
    param(
        [int]$Lines = 50,
        [string]$ComponentFilter = "*"
    )

    $latestLog = Get-OptLogFiles -ComponentFilter $ComponentFilter | Select-Object -First 1

    if ($latestLog) {
        Write-Host ""
        Write-Host "Recent entries from: $($latestLog.Name)" -ForegroundColor Cyan
        Write-Host ("-" * 60) -ForegroundColor Gray
        Get-Content $latestLog.FullName -Tail $Lines
    } else {
        Write-Host "No log files found" -ForegroundColor Yellow
    }
}

# Export log summary
function Export-OptLogSummary {
    param([string]$OutputPath = "$LogDir\Summary_$(Get-Date -Format 'yyyy-MM-dd').txt")

    $summary = @"
================================================================================
SYSTEM OPTIMIZER - LOG SUMMARY
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
================================================================================

LOG FILES:
"@

    $logs = Get-OptLogFiles
    foreach ($log in $logs) {
        $errors = (Select-String -Path $log.FullName -Pattern "\[ERROR\]" -ErrorAction SilentlyContinue).Count
        $warnings = (Select-String -Path $log.FullName -Pattern "\[WARNING\]" -ErrorAction SilentlyContinue).Count
        $summary += "`n  $($log.Name) - Errors: $errors, Warnings: $warnings"
    }

    $summary | Out-File $OutputPath -Force
    Write-Host "Summary exported to: $OutputPath" -ForegroundColor Green
    return $OutputPath
}

# Finalize logging (write footer)
function Complete-Logging {
    if ($CurrentLogFile) {
        $footer = @"

================================================================================
Completed: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
================================================================================
"@
        Add-Content -Path $CurrentLogFile -Value $footer -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================
Export-ModuleMember -Function @(
    'Initialize-Logging',
    'Remove-OldLogs',
    'Write-OptLog',
    'Write-OptError',
    'Write-OptCommand',
    'Write-OptSection',
    'Start-OptOperation',
    'Complete-OptOperation',
    'Get-OptLogPath',
    'Get-OptLogFiles',
    'Show-OptRecentLogs',
    'Export-OptLogSummary',
    'Complete-Logging'
)
