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

# ============================================================================
# FULL SYSTEM SNAPSHOT (Before/After Comparison System)
# ============================================================================

# Snapshot storage configuration
$script:SnapshotDir = "$($RollbackConfig.RollbackDir)\Snapshots"
$script:PendingComparisonFile = "$($RollbackConfig.RollbackDir)\pending_comparison.json"

function Get-ScheduledTaskSnapshot {
    <#
    .SYNOPSIS
        Take a snapshot of scheduled task states
    .DESCRIPTION
        Captures non-Microsoft scheduled tasks for comparison
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeSystemTasks
    )

    $snapshot = @{}

    try {
        $filter = if ($IncludeSystemTasks) {
            { $true }
        } else {
            # Exclude most Microsoft system tasks, keep user-relevant ones
            { $_.TaskPath -notmatch '^\\Microsoft\\Windows\\(Defrag|DiskCleanup|Maintenance|Servicing|Setup|Shell|SoftwareProtectionPlatform|Sysmain|Task Manager|Time|UpdateOrchestrator|Windows Defender|WindowsUpdate|WwanSvc)\\' }
        }

        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object $filter

        foreach ($task in $tasks) {
            $fullPath = "$($task.TaskPath)$($task.TaskName)"
            $snapshot[$fullPath] = @{
                TaskPath = $task.TaskPath
                TaskName = $task.TaskName
                State = $task.State.ToString()
                Enabled = ($task.State -ne 'Disabled')
                Description = $task.Description
            }
        }
    } catch {
        Write-Warning "Failed to get scheduled task snapshot: $($_.Exception.Message)"
    }

    return $snapshot
}

function Compare-ScheduledTaskSnapshots {
    <#
    .SYNOPSIS
        Compare two scheduled task snapshots and return changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Before,

        [Parameter(Mandatory)]
        [hashtable]$After
    )

    $changes = @()

    foreach ($path in $After.Keys) {
        if ($Before.ContainsKey($path)) {
            if ($Before[$path].State -ne $After[$path].State) {
                $changes += @{
                    TaskPath = $After[$path].TaskPath
                    TaskName = $After[$path].TaskName
                    FullPath = $path
                    OldState = $Before[$path].State
                    NewState = $After[$path].State
                }
            }
        }
    }

    return $changes
}

function Get-AppSnapshot {
    <#
    .SYNOPSIS
        Take a snapshot of installed UWP/Store apps
    #>
    [CmdletBinding()]
    param()

    $apps = @()

    try {
        $appxPackages = Get-AppxPackage -ErrorAction SilentlyContinue

        foreach ($app in $appxPackages) {
            $apps += @{
                Name = $app.Name
                Version = $app.Version
                Publisher = $app.Publisher
                PackageFullName = $app.PackageFullName
                InstallLocation = $app.InstallLocation
            }
        }
    } catch {
        Write-Warning "Failed to get app snapshot: $($_.Exception.Message)"
    }

    return $apps
}

function Compare-AppSnapshots {
    <#
    .SYNOPSIS
        Compare two app snapshots and return changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Before,

        [Parameter(Mandatory)]
        [array]$After
    )

    $changes = @{
        Removed = @()
        Added = @()
        Updated = @()
    }

    $beforeNames = $Before | ForEach-Object { $_.Name }
    $afterNames = $After | ForEach-Object { $_.Name }

    # Find removed apps
    foreach ($app in $Before) {
        if ($app.Name -notin $afterNames) {
            $changes.Removed += $app.Name
        }
    }

    # Find added apps
    foreach ($app in $After) {
        if ($app.Name -notin $beforeNames) {
            $changes.Added += $app.Name
        }
    }

    # Find updated apps (version changed)
    foreach ($afterApp in $After) {
        $beforeApp = $Before | Where-Object { $_.Name -eq $afterApp.Name } | Select-Object -First 1
        if ($beforeApp -and $beforeApp.Version -ne $afterApp.Version) {
            $changes.Updated += @{
                Name = $afterApp.Name
                OldVersion = $beforeApp.Version
                NewVersion = $afterApp.Version
            }
        }
    }

    return $changes
}

