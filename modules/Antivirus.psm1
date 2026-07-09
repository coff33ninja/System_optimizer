#Requires -Version 5.1
<#
.SYNOPSIS
    Antivirus Management Module - System Optimizer
.DESCRIPTION
    Provides antivirus solution management including ESET direct CDN installation,
    Windows Defender configuration routing, and system AV detection.

    All ESET products (EAV/EIS/ESSP/ESU/ESBS/ESSV) are downloaded directly from
    the official ESET CDN with architecture auto-detection (x64/ARM64/x86).

Exported Functions:
    Show-AntivirusMenu    - Main antivirus management submenu
    Show-EsetMenu         - ESET product selection and installation submenu
    Install-EsetProduct   - Download and install an ESET product from CDN
    Get-SystemArch        - Detect system processor architecture
    Get-InstalledAvProducts - Scan for installed antivirus products

    See docs/ESET_Installer_Links_and_Version_History.md for full ESET
    product reference, CDN URLs, version history, and binary analysis.

Requires Admin: Yes
Version: 1.0.0
#>

# ============================================================================
# ARCHITECTURE DETECTION
# ============================================================================

function Get-SystemArch {
    <#
    .SYNOPSIS
        Detects the system processor architecture.
    .DESCRIPTION
        Returns "x64", "arm64", or "x86" based on $env:PROCESSOR_ARCHITECTURE
        with fallback to [Environment]::Is64BitOperatingSystem.
    #>
    [CmdletBinding()]
    param()

    $rawArch = $env:PROCESSOR_ARCHITECTURE

    if ($rawArch -eq 'ARM64') {
        return 'arm64'
    } elseif ($rawArch -eq 'AMD64' -or $rawArch -eq 'IA64') {
        return 'x64'
    } elseif ([Environment]::Is64BitOperatingSystem) {
        return 'x64'
    } else {
        return 'x86'
    }
}

function Get-ArchDisplayName {
    param([string]$Arch)

    switch ($Arch) {
        'x64'   { return 'x64 (Intel/AMD 64-bit)' }
        'arm64' { return 'ARM64 (Windows on ARM)' }
        'x86'   { return 'x86 (32-bit)' }
        default { return $Arch }
    }
}

# ============================================================================
# ESET PRODUCT DATA
# ============================================================================

$script:EsetProducts = @{
    EAV = @{
        Name        = 'ESET NOD32 Antivirus'
        ShortName   = 'EAV'
        Description = 'Essential antivirus and antispyware protection'
        Features    = @('Antivirus/Antispyware', 'Anti-Phishing', 'Ransomware Shield', 'UEFI Scanner')
        Price       = '$59.99/yr (1 PC)'
        CdnPrefix   = 'eav'
    }
    EIS = @{
        Name        = 'ESET Internet Security'
        ShortName   = 'EIS'
        Description = 'Complete online protection with firewall and banking security'
        Features    = @('Everything in EAV', 'Personal Firewall', 'Webcam Protection',
                         'Banking & Payment Protection', 'Parental Control', 'Home Network Protection')
        Price       = '~$59.99/yr (1 PC)'
        CdnPrefix   = 'eis'
    }
    ESSP = @{
        Name        = 'ESET Smart Security Premium'
        ShortName   = 'ESSP'
        Description = 'Premium suite with password manager and file encryption'
        Features    = @('Everything in EIS', 'Password Manager', 'File Encryption')
        Price       = '$89.99/yr (1 PC)'
        CdnPrefix   = 'essp'
    }
    ESU = @{
        Name        = 'ESET Security Ultimate'
        ShortName   = 'ESU'
        Description = 'Ultimate protection including VPN for complete privacy'
        Features    = @('Everything in ESSP', 'VPN')
        Price       = '$179.99/yr (5 devices)'
        CdnPrefix   = 'esu'
    }
    ESBS = @{
        Name        = 'ESET Small Business Security'
        ShortName   = 'ESBS'
        Description = 'Business-grade protection for small organizations'
        Features    = @('Everything in EIS', 'Centralized Management', 'SOHO Web Control')
        Price       = 'Varies by seats'
        CdnPrefix   = 'esbs'
    }
    ESSV = @{
        Name        = 'ESET Safe Server'
        ShortName   = 'ESSV'
        Description = 'Server protection with network attack protection'
        Features    = @('Everything in ESBS', 'Network Attack Protection', 'Server-specific rules')
        Price       = 'Varies by seats'
        CdnPrefix   = 'essv'
    }
}

