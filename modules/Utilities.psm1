#Requires -Version 5.1
<#
.SYNOPSIS
    Utilities Module - System Optimizer
.DESCRIPTION
    Provides utility functions for System Optimizer including Wi-Fi password extraction,
    optimization status verification, log viewing, and menu display helpers.

Exported Functions:
    Get-WifiPasswords           - Extract saved Wi-Fi passwords
    Test-OptimizationStatus     - Check current optimization status
    Show-LogViewer              - Interactive log viewer
    Initialize-Logging          - Initialize logging (compatibility)
    Write-Log                   - Write log entry (wrapper)
    Set-ConsoleSize             - Set console window dimensions
    Show-Menu                   - Display formatted menu

Features:
    - Wi-Fi password extraction from system profiles
    - Multi-category optimization verification
    - Log file browsing with filtering
    - Console size management for UI consistency

Dependencies:
    - Requires admin privileges for Wi-Fi password extraction
    - Logging module for Write-Log functionality

Version: 1.0.0
#>

function Get-WifiPasswords {
    Write-Log "EXTRACTING WI-FI PASSWORDS" "SECTION"

    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
        ($_ -split ":")[1].Trim()
    }

    if ($profiles.Count -eq 0) {
        Write-Log "No Wi-Fi profiles found" "WARNING"
        return
    }

    $wifiData = @()
    foreach ($wifiProfile in $profiles) {
        $profileInfo = netsh wlan show profile name="$wifiProfile" key=clear 2>$null
        $password = ($profileInfo | Select-String "Key Content") -replace ".*:\s*", ""

        if ([string]::IsNullOrEmpty($password)) {
            $password = "(No password / Open network)"
        }

        $wifiData += [PSCustomObject]@{
            SSID = $wifiProfile
            Password = $password
        }

        Write-Log "SSID: $wifiProfile | Password: $password" "INFO"
    }

    # Save to file
    $wifiFile = "C:\temp\wifi_passwords_$(Get-Date -Format 'yyyy-MM-dd').txt"
    $wifiData | Format-Table -AutoSize | Out-String | Set-Content -Path $wifiFile
    Write-Log "Wi-Fi passwords saved to: $wifiFile" "SUCCESS"

    # Display table
    Write-Host ""
    $wifiData | Format-Table -AutoSize
}

