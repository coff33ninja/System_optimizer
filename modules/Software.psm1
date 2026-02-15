# ============================================================================
# Software Module - System Optimizer
# ============================================================================

function Start-PatchMyPC {
    $BaseDir = "C:\System_Optimizer\Updater"
    $PreSelectDir = "$BaseDir\PRE-SELECT"
    $SelfSelectDir = "$BaseDir\SELF-SELECT"

    # Create directories
    if (-not (Test-Path $PreSelectDir)) { New-Item -ItemType Directory -Path $PreSelectDir -Force | Out-Null }
    if (-not (Test-Path $SelfSelectDir)) { New-Item -ItemType Directory -Path $SelfSelectDir -Force | Out-Null }

    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Software Installation" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  PatchMyPC:" -ForegroundColor Gray
        Write-Host "  [1] Pre-Selected Apps (Common software)"
        Write-Host "  [2] Self-Select Apps (Choose your own)"
        Write-Host ""
        Write-Host "  Winget (Windows Package Manager):" -ForegroundColor Gray
        Write-Host "  [3] Essential Apps (Browser, 7zip, VLC, Reader)"
        Write-Host "  [4] All Runtimes (.NET, VC++, DirectX, Java)"
        Write-Host "  [5] Developer Tools (VS Code, Git, PS7)"
        Write-Host "  [6] Gaming Apps (Steam, Epic, Discord)"
        Write-Host "  [7] Security Tools (Individual Selection Menu)" -ForegroundColor Red
        Write-Host "  [8] Custom Selection (GUI)" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Chocolatey:" -ForegroundColor Gray
        Write-Host "  [9] Install Chocolatey"
        Write-Host "  [10] Choco Essential Apps"
        Write-Host "  [11] Chocolatey GUI"
        Write-Host ""
        Write-Host "  Remote Desktop:" -ForegroundColor Gray
        Write-Host "  [12] Install RustDesk"
        Write-Host "  [13] Install AnyDesk"
        Write-Host ""
        Write-Host "  [0] Back"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
        "1" {
            Write-Log "Downloading PatchMyPC (Pre-Selected)..."
            $exePath = "$PreSelectDir\PatchMyPC.exe"
            $iniPath = "$PreSelectDir\PatchMyPC.ini"

            try {
                # Download exe with progress
                $exeUrl = "https://patchmypc.com/freeupdater/PatchMyPC.exe"
                $hasDownloader = Get-Command 'Start-Download' -ErrorAction SilentlyContinue
                if ($hasDownloader) {
                    Start-Download -Url $exeUrl -OutFile $exePath -Description "PatchMyPC.exe"
                } else {
                    Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing
                }
                Write-Log "Downloaded PatchMyPC.exe" "SUCCESS"

                # Download pre-configured ini
                $iniUrl = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/PatchMyPC.ini"
                Invoke-WebRequest -Uri $iniUrl -OutFile $iniPath -UseBasicParsing
                Write-Log "Downloaded PatchMyPC.ini (pre-selected)" "SUCCESS"

                # Run PatchMyPC and wait for it to close
                Write-Log "Launching PatchMyPC (waiting for it to close)..."
                Write-Host "PatchMyPC is running. Close it when done to continue..." -ForegroundColor Yellow
                $proc = Start-Process -FilePath $exePath -WorkingDirectory $PreSelectDir -PassThru
                $proc.WaitForExit()
                Write-Log "PatchMyPC closed" "SUCCESS"

                # Check for Adobe Reader and set as PDF default
                Set-AdobeReaderAsDefault
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "2" {
            Write-Log "Downloading PatchMyPC (Self-Select)..."
            $exePath = "$SelfSelectDir\PatchMyPC.exe"

            try {
                # Download exe with progress
                $exeUrl = "https://patchmypc.com/freeupdater/PatchMyPC.exe"
                $hasDownloader = Get-Command 'Start-Download' -ErrorAction SilentlyContinue
                if ($hasDownloader) {
                    Start-Download -Url $exeUrl -OutFile $exePath -Description "PatchMyPC.exe"
                } else {
                    Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing
                }
                Write-Log "Downloaded PatchMyPC.exe" "SUCCESS"

                # Run PatchMyPC and wait for it to close
                Write-Log "Launching PatchMyPC (waiting for it to close)..."
                Write-Host "PatchMyPC is running. Close it when done to continue..." -ForegroundColor Yellow
                $proc = Start-Process -FilePath $exePath -WorkingDirectory $SelfSelectDir -PassThru
                $proc.WaitForExit()
                Write-Log "PatchMyPC closed" "SUCCESS"

                # Check for Adobe Reader and set as PDF default
                Set-AdobeReaderAsDefault
            } catch {
                Write-Log "Error: $_" "ERROR"
            }
        }
        "3" { Install-WingetPreset -Preset "essential" }
        "4" { Install-WingetPreset -Preset "runtimes" }
        "5" { Install-WingetPreset -Preset "developer" }
        "6" { Install-WingetPreset -Preset "gaming" }
        "7" { Install-SecurityTools }
        "8" { Show-WingetGUI }
        "9" { Install-Chocolatey }
        "10" { Install-ChocoEssentials }
        "11" { Install-ChocoGUI }
        "12" { Install-RustDesk }
        "13" { Install-AnyDesk }
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

function Set-AdobeReaderAsDefault {
    Write-Log "Checking for Adobe Acrobat Reader..."

    # Common Adobe Reader/Acrobat installation paths
    $adobePaths = @(
        "${env:ProgramFiles}\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
        "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
        "${env:ProgramFiles}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
        "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
        "${env:ProgramFiles}\Adobe\Reader 11.0\Reader\AcroRd32.exe"
        "${env:ProgramFiles(x86)}\Adobe\Reader 11.0\Reader\AcroRd32.exe"
        "${env:ProgramFiles}\Adobe\Acrobat DC\Acrobat\x86\Acrobat\Acrobat.exe"
        "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\x86\Acrobat\Acrobat.exe"
    )

    $adobeExe = $null
    foreach ($path in $adobePaths) {
        if (Test-Path $path) {
            $adobeExe = $path
            break
        }
    }

    if (-not $adobeExe) {
        Write-Log "Adobe Reader not found - skipping PDF default" "INFO"
        return
    }

    Write-Log "Adobe Reader found: $adobeExe" "SUCCESS"
    Write-Log "Setting Adobe Reader as default PDF viewer..."

    try {
        # Set file association via registry (user level)
        $progId = "AcroExch.Document.DC"

        # Check if Adobe's ProgID exists
        $adobeProgId = Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\AcroExch.Document.DC" -ErrorAction SilentlyContinue
        if (-not $adobeProgId) {
            $progId = "AcroExch.Document"
            $adobeProgId = Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\AcroExch.Document" -ErrorAction SilentlyContinue
        }

        if ($adobeProgId) {
            # Set .pdf association
            $pdfPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\UserChoice"

            # Remove existing UserChoice (requires special handling due to hash protection)
            try {
                Remove-Item -Path $pdfPath -Force -Recurse -ErrorAction Stop
                Write-Log "Removed existing PDF UserChoice" "SUCCESS"
            } catch {
                # UserChoice may be protected or not exist - continue with association
                $null
            }

            # Method 1: Try using DISM/deployment tools approach
            $assocPath = "HKCU:\SOFTWARE\Classes\.pdf"
            if (-not (Test-Path $assocPath)) { New-Item -Path $assocPath -Force | Out-Null }
            Set-ItemProperty -Path $assocPath -Name "(Default)" -Value $progId -Force

            # Set OpenWithProgids
            $openWithPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\OpenWithProgids"
            if (-not (Test-Path $openWithPath)) { New-Item -Path $openWithPath -Force | Out-Null }
            Set-ItemProperty -Path $openWithPath -Name $progId -Value ([byte[]]@()) -Force

            # Remove Edge as handler if present
            Remove-ItemProperty -Path $openWithPath -Name "AppXd4nrz8ff68srnhf9t5a8sbjyar1cr723" -Force -ErrorAction SilentlyContinue

            Write-Log "Adobe Reader set as PDF handler" "SUCCESS"
            Write-Host ""
            Write-Host "Note: Windows 10/11 may require you to confirm the default app in Settings." -ForegroundColor Yellow
            Write-Host "Opening Default Apps settings..." -ForegroundColor Gray
            Start-Process "ms-settings:defaultapps"

        } else {
            Write-Log "Adobe Reader ProgID not found in registry" "WARNING"
        }
    } catch {
        Write-Log "Error setting PDF default: $_" "ERROR"
    }
}

function Install-WingetPreset {
    param([string]$Preset)

    # Check if winget is available
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetPath) {
        Write-Log "Winget not found. Please install App Installer from Microsoft Store." "ERROR"
        Write-Host "Opening Microsoft Store..." -ForegroundColor Yellow
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
        return
    }

    $packages = switch ($Preset) {
        "essential" {
            @(
                "Mozilla.Firefox",
                "7zip.7zip",
                "VideoLAN.VLC",
                "Notepad++.Notepad++",
                "Adobe.Acrobat.Reader.64-bit",
                "Microsoft.VCRedist.2015+.x64",
                "Microsoft.VCRedist.2015+.x86"
            )
        }
        "runtimes" {
            @(
                "Microsoft.DotNet.Runtime.8",
                "Microsoft.DotNet.Runtime.7",
                "Microsoft.DotNet.Runtime.6",
                "Microsoft.DotNet.DesktopRuntime.8",
                "Microsoft.DotNet.DesktopRuntime.7",
                "Microsoft.DotNet.DesktopRuntime.6",
                "Microsoft.VCRedist.2015+.x64",
                "Microsoft.VCRedist.2015+.x86",
                "Microsoft.VCRedist.2013.x64",
                "Microsoft.VCRedist.2013.x86",
                "Microsoft.VCRedist.2012.x64",
                "Microsoft.VCRedist.2012.x86",
                "Microsoft.VCRedist.2010.x64",
                "Microsoft.VCRedist.2010.x86",
                "Microsoft.DirectX",
                "Oracle.JavaRuntimeEnvironment"
            )
        }
        "developer" {
            @(
                "Microsoft.PowerShell",
                "Git.Git",
                "Microsoft.VisualStudioCode",
                "Microsoft.WindowsTerminal",
                "Python.Python.3.11"
            )
        }
        "gaming" {
            @(
                "Valve.Steam",
                "EpicGames.EpicGamesLauncher",
                "Discord.Discord",
                "Nvidia.GeForceExperience"
            )
        }
    }

    Write-Log "Installing $Preset packages via Winget..." "SECTION"
    Write-Host "Note: Some packages may require user interaction during installation." -ForegroundColor Yellow
    $total = $packages.Count
    $current = 0
    $success = 0
    $failed = @()

    foreach ($pkg in $packages) {
        $current++
        Write-Host "[$current/$total] Installing $pkg..." -ForegroundColor Cyan

        winget install $pkg --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Installed: $pkg" "SUCCESS"
            $success++
        } else {
            Write-Log "Failed or already installed: $pkg" "WARNING"
            $failed += $pkg
        }
    }

    Write-Host ""
    Write-Log "Installation complete: $success/$total succeeded" "SUCCESS"
    if ($failed.Count -gt 0) {
        Write-Host "Failed/Skipped: $($failed -join ', ')" -ForegroundColor Yellow
    }

    # Check for Adobe Reader and set as default
    if ($Preset -eq "essential") {
        Set-AdobeReaderAsDefault
    }
}

function Show-WingetGUI {
    Write-Log "WINGET PACKAGE SELECTOR" "SECTION"

    # Check winget
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetPath) {
        Write-Log "Winget not found" "ERROR"
        return
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Winget Package Installer"
    $form.Size = New-Object System.Drawing.Size(500, 600)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    # Package list with checkboxes
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Location = New-Object System.Drawing.Point(10, 10)
    $checkedListBox.Size = New-Object System.Drawing.Size(460, 450)
    $checkedListBox.CheckOnClick = $true

    # Add packages by category
    $packages = @(
        "--- BROWSERS ---",
        "Mozilla.Firefox|Firefox",
        "Google.Chrome|Chrome",
        "BraveSoftware.BraveBrowser|Brave",
        "--- UTILITIES ---",
        "7zip.7zip|7-Zip",
        "Notepad++.Notepad++|Notepad++",
        "VideoLAN.VLC|VLC Player",
        "voidtools.Everything|Everything Search",
        "--- DOCUMENTS ---",
        "Adobe.Acrobat.Reader.64-bit|Adobe Reader",
        "SumatraPDF.SumatraPDF|SumatraPDF",
        "--- DEVELOPMENT ---",
        "Microsoft.PowerShell|PowerShell 7",
        "Git.Git|Git",
        "Microsoft.VisualStudioCode|VS Code",
        "Microsoft.WindowsTerminal|Windows Terminal",
        "Python.Python.3.11|Python 3.11",
        "--- RUNTIMES ---",
        "Microsoft.DotNet.Runtime.8|.NET 8 Runtime",
        "Microsoft.DotNet.DesktopRuntime.8|.NET 8 Desktop",
        "Microsoft.VCRedist.2015+.x64|VC++ 2015-2022 x64",
        "Microsoft.VCRedist.2015+.x86|VC++ 2015-2022 x86",
        "Oracle.JavaRuntimeEnvironment|Java Runtime",
        "--- REMOTE ---",
        "RustDesk.RustDesk|RustDesk",
        "AnyDeskSoftwareGmbH.AnyDesk|AnyDesk",
        "--- GAMING ---",
        "Valve.Steam|Steam",
        "Discord.Discord|Discord",
        "EpicGames.EpicGamesLauncher|Epic Games"
    )

    foreach ($pkg in $packages) {
        if ($pkg.StartsWith("---")) {
            $checkedListBox.Items.Add($pkg)
        } else {
            $parts = $pkg.Split("|")
            $checkedListBox.Items.Add("$($parts[1]) [$($parts[0])]")
        }
    }

    $form.Controls.Add($checkedListBox)

    # Select All button
    $selectAllBtn = New-Object System.Windows.Forms.Button
    $selectAllBtn.Location = New-Object System.Drawing.Point(10, 470)
    $selectAllBtn.Size = New-Object System.Drawing.Size(100, 30)
    $selectAllBtn.Text = "Select All"
    $selectAllBtn.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            if (-not $checkedListBox.Items[$i].ToString().StartsWith("---")) {
                $checkedListBox.SetItemChecked($i, $true)
            }
        }
    })
    $form.Controls.Add($selectAllBtn)

    # Clear button
    $clearBtn = New-Object System.Windows.Forms.Button
    $clearBtn.Location = New-Object System.Drawing.Point(120, 470)
    $clearBtn.Size = New-Object System.Drawing.Size(100, 30)
    $clearBtn.Text = "Clear All"
    $clearBtn.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $false)
        }
    })
    $form.Controls.Add($clearBtn)

    # Install button
    $installBtn = New-Object System.Windows.Forms.Button
    $installBtn.Location = New-Object System.Drawing.Point(350, 470)
    $installBtn.Size = New-Object System.Drawing.Size(120, 30)
    $installBtn.Text = "Install Selected"
    $installBtn.BackColor = [System.Drawing.Color]::LightGreen
    $installBtn.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })
    $form.Controls.Add($installBtn)

    # Cancel button
    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Location = New-Object System.Drawing.Point(350, 510)
    $cancelBtn.Size = New-Object System.Drawing.Size(120, 30)
    $cancelBtn.Text = "Cancel"
    $cancelBtn.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })
    $form.Controls.Add($cancelBtn)

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedPackages = @()
        foreach ($item in $checkedListBox.CheckedItems) {
            if (-not $item.ToString().StartsWith("---")) {
                # Extract package ID from "[id]"
                if ($item -match '\[([^\]]+)\]') {
                    $selectedPackages += $matches[1]
                }
            }
        }

        if ($selectedPackages.Count -gt 0) {
            Write-Log "Installing $($selectedPackages.Count) packages..." "SECTION"
            foreach ($pkg in $selectedPackages) {
                Write-Host "Installing $pkg..." -ForegroundColor Cyan
                winget install $pkg --accept-package-agreements --accept-source-agreements
            }
            Write-Log "Installation complete" "SUCCESS"

            # Check for Adobe Reader
            if ($selectedPackages -contains "Adobe.Acrobat.Reader.64-bit") {
                Set-AdobeReaderAsDefault
            }
        }
    }
}

