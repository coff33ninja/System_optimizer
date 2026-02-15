#Requires -Version 5.1
<#
.SYNOPSIS
    Shutdown Module - System Optimizer
.DESCRIPTION
    Provides power state controls and shutdown/restart options.

Exported Functions:
    Show-ShutdownMenu    - Interactive shutdown menu
    Restart-Computer     - Restart with optional delay
    Stop-Computer        - Shutdown with optional delay
    Suspend-Computer     - Sleep/Standby
    Hibernate-Computer   - Hibernate
    Lock-Computer        - Lock workstation
    SignOut-User         - Sign out current user

Power States:
    - Restart: Reboot system
    - Shutdown: Power off
    - Sleep: Low power standby
    - Hibernate: Save state to disk
    - Lock: Lock without signing out
    - Sign Out: End user session

Features:
    - Countdown timer with cancel option
    - Force close applications option
    - Scheduled shutdown capability

Requires Admin: No (most functions)

Version: 1.0.0
#>

function Show-ShutdownMenu {
    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Shutdown & Restart Options" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Immediate Actions:" -ForegroundColor Gray
        Write-Host "  [1] Shutdown Now"
        Write-Host "  [2] Restart Now"
        Write-Host "  [3] Log Off Current User"
        Write-Host "  [4] Lock Workstation"
        Write-Host ""
        Write-Host "  Scheduled Actions:" -ForegroundColor Gray
        Write-Host "  [5] Schedule Shutdown (Custom Time)"
        Write-Host "  [6] Schedule Restart (Custom Time)"
        Write-Host "  [7] Schedule Shutdown (Timer in Minutes)"
        Write-Host "  [8] Schedule Restart (Timer in Minutes)"
        Write-Host ""
        Write-Host "  Advanced Options:" -ForegroundColor Gray
        Write-Host "  [9] Force Shutdown (Kill All Processes)"
        Write-Host "  [10] Force Restart (Kill All Processes)"
        Write-Host "  [11] Hibernate (if enabled)"
        Write-Host "  [12] Sleep/Suspend"
        Write-Host ""
        Write-Host "  Schedule Management:" -ForegroundColor Gray
        Write-Host "  [13] View Scheduled Shutdowns"
        Write-Host "  [14] Cancel All Scheduled Shutdowns"
        Write-Host ""
        Write-Host "  [0] Back to main menu"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Invoke-ImmediateShutdown }
            "2" { Invoke-ImmediateRestart }
            "3" { Invoke-LogOff }
            "4" { Invoke-LockWorkstation }
            "5" { Schedule-ShutdownAtTime }
            "6" { Schedule-RestartAtTime }
            "7" { Schedule-ShutdownTimer }
            "8" { Schedule-RestartTimer }
            "9" { Invoke-ForceShutdown }
            "10" { Invoke-ForceRestart }
            "11" { Invoke-Hibernate }
            "12" { Invoke-Sleep }
            "13" { Show-ScheduledShutdowns }
            "14" { Cancel-AllScheduledShutdowns }
            "0" { return }
            default { Write-Host "Invalid option" -ForegroundColor Red }
        }

        if ($choice -ne "0" -and $choice -notin @("1","2","9","10")) {
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } while ($true)
}

function Invoke-ImmediateShutdown {
    Write-Log "IMMEDIATE SHUTDOWN REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "WARNING: This will shutdown the computer immediately!" -ForegroundColor Red
    Write-Host "All unsaved work will be lost!" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Are you sure? Type 'SHUTDOWN' to confirm"

    if ($confirm -eq "SHUTDOWN") {
        Write-Log "Initiating immediate shutdown..." "WARNING"
        Write-Host "Shutting down in 10 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 3
        Write-Host "7..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "6..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "5..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "4..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "3..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "2..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "1..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "Goodbye!" -ForegroundColor Red
        Start-Sleep -Seconds 1
        shutdown /s /t 0
    } else {
        Write-Log "Shutdown cancelled by user" "INFO"
    }
}