function New-FullSystemSnapshot {
    <#
    .SYNOPSIS
        Create a comprehensive system snapshot for before/after comparison
    .PARAMETER Type
        "Before" or "After" to indicate snapshot purpose
    .PARAMETER Save
        If specified, saves snapshot to disk
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("Before", "After")]
        [string]$Type = "Before",

        [switch]$Save
    )

    Write-Host "  Taking system snapshot ($Type)..." -ForegroundColor Cyan

    # Key registry paths to snapshot
    $regPaths = @(
        # Telemetry
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
        # Game Bar / DVR
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR",
        "HKCU:\SOFTWARE\Microsoft\GameBar",
        "HKCU:\System\GameConfigStore",
        # Privacy
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo",
        "HKCU:\SOFTWARE\Microsoft\InputPersonalization",
        # Performance
        "HKCU:\Control Panel\Desktop",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
        "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
        # Services (key ones)
        "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack",
        "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice",
        "HKLM:\SYSTEM\CurrentControlSet\Services\SysMain"
    )

    # Get hardware info if available
    $hardware = $null
    if (Get-Command 'Get-HardwareProfile' -ErrorAction SilentlyContinue) {
        try {
            $hardware = Get-HardwareProfile
        } catch {
            Write-Verbose "Hardware detection unavailable"
        }
    }

    # Get memory usage
    $os = Get-CimOrWmi -ClassName Win32_OperatingSystem
    $memoryUsage = $null
    if ($os) {
        $totalMem = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $freeMem = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $memoryUsage = @{
            Total_GB = $totalMem
            Free_GB = $freeMem
            Used_GB = [math]::Round($totalMem - $freeMem, 1)
            UsedPercent = [math]::Round((($totalMem - $freeMem) / $totalMem) * 100, 0)
        }
    }

    $snapshot = @{
        Timestamp = Get-Date -Format "o"
        Type = $Type
        ComputerName = $env:COMPUTERNAME
        WindowsBuild = $WinVersion.Build
        Hardware = $hardware
        MemoryUsage = $memoryUsage
        Services = Get-ServiceSnapshot
        Registry = Get-RegistrySnapshot -Paths $regPaths
        Tasks = Get-ScheduledTaskSnapshot
        Apps = Get-AppSnapshot
        Counts = @{
            Services = (Get-Service -ErrorAction SilentlyContinue).Count
            RunningServices = (Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }).Count
            Tasks = (Get-ScheduledTask -ErrorAction SilentlyContinue).Count
            EnabledTasks = (Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Disabled' }).Count
            Apps = (Get-AppxPackage -ErrorAction SilentlyContinue).Count
        }
    }

    Write-Host "  Snapshot complete: $($snapshot.Counts.Services) services, $($snapshot.Counts.Tasks) tasks, $($snapshot.Counts.Apps) apps" -ForegroundColor Green

    if ($Save) {
        $path = Save-Snapshot -Snapshot $snapshot
        Write-Host "  Saved to: $path" -ForegroundColor DarkGray
    }

    return $snapshot
}

function Save-Snapshot {
    <#
    .SYNOPSIS
        Save a snapshot to disk
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Snapshot
    )

    # Ensure directory exists
    if (-not (Test-Path $script:SnapshotDir)) {
        New-Item -ItemType Directory -Path $script:SnapshotDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $type = $Snapshot.Type.ToLower()
    $filename = "snapshot_${timestamp}_${type}.json"
    $path = Join-Path $script:SnapshotDir $filename

    $Snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8

    return $path
}

