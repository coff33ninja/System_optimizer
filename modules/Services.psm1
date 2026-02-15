# ============================================================================
# Services Module - System Optimizer
# ============================================================================

function Disable-Services {
    param(
        [switch]$Aggressive  # Use aggressive mode for maximum optimization
    )

    Write-Log "DISABLING UNNECESSARY SERVICES" "SECTION"

    # ============================================
    # SAFE TO DISABLE - Won't break common functionality
    # ============================================
    $SafeToDisable = @(
        # Telemetry & Data Collection
        "DiagTrack",           # Connected User Experiences and Telemetry
        "dmwappushservice",    # WAP Push Message Routing Service
        "WerSvc",              # Windows Error Reporting
        "wisvc",               # Windows Insider Service
        "PcaSvc",              # Program Compatibility Assistant
        "wercplsupport",       # Problem Reports Control Panel Support

        # Xbox (safe even for gamers - games work without these services)
        "XblAuthManager",      # Xbox Live Auth Manager
        "XblGameSave",         # Xbox Live Game Save
        "XboxGipSvc",          # Xbox Accessory Management
        "XboxNetApiSvc",       # Xbox Live Networking

        # Rarely Used Features
        "Fax",                 # Fax Service
        "RetailDemo",          # Retail Demo Service
        "MapsBroker",          # Downloaded Maps Manager
        "AJRouter",            # AllJoyn Router (IoT)
        "SharedAccess",        # Internet Connection Sharing
        "RemoteRegistry",      # Remote Registry (security risk anyway)
        "WalletService",       # Wallet Service (NFC payments)
        "SmsRouter",           # SMS Router Service

        # Hyper-V Guest Services (only needed inside VMs, not on host)
        "vmickvpexchange",     # Hyper-V Data Exchange Service
        "vmicguestinterface",  # Hyper-V Guest Service Interface
        "vmicshutdown",        # Hyper-V Guest Shutdown Service
        "vmicheartbeat",       # Hyper-V Heartbeat Service
        "vmicvmsession",       # Hyper-V PowerShell Direct Service
        "vmicrdv",             # Hyper-V Remote Desktop Virtualization Service
        "vmictimesync",        # Hyper-V Time Synchronization Service
        "vmicvss",             # Hyper-V Volume Shadow Copy Requestor

        # Misc Safe to Disable
        "WMPNetworkSvc",       # Windows Media Player Network Sharing
        "WpcMonSvc",           # Parental Controls
        "SEMgrSvc",            # Payments and NFC/SE Manager
        "MessagingService",    # MessagingService (SMS/MMS)
        "spectrum",            # Windows Perception Service (Mixed Reality)
        "perceptionsimulation", # Windows Perception Simulation Service
        "AssignedAccessManagerSvc", # Assigned Access Manager (Kiosk mode)
        "tzautoupdate",        # Auto Time Zone Updater
        "DusmSvc"              # Data Usage (mobile data tracking)
    )

    # ============================================
    # AGGRESSIVE - May affect some users, use with caution
    # ============================================
    $AggressiveDisable = @(
        # Performance (may affect some workflows)
        "SysMain",             # Superfetch - safe on SSD, may slow HDD
        "WSearch",             # Windows Search - disables search indexing

        # Print (only disable if no printer)
        "Spooler",             # Print Spooler
        "PrintNotify",         # Printer Extensions and Notifications

        # Touch/Biometric (only if no touchscreen/fingerprint)
        "TabletInputService",  # Touch Keyboard and Handwriting
        "WbioSrvc",            # Windows Biometric Service

        # Location (breaks weather widget, maps, find my device)
        "lfsvc",               # Geolocation Service

        # Phone integration (breaks Phone Link app)
        "PhoneSvc",            # Phone Service

        # Remote Desktop (only if not using RDP)
        "SessionEnv",          # Remote Desktop Configuration
        "TermService",         # Remote Desktop Services
        "UmRdpService",        # Remote Desktop UserMode Port Redirector
        "RemoteAccess",        # Routing and Remote Access
        "RasAuto",             # Remote Access Auto Connection Manager

        # Smart Card (only if not using smart cards/PIV)
        "SCardSvr",            # Smart Card
        "ScDeviceEnum",        # Smart Card Device Enumeration
        "SCPolicySvc",         # Smart Card Removal Policy

        # Sync (breaks MS account settings sync)
        "OneSyncSvc",          # Sync Host

        # Push Notifications (breaks Store/app notifications)
        "WpnService",          # Windows Push Notifications System
        "WpnUserService",      # Windows Push Notifications User
        "PushToInstall",       # Windows PushToInstall Service

        # Connected Devices (breaks device pairing, nearby share)
        "CDPSvc",              # Connected Devices Platform Service
        "CDPUserSvc",          # Connected Devices Platform User Service
        "DevicesFlowUserSvc",  # Devices Flow
        "NcbService",          # Network Connection Broker

        # Windows Hello (breaks PIN/face/fingerprint login)
        "NgcSvc",              # Microsoft Passport
        "NgcCtnrSvc",          # Microsoft Passport Container

        # Diagnostics (may affect troubleshooting tools)
        "DiagSvc",             # Diagnostic Execution Service
        "DPS",                 # Diagnostic Policy Service
        "WdiServiceHost",      # Diagnostic Service Host
        "WdiSystemHost",       # Diagnostic System Host

        # Other aggressive
        "TrkWks",              # Distributed Link Tracking Client
        "CscService",          # Offline Files
        "icssvc",              # Windows Mobile Hotspot Service
        "WFDSConMgrSvc",       # Wi-Fi Direct Services
        "FrameServer",         # Windows Camera Frame Server (breaks camera)
        "GraphicsPerfSvc",     # Graphics Performance Monitor
        "PerfHost",            # Performance Counter DLL Host
        "AppReadiness",        # App Readiness
        "stisvc",              # Windows Image Acquisition (breaks scanner)
        "WiaRpc",              # Still Image Acquisition Events
        "defragsvc"            # Optimize Drives (manual defrag still works)
    )

    # Determine which list to use
    if ($Aggressive) {
        Write-Log "Using AGGRESSIVE mode - more services will be disabled" "WARNING"
        Write-Log "Some features may not work: Search, Print, RDP, Camera, Scanner, Notifications" "WARNING"
        $ServicesToDisable = $SafeToDisable + $AggressiveDisable
    } else {
        Write-Log "Using SAFE mode - only non-essential services disabled" "INFO"
        $ServicesToDisable = $SafeToDisable
    }

    # Use progress tracking if available
    $hasProgress = Get-Command 'Start-ProgressOperation' -ErrorAction SilentlyContinue
    if ($hasProgress) {
        Start-ProgressOperation -Name "Disabling Services" -TotalItems $ServicesToDisable.Count
    }

    foreach ($service in $ServicesToDisable) {
        try {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                if ($hasProgress) {
                    Update-ProgressItem -ItemName $service -Status 'Success'
                } else {
                    Write-Log "Disabled: $service" "SUCCESS"
                }
            } else {
                if ($hasProgress) {
                    Update-ProgressItem -ItemName $service -Status 'Skipped' -Message "Not found"
                }
            }
        } catch {
            if ($hasProgress) {
                Update-ProgressItem -ItemName $service -Status 'Failed' -Message $_.Exception.Message
            } else {
                Write-Log "Could not disable: $service" "WARNING"
            }
        }
    }

    # Disable Windows Defender (optional - be careful!)
    Write-Log "Disabling Windows Defender real-time monitoring..."
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    if ($hasProgress) {
        Update-ProgressItem -ItemName "Windows Defender Real-time" -Status 'Success'
    } else {
        Write-Log "Windows Defender real-time disabled" "SUCCESS"
    }

    # Disable Teams startup (keeps Teams installed but prevents auto-start)
    Disable-TeamsStartup

    if ($hasProgress) {
        Complete-ProgressOperation
    } else {
        Write-Log "Services optimization completed" "SUCCESS"
    }
}

