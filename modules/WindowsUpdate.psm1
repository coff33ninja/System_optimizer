# ============================================================================
# WindowsUpdate Module - System Optimizer
# ============================================================================

function Set-WindowsUpdateControl {
    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Windows Update Control" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Pause/Control:" -ForegroundColor Gray
        Write-Host "  [1] Pause updates for 35 days (registry)"
        Write-Host "  [2] Pause updates with scheduled task (AIO method)"
        Write-Host "  [3] Disable Windows Update service"
        Write-Host "  [4] Enable Windows Update service"
        Write-Host ""
        Write-Host "  Update:" -ForegroundColor Gray
        Write-Host "  [5] Check for updates (Settings)"
        Write-Host "  [6] Install updates via PowerShell"
        Write-Host "  [7] Run WUpdater GUI (AIO tool)"
        Write-Host "  [8] Update drivers via Windows Update"
        Write-Host ""
        Write-Host "  [0] Back"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
        "1" {
            Write-Log "Pausing Windows Updates for 35 days..."
            $pause = (Get-Date).AddDays(35).ToString("yyyy-MM-dd")
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesExpiryTime" -Value $pause -Force
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesStartTime" -Value (Get-Date).ToString("yyyy-MM-dd") -Force
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesEndTime" -Value $pause -Force
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesStartTime" -Value (Get-Date).ToString("yyyy-MM-dd") -Force
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesEndTime" -Value $pause -Force
            Write-Log "Updates paused until $pause" "SUCCESS"
        }
        "2" {
            # AIO method - pause with scheduled task to auto-resume
            Set-UpdatePauseTask
        }
        "3" {
            Write-Log "Disabling Windows Update service..."
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Windows Update service disabled" "SUCCESS"
        }
        "4" {
            Write-Log "Enabling Windows Update service..."
            Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            Write-Log "Windows Update service enabled" "SUCCESS"
        }
        "5" {
            Write-Log "Opening Windows Update settings..."
            Start-Process "ms-settings:windowsupdate-action"
            Write-Log "Windows Update settings opened" "SUCCESS"
        }
        "6" {
            Install-WindowsUpdates
        }
        "7" {
            # AIO WUpdater GUI tool
            Start-WUpdater
        }
        "8" {
            Update-DriversViaWindowsUpdate
        }
        "0" { return }
        default { Write-Host "Invalid option" -ForegroundColor Red }
        }

        if ($choice -ne "0") {
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } while ($true)
}

function Set-UpdatePauseTask {
    Write-Log "SETTING UPDATE PAUSE SCHEDULED TASK" "SECTION"

    Write-Host ""
    Write-Host "This will:" -ForegroundColor Yellow
    Write-Host "  1. Stop and disable Windows Update service now"
    Write-Host "  2. Create a scheduled task to re-enable it after X days"
    Write-Host ""

    $days = Read-Host "Enter number of days to pause updates"

    if (-not [int]::TryParse($days, [ref]$null) -or [int]$days -lt 1) {
        Write-Log "Invalid number of days" "ERROR"
        return
    }

    try {
        # Stop and disable Windows Update
        Write-Log "Stopping Windows Update service..."
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "Windows Update service disabled" "SUCCESS"

        # Calculate resume date
        $resumeDate = (Get-Date).AddDays([int]$days)
        Write-Log "Updates will resume on: $($resumeDate.ToString('yyyy-MM-dd HH:mm'))"

        # Remove existing task if present
        Unregister-ScheduledTask -TaskName "PauseWinUpdates" -Confirm:$false -ErrorAction SilentlyContinue

        # Create scheduled task to re-enable updates
        $action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument '-NoProfile -WindowStyle Hidden -Command "Set-Service wuauserv -StartupType Manual; Start-Service wuauserv"'
        $trigger = New-ScheduledTaskTrigger -At $resumeDate -Once

        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "PauseWinUpdates" -Description "Re-enables Windows Update after pause period" -RunLevel Highest -Force | Out-Null

        Write-Log "Scheduled task created: PauseWinUpdates" "SUCCESS"
        Write-Host ""
        Write-Host "Windows Update is now paused for $days days." -ForegroundColor Green
        Write-Host "It will automatically resume on $($resumeDate.ToString('yyyy-MM-dd'))." -ForegroundColor Green
    } catch {
        Write-Log "Error: $_" "ERROR"
    }
}

