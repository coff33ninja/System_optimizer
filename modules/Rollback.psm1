# ============================================================================
# ROLLBACK MODULE - Undo/Restore System for System Optimizer
# ============================================================================
# Tracks changes and generates reverse scripts for safe rollback
# ============================================================================

# ============================================================================
# CONFIGURATION
# ============================================================================
$script:RollbackConfig = @{
    RollbackDir = "C:\System_Optimizer_Backup\Rollback"
    MaxHistory = 50  # Keep last 50 operations
    CurrentSession = $null
    SessionFile = $null
}

# Windows version info for command compatibility
$script:WinVersion = @{
    Build = [System.Environment]::OSVersion.Version.Build
    Major = [System.Environment]::OSVersion.Version.Major
    IsWin11 = [System.Environment]::OSVersion.Version.Build -ge 22000
    IsWin10 = [System.Environment]::OSVersion.Version.Build -lt 22000 -and [System.Environment]::OSVersion.Version.Build -ge 10240
    PSVersion = $PSVersionTable.PSVersion.Major
}

# ============================================================================
# INITIALIZATION
# ============================================================================
function Initialize-RollbackSystem {
    <#
    .SYNOPSIS
        Initialize the rollback tracking system
    .DESCRIPTION
        Creates necessary directories and starts a new tracking session
    #>
    [CmdletBinding()]
    param(
        [string]$OperationName = "SystemOptimizer"
    )

    # Create rollback directory structure
    $dirs = @(
        $RollbackConfig.RollbackDir,
        "$($RollbackConfig.RollbackDir)\Sessions",
        "$($RollbackConfig.RollbackDir)\Scripts"
    )

    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    # Start new session
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $sessionId = "$OperationName`_$timestamp"

    $script:RollbackConfig.CurrentSession = @{
        Id = $sessionId
        StartTime = Get-Date
        OperationName = $OperationName
        ComputerName = $env:COMPUTERNAME
        WindowsBuild = $WinVersion.Build
        Changes = @{
            Registry = @()
            Services = @()
            ScheduledTasks = @()
            Files = @()
            Features = @()
        }
        RestorePointCreated = $false
    }

    $script:RollbackConfig.SessionFile = "$($RollbackConfig.RollbackDir)\Sessions\$sessionId.json"

    Write-Verbose "Rollback session initialized: $sessionId"
    return $sessionId
}

# ============================================================================
# SYSTEM RESTORE POINT (OPTIONAL)
# ============================================================================
function New-OptionalRestorePoint {
    <#
    .SYNOPSIS
        Optionally create a System Restore point
    .DESCRIPTION
        Prompts user to create restore point. Default is to skip.
    #>
    [CmdletBinding()]
    param(
        [string]$Description = "System Optimizer Backup",
        [switch]$Force
    )

    if (-not $Force) {
        Write-Host "`n[?] Create System Restore Point? (slower but safer)" -ForegroundColor Yellow
        Write-Host "    This can take 1-5 minutes depending on your system." -ForegroundColor Gray
        $response = Read-Host "    Create restore point? [y/N]"

        if ($response -notmatch '^[Yy]') {
            Write-Host "    Skipping restore point." -ForegroundColor Gray
            return $false
        }
    }

    Write-Host "    Creating restore point..." -ForegroundColor Cyan

    try {
        # Check if System Restore is enabled and get existing points
        $srEnabled = $false
        $existingPoints = @()
        try {
            $existingPoints = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue)
            $srEnabled = $true
            if ($existingPoints.Count -gt 0) {
                $latest = $existingPoints | Sort-Object CreationTime -Descending | Select-Object -First 1
                Write-Host "    Found $($existingPoints.Count) existing restore point(s). Latest: $($latest.Description)" -ForegroundColor DarkGray
            }
        } catch {
            # Try enabling it
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            $srEnabled = $true
        }

        if ($srEnabled) {
            # Restore point types: 0=APPLICATION_INSTALL, 10=DEVICE_DRIVER_INSTALL, 12=MODIFY_SETTINGS
            $restoreType = "MODIFY_SETTINGS"  # Type 12 - for system settings changes
            Checkpoint-Computer -Description $Description -RestorePointType $restoreType -ErrorAction Stop

            if ($RollbackConfig.CurrentSession) {
                $RollbackConfig.CurrentSession.RestorePointCreated = $true
            }

            Write-Host "    [OK] Restore point created: $Description" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "    [!] Could not create restore point: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "    Continuing without restore point..." -ForegroundColor Gray
    }

    return $false
}