function Install-Chocolatey {
    Write-Log "INSTALLING CHOCOLATEY" "SECTION"

    # Check if already installed
    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if ($chocoPath) {
        Write-Log "Chocolatey is already installed" "SUCCESS"
        choco --version
        return
    }

    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-Null
        Write-Log "Chocolatey installed successfully" "SUCCESS"
        Write-Host "Please restart PowerShell to use choco commands." -ForegroundColor Yellow
    } catch {
        Write-Log "Failed to install Chocolatey: $_" "ERROR"
    }
}

function Install-ChocoEssentials {
    Write-Log "INSTALLING CHOCO ESSENTIALS" "SECTION"

    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoPath) {
        Write-Log "Chocolatey not installed. Run option 6 first." "ERROR"
        return
    }

    $packages = @(
        "firefox",
        "7zip",
        "vlc",
        "notepadplusplus",
        "adobereader",
        "vcredist-all",
        "dotnet-desktopruntime"
    )

    Write-Host "Installing essential packages via Chocolatey..." -ForegroundColor Cyan
    foreach ($pkg in $packages) {
        Write-Host "Installing $pkg..." -ForegroundColor Gray
        choco install $pkg -y --no-progress
    }

    Write-Log "Chocolatey essentials installed" "SUCCESS"
}

