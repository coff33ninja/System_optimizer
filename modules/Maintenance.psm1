# ============================================================================
# Maintenance Module - System Optimizer
# ============================================================================
# This module provides comprehensive system maintenance and repair tools.
#
# Exported Functions:
#   Start-SystemMaintenance    - Automated maintenance (DISM, SFC, cleanup)
#   Start-DiskCleanup          - Advanced disk cleanup with multiple modes
#   Get-DiskSpaceInfo          - Get drive space information
#   Show-DiskSpaceReport       - Display formatted disk space report
#   Reset-GroupPolicy          - Reset Group Policy to defaults
#   Reset-WMI                  - Repair Windows Management Instrumentation
#   Start-CheckDisk            - Run chkdsk with options
#   Start-SystemRestore        - System restore point management
#   Start-BCDRepair            - Boot configuration repair
#   Start-MemoryDiagnostic     - Memory test scheduling
#   Get-DriveHealth            - SMART drive health check
#   Start-WindowsUpdateRepair  - Fix Windows Update issues
#   Start-DISMRepair           - DISM image repair tools
#   Start-DriveOptimization    - Defrag/TRIM optimization
#   Start-TimeSyncRepair       - Fix time synchronization
#   Start-SearchIndexRebuild   - Rebuild Windows Search index
#   Start-StartupProgramManager - Manage startup programs
#   Start-MaintenanceMenu      - Interactive maintenance menu (main entry)
#
# Menu Structure:
#   [1]  Run Automated Maintenance (DISM, SFC, Cleanup)
#   [2]  Disk Cleanup
#   [3]  Disk Space Report
#   [4]  Drive Optimization (Defrag/TRIM)
#   [5]  Check Disk (chkdsk)
#   [6]  System Restore
#   [7]  BCD/Boot Repair
#   [8]  Memory Diagnostic
#   [9]  Drive Health (SMART)
#   [10] Windows Update Repair
#   [11] DISM Repair Tools
#   [12] Time Sync Repair
#   [13] Search Index Rebuild
#   [14] Startup Program Manager
#   [15] Reset Group Policy
#   [16] Reset WMI
#
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