function Get-LatestSnapshot {
    <#
    .SYNOPSIS
        Get the most recent snapshot of a specific type
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("Before", "After", "Any")]
        [string]$Type = "Any"
    )

    if (-not (Test-Path $script:SnapshotDir)) {
        return $null
    }

    $pattern = switch ($Type) {
        "Before" { "snapshot_*_before.json" }
        "After" { "snapshot_*_after.json" }
        "Any" { "snapshot_*.json" }
    }

    $latest = Get-ChildItem -Path $script:SnapshotDir -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latest) {
        try {
            return Get-Content $latest.FullName -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            # Fallback for older PowerShell
            $json = Get-Content $latest.FullName -Raw | ConvertFrom-Json
            return $json
        }
    }

    return $null
}

function Compare-FullSnapshots {
    <#
    .SYNOPSIS
        Compare two full system snapshots
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Before,

        [Parameter(Mandatory)]
        $After
    )

    # Handle PSCustomObject from JSON
    $beforeServices = if ($Before.Services -is [hashtable]) { $Before.Services } else { 
        $ht = @{}
        $Before.Services.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        $ht
    }
    $afterServices = if ($After.Services -is [hashtable]) { $After.Services } else {
        $ht = @{}
        $After.Services.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        $ht
    }

    $beforeRegistry = if ($Before.Registry -is [hashtable]) { $Before.Registry } else {
        $ht = @{}
        $Before.Registry.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        $ht
    }
    $afterRegistry = if ($After.Registry -is [hashtable]) { $After.Registry } else {
        $ht = @{}
        $After.Registry.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        $ht
    }

    $beforeTasks = if ($Before.Tasks -is [hashtable]) { $Before.Tasks } else {
        $ht = @{}
        $Before.Tasks.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        $ht
    }
    $afterTasks = if ($After.Tasks -is [hashtable]) { $After.Tasks } else {
        $ht = @{}
        $After.Tasks.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        $ht
    }

    $beforeApps = if ($Before.Apps -is [array]) { $Before.Apps } else { @($Before.Apps) }
    $afterApps = if ($After.Apps -is [array]) { $After.Apps } else { @($After.Apps) }

    return @{
        BeforeTimestamp = $Before.Timestamp
        AfterTimestamp = $After.Timestamp
        Services = Compare-ServiceSnapshots -Before $beforeServices -After $afterServices
        Registry = Compare-RegistrySnapshots -Before $beforeRegistry -After $afterRegistry
        Tasks = Compare-ScheduledTaskSnapshots -Before $beforeTasks -After $afterTasks
        Apps = Compare-AppSnapshots -Before $beforeApps -After $afterApps
        CountChanges = @{
            ServicesBefore = $Before.Counts.RunningServices
            ServicesAfter = $After.Counts.RunningServices
            TasksBefore = $Before.Counts.EnabledTasks
            TasksAfter = $After.Counts.EnabledTasks
            AppsBefore = $Before.Counts.Apps
            AppsAfter = $After.Counts.Apps
        }
        MemoryChange = @{
            UsedBefore_GB = $Before.MemoryUsage.Used_GB
            UsedAfter_GB = $After.MemoryUsage.Used_GB
            Difference_GB = [math]::Round($After.MemoryUsage.Used_GB - $Before.MemoryUsage.Used_GB, 2)
        }
    }
}

# ============================================================================
# PENDING COMPARISON (Reboot Handling)
# ============================================================================

function Save-PendingComparison {
    <#
    .SYNOPSIS
        Save snapshot and session info for post-reboot comparison
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$BeforeSnapshot,

        [string]$ProfileName
    )

    $pending = @{
        BeforeSnapshot = $BeforeSnapshot
        SessionId = if ($RollbackConfig.CurrentSession) { $RollbackConfig.CurrentSession.Id } else { $null }
        ProfileApplied = $ProfileName
        Timestamp = Get-Date -Format "o"
        SessionSummary = Get-SessionSummary
    }

    # Ensure directory exists
    $dir = Split-Path $script:PendingComparisonFile -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $pending | ConvertTo-Json -Depth 15 | Set-Content -Path $script:PendingComparisonFile -Encoding UTF8

    Write-Verbose "Pending comparison saved for post-reboot"
    return $script:PendingComparisonFile
}

