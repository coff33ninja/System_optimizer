# ============================================================================
# Privacy Module - System Optimizer
# ============================================================================

function Start-OOShutUp10 {
    Set-ConsoleSize
    Clear-Host
    Write-Log "LAUNCHING O&O SHUTUP10" "SECTION"

    $BaseDir = "C:\System_Optimizer\OOSU10"
    if (-not (Test-Path $BaseDir)) { New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null }

    $exePath = "$BaseDir\OOSU10.exe"
    $cfgPath = "$BaseDir\ooshutup10.cfg"

    Write-Host ""
    Write-Host "O&O ShutUp10 Options:" -ForegroundColor Cyan
    Write-Host "  [1] Download and run with recommended settings"
    Write-Host "  [2] Download and run interactively (choose your own)"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            try {
                # Download OOSU10 with progress
                Write-Log "Downloading O&O ShutUp10..."
                $hasDownloader = Get-Command 'Start-Download' -ErrorAction SilentlyContinue
                if ($hasDownloader) {
                    Start-Download -Url "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -OutFile $exePath -Description "O&O ShutUp10"
                } else {
                    Invoke-WebRequest -Uri "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -OutFile $exePath -UseBasicParsing
                }
                Write-Log "Downloaded OOSU10.exe" "SUCCESS"

                # Download recommended config
                Write-Log "Downloading recommended config..."
                $cfgUrl = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/ooshutup10.cfg"
                Invoke-WebRequest -Uri $cfgUrl -OutFile $cfgPath -UseBasicParsing
                Write-Log "Downloaded config" "SUCCESS"

                # Run with config
                Write-Log "Applying recommended settings..."
                Start-Process -FilePath $exePath -ArgumentList "$cfgPath /quiet" -Wait
                Write-Log "O&O ShutUp10 settings applied" "SUCCESS"
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "2" {
            try {
                # Download OOSU10 with progress
                Write-Log "Downloading O&O ShutUp10..."
                $hasDownloader = Get-Command 'Start-Download' -ErrorAction SilentlyContinue
                if ($hasDownloader) {
                    Start-Download -Url "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -OutFile $exePath -Description "O&O ShutUp10"
                } else {
                    Invoke-WebRequest -Uri "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -OutFile $exePath -UseBasicParsing
                }
                Write-Log "Downloaded OOSU10.exe" "SUCCESS"

                # Run interactively
                Write-Log "Launching O&O ShutUp10..."
                Start-Process -FilePath $exePath
                Write-Log "O&O ShutUp10 launched" "SUCCESS"
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-AdvancedDebloat {
    $BaseDir = "C:\System_Optimizer\Scripts"
    if (-not (Test-Path $BaseDir)) { New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null }

    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Advanced Debloat Scripts (AIO)" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Block Telemetry (hosts file + firewall rules)"
        Write-Host "      - Blocks 150+ telemetry domains via hosts file"
        Write-Host "      - Adds firewall rules for telemetry IPs"
        Write-Host ""
        Write-Host "  [2] Full Debloater Script"
        Write-Host "      - Comprehensive app removal with whitelist"
        Write-Host "      - Registry cleanup for removed apps"
        Write-Host "      - Privacy protections"
        Write-Host ""
        Write-Host "  [3] Run Both (Block Telemetry + Debloater)"
        Write-Host ""
        Write-Host "  [0] Back"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
        "1" {
            Write-Log "Downloading and running Block Telemetry script..."
            $scriptPath = "$BaseDir\block-telemetry.ps1"
            try {
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/block-telemetry.ps1" -OutFile $scriptPath -UseBasicParsing
                Write-Log "Downloaded block-telemetry.ps1" "SUCCESS"

                Write-Host ""
                Write-Host "This will:" -ForegroundColor Yellow
                Write-Host "  - Add 150+ telemetry domains to hosts file (blocked)"
                Write-Host "  - Create firewall rules to block telemetry IPs"
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"

                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    Write-Log "Running block-telemetry.ps1..."
                    & $scriptPath
                    Write-Log "Block Telemetry script completed" "SUCCESS"
                } else {
                    Write-Log "Cancelled" "INFO"
                }
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "2" {
            Write-Log "Downloading and running Debloater script..."
            $scriptPath = "$BaseDir\DEBLOATER.ps1"
            try {
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/DEBLOATER.ps1" -OutFile $scriptPath -UseBasicParsing
                Write-Log "Downloaded DEBLOATER.ps1" "SUCCESS"

                Write-Host ""
                Write-Host "This will:" -ForegroundColor Yellow
                Write-Host "  - Remove bloatware apps (with whitelist protection)"
                Write-Host "  - Clean up registry keys from removed apps"
                Write-Host "  - Apply privacy protections"
                Write-Host "  - Disable unnecessary scheduled tasks"
                Write-Host ""
                Write-Host "Note: This script has its own interactive menu." -ForegroundColor Cyan
                Write-Host ""
                $confirm = Read-Host "Continue? (Y/N)"

                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    Write-Log "Running DEBLOATER.ps1..."
                    & $scriptPath
                    Write-Log "Debloater script completed" "SUCCESS"
                } else {
                    Write-Log "Cancelled" "INFO"
                }
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "3" {
            Write-Log "Running both scripts..."
            $telemetryPath = "$BaseDir\block-telemetry.ps1"
            $debloatPath = "$BaseDir\DEBLOATER.ps1"

            try {
                # Download both
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/block-telemetry.ps1" -OutFile $telemetryPath -UseBasicParsing
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/DEBLOATER.ps1" -OutFile $debloatPath -UseBasicParsing
                Write-Log "Downloaded both scripts" "SUCCESS"

                Write-Host ""
                Write-Host "This will run both Block Telemetry and Debloater scripts." -ForegroundColor Yellow
                $confirm = Read-Host "Continue? (Y/N)"

                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    Write-Log "Running block-telemetry.ps1..."
                    & $telemetryPath
                    Write-Log "Block Telemetry completed" "SUCCESS"

                    Write-Log "Running DEBLOATER.ps1..."
                    & $debloatPath
                    Write-Log "Debloater completed" "SUCCESS"
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
    'Start-OOShutUp10',
    'Start-AdvancedDebloat'
)