# ============================================================================
# REGISTRY TRACKING
# ============================================================================
function Backup-RegistryValue {
    <#
    .SYNOPSIS
        Backup a registry value before modification
    .DESCRIPTION
        Records the original value for later rollback
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [string]$NewValue,
        [string]$NewType = "DWord"
    )

    if (-not $RollbackConfig.CurrentSession) {
        Initialize-RollbackSystem | Out-Null
    }

    $backup = @{
        Path = $Path
        Name = $Name
        Timestamp = Get-Date -Format "o"
        NewValue = $NewValue
        NewType = $NewType
    }

    try {
        # Check if key exists
        if (Test-Path $Path) {
            $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $currentValue) {
                $backup.OriginalValue = $currentValue.$Name
                $backup.OriginalType = (Get-Item $Path).GetValueKind($Name).ToString()
                $backup.Existed = $true
            } else {
                $backup.Existed = $false
                $backup.KeyExisted = $true
            }
        } else {
            $backup.Existed = $false
            $backup.KeyExisted = $false
        }
    } catch {
        $backup.Existed = $false
        $backup.Error = $_.Exception.Message
    }

    $RollbackConfig.CurrentSession.Changes.Registry += $backup
    return $backup
}

function Set-TrackedRegistryValue {
    <#
    .SYNOPSIS
        Set a registry value with automatic backup tracking
    .DESCRIPTION
        Backs up original value, then sets new value. Supports version-specific paths.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value,

        [ValidateSet("String", "ExpandString", "Binary", "DWord", "QWord", "MultiString")]
        [string]$Type = "DWord",

        [switch]$Force
    )

    # Backup first
    $backup = Backup-RegistryValue -Path $Path -Name $Name -NewValue $Value -NewType $Type

    try {
        # Create key if needed
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        # Set value - use compatible method for all Windows versions
        # New-ItemProperty works on Win10/11, Set-ItemProperty for existing
        if ($backup.Existed) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        } else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        }

        return $true
    } catch {
        Write-Warning "Failed to set registry value: $Path\$Name - $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
# SERVICE TRACKING
# ============================================================================
function Backup-ServiceState {
    <#
    .SYNOPSIS
        Backup service configuration before modification
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [string]$NewStartType
    )

    if (-not $RollbackConfig.CurrentSession) {
        Initialize-RollbackSystem | Out-Null
    }

    $backup = @{
        ServiceName = $ServiceName
        Timestamp = Get-Date -Format "o"
        NewStartType = $NewStartType
    }

    try {
        # Get current service state - works on all Windows versions
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        $wmiService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue

        $backup.Existed = $true
        $backup.OriginalStatus = $service.Status.ToString()
        $backup.OriginalStartType = $service.StartType.ToString()
        $backup.DisplayName = $service.DisplayName

        if ($wmiService) {
            $backup.OriginalStartMode = $wmiService.StartMode
            $backup.PathName = $wmiService.PathName
        }
    } catch {
        $backup.Existed = $false
        $backup.Error = $_.Exception.Message
    }

    $RollbackConfig.CurrentSession.Changes.Services += $backup
    return $backup
}

function Set-TrackedServiceStartup {
    <#
    .SYNOPSIS
        Change service startup type with automatic backup
    .DESCRIPTION
        Uses sc.exe as fallback for protected services where Set-Service fails
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [ValidateSet("Automatic", "Manual", "Disabled", "Boot", "System")]
        [string]$StartupType
    )

    # Backup first
    $backup = Backup-ServiceState -ServiceName $ServiceName -NewStartType $StartupType

    if (-not $backup.Existed) {
        Write-Verbose "Service not found: $ServiceName"
        return $false
    }

    try {
        # Try PowerShell cmdlet first (cleaner)
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
        return $true
    } catch {
        # Fallback to sc.exe for protected services
        # sc.exe uses different naming: auto, demand, disabled
        $scType = switch ($StartupType) {
            "Automatic" { "auto" }
            "Manual" { "demand" }
            "Disabled" { "disabled" }
            "Boot" { "boot" }
            "System" { "system" }
            default { "demand" }
        }

        try {
            $result = & sc.exe config $ServiceName start= $scType 2>&1
            if ($LASTEXITCODE -eq 0) {
                return $true
            } else {
                Write-Warning "sc.exe failed for $ServiceName`: $result"
                return $false
            }
        } catch {
            Write-Warning "Failed to set service $ServiceName`: $($_.Exception.Message)"
            return $false
        }
    }
}