function Test-PendingComparison {
    <#
    .SYNOPSIS
        Check if there's a pending comparison from before reboot
    #>
    [CmdletBinding()]
    param()

    return Test-Path $script:PendingComparisonFile
}

function Get-PendingComparison {
    <#
    .SYNOPSIS
        Get the pending comparison data
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-Path $script:PendingComparisonFile)) {
        return $null
    }

    try {
        $content = Get-Content $script:PendingComparisonFile -Raw
        try {
            return $content | ConvertFrom-Json -AsHashtable
        } catch {
            return $content | ConvertFrom-Json
        }
    } catch {
        Write-Warning "Failed to read pending comparison: $($_.Exception.Message)"
        return $null
    }
}

function Remove-PendingComparison {
    <#
    .SYNOPSIS
        Remove the pending comparison file after processing
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:PendingComparisonFile) {
        Remove-Item $script:PendingComparisonFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-SessionSummary {
    <#
    .SYNOPSIS
        Get summary of current rollback session changes
    #>
    [CmdletBinding()]
    param()

    if (-not $RollbackConfig.CurrentSession) {
        return @{
            SessionId = $null
            TotalChanges = 0
            RegistryChanges = 0
            ServiceChanges = 0
            TaskChanges = 0
        }
    }

    return @{
        SessionId = $RollbackConfig.CurrentSession.Id
        StartTime = $RollbackConfig.CurrentSession.StartTime
        RegistryChanges = $RollbackConfig.CurrentSession.Changes.Registry.Count
        ServiceChanges = $RollbackConfig.CurrentSession.Changes.Services.Count
        TaskChanges = $RollbackConfig.CurrentSession.Changes.ScheduledTasks.Count
        TotalChanges = (
            $RollbackConfig.CurrentSession.Changes.Registry.Count +
            $RollbackConfig.CurrentSession.Changes.Services.Count +
            $RollbackConfig.CurrentSession.Changes.ScheduledTasks.Count
        )
    }
}

# ============================================================================
# COMPARISON DISPLAY
# ============================================================================

function Show-SnapshotComparison {
    <#
    .SYNOPSIS
        Display a formatted comparison between two snapshots
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Before,

        [Parameter(Mandatory)]
        $After
    )

    $comparison = Compare-FullSnapshots -Before $Before -After $After

    Write-Host ""
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host "  BEFORE/AFTER COMPARISON" -ForegroundColor Yellow
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host ""

    # Counts summary
    Write-Host "  System Counts:" -ForegroundColor Gray
    $svcDiff = $comparison.CountChanges.ServicesAfter - $comparison.CountChanges.ServicesBefore
    $taskDiff = $comparison.CountChanges.TasksAfter - $comparison.CountChanges.TasksBefore
    $appDiff = $comparison.CountChanges.AppsAfter - $comparison.CountChanges.AppsBefore

    $svcColor = if ($svcDiff -lt 0) { 'Green' } elseif ($svcDiff -gt 0) { 'Yellow' } else { 'Gray' }
    $taskColor = if ($taskDiff -lt 0) { 'Green' } elseif ($taskDiff -gt 0) { 'Yellow' } else { 'Gray' }
    $appColor = if ($appDiff -lt 0) { 'Green' } elseif ($appDiff -gt 0) { 'Yellow' } else { 'Gray' }

    Write-Host "    Running Services: $($comparison.CountChanges.ServicesBefore) -> $($comparison.CountChanges.ServicesAfter) " -NoNewline
    Write-Host "($svcDiff)" -ForegroundColor $svcColor
    Write-Host "    Enabled Tasks:    $($comparison.CountChanges.TasksBefore) -> $($comparison.CountChanges.TasksAfter) " -NoNewline
    Write-Host "($taskDiff)" -ForegroundColor $taskColor
    Write-Host "    Installed Apps:   $($comparison.CountChanges.AppsBefore) -> $($comparison.CountChanges.AppsAfter) " -NoNewline
    Write-Host "($appDiff)" -ForegroundColor $appColor

    # Memory
    if ($comparison.MemoryChange.Difference_GB) {
        $memColor = if ($comparison.MemoryChange.Difference_GB -lt 0) { 'Green' } else { 'Yellow' }
        Write-Host "    Memory Used:      $($comparison.MemoryChange.UsedBefore_GB) GB -> $($comparison.MemoryChange.UsedAfter_GB) GB " -NoNewline
        Write-Host "($($comparison.MemoryChange.Difference_GB) GB)" -ForegroundColor $memColor
    }

    Write-Host ""

    # Service changes
    if ($comparison.Services.Count -gt 0) {
        Write-Host "  Service Changes ($($comparison.Services.Count)):" -ForegroundColor Yellow
        $comparison.Services | Select-Object -First 10 | ForEach-Object {
            Write-Host "    $($_.ServiceName): $($_.OldStartType) -> $($_.NewStartType)" -ForegroundColor Gray
        }
        if ($comparison.Services.Count -gt 10) {
            Write-Host "    ... and $($comparison.Services.Count - 10) more" -ForegroundColor DarkGray
        }
        Write-Host ""
    }

    # Task changes
    if ($comparison.Tasks.Count -gt 0) {
        Write-Host "  Task Changes ($($comparison.Tasks.Count)):" -ForegroundColor Yellow
        $comparison.Tasks | Select-Object -First 5 | ForEach-Object {
            Write-Host "    $($_.TaskName): $($_.OldState) -> $($_.NewState)" -ForegroundColor Gray
        }
        if ($comparison.Tasks.Count -gt 5) {
            Write-Host "    ... and $($comparison.Tasks.Count - 5) more" -ForegroundColor DarkGray
        }
        Write-Host ""
    }

    # App changes
    if ($comparison.Apps.Removed.Count -gt 0) {
        Write-Host "  Apps Removed ($($comparison.Apps.Removed.Count)):" -ForegroundColor Green
        $comparison.Apps.Removed | Select-Object -First 10 | ForEach-Object {
            Write-Host "    - $_" -ForegroundColor Gray
        }
        if ($comparison.Apps.Removed.Count -gt 10) {
            Write-Host "    ... and $($comparison.Apps.Removed.Count - 10) more" -ForegroundColor DarkGray
        }
        Write-Host ""
    }

    # Registry changes
    $regChanges = @($comparison.Registry).Count
    if ($regChanges -gt 0) {
        Write-Host "  Registry Changes: $regChanges values modified" -ForegroundColor Yellow
        Write-Host ""
    }

    Write-Host ("=" * 65) -ForegroundColor Cyan

    return $comparison
}