function Start-WUpdater {
    Write-Log "LAUNCHING WUPDATER" "SECTION"

    $BaseDir = "C:\System_Optimizer\WUpdater"
    if (-not (Test-Path $BaseDir)) { New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null }

    $exePath = "$BaseDir\WUpdater.exe"

    try {
        Write-Log "Downloading WUpdater..."
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/tools/WUpdater.exe" -OutFile $exePath -UseBasicParsing
        Write-Log "Downloaded WUpdater" "SUCCESS"

        Write-Log "Launching WUpdater..."
        Start-Process -FilePath $exePath
        Write-Log "WUpdater launched" "SUCCESS"
    } catch {
        Write-Log "Error: $_" "ERROR"
        Write-Host "Manual download: https://github.com/coff33ninja/System_Optimizer/tree/main/tools" -ForegroundColor Cyan
    }
}

function Install-WindowsUpdates {
    Set-ConsoleSize
    Clear-Host
    Write-Log "INSTALLING WINDOWS UPDATES VIA POWERSHELL" "SECTION"

    # Check if PSWindowsUpdate module is installed
    $module = Get-Module -ListAvailable -Name PSWindowsUpdate
    if (-not $module) {
        Write-Log "Installing PSWindowsUpdate module..."
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue | Out-Null
            Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope CurrentUser
            Write-Log "PSWindowsUpdate module installed" "SUCCESS"
        } catch {
            Write-Log "Failed to install PSWindowsUpdate module: $_" "ERROR"
            Write-Host "Alternative: Run 'Install-Module PSWindowsUpdate' manually" -ForegroundColor Yellow
            return
        }
    }

    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Update Options:" -ForegroundColor Cyan
    Write-Host "  [1] List available updates"
    Write-Host "  [2] Install all updates (no reboot)"
    Write-Host "  [3] Install all updates (auto reboot)"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Write-Log "Checking for available updates..."
            Get-WindowsUpdate -MicrosoftUpdate -Verbose
        }
        "2" {
            Write-Log "Installing all updates (no reboot)..."
            Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -IgnoreReboot
            Write-Log "Updates installed" "SUCCESS"
        }
        "3" {
            Write-Log "Installing all updates (will reboot if needed)..."
            Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -AutoReboot
            Write-Log "Updates installed" "SUCCESS"
        }
        "0" { Write-Log "Cancelled" "INFO" }
    }
}

function Update-DriversViaWindowsUpdate {
    Set-ConsoleSize
    Clear-Host
    Write-Log "UPDATING DRIVERS VIA WINDOWS UPDATE" "SECTION"

    # Check if PSWindowsUpdate module is installed
    $module = Get-Module -ListAvailable -Name PSWindowsUpdate
    if (-not $module) {
        Write-Log "Installing PSWindowsUpdate module..."
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue | Out-Null
            Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope CurrentUser
            Write-Log "PSWindowsUpdate module installed" "SUCCESS"
        } catch {
            Write-Log "Failed to install PSWindowsUpdate module: $_" "ERROR"
            return
        }
    }

    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Driver Update Options:" -ForegroundColor Cyan
    Write-Host "  [1] List available driver updates"
    Write-Host "  [2] Install all driver updates"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Write-Log "Checking for driver updates..."
            Get-WindowsUpdate -MicrosoftUpdate -Category "Drivers" -Verbose
        }
        "2" {
            Write-Log "Installing driver updates..."
            Get-WindowsUpdate -MicrosoftUpdate -Category "Drivers" -AcceptAll -Install -IgnoreReboot
            Write-Log "Driver updates installed" "SUCCESS"
            Write-Host "A reboot may be required." -ForegroundColor Yellow
        }
        "0" { Write-Log "Cancelled" "INFO" }
    }
}