function Install-RustDesk {
    Write-Log "INSTALLING RUSTDESK" "SECTION"

    $installed = $false

    # Try winget first
    Write-Log "Trying winget..."
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        try {
            $result = winget install RustDesk.RustDesk --accept-package-agreements --accept-source-agreements 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "RustDesk installed via winget" "SUCCESS"
                $installed = $true
            } else {
                Write-Log "Winget install failed: $result" "WARNING"
            }
        } catch {
            Write-Log "Winget error: $_" "WARNING"
        }
    } else {
        Write-Log "Winget not found" "WARNING"
    }

    # Try choco if winget failed
    if (-not $installed) {
        Write-Log "Trying chocolatey..."
        $chocoPath = Get-Command choco -ErrorAction SilentlyContinue

        # Install choco if not present
        if (-not $chocoPath) {
            Write-Log "Chocolatey not found, installing..."
            try {
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-Null

                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                Write-Log "Chocolatey installed" "SUCCESS"
                $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Failed to install Chocolatey: $_" "ERROR"
            }
        }

        if ($chocoPath) {
            try {
                choco install rustdesk -y 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "RustDesk installed via Chocolatey" "SUCCESS"
                    $installed = $true
                } else {
                    Write-Log "Chocolatey install failed" "WARNING"
                }
            } catch {
                Write-Log "Chocolatey error: $_" "WARNING"
            }
        }
    }

    # Install winget if choco worked but winget was missing
    if ($installed -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "Installing winget via Chocolatey..."
        try {
            choco install winget -y 2>&1 | Out-Null
            Write-Log "Winget installed" "SUCCESS"
        } catch {
            Write-Log "Could not install winget: $_" "WARNING"
        }
    }

    if (-not $installed) {
        Write-Log "All installation methods failed" "ERROR"
        Write-Host "Manual download: https://rustdesk.com/download" -ForegroundColor Cyan
    } else {
        # Create desktop shortcut for RustDesk
        New-RustDeskShortcut
    }
}