function Test-OptimizationStatus {
    Write-Log "VERIFYING OPTIMIZATION STATUS" "SECTION"

    Write-Host ""
    Write-Host "=== SYSTEM STATUS ===" -ForegroundColor Cyan

    # Memory Usage
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMem = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMem = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMem = $totalMem - $freeMem
    $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 1)
    Write-Host "Memory: $usedMem GB / $totalMem GB ($memPercent% used)" -ForegroundColor $(if ($memPercent -lt 50) { "Green" } else { "Yellow" })

    # Running Services
    $runningServices = (Get-Service | Where-Object { $_.Status -eq 'Running' }).Count
    Write-Host "Running Services: $runningServices" -ForegroundColor $(if ($runningServices -lt 100) { "Green" } else { "Yellow" })

    # Startup Programs
    $startupItems = (Get-CimInstance Win32_StartupCommand).Count
    Write-Host "Startup Items: $startupItems" -ForegroundColor $(if ($startupItems -lt 10) { "Green" } else { "Yellow" })

    # Power Plan
    $powerPlan = powercfg /getactivescheme
    $planName = if ($powerPlan -match '"([^"]+)"') { $matches[1] } else { "Unknown" }
    Write-Host "Power Plan: $planName" -ForegroundColor $(if ($planName -like "*High*" -or $planName -like "*Ultimate*") { "Green" } else { "Yellow" })

    Write-Host ""
    Write-Host "=== KEY SETTINGS ===" -ForegroundColor Cyan

    # Check Telemetry
    $telemetry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    $telemetryStatus = if ($telemetry.AllowTelemetry -eq 0) { "Disabled" } else { "Enabled" }
    Write-Host "Telemetry: $telemetryStatus" -ForegroundColor $(if ($telemetryStatus -eq "Disabled") { "Green" } else { "Red" })

    # Check Game Bar
    $gameBar = Get-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue
    $gameBarStatus = if ($gameBar.GameDVR_Enabled -eq 0) { "Disabled" } else { "Enabled" }
    Write-Host "Game Bar: $gameBarStatus" -ForegroundColor $(if ($gameBarStatus -eq "Disabled") { "Green" } else { "Red" })

    # Check VBS
    $vbs = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -ErrorAction SilentlyContinue
    $vbsStatus = if ($vbs.Enabled -eq 0) { "Disabled" } else { "Enabled" }
    Write-Host "VBS/Memory Integrity: $vbsStatus" -ForegroundColor $(if ($vbsStatus -eq "Disabled") { "Green" } else { "Red" })

    # Check Defender Real-time
    $defender = Get-MpPreference -ErrorAction SilentlyContinue
    $defenderStatus = if ($defender.DisableRealtimeMonitoring -eq $true) { "Disabled" } else { "Enabled" }
    Write-Host "Defender Real-time: $defenderStatus" -ForegroundColor $(if ($defenderStatus -eq "Disabled") { "Green" } else { "Yellow" })

    # Check IPv6
    $ipv6 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -ErrorAction SilentlyContinue
    $ipv6Status = if ($ipv6.DisabledComponents -eq 255) { "Disabled" } else { "Enabled" }
    Write-Host "IPv6: $ipv6Status" -ForegroundColor $(if ($ipv6Status -eq "Disabled") { "Green" } else { "Yellow" })

    # Check Background Apps
    $bgApps = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
    $bgAppsStatus = if ($bgApps.GlobalUserDisabled -eq 1) { "Disabled" } else { "Enabled" }
    Write-Host "Background Apps: $bgAppsStatus" -ForegroundColor $(if ($bgAppsStatus -eq "Disabled") { "Green" } else { "Red" })

    Write-Host ""
    Write-Host "=== DISABLED SERVICES ===" -ForegroundColor Cyan
    $criticalServices = @("DiagTrack", "WSearch", "SysMain", "dmwappushservice")
    foreach ($svc in $criticalServices) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            $status = $service.Status
            $startType = $service.StartType
            $color = if ($startType -eq "Disabled") { "Green" } else { "Yellow" }
            Write-Host "$svc : $status ($startType)" -ForegroundColor $color
        }
    }

    Write-Host ""
    Write-Log "Verification completed" "SUCCESS"
}