function Repair-WindowsUpdate {
    Set-ConsoleSize
    Clear-Host
    Write-Log "REPAIRING WINDOWS UPDATE" "SECTION"

    Write-Host ""
    Write-Host "Windows Update Repair Options:" -ForegroundColor Cyan
    Write-Host "  [1] Quick repair (stop services, clear cache, restart)"
    Write-Host "  [2] Full repair (re-register DLLs, reset components)"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            try {
                Write-Log "Performing quick Windows Update repair..."

                # Stop services
                Write-Log "Stopping Windows Update services..."
                Stop-Service -Name BITS -Force -ErrorAction SilentlyContinue
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue

                # Clear download cache
                Write-Log "Clearing Windows Update cache..."
                Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue

                # Start services
                Write-Log "Starting Windows Update services..."
                Start-Service -Name cryptsvc -ErrorAction SilentlyContinue
                Start-Service -Name BITS -ErrorAction SilentlyContinue
                Start-Service -Name wuauserv -ErrorAction SilentlyContinue

                # Force detection
                Write-Log "Forcing update detection..."
                wuauclt /resetauthorization /detectnow 2>$null

                Write-Log "Quick repair completed" "SUCCESS"
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "2" {
            try {
                Write-Log "Performing full Windows Update repair (this may take a while)..."

                # Stop services
                Write-Log "Stopping Windows Update services..."
                Stop-Service -Name BITS -Force -ErrorAction SilentlyContinue
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                Stop-Service -Name appidsvc -Force -ErrorAction SilentlyContinue
                Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue

                # Remove QMGR data files
                Write-Log "Removing BITS job files..."
                Remove-Item "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -Force -ErrorAction SilentlyContinue

                # Rename folders
                Write-Log "Renaming Windows Update folders..."
                if (Test-Path "$env:SystemRoot\SoftwareDistribution\DataStore") {
                    Rename-Item "$env:SystemRoot\SoftwareDistribution\DataStore" "DataStore.bak" -Force -ErrorAction SilentlyContinue
                }
                if (Test-Path "$env:SystemRoot\SoftwareDistribution\Download") {
                    Rename-Item "$env:SystemRoot\SoftwareDistribution\Download" "Download.bak" -Force -ErrorAction SilentlyContinue
                }
                if (Test-Path "$env:SystemRoot\System32\catroot2") {
                    Rename-Item "$env:SystemRoot\System32\catroot2" "catroot2.bak" -Force -ErrorAction SilentlyContinue
                }

                # Re-register DLLs
                Write-Log "Re-registering Windows Update DLLs..."
                $DLLs = @(
                    "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
                    "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll",
                    "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll",
                    "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll",
                    "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", "wuapi.dll",
                    "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll",
                    "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll", "wuwebv.dll"
                )

                $oldLocation = Get-Location
                Set-Location "$env:SystemRoot\System32"
                foreach ($dll in $DLLs) {
                    regsvr32.exe /s $dll 2>$null
                }
                Set-Location $oldLocation
                Write-Log "DLLs re-registered" "SUCCESS"

                # Reset WinSock
                Write-Log "Resetting WinSock..."
                netsh winsock reset | Out-Null
                netsh winhttp reset proxy | Out-Null

                # Delete BITS jobs
                Write-Log "Clearing BITS jobs..."
                Get-BitsTransfer -AllUsers -ErrorAction SilentlyContinue | Remove-BitsTransfer -ErrorAction SilentlyContinue

                # Start services
                Write-Log "Starting Windows Update services..."
                Start-Service -Name cryptsvc -ErrorAction SilentlyContinue
                Start-Service -Name appidsvc -ErrorAction SilentlyContinue
                Start-Service -Name BITS -ErrorAction SilentlyContinue
                Start-Service -Name wuauserv -ErrorAction SilentlyContinue

                # Force detection
                Write-Log "Forcing update detection..."
                wuauclt /resetauthorization /detectnow 2>$null
                try {
                    (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
                } catch { }

                Write-Log "Full repair completed" "SUCCESS"
                Write-Host ""
                Write-Host "Please reboot your computer." -ForegroundColor Yellow
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Set-WindowsUpdateControl',
    'Set-UpdatePauseTask',
    'Start-WUpdater',
    'Install-WindowsUpdates',
    'Update-DriversViaWindowsUpdate',
    'Repair-WindowsUpdate'
)