function Invoke-ImmediateRestart {
    Write-Log "IMMEDIATE RESTART REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "WARNING: This will restart the computer immediately!" -ForegroundColor Red
    Write-Host "All unsaved work will be lost!" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Are you sure? Type 'RESTART' to confirm"

    if ($confirm -eq "RESTART") {
        Write-Log "Initiating immediate restart..." "WARNING"
        Write-Host "Restarting in 10 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 3
        Write-Host "7..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "6..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "5..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "4..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "3..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "2..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "1..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "See you soon!" -ForegroundColor Red
        Start-Sleep -Seconds 1
        shutdown /r /t 0
    } else {
        Write-Log "Restart cancelled by user" "INFO"
    }
}

function Invoke-LogOff {
    Write-Log "LOG OFF REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "This will log off the current user." -ForegroundColor Yellow
    Write-Host "All unsaved work will be lost!" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Continue? (y/N)"

    if ($confirm -eq "y" -or $confirm -eq "Y") {
        Write-Log "Logging off current user..." "INFO"
        shutdown /l
    } else {
        Write-Log "Log off cancelled by user" "INFO"
    }
}

function Invoke-LockWorkstation {
    Write-Log "LOCKING WORKSTATION" "INFO"
    Write-Host "Locking workstation..." -ForegroundColor Green
    rundll32.exe user32.dll,LockWorkStation
}

function Schedule-ShutdownAtTime {
    Write-Log "SCHEDULE SHUTDOWN AT SPECIFIC TIME" "SECTION"
    Write-Host ""
    Write-Host "Schedule shutdown at a specific time (24-hour format)" -ForegroundColor Cyan
    Write-Host "Examples: 14:30, 23:45, 09:15" -ForegroundColor Gray
    Write-Host ""

    $timeInput = Read-Host "Enter time (HH:MM)"

    try {
        $targetTime = [DateTime]::ParseExact($timeInput, "HH:mm", $null)
        $currentTime = Get-Date

        if ($targetTime.TimeOfDay -lt $currentTime.TimeOfDay) {
            $targetTime = $targetTime.AddDays(1)
        }

        $timeUntil = ($targetTime - $currentTime).TotalSeconds

        if ($timeUntil -lt 60) {
            Write-Host "Time must be at least 1 minute in the future!" -ForegroundColor Red
            return
        }

        Write-Host ""
        Write-Host "Shutdown scheduled for: $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        Write-Host "Time until shutdown: $([Math]::Round($timeUntil / 60, 1)) minutes" -ForegroundColor Yellow
        Write-Host ""

        $confirm = Read-Host "Confirm schedule? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            shutdown /s /t $([Math]::Round($timeUntil))
            Write-Log "Shutdown scheduled for $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" "SUCCESS"
            Write-Host "Shutdown scheduled successfully!" -ForegroundColor Green
            Write-Host "Use option 14 to cancel if needed." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Invalid time format! Use HH:MM (24-hour format)" -ForegroundColor Red
    }
}

function Schedule-RestartAtTime {
    Write-Log "SCHEDULE RESTART AT SPECIFIC TIME" "SECTION"
    Write-Host ""
    Write-Host "Schedule restart at a specific time (24-hour format)" -ForegroundColor Cyan
    Write-Host "Examples: 14:30, 23:45, 09:15" -ForegroundColor Gray
    Write-Host ""

    $timeInput = Read-Host "Enter time (HH:MM)"

    try {
        $targetTime = [DateTime]::ParseExact($timeInput, "HH:mm", $null)
        $currentTime = Get-Date

        if ($targetTime.TimeOfDay -lt $currentTime.TimeOfDay) {
            $targetTime = $targetTime.AddDays(1)
        }

        $timeUntil = ($targetTime - $currentTime).TotalSeconds

        if ($timeUntil -lt 60) {
            Write-Host "Time must be at least 1 minute in the future!" -ForegroundColor Red
            return
        }

        Write-Host ""
        Write-Host "Restart scheduled for: $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        Write-Host "Time until restart: $([Math]::Round($timeUntil / 60, 1)) minutes" -ForegroundColor Yellow
        Write-Host ""

        $confirm = Read-Host "Confirm schedule? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            shutdown /r /t $([Math]::Round($timeUntil))
            Write-Log "Restart scheduled for $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" "SUCCESS"
            Write-Host "Restart scheduled successfully!" -ForegroundColor Green
            Write-Host "Use option 14 to cancel if needed." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Invalid time format! Use HH:MM (24-hour format)" -ForegroundColor Red
    }
}