function Show-LogViewer {
    Set-ConsoleSize
    Clear-Host
    Write-Log "LOG VIEWER" "SECTION"

    Write-Host ""
    Write-Host "  Log Directory: $LogDir" -ForegroundColor Cyan
    Write-Host "  Current Log:   $LogFile" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Options:" -ForegroundColor Gray
    Write-Host "  [1] View current session log"
    Write-Host "  [2] View recent log files"
    Write-Host "  [3] Open log folder in Explorer"
    Write-Host "  [4] Export log summary"
    Write-Host "  [5] Clear old logs (30+ days)"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            # View current log
            if ($LogFile -and (Test-Path $LogFile)) {
                Write-Host ""
                Write-Host "  Current Session Log (last 100 lines):" -ForegroundColor Cyan
                Write-Host ("-" * 70) -ForegroundColor Gray
                Get-Content $LogFile -Tail 100
                Write-Host ("-" * 70) -ForegroundColor Gray
            } else {
                Write-Host "  No log file for current session" -ForegroundColor Yellow
            }
        }
        "2" {
            # View recent logs
            Write-Host ""
            Write-Host "  Recent Log Files:" -ForegroundColor Cyan
            $logs = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 15

            if ($logs) {
                $i = 1
                foreach ($log in $logs) {
                    $errors = (Select-String -Path $log.FullName -Pattern "\[ERROR\]" -ErrorAction SilentlyContinue).Count
                    $warnings = (Select-String -Path $log.FullName -Pattern "\[WARNING\]" -ErrorAction SilentlyContinue).Count
                    $sizeKB = [math]::Round($log.Length / 1KB, 1)
                    $color = if ($errors -gt 0) { "Red" } elseif ($warnings -gt 0) { "Yellow" } else { "Gray" }
                    Write-Host "    [$i] $($log.Name) - ${sizeKB}KB - E:$errors W:$warnings" -ForegroundColor $color
                    $i++
                }
                Write-Host ""
                $viewChoice = Read-Host "Enter number to view log (or Enter to skip)"
                if ($viewChoice -match '^\d+$' -and [int]$viewChoice -le $logs.Count) {
                    $selectedLog = $logs[[int]$viewChoice - 1]
                    if ($selectedLog) {
                        Write-Host ""
                        Write-Host "  Last 50 lines of $($selectedLog.Name):" -ForegroundColor Cyan
                        Write-Host ("-" * 70) -ForegroundColor Gray
                        Get-Content $selectedLog.FullName -Tail 50
                    }
                }
            } else {
                Write-Host "    No log files found" -ForegroundColor Yellow
            }
        }
        "3" {
            # Open log folder
            if (Test-Path $LogDir) {
                Start-Process explorer.exe -ArgumentList $LogDir
                Write-Log "Opened log folder: $LogDir" "SUCCESS"
            } else {
                Write-Log "Log folder does not exist" "WARNING"
            }
        }
        "4" {
            # Export summary
            $summaryPath = "$LogDir\LogSummary_$(Get-Date -Format 'yyyy-MM-dd').txt"
            $summary = @"
================================================================================
SYSTEM OPTIMIZER - LOG SUMMARY
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
================================================================================

LOG FILES IN $LogDir`:

"@
            $logs = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending

            foreach ($log in $logs) {
                $errors = (Select-String -Path $log.FullName -Pattern "\[ERROR\]" -ErrorAction SilentlyContinue).Count
                $warnings = (Select-String -Path $log.FullName -Pattern "\[WARNING\]" -ErrorAction SilentlyContinue).Count
                $successes = (Select-String -Path $log.FullName -Pattern "\[SUCCESS\]" -ErrorAction SilentlyContinue).Count
                $summary += "  $($log.Name)`n"
                $summary += "    Date: $($log.LastWriteTime)`n"
                $summary += "    Size: $([math]::Round($log.Length / 1KB, 1)) KB`n"
                $summary += "    Errors: $errors | Warnings: $warnings | Successes: $successes`n`n"
            }

            $summary | Out-File $summaryPath -Force
            Write-Log "Summary exported to: $summaryPath" "SUCCESS"
            Start-Process notepad.exe -ArgumentList $summaryPath
        }
        "5" {
            # Clear old logs
            $oldLogs = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }

            if ($oldLogs.Count -gt 0) {
                Write-Host ""
                Write-Host "  Found $($oldLogs.Count) logs older than 30 days" -ForegroundColor Yellow
                $confirm = Read-Host "Delete them? (Y/N)"
                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    $oldLogs | Remove-Item -Force
                    Write-Log "Deleted $($oldLogs.Count) old log files" "SUCCESS"
                }
            } else {
                Write-Host "  No logs older than 30 days found" -ForegroundColor Green
            }
        }
    }
}