function Sync-WinUtilServices {
    $WinUtilUrl = "https://raw.githubusercontent.com/ChrisTitusTech/winutil/main/config/tweaks.json"
    $LocalCache = "C:\System_Optimizer\winutil_tweaks.json"

    # Ensure directory exists
    if (-not (Test-Path "C:\System_Optimizer")) {
        New-Item -ItemType Directory -Path "C:\System_Optimizer" -Force | Out-Null
    }

    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  WinUtil Service Sync" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Sync from WinUtil (Download latest config)" -ForegroundColor Green
        Write-Host "  [2] Apply cached config (Use previously downloaded)"
        Write-Host "  [3] Apply WinUtil + Our aggressive tweaks (Combined)"
        Write-Host "  [4] View service changes (Preview only)"
        Write-Host "  [5] Export current service states (Backup)"
        Write-Host "  [0] Back to main menu"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
        "1" {
            Write-Log "Downloading WinUtil tweaks.json..."
            try {
                $response = Invoke-WebRequest -Uri $WinUtilUrl -UseBasicParsing -TimeoutSec 30
                $response.Content | Out-File -FilePath $LocalCache -Encoding UTF8 -Force
                Write-Log "Downloaded WinUtil config to: $LocalCache" "SUCCESS"

                # Parse and apply
                Apply-WinUtilServiceConfig -ConfigPath $LocalCache
            } catch {
                Write-Log "Failed to download WinUtil config: $_" "ERROR"
                Write-Log "Try using cached config (option 2) if available" "WARNING"
            }
        }
        "2" {
            if (Test-Path $LocalCache) {
                Write-Log "Using cached WinUtil config..."
                Apply-WinUtilServiceConfig -ConfigPath $LocalCache
            } else {
                Write-Log "No cached config found. Please download first (option 1)" "ERROR"
            }
        }
        "3" {
            Write-Log "Applying WinUtil config + aggressive tweaks..."

            # First apply WinUtil (safe mode)
            if (-not (Test-Path $LocalCache)) {
                Write-Log "Downloading WinUtil config first..."
                try {
                    $response = Invoke-WebRequest -Uri $WinUtilUrl -UseBasicParsing -TimeoutSec 30
                    $response.Content | Out-File -FilePath $LocalCache -Encoding UTF8 -Force
                } catch {
                    Write-Log "Failed to download: $_" "ERROR"
                    return
                }
            }

            Apply-WinUtilServiceConfig -ConfigPath $LocalCache

            # Then apply our aggressive tweaks on top
            Write-Log "Applying additional aggressive service disables..." "SECTION"
            $AggressiveDisable = @(
                "DiagTrack",           # Telemetry - WinUtil sets Disabled, we ensure it
                "WSearch",             # Windows Search - WinUtil sets DelayedStart, we disable
                "SysMain",             # Superfetch - WinUtil keeps Auto, we can disable on SSD
                "Spooler",             # Print Spooler - disable if no printer
                "TabletInputService",  # Touch Keyboard - disable if no touchscreen
                "Fax"                  # Fax - almost never needed
            )

            foreach ($svc in $AggressiveDisable) {
                try {
                    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
                    if ($service) {
                        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                        Write-Log "Aggressively disabled: $svc" "SUCCESS"
                    }
                } catch {
                    Write-Log "Could not disable: $svc" "WARNING"
                }
            }

            Write-Log "Combined optimization completed" "SUCCESS"
        }
        "4" {
            if (-not (Test-Path $LocalCache)) {
                Write-Log "Downloading WinUtil config for preview..."
                try {
                    $response = Invoke-WebRequest -Uri $WinUtilUrl -UseBasicParsing -TimeoutSec 30
                    $response.Content | Out-File -FilePath $LocalCache -Encoding UTF8 -Force
                } catch {
                    Write-Log "Failed to download: $_" "ERROR"
                    return
                }
            }

            Preview-WinUtilServiceChanges -ConfigPath $LocalCache
        }
        "5" {
            Export-CurrentServiceStates
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

function Apply-WinUtilServiceConfig {
    param([string]$ConfigPath)

    Write-Log "Parsing WinUtil service configuration..."

    try {
        $json = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

        # Find the WPFTweaksServices entry
        $servicesConfig = $json.WPFTweaksServices.service

        if (-not $servicesConfig) {
            Write-Log "Could not find service configuration in WinUtil JSON" "ERROR"
            return
        }

        $totalServices = $servicesConfig.Count
        $processed = 0
        $changed = 0
        $skipped = 0

        Write-Log "Found $totalServices service configurations"
        Write-Host ""

        foreach ($svcConfig in $servicesConfig) {
            $processed++
            $svcName = $svcConfig.Name
            $targetType = $svcConfig.StartupType

            # Enhanced progress indicator
            $percent = [math]::Round(($processed / $totalServices) * 100)
            if (Get-Command 'Show-EnhancedProgress' -ErrorAction SilentlyContinue) {
                Show-EnhancedProgress -Percent $percent -Activity "Applying WinUtil Service Config" -Status "$svcName"
            } else {
                Write-Progress -Activity "Applying WinUtil Service Config" -Status "$svcName" -PercentComplete $percent
            }

            try {
                $service = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                if ($service) {
                    $currentType = (Get-WmiObject -Class Win32_Service -Filter "Name='$svcName'" -ErrorAction SilentlyContinue).StartMode

                    # Map WinUtil types to PowerShell types
                    $psType = switch ($targetType) {
                        "AutomaticDelayedStart" { "Automatic" }  # PS doesn't have delayed, use registry
                        "Automatic" { "Automatic" }
                        "Manual" { "Manual" }
                        "Disabled" { "Disabled" }
                        default { "Manual" }
                    }

                    # Skip if already correct type
                    if ($currentType -eq $targetType) {
                        $skipped++
                        continue
                    }

                    # Apply the change
                    if ($targetType -eq "AutomaticDelayedStart") {
                        # Use sc.exe for delayed start
                        $null = sc.exe config $svcName start=delayed-auto 2>&1
                        $changed++
                        Write-Log "Set $svcName to Automatic (Delayed Start)" "SUCCESS"
                    } else {
                        Set-Service -Name $svcName -StartupType $psType -ErrorAction Stop
                        $changed++
                        Write-Log "Set $svcName to $psType" "SUCCESS"
                    }
                } else {
                    $skipped++
                }
            } catch {
                $skipped++
                Write-Log "Skipped $svcName (not found or protected)" "WARNING"
            }
        }

        # Close enhanced progress
        if (Get-Command 'Close-EnhancedProgress' -ErrorAction SilentlyContinue) {
            Close-EnhancedProgress
        } else {
            Write-Progress -Activity "Applying WinUtil Service Config" -Completed
        }

        Write-Host ""
        Write-Log "WinUtil Service Sync Complete:" "SECTION"
        Write-Log "  Total in config: $totalServices"
        Write-Log "  Successfully changed: $changed" "SUCCESS"
        Write-Log "  Skipped (not found/protected): $skipped" "WARNING"

    } catch {
        Write-Log "Error parsing WinUtil config: $_" "ERROR"
    }
}

function Preview-WinUtilServiceChanges {
    param([string]$ConfigPath)

    Write-Log "PREVIEW: WinUtil Service Changes" "SECTION"

    try {
        $json = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        $servicesConfig = $json.WPFTweaksServices.service

        if (-not $servicesConfig) {
            Write-Log "Could not find service configuration" "ERROR"
            return
        }

        Write-Host ""
        Write-Host "Services that would be DISABLED:" -ForegroundColor Red
        $servicesConfig | Where-Object { $_.StartupType -eq "Disabled" } | ForEach-Object {
            $svc = Get-Service -Name $_.Name -ErrorAction SilentlyContinue
            if ($svc) {
                Write-Host "  - $($_.Name)" -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Host "Services that would be set to MANUAL:" -ForegroundColor Yellow
        $manualCount = 0
        $servicesConfig | Where-Object { $_.StartupType -eq "Manual" } | ForEach-Object {
            $svc = Get-Service -Name $_.Name -ErrorAction SilentlyContinue
            if ($svc) {
                $manualCount++
                if ($manualCount -le 20) {
                    Write-Host "  - $($_.Name)" -ForegroundColor Yellow
                }
            }
        }
        if ($manualCount -gt 20) {
            Write-Host "  ... and $($manualCount - 20) more" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Services that would be set to AUTOMATIC (Delayed):" -ForegroundColor Green
        $servicesConfig | Where-Object { $_.StartupType -eq "AutomaticDelayedStart" } | ForEach-Object {
            $svc = Get-Service -Name $_.Name -ErrorAction SilentlyContinue
            if ($svc) {
                Write-Host "  - $($_.Name)" -ForegroundColor Green
            }
        }

        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    } catch {
        Write-Log "Error previewing config: $_" "ERROR"
    }
}

function Export-CurrentServiceStates {
    Write-Log "EXPORTING CURRENT SERVICE STATES" "SECTION"

    $exportPath = "C:\System_Optimizer\service_backup_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').json"

    try {
        $services = Get-WmiObject -Class Win32_Service | Select-Object Name, StartMode, State, DisplayName

        $exportData = @{
            ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            ComputerName = $env:COMPUTERNAME
            Services = @()
        }

        foreach ($svc in $services) {
            $exportData.Services += @{
                Name = $svc.Name
                StartupType = $svc.StartMode
                State = $svc.State
                DisplayName = $svc.DisplayName
            }
        }

        $exportData | ConvertTo-Json -Depth 3 | Out-File -FilePath $exportPath -Encoding UTF8 -Force

        Write-Log "Exported $($services.Count) service states to:" "SUCCESS"
        Write-Log "  $exportPath" "INFO"
        Write-Host ""
        Write-Host "You can use this backup to restore service states later." -ForegroundColor Gray

    } catch {
        Write-Log "Error exporting service states: $_" "ERROR"
    }
}

function Disable-TeamsStartup {
    <#
    .SYNOPSIS
        Disable Microsoft Teams from starting automatically
    .DESCRIPTION
        Disables Teams startup via registry Run keys, startup folder, and config.
        Works with both classic Teams and new Teams (Win11).
        Compatible with Windows 7+ and PowerShell 2.0+
    #>

    Write-Log "Disabling Microsoft Teams startup..." "SECTION"

    # Method 1: Registry Run keys (current user)
    $RunKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $TeamsKeys = @("com.squirrel.Teams.Teams", "Teams", "MicrosoftTeams")
    foreach ($key in $TeamsKeys) {
        if (Get-ItemProperty -Path $RunKey -Name $key -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $RunKey -Name $key -ErrorAction SilentlyContinue
            Write-Log "Removed startup entry: $key" "SUCCESS"
        }
    }

    # Method 2: Registry Run keys (all users)
    $RunKeyLM = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    foreach ($key in $TeamsKeys) {
        if (Get-ItemProperty -Path $RunKeyLM -Name $key -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $RunKeyLM -Name $key -ErrorAction SilentlyContinue
            Write-Log "Removed startup entry (HKLM): $key" "SUCCESS"
        }
    }

    # Method 3: Startup folder shortcuts
    $StartupPaths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    )
    foreach ($path in $StartupPaths) {
        if (Test-Path $path) {
            $teamsShortcuts = Get-ChildItem -Path $path -Filter "*Teams*" -ErrorAction SilentlyContinue
            foreach ($shortcut in $teamsShortcuts) {
                Remove-Item $shortcut.FullName -Force -ErrorAction SilentlyContinue
                Write-Log "Removed startup shortcut: $($shortcut.Name)" "SUCCESS"
            }
        }
    }

    # Method 4: Teams config file (classic Teams)
    $TeamsConfig = "$env:APPDATA\Microsoft\Teams\desktop-config.json"
    if (Test-Path $TeamsConfig) {
        try {
            $config = Get-Content $TeamsConfig -Raw | ConvertFrom-Json
            if ($config.appPreferenceSettings) {
                $config.appPreferenceSettings.openAtLogin = $false
                $config | ConvertTo-Json -Depth 10 | Set-Content $TeamsConfig -Force
                Write-Log "Disabled auto-start in Teams config" "SUCCESS"
            }
        } catch {
            Write-Log "Could not modify Teams config (may be in use)" "WARNING"
        }
    }

    # Method 5: Task Scheduler (new Teams on Win11)
    $WinBuild = [System.Environment]::OSVersion.Version.Build
    if ($WinBuild -ge 10240) {
        $teamsTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Teams*" }
        foreach ($task in $teamsTasks) {
            Disable-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue
            Write-Log "Disabled scheduled task: $($task.TaskName)" "SUCCESS"
        }
    }

    Write-Log "Teams startup disabled. Teams can still be launched manually." "INFO"
}

function Enable-TeamsStartup {
    <#
    .SYNOPSIS
        Re-enable Microsoft Teams startup
    .DESCRIPTION
        Re-enables Teams to start automatically via config and scheduled tasks.
    #>

    Write-Log "Re-enabling Microsoft Teams startup..." "SECTION"

    # Re-enable via Teams config
    $TeamsConfig = "$env:APPDATA\Microsoft\Teams\desktop-config.json"
    if (Test-Path $TeamsConfig) {
        try {
            $config = Get-Content $TeamsConfig -Raw | ConvertFrom-Json
            if ($config.appPreferenceSettings) {
                $config.appPreferenceSettings.openAtLogin = $true
                $config | ConvertTo-Json -Depth 10 | Set-Content $TeamsConfig -Force
                Write-Log "Enabled auto-start in Teams config" "SUCCESS"
            }
        } catch {
            Write-Log "Could not modify Teams config" "WARNING"
        }
    }

    # Re-enable scheduled tasks
    $WinBuild = [System.Environment]::OSVersion.Version.Build
    if ($WinBuild -ge 10240) {
        $teamsTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*Teams*" }
        foreach ($task in $teamsTasks) {
            Enable-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue
            Write-Log "Enabled scheduled task: $($task.TaskName)" "SUCCESS"
        }
    }

    Write-Log "Teams startup re-enabled." "INFO"
}

function Show-ServicesMenu {
    <#
    .SYNOPSIS
        Interactive menu for service optimization options
    #>

    do {
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Services Optimization" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Safe Mode (Recommended)" -ForegroundColor Green
        Write-Host "      Disables ~45 services: telemetry, Xbox, Hyper-V guest,"
        Write-Host "      rarely used features. Won't break common functionality."
        Write-Host ""
        Write-Host "  [2] Aggressive Mode" -ForegroundColor Yellow
        Write-Host "      Disables ~90 services including: Print, Search, RDP,"
        Write-Host "      Camera, Notifications, Windows Hello, Location."
        Write-Host "      " -NoNewline
        Write-Host "May break some features!" -ForegroundColor Red
        Write-Host ""
        Write-Host "  [3] Disable Teams Startup Only" -ForegroundColor Cyan
        Write-Host "      Keeps Teams installed but prevents auto-start."
        Write-Host ""
        Write-Host "  [4] Re-enable Teams Startup" -ForegroundColor Cyan
        Write-Host "      Restore Teams auto-start behavior."
        Write-Host ""
        Write-Host "  [5] WinUtil Service Sync" -ForegroundColor Magenta
        Write-Host "      Sync service configs from ChrisTitusTech's WinUtil."
        Write-Host ""
        Write-Host "  [6] Export Current Service States" -ForegroundColor DarkGray
        Write-Host "      Backup current service configuration to JSON."
        Write-Host ""
        Write-Host "  [0] Back to Main Menu"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" {
                Write-Host ""
                Write-Host "Running Safe Mode service optimization..." -ForegroundColor Green
                Disable-Services
                Write-Host ""
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Write-Host ""
                Write-Host "WARNING: Aggressive mode may disable features you use!" -ForegroundColor Red
                Write-Host "Affected: Print, Search, RDP, Camera, Scanner, Notifications, Windows Hello" -ForegroundColor Yellow
                $confirm = Read-Host "Continue? (y/N)"
                if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                    Disable-Services -Aggressive
                }
                Write-Host ""
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Write-Host ""
                Disable-TeamsStartup
                Write-Host ""
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "4" {
                Write-Host ""
                Enable-TeamsStartup
                Write-Host ""
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "5" {
                Sync-WinUtilServices
            }
            "6" {
                Write-Host ""
                Export-CurrentServiceStates
                Write-Host ""
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "0" { return }
            default {
                Write-Host "Invalid option" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

# Export functions
Export-ModuleMember -Function @(
    'Disable-Services',
    'Show-ServicesMenu',
    'Sync-WinUtilServices',
    'Apply-WinUtilServiceConfig',
    'Preview-WinUtilServiceChanges',
    'Export-CurrentServiceStates',
    'Disable-TeamsStartup',
    'Enable-TeamsStartup'
)