# ============================================================================
# ESET CDN URL BUILDER
# ============================================================================

function Get-EsetDownloadUrl {
    <#
    .SYNOPSIS
        Builds the official ESET CDN download URL for a product and architecture.
    .PARAMETER Product
        ESET product code: EAV, EIS, ESSP, ESU, ESBS, or ESSV.
    .PARAMETER Arch
        Target architecture: x64, arm64, or x86. Auto-detected if not provided.
    .OUTPUTS
        String URL for the offline installer.
    .NOTES
        ESET CDN always serves the latest version via /latest/ paths.
        No version pinning is possible. See docs/ESET_Installer_Links_and_Version_History.md.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('EAV','EIS','ESSP','ESU','ESBS','ESSV')]
        [string]$Product,

        [ValidateSet('x64','arm64','x86')]
        [string]$Arch
    )

    if (-not $Arch) {
        $Arch = Get-SystemArch
    }

    $prefix = $script:EsetProducts[$Product].CdnPrefix

    $archSuffix = switch ($Arch) {
        'x64'   { 'nt64' }
        'x86'   { 'nt32' }
        'arm64' { 'arm64' }
    }

    return "https://download.eset.com/com/eset/apps/home/$prefix/windows/latest/${prefix}_${archSuffix}.exe"
}

# ============================================================================
# INSTALLED AV DETECTION
# ============================================================================

function Get-InstalledAvProducts {
    <#
    .SYNOPSIS
        Scans for installed antivirus products on the system.
    .DESCRIPTION
        Checks WMI SecurityCenter2 and registry for installed AV products.
        Displays status and warns about potential conflicts.
    #>
    [CmdletBinding()]
    param()

    Write-Log "SCANNING INSTALLED ANTIVIRUS PRODUCTS" "SECTION"

    $installed = @()

    # Query WMI SecurityCenter2 for AV products
    try {
        $avProducts = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "AntiVirusProduct" -ErrorAction Stop
        foreach ($av in $avProducts) {
            $state = switch ([int]("0x{0:X6}" -f $av.productState).Substring(2,2)) {
                '00' { 'Off' }
                '01' { 'Expired' }
                '10' { 'On' }
                '11' { 'Paused' }
                default { 'Unknown' }
            }

            $installed += [PSCustomObject]@{
                Name    = $av.displayName
                State   = $state
                GUID    = $av.productID
                Path    = $av.pathToSignedProductExe
            }
        }
    } catch {
        Write-Log "Could not query WMI SecurityCenter2: $($_.Exception.Message)" "WARNING"
    }

    # Also check for ESET specifically via registry
    try {
        $esetReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\ESET\ESET Security\CurrentVersion\Info" -ErrorAction SilentlyContinue
        if ($esetReg -and $esetReg.ProductName) {
            $alreadyListed = $installed | Where-Object { $_.Name -like "*ESET*" }
            if (-not $alreadyListed) {
                $installed += [PSCustomObject]@{
                    Name    = $esetReg.ProductName
                    State   = 'On'
                    GUID    = 'ESET (registry)'
                    Path    = ''
                }
            }
        }
    } catch {
        # ESET not installed or not accessible
    }

    if ($installed.Count -eq 0) {
        Write-Host ""
        Write-Host "  No antivirus products detected." -ForegroundColor Yellow
        Write-Host "  Windows Defender may still be active (requires manual check)." -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "  Detected Antivirus Products:" -ForegroundColor Cyan
        Write-Host "  $('=' * 60)" -ForegroundColor DarkGray

        foreach ($av in $installed) {
            $color = switch ($av.State) {
                'On'      { 'Green' }
                'Off'     { 'Red' }
                'Expired' { 'Yellow' }
                'Paused'  { 'DarkYellow' }
                default   { 'Gray' }
            }
            Write-Host "  $($av.Name)" -ForegroundColor White -NoNewline
            Write-Host " [$($av.State)]" -ForegroundColor $color
        }

        # Check for conflicts
        $realTimeAVs = $installed | Where-Object { $_.State -eq 'On' }
        if ($realTimeAVs.Count -gt 1) {
            Write-Host ""
            Write-Host "  WARNING: Multiple active AV products detected!" -ForegroundColor Red
            Write-Host "  Running more than one real-time antivirus can cause:" -ForegroundColor Yellow
            Write-Host "  - System slowdowns and high CPU usage" -ForegroundColor Yellow
            Write-Host "  - File locking conflicts" -ForegroundColor Yellow
            Write-Host "  - False positive detection loops" -ForegroundColor Yellow
            Write-Host "  Consider disabling or uninstalling one." -ForegroundColor Yellow
        }
    }

    # Check Defender status
    try {
        $defender = Get-MpPreference -ErrorAction Stop
        $rtStatus = if ($defender.DisableRealtimeMonitoring) { 'Off' } else { 'On' }
        Write-Host ""
        Write-Host "  Windows Defender Real-Time Protection: " -ForegroundColor Gray -NoNewline
        Write-Host $rtStatus -ForegroundColor $(if ($rtStatus -eq 'On') { 'Green' } else { 'Yellow' })
    } catch {
        # Defender not available
    }

    Write-Host ""
    return $installed
}