function Install-AnyDesk {
    Write-Log "INSTALLING ANYDESK" "SECTION"

    $installed = $false

    # Try winget first
    Write-Log "Trying winget..."
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        try {
            $result = winget install AnyDesk.AnyDesk --accept-package-agreements --accept-source-agreements 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "AnyDesk installed via winget" "SUCCESS"
                $installed = $true
            } else {
                Write-Log "Winget install failed: $result" "WARNING"
            }
        } catch {
            Write-Log "Winget error: $_" "WARNING"
        }
    } else {
        Write-Log "Winget not found" "WARNING"
    }

    # Try choco if winget failed
    if (-not $installed) {
        Write-Log "Trying chocolatey..."
        $chocoPath = Get-Command choco -ErrorAction SilentlyContinue

        # Install choco if not present
        if (-not $chocoPath) {
            Write-Log "Chocolatey not found, installing..."
            try {
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-Null

                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                Write-Log "Chocolatey installed" "SUCCESS"
                $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Failed to install Chocolatey: $_" "ERROR"
            }
        }

        if ($chocoPath) {
            try {
                choco install anydesk -y 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "AnyDesk installed via Chocolatey" "SUCCESS"
                    $installed = $true
                } else {
                    Write-Log "Chocolatey install failed" "WARNING"
                }
            } catch {
                Write-Log "Chocolatey error: $_" "WARNING"
            }
        }
    }

    # Install winget if choco worked but winget was missing
    if ($installed -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "Installing winget via Chocolatey..."
        try {
            choco install winget -y 2>&1 | Out-Null
            Write-Log "Winget installed" "SUCCESS"
        } catch {
            Write-Log "Could not install winget: $_" "WARNING"
        }
    }

    if (-not $installed) {
        Write-Log "All installation methods failed" "ERROR"
        Write-Host "Manual download: https://anydesk.com/download" -ForegroundColor Cyan
    } else {
        # Create desktop shortcut for AnyDesk
        New-AnyDeskShortcut
    }
}