function Initialize-Logging {
    # Ensure log directory exists
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    # Create log file with timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $script:LogFile = "$LogDir\SystemOptimizer_$timestamp.log"

    # Write header
    $header = @"
================================================================================
SYSTEM OPTIMIZER - MAIN SCRIPT LOG
================================================================================
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
PowerShell: $($PSVersionTable.PSVersion)
================================================================================

"@
    Add-Content -Path $LogFile -Value $header -ErrorAction SilentlyContinue

    # Cleanup old logs (keep last 30 days)
    Get-ChildItem -Path $LogDir -Filter "SystemOptimizer_*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $shortTime = Get-Date -Format "HH:mm:ss"

    # Write to log file
    $logMessage = "[$timestamp] [$Type] $Message"
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }

    # Write to console with colors and timestamps
    switch ($Type) {
        "SUCCESS" { Write-Host "[$shortTime] [OK] " -ForegroundColor Green -NoNewline; Write-Host $Message }
        "ERROR"   { Write-Host "[$shortTime] [X] " -ForegroundColor Red -NoNewline; Write-Host $Message }
        "WARNING" { Write-Host "[$shortTime] [!] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "SECTION" { Write-Host "`n[$shortTime] === " -ForegroundColor Cyan -NoNewline; Write-Host $Message -ForegroundColor Cyan -NoNewline; Write-Host " ===" -ForegroundColor Cyan }
        default   { Write-Host "[$shortTime] [-] " -ForegroundColor Gray -NoNewline; Write-Host $Message }
    }
}

function Set-ConsoleSize {
    param(
        [int]$Width = $ConsoleWidth,
        [int]$Height = $ConsoleHeight
    )

    try {
        # Only resize if running in a console host (not ISE or VS Code)
        if ($Host.Name -eq 'ConsoleHost') {
            $maxWidth = $Host.UI.RawUI.MaxPhysicalWindowSize.Width
            $maxHeight = $Host.UI.RawUI.MaxPhysicalWindowSize.Height

            # Clamp to max available size
            $Width = [Math]::Min($Width, $maxWidth)
            $Height = [Math]::Min($Height, $maxHeight)

            # Set buffer size first (must be >= window size)
            $bufferSize = $Host.UI.RawUI.BufferSize
            $bufferSize.Width = [Math]::Max($Width, $bufferSize.Width)
            $bufferSize.Height = 9999  # Large buffer for scrollback
            $Host.UI.RawUI.BufferSize = $bufferSize

            # Set window size
            $windowSize = $Host.UI.RawUI.WindowSize
            $windowSize.Width = $Width
            $windowSize.Height = $Height
            $Host.UI.RawUI.WindowSize = $windowSize
        }
    } catch {
        # Silently ignore sizing errors (happens in some terminals)
    }
}

function Show-Menu {
    Set-ConsoleSize
    Clear-Host
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  ULTIMATE WINDOWS 11 OPTIMIZATION SCRIPT" -ForegroundColor Yellow
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Run ALL Optimizations (Recommended)" -ForegroundColor Green
    Write-Host "  [16] Full Setup (PatchMyPC + Office + Services + MAS)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Individual Options:" -ForegroundColor Gray
    Write-Host "  [2] Disable Telemetry & Privacy Tweaks"
    Write-Host "  [3] Disable Unnecessary Services"
    Write-Host "  [4] Remove Bloatware Apps"
    Write-Host "  [5] Disable Scheduled Tasks"
    Write-Host "  [6] Registry Optimizations"
    Write-Host "  [7] Disable VBS/Memory Integrity"
    Write-Host "  [8] Network Optimizations"
    Write-Host "  [9] Remove OneDrive"
    Write-Host "  [10] System Maintenance (DISM/SFC)"
    Write-Host ""
    Write-Host "  Software & Activation:" -ForegroundColor Gray
    Write-Host "  [11] PatchMyPC (Update/Install Software)"
    Write-Host "  [12] Office Tool Plus (Install Office)"
    Write-Host "  [13] Microsoft Activation Script (MAS)"
    Write-Host ""
    Write-Host "  Advanced:" -ForegroundColor Gray
    Write-Host "  [17] Set Power Plan (High Performance/Ultimate)"
    Write-Host "  [18] Run O&O ShutUp10 (Privacy Tool)"
    Write-Host "  [19] Reset Group Policy"
    Write-Host "  [20] Reset WMI Repository"
    Write-Host "  [21] Disk Cleanup"
    Write-Host "  [22] Windows Update Control"
    Write-Host "  [23] Snappy Driver Installer"
    Write-Host "  [24] Reset Network"
    Write-Host "  [25] Repair Windows Update"
    Write-Host "  [26] Windows Defender Control"
    Write-Host "  [27] Advanced Debloat Scripts (AIO)"
    Write-Host "  [28] WinUtil Service Sync (Safe Mode)" -ForegroundColor Magenta
    Write-Host "  [29] DISM++ Style Tweaks" -ForegroundColor Magenta
    Write-Host "  [30] Windows Image Tool (ISO/Install)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Utilities:" -ForegroundColor Gray
    Write-Host "  [14] Extract Wi-Fi Passwords"
    Write-Host "  [15] Verify Optimization Status"
    Write-Host "  [31] View Logs" -ForegroundColor DarkGray
    Write-Host "  [32] User Profile Backup & Restore" -ForegroundColor Magenta
    Write-Host "  [33] Shutdown & Restart Options" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Log: $LogFile" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [0] Exit"
    Write-Host ""
}

# Export functions
Export-ModuleMember -Function @(
    'Get-WifiPasswords',
    'Test-OptimizationStatus',
    'Show-LogViewer',
    'Initialize-Logging',
    'Write-Log',
    'Set-ConsoleSize',
    'Show-Menu'
)
