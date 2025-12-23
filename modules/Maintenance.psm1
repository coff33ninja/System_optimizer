# ============================================================================
# Maintenance Module - System Optimizer
# ============================================================================

function Start-SystemMaintenance {
    Write-Log "RUNNING SYSTEM MAINTENANCE" "SECTION"

    # DISM Health Check
    Write-Log "Running DISM RestoreHealth (this may take a while)..."
    $dismResult = DISM /Online /Cleanup-Image /RestoreHealth 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "DISM RestoreHealth completed successfully" "SUCCESS"
    } else {
        Write-Log "DISM RestoreHealth completed with warnings" "WARNING"
    }

    # SFC Scan
    Write-Log "Running SFC /scannow (this may take a while)..."
    $sfcResult = sfc /scannow 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "SFC scan completed successfully" "SUCCESS"
    } else {
        Write-Log "SFC scan completed with warnings" "WARNING"
    }

    # Clear Temp Files
    Write-Log "Clearing temporary files..."
    $tempPaths = @(
        "$env:TEMP\*"
        "$env:WINDIR\Temp\*"
        "$env:WINDIR\Prefetch\*"
    )

    foreach ($path in $tempPaths) {
        Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
    }
    Write-Log "Temporary files cleared" "SUCCESS"

    # Clear Windows Update Cache
    Write-Log "Clearing Windows Update cache..."
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Force -Recurse -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Write-Log "Windows Update cache cleared" "SUCCESS"

    Write-Log "System maintenance completed" "SUCCESS"
}

function Start-DiskCleanup {
    Set-ConsoleSize
    Clear-Host
    Write-Log "DISK CLEANUP" "SECTION"

    Write-Host ""
    Write-Host "Disk Cleanup Options:" -ForegroundColor Cyan
    Write-Host "  [1] Quick cleanup (temp files only)"
    Write-Host "  [2] Full cleanup (Windows Update, logs, etc.)"
    Write-Host "  [3] Launch Disk Cleanup GUI"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Write-Log "Running quick cleanup..."

            # Clear temp folders
            $tempPaths = @(
                "$env:TEMP\*"
                "$env:WINDIR\Temp\*"
                "$env:WINDIR\Prefetch\*"
                "$env:LOCALAPPDATA\Temp\*"
            )

            foreach ($path in $tempPaths) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
            }

            Write-Log "Quick cleanup completed" "SUCCESS"
        }
        "2" {
            Write-Log "Running full cleanup..."

            # Clear temp folders
            $tempPaths = @(
                "$env:TEMP\*"
                "$env:WINDIR\Temp\*"
                "$env:WINDIR\Prefetch\*"
                "$env:LOCALAPPDATA\Temp\*"
            )

            foreach ($path in $tempPaths) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
            }
            Write-Log "Temp files cleared" "SUCCESS"

            # Clear Windows Update cache
            Write-Log "Clearing Windows Update cache..."
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Force -Recurse -ErrorAction SilentlyContinue
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            Write-Log "Windows Update cache cleared" "SUCCESS"

            # Clear Windows logs
            Write-Log "Clearing Windows logs..."
            wevtutil cl Application 2>$null
            wevtutil cl System 2>$null
            wevtutil cl Security 2>$null
            Write-Log "Windows logs cleared" "SUCCESS"

            # Clear thumbnail cache
            Write-Log "Clearing thumbnail cache..."
            Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
            Write-Log "Thumbnail cache cleared" "SUCCESS"

            Write-Log "Full cleanup completed" "SUCCESS"
        }
        "3" {
            Write-Log "Launching Disk Cleanup GUI..."
            Start-Process cleanmgr.exe
            Write-Log "Disk Cleanup GUI launched" "SUCCESS"
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Reset-GroupPolicy {
    Write-Log "RESETTING GROUP POLICY" "SECTION"

    Write-Host ""
    Write-Host "This will reset all local Group Policy settings to defaults." -ForegroundColor Yellow
    Write-Host "This includes registry policy keys and Group Policy folders." -ForegroundColor Yellow
    Write-Host "This can fix issues caused by corrupted policies." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Continue? (Y/N)"

    if ($confirm -eq "Y" -or $confirm -eq "y") {
        try {
            # Delete policy registry keys (like NexTool does)
            Write-Log "Removing policy registry keys..."
            $regPaths = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies"
                "HKCU:\Software\Microsoft\WindowsSelfHost"
                "HKCU:\Software\Policies"
                "HKLM:\Software\Microsoft\Policies"
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies"
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate"
                "HKLM:\Software\Microsoft\WindowsSelfHost"
                "HKLM:\Software\Policies"
                "HKLM:\Software\WOW6432Node\Microsoft\Policies"
                "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies"
                "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate"
            )

            foreach ($path in $regPaths) {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Removed: $path" "SUCCESS"
                }
            }

            # Remove Group Policy folders
            Write-Log "Removing Group Policy folders..."
            Remove-Item -Path "$env:WinDir\System32\GroupPolicyUsers" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:WinDir\System32\GroupPolicy" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Group Policy folders removed" "SUCCESS"

            # Update Group Policy
            Write-Log "Updating Group Policy..."
            gpupdate /force | Out-Null
            Write-Log "Group Policy reset completed" "SUCCESS"

            Write-Host ""
            Write-Host "A reboot is recommended to complete the reset." -ForegroundColor Yellow
        } catch {
            Write-Log "Error: $_" "ERROR"
        }
    } else {
        Write-Log "Cancelled" "INFO"
    }
}