function New-RustDeskShortcut {
    Write-Log "Creating RustDesk desktop shortcut..."

    # Common installation paths for RustDesk
    $searchPaths = @(
        "$env:ProgramFiles\RustDesk\rustdesk.exe"
        "${env:ProgramFiles(x86)}\RustDesk\rustdesk.exe"
        "$env:LOCALAPPDATA\RustDesk\rustdesk.exe"
        "$env:APPDATA\RustDesk\rustdesk.exe"
        "C:\Program Files\RustDesk\rustdesk.exe"
        "C:\Program Files (x86)\RustDesk\rustdesk.exe"
    )

    # Also search common choco/winget install locations
    $chocoPath = "C:\ProgramData\chocolatey\lib\rustdesk\tools\rustdesk.exe"
    if (Test-Path $chocoPath) { $searchPaths += $chocoPath }

    # Find the exe
    $rustdeskExe = $null
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $rustdeskExe = $path
            break
        }
    }

    # If not found in common paths, search more broadly
    if (-not $rustdeskExe) {
        Write-Log "Searching for RustDesk installation..."
        $found = Get-ChildItem -Path "C:\Program Files","C:\Program Files (x86)",$env:LOCALAPPDATA,$env:APPDATA,"C:\ProgramData\chocolatey" -Recurse -Filter "rustdesk.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $rustdeskExe = $found.FullName
        }
    }

    if ($rustdeskExe) {
        Write-Log "Found RustDesk at: $rustdeskExe"

        # Create shortcut on desktop
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = "$desktopPath\RustDesk.lnk"

        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $rustdeskExe
        $shortcut.WorkingDirectory = Split-Path $rustdeskExe
        $shortcut.Description = "RustDesk Remote Desktop"
        $shortcut.Save()

        Write-Log "Desktop shortcut created: $shortcutPath" "SUCCESS"
    } else {
        Write-Log "Could not find RustDesk executable to create shortcut" "WARNING"
    }
}

