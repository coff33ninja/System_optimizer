#Requires -Version 5.1
<#
.SYNOPSIS
    Drivers Module - System Optimizer
.DESCRIPTION
    Provides driver management through Snappy Driver Installer (SDI)
    and DISM-based backup/restore functionality.

Exported Functions:
    Start-SnappyDriverInstaller   - Launch SDI for driver updates
    Backup-Drivers                - Backup drivers via DISM
    Restore-Drivers               - Restore drivers from backup
    Export-Drivers                - Export drivers to folder

SDI Integration:
    - Downloads SDI automatically
    - SDI Lite for quick updates
    - Full SDI with auto-update
    - Driver pack management

DISM Operations:
    - Export all third-party drivers
    - Import drivers from backup
    - Online/offline driver management

Backup Location:
    C:\System_Optimizer_Backup\DRIVERS_EXPORT

Requires Admin: Yes

Version: 1.0.0
#>

function Start-SnappyDriverInstaller {
    $BaseDir = "C:\System_Optimizer\SDI"
    $BackupDir = "C:\System_Optimizer_Backup\DRIVERS_EXPORT"
    if (-not (Test-Path $BaseDir)) { New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null }

    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Driver Management" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Update Drivers:" -ForegroundColor Gray
        Write-Host "  [1] Update via Windows Update (recommended)"
        Write-Host "  [2] Download Snappy Driver Installer Lite"
        Write-Host "  [3] SDI Auto-Update (NexTool method)"
        Write-Host "  [4] Open SDI download page"
        Write-Host ""
        Write-Host "  Backup/Restore:" -ForegroundColor Gray
        Write-Host "  [5] Backup current drivers (DISM)"
        Write-Host "  [6] Restore drivers from backup"
        Write-Host ""
        Write-Host "  [0] Back"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
        "1" {
            # Use Windows Update for drivers
            Update-DriversViaWindowsUpdate
        }
        "2" {
            try {
                Write-Log "Downloading Snappy Driver Installer Lite..."
                $sdiUrl = "https://sdi-tool.org/releases/SDI_R2411.zip"
                $zipPath = "$BaseDir\SDI.zip"

                Invoke-WebRequest -Uri $sdiUrl -OutFile $zipPath -UseBasicParsing
                Write-Log "Downloaded SDI" "SUCCESS"

                Write-Log "Extracting..."
                Expand-Archive -Path $zipPath -DestinationPath $BaseDir -Force
                Write-Log "Extracted SDI" "SUCCESS"

                # Find and run SDI
                $sdiExe = Get-ChildItem -Path $BaseDir -Recurse -Filter "SDI*.exe" | Where-Object { $_.Name -notlike "*_x64*" -and $_.Name -notlike "*_x86*" } | Select-Object -First 1
                if (-not $sdiExe) {
                    $sdiExe = Get-ChildItem -Path $BaseDir -Recurse -Filter "SDI*.exe" | Select-Object -First 1
                }

                if ($sdiExe) {
                    Write-Log "Launching Snappy Driver Installer..."
                    Start-Process -FilePath $sdiExe.FullName
                    Write-Log "SDI launched" "SUCCESS"
                } else {
                    Write-Log "Could not find SDI executable" "ERROR"
                }

                Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "3" {
            # NexTool method - download from AIO repo with auto-update flags
            try {
                Write-Log "Downloading Snappy Driver Installer..."
                $sdiUrl = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/tools/SNAPPY_DRIVER.zip"
                $zipPath = "$BaseDir\SNAPPY_DRIVER.zip"
                $extractPath = "$BaseDir\SNAPPY_DRIVER"

                Invoke-WebRequest -Uri $sdiUrl -OutFile $zipPath -UseBasicParsing
                Write-Log "Downloaded SDI" "SUCCESS"

                Write-Log "Extracting..."
                if (-not (Test-Path $extractPath)) { New-Item -ItemType Directory -Path $extractPath -Force | Out-Null }
                Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
                Write-Log "Extracted SDI" "SUCCESS"

                # Find appropriate exe based on architecture
                $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "R" }
                $sdiExe = Get-ChildItem -Path $extractPath -Recurse -Filter "SDI*$arch*.exe" | Select-Object -First 1
                if (-not $sdiExe) {
                    $sdiExe = Get-ChildItem -Path $extractPath -Recurse -Filter "SDI*.exe" | Select-Object -First 1
                }

                if ($sdiExe) {
                    Write-Log "Launching SDI with auto-update..."
                    # Run with auto-update flags like NexTool does
                    Start-Process -FilePath $sdiExe.FullName -ArgumentList "-checkupdates -autoupdate"
                    Write-Log "SDI launched with auto-update" "SUCCESS"
                } else {
                    Write-Log "Could not find SDI executable" "ERROR"
                }

                Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "4" {
            Write-Log "Opening SDI download page..."
            Start-Process "https://sdi-tool.org/download/"
            Write-Log "Browser opened" "SUCCESS"
        }
        "5" {
            # Backup drivers using DISM (AIO method)
            try {
                Write-Log "Backing up drivers using DISM..."
                if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

                Write-Host "This will export all third-party drivers to: $BackupDir" -ForegroundColor Yellow
                Write-Host "This may take a few minutes..." -ForegroundColor Yellow

                DISM /Online /Export-Driver /Destination:$BackupDir 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $driverCount = (Get-ChildItem -Path $BackupDir -Directory).Count
                    Write-Log "Drivers backed up successfully ($driverCount drivers)" "SUCCESS"
                    Write-Host "Backup location: $BackupDir" -ForegroundColor Cyan
                } else {
                    Write-Log "DISM export completed with warnings" "WARNING"
                }
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "6" {
            # Restore drivers using DISM (AIO method)
            try {
                if (-not (Test-Path $BackupDir)) {
                    Write-Log "No driver backup found at $BackupDir" "ERROR"
                    return
                }

                $driverCount = (Get-ChildItem -Path $BackupDir -Directory).Count
                Write-Host "Found $driverCount driver folders in backup." -ForegroundColor Yellow
                Write-Host "This will install all backed up drivers." -ForegroundColor Yellow
                $confirm = Read-Host "Continue? (Y/N)"

                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    Write-Log "Restoring drivers from backup..."
                    DISM /Online /Add-Driver /Driver:$BackupDir /Recurse 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Drivers restored successfully" "SUCCESS"
                    } else {
                        Write-Log "Some drivers may have failed to install" "WARNING"
                    }
                } else {
                    Write-Log "Cancelled" "INFO"
                }
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
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

# Export functions
Export-ModuleMember -Function @(
    'Start-SnappyDriverInstaller'
)