function Reset-WMI {
    Set-ConsoleSize
    Clear-Host
    Write-Log "RESETTING WMI REPOSITORY" "SECTION"

    Write-Host ""
    Write-Host "This will reset the WMI repository." -ForegroundColor Yellow
    Write-Host "This can fix WMI-related errors and issues." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  [1] Quick reset (salvage + reset)"
    Write-Host "  [2] Full reset (re-register all components)"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            try {
                Write-Log "Attempting WMI salvage..."
                $salvageResult = winmgmt /salvagerepository 2>&1

                if ($salvageResult -match "failed|error") {
                    Write-Log "Salvage failed, trying reset..." "WARNING"
                    winmgmt /resetrepository 2>&1 | Out-Null
                }

                Write-Log "WMI quick reset completed" "SUCCESS"
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "2" {
            try {
                Write-Log "Performing full WMI reset (this may take a while)..."

                # Stop WMI service
                Write-Log "Stopping WMI service..."
                sc.exe config winmgmt start= disabled | Out-Null
                net stop winmgmt /y 2>&1 | Out-Null

                # Re-register DLLs
                Write-Log "Re-registering system DLLs..."
                regsvr32 /s "$env:SystemRoot\system32\scecli.dll" 2>&1 | Out-Null
                regsvr32 /s "$env:SystemRoot\system32\userenv.dll" 2>&1 | Out-Null

                # Remove and rebuild repository
                Write-Log "Removing WMI repository..."
                $wbemPath = "$env:SystemRoot\System32\wbem"
                if (Test-Path "$wbemPath\repository") {
                    Remove-Item -Path "$wbemPath\repository" -Recurse -Force -ErrorAction SilentlyContinue
                }

                # Re-register MOF files
                Write-Log "Re-registering MOF files..."
                $mofFiles = Get-ChildItem -Path $wbemPath -Filter "*.mof" -ErrorAction SilentlyContinue
                foreach ($mof in $mofFiles) {
                    mofcomp $mof.FullName 2>&1 | Out-Null
                }

                # Re-register MFL files
                $mflFiles = Get-ChildItem -Path $wbemPath -Filter "*.mfl" -ErrorAction SilentlyContinue
                foreach ($mfl in $mflFiles) {
                    mofcomp $mfl.FullName 2>&1 | Out-Null
                }

                # Re-register WMI providers
                Write-Log "Re-registering WMI providers..."
                wmiprvse /regserver 2>&1 | Out-Null
                winmgmt /regserver 2>&1 | Out-Null

                # Re-enable and start WMI service
                Write-Log "Starting WMI service..."
                sc.exe config winmgmt start= auto | Out-Null
                net start winmgmt 2>&1 | Out-Null

                # Final reset
                winmgmt /resetrepository 2>&1 | Out-Null

                Write-Log "Full WMI reset completed" "SUCCESS"
                Write-Host "A reboot is recommended." -ForegroundColor Yellow
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
    'Start-SystemMaintenance',
    'Start-DiskCleanup',
    'Reset-GroupPolicy',
    'Reset-WMI'
)
