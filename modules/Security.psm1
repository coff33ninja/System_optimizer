#Requires -Version 5.1
<#
.SYNOPSIS
    Security Module - System Optimizer
.DESCRIPTION
    Provides Windows Defender management and security tool integration.

Exported Functions:
    Set-DefenderControl    - Manage Windows Defender settings
    Disable-Defender       - Disable real-time protection
    Enable-Defender        - Enable real-time protection
    Add-DefenderExclusion  - Add path exclusion
    Remove-Defender        - Advanced Defender removal

Defender Tools Integration:
    - Defender_Tools.exe for advanced control
    - Real-time protection toggle
    - Cloud protection settings
    - Automatic sample submission

Warning:
    Disabling Defender reduces system security.
    Only recommended for advanced users with alternative protection.

Requires Admin: Yes

Version: 1.0.0
#>

function Set-DefenderControl {
    $BaseDir = "C:\System_Optimizer\Defender"
    if (-not (Test-Path $BaseDir)) { New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null }

    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Windows Defender Control" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Quick Actions:" -ForegroundColor Gray
        Write-Host "  [1] Disable Real-time Protection (temporary)"
        Write-Host "  [2] Enable Real-time Protection"
        Write-Host ""
        Write-Host "  Advanced (Registry):" -ForegroundColor Gray
        Write-Host "  [3] Disable Windows Defender (full - via registry)"
        Write-Host "  [4] Enable Windows Defender (restore registry)"
        Write-Host "  [5] Disable Tamper Protection (requires manual step)"
        Write-Host ""
        Write-Host "  Tools:" -ForegroundColor Gray
        Write-Host "  [6] Launch Defender Tools GUI"
        Write-Host "  [7] Add Firewall Exceptions (for activation tools)"
        Write-Host ""
        Write-Host "  Permanent Removal (NOT RECOMMENDED):" -ForegroundColor Red
        Write-Host "  [8] Remove Windows Defender completely"
        Write-Host ""
        Write-Host "  [0] Back"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
        "1" {
            Write-Log "Disabling Real-time Protection..."
            try {
                Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
                Write-Log "Real-time Protection disabled" "SUCCESS"
                Write-Host "Note: This is temporary and may re-enable after reboot or by Windows." -ForegroundColor Yellow
            } catch {
                Write-Log "Failed - Tamper Protection may be enabled. Disable it first in Windows Security." "ERROR"
            }
        }
        "2" {
            Write-Log "Enabling Real-time Protection..."
            try {
                Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
                Write-Log "Real-time Protection enabled" "SUCCESS"
            } catch {
                Write-Log "Failed: $_" "ERROR"
            }
        }
        "3" {
            Write-Log "Disabling Windows Defender via registry..."
            Write-Host ""
            Write-Host "WARNING: This disables Defender at the policy level." -ForegroundColor Yellow
            Write-Host "You may need to disable Tamper Protection first in Windows Security." -ForegroundColor Yellow
            $confirm = Read-Host "Continue? (Y/N)"

            if ($confirm -eq "Y" -or $confirm -eq "y") {
                try {
                    # Disable via Group Policy registry keys
                    $DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
                    if (-not (Test-Path $DefenderPath)) { New-Item -Path $DefenderPath -Force | Out-Null }
                    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force

                    $RTPPath = "$DefenderPath\Real-Time Protection"
                    if (-not (Test-Path $RTPPath)) { New-Item -Path $RTPPath -Force | Out-Null }
                    Set-ItemProperty -Path $RTPPath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force
                    Set-ItemProperty -Path $RTPPath -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force
                    Set-ItemProperty -Path $RTPPath -Name "DisableOnAccessProtection" -Value 1 -Type DWord -Force
                    Set-ItemProperty -Path $RTPPath -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force

                    # Disable SpyNet/MAPS
                    $SpynetPath = "$DefenderPath\Spynet"
                    if (-not (Test-Path $SpynetPath)) { New-Item -Path $SpynetPath -Force | Out-Null }
                    Set-ItemProperty -Path $SpynetPath -Name "SpyNetReporting" -Value 0 -Type DWord -Force
                    Set-ItemProperty -Path $SpynetPath -Name "SubmitSamplesConsent" -Value 2 -Type DWord -Force
                    Set-ItemProperty -Path $SpynetPath -Name "DontReportInfectionInformation" -Value 1 -Type DWord -Force

                    # Disable SmartScreen
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force

                    # Also try the direct method
                    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue

                    Write-Log "Windows Defender disabled via registry" "SUCCESS"
                    Write-Host "A reboot is recommended." -ForegroundColor Yellow
                } catch {
                    Write-Log "Error: $_" "ERROR"
                }
            }
        }
        "4" {
            Write-Log "Enabling Windows Defender via registry..."
            try {
                $DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
                Remove-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Force -ErrorAction SilentlyContinue

                $RTPPath = "$DefenderPath\Real-Time Protection"
                Remove-Item -Path $RTPPath -Recurse -Force -ErrorAction SilentlyContinue

                $SpynetPath = "$DefenderPath\Spynet"
                Remove-Item -Path $SpynetPath -Recurse -Force -ErrorAction SilentlyContinue

                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Warn" -Force

                Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue

                Write-Log "Windows Defender registry settings restored" "SUCCESS"
                Write-Host "A reboot is recommended." -ForegroundColor Yellow
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "5" {
            Write-Log "Tamper Protection Instructions" "SECTION"
            Write-Host ""
            Write-Host "Tamper Protection must be disabled manually:" -ForegroundColor Yellow
            Write-Host "1. Open Windows Security (search 'Windows Security')" -ForegroundColor Cyan
            Write-Host "2. Go to Virus & threat protection" -ForegroundColor Cyan
            Write-Host "3. Click 'Manage settings' under Virus & threat protection settings" -ForegroundColor Cyan
            Write-Host "4. Toggle OFF 'Tamper Protection'" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Opening Windows Security..." -ForegroundColor Gray
            Start-Process "windowsdefender://threatsettings"
        }
        "6" {
            Write-Log "Downloading Defender Tools GUI..."
            $exePath = "$BaseDir\Defender_Tools.exe"
            try {
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/tools/Defender_Tools.exe" -OutFile $exePath -UseBasicParsing
                Write-Log "Downloaded Defender_Tools.exe" "SUCCESS"
                Start-Process -FilePath $exePath
                Write-Log "Defender Tools launched" "SUCCESS"
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "7" {
            Write-Log "Adding Firewall & Defender Exceptions for Activation Tools..."
            try {
                # Programs that need firewall exceptions for activation
                $firewallPrograms = @(
                    "C:\Windows\System32\cmd.exe"
                    "C:\Windows\System32\cscript.exe"
                    "C:\Windows\System32\wscript.exe"
                    "C:\Windows\System32\mshta.exe"
                    "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
                    "C:\Windows\SysWOW64\cmd.exe"
                    "C:\Windows\SysWOW64\cscript.exe"
                    "C:\Windows\SysWOW64\wscript.exe"
                    "C:\Windows\SysWOW64\mshta.exe"
                    "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
                )

                Write-Log "Adding firewall rules for script hosts..."
                foreach ($prog in $firewallPrograms) {
                    if (Test-Path $prog) {
                        $name = Split-Path $prog -Leaf
                        netsh advfirewall firewall add rule name="Allow $name (Activation)" dir=out action=allow program="$prog" enable=yes 2>$null
                        netsh advfirewall firewall add rule name="Allow $name (Activation) In" dir=in action=allow program="$prog" enable=yes 2>$null
                    }
                }
                Write-Log "Firewall rules added" "SUCCESS"

                # Folders to exclude from Defender scanning
                $exclusionPaths = @(
                    $env:TEMP
                    "$env:LOCALAPPDATA\Temp"
                    "C:\System_Optimizer"
                    "C:\Windows\Temp"
                    "$env:USERPROFILE\AppData\Local\Temp"
                    "$env:USERPROFILE\Downloads"
                )

                Write-Log "Adding Defender folder exclusions..."
                foreach ($path in $exclusionPaths) {
                    if (Test-Path $path) {
                        Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
                        Write-Log "Excluded: $path" "SUCCESS"
                    }
                }

                # Processes to exclude from Defender
                $exclusionProcesses = @(
                    "cmd.exe"
                    "cscript.exe"
                    "wscript.exe"
                    "mshta.exe"
                    "powershell.exe"
                    "pwsh.exe"
                )

                Write-Log "Adding Defender process exclusions..."
                foreach ($proc in $exclusionProcesses) {
                    Add-MpPreference -ExclusionProcess $proc -ErrorAction SilentlyContinue
                }
                Write-Log "Process exclusions added" "SUCCESS"

                # File extensions commonly used by activators
                $exclusionExtensions = @(
                    ".cmd"
                    ".bat"
                    ".vbs"
                    ".ps1"
                    ".hta"
                )

                Write-Log "Adding Defender extension exclusions..."
                foreach ($ext in $exclusionExtensions) {
                    Add-MpPreference -ExclusionExtension $ext -ErrorAction SilentlyContinue
                }
                Write-Log "Extension exclusions added" "SUCCESS"

                Write-Host ""
                Write-Host "All exceptions added. Activation tools should now work." -ForegroundColor Green
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "8" {
            Write-Host ""
            Write-Host "WARNING: This will PERMANENTLY remove Windows Defender!" -ForegroundColor Red
            Write-Host "This cannot be undone without reinstalling Windows or a major update." -ForegroundColor Red
            Write-Host "Your system will be unprotected!" -ForegroundColor Red
            Write-Host ""
            $confirm = Read-Host "Type 'REMOVE' to confirm"

            if ($confirm -eq "REMOVE") {
                Write-Log "Removing Windows Defender..."
                try {
                    # Download install_wim_tweak.exe
                    $tweakPath = "$BaseDir\install_wim_tweak.exe"
                    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/tools/install_wim_tweak.exe" -OutFile $tweakPath -UseBasicParsing

                    # Run the removal commands
                    Start-Process -FilePath $tweakPath -ArgumentList "/o /l" -Wait
                    Start-Process -FilePath $tweakPath -ArgumentList "/o /c Windows-Defender /r" -Wait
                    Start-Process -FilePath $tweakPath -ArgumentList "/h /o /l" -Wait

                    # Registry cleanup
                    $DefenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
                    if (-not (Test-Path $DefenderPath)) { New-Item -Path $DefenderPath -Force | Out-Null }
                    Set-ItemProperty -Path $DefenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force

                    # Disable Sense service
                    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Sense" /f 2>$null

                    # Disable MRT reporting
                    $MRTPath = "HKLM:\SOFTWARE\Policies\Microsoft\MRT"
                    if (-not (Test-Path $MRTPath)) { New-Item -Path $MRTPath -Force | Out-Null }
                    Set-ItemProperty -Path $MRTPath -Name "DontReportInfectionInformation" -Value 1 -Type DWord -Force

                    Write-Log "Windows Defender removed" "SUCCESS"
                    Write-Host "A reboot is REQUIRED." -ForegroundColor Yellow
                } catch {
                    Write-Log "Error: $_" "ERROR"
                }
            } else {
                Write-Log "Cancelled" "INFO"
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

function Install-SecurityTools {
    # Check if winget is available
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetPath) {
        Write-Log "Winget not found. Please install App Installer from Microsoft Store." "ERROR"
        Write-Host "Opening Microsoft Store..." -ForegroundColor Yellow
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
        return
    }

    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Security Tools Installation" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Antivirus Solutions:" -ForegroundColor Gray
        Write-Host "  [1] ESET NOD32 Antivirus (Premium)" -ForegroundColor Red
        Write-Host "  [2] Windows Defender (Enable/Configure)" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Anti-Malware Tools:" -ForegroundColor Gray
        Write-Host "  [3] Malwarebytes (Premium Anti-Malware)"
        Write-Host "  [4] AdwCleaner (Adware/PUP Remover)"
        Write-Host ""
        Write-Host "  Network Security:" -ForegroundColor Gray
        Write-Host "  [5] Wireshark (Network Protocol Analyzer)"
        Write-Host "  [6] Nmap (Network Discovery & Security Auditing)"
        Write-Host ""
        Write-Host "  Privacy & Cleanup:" -ForegroundColor Gray
        Write-Host "  [7] BleachBit (System Cleaner & Privacy Tool)"
        Write-Host "  [8] Eraser (Secure File Deletion)"
        Write-Host ""
        Write-Host "  [9] Install All Security Tools (Not Recommended)" -ForegroundColor DarkRed
        Write-Host "  [0] Back to main menu"
        Write-Host ""
        Write-Host "  Note: Only install one antivirus solution to avoid conflicts!" -ForegroundColor Yellow
        Write-Host "  Some installations may require user interaction or license acceptance." -ForegroundColor Gray
        Write-Host ""

        $choice = Read-Host "Select security tool to install"

        switch ($choice) {
            "1" { Install-SingleSecurityTool -PackageId "ESET.Nod32" -Name "ESET NOD32 Antivirus" }
            "2" { Enable-WindowsDefender }
            "3" { Install-SingleSecurityTool -PackageId "Malwarebytes.Malwarebytes" -Name "Malwarebytes" }
            "4" { Install-SingleSecurityTool -PackageId "Malwarebytes.AdwCleaner" -Name "AdwCleaner" }
            "5" { Install-SingleSecurityTool -PackageId "WiresharkFoundation.Wireshark" -Name "Wireshark" }
            "6" { Install-SingleSecurityTool -PackageId "Insecure.Nmap" -Name "Nmap" }
            "7" { Install-SingleSecurityTool -PackageId "BleachBit.BleachBit" -Name "BleachBit" }
            "8" { Install-SingleSecurityTool -PackageId "Eraser.Eraser" -Name "Eraser" }
            "9" { Install-AllSecurityTools }
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

function Install-SingleSecurityTool {
    param(
        [string]$PackageId,
        [string]$Name
    )

    Write-Log "INSTALLING $Name" "SECTION"

    # Special warning for antivirus software
    if ($PackageId -eq "ESET.Nod32") {
        Write-Host ""
        Write-Host "WARNING: Installing ESET NOD32 will:" -ForegroundColor Yellow
        Write-Host "- Require a license key for full functionality" -ForegroundColor Yellow
        Write-Host "- May conflict with Windows Defender" -ForegroundColor Yellow
        Write-Host "- Recommend disabling Windows Defender real-time protection" -ForegroundColor Yellow
        Write-Host ""
        $confirm = Read-Host "Continue with ESET installation? (y/N)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Log "ESET installation cancelled by user" "INFO"
            return
        }
    }

    Write-Host "Installing $Name..." -ForegroundColor Cyan
    Write-Host "Note: You may need to respond to installation prompts." -ForegroundColor Yellow

    try {
        $result = winget install $PackageId --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "$Name installed successfully" "SUCCESS"

            # Post-installation actions
            switch ($PackageId) {
                "ESET.Nod32" {
                    Write-Host ""
                    Write-Host "ESET NOD32 Installation Complete!" -ForegroundColor Green
                    Write-Host "Next steps:" -ForegroundColor Yellow
                    Write-Host "1. Launch ESET NOD32 from Start Menu" -ForegroundColor Gray
                    Write-Host "2. Enter your license key" -ForegroundColor Gray
                    Write-Host "3. Run initial system scan" -ForegroundColor Gray
                    Write-Host "4. Consider disabling Windows Defender to avoid conflicts" -ForegroundColor Gray
                }
                "Malwarebytes.Malwarebytes" {
                    Write-Host ""
                    Write-Host "Malwarebytes installed! Consider running a full system scan." -ForegroundColor Green
                }
                "Malwarebytes.AdwCleaner" {
                    Write-Host ""
                    Write-Host "AdwCleaner installed! Run it to remove adware and PUPs." -ForegroundColor Green
                }
            }
        } else {
            Write-Log "$Name installation failed or already installed: $result" "WARNING"
        }
    } catch {
        Write-Log "Error installing $Name`: $_" "ERROR"
    }
}

function Install-AllSecurityTools {
    Write-Host ""
    Write-Host "WARNING: Installing multiple antivirus solutions can cause conflicts!" -ForegroundColor Red
    Write-Host "This will install ALL security tools including ESET and enable Defender." -ForegroundColor Red
    Write-Host "This is NOT recommended for production systems." -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Are you absolutely sure? Type 'INSTALL ALL' to confirm"

    if ($confirm -eq "INSTALL ALL") {
        Write-Log "Installing all security tools (user confirmed)" "WARNING"
        Write-Host ""
        Write-Host "Note: You may need to respond to installation prompts for each tool." -ForegroundColor Yellow
        Write-Host "Some installations may require user interaction or license acceptance." -ForegroundColor Yellow
        Write-Host ""

        $securityPackages = @(
            @{Id="ESET.Nod32"; Name="ESET NOD32"},
            @{Id="Malwarebytes.Malwarebytes"; Name="Malwarebytes"},
            @{Id="Malwarebytes.AdwCleaner"; Name="AdwCleaner"},
            @{Id="WiresharkFoundation.Wireshark"; Name="Wireshark"},
            @{Id="Insecure.Nmap"; Name="Nmap"},
            @{Id="BleachBit.BleachBit"; Name="BleachBit"},
            @{Id="Eraser.Eraser"; Name="Eraser"}
        )

        $total = $securityPackages.Count
        $current = 0
        $success = 0

        foreach ($pkg in $securityPackages) {
            $current++
            Write-Host "[$current/$total] Installing $($pkg.Name)..." -ForegroundColor Cyan

            try {
                $result = winget install $pkg.Id --accept-package-agreements --accept-source-agreements 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "$($pkg.Name) installed" "SUCCESS"
                    $success++
                } else {
                    Write-Log "$($pkg.Name) failed or already installed" "WARNING"
                    Write-Log "Output: $result" "DEBUG"
                }
            } catch {
                Write-Log "Error installing $($pkg.Name): $_" "WARNING"
                Write-Log "Output: $result" "DEBUG"
            }
        }

        Write-Host ""
        Write-Log "Security tools installation complete: $success/$total succeeded" "SUCCESS"
        Write-Host ""
        Write-Host "IMPORTANT: You now have multiple security tools installed!" -ForegroundColor Red
        Write-Host "Consider keeping only one antivirus solution active to avoid conflicts." -ForegroundColor Yellow

    } else {
        Write-Log "Bulk installation cancelled" "INFO"
    }
}

function Enable-WindowsDefender {
    Write-Log "CONFIGURING WINDOWS DEFENDER" "SECTION"

    try {
        # Enable real-time protection
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        Write-Log "Windows Defender real-time protection enabled" "SUCCESS"

        # Update definitions
        Write-Host "Updating Windows Defender definitions..." -ForegroundColor Cyan
        Update-MpSignature -ErrorAction SilentlyContinue
        Write-Log "Windows Defender definitions updated" "SUCCESS"

        # Configure enhanced protection
        Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction SilentlyContinue
        Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
        Write-Log "Enhanced protection features enabled" "SUCCESS"

        Write-Host ""
        Write-Host "Windows Defender is now fully enabled and configured!" -ForegroundColor Green
        Write-Host "Consider running a full system scan from Windows Security." -ForegroundColor Yellow

    } catch {
        Write-Log "Error configuring Windows Defender: $_" "ERROR"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Set-DefenderControl',
    'Install-SecurityTools',
    'Install-SingleSecurityTool',
    'Install-AllSecurityTools',
    'Enable-WindowsDefender'
)