# ============================================================================
# ESET SUBMENU
# ============================================================================

function Show-EsetMenu {
    <#
    .SYNOPSIS
        ESET product selection and installation submenu.
    .DESCRIPTION
        Displays all 6 ESET products with feature comparison, auto-detects
        system architecture, and downloads the correct offline installer
        directly from the official ESET CDN.
    #>
    [CmdletBinding()]
    param()

    $detectedArch = Get-SystemArch
    $archDisplay = Get-ArchDisplayName -Arch $detectedArch

    $productKeys = @('EAV','EIS','ESSP','ESU','ESBS','ESSV')
    $productNums = @('1','2','3','4','5','6')

    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  ESET Antivirus Products" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Detected System: " -ForegroundColor Gray -NoNewline
        Write-Host $archDisplay -ForegroundColor Green
        Write-Host ""
        Write-Host "  All installers downloaded directly from official ESET CDN." -ForegroundColor DarkGray
        Write-Host "  Product is activated via license key at first launch." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  ESET Products:" -ForegroundColor White

        for ($i = 0; $i -lt $productKeys.Count; $i++) {
            $key = $productKeys[$i]
            $num = $productNums[$i]
            $p = $script:EsetProducts[$key]
            Write-Host "  [$num] $($p.Name)" -ForegroundColor Cyan -NoNewline
            Write-Host "  $($p.Price)" -ForegroundColor DarkGray
            Write-Host "      $($p.Description)" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "  System:" -ForegroundColor White
        Write-Host "  [I]  Scan Installed AV Products" -ForegroundColor Magenta
        Write-Host "  [C]  Compare Products (Detailed)" -ForegroundColor Magenta
        Write-Host "  [0]  Back" -ForegroundColor Gray
        Write-Host ""

        $choice = Read-Host "Select product"

        switch ($choice) {
            { $_ -in @('1','2','3','4','5','6') } {
                $idx = [int]$choice - 1
                $productKey = $productKeys[$idx]
                Install-EsetProduct -Product $productKey -Arch $detectedArch
            }
            "I" { Get-InstalledAvProducts }
            "C" { Show-EsetComparison }
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

# ============================================================================
# ESET PRODUCT COMPARISON
# ============================================================================

function Show-EsetComparison {
    <#
    .SYNOPSIS
        Displays a detailed feature comparison table for all ESET products.
    #>
    [CmdletBinding()]
    param()

    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  ESET Product Comparison" -ForegroundColor Yellow
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""

    $features = @(
        @{ Name='Antivirus/Antispyware';       EAV='Yes'; EIS='Yes'; ESSP='Yes';  ESU='Yes';  ESBS='Yes'; ESSV='Yes'  },
        @{ Name='Anti-Phishing';                EAV='Yes'; EIS='Yes'; ESSP='Yes';  ESU='Yes';  ESBS='Yes'; ESSV='Yes'  },
        @{ Name='Ransomware Shield';            EAV='Yes'; EIS='Yes'; ESSP='Yes';  ESU='Yes';  ESBS='Yes'; ESSV='Yes'  },
        @{ Name='UEFI Scanner';                 EAV='Yes'; EIS='Yes'; ESSP='Yes';  ESU='Yes';  ESBS='Yes'; ESSV='Yes'  },
        @{ Name='Personal Firewall';            EAV='No';  EIS='Yes'; ESSP='Yes';  ESU='Yes';  ESBS='Yes'; ESSV='Yes'  },
        @{ Name='Webcam Protection';            EAV='No';  EIS='Yes'; ESSP='Yes';  ESU='Yes';  ESBS='Yes'; ESSV='Yes'  },
        @{ Name='Banking & Payment Protection'; EAV='No';  EIS='Yes'; ESSP='Yes';  ESU='Yes';  ESBS='Yes'; ESSV='Yes'  },
        @{ Name='Parental Control';             EAV='No';  EIS='Yes'; ESSP='Yes';  ESU='Yes';  ESBS='Yes'; ESSV='Yes'  },
        @{ Name='Home Network Protection';      EAV='No';  EIS='Yes'; ESSP='Yes';  ESU='Yes';  ESBS='Yes'; ESSV='Yes'  },
        @{ Name='Password Manager';             EAV='No';  EIS='No';  ESSP='Yes';  ESU='Yes';  ESBS='No';  ESSV='No'   },
        @{ Name='File Encryption';              EAV='No';  EIS='No';  ESSP='Yes';  ESU='Yes';  ESBS='No';  ESSV='No'   },
        @{ Name='VPN';                          EAV='No';  EIS='No';  ESSP='No';   ESU='Yes';  ESBS='No';  ESSV='No'   },
        @{ Name='SOHO Web Control';             EAV='No';  EIS='No';  ESSP='No';   ESU='No';   ESBS='Yes'; ESSV='Yes'  },
        @{ Name='Centralized Management';       EAV='No';  EIS='No';  ESSP='No';   ESU='No';   ESBS='Yes'; ESSV='Yes'  }
    )

    $labels = @('EAV','EIS','ESSP','ESU','ESBS','ESSV')
    $names  = @('NOD32','Internet','Premium','Ultimate','Biz','Server')

    # Header
    Write-Host "  Feature                       " -NoNewline
    foreach ($n in $names) {
        Write-Host (" {0,-9}" -f $n) -NoNewline -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  $('=' * 68)" -ForegroundColor DarkGray

    foreach ($f in $features) {
        Write-Host "  $($f.Name.PadRight(30))" -NoNewline
        foreach ($l in $labels) {
            $val = $f.$l
            $color = if ($val -eq 'Yes') { 'Green' } else { 'DarkGray' }
            Write-Host (" {0,-9}" -f $val) -NoNewline -ForegroundColor $color
        }
        Write-Host ""
    }

    Write-Host ""
    Write-Host "  Pricing (1 year, 1 PC unless noted):" -ForegroundColor Gray
    Write-Host "  NOD32: `$59.99  |  Internet: ~`$59.99  |  Premium: `$89.99" -ForegroundColor DarkGray
    Write-Host "  Ultimate: `$179.99 (5 devices)  |  Business/Server: varies" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Note: All products share the same installer binary." -ForegroundColor Yellow
    Write-Host "  Product differentiation happens at activation via license key." -ForegroundColor Yellow
}

# ============================================================================
# ESET PRODUCT INSTALLER (DIRECT CDN)
# ============================================================================

function Install-EsetProduct {
    <#
    .SYNOPSIS
        Downloads and installs an ESET product from the official CDN.
    .PARAMETER Product
        ESET product code: EAV, EIS, ESSP, ESU, ESBS, or ESSV.
    .PARAMETER Arch
        Target architecture. Auto-detected if not provided.
    .DESCRIPTION
        Downloads the offline installer directly from download.eset.com,
        verifies the file, and launches the installer. This replaces the
        unreliable winget-based installation which only provides a live
        installer stub requiring internet during install.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('EAV','EIS','ESSP','ESU','ESBS','ESSV')]
        [string]$Product,

        [ValidateSet('x64','arm64','x86')]
        [string]$Arch
    )

    if (-not $Arch) {
        $Arch = Get-SystemArch
    }

    $pInfo = $script:EsetProducts[$Product]
    $url = Get-EsetDownloadUrl -Product $Product -Arch $Arch
    $fileName = Split-Path $url -Leaf
    $downloadPath = Join-Path $env:TEMP $fileName

    Write-Log "INSTALLING $($pInfo.Name)" "SECTION"
    Write-Host ""
    Write-Host "  Product:   $($pInfo.Name)" -ForegroundColor White
    Write-Host "  Arch:      $(Get-ArchDisplayName -Arch $Arch)" -ForegroundColor White
    Write-Host "  Source:    Official ESET CDN (direct download)" -ForegroundColor Gray
    Write-Host "  File:      $fileName" -ForegroundColor Gray
    Write-Host "  URL:       $url" -ForegroundColor DarkGray
    Write-Host ""

    # Feature summary
    Write-Host "  Included:" -ForegroundColor Gray
    foreach ($f in $pInfo.Features) {
        Write-Host "    + $f" -ForegroundColor Green
    }
    Write-Host ""

    # Warn about Defender conflict
    Write-Host "  WARNING: Installing a third-party antivirus will:" -ForegroundColor Yellow
    Write-Host "  - Require a license key for full functionality" -ForegroundColor Yellow
    Write-Host "  - May conflict with Windows Defender" -ForegroundColor Yellow
    Write-Host "  - Recommend disabling Windows Defender real-time protection" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "  Download and install $($pInfo.Name)? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Log "ESET installation cancelled by user" "INFO"
        return
    }

    # Download
    Write-Host ""
    Write-Host "  Downloading $fileName..." -ForegroundColor Cyan

    try {
        $ProgressPreference = 'SilentlyContinue'
        $webClient = New-Object System.Net.WebClient

        # Track download progress via DownloadFileCompleted
        $script:downloadComplete = $false
        $script:downloadError = $null

        Register-ObjectEvent $webClient DownloadFileCompleted -Action {
            $script:downloadComplete = $true
            if ($EventArgs.Error) {
                $script:downloadError = $EventArgs.Error.Message
            }
        } | Out-Null

        $webClient.DownloadFileAsync($url, $downloadPath)

        # Show progress while downloading
        while (-not $script:downloadComplete) {
            Start-Sleep -Milliseconds 200
            if (Test-Path $downloadPath) {
                $sizeMB = [math]::Round((Get-Item $downloadPath).Length / 1MB, 1)
                Write-Host "`r  Downloaded: ${sizeMB} MB" -NoNewline -ForegroundColor Cyan
            }
        }

        Write-Host ""

        if ($script:downloadError) {
            Write-Log "Download failed: $($script:downloadError)" "ERROR"
            return
        }

        $ProgressPreference = 'Continue'

        # Verify download
        if (-not (Test-Path $downloadPath)) {
            Write-Log "Downloaded file not found at $downloadPath" "ERROR"
            return
        }

        $fileSize = (Get-Item $downloadPath).Length
        $fileSizeMB = [math]::Round($fileSize / 1MB, 1)

        if ($fileSize -lt 1MB) {
            Write-Log "Downloaded file too small (${fileSizeMB} MB) - likely an error page" "ERROR"
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
            return
        }

        Write-Log "Download complete: $fileName ($fileSizeMB MB)" "SUCCESS"

        # SHA256 hash display (for reference, ESET hashes change with each version)
        Write-Host "  Calculating SHA256..." -ForegroundColor Gray
        $hash = (Get-FileHash -Path $downloadPath -Algorithm SHA256).Hash
        Write-Host "  SHA256: $hash" -ForegroundColor DarkGray
        Write-Host ""

        # Launch installer
        Write-Host "  Launching installer..." -ForegroundColor Cyan
        Write-Host "  Follow the on-screen prompts to complete installation." -ForegroundColor Yellow
        Write-Host ""

        Start-Process -FilePath $downloadPath -Wait:$false

        Write-Log "ESET installer launched: $fileName" "SUCCESS"

        Write-Host ""
        Write-Host "  $($pInfo.Name) installer has been launched!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Follow the installation wizard" -ForegroundColor Gray
        Write-Host "  2. Enter your license key when prompted" -ForegroundColor Gray
        Write-Host "  3. Run the initial system scan" -ForegroundColor Gray
        Write-Host "  4. Consider disabling Windows Defender to avoid conflicts" -ForegroundColor Gray
        Write-Host "     (Use [22] Defender Control from main menu)" -ForegroundColor DarkGray

    } catch {
        Write-Log "Error during ESET installation: $($_.Exception.Message)" "ERROR"
        $ProgressPreference = 'Continue'
    }
}

# ============================================================================
# MAIN ANTIVIRUS MENU
# ============================================================================

function Show-AntivirusMenu {
    <#
    .SYNOPSIS
        Main antivirus management submenu.
    .DESCRIPTION
        Provides access to ESET product installation (direct CDN download),
        Windows Defender configuration, and other security tools.
    #>
    [CmdletBinding()]
    param()

    $detectedArch = Get-SystemArch
    $archDisplay = Get-ArchDisplayName -Arch $detectedArch

    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Antivirus Management" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  System: " -ForegroundColor Gray -NoNewline
        Write-Host $archDisplay -ForegroundColor Green -NoNewline
        Write-Host " | " -ForegroundColor DarkGray -NoNewline

        # Quick OS info
        try {
            $osInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption
            Write-Host $osInfo -ForegroundColor Green
        } catch {
            Write-Host "Windows" -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "  ESET Products (Direct CDN Download):" -ForegroundColor White
        Write-Host "  [1] ESET NOD32 Antivirus          -- Basic AV protection" -ForegroundColor Cyan
        Write-Host "  [2] ESET Internet Security         -- + Firewall, Banking, Webcam" -ForegroundColor Cyan
        Write-Host "  [3] ESET Smart Security Premium    -- + Password Manager, Encryption" -ForegroundColor Cyan
        Write-Host "  [4] ESET Security Ultimate         -- + VPN included" -ForegroundColor Cyan
        Write-Host "  [5] ESET Small Business Security   -- Business tier" -ForegroundColor Cyan
        Write-Host "  [6] ESET Safe Server               -- Server tier" -ForegroundColor Cyan
        Write-Host "  [E] ESET Product Comparison (Detailed Table)" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "  Other Options:" -ForegroundColor White
        Write-Host "  [7] Windows Defender Configuration" -ForegroundColor Green
        Write-Host "  [8] Malwarebytes (Anti-Malware)" -ForegroundColor White
        Write-Host "  [9] Other Security Tools (Wireshark, Nmap, etc.)" -ForegroundColor White
        Write-Host ""
        Write-Host "  [S] System AV Scan -- Detect installed antivirus products" -ForegroundColor Magenta
        Write-Host "  [0] Back to main menu" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Note: Only install one real-time antivirus to avoid conflicts!" -ForegroundColor Yellow
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            { $_ -in @('1','2','3','4','5','6') } {
                Show-EsetMenu
            }
            "E" { Show-EsetComparison }
            "7" {
                if (Get-Command 'Set-DefenderControl' -ErrorAction SilentlyContinue) {
                    Set-DefenderControl
                } else {
                    Write-Log "Security module not loaded. Defender control unavailable." "ERROR"
                }
            }
            "8" {
                $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
                if ($wingetPath) {
                    Write-Log "INSTALLING MALWAREBYTES" "SECTION"
                    Write-Host "  Installing Malwarebytes..." -ForegroundColor Cyan
                    try {
                        winget install Malwarebytes.Malwarebytes --accept-package-agreements --accept-source-agreements
                        if ($LASTEXITCODE -eq 0) {
                            Write-Log "Malwarebytes installed successfully" "SUCCESS"
                        } else {
                            Write-Log "Malwarebytes installation failed" "WARNING"
                        }
                    } catch {
                        Write-Log "Error installing Malwarebytes: $($_.Exception.Message)" "ERROR"
                    }
                } else {
                    Write-Log "Winget not found. Please install App Installer from Microsoft Store." "ERROR"
                    Write-Host "Opening Microsoft Store..." -ForegroundColor Yellow
                    Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
                }
            }
            "9" {
                if (Get-Command 'Install-SecurityTools' -ErrorAction SilentlyContinue) {
                    Install-SecurityTools
                } else {
                    Write-Log "Security module not loaded." "ERROR"
                }
            }
            "S" { Get-InstalledAvProducts }
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

# ============================================================================
# MODULE EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Show-AntivirusMenu',
    'Show-EsetMenu',
    'Show-EsetComparison',
    'Install-EsetProduct',
    'Get-SystemArch',
    'Get-ArchDisplayName',
    'Get-EsetDownloadUrl',
    'Get-InstalledAvProducts'
)
