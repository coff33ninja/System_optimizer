# ============================================================================
# Maintenance Module - System Optimizer
# ============================================================================

function Start-SystemMaintenance {
    Write-Log "RUNNING SYSTEM MAINTENANCE" "SECTION"

    # DISM Health Check
    Write-Log "Running DISM RestoreHealth (this may take a while)..."
    $dismOutput = DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
    $dismExitCode = $LASTEXITCODE
    if ($dismExitCode -eq 0) {
        Write-Log "DISM RestoreHealth completed successfully" "SUCCESS"
    } else {
        Write-Log "DISM RestoreHealth completed with warnings (Exit Code: $dismExitCode)" "WARNING"
        Write-Log "DISM Output: $dismOutput" "DEBUG"
    }

    # SFC Scan
    Write-Log "Running SFC /scannow (this may take a while)..."
    $sfcOutput = sfc /scannow 2>&1 | Out-String
    $sfcExitCode = $LASTEXITCODE
    if ($sfcExitCode -eq 0) {
        Write-Log "SFC scan completed successfully" "SUCCESS"
    } else {
        Write-Log "SFC scan completed with warnings (Exit Code: $sfcExitCode)" "WARNING"
        Write-Log "SFC Output: $sfcOutput" "DEBUG"
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

function Get-DiskSpaceInfo {
    <#
    .SYNOPSIS
        Get current disk space information for all drives
    #>
    $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    $results = @()
    foreach ($drive in $drives) {
        $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $totalGB = [math]::Round($drive.Size / 1GB, 2)
        $usedGB = $totalGB - $freeGB
        $percentFree = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
        $results += [PSCustomObject]@{
            Drive = $drive.DeviceID
            FreeGB = $freeGB
            TotalGB = $totalGB
            UsedGB = $usedGB
            PercentFree = $percentFree
        }
    }
    return $results
}

function Show-DiskSpaceReport {
    <#
    .SYNOPSIS
        Display formatted disk space report
    #>
    param([string]$Title = "Current Disk Space")
    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "  $('-' * 50)" -ForegroundColor Gray
    $drives = Get-DiskSpaceInfo
    foreach ($drive in $drives) {
        $color = if ($drive.PercentFree -lt 10) { 'Red' } elseif ($drive.PercentFree -lt 20) { 'Yellow' } else { 'Green' }
        Write-Host "  $($drive.Drive) " -NoNewline
        Write-Host "$($drive.FreeGB) GB free" -ForegroundColor $color -NoNewline
        Write-Host " / $($drive.TotalGB) GB total ($($drive.PercentFree)% free)" -ForegroundColor Gray
    }
    Write-Host ""
}

function Get-CleanupTargetSize {
    <#
    .SYNOPSIS
        Calculate size of files in a cleanup target
    #>
    param([string]$Path, [int]$MaxAgeDays = 0)
    try {
        if (-not (Test-Path $Path)) { return 0 }
        $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
        if ($MaxAgeDays -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)
            $files = $files | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        }
        return ($files | Measure-Object -Property Length -Sum).Sum
    } catch {
        return 0
    }
}

function Remove-FilesSafely {
    <#
    .SYNOPSIS
        Safely remove files with age check and error handling
    #>
    param(
        [string]$Path,
        [int]$MaxAgeDays = 0,
        [switch]$Recurse
    )
    try {
        if (-not (Test-Path $Path)) { return 0 }
        $params = @{
            Path = $Path
            Force = $true
            ErrorAction = 'SilentlyContinue'
        }
        if ($Recurse) { $params['Recurse'] = $true }
        if ($MaxAgeDays -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)
            Get-ChildItem @params | Where-Object { $_.LastWriteTime -lt $cutoffDate -and -not $_.IsReadOnly } | Remove-Item -Force -ErrorAction SilentlyContinue
        } else {
            Remove-Item @params
        }
        return (Get-CleanupTargetSize -Path $Path)
    } catch {
        return 0
    }
}