function New-AnyDeskShortcut {
    Write-Log "Creating AnyDesk desktop shortcut..."

    # Common installation paths for AnyDesk
    $searchPaths = @(
        "$env:ProgramFiles\AnyDesk\AnyDesk.exe"
        "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe"
        "$env:LOCALAPPDATA\AnyDesk\AnyDesk.exe"
        "$env:APPDATA\AnyDesk\AnyDesk.exe"
        "C:\Program Files\AnyDesk\AnyDesk.exe"
        "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"
        "$env:ProgramData\chocolatey\lib\anydesk\tools\AnyDesk.exe"
    )

    # Find the exe
    $anydeskExe = $null
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $anydeskExe = $path
            break
        }
    }

    # If not found in common paths, search more broadly
    if (-not $anydeskExe) {
        Write-Log "Searching for AnyDesk installation..."
        $found = Get-ChildItem -Path "C:\Program Files","C:\Program Files (x86)",$env:LOCALAPPDATA,$env:APPDATA,"C:\ProgramData\chocolatey" -Recurse -Filter "AnyDesk.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $anydeskExe = $found.FullName
        }
    }

    if ($anydeskExe) {
        Write-Log "Found AnyDesk at: $anydeskExe"

        # Create shortcut on desktop
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = "$desktopPath\AnyDesk.lnk"

        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $anydeskExe
        $shortcut.WorkingDirectory = Split-Path $anydeskExe
        $shortcut.Description = "AnyDesk Remote Desktop"
        $shortcut.Save()

        Write-Log "Desktop shortcut created: $shortcutPath" "SUCCESS"
    } else {
        Write-Log "Could not find AnyDesk executable to create shortcut" "WARNING"
    }
}