function Schedule-ShutdownTimer {
    Write-Log "SCHEDULE SHUTDOWN TIMER" "SECTION"
    Write-Host ""
    Write-Host "Schedule shutdown after a specific number of minutes" -ForegroundColor Cyan
    Write-Host "Examples: 30 (30 minutes), 120 (2 hours), 5 (5 minutes)" -ForegroundColor Gray
    Write-Host ""

    $minutesInput = Read-Host "Enter minutes until shutdown"

    try {
        $minutes = [int]$minutesInput

        if ($minutes -lt 1) {
            Write-Host "Minutes must be at least 1!" -ForegroundColor Red
            return
        }

        if ($minutes -gt 1440) {
            Write-Host "Maximum is 1440 minutes (24 hours)!" -ForegroundColor Red
            return
        }

        $seconds = $minutes * 60
        $targetTime = (Get-Date).AddMinutes($minutes)

        Write-Host ""
        Write-Host "Shutdown scheduled for: $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        Write-Host "Time until shutdown: $minutes minutes" -ForegroundColor Yellow
        Write-Host ""

        $confirm = Read-Host "Confirm schedule? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            shutdown /s /t $seconds
            Write-Log "Shutdown scheduled for $minutes minutes ($($targetTime.ToString('yyyy-MM-dd HH:mm:ss')))" "SUCCESS"
            Write-Host "Shutdown scheduled successfully!" -ForegroundColor Green
            Write-Host "Use option 14 to cancel if needed." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Invalid number! Enter a whole number of minutes." -ForegroundColor Red
    }
}

function Schedule-RestartTimer {
    Write-Log "SCHEDULE RESTART TIMER" "SECTION"
    Write-Host ""
    Write-Host "Schedule restart after a specific number of minutes" -ForegroundColor Cyan
    Write-Host "Examples: 30 (30 minutes), 120 (2 hours), 5 (5 minutes)" -ForegroundColor Gray
    Write-Host ""

    $minutesInput = Read-Host "Enter minutes until restart"

    try {
        $minutes = [int]$minutesInput

        if ($minutes -lt 1) {
            Write-Host "Minutes must be at least 1!" -ForegroundColor Red
            return
        }

        if ($minutes -gt 1440) {
            Write-Host "Maximum is 1440 minutes (24 hours)!" -ForegroundColor Red
            return
        }

        $seconds = $minutes * 60
        $targetTime = (Get-Date).AddMinutes($minutes)

        Write-Host ""
        Write-Host "Restart scheduled for: $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        Write-Host "Time until restart: $minutes minutes" -ForegroundColor Yellow
        Write-Host ""

        $confirm = Read-Host "Confirm schedule? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            shutdown /r /t $seconds
            Write-Log "Restart scheduled for $minutes minutes ($($targetTime.ToString('yyyy-MM-dd HH:mm:ss')))" "SUCCESS"
            Write-Host "Restart scheduled successfully!" -ForegroundColor Green
            Write-Host "Use option 14 to cancel if needed." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Invalid number! Enter a whole number of minutes." -ForegroundColor Red
    }
}

function Invoke-ForceShutdown {
    Write-Log "FORCE SHUTDOWN REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "WARNING: This will FORCE shutdown the computer!" -ForegroundColor Red
    Write-Host "All running programs will be terminated without saving!" -ForegroundColor Red
    Write-Host "This may cause data loss!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Are you absolutely sure? Type 'FORCE SHUTDOWN' to confirm"

    if ($confirm -eq "FORCE SHUTDOWN") {
        Write-Log "Initiating force shutdown..." "WARNING"
        Write-Host "Force shutting down in 5 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "4..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "3..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "2..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "1..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        shutdown /s /f /t 0
    } else {
        Write-Log "Force shutdown cancelled by user" "INFO"
    }
}

function Invoke-ForceRestart {
    Write-Log "FORCE RESTART REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "WARNING: This will FORCE restart the computer!" -ForegroundColor Red
    Write-Host "All running programs will be terminated without saving!" -ForegroundColor Red
    Write-Host "This may cause data loss!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Are you absolutely sure? Type 'FORCE RESTART' to confirm"

    if ($confirm -eq "FORCE RESTART") {
        Write-Log "Initiating force restart..." "WARNING"
        Write-Host "Force restarting in 5 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "4..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "3..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "2..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "1..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        shutdown /r /f /t 0
    } else {
        Write-Log "Force restart cancelled by user" "INFO"
    }
}