# ============================================================================
# SCHEDULED TASK TRACKING
# ============================================================================
function Backup-ScheduledTaskState {
    <#
    .SYNOPSIS
        Backup scheduled task state before modification
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TaskPath,

        [Parameter(Mandatory)]
        [string]$TaskName,

        [bool]$NewEnabled
    )

    if (-not $RollbackConfig.CurrentSession) {
        Initialize-RollbackSystem | Out-Null
    }

    $fullPath = if ($TaskPath -eq "\") { "\$TaskName" } else { "$TaskPath$TaskName" }

    $backup = @{
        TaskPath = $TaskPath
        TaskName = $TaskName
        FullPath = $fullPath
        Timestamp = Get-Date -Format "o"
        NewEnabled = $NewEnabled
    }

    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
        $backup.Existed = $true
        $backup.OriginalState = $task.State.ToString()
        $backup.OriginalEnabled = ($task.State -ne 'Disabled')
        $backup.Description = $task.Description
    } catch {
        $backup.Existed = $false
        $backup.Error = $_.Exception.Message
    }

    $RollbackConfig.CurrentSession.Changes.ScheduledTasks += $backup
    return $backup
}

function Set-TrackedScheduledTask {
    <#
    .SYNOPSIS
        Enable or disable a scheduled task with tracking
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TaskPath,

        [Parameter(Mandatory)]
        [string]$TaskName,

        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    # Backup first
    $backup = Backup-ScheduledTaskState -TaskPath $TaskPath -TaskName $TaskName -NewEnabled $Enabled

    if (-not $backup.Existed) {
        Write-Verbose "Task not found: $TaskPath$TaskName"
        return $false
    }

    try {
        if ($Enabled) {
            Enable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null
        } else {
            Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null
        }
        return $true
    } catch {
        # Fallback to schtasks.exe
        $fullPath = if ($TaskPath -eq "\") { "\$TaskName" } else { "$TaskPath$TaskName" }
        $action = if ($Enabled) { "/Enable" } else { "/Disable" }

        try {
            $result = & schtasks.exe /Change /TN $fullPath $action 2>&1
            if ($LASTEXITCODE -eq 0) {
                return $true
            } else {
                Write-Warning "schtasks.exe failed for $fullPath`: $result"
                return $false
            }
        } catch {
            Write-Warning "Failed to modify task $fullPath`: $($_.Exception.Message)"
            return $false
        }
    }
}

# ============================================================================
# SESSION MANAGEMENT
# ============================================================================
function Save-RollbackSession {
    <#
    .SYNOPSIS
        Save current session to disk
    #>
    [CmdletBinding()]
    param()

    if (-not $RollbackConfig.CurrentSession) {
        Write-Warning "No active rollback session"
        return $false
    }

    $RollbackConfig.CurrentSession.EndTime = Get-Date
    $RollbackConfig.CurrentSession.Duration = (
        $RollbackConfig.CurrentSession.EndTime - $RollbackConfig.CurrentSession.StartTime
    ).TotalSeconds

    # Count changes
    $RollbackConfig.CurrentSession.Summary = @{
        RegistryChanges = $RollbackConfig.CurrentSession.Changes.Registry.Count
        ServiceChanges = $RollbackConfig.CurrentSession.Changes.Services.Count
        TaskChanges = $RollbackConfig.CurrentSession.Changes.ScheduledTasks.Count
        FileChanges = $RollbackConfig.CurrentSession.Changes.Files.Count
        TotalChanges = (
            $RollbackConfig.CurrentSession.Changes.Registry.Count +
            $RollbackConfig.CurrentSession.Changes.Services.Count +
            $RollbackConfig.CurrentSession.Changes.ScheduledTasks.Count +
            $RollbackConfig.CurrentSession.Changes.Files.Count
        )
    }

    try {
        $RollbackConfig.CurrentSession | ConvertTo-Json -Depth 10 | Set-Content -Path $RollbackConfig.SessionFile -Encoding UTF8

        # Also generate rollback script
        $scriptPath = Export-RollbackScript -SessionId $RollbackConfig.CurrentSession.Id

        Write-Host "[OK] Session saved: $($RollbackConfig.CurrentSession.Summary.TotalChanges) changes tracked" -ForegroundColor Green
        if ($scriptPath) {
            Write-Host "[OK] Rollback script: $scriptPath" -ForegroundColor DarkGray
        }
        return $true
    } catch {
        Write-Warning "Failed to save session: $($_.Exception.Message)"
        return $false
    }
}


# ============================================================================
# ROLLBACK SCRIPT GENERATION
# ============================================================================
function Export-RollbackScript {
    <#
    .SYNOPSIS
        Generate a PowerShell script to undo all changes from a session
    #>
    [CmdletBinding()]
    param(
        [string]$SessionId
    )

    $session = $null

    if ($SessionId -and $SessionId -ne $RollbackConfig.CurrentSession.Id) {
        # Load from file
        $sessionFile = "$($RollbackConfig.RollbackDir)\Sessions\$SessionId.json"
        if (Test-Path $sessionFile) {
            $session = Get-Content $sessionFile -Raw | ConvertFrom-Json
        }
    } else {
        $session = $RollbackConfig.CurrentSession
    }

    if (-not $session) {
        Write-Warning "Session not found: $SessionId"
        return $null
    }

    $scriptPath = "$($RollbackConfig.RollbackDir)\Scripts\Undo_$($session.Id).ps1"

    $script = @"
# ============================================================================
# ROLLBACK SCRIPT - Auto-generated by System Optimizer
# ============================================================================
# Session: $($session.Id)
# Created: $($session.StartTime)
# Computer: $($session.ComputerName)
# Windows Build: $($session.WindowsBuild)
# ============================================================================
# WARNING: Run this script as Administrator to undo changes
# ============================================================================

#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " SYSTEM OPTIMIZER - ROLLBACK SCRIPT" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Session: $($session.Id)"
Write-Host ""

`$ErrorCount = 0
`$SuccessCount = 0

"@

    # Registry rollback
    if ($session.Changes.Registry.Count -gt 0) {
        $script += @"

# ============================================================================
# REGISTRY ROLLBACK
# ============================================================================
Write-Host "`n[Registry] Restoring $($session.Changes.Registry.Count) values..." -ForegroundColor Cyan

"@
        foreach ($reg in $session.Changes.Registry) {
            if ($reg.Existed) {
                # Restore original value
                $script += @"
try {
    Set-ItemProperty -Path '$($reg.Path)' -Name '$($reg.Name)' -Value $($reg.OriginalValue) -Type $($reg.OriginalType) -Force -ErrorAction Stop
    Write-Host "  [OK] $($reg.Path)\$($reg.Name)" -ForegroundColor Green
    `$SuccessCount++
} catch {
    Write-Host "  [X] $($reg.Path)\$($reg.Name): `$(`$_.Exception.Message)" -ForegroundColor Red
    `$ErrorCount++
}

"@
            } elseif (-not $reg.KeyExisted) {
                # Key didn't exist - remove it
                $script += @"
try {
    if (Test-Path '$($reg.Path)') {
        Remove-Item -Path '$($reg.Path)' -Recurse -Force -ErrorAction Stop
        Write-Host "  [OK] Removed: $($reg.Path)" -ForegroundColor Green
        `$SuccessCount++
    }
} catch {
    Write-Host "  [X] Remove $($reg.Path): `$(`$_.Exception.Message)" -ForegroundColor Red
    `$ErrorCount++
}

"@
            } else {
                # Value didn't exist - remove it
                $script += @"
try {
    Remove-ItemProperty -Path '$($reg.Path)' -Name '$($reg.Name)' -Force -ErrorAction Stop
    Write-Host "  [OK] Removed: $($reg.Path)\$($reg.Name)" -ForegroundColor Green
    `$SuccessCount++
} catch {
    Write-Host "  [X] Remove $($reg.Path)\$($reg.Name): `$(`$_.Exception.Message)" -ForegroundColor Red
    `$ErrorCount++
}

"@
            }
        }
    }

    # Service rollback
    if ($session.Changes.Services.Count -gt 0) {
        $script += @"

# ============================================================================
# SERVICE ROLLBACK
# ============================================================================
Write-Host "`n[Services] Restoring $($session.Changes.Services.Count) services..." -ForegroundColor Cyan

"@
        foreach ($svc in $session.Changes.Services) {
            if ($svc.Existed -and $svc.OriginalStartType) {
                $script += @"
try {
    Set-Service -Name '$($svc.ServiceName)' -StartupType $($svc.OriginalStartType) -ErrorAction Stop
    Write-Host "  [OK] $($svc.ServiceName) -> $($svc.OriginalStartType)" -ForegroundColor Green
    `$SuccessCount++
} catch {
    # Fallback to sc.exe
    `$scType = switch ('$($svc.OriginalStartType)') {
        'Automatic' { 'auto' }
        'Manual' { 'demand' }
        'Disabled' { 'disabled' }
        default { 'demand' }
    }
    `$result = & sc.exe config '$($svc.ServiceName)' start= `$scType 2>&1
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $($svc.ServiceName) -> $($svc.OriginalStartType) (sc.exe)" -ForegroundColor Green
        `$SuccessCount++
    } else {
        Write-Host "  [X] $($svc.ServiceName): `$result" -ForegroundColor Red
        `$ErrorCount++
    }
}

"@
            }
        }
    }

    # Scheduled task rollback
    if ($session.Changes.ScheduledTasks.Count -gt 0) {
        $script += @"

# ============================================================================
# SCHEDULED TASK ROLLBACK
# ============================================================================
Write-Host "`n[Tasks] Restoring $($session.Changes.ScheduledTasks.Count) scheduled tasks..." -ForegroundColor Cyan

"@
        foreach ($task in $session.Changes.ScheduledTasks) {
            if ($task.Existed) {
                $action = if ($task.OriginalEnabled) { "Enable" } else { "Disable" }
                $script += @"
try {
    $action-ScheduledTask -TaskPath '$($task.TaskPath)' -TaskName '$($task.TaskName)' -ErrorAction Stop | Out-Null
    Write-Host "  [OK] $($task.FullPath) -> $action" -ForegroundColor Green
    `$SuccessCount++
} catch {
    Write-Host "  [X] $($task.FullPath): `$(`$_.Exception.Message)" -ForegroundColor Red
    `$ErrorCount++
}

"@
            }
        }
    }

    # Summary
    $script += @"

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ROLLBACK COMPLETE" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Success: `$SuccessCount" -ForegroundColor Green
Write-Host "  Errors:  `$ErrorCount" -ForegroundColor $(if ('$ErrorCount' -gt 0) { 'Red' } else { 'Gray' })
Write-Host ""
Write-Host "Note: Some changes may require a restart to take effect." -ForegroundColor Yellow
Write-Host ""
"@

    try {
        $script | Set-Content -Path $scriptPath -Encoding UTF8
        Write-Verbose "Rollback script saved: $scriptPath"
        return $scriptPath
    } catch {
        Write-Warning "Failed to save rollback script: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# HISTORY & UNDO MENU
# ============================================================================
function Get-RollbackHistory {
    <#
    .SYNOPSIS
        Get list of all rollback sessions
    #>
    [CmdletBinding()]
    param(
        [int]$Last = 20
    )

    $sessionsDir = "$($RollbackConfig.RollbackDir)\Sessions"

    if (-not (Test-Path $sessionsDir)) {
        return @()
    }

    $sessions = Get-ChildItem -Path $sessionsDir -Filter "*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $Last |
        ForEach-Object {
            try {
                $data = Get-Content $_.FullName -Raw | ConvertFrom-Json
                [PSCustomObject]@{
                    Id = $data.Id
                    Date = $data.StartTime
                    Operation = $data.OperationName
                    Changes = $data.Summary.TotalChanges
                    RestorePoint = $data.RestorePointCreated
                    File = $_.FullName
                }
            } catch {
                $null
            }
        } |
        Where-Object { $_ -ne $null }

    return $sessions
}

function Show-RollbackMenu {
    <#
    .SYNOPSIS
        Interactive menu for viewing history and running rollback scripts
    #>
    [CmdletBinding()]
    param()

    do {
        Clear-Host
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "  ROLLBACK & UNDO CENTER" -ForegroundColor Yellow
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host ""

        $history = Get-RollbackHistory -Last 15

        if ($history.Count -eq 0) {
            Write-Host "  No rollback history found." -ForegroundColor Gray
            Write-Host "  Changes will be tracked after running optimizations." -ForegroundColor Gray
        } else {
            Write-Host "  Recent Sessions:" -ForegroundColor Gray
            Write-Host ""

            $i = 1
            foreach ($session in $history) {
                $date = if ($session.Date) {
                    try { [DateTime]::Parse($session.Date).ToString("MM/dd HH:mm") } catch { "Unknown" }
                } else { "Unknown" }
                $rp = if ($session.RestorePoint) { "[RP]" } else { "    " }
                Write-Host "  [$i] $rp $date - $($session.Operation) ($($session.Changes) changes)"
                $i++
            }
        }

        Write-Host ""
        Write-Host "  [V] View session details"
        Write-Host "  [R] Run rollback script"
        Write-Host "  [E] Export rollback script"
        Write-Host "  [C] Cleanup old sessions"
        Write-Host ""
        Write-Host "  [0] Back to main menu"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice.ToUpper()) {
            "V" {
                if ($history.Count -gt 0) {
                    $num = Read-Host "Enter session number to view"
                    if ($num -match '^\d+$' -and [int]$num -le $history.Count -and [int]$num -gt 0) {
                        Show-SessionDetails -SessionFile $history[[int]$num - 1].File
                    }
                }
            }
            "R" {
                if ($history.Count -gt 0) {
                    $num = Read-Host "Enter session number to rollback"
                    if ($num -match '^\d+$' -and [int]$num -le $history.Count -and [int]$num -gt 0) {
                        Invoke-Rollback -SessionId $history[[int]$num - 1].Id
                    }
                }
            }
            "E" {
                if ($history.Count -gt 0) {
                    $num = Read-Host "Enter session number to export"
                    if ($num -match '^\d+$' -and [int]$num -le $history.Count -and [int]$num -gt 0) {
                        $scriptPath = Export-RollbackScript -SessionId $history[[int]$num - 1].Id
                        if ($scriptPath) {
                            Write-Host "`nScript exported to: $scriptPath" -ForegroundColor Green
                            Write-Host "Press any key..." -ForegroundColor Gray
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                    }
                }
            }
            "C" {
                Clear-OldSessions
            }
            "0" { return }
        }
    } while ($true)
}

function Show-SessionDetails {
    <#
    .SYNOPSIS
        Display detailed information about a rollback session
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SessionFile
    )

    try {
        $session = Get-Content $SessionFile -Raw | ConvertFrom-Json

        Clear-Host
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "  SESSION DETAILS" -ForegroundColor Yellow
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  ID: $($session.Id)"
        Write-Host "  Operation: $($session.OperationName)"
        Write-Host "  Date: $($session.StartTime)"
        Write-Host "  Computer: $($session.ComputerName)"
        Write-Host "  Windows Build: $($session.WindowsBuild)"
        Write-Host "  Restore Point: $(if ($session.RestorePointCreated) { 'Yes' } else { 'No' })"
        Write-Host ""
        Write-Host "  Changes Summary:" -ForegroundColor Gray
        Write-Host "    Registry:  $($session.Summary.RegistryChanges)"
        Write-Host "    Services:  $($session.Summary.ServiceChanges)"
        Write-Host "    Tasks:     $($session.Summary.TaskChanges)"
        Write-Host "    Files:     $($session.Summary.FileChanges)"
        Write-Host "    -----------------"
        Write-Host "    Total:     $($session.Summary.TotalChanges)"
        Write-Host ""

        # Show some details
        if ($session.Changes.Registry.Count -gt 0) {
            Write-Host "  Registry Changes (first 10):" -ForegroundColor Gray
            $session.Changes.Registry | Select-Object -First 10 | ForEach-Object {
                Write-Host "    $($_.Path)\$($_.Name)"
            }
            if ($session.Changes.Registry.Count -gt 10) {
                Write-Host "    ... and $($session.Changes.Registry.Count - 10) more"
            }
        }

        if ($session.Changes.Services.Count -gt 0) {
            Write-Host "`n  Service Changes:" -ForegroundColor Gray
            $session.Changes.Services | ForEach-Object {
                Write-Host "    $($_.ServiceName): $($_.OriginalStartType) -> $($_.NewStartType)"
            }
        }

    } catch {
        Write-Host "  Error reading session: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Invoke-Rollback {
    <#
    .SYNOPSIS
        Execute rollback for a specific session
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SessionId
    )

    $scriptPath = "$($RollbackConfig.RollbackDir)\Scripts\Undo_$SessionId.ps1"

    # Generate if doesn't exist
    if (-not (Test-Path $scriptPath)) {
        $scriptPath = Export-RollbackScript -SessionId $SessionId
    }

    if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
        Write-Host "Could not find or generate rollback script" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "WARNING: This will undo changes from session: $SessionId" -ForegroundColor Yellow
    $confirm = Read-Host "Continue? [y/N]"

    if ($confirm -match '^[Yy]') {
        Write-Host ""
        & $scriptPath
    }
}

function Clear-OldSessions {
    <#
    .SYNOPSIS
        Remove old rollback sessions
    #>
    [CmdletBinding()]
    param(
        [int]$KeepLast = 20
    )

    $sessionsDir = "$($RollbackConfig.RollbackDir)\Sessions"
    $scriptsDir = "$($RollbackConfig.RollbackDir)\Scripts"

    $sessions = Get-ChildItem -Path $sessionsDir -Filter "*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if ($sessions.Count -le $KeepLast) {
        Write-Host "No old sessions to clean up (keeping last $KeepLast)" -ForegroundColor Gray
        return
    }

    $toDelete = $sessions | Select-Object -Skip $KeepLast
    $count = $toDelete.Count

    Write-Host "This will delete $count old sessions." -ForegroundColor Yellow
    $confirm = Read-Host "Continue? [y/N]"

    if ($confirm -match '^[Yy]') {
        foreach ($file in $toDelete) {
            Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue

            # Also remove corresponding script
            $scriptName = "Undo_" + $file.BaseName + ".ps1"
            $scriptPath = Join-Path $scriptsDir $scriptName
            if (Test-Path $scriptPath) {
                Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "Deleted $count old sessions" -ForegroundColor Green
    }

    Write-Host "Press any key..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ============================================================================
# WINDOWS VERSION HELPERS
# ============================================================================
function Get-WindowsVersionInfo {
    <#
    .SYNOPSIS
        Get detailed Windows version information for compatibility checks
    #>
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        Build = $WinVersion.Build
        Major = $WinVersion.Major
        IsWin11 = $WinVersion.IsWin11
        IsWin10 = $WinVersion.IsWin10
        PSVersion = $WinVersion.PSVersion
        Edition = (Get-CimInstance Win32_OperatingSystem).Caption
        Architecture = $env:PROCESSOR_ARCHITECTURE
        BuildLabEx = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).BuildLabEx
    }
}

function Test-CommandAvailable {
    <#
    .SYNOPSIS
        Check if a command/cmdlet is available on this system
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command
    )

    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# ============================================================================
# BULK TRACKING WRAPPERS
# ============================================================================
# These functions allow tracking changes from existing code without rewriting

function Start-TrackedOperation {
    <#
    .SYNOPSIS
        Start tracking an operation - call before making changes
    .DESCRIPTION
        Initializes a session and optionally creates a restore point
    .EXAMPLE
        Start-TrackedOperation -Name "DisableTelemetry" -PromptRestorePoint
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$PromptRestorePoint,
        [switch]$ForceRestorePoint
    )

    $sessionId = Initialize-RollbackSystem -OperationName $Name

    if ($ForceRestorePoint) {
        New-OptionalRestorePoint -Description "Before $Name" -Force
    } elseif ($PromptRestorePoint) {
        New-OptionalRestorePoint -Description "Before $Name"
    }

    return $sessionId
}

function Stop-TrackedOperation {
    <#
    .SYNOPSIS
        Finish tracking and save the session
    #>
    [CmdletBinding()]
    param()

    Save-RollbackSession
}

function Add-RegistryChangeToSession {
    <#
    .SYNOPSIS
        Manually add a registry change to the current session (for bulk tracking)
    .DESCRIPTION
        Use this to track registry changes made by existing code
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        $OriginalValue,
        $NewValue,
        [string]$Type = "DWord",
        [bool]$Existed = $true
    )

    if (-not $RollbackConfig.CurrentSession) {
        Initialize-RollbackSystem | Out-Null
    }

    $change = @{
        Path = $Path
        Name = $Name
        OriginalValue = $OriginalValue
        NewValue = $NewValue
        OriginalType = $Type
        NewType = $Type
        Existed = $Existed
        Timestamp = Get-Date -Format "o"
    }

    $RollbackConfig.CurrentSession.Changes.Registry += $change
}

function Add-ServiceChangeToSession {
    <#
    .SYNOPSIS
        Manually add a service change to the current session
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [string]$OriginalStartType,
        [string]$NewStartType
    )

    if (-not $RollbackConfig.CurrentSession) {
        Initialize-RollbackSystem | Out-Null
    }

    $change = @{
        ServiceName = $ServiceName
        OriginalStartType = $OriginalStartType
        NewStartType = $NewStartType
        Existed = $true
        Timestamp = Get-Date -Format "o"
    }

    $RollbackConfig.CurrentSession.Changes.Services += $change
}

# ============================================================================
# SNAPSHOT-BASED TRACKING (Alternative approach)
# ============================================================================
# Takes before/after snapshots to detect changes automatically

function Get-RegistrySnapshot {
    <#
    .SYNOPSIS
        Take a snapshot of specific registry paths for comparison
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths
    )

    $snapshot = @{}

    foreach ($path in $Paths) {
        if (Test-Path $path) {
            try {
                $props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
                $snapshot[$path] = @{}

                foreach ($prop in $props.PSObject.Properties) {
                    if ($prop.Name -notmatch '^PS') {  # Skip PS* properties
                        $snapshot[$path][$prop.Name] = $prop.Value
                    }
                }
            } catch {
                # Path exists but can't read
            }
        }
    }

    return $snapshot
}

function Compare-RegistrySnapshots {
    <#
    .SYNOPSIS
        Compare two registry snapshots and return changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Before,

        [Parameter(Mandatory)]
        [hashtable]$After
    )

    $changes = @()

    # Check for modified/new values
    foreach ($path in $After.Keys) {
        foreach ($name in $After[$path].Keys) {
            $newValue = $After[$path][$name]

            if ($Before.ContainsKey($path) -and $Before[$path].ContainsKey($name)) {
                $oldValue = $Before[$path][$name]
                if ($oldValue -ne $newValue) {
                    $changes += @{
                        Type = "Modified"
                        Path = $path
                        Name = $name
                        OldValue = $oldValue
                        NewValue = $newValue
                    }
                }
            } else {
                $changes += @{
                    Type = "Added"
                    Path = $path
                    Name = $name
                    OldValue = $null
                    NewValue = $newValue
                }
            }
        }
    }

    # Check for deleted values
    foreach ($path in $Before.Keys) {
        foreach ($name in $Before[$path].Keys) {
            if (-not ($After.ContainsKey($path) -and $After[$path].ContainsKey($name))) {
                $changes += @{
                    Type = "Deleted"
                    Path = $path
                    Name = $name
                    OldValue = $Before[$path][$name]
                    NewValue = $null
                }
            }
        }
    }

    return $changes
}

function Get-ServiceSnapshot {
    <#
    .SYNOPSIS
        Take a snapshot of service startup types
    #>
    [CmdletBinding()]
    param(
        [string[]]$ServiceNames
    )

    $snapshot = @{}

    $services = if ($ServiceNames) {
        Get-Service -Name $ServiceNames -ErrorAction SilentlyContinue
    } else {
        Get-Service -ErrorAction SilentlyContinue
    }

    foreach ($svc in $services) {
        $snapshot[$svc.Name] = @{
            StartType = $svc.StartType.ToString()
            Status = $svc.Status.ToString()
            DisplayName = $svc.DisplayName
        }
    }

    return $snapshot
}

function Compare-ServiceSnapshots {
    <#
    .SYNOPSIS
        Compare two service snapshots and return changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Before,

        [Parameter(Mandatory)]
        [hashtable]$After
    )

    $changes = @()

    foreach ($name in $After.Keys) {
        if ($Before.ContainsKey($name)) {
            if ($Before[$name].StartType -ne $After[$name].StartType) {
                $changes += @{
                    ServiceName = $name
                    DisplayName = $After[$name].DisplayName
                    OldStartType = $Before[$name].StartType
                    NewStartType = $After[$name].StartType
                }
            }
        }
    }

    return $changes
}

# Update exports
Export-ModuleMember -Function @(
    # Initialization
    'Initialize-RollbackSystem',
    'New-OptionalRestorePoint',

    # Tracked operations
    'Set-TrackedRegistryValue',
    'Set-TrackedServiceStartup',
    'Set-TrackedScheduledTask',

    # Backup functions (for manual use)
    'Backup-RegistryValue',
    'Backup-ServiceState',
    'Backup-ScheduledTaskState',

    # Session management
    'Save-RollbackSession',
    'Export-RollbackScript',

    # History & UI
    'Get-RollbackHistory',
    'Show-RollbackMenu',
    'Show-SessionDetails',
    'Invoke-Rollback',
    'Clear-OldSessions',

    # Helpers
    'Get-WindowsVersionInfo',
    'Test-CommandAvailable',

    # Bulk tracking wrappers
    'Start-TrackedOperation',
    'Stop-TrackedOperation',
    'Add-RegistryChangeToSession',
    'Add-ServiceChangeToSession',

    # Snapshot-based tracking
    'Get-RegistrySnapshot',
    'Compare-RegistrySnapshots',
    'Get-ServiceSnapshot',
    'Compare-ServiceSnapshots'
)