function Start-OfficeTool {
    Write-Log "LAUNCHING OFFICE TOOL PLUS" "SECTION"

    $BaseDir = "C:\System_Optimizer\OfficeTool"
    if (-not (Test-Path $BaseDir)) { New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null }

    # Detect architecture
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    Write-Log "Detected architecture: $arch"

    $zipPath = "$BaseDir\OfficeTool.zip"
    $extractPath = "$BaseDir"
    $downloadUrl = $null

    Write-Host ""
    Write-Host "This will download and launch Office Tool Plus." -ForegroundColor Yellow
    Write-Host "You can use it to install/configure Microsoft Office." -ForegroundColor Yellow
    Write-Host ""

    try {
        # Try to get latest release from GitHub API
        Write-Log "Checking for latest Office Tool Plus release..."
        try {
            $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/YerongAI/Office-Tool/releases/latest" -UseBasicParsing -TimeoutSec 10
            $latestVersion = $releaseInfo.tag_name
            Write-Log "Latest version: $latestVersion" "SUCCESS"

            # Find the runtime zip for our architecture
            $asset = $releaseInfo.assets | Where-Object {
                $_.name -like "*with_runtime*$arch.zip"
            } | Select-Object -First 1

            if ($asset) {
                $downloadUrl = $asset.browser_download_url
                Write-Log "Found download URL: $($asset.name)"
            }
        } catch {
            Write-Log "Could not fetch latest release, using fallback URL" "WARNING"
        }

        # Fallback to known working version if API failed
        if (-not $downloadUrl) {
            $downloadUrl = "https://github.com/YerongAI/Office-Tool/releases/download/v10.29.50.0/Office_Tool_with_runtime_v10.29.50.0_$arch.zip"
            Write-Log "Using fallback URL: v10.29.50.0"
        }

        # Download
        Write-Log "Downloading Office Tool Plus ($arch)..."
        $hasDownloader = Get-Command 'Start-Download' -ErrorAction SilentlyContinue
        if ($hasDownloader) {
            Start-Download -Url $downloadUrl -OutFile $zipPath -Description "Office Tool Plus ($arch)"
        } else {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        }
        Write-Log "Downloaded Office Tool Plus" "SUCCESS"

        # Extract
        Write-Log "Extracting..."
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Write-Log "Extracted Office Tool Plus" "SUCCESS"

        # Find and run the exe
        $otpExe = Get-ChildItem -Path $extractPath -Recurse -Filter "Office Tool Plus.exe" | Select-Object -First 1
        if ($otpExe) {
            Write-Log "Launching Office Tool Plus..."
            Start-Process -FilePath $otpExe.FullName
            Write-Log "Office Tool Plus launched" "SUCCESS"
        } else {
            Write-Log "Could not find Office Tool Plus.exe" "ERROR"
        }

        # Cleanup zip
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

    } catch {
        Write-Log "Error: $_" "ERROR"
        Write-Log "Trying web installer fallback..." "WARNING"
        try {
            Invoke-Expression (Invoke-RestMethod https://officetool.plus) | Out-Null
            Write-Log "Office Tool Plus launched via web installer" "SUCCESS"
        } catch {
            Write-Log "Web installer also failed: $_" "ERROR"
            Write-Host "Manual download: https://otp.landian.vip/" -ForegroundColor Cyan
        }
    }
}

function Start-MAS {
    Write-Log "LAUNCHING MICROSOFT ACTIVATION SCRIPT" "SECTION"

    Write-Host ""
    Write-Host "This will launch the Microsoft Activation Script (MAS)." -ForegroundColor Yellow
    Write-Host "A new window will open with activation options." -ForegroundColor Yellow
    Write-Host ""

    try {
        # Updated MAS link as of 2025
        Write-Log "Downloading and running MAS from get.activated.win..."
        Invoke-Expression (Invoke-RestMethod https://get.activated.win) | Out-Null
        Write-Log "MAS launched successfully" "SUCCESS"
    } catch {
        Write-Log "Primary method failed, trying alternative..." "WARNING"
        try {
            # Alternative method with DoH
            Invoke-Expression (curl.exe -s --doh-url https://1.1.1.1/dns-query https://get.activated.win | Out-String) | Out-Null
            Write-Log "MAS launched via alternative method" "SUCCESS"
        } catch {
            Write-Log "Failed to launch MAS: $_" "ERROR"
            Write-Host "Manual method: Open PowerShell and run:" -ForegroundColor Yellow
            Write-Host "irm https://get.activated.win | iex" -ForegroundColor Cyan
        }
    }
}

function Install-ChocoGUI {
    Write-Log "INSTALLING CHOCOLATEY GUI" "SECTION"

    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoPath) {
        Write-Log "Chocolatey not installed. Install Chocolatey first." "ERROR"
        return
    }

    Write-Host "Installing Chocolatey GUI..." -ForegroundColor Cyan
    choco install chocolateygui -y

    Write-Log "Chocolatey GUI installed" "SUCCESS"
    Write-Host "You can now run 'chocolateygui' from Start Menu" -ForegroundColor Green
}

# Export functions
Export-ModuleMember -Function @(
    'Start-PatchMyPC',
    'Set-AdobeReaderAsDefault',
    'Install-WingetPreset',
    'Show-WingetGUI',
    'Install-Chocolatey',
    'Install-ChocoEssentials',
    'Install-ChocoGUI',
    'Install-RustDesk',
    'Install-AnyDesk',
    'New-RustDeskShortcut',
    'New-AnyDeskShortcut',
    'Start-OfficeTool',
    'Start-MAS'
)