# ============================================================================
# REPORT GENERATION
# ============================================================================

function New-OptimizationReport {
    <#
    .SYNOPSIS
        Generate a desktop report summarizing optimizations
    .PARAMETER BeforeSnapshot
        The "before" system snapshot
    .PARAMETER AfterSnapshot
        Optional "after" snapshot for comparison
    .PARAMETER ProfileName
        Name of the profile that was applied
    .PARAMETER OutputPath
        Custom output path (defaults to Desktop)
    #>
    [CmdletBinding()]
    param(
        $BeforeSnapshot,
        $AfterSnapshot,
        [string]$ProfileName,
        [string]$OutputPath
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $sessionSummary = Get-SessionSummary

    if (-not $OutputPath) {
        $OutputPath = "$env:USERPROFILE\Desktop\System_Optimizer_Report.txt"
    }

    # Build hardware summary
    $hwSummary = "Hardware detection unavailable"
    if ($BeforeSnapshot -and $BeforeSnapshot.Hardware) {
        $hwSummary = Format-HardwareSummaryText -Hardware $BeforeSnapshot.Hardware
    }

    # Build comparison section if we have after snapshot
    $comparisonSection = ""
    if ($AfterSnapshot) {
        $comparison = Compare-FullSnapshots -Before $BeforeSnapshot -After $AfterSnapshot

        $svcDiff = $comparison.CountChanges.ServicesAfter - $comparison.CountChanges.ServicesBefore
        $taskDiff = $comparison.CountChanges.TasksAfter - $comparison.CountChanges.TasksBefore
        $appDiff = $comparison.CountChanges.AppsAfter - $comparison.CountChanges.AppsBefore

        $comparisonSection = @"

================================================================================
BEFORE/AFTER COMPARISON
================================================================================
Running Services: $($comparison.CountChanges.ServicesBefore) -> $($comparison.CountChanges.ServicesAfter) ($svcDiff)
Enabled Tasks:    $($comparison.CountChanges.TasksBefore) -> $($comparison.CountChanges.TasksAfter) ($taskDiff)
Installed Apps:   $($comparison.CountChanges.AppsBefore) -> $($comparison.CountChanges.AppsAfter) ($appDiff)
Memory Used:      $($comparison.MemoryChange.UsedBefore_GB) GB -> $($comparison.MemoryChange.UsedAfter_GB) GB ($($comparison.MemoryChange.Difference_GB) GB)

Service Changes: $($comparison.Services.Count)
Task Changes:    $($comparison.Tasks.Count)
Apps Removed:    $($comparison.Apps.Removed.Count)
Registry Changes: $(@($comparison.Registry).Count)
"@

        # Add removed apps list if any
        if ($comparison.Apps.Removed.Count -gt 0) {
            $comparisonSection += "`n`nApps Removed:`n"
            $comparison.Apps.Removed | ForEach-Object {
                $comparisonSection += "  - $_`n"
            }
        }
    } else {
        $comparisonSection = @"

================================================================================
REBOOT REQUIRED
================================================================================
A reboot is recommended to complete the optimizations.

After reboot, run System Optimizer again to see the before/after comparison.
The comparison will show actual changes to services, tasks, and memory usage.
"@
    }

    # Build changes applied section
    $changesSection = ""
    if ($sessionSummary.TotalChanges -gt 0) {
        $changesSection = @"

================================================================================
CHANGES APPLIED (This Session)
================================================================================
Registry Changes:  $($sessionSummary.RegistryChanges)
Service Changes:   $($sessionSummary.ServiceChanges)
Task Changes:      $($sessionSummary.TaskChanges)
---------------------------------
Total Changes:     $($sessionSummary.TotalChanges)
"@
    }

    # Build expected improvements section
    $expectedSection = ""
    if ($ProfileName) {
        $expectedSection = Get-ExpectedImprovementsText -ProfileName $ProfileName
    }

    # Get log file path
    $logPath = "Not available"
    if (Get-Command 'Get-OptLogPath' -ErrorAction SilentlyContinue) {
        $logPath = Get-OptLogPath
        if (-not $logPath) { $logPath = "C:\System_Optimizer\Logs\" }
    }

    # Build full report
    $report = @"
================================================================================
SYSTEM OPTIMIZER - OPTIMIZATION REPORT
================================================================================
Generated: $timestamp
Computer:  $env:COMPUTERNAME
Profile:   $(if ($ProfileName) { $ProfileName } else { "Custom/Manual" })

================================================================================
HARDWARE SUMMARY
================================================================================
$hwSummary
$changesSection
$expectedSection
$comparisonSection

================================================================================
NEXT STEPS
================================================================================
1. Review this report
2. Reboot your computer (if not already done)
3. Run System Optimizer -> Verify Status to confirm changes
4. Check the rollback menu if you need to undo any changes

================================================================================
FILES
================================================================================
Log File:     $logPath
Rollback Dir: $($RollbackConfig.RollbackDir)
================================================================================
"@

    # Write report
    $report | Out-File -FilePath $OutputPath -Encoding UTF8 -Force

    Write-Host ""
    Write-Host "Report saved to: $OutputPath" -ForegroundColor Green

    return $OutputPath
}

function Format-HardwareSummaryText {
    <#
    .SYNOPSIS
        Format hardware profile as plain text for report
    #>
    [CmdletBinding()]
    param($Hardware)

    if (-not $Hardware) { return "Hardware detection unavailable" }

    $lines = @()

    # CPU
    if ($Hardware.CPU) {
        $cpu = $Hardware.CPU
        $cpuName = if ($cpu.Name) { $cpu.Name } else { "Unknown CPU" }
        $lines += "CPU:  $cpuName"
        
        $cores = if ($cpu.Cores) { $cpu.Cores } else { "?" }
        $threads = if ($cpu.Threads) { $cpu.Threads } else { "?" }
        $lines += "      $cores cores / $threads threads"
        
        if ($cpu.Generation) {
            $lines += "      $($cpu.Generation)"
        }
        if ($cpu.IsHybrid) {
            $pCores = if ($cpu.PCores) { $cpu.PCores } else { "?" }
            $eCores = if ($cpu.ECores) { $cpu.ECores } else { "?" }
            $lines += "      Hybrid: $pCores P-cores + $eCores E-cores"
        }
    }

    # GPU
    if ($Hardware.PrimaryGPU) {
        $gpu = $Hardware.PrimaryGPU
        $gpuName = if ($gpu.Name) { $gpu.Name } else { "Unknown GPU" }
        $gpuType = if ($gpu.IsDedicated) { "[Dedicated]" } else { "[Integrated]" }
        $lines += ""
        $lines += "GPU:  $gpuName $gpuType"
        if ($gpu.VRAM_GB) {
            $lines += "      VRAM: $($gpu.VRAM_GB) GB"
        }
        if ($gpu.Series) {
            $lines += "      $($gpu.Series)"
        }
    }

    # Memory
    if ($Hardware.Memory) {
        $mem = $Hardware.Memory
        $total = if ($mem.Total_GB) { $mem.Total_GB } else { "?" }
        $type = if ($mem.Type) { $mem.Type } else { "DDR" }
        $speed = if ($mem.ConfiguredSpeed_MHz) { $mem.ConfiguredSpeed_MHz } else { "?" }
        $lines += ""
        $lines += "RAM:  $total GB $type @ $speed MHz"
        if ($mem.ChannelMode) {
            $lines += "      $($mem.ChannelMode)"
        }
    }

    # Storage
    if ($Hardware.BootDrive) {
        $drive = $Hardware.BootDrive
        $driveType = if ($drive.Type) { $drive.Type } else { "Unknown" }
        $free = if ($drive.Free_GB) { $drive.Free_GB } else { "?" }
        $total = if ($drive.Size_GB) { $drive.Size_GB } else { "?" }
        $lines += ""
        $lines += "Boot: $driveType - $free GB free / $total GB total"
        if ($drive.HealthStatus) {
            $lines += "      Health: $($drive.HealthStatus)"
        }
    }

    return $lines -join "`n"
}

function Get-ExpectedImprovementsText {
    <#
    .SYNOPSIS
        Get expected improvements text based on profile
    #>
    [CmdletBinding()]
    param([string]$ProfileName)

    $improvements = switch ($ProfileName) {
        "Gaming" {
            @(
                "Boot time: ~10-20% faster",
                "RAM usage: ~300-500MB reduction",
                "Gaming FPS: +5-10% (if VBS disabled)",
                "Background CPU: Significantly reduced",
                "Input latency: Reduced (services optimized)"
            )
        }
        "Developer" {
            @(
                "Reduced telemetry overhead",
                "Privacy improvements",
                "Bloatware removed",
                "Long paths enabled"
            )
        }
        "LowSpec" {
            @(
                "Boot time: ~20-30% faster",
                "RAM usage: ~500MB+ reduction",
                "CPU usage: Significantly reduced",
                "Visual effects disabled for performance"
            )
        }
        "Laptop" {
            @(
                "Battery life: Extended",
                "Background activity: Reduced",
                "Telemetry disabled",
                "Bloatware removed"
            )
        }
        "ContentCreator" {
            @(
                "GPU scheduling optimized",
                "Low latency audio enabled",
                "Large system cache enabled",
                "Background activity reduced"
            )
        }
        "Office" {
            @(
                "Game Bar disabled",
                "Minimal changes for stability"
            )
        }
        default {
            @(
                "Various optimizations applied",
                "Check session summary for details"
            )
        }
    }

    $text = @"

================================================================================
EXPECTED IMPROVEMENTS ($ProfileName Profile)
================================================================================
"@

    foreach ($item in $improvements) {
        $text += "`n  * $item"
    }

    $text += @"

`nNote: Actual improvements depend on your hardware and current system state.
Some changes require a reboot to take full effect.
"@

    return $text
}

function Get-QuickHardwareLine {
    <#
    .SYNOPSIS
        Get a one-line hardware summary for menu headers
    #>
    [CmdletBinding()]
    param()

    $parts = @()

    try {
        if (Get-Command 'Get-HardwareProfile' -ErrorAction SilentlyContinue) {
            $hw = Get-HardwareProfile

            if ($hw.CPU) {
                $cpuShort = $hw.CPU.Name -replace 'Intel\(R\) Core\(TM\) ', '' -replace 'AMD ', '' -replace ' Processor', '' -replace '\s+', ' '
                $cpuShort = $cpuShort.Trim()
                if ($cpuShort.Length -gt 20) {
                    $cpuShort = $cpuShort.Substring(0, 17) + "..."
                }
                $parts += $cpuShort
            }

            if ($hw.PrimaryGPU) {
                $gpuShort = $hw.PrimaryGPU.Name -replace 'NVIDIA GeForce ', '' -replace 'AMD Radeon ', '' -replace 'Intel\(R\) ', ''
                if ($hw.PrimaryGPU.VRAM_GB) {
                    $gpuShort += " $($hw.PrimaryGPU.VRAM_GB)GB"
                }
                if ($gpuShort.Length -gt 20) {
                    $gpuShort = $gpuShort.Substring(0, 17) + "..."
                }
                $parts += $gpuShort
            }

            if ($hw.Memory) {
                $parts += "$($hw.Memory.Total_GB)GB $($hw.Memory.Type)"
            }

            if ($hw.BootDrive) {
                $parts += "$($hw.BootDrive.Type) $($hw.BootDrive.Free_GB)GB free"
            }
        }
    } catch {
        # Silently fail
    }

    if ($parts.Count -eq 0) {
        return $null
    }

    return $parts -join " | "
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
    'Get-SessionSummary',

    # History & UI
    'Get-RollbackHistory',
    'Show-RollbackMenu',
    'Show-SessionDetails',
    'Invoke-Rollback',
    'Clear-OldSessions',

    # Helpers
    'Get-WindowsVersionInfo',
    'Test-CommandAvailable',
    'Get-QuickHardwareLine',

    # Bulk tracking wrappers
    'Start-TrackedOperation',
    'Stop-TrackedOperation',
    'Add-RegistryChangeToSession',
    'Add-ServiceChangeToSession',

    # Snapshot-based tracking (existing)
    'Get-RegistrySnapshot',
    'Compare-RegistrySnapshots',
    'Get-ServiceSnapshot',
    'Compare-ServiceSnapshots',

    # Full system snapshots (NEW)
    'Get-ScheduledTaskSnapshot',
    'Compare-ScheduledTaskSnapshots',
    'Get-AppSnapshot',
    'Compare-AppSnapshots',
    'New-FullSystemSnapshot',
    'Save-Snapshot',
    'Get-LatestSnapshot',
    'Compare-FullSnapshots',
    'Show-SnapshotComparison',

    # Pending comparison / reboot handling (NEW)
    'Save-PendingComparison',
    'Test-PendingComparison',
    'Get-PendingComparison',
    'Remove-PendingComparison',

    # Report generation (NEW)
    'New-OptimizationReport',
    'Format-HardwareSummaryText',
    'Get-ExpectedImprovementsText'
)