function Invoke-Hibernate {
    Write-Log "HIBERNATE REQUESTED" "SECTION"

    $hibernateEnabled = (powercfg /a | Select-String "hibernate" -Quiet)

    if (-not $hibernateEnabled) {
        Write-Host "Hibernation is not enabled on this system." -ForegroundColor Red
        Write-Host ""
        $enable = Read-Host "Would you like to enable hibernation? (y/N)"

        if ($enable -eq "y" -or $enable -eq "Y") {
            Write-Log "Enabling hibernation..." "INFO"
            powercfg /hibernate on
            Write-Host "Hibernation enabled!" -ForegroundColor Green
            Write-Host ""
        } else {
            Write-Log "Hibernation not enabled by user" "INFO"
            return
        }
    }

    Write-Host "This will hibernate the computer (save state to disk and power off)." -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (y/N)"

    if ($confirm -eq "y" -or $confirm -eq "Y") {
        Write-Log "Hibernating system..." "INFO"
        shutdown /h
    } else {
        Write-Log "Hibernation cancelled by user" "INFO"
    }
}

function Invoke-Sleep {
    Write-Log "SLEEP REQUESTED" "SECTION"
    Write-Host "This will put the computer to sleep (low power mode)." -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (y/N)"

    if ($confirm -eq "y" -or $confirm -eq "Y") {
        Write-Log "Putting system to sleep..." "INFO"
        rundll32.exe powrprof.dll,SetSuspendState 0,1,0
    } else {
        Write-Log "Sleep cancelled by user" "INFO"
    }
}

function Show-ScheduledShutdowns {
    Write-Log "VIEWING SCHEDULED SHUTDOWNS" "SECTION"
    Write-Host ""
    Write-Host "Checking for scheduled shutdowns..." -ForegroundColor Cyan

    try {
        $tasks = schtasks /query /fo csv | ConvertFrom-Csv | Where-Object { $_.TaskName -like "*shutdown*" -or $_.TaskName -like "*restart*" }

        if ($tasks) {
            Write-Host "Scheduled shutdown/restart tasks found:" -ForegroundColor Green
            $tasks | Format-Table TaskName, Status, "Next Run Time" -AutoSize
        } else {
            Write-Host "No scheduled shutdown/restart tasks found via Task Scheduler." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Note: shutdown.exe scheduled shutdowns are not easily detectable." -ForegroundColor Gray
        Write-Host "If you scheduled a shutdown using options 5-8, use option 14 to cancel." -ForegroundColor Gray

    } catch {
        Write-Host "Error checking scheduled tasks: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "You can manually check with: schtasks /query" -ForegroundColor Gray
    }
}

function Cancel-AllScheduledShutdowns {
    Write-Log "CANCELLING SCHEDULED SHUTDOWNS" "SECTION"
    Write-Host ""
    Write-Host "This will cancel any pending shutdown/restart scheduled with shutdown.exe" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Cancel all scheduled shutdowns? (y/N)"

    if ($confirm -eq "y" -or $confirm -eq "Y") {
        try {
            shutdown /a
            Write-Log "Cancelled scheduled shutdowns" "SUCCESS"
            Write-Host "All scheduled shutdowns have been cancelled!" -ForegroundColor Green
        } catch {
            Write-Host "No scheduled shutdowns to cancel, or cancellation failed." -ForegroundColor Yellow
            Write-Log "Shutdown cancellation failed or no shutdowns scheduled: $_" "WARNING"
        }
    } else {
        Write-Log "Shutdown cancellation cancelled by user" "INFO"
    }
}

# Export all functions
Export-ModuleMember -Function @(
    'Show-ShutdownMenu',
    'Invoke-ImmediateShutdown',
    'Invoke-ImmediateRestart',
    'Invoke-LogOff',
    'Invoke-LockWorkstation',
    'Schedule-ShutdownAtTime',
    'Schedule-RestartAtTime',
    'Schedule-ShutdownTimer',
    'Schedule-RestartTimer',
    'Invoke-ForceShutdown',
    'Invoke-ForceRestart',
    'Invoke-Hibernate',
    'Invoke-Sleep',
    'Show-ScheduledShutdowns',
    'Cancel-AllScheduledShutdowns'
)