function Start-DiskCleanup {
    Set-ConsoleSize
    Clear-Host
    Write-Log "DISK CLEANUP" "SECTION"

    # Show initial disk space
    Show-DiskSpaceReport -Title "Disk Space Before Cleanup"

    Write-Host "  Disk Cleanup Options:" -ForegroundColor Cyan
    Write-Host "  [1] Quick cleanup (temp files, 7+ days old)"
    Write-Host "  [2] Full cleanup (includes Windows Update, logs)"
    Write-Host "  [3] Super Aggressive (browser caches, all temps)"
    Write-Host "  [4] Preview only (see what would be deleted)"
    Write-Host "  [5] Launch Disk Cleanup GUI"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "0" { Write-Log "Cancelled" "INFO"; return }
        "5" { Start-Process cleanmgr.exe; Write-Log "Disk Cleanup GUI launched" "SUCCESS"; return }
        "1" { $fullMode = $false; $aggressiveMode = $false; $previewMode = $false }
        "2" { $fullMode = $true; $aggressiveMode = $false; $previewMode = $false }
        "3" { $fullMode = $true; $aggressiveMode = $true; $previewMode = $false }
        "4" { $fullMode = $true; $aggressiveMode = $true; $previewMode = $true }
        default { Write-Host "Invalid option" -ForegroundColor Red; return }
    }

    if ($previewMode) {
        Write-Log "PREVIEW MODE - Analyzing cleanup targets..." "SECTION"
    } else {
        Write-Log "Starting cleanup..." "SECTION"
    }

    $totalFreed = 0

    # Define cleanup targets
    $cleanupTargets = @(
        @{ Name = "Windows Temp"; Path = "$env:WINDIR\Temp\*"; Age = 7; Recurse = $true },
        @{ Name = "User Temp"; Path = "$env:TEMP\*"; Age = 7; Recurse = $true },
        @{ Name = "Local AppData Temp"; Path = "$env:LOCALAPPDATA\Temp\*"; Age = 7; Recurse = $true },
        @{ Name = "Prefetch"; Path = "$env:WINDIR\Prefetch\*"; Age = 14; Recurse = $false }
    )

    if ($fullMode -or $aggressiveMode) {
        $cleanupTargets += @(
            @{ Name = "Windows Update Cache"; Path = "$env:WINDIR\SoftwareDistribution\Download\*"; Age = 0; Recurse = $true; Service = "wuauserv" },
            @{ Name = "Thumbnail Cache"; Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"; Age = 0; Recurse = $false },
            @{ Name = "Windows Logs"; Path = "$env:WINDIR\Logs\*"; Age = 7; Recurse = $true },
            @{ Name = "CBS Logs"; Path = "$env:WINDIR\Logs\CBS\*"; Age = 7; Recurse = $true },
            @{ Name = "DISM Logs"; Path = "$env:WINDIR\Logs\DISM\*"; Age = 7; Recurse = $true }
        )
    }

    if ($aggressiveMode) {
        $cleanupTargets += @(
            @{ Name = "Chrome Cache"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache\*"; Age = 0; Recurse = $true },
            @{ Name = "Chrome Code Cache"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Code Cache\*"; Age = 0; Recurse = $true },
            @{ Name = "Edge Cache"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache\*"; Age = 0; Recurse = $true },
            @{ Name = "Edge Code Cache"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Code Cache\*"; Age = 0; Recurse = $true },
            @{ Name = "Firefox Cache"; Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2\*"; Age = 0; Recurse = $true },
            @{ Name = "IE/Edge Temp"; Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"; Age = 0; Recurse = $true },
            @{ Name = "Crash Dumps"; Path = "$env:LOCALAPPDATA\CrashDumps\*"; Age = 7; Recurse = $true },
            @{ Name = "WER Reports"; Path = "$env:LOCALAPPDATA\Microsoft\Windows\WER\*"; Age = 30; Recurse = $true }
        )
    }

    # Process each target
    foreach ($target in $cleanupTargets) {
        Write-Host "  Processing: $($target.Name)..." -NoNewline -ForegroundColor Gray
        $sizeBefore = Get-CleanupTargetSize -Path $target.Path

        if ($sizeBefore -gt 0) {
            if (-not $previewMode) {
                # Stop service if needed
                if ($target.Service) {
                    Stop-Service -Name $target.Service -Force -ErrorAction SilentlyContinue | Out-Null
                }

                # Remove files
                $params = @{
                    Path = $target.Path
                    MaxAgeDays = $target.Age
                }
                if ($target.Recurse) { $params['Recurse'] = $true }
                Remove-FilesSafely @params | Out-Null

                # Start service if needed
                if ($target.Service) {
                    Start-Service -Name $target.Service -ErrorAction SilentlyContinue | Out-Null
                }
            }

            $sizeFreed = if ($previewMode) { $sizeBefore } else {
                $sizeAfter = Get-CleanupTargetSize -Path $target.Path
                [math]::Max(0, $sizeBefore - $sizeAfter)
            }
            $totalFreed += $sizeFreed

            if ($sizeFreed -gt 0) {
                $sizeDisplay = if ($sizeFreed -gt 1GB) { "{0:N2} GB" -f ($sizeFreed / 1GB) } else { "{0:N2} MB" -f ($sizeFreed / 1MB) }
                Write-Host " $($sizeDisplay)" -ForegroundColor Green
            } else {
                Write-Host " 0 MB" -ForegroundColor DarkGray
            }
        } else {
            Write-Host " 0 MB" -ForegroundColor DarkGray
        }
    }

    # Component Store cleanup (Full/Aggressive only)
    if ($fullMode -or $aggressiveMode) {
        Write-Host "  Processing: Component Store (DISM)..." -NoNewline -ForegroundColor Gray
        if (-not $previewMode) {
            $dismResult = dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1
            if ($dismResult -match "The operation completed successfully") {
                Write-Host " Cleaned" -ForegroundColor Green
            } else {
                Write-Host " No action needed" -ForegroundColor DarkGray
            }
        } else {
            Write-Host " (requires execution)" -ForegroundColor Yellow
        }
    }

    # Clear Event Logs (Full/Aggressive only)
    if ($fullMode -or $aggressiveMode) {
        Write-Host "  Processing: Event Logs..." -NoNewline -ForegroundColor Gray
        if (-not $previewMode) {
            wevtutil el | ForEach-Object { wevtutil cl "$($_)" 2>$null | Out-Null }
            Write-Host " Cleared" -ForegroundColor Green
        } else {
            Write-Host " (requires execution)" -ForegroundColor Yellow
        }
    }

    # Recycle Bin (optional)
    if ($aggressiveMode -and -not $previewMode) {
        Write-Host "  Processing: Recycle Bin..." -NoNewline -ForegroundColor Gray
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Host " Emptied" -ForegroundColor Green
    }

    Write-Host ""

    # Show results
    if ($previewMode) {
        $totalDisplay = if ($totalFreed -gt 1GB) { "{0:N2} GB" -f ($totalFreed / 1GB) } else { "{0:N2} MB" -f ($totalFreed / 1MB) }
        Write-Log "Preview complete. Estimated recoverable: $totalDisplay" "WARNING"
        Write-Host "  Run 'Full' or 'Super Aggressive' cleanup to actually delete these files." -ForegroundColor Yellow
    } else {
        $totalDisplay = if ($totalFreed -gt 1GB) { "{0:N2} GB" -f ($totalFreed / 1GB) } else { "{0:N2} MB" -f ($totalFreed / 1MB) }
        Write-Log "Cleanup completed! Space freed: $totalDisplay" "SUCCESS"

        # Show after disk space
        Show-DiskSpaceReport -Title "Disk Space After Cleanup"
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
    'Get-DiskSpaceInfo',
    'Show-DiskSpaceReport',
    'Reset-GroupPolicy',
    'Reset-WMI'
)