function Start-CheckDisk {
    <#
    .SYNOPSIS
        Check disk for errors and schedule chkdsk if needed
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "CHECK DISK (CHKDSK)" "SECTION"

    Write-Host ""
    Write-Host "  This tool checks drives for file system errors and bad sectors." -ForegroundColor Cyan
    Write-Host ""

    # Get all fixed drives
    $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID, VolumeName, Size, FreeSpace

    Write-Host "  Available drives:" -ForegroundColor Gray
    $i = 1
    $driveMap = @{}
    foreach ($drive in $drives) {
        $sizeGB = [math]::Round($drive.Size / 1GB, 2)
        $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $label = if ($drive.VolumeName) { " ($($drive.VolumeName))" } else { "" }
        Write-Host "  [$i] $($drive.DeviceID) $label - $freeGB GB free / $sizeGB GB total"
        $driveMap[$i] = $drive.DeviceID
        $i++
    }
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "  Select drive"
    if ($choice -eq "0") { Write-Log "Cancelled" "INFO"; return }

    $selectedDrive = $driveMap[[int]$choice]
    if (-not $selectedDrive) { Write-Host "Invalid selection" -ForegroundColor Red; return }

    Write-Host ""
    Write-Host "  Options for $selectedDrive" -ForegroundColor Cyan
    Write-Host "  [1] Check only (read-only, no fixes)"
    Write-Host "  [2] Check and fix errors (schedules if drive in use)"
    Write-Host "  [3] Check, fix, and scan for bad sectors (slow)"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $scanChoice = Read-Host "  Select option"

    switch ($scanChoice) {
        "1" {
            Write-Log "Running read-only check on $selectedDrive..."
            chkdsk $selectedDrive
        }
        "2" {
            Write-Log "Scheduling chkdsk with fix on $selectedDrive..."
            $result = chkdsk $selectedDrive /F 2>&1
            if ($result -match "cannot run because the volume is in use" -or $result -match "Would you like to schedule this volume to be checked") {
                Write-Host "  Drive is in use. Schedule check on next restart? (Y/N)" -ForegroundColor Yellow
                $schedule = Read-Host
                if ($schedule -eq "Y" -or $schedule -eq "y") {
                    Write-Output "Y" | chkdsk $selectedDrive /F | Out-Null
                    Write-Log "Scheduled chkdsk on next reboot" "SUCCESS"
                }
            } else {
                Write-Log "Check completed" "SUCCESS"
            }
        }
        "3" {
            Write-Log "Scheduling thorough check with bad sector scan on $selectedDrive..."
            Write-Host "  WARNING: This may take several hours on large drives!" -ForegroundColor Red
            $confirm = Read-Host "  Continue? (Y/N)"
            if ($confirm -eq "Y" -or $confirm -eq "y") {
                $result = chkdsk $selectedDrive /F /R 2>&1
                if ($result -match "cannot run because the volume is in use") {
                    Write-Host "  Schedule on next restart? (Y/N)" -ForegroundColor Yellow
                    $schedule = Read-Host
                    if ($schedule -eq "Y" -or $schedule -eq "y") {
                        Write-Output "Y" | chkdsk $selectedDrive /F /R | Out-Null
                        Write-Log "Scheduled thorough check on next reboot" "SUCCESS"
                    }
                }
            }
        }
        "0" { Write-Log "Cancelled" "INFO"; return }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-SystemRestore {
    <#
    .SYNOPSIS
        Manage System Restore points
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "SYSTEM RESTORE MANAGEMENT" "SECTION"

    Write-Host ""
    Write-Host "  [1] Create new restore point"
    Write-Host "  [2] List available restore points"
    Write-Host "  [3] Clean old restore points"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Creating restore point..."
            try {
                Checkpoint-Computer -Description "System Optimizer - Manual Restore Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
                Write-Log "Restore point created successfully" "SUCCESS"
            } catch {
                Write-Log "Failed to create restore point: $_" "ERROR"
            }
        }
        "2" {
            Write-Log "Available restore points:" "SECTION"
            $restorePoints = Get-ComputerRestorePoint | Sort-Object ConvertToDateTime -Descending | Select-Object -First 10
            if ($restorePoints) {
                foreach ($rp in $restorePoints) {
                    $date = $rp.ConvertToDateTime($rp.CreationTime)
                    Write-Host "  [$($rp.SequenceNumber)] $date - $($rp.Description)" -ForegroundColor Gray
                }
            } else {
                Write-Host "  No restore points found" -ForegroundColor Yellow
            }
        }
        "3" {
            Write-Log "Cleaning old restore points..."
            Write-Host "  This will keep only the most recent restore point." -ForegroundColor Yellow
            $confirm = Read-Host "  Continue? (Y/N)"
            if ($confirm -eq "Y" -or $confirm -eq "y") {
                try {
                    vssadmin delete shadows /all /quiet 2>&1 | Out-Null
                    Write-Log "Old restore points cleaned" "SUCCESS"
                } catch {
                    Write-Log "Could not clean restore points: $_" "WARNING"
                }
            }
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-BCDRepair {
    <#
    .SYNOPSIS
        Comprehensive Boot Configuration Data repair for UEFI and BIOS systems
        Supports repairing external drives with Windows installations
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "BCD AND BOOT REPAIR" "SECTION"

    # Detect current boot mode
    $firmwareType = if (Test-Path "$env:SystemRoot\Panther\setupact.log") {
        $setupLog = Get-Content "$env:SystemRoot\Panther\setupact.log" -ErrorAction SilentlyContinue | Select-String "Detected boot environment"
        if ($setupLog -match "UEFI") { "UEFI" } else { "BIOS" }
    } else {
        # Alternative detection
        if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State") { "UEFI" } else { "BIOS" }
    }

    Write-Host ""
    Write-Host "  Current system boot mode: $firmwareType" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  WARNING: These operations modify system boot files!" -ForegroundColor Red
    Write-Host "  Only use if you're experiencing boot problems." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Auto-repair current system BCD"
    Write-Host "  [2] Repair external/offline Windows drive"
    Write-Host "  [3] Rebuild BCD from scratch (advanced)"
    Write-Host "  [4] Fix boot records (MBR for BIOS / EFI for UEFI)"
    Write-Host "  [5] Reinstall UEFI bootloader files"
    Write-Host "  [6] Scan and add Windows installations to BCD"
    Write-Host "  [7] Set active partition (BIOS only)"
    Write-Host "  [8] Assign drive letters to system partitions"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Auto-repairing BCD..." "SECTION"

            # Method 1: Automatic BCD rebuild
            Write-Host "  Method 1: Rebuilding BCD automatically..." -ForegroundColor Yellow
            bootrec /rebuildbcd

            # Method 2: Fix boot records based on firmware type
            if ($firmwareType -eq "UEFI") {
                Write-Host "  Method 2: Repairing UEFI boot files..." -ForegroundColor Yellow
                bcdboot $env:SystemRoot /s S: /f UEFI 2>$null
                if ($LASTEXITCODE -ne 0) {
                    # Try to find EFI partition
                    $efiPart = Get-Partition | Where-Object { $_.Type -eq "System" -or $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" } | Select-Object -First 1
                    if ($efiPart) {
                        $efiLetter = if ($efiPart.DriveLetter) { $efiPart.DriveLetter } else { "S" }
                        if (-not $efiPart.DriveLetter) {
                            Get-Volume -Partition $efiPart | Get-Partition | Set-Partition -NewDriveLetter $efiLetter -ErrorAction SilentlyContinue
                        }
                        bcdboot $env:SystemRoot /s "${efiLetter}:" /f UEFI
                    }
                }
            } else {
                Write-Host "  Method 2: Repairing BIOS boot records..." -ForegroundColor Yellow
                bootrec /fixmbr
                bootrec /fixboot
            }

            # Method 3: Scan for Windows
            Write-Host "  Method 3: Scanning for Windows installations..." -ForegroundColor Yellow
            bootrec /scanos

            Write-Log "Auto-repair completed" "SUCCESS"
            Write-Host "  Restart and check if Windows boots." -ForegroundColor Cyan
        }

        "2" {
            Write-Log "Repair external/offline Windows drive" "SECTION"

            # List available drives
            Write-Host "  Available drives with Windows installations:" -ForegroundColor Cyan
            $volumes = Get-Volume | Where-Object { $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Windows\System32") }

            $i = 1
            $driveMap = @{}
            foreach ($vol in $volumes) {
                $windowsVer = if (Test-Path "$($vol.DriveLetter):\Windows\System32\ntoskrnl.exe") {
                    $fileInfo = Get-ItemProperty "$($vol.DriveLetter):\Windows\System32\ntoskrnl.exe" -ErrorAction SilentlyContinue
                    "(Modified: $($fileInfo.LastWriteTime.ToString('yyyy-MM-dd')))"
                } else { "" }
                Write-Host "  [$i] $($vol.DriveLetter): Drive - $windowsVer"
                $driveMap[$i] = $vol.DriveLetter
                $i++
            }
            Write-Host "  [0] Cancel"
            Write-Host ""

            $driveChoice = Read-Host "  Select Windows drive to repair"
            if ($driveChoice -eq "0") { Write-Log "Cancelled" "INFO"; return }

            $targetDrive = $driveMap[[int]$driveChoice]
            if (-not $targetDrive) { Write-Host "Invalid selection" -ForegroundColor Red; return }

            Write-Host ""
            Write-Host "  Selected drive: $targetDrive`:" -ForegroundColor Cyan
            Write-Host "  [1] Repair BCD for this drive (UEFI)"
            Write-Host "  [2] Repair BCD for this drive (BIOS/Legacy)"
            Write-Host "  [3] Full repair (rebuild BCD + boot files)"
            Write-Host "  [0] Cancel"
            Write-Host ""

            $repairChoice = Read-Host "  Select repair type"

            $windowsPath = "$targetDrive`:\Windows"

            switch ($repairChoice) {
                "1" {
                    # Find or assign EFI partition
                    $efiPart = Get-Partition | Where-Object { $_.Type -eq "System" -or $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" } | Select-Object -First 1
                    if ($efiPart) {
                        $efiLetter = if ($efiPart.DriveLetter) { $efiPart.DriveLetter } else {
                            # Assign temporary letter
                            $availableLetters = 67..90 | ForEach-Object { [char]$_ } | Where-Object { -not (Get-Volume -DriveLetter $_ -ErrorAction SilentlyContinue) }
                            $newLetter = $availableLetters | Select-Object -First 1
                            Get-Partition -DiskNumber $efiPart.DiskNumber -PartitionNumber $efiPart.PartitionNumber | Set-Partition -NewDriveLetter $newLetter -ErrorAction SilentlyContinue
                            $newLetter
                        }
                        Write-Log "Installing UEFI bootloader to ${efiLetter}:..."
                        bcdboot $windowsPath /s "${efiLetter}:" /f UEFI
                        Write-Log "UEFI bootloader installed" "SUCCESS"
                    } else {
                        Write-Log "No EFI partition found!" "ERROR"
                    }
                }
                "2" {
                    Write-Log "Installing BIOS bootloader..."
                    bootsect /nt60 $targetDrive /mbr /force
                    bcdboot $windowsPath /s "${targetDrive}:"
                    Write-Log "BIOS bootloader installed" "SUCCESS"
                }
                "3" {
                    Write-Log "Performing full repair..."
                    # Rebuild BCD
                    $bcdPath = "$targetDrive`:\Boot\BCD"
                    if (Test-Path $bcdPath) {
                        Rename-Item $bcdPath "$bcdPath.old" -Force -ErrorAction SilentlyContinue
                    }
                    bootrec /rebuildbcd
                    # Also try bcdboot
                    bcdboot $windowsPath
                    Write-Log "Full repair completed" "SUCCESS"
                }
                "0" { Write-Log "Cancelled" "INFO" }
                default { Write-Host "Invalid option" -ForegroundColor Red }
            }
        }

        "3" {
            Write-Log "Rebuild BCD from scratch (advanced)" "SECTION"
            Write-Host "  This will delete the current BCD and create a new one." -ForegroundColor Red
            $confirm = Read-Host "  Continue? Type 'REBUILD' to confirm"

            if ($confirm -eq "REBUILD") {
                # Backup current BCD
                $bcdBackup = "$env:TEMP\BCD_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Write-Host "  Backing up BCD to $bcdBackup..." -ForegroundColor Yellow
                bcdedit /export $bcdBackup

                # Rebuild
                Write-Host "  Rebuilding BCD store..." -ForegroundColor Yellow
                bootrec /rebuildbcd

                Write-Log "BCD rebuilt successfully" "SUCCESS"
                Write-Host "  Backup saved to: $bcdBackup" -ForegroundColor Cyan
            } else {
                Write-Log "Cancelled" "INFO"
            }
        }

        "4" {
            Write-Log "Fix boot records" "SECTION"
            Write-Host "  Boot mode detected: $firmwareType" -ForegroundColor Cyan
            Write-Host ""

            if ($firmwareType -eq "UEFI") {
                Write-Host "  [1] Repair EFI System Partition"
                Write-Host "  [2] Recreate EFI boot files"
                Write-Host "  [3] Fix GPT partition table"
                Write-Host "  [0] Cancel"
                Write-Host ""

                $efiChoice = Read-Host "  Select option"
                switch ($efiChoice) {
                    "1" {
                        Write-Log "Repairing EFI System Partition..."
                        $efiPart = Get-Partition | Where-Object { $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" } | Select-Object -First 1
                        if ($efiPart) {
                            Repair-Volume -DriveLetter $efiPart.DriveLetter -Scan
                            Write-Log "ESP repaired" "SUCCESS"
                        }
                    }
                    "2" {
                        Write-Log "Recreating EFI boot files..."
                        bcdboot $env:SystemRoot /s S: /f UEFI 2>$null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Log "EFI boot files recreated" "SUCCESS"
                        } else {
                            Write-Log "Failed to recreate EFI files" "ERROR"
                        }
                    }
                    "3" {
                        Write-Log "Running GPT repair..."
                        Write-Host "  Use diskpart to fix GPT? (Y/N)" -ForegroundColor Yellow
                        $gptConfirm = Read-Host
                        if ($gptConfirm -eq "Y") {
                            Start-Process diskpart -ArgumentList "/s" -Wait
                        }
                    }
                }
            } else {
                Write-Host "  [1] Fix Master Boot Record (MBR)"
                Write-Host "  [2] Fix boot sector"
                Write-Host "  [3] Fix both MBR and boot sector"
                Write-Host "  [0] Cancel"
                Write-Host ""

                $biosChoice = Read-Host "  Select option"
                switch ($biosChoice) {
                    "1" { bootrec /fixmbr; Write-Log "MBR repaired" "SUCCESS" }
                    "2" { bootrec /fixboot; Write-Log "Boot sector repaired" "SUCCESS" }
                    "3" { bootrec /fixmbr; bootrec /fixboot; Write-Log "Boot records repaired" "SUCCESS" }
                }
            }
        }

        "5" {
            Write-Log "Reinstall UEFI bootloader files" "SECTION"
            Write-Host "  This will reinstall Windows UEFI bootloader files." -ForegroundColor Yellow

            # Find EFI partition
            $efiParts = Get-Partition | Where-Object { $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" }

            if (-not $efiParts) {
                Write-Log "No EFI partitions found!" "ERROR"
                return
            }

            $i = 1
            $partMap = @{}
            foreach ($part in $efiParts) {
                $diskInfo = Get-Disk -Number $part.DiskNumber
                Write-Host "  [$i] Disk $($part.DiskNumber), Partition $($part.PartitionNumber) - $($diskInfo.FriendlyName)"
                $partMap[$i] = $part
                $i++
            }

            $partChoice = Read-Host "  Select EFI partition"
            $selectedPart = $partMap[[int]$partChoice]

            if ($selectedPart) {
                # Assign letter if needed
                $efiLetter = if ($selectedPart.DriveLetter) { $selectedPart.DriveLetter } else { "S" }
                if (-not $selectedPart.DriveLetter) {
                    Get-Partition -DiskNumber $selectedPart.DiskNumber -PartitionNumber $selectedPart.PartitionNumber | Set-Partition -NewDriveLetter $efiLetter -ErrorAction SilentlyContinue
                }

                Write-Log "Installing UEFI bootloader to ${efiLetter}:..."
                bcdboot $env:SystemRoot /s "${efiLetter}:" /f UEFI

                Write-Log "UEFI bootloader reinstalled" "SUCCESS"
            }
        }

        "6" {
            Write-Log "Scanning for Windows installations..."
            bootrec /scanos
            Write-Host ""
            Write-Host "  Add found installations to BCD? (Y/N)" -ForegroundColor Yellow
            $addChoice = Read-Host
            if ($addChoice -eq "Y") {
                bootrec /rebuildbcd
            }
        }

        "7" {
            if ($firmwareType -eq "UEFI") {
                Write-Log "Set active partition is for BIOS systems only" "WARNING"
                return
            }

            Write-Log "Set active partition (BIOS)" "SECTION"
            Write-Host "  Available disks:" -ForegroundColor Cyan
            Get-Disk | Where-Object { $_.BusType -ne 'USB' } | Format-Table Number, FriendlyName, Size, PartitionStyle -AutoSize

            $diskNum = Read-Host "  Enter disk number"
            $partNum = Read-Host "  Enter partition number to set active"

            Write-Log "Setting partition $partNum on disk $diskNum as active..."
            $diskpartScript = @"
select disk $diskNum
select partition $partNum
active
exit
"@
            $diskpartScript | diskpart
            Write-Log "Partition set as active" "SUCCESS"
        }

        "8" {
            Write-Log "Assign drive letters to system partitions" "SECTION"
            Write-Host "  Scanning for unassigned system partitions..." -ForegroundColor Gray

            $partitions = Get-Partition | Where-Object { -not $_.DriveLetter -and ($_.Type -eq "System" -or $_.Type -eq "Reserved") }

            if ($partitions) {
                foreach ($part in $partitions) {
                    $availableLetters = 67..90 | ForEach-Object { [char]$_ } | Where-Object { -not (Get-Volume -DriveLetter $_ -ErrorAction SilentlyContinue) }
                    $newLetter = $availableLetters | Select-Object -First 1

                    if ($newLetter) {
                        Write-Host "  Assigning letter $newLetter to partition $($part.PartitionNumber) on disk $($part.DiskNumber)..."
                        Get-Partition -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber | Set-Partition -NewDriveLetter $newLetter -ErrorAction SilentlyContinue
                    }
                }
                Write-Log "Drive letters assigned" "SUCCESS"
            } else {
                Write-Log "No unassigned system partitions found" "INFO"
            }
        }

        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-MemoryDiagnostic {
    <#
    .SYNOPSIS
        Schedule Windows Memory Diagnostic
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "MEMORY DIAGNOSTIC" "SECTION"

    Write-Host ""
    Write-Host "  This schedules Windows Memory Diagnostic to run on next reboot." -ForegroundColor Cyan
    Write-Host "  The test will take 15-30 minutes depending on your RAM." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [1] Standard test (recommended)"
    Write-Host "  [2] Extended test (thorough but slow)"
    Write-Host "  [3] Cancel scheduled test"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Scheduling standard memory test..."
            mdsched.exe
            Write-Log "Memory diagnostic scheduled. Restart to begin test." "SUCCESS"
        }
        "2" {
            Write-Log "Scheduling extended memory test..."
            # Extended test requires registry modification
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "MemTestMode" -Value 2 -Type DWord -ErrorAction SilentlyContinue
            mdsched.exe
            Write-Log "Extended memory diagnostic scheduled. Restart to begin test." "SUCCESS"
        }
        "3" {
            Write-Log "Cancelling scheduled memory test..."
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "MemoryDiagnostic" -ErrorAction SilentlyContinue
            Write-Log "Memory test cancelled" "SUCCESS"
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Get-DriveHealth {
    <#
    .SYNOPSIS
        Check drive health using SMART data
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "DRIVE HEALTH (SMART)" "SECTION"

    Write-Host ""
    Write-Host "  Retrieving drive health information..." -ForegroundColor Gray
    Write-Host ""

    try {
        # Get physical disks
        $disks = Get-PhysicalDisk | Where-Object { $_.BusType -ne 'USB' }

        foreach ($disk in $disks) {
            Write-Host "  Drive: $($disk.FriendlyName)" -ForegroundColor Cyan
            Write-Host "    Model: $($disk.Model)"
            Write-Host "    Size: $([math]::Round($disk.Size / 1GB, 2)) GB"
            Write-Host "    Media Type: $($disk.MediaType)"
            Write-Host "    Health Status: $($disk.HealthStatus)" -ForegroundColor $(if($disk.HealthStatus -eq 'Healthy'){'Green'}else{'Red'})

            # Try to get additional SMART info via WMI
            try {
                $wmiDisk = Get-WmiObject -Namespace "root\wmi" -Class MSStorageDriver_FailurePredictStatus | Where-Object { $_.InstanceName -like "*$($disk.DeviceId)*" }
                if ($wmiDisk) {
                    Write-Host "    SMART Predict Failure: $($wmiDisk.PredictFailure)" -ForegroundColor $(if($wmiDisk.PredictFailure -eq $false){'Green'}else{'Red'})
                }
            } catch {
                # SMART data not available
            }

            # Get temperature if available
            try {
                $temp = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction SilentlyContinue
                if ($temp.Temperature) {
                    $tempColor = if ($temp.Temperature -gt 50) { 'Red' } elseif ($temp.Temperature -gt 40) { 'Yellow' } else { 'Green' }
                    Write-Host "    Temperature: $($temp.Temperature)°C" -ForegroundColor $tempColor
                }

                if ($temp.PowerOnHours) {
                    Write-Host "    Power On Hours: $($temp.PowerOnHours)"
                }

                if ($temp.StartStopCycleCount) {
                    Write-Host "    Start/Stop Cycles: $($temp.StartStopCycleCount)"
                }
            } catch {
                # Reliability counters not available
            }

            Write-Host ""
        }
    } catch {
        Write-Log "Could not retrieve drive health: $_" "ERROR"
    }
}

function Start-WindowsUpdateRepair {
    <#
    .SYNOPSIS
        Comprehensive Windows Update repair
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "WINDOWS UPDATE REPAIR" "SECTION"

    Write-Host ""
    Write-Host "  This will perform a comprehensive Windows Update repair:" -ForegroundColor Cyan
    Write-Host "    - Stop Windows Update services"
    Write-Host "    - Clear update caches"
    Write-Host "    - Re-register update DLLs"
    Write-Host "    - Reset update components"
    Write-Host ""
    $confirm = Read-Host "  Continue? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") { Write-Log "Cancelled" "INFO"; return }

    # Stop services
    Write-Log "Stopping Windows Update services..."
    $services = @("wuauserv", "cryptSvc", "bits", "msiserver")
    foreach ($svc in $services) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Write-Host "  Stopped: $svc" -ForegroundColor Gray
    }

    # Rename SoftwareDistribution and CatRoot2
    Write-Log "Renaming update folders..."
    Rename-Item -Path "$env:WINDIR\SoftwareDistribution" -NewName "SoftwareDistribution.old" -Force -ErrorAction SilentlyContinue
    Rename-Item -Path "$env:WINDIR\System32\catroot2" -NewName "catroot2.old" -Force -ErrorAction SilentlyContinue

    # Re-register DLLs
    Write-Log "Re-registering Windows Update DLLs..."
    $dlls = @(
        "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
        "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll",
        "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll",
        "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll",
        "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", "wuapi.dll",
        "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll",
        "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll", "wuwebv.dll"
    )

    foreach ($dll in $dlls) {
        regsvr32 /s "$env:SystemRoot\System32\$dll" 2>&1 | Out-Null
    }
    Write-Log "DLLs re-registered" "SUCCESS"

    # Reset Windows Update components
    Write-Log "Resetting Windows Update components..."
    netsh winsock reset | Out-Null
    netsh winhttp reset proxy | Out-Null

    # Restart services
    Write-Log "Restarting services..."
    foreach ($svc in $services) {
        Start-Service -Name $svc -ErrorAction SilentlyContinue
        Write-Host "  Started: $svc" -ForegroundColor Gray
    }

    # Run Windows Update troubleshooter
    Write-Log "Running Windows Update troubleshooter..."
    msdt.exe /id WindowsUpdateDiagnostic

    Write-Log "Windows Update repair completed" "SUCCESS"
    Write-Host "  Please restart your computer." -ForegroundColor Yellow
}

function Start-DISMRepair {
    <#
    .SYNOPSIS
        Enhanced DISM repair with multiple scan options
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "DISM REPAIR TOOLS" "SECTION"

    Write-Host ""
    Write-Host "  [1] CheckHealth - Quick corruption check"
    Write-Host "  [2] ScanHealth - Detailed scan (5-10 min)"
    Write-Host "  [3] RestoreHealth - Repair corruption (15-30 min)"
    Write-Host "  [4] Analyze Component Store - Show cleanup potential"
    Write-Host "  [5] Full Repair Sequence - All of the above"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Running DISM CheckHealth..."
            DISM /Online /Cleanup-Image /CheckHealth
            Write-Log "Check completed" "SUCCESS"
        }
        "2" {
            Write-Log "Running DISM ScanHealth (this may take 5-10 minutes)..."
            DISM /Online /Cleanup-Image /ScanHealth
            Write-Log "Scan completed" "SUCCESS"
        }
        "3" {
            Write-Log "Running DISM RestoreHealth (this may take 15-30 minutes)..."
            DISM /Online /Cleanup-Image /RestoreHealth
            Write-Log "Repair completed" "SUCCESS"
        }
        "4" {
            Write-Log "Analyzing Component Store..."
            DISM /Online /Cleanup-Image /AnalyzeComponentStore
            Write-Log "Analysis completed" "SUCCESS"
        }
        "5" {
            Write-Log "Running full DISM repair sequence..." "SECTION"

            Write-Host "  Step 1/3: Checking health..." -ForegroundColor Yellow
            DISM /Online /Cleanup-Image /CheckHealth

            Write-Host "  Step 2/3: Scanning for corruption..." -ForegroundColor Yellow
            DISM /Online /Cleanup-Image /ScanHealth

            Write-Host "  Step 3/3: Repairing corruption..." -ForegroundColor Yellow
            DISM /Online /Cleanup-Image /RestoreHealth

            Write-Log "Full DISM sequence completed" "SUCCESS"
            Write-Host "  Run SFC /scannow to verify repairs." -ForegroundColor Cyan
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-DriveOptimization {
    <#
    .SYNOPSIS
        Optimize drives - defrag HDDs, TRIM SSDs, with automatic media type detection
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "DRIVE OPTIMIZATION" "SECTION"

    Write-Host ""
    Write-Host "  Analyzing drives..." -ForegroundColor Gray
    Write-Host ""

    # Get all fixed drives with media type
    $drives = Get-PhysicalDisk | Where-Object { $_.BusType -ne 'USB' -and $_.BusType -ne 'File Backed Virtual' } | ForEach-Object {
        $physicalDisk = $_
        $partition = Get-Partition -DiskNumber $physicalDisk.DeviceId | Where-Object { $_.Type -eq 'Basic' -and $_.DriveLetter } | Select-Object -First 1
        if ($partition) {
            [PSCustomObject]@{
                DriveLetter = $partition.DriveLetter
                MediaType = $physicalDisk.MediaType
                FriendlyName = $physicalDisk.FriendlyName
                SizeGB = [math]::Round($physicalDisk.Size / 1GB, 2)
                IsOptimized = $false
            }
        }
    }

    if (-not $drives) {
        Write-Log "No optimizable drives found" "WARNING"
        return
    }

    Write-Host "  Detected drives:" -ForegroundColor Cyan
    $i = 1
    $driveMap = @{}
    foreach ($drive in $drives) {
        $optType = if ($drive.MediaType -eq 'SSD') { "TRIM" } else { "Defrag" }
        Write-Host "  [$i] $($drive.DriveLetter): - $($drive.FriendlyName) ($($drive.MediaType), $($drive.SizeGB) GB) - $optType"
        $driveMap[$i] = $drive
        $i++
    }
    Write-Host "  [A] Optimize all drives"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "  Select drive to optimize"

    if ($choice -eq "0") { Write-Log "Cancelled" "INFO"; return }

    $selectedDrives = if ($choice -eq "A" -or $choice -eq "a") {
        $drives
    } else {
        $driveMap[[int]$choice]
        if (-not $driveMap[[int]$choice]) { Write-Host "Invalid selection" -ForegroundColor Red; return }
        @($driveMap[[int]$choice])
    }

    foreach ($drive in $selectedDrives) {
        Write-Host ""
        Write-Log "Optimizing $($drive.DriveLetter): ($($drive.MediaType))..." "SECTION"

        try {
            if ($drive.MediaType -eq 'SSD' -or $drive.MediaType -eq 'NVMe') {
                # For SSDs: Run TRIM/Retrim
                Write-Host "  Running TRIM optimization for SSD..." -ForegroundColor Yellow
                Optimize-Volume -DriveLetter $drive.DriveLetter -ReTrim -Verbose
                Write-Log "TRIM completed for $($drive.DriveLetter):" "SUCCESS"
            } else {
                # For HDDs: Run defrag
                Write-Host "  Running defragmentation for HDD..." -ForegroundColor Yellow
                Write-Host "  This may take a while for large drives..." -ForegroundColor Gray
                Optimize-Volume -DriveLetter $drive.DriveLetter -Defrag -Verbose
                Write-Log "Defrag completed for $($drive.DriveLetter):" "SUCCESS"
            }

            # Show fragmentation analysis
            $analysis = Optimize-Volume -DriveLetter $drive.DriveLetter -Analyze
            Write-Host "  Fragmentation: $($analysis.FragmentationPercent)%" -ForegroundColor $(if($analysis.FragmentationPercent -gt 10){'Yellow'}else{'Green'})
        } catch {
            Write-Log "Failed to optimize $($drive.DriveLetter): $_" "ERROR"
        }
    }

    Write-Host ""
    Write-Log "Drive optimization completed" "SUCCESS"
}

function Start-TimeSyncRepair {
    <#
    .SYNOPSIS
        Repair Windows Time service and resync with NTP servers
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "TIME SYNCHRONIZATION REPAIR" "SECTION"

    Write-Host ""
    Write-Host "  Current time: $(Get-Date)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [1] Quick repair (restart service and sync)"
    Write-Host "  [2] Full repair (reset service, reconfigure NTP)"
    Write-Host "  [3] Change NTP server"
    Write-Host "  [4] View current time configuration"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Performing quick time sync repair..."

            # Restart time service
            Write-Host "  Restarting Windows Time service..." -ForegroundColor Yellow
            Restart-Service -Name w32time -Force -ErrorAction SilentlyContinue

            # Force resync
            Write-Host "  Forcing time synchronization..." -ForegroundColor Yellow
            w32tm /resync /force | Out-Null

            Start-Sleep -Seconds 2
            Write-Log "Time sync completed" "SUCCESS"
            Write-Host "  Current time: $(Get-Date)" -ForegroundColor Cyan
        }

        "2" {
            Write-Log "Performing full time service repair..."

            # Unregister and re-register time service
            Write-Host "  Re-registering time service..." -ForegroundColor Yellow
            w32tm /unregister | Out-Null
            w32tm /register | Out-Null

            # Configure NTP servers
            Write-Host "  Configuring NTP servers..." -ForegroundColor Yellow
            w32tm /config /syncfromflags:manual /manualpeerlist:"time.windows.com,0x1 pool.ntp.org,0x1" | Out-Null

            # Set update interval
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" -Name "SpecialPollInterval" -Value 3600 -Type DWord -Force

            # Start service
            Set-Service -Name w32time -StartupType Automatic
            Start-Service -Name w32time

            # Force sync
            w32tm /resync /force | Out-Null

            Write-Log "Full repair completed" "SUCCESS"
            Write-Host "  Current time: $(Get-Date)" -ForegroundColor Cyan
        }

        "3" {
            Write-Host ""
            Write-Host "  Common NTP servers:" -ForegroundColor Cyan
            Write-Host "  [1] Windows (time.windows.com)"
            Write-Host "  [2] Google (time.google.com)"
            Write-Host "  [3] Cloudflare (time.cloudflare.com)"
            Write-Host "  [4] Pool (pool.ntp.org)"
            Write-Host "  [5] Custom"
            Write-Host ""

            $ntpChoice = Read-Host "  Select NTP server"
            $ntpServer = switch ($ntpChoice) {
                "1" { "time.windows.com,0x1" }
                "2" { "time.google.com,0x1" }
                "3" { "time.cloudflare.com,0x1" }
                "4" { "pool.ntp.org,0x1" }
                "5" { Read-Host "  Enter custom NTP server" }
                default { "time.windows.com,0x1" }
            }

            Write-Log "Setting NTP server to: $ntpServer"
            w32tm /config /manualpeerlist:$ntpServer /syncfromflags:manual /update | Out-Null
            w32tm /resync /force | Out-Null
            Write-Log "NTP server updated" "SUCCESS"
        }

        "4" {
            Write-Log "Current time configuration:" "SECTION"
            w32tm /query /status
            Write-Host ""
            Write-Host "  Configuration:" -ForegroundColor Cyan
            w32tm /query /configuration | Select-String "NtpServer|Type|Source"
        }

        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-SearchIndexRebuild {
    <#
    .SYNOPSIS
        Rebuild Windows Search index
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "WINDOWS SEARCH INDEX REBUILD" "SECTION"

    Write-Host ""
    Write-Host "  This will reset the Windows Search index database." -ForegroundColor Yellow
    Write-Host "  Search functionality will be unavailable during rebuild." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Quick reset (stop service, delete index, restart)"
    Write-Host "  [2] Full reset with index location change (for SSD users)"
    Write-Host "  [3] Disable Windows Search indexing"
    Write-Host "  [4] Enable Windows Search indexing"
    Write-Host "  [5] Check index status"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Performing quick index reset..."

            # Stop Windows Search service
            Write-Host "  Stopping Windows Search service..." -ForegroundColor Yellow
            Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue

            # Remove index files
            Write-Host "  Removing old index files..." -ForegroundColor Yellow
            $indexPaths = @(
                "$env:ALLUSERSPROFILE\Microsoft\Search\Data\Applications\Windows\Windows.edb",
                "$env:ALLUSERSPROFILE\Microsoft\Search\Data\Applications\Windows\*.log"
            )
            foreach ($path in $indexPaths) {
                Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
            }

            # Start service
            Write-Host "  Restarting Windows Search service..." -ForegroundColor Yellow
            Start-Service -Name WSearch -ErrorAction SilentlyContinue

            Write-Log "Index reset completed. Rebuild will begin automatically." "SUCCESS"
            Write-Host "  This may take several hours depending on file count." -ForegroundColor Cyan
        }

        "2" {
            Write-Log "Full reset with index location configuration..."

            # Ask for new location
            Write-Host ""
            Write-Host "  Current index location: $env:ALLUSERSPROFILE\Microsoft\Search\Data" -ForegroundColor Gray
            Write-Host "  Recommended: Move to secondary HDD if Windows is on SSD" -ForegroundColor Cyan
            Write-Host ""
            $newPath = Read-Host "  Enter new index location (or press Enter to keep default)"

            if ($newPath -and (Test-Path $newPath)) {
                # Stop service
                Stop-Service -Name WSearch -Force

                # Update registry
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Search" -Name "DataDirectory" -Value $newPath -Force

                # Move existing files
                $oldPath = "$env:ALLUSERSPROFILE\Microsoft\Search\Data"
                if (Test-Path $oldPath) {
                    Move-Item -Path $oldPath -Destination "$newPath\SearchData_Backup_$(Get-Date -Format 'yyyyMMdd')" -Force -ErrorAction SilentlyContinue
                }

                # Start service
                Start-Service -Name WSearch
                Write-Log "Index location changed and service restarted" "SUCCESS"
            } else {
                Write-Log "Invalid path or no change requested" "WARNING"
            }
        }

        "3" {
            Write-Log "Disabling Windows Search indexing..."
            Stop-Service -Name WSearch -Force
            Set-Service -Name WSearch -StartupType Disabled
            Write-Log "Windows Search disabled" "SUCCESS"
            Write-Host "  This will improve performance on low-end systems." -ForegroundColor Cyan
        }

        "4" {
            Write-Log "Enabling Windows Search indexing..."
            Set-Service -Name WSearch -StartupType Automatic
            Start-Service -Name WSearch
            Write-Log "Windows Search enabled" "SUCCESS"
        }

        "5" {
            Write-Log "Windows Search Index Status:" "SECTION"
            $service = Get-Service -Name WSearch -ErrorAction SilentlyContinue
            Write-Host "  Service Status: $($service.Status)" -ForegroundColor $(if($service.Status -eq 'Running'){'Green'}else{'Red'})
            Write-Host "  Startup Type: $($service.StartupType)" -ForegroundColor Gray

            $indexPath = "$env:ALLUSERSPROFILE\Microsoft\Search\Data\Applications\Windows"
            if (Test-Path $indexPath) {
                $indexSize = (Get-ChildItem $indexPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                $sizeMB = [math]::Round($indexSize / 1MB, 2)
                Write-Host "  Index Size: $sizeMB MB" -ForegroundColor Gray
            }

            # Show indexed locations
            Write-Host ""
            Write-Host "  Indexed Locations:" -ForegroundColor Cyan
            $indexedPaths = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex" -Name "DefaultRules" -ErrorAction SilentlyContinue
            if ($indexedPaths) {
                $indexedPaths.DefaultRules | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            }
        }

        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-StartupProgramManager {
    <#
    .SYNOPSIS
        Manage startup programs - view, enable, disable, remove
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "STARTUP PROGRAM MANAGER" "SECTION"

    Write-Host ""
    Write-Host "  Loading startup programs..." -ForegroundColor Gray

    # Get startup items from multiple sources
    $startupItems = @()

    # Registry Run keys
    $runKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($key in $runKeys) {
        if (Test-Path $key) {
            Get-ItemProperty -Path $key | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                $value = (Get-ItemProperty -Path $key -Name $_.Name).$($_.Name)
                $startupItems += [PSCustomObject]@{
                    Name = $_.Name
                    Command = $value
                    Location = if ($key -like "HKLM*") { "Machine" } else { "User" }
                    Type = "Registry"
                    KeyPath = $key
                }
            }
        }
    }

    # Startup folders
    $startupFolders = @(
        "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\StartUp",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    )

    foreach ($folder in $startupFolders) {
        if (Test-Path $folder) {
            Get-ChildItem -Path $folder -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($_.FullName)
                $startupItems += [PSCustomObject]@{
                    Name = $_.BaseName
                    Command = $shortcut.TargetPath
                    Location = if ($folder -like "*All Users*" -or $folder -like "*ProgramData*") { "Machine" } else { "User" }
                    Type = "Shortcut"
                    FilePath = $_.FullName
                }
            }
        }
    }

    # Task Manager startup items (modern)
    try {
        Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | ForEach-Object {
            $startupItems += [PSCustomObject]@{
                Name = $_.Name
                Command = $_.Command
                Location = $_.Location
                Type = "TaskManager"
                User = $_.User
            }
        } | Out-Null
    } catch {
        # Win32_StartupCommand may not be available on all systems
    }

    if ($startupItems.Count -eq 0) {
        Write-Log "No startup programs found" "INFO"
        return
    }

    Write-Host ""
    Write-Host "  Found $($startupItems.Count) startup programs:" -ForegroundColor Cyan
    Write-Host ""

    $i = 1
    $itemMap = @{}
    foreach ($item in $startupItems) {
        $locationColor = if ($item.Location -eq "Machine") { "Yellow" } else { "Cyan" }
        Write-Host "  [$i] " -NoNewline
        Write-Host "$($item.Name)" -ForegroundColor White -NoNewline
        Write-Host " ($($item.Type), " -NoNewline -ForegroundColor Gray
        Write-Host "$($item.Location)" -ForegroundColor $locationColor -NoNewline
        Write-Host ")" -ForegroundColor Gray
        Write-Host "      $($item.Command)" -ForegroundColor DarkGray
        $itemMap[$i] = $item
        $i++
    }

    Write-Host ""
    Write-Host "  [D] Disable selected program"
    Write-Host "  [R] Remove selected program"
    Write-Host "  [A] Add new startup program"
    Write-Host "  [0] Back"
    Write-Host ""

    $action = Read-Host "  Select action"

    switch ($action) {
        "D" {
            $num = Read-Host "  Enter program number to disable"
            $item = $itemMap[[int]$num]
            if ($item) {
                if ($item.Type -eq "Registry") {
                    # Rename the value to disable (prefix with _)
                    $currentValue = (Get-ItemProperty -Path $item.KeyPath -Name $item.Name).$($item.Name)
                    Remove-ItemProperty -Path $item.KeyPath -Name $item.Name -Force
                    New-ItemProperty -Path $item.KeyPath -Name "_$($item.Name)_Disabled" -Value $currentValue -PropertyType String -Force | Out-Null
                    Write-Log "Disabled: $($item.Name)" "SUCCESS"
                } elseif ($item.Type -eq "Shortcut") {
                    Rename-Item -Path $item.FilePath -NewName "$($item.FilePath).disabled" -Force
                    Write-Log "Disabled: $($item.Name)" "SUCCESS"
                }
            }
        }

        "R" {
            $num = Read-Host "  Enter program number to remove"
            $item = $itemMap[[int]$num]
            if ($item) {
                $confirm = Read-Host "  Confirm removal of '$($item.Name)'? (Y/N)"
                if ($confirm -eq "Y") {
                    if ($item.Type -eq "Registry") {
                        Remove-ItemProperty -Path $item.KeyPath -Name $item.Name -Force
                    } elseif ($item.Type -eq "Shortcut") {
                        Remove-Item -Path $item.FilePath -Force
                    }
                    Write-Log "Removed: $($item.Name)" "SUCCESS"
                }
            }
        }

        "A" {
            Write-Host ""
            Write-Host "  Add new startup program:" -ForegroundColor Cyan
            $progName = Read-Host "  Program name"
            $progPath = Read-Host "  Program path (or command)"
            $progScope = Read-Host "  Scope (M)achine or (U)ser"

            if ($progScope -eq "M" -or $progScope -eq "m") {
                $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            } else {
                $key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            }

            New-ItemProperty -Path $key -Name $progName -Value $progPath -PropertyType String -Force | Out-Null
            Write-Log "Added: $progName" "SUCCESS"
        }

        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-MaintenanceMenu {
    <#
    .SYNOPSIS
        Maintenance tools menu
    #>
    do {
        Set-ConsoleSize
        Clear-Host
        Write-Log "MAINTENANCE TOOLS" "SECTION"

        Write-Host ""
        Write-Host "  [1] Run Automated Maintenance (DISM, SFC, Cleanup)"
        Write-Host "  [2] Disk Cleanup"
        Write-Host "  [3] Disk Space Report"
        Write-Host "  [4] Drive Optimization (Defrag/TRIM)"
        Write-Host "  [5] Check Disk (chkdsk)"
        Write-Host "  [6] System Restore"
        Write-Host "  [7] BCD/Boot Repair"
        Write-Host "  [8] Memory Diagnostic"
        Write-Host "  [9] Drive Health (SMART)"
        Write-Host "  [10] Windows Update Repair"
        Write-Host "  [11] DISM Repair Tools"
        Write-Host "  [12] Time Sync Repair"
        Write-Host "  [13] Search Index Rebuild"
        Write-Host "  [14] Startup Program Manager"
        Write-Host "  [15] Reset Group Policy"
        Write-Host "  [16] Reset WMI"
        Write-Host "  [0] Back to Main Menu"
        Write-Host ""

        $choice = Read-Host "  Select an option"

        switch ($choice) {
            "1" { Start-SystemMaintenance }
            "2" { Start-DiskCleanup }
            "3" { Show-DiskSpaceReport }
            "4" { Start-DriveOptimization }
            "5" { Start-CheckDisk }
            "6" { Start-SystemRestore }
            "7" { Start-BCDRepair }
            "8" { Start-MemoryDiagnostic }
            "9" { Get-DriveHealth }
            "10" { Start-WindowsUpdateRepair }
            "11" { Start-DISMRepair }
            "12" { Start-TimeSyncRepair }
            "13" { Start-SearchIndexRebuild }
            "14" { Start-StartupProgramManager }
            "15" { Reset-GroupPolicy }
            "16" { Reset-WMI }
            "0" { return }
            default { Write-Host "Invalid option" -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }

        if ($choice -ne "0") {
            Write-Host ""
            Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
    } while ($choice -ne "0")
}

# Export functions
Export-ModuleMember -Function @(
    'Start-SystemMaintenance',
    'Start-DiskCleanup',
    'Get-DiskSpaceInfo',
    'Show-DiskSpaceReport',
    'Reset-GroupPolicy',
    'Reset-WMI',
    'Start-CheckDisk',
    'Start-SystemRestore',
    'Start-BCDRepair',
    'Start-MemoryDiagnostic',
    'Get-DriveHealth',
    'Start-WindowsUpdateRepair',
    'Start-DISMRepair',
    'Start-DriveOptimization',
    'Start-TimeSyncRepair',
    'Start-SearchIndexRebuild',
    'Start-StartupProgramManager',
    'Start-MaintenanceMenu'
)
