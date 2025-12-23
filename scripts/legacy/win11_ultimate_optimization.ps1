# ============================================================================
# ULTIMATE WINDOWS 11 OPTIMIZATION SCRIPT
# ============================================================================
# Combines features from: AIO, NexTool, WinUtil, and custom optimizations
# Date: 2025-12-17
# Requires: PowerShell 5.1+, Administrator privileges
# ============================================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = 'SilentlyContinue'

# ============================================================================
# LOGGING SETUP - Centralized logging to C:\System_Optimizer\Logs
# ============================================================================
$script:LogDir = "C:\System_Optimizer\Logs"
$script:LogFile = $null

function Initialize-Logging {
    # Ensure log directory exists
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    
    # Create log file with timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $script:LogFile = "$LogDir\SystemOptimizer_$timestamp.log"
    
    # Write header
    $header = @"
================================================================================
SYSTEM OPTIMIZER - MAIN SCRIPT LOG
================================================================================
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
PowerShell: $($PSVersionTable.PSVersion)
================================================================================

"@
    Add-Content -Path $LogFile -Value $header -ErrorAction SilentlyContinue
    
    # Cleanup old logs (keep last 30 days)
    Get-ChildItem -Path $LogDir -Filter "SystemOptimizer_*.log" -ErrorAction SilentlyContinue | 
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# Legacy log path for backward compatibility
$LogPath = "C:\System_Optimizer\Logs\SystemOptimizer_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $shortTime = Get-Date -Format "HH:mm:ss"
    
    # Write to log file
    $logMessage = "[$timestamp] [$Type] $Message"
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
    
    # Write to console with colors and timestamps
    switch ($Type) {
        "SUCCESS" { Write-Host "[$shortTime] [OK] " -ForegroundColor Green -NoNewline; Write-Host $Message }
        "ERROR"   { Write-Host "[$shortTime] [X] " -ForegroundColor Red -NoNewline; Write-Host $Message }
        "WARNING" { Write-Host "[$shortTime] [!] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "SECTION" { Write-Host "`n[$shortTime] === " -ForegroundColor Cyan -NoNewline; Write-Host $Message -ForegroundColor Cyan -NoNewline; Write-Host " ===" -ForegroundColor Cyan }
        default   { Write-Host "[$shortTime] [-] " -ForegroundColor Gray -NoNewline; Write-Host $Message }
    }
}

# Initialize logging on script start
Initialize-Logging

# ============================================================================
# CONSOLE WINDOW SIZING - Consistent terminal size across all menus
# ============================================================================
$script:ConsoleWidth = 85
$script:ConsoleHeight = 45

function Set-ConsoleSize {
    param(
        [int]$Width = $ConsoleWidth,
        [int]$Height = $ConsoleHeight
    )
    
    try {
        # Only resize if running in a console host (not ISE or VS Code)
        if ($Host.Name -eq 'ConsoleHost') {
            $maxWidth = $Host.UI.RawUI.MaxPhysicalWindowSize.Width
            $maxHeight = $Host.UI.RawUI.MaxPhysicalWindowSize.Height
            
            # Clamp to max available size
            $Width = [Math]::Min($Width, $maxWidth)
            $Height = [Math]::Min($Height, $maxHeight)
            
            # Set buffer size first (must be >= window size)
            $bufferSize = $Host.UI.RawUI.BufferSize
            $bufferSize.Width = [Math]::Max($Width, $bufferSize.Width)
            $bufferSize.Height = 9999  # Large buffer for scrollback
            $Host.UI.RawUI.BufferSize = $bufferSize
            
            # Set window size
            $windowSize = $Host.UI.RawUI.WindowSize
            $windowSize.Width = $Width
            $windowSize.Height = $Height
            $Host.UI.RawUI.WindowSize = $windowSize
        }
    } catch {
        # Silently ignore sizing errors (happens in some terminals)
    }
}

function Show-Menu {
    Set-ConsoleSize
    Clear-Host
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  ULTIMATE WINDOWS 11 OPTIMIZATION SCRIPT" -ForegroundColor Yellow
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Run ALL Optimizations (Recommended)" -ForegroundColor Green
    Write-Host "  [16] Full Setup (PatchMyPC + Office + Services + MAS)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Individual Options:" -ForegroundColor Gray
    Write-Host "  [2] Disable Telemetry & Privacy Tweaks"
    Write-Host "  [3] Disable Unnecessary Services"
    Write-Host "  [4] Remove Bloatware Apps"
    Write-Host "  [5] Disable Scheduled Tasks"
    Write-Host "  [6] Registry Optimizations"
    Write-Host "  [7] Disable VBS/Memory Integrity"
    Write-Host "  [8] Network Optimizations"
    Write-Host "  [9] Remove OneDrive"
    Write-Host "  [10] System Maintenance (DISM/SFC)"
    Write-Host ""
    Write-Host "  Software & Activation:" -ForegroundColor Gray
    Write-Host "  [11] PatchMyPC (Update/Install Software)"
    Write-Host "  [12] Office Tool Plus (Install Office)"
    Write-Host "  [13] Microsoft Activation Script (MAS)"
    Write-Host ""
    Write-Host "  Advanced:" -ForegroundColor Gray
    Write-Host "  [17] Set Power Plan (High Performance/Ultimate)"
    Write-Host "  [18] Run O&O ShutUp10 (Privacy Tool)"
    Write-Host "  [19] Reset Group Policy"
    Write-Host "  [20] Reset WMI Repository"
    Write-Host "  [21] Disk Cleanup"
    Write-Host "  [22] Windows Update Control"
    Write-Host "  [23] Snappy Driver Installer"
    Write-Host "  [24] Reset Network"
    Write-Host "  [25] Repair Windows Update"
    Write-Host "  [26] Windows Defender Control"
    Write-Host "  [27] Advanced Debloat Scripts (AIO)"
    Write-Host "  [28] WinUtil Service Sync (Safe Mode)" -ForegroundColor Magenta
    Write-Host "  [29] DISM++ Style Tweaks" -ForegroundColor Magenta
    Write-Host "  [30] Windows Image Tool (ISO/Install)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Utilities:" -ForegroundColor Gray
    Write-Host "  [14] Extract Wi-Fi Passwords"
    Write-Host "  [15] Verify Optimization Status"
    Write-Host "  [31] View Logs" -ForegroundColor DarkGray
    Write-Host "  [32] User Profile Backup & Restore" -ForegroundColor Magenta
    Write-Host "  [33] Shutdown & Restart Options" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Log: $LogFile" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [0] Exit"
    Write-Host ""
}

# ============================================================================
# SECTION 1: TELEMETRY & PRIVACY
# ============================================================================
function Disable-Telemetry {
    Write-Log "DISABLING TELEMETRY & PRIVACY TWEAKS" "SECTION"
    
    # Disable Advertising ID
    Write-Log "Disabling Advertising ID..."
    $AdvPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    if (-not (Test-Path $AdvPath)) { New-Item -Path $AdvPath -Force | Out-Null }
    Set-ItemProperty -Path $AdvPath -Name "Enabled" -Value 0 -Type DWord -Force
    Write-Log "Advertising ID disabled" "SUCCESS"
    
    # Disable Activity History
    Write-Log "Disabling Activity History..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord -Force
    Write-Log "Activity History disabled" "SUCCESS"
    
    # Disable Bing Search in Start Menu
    Write-Log "Disabling Bing Search in Start Menu..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
    $WebSearch = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    if (-not (Test-Path $WebSearch)) { New-Item -Path $WebSearch -Force | Out-Null }
    Set-ItemProperty -Path $WebSearch -Name "DisableWebSearch" -Value 1 -Type DWord -Force
    Write-Log "Bing Search disabled" "SUCCESS"
    
    # Disable Windows Feedback
    Write-Log "Disabling Windows Feedback..."
    $FeedbackPath = "HKCU:\Software\Microsoft\Siuf\Rules"
    if (-not (Test-Path $FeedbackPath)) { New-Item -Path $FeedbackPath -Force | Out-Null }
    Set-ItemProperty -Path $FeedbackPath -Name "PeriodInNanoSeconds" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $FeedbackPath -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -Force
    Write-Log "Windows Feedback disabled" "SUCCESS"
    
    # Disable Content Delivery (prevents bloatware reinstall)
    Write-Log "Disabling Content Delivery Manager..."
    $CloudContent = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $CloudContent)) { New-Item -Path $CloudContent -Force | Out-Null }
    Set-ItemProperty -Path $CloudContent -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -Force
    
    $CDM = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-ItemProperty -Path $CDM -Name "ContentDeliveryAllowed" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "PreInstalledAppsEverEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SoftLandingEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-353694Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-353696Enabled" -Value 0 -Type DWord -Force
    Write-Log "Content Delivery Manager disabled" "SUCCESS"
    
    # Disable Location Tracking
    Write-Log "Disabling Location Tracking..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\Maps" -Name "AutoUpdateEnabled" -Value 0 -Type DWord -Force
    Write-Log "Location Tracking disabled" "SUCCESS"
    
    # Disable Wi-Fi Sense
    Write-Log "Disabling Wi-Fi Sense..."
    $WifiSense1 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting"
    $WifiSense2 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots"
    if (-not (Test-Path $WifiSense1)) { New-Item -Path $WifiSense1 -Force | Out-Null }
    if (-not (Test-Path $WifiSense2)) { New-Item -Path $WifiSense2 -Force | Out-Null }
    Set-ItemProperty -Path $WifiSense1 -Name "Value" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $WifiSense2 -Name "Value" -Value 0 -Type DWord -Force
    Write-Log "Wi-Fi Sense disabled" "SUCCESS"
    
    # Disable Telemetry (Data Collection)
    Write-Log "Disabling Data Collection..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
    Write-Log "Data Collection disabled" "SUCCESS"
    
    # Disable Cortana
    Write-Log "Disabling Cortana..."
    $CortanaSearch = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    if (-not (Test-Path $CortanaSearch)) { New-Item -Path $CortanaSearch -Force | Out-Null }
    Set-ItemProperty -Path $CortanaSearch -Name "AllowCortana" -Value 0 -Type DWord -Force
    
    $Cortana1 = "HKCU:\SOFTWARE\Microsoft\Personalization\Settings"
    $Cortana2 = "HKCU:\SOFTWARE\Microsoft\InputPersonalization"
    $Cortana3 = "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"
    if (-not (Test-Path $Cortana1)) { New-Item -Path $Cortana1 -Force | Out-Null }
    if (-not (Test-Path $Cortana2)) { New-Item -Path $Cortana2 -Force | Out-Null }
    if (-not (Test-Path $Cortana3)) { New-Item -Path $Cortana3 -Force | Out-Null }
    Set-ItemProperty -Path $Cortana1 -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $Cortana2 -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $Cortana2 -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $Cortana3 -Name "HarvestContacts" -Value 0 -Type DWord -Force
    Write-Log "Cortana disabled" "SUCCESS"
    
    # Disable Live Tiles
    Write-Log "Disabling Live Tiles..."
    $LiveTiles = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
    if (-not (Test-Path $LiveTiles)) { New-Item -Path $LiveTiles -Force | Out-Null }
    Set-ItemProperty -Path $LiveTiles -Name "NoTileApplicationNotification" -Value 1 -Type DWord -Force
    Write-Log "Live Tiles disabled" "SUCCESS"
    
    # Additional SubscribedContent entries
    Write-Log "Disabling additional suggestions & tips..."
    $CDM = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-353698Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord -Force
    Write-Log "Suggestions & tips disabled" "SUCCESS"
    
    # Disable Feedback Notifications
    Write-Log "Disabling feedback notifications..."
    $DataCol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (-not (Test-Path $DataCol)) { New-Item -Path $DataCol -Force | Out-Null }
    Set-ItemProperty -Path $DataCol -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord -Force
    Write-Log "Feedback notifications disabled" "SUCCESS"
    
    # Disable Tailored Experiences
    Write-Log "Disabling tailored experiences..."
    $CloudContent = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $CloudContent)) { New-Item -Path $CloudContent -Force | Out-Null }
    Set-ItemProperty -Path $CloudContent -Name "DisableTailoredExperiencesWithDiagnosticData" -Value 1 -Type DWord -Force
    Write-Log "Tailored experiences disabled" "SUCCESS"
    
    # Disable Advertising ID via Group Policy
    Write-Log "Disabling Advertising ID (Group Policy)..."
    $AdvPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"
    if (-not (Test-Path $AdvPolicy)) { New-Item -Path $AdvPolicy -Force | Out-Null }
    Set-ItemProperty -Path $AdvPolicy -Name "DisabledByGroupPolicy" -Value 1 -Type DWord -Force
    Write-Log "Advertising ID policy disabled" "SUCCESS"
    
    # Disable Windows Error Reporting
    Write-Log "Disabling Windows Error Reporting..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1 -Type DWord -Force
    Write-Log "Windows Error Reporting disabled" "SUCCESS"
    
    # Disable Delivery Optimization (P2P updates)
    Write-Log "Disabling Delivery Optimization..."
    $DOConfig = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
    $DOPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    if (-not (Test-Path $DOConfig)) { New-Item -Path $DOConfig -Force | Out-Null }
    if (-not (Test-Path $DOPolicy)) { New-Item -Path $DOPolicy -Force | Out-Null }
    Set-ItemProperty -Path $DOConfig -Name "DODownloadMode" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $DOPolicy -Name "DODownloadMode" -Value 0 -Type DWord -Force
    Write-Log "Delivery Optimization disabled" "SUCCESS"
    
    # Disable Remote Assistance
    Write-Log "Disabling Remote Assistance..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0 -Type DWord -Force
    Write-Log "Remote Assistance disabled" "SUCCESS"
    
    # Hide Task View button
    Write-Log "Hiding Task View button..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force
    Write-Log "Task View button hidden" "SUCCESS"
    
    # Hide People icon
    Write-Log "Hiding People icon..."
    $People = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People"
    if (-not (Test-Path $People)) { New-Item -Path $People -Force | Out-Null }
    Set-ItemProperty -Path $People -Name "PeopleBand" -Value 0 -Type DWord -Force
    Write-Log "People icon hidden" "SUCCESS"
    
    # Disable News and Feeds
    Write-Log "Disabling News and Feeds..."
    $Feeds = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
    if (-not (Test-Path $Feeds)) { New-Item -Path $Feeds -Force | Out-Null }
    Set-ItemProperty -Path $Feeds -Name "EnableFeeds" -Value 0 -Type DWord -Force
    $FeedsView = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"
    if (-not (Test-Path $FeedsView)) { New-Item -Path $FeedsView -Force | Out-Null }
    Set-ItemProperty -Path $FeedsView -Name "ShellFeedsTaskbarViewMode" -Value 2 -Type DWord -Force
    Write-Log "News and Feeds disabled" "SUCCESS"
    
    # Hide Meet Now
    Write-Log "Hiding Meet Now..."
    $MeetNow = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (-not (Test-Path $MeetNow)) { New-Item -Path $MeetNow -Force | Out-Null }
    Set-ItemProperty -Path $MeetNow -Name "HideSCAMeetNow" -Value 1 -Type DWord -Force
    Write-Log "Meet Now hidden" "SUCCESS"
    
    # Enable Long Paths
    Write-Log "Enabling long path support..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord -Force
    Write-Log "Long paths enabled" "SUCCESS"
    
    # Performance tweaks
    Write-Log "Applying performance tweaks..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 4294967295 -Type DWord -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "AutoEndTasks" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "IRPStackSize" -Value 30 -Type DWord -Force
    Write-Log "Performance tweaks applied" "SUCCESS"
    
    # Disable PowerShell 7 Telemetry
    Write-Log "Disabling PowerShell 7 telemetry..."
    [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
    Write-Log "PowerShell 7 telemetry disabled" "SUCCESS"
    
    # Disable Copilot
    Write-Log "Disabling Windows Copilot..."
    $CopilotPolicy = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    if (-not (Test-Path $CopilotPolicy)) { New-Item -Path $CopilotPolicy -Force | Out-Null }
    Set-ItemProperty -Path $CopilotPolicy -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
    Write-Log "Windows Copilot disabled" "SUCCESS"
    
    # Disable Recall (AI feature)
    Write-Log "Disabling Windows Recall..."
    $RecallPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    if (-not (Test-Path $RecallPolicy)) { New-Item -Path $RecallPolicy -Force | Out-Null }
    Set-ItemProperty -Path $RecallPolicy -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force
    Write-Log "Windows Recall disabled" "SUCCESS"
    
    Write-Log "Telemetry & Privacy tweaks completed" "SUCCESS"
}

# ============================================================================
# SECTION 2: SERVICES
# ============================================================================
function Disable-Services {
    Write-Log "DISABLING UNNECESSARY SERVICES" "SECTION"
    
    $ServicesToDisable = @(
        "DiagTrack",           # Connected User Experiences and Telemetry
        "dmwappushservice",    # WAP Push Message Routing Service
        "WSearch",             # Windows Search
        "SysMain",             # Superfetch
        "Spooler",             # Print Spooler (if no printer)
        "WbioSrvc",            # Windows Biometric Service
        "MapsBroker",          # Downloaded Maps Manager
        "lfsvc",               # Geolocation Service
        "PhoneSvc",            # Phone Service
        "RemoteRegistry",      # Remote Registry
        "PcaSvc",              # Program Compatibility Assistant
        "WerSvc",              # Windows Error Reporting
        "TabletInputService",  # Touch Keyboard
        "Fax",                 # Fax
        "WalletService",       # Wallet Service
        "RetailDemo",          # Retail Demo
        "AJRouter",            # AllJoyn Router
        "SharedAccess",        # Internet Connection Sharing
        "SmsRouter",           # SMS Router
        "wisvc",               # Windows Insider Service
        "XblAuthManager",      # Xbox Live Auth Manager
        "XblGameSave",         # Xbox Live Game Save
        "XboxGipSvc",          # Xbox Accessory Management
        "XboxNetApiSvc"        # Xbox Live Networking
    )
    
    foreach ($service in $ServicesToDisable) {
        try {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Log "Disabled: $service" "SUCCESS"
            }
        } catch {
            Write-Log "Could not disable: $service" "WARNING"
        }
    }
    
    # Disable Windows Defender (optional - be careful!)
    Write-Log "Disabling Windows Defender real-time monitoring..."
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Write-Log "Windows Defender real-time disabled" "SUCCESS"
    
    Write-Log "Services optimization completed" "SUCCESS"
}

# ============================================================================
# SECTION 2B: WINUTIL SERVICE SYNC (SAFE MODE)
# ============================================================================
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
            
            # Progress indicator
            $percent = [math]::Round(($processed / $totalServices) * 100)
            Write-Progress -Activity "Applying WinUtil Service Config" -Status "$svcName" -PercentComplete $percent
            
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
        
        Write-Progress -Activity "Applying WinUtil Service Config" -Completed
        
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

# ============================================================================
# SECTION 3: BLOATWARE REMOVAL
# ============================================================================
function Remove-BloatwareApps {
    Write-Log "REMOVING BLOATWARE APPS" "SECTION"
    
    $Bloatware = @(
        "Microsoft.BingNews"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.Messaging"
        "Microsoft.Microsoft3DViewer"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.NetworkSpeedTest"
        "Microsoft.News"
        "Microsoft.Office.Lens"
        "Microsoft.Office.OneNote"
        "Microsoft.Office.Sway"
        "Microsoft.OneConnect"
        "Microsoft.People"
        "Microsoft.Print3D"
        "Microsoft.SkypeApp"
        "Microsoft.WindowsAlarms"
        "microsoft.windowscommunicationsapps"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.WindowsMaps"
        "Microsoft.WindowsSoundRecorder"
        "Microsoft.Xbox.TCUI"
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
        "Microsoft.MixedReality.Portal"
        "Microsoft.YourPhone"
        "Microsoft.Wallet"
        "*EclipseManager*"
        "*ActiproSoftwareLLC*"
        "*CandyCrush*"
        "*BubbleWitch*"
        "*Facebook*"
        "*Twitter*"
        "*Spotify*"
        "*Disney*"
        "*TikTok*"
        "*Clipchamp*"
    )
    
    foreach ($app in $Bloatware) {
        try {
            $pkg = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
            if ($pkg) {
                Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                Write-Log "Removed: $app" "SUCCESS"
            }
        } catch {
            Write-Log "Could not remove: $app" "WARNING"
        }
    }
    
    Write-Log "Bloatware removal completed" "SUCCESS"
}

# ============================================================================
# SECTION 4: SCHEDULED TASKS
# ============================================================================
function Disable-ScheduledTasks {
    Write-Log "DISABLING SCHEDULED TASKS" "SECTION"
    
    $TasksToDisable = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
        "\Microsoft\Windows\Autochk\Proxy"
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
        "\Microsoft\Windows\Feedback\Siuf\DmClient"
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
        "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
        "\Microsoft\Windows\DiskFootprint\Diagnostics"
        "\Microsoft\Windows\Maintenance\WinSAT"
        "\Microsoft\Windows\Maps\MapsToastTask"
        "\Microsoft\Windows\Maps\MapsUpdateTask"
        "\Microsoft\Windows\Shell\FamilySafetyMonitor"
        "\Microsoft\Windows\Shell\FamilySafetyRefreshTask"
        "\Microsoft\XblGameSave\XblGameSaveTask"
        "\Microsoft\XblGameSave\XblGameSaveTaskLogon"
    )
    
    foreach ($task in $TasksToDisable) {
        try {
            Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Disabled task: $task" "SUCCESS"
        } catch {
            Write-Log "Could not disable: $task" "WARNING"
        }
    }
    
    Write-Log "Scheduled tasks optimization completed" "SUCCESS"
}


# ============================================================================
# SECTION 5: REGISTRY OPTIMIZATIONS
# ============================================================================
function Set-RegistryOptimizations {
    Write-Log "APPLYING REGISTRY OPTIMIZATIONS" "SECTION"
    
    # Disable Game Bar/DVR
    Write-Log "Disabling Game Bar/DVR..."
    $GameDVR = "HKCU:\System\GameConfigStore"
    Set-ItemProperty -Path $GameDVR -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $GameDVR -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force
    Set-ItemProperty -Path $GameDVR -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $GameDVR -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $GameDVR -Name "GameDVR_EFSEFeatureFlags" -Value 0 -Type DWord -Force
    
    $GameBar = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    if (-not (Test-Path $GameBar)) { New-Item -Path $GameBar -Force | Out-Null }
    Set-ItemProperty -Path $GameBar -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
    
    $GameBarPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (-not (Test-Path $GameBarPolicy)) { New-Item -Path $GameBarPolicy -Force | Out-Null }
    Set-ItemProperty -Path $GameBarPolicy -Name "AllowGameDVR" -Value 0 -Type DWord -Force
    Write-Log "Game Bar/DVR disabled" "SUCCESS"
    
    # Disable Background Apps
    Write-Log "Disabling Background Apps..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BackgroundAppGlobalToggle" -Value 0 -Type DWord -Force
    Write-Log "Background Apps disabled" "SUCCESS"
    
    # Disable Transparency Effects
    Write-Log "Disabling Transparency Effects..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force
    Write-Log "Transparency Effects disabled" "SUCCESS"
    
    # Disable Animations
    Write-Log "Disabling Animations..."
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force
    Write-Log "Animations disabled" "SUCCESS"
    
    # Disable Startup Delay
    Write-Log "Disabling Startup Delay..."
    $Serialize = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
    if (-not (Test-Path $Serialize)) { New-Item -Path $Serialize -Force | Out-Null }
    Set-ItemProperty -Path $Serialize -Name "StartupDelayInMSec" -Value 0 -Type DWord -Force
    Write-Log "Startup Delay disabled" "SUCCESS"
    
    # Disable Mouse Acceleration
    Write-Log "Disabling Mouse Acceleration..."
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Force
    Write-Log "Mouse Acceleration disabled" "SUCCESS"
    
    # Disable Edge PDF Takeover
    Write-Log "Preventing Edge PDF takeover..."
    $NoPDF = "HKCR:\.pdf"
    if (Test-Path $NoPDF) {
        New-ItemProperty -Path $NoPDF -Name "NoOpenWith" -Value "" -Force -ErrorAction SilentlyContinue
        New-ItemProperty -Path $NoPDF -Name "NoStaticDefaultVerb" -Value "" -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Edge PDF takeover prevented" "SUCCESS"
    
    # Disable Hibernation
    Write-Log "Disabling Hibernation..."
    powercfg.exe /hibernate off
    $HibPath = "HKLM:\System\CurrentControlSet\Control\Session Manager\Power"
    Set-ItemProperty -Path $HibPath -Name "HibernateEnabled" -Value 0 -Type DWord -Force
    Write-Log "Hibernation disabled" "SUCCESS"
    
    Write-Log "Registry optimizations completed" "SUCCESS"
}


# ============================================================================
# SECTION 6: VBS/MEMORY INTEGRITY
# ============================================================================
function Disable-VBS {
    Write-Log "DISABLING VBS/MEMORY INTEGRITY" "SECTION"
    
    # Disable Memory Integrity (HVCI)
    Write-Log "Disabling Memory Integrity (HVCI)..."
    $HVCIPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (-not (Test-Path $HVCIPath)) { New-Item -Path $HVCIPath -Force | Out-Null }
    Set-ItemProperty -Path $HVCIPath -Name "Enabled" -Value 0 -Type DWord -Force
    Write-Log "Memory Integrity disabled" "SUCCESS"
    
    # Disable Credential Guard
    Write-Log "Disabling Credential Guard..."
    $CredGuard = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    Set-ItemProperty -Path $CredGuard -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CredGuard -Name "RequirePlatformSecurityFeatures" -Value 0 -Type DWord -Force
    
    $LsaCfg = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    Set-ItemProperty -Path $LsaCfg -Name "LsaCfgFlags" -Value 0 -Type DWord -Force
    Write-Log "Credential Guard disabled" "SUCCESS"
    
    # Disable Core Isolation
    Write-Log "Disabling Core Isolation..."
    $CoreIso = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard"
    if (-not (Test-Path $CoreIso)) { New-Item -Path $CoreIso -Force | Out-Null }
    Set-ItemProperty -Path $CoreIso -Name "Enabled" -Value 0 -Type DWord -Force
    Write-Log "Core Isolation disabled" "SUCCESS"
    
    Write-Log "VBS/Memory Integrity disabled - REBOOT REQUIRED" "WARNING"
}


# ============================================================================
# SECTION 7: NETWORK OPTIMIZATIONS
# ============================================================================
function Set-NetworkOptimizations {
    Write-Log "APPLYING NETWORK OPTIMIZATIONS" "SECTION"
    
    # Disable IPv6
    Write-Log "Disabling IPv6..."
    Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue | ForEach-Object {
        Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 255 -Type DWord -Force
    Write-Log "IPv6 disabled" "SUCCESS"
    
    # Disable Nagle's Algorithm (reduces latency)
    Write-Log "Disabling Nagle's Algorithm..."
    $NaglePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem $NaglePath | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Nagle's Algorithm disabled" "SUCCESS"
    
    # Optimize Network Throttling
    Write-Log "Optimizing Network Throttling..."
    $MultimediaPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $MultimediaPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
    Set-ItemProperty -Path $MultimediaPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
    Write-Log "Network Throttling optimized" "SUCCESS"
    
    # Disable Network Location Wizard
    Write-Log "Disabling Network Location Wizard..."
    $NLW = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff"
    if (-not (Test-Path $NLW)) { New-Item -Path $NLW -Force | Out-Null }
    Write-Log "Network Location Wizard disabled" "SUCCESS"
    
    # Flush DNS
    Write-Log "Flushing DNS cache..."
    ipconfig /flushdns | Out-Null
    Write-Log "DNS cache flushed" "SUCCESS"
    
    Write-Log "Network optimizations completed" "SUCCESS"
}


# ============================================================================
# SECTION 8: ONEDRIVE REMOVAL
# ============================================================================
function Remove-OneDrive {
    Write-Log "REMOVING ONEDRIVE" "SECTION"
    
    # Stop OneDrive processes
    Write-Log "Stopping OneDrive processes..."
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "OneDriveSetup" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Log "OneDrive processes stopped" "SUCCESS"
    
    # Uninstall OneDrive
    Write-Log "Uninstalling OneDrive..."
    $onedrive64 = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
    $onedrive32 = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
    
    if (Test-Path $onedrive64) {
        Start-Process $onedrive64 "/uninstall" -NoNewWindow -Wait
        Write-Log "OneDrive uninstalled (64-bit)" "SUCCESS"
    } elseif (Test-Path $onedrive32) {
        Start-Process $onedrive32 "/uninstall" -NoNewWindow -Wait
        Write-Log "OneDrive uninstalled (32-bit)" "SUCCESS"
    } else {
        Write-Log "OneDrive installer not found" "WARNING"
    }
    
    # Remove leftover folders
    Write-Log "Removing OneDrive folders..."
    $foldersToRemove = @(
        "$env:USERPROFILE\OneDrive"
        "$env:LOCALAPPDATA\Microsoft\OneDrive"
        "$env:PROGRAMDATA\Microsoft OneDrive"
        "C:\OneDriveTemp"
    )
    
    foreach ($folder in $foldersToRemove) {
        if (Test-Path $folder) {
            Remove-Item -Path $folder -Force -Recurse -ErrorAction SilentlyContinue
            Write-Log "Removed: $folder" "SUCCESS"
        }
    }
    
    # Disable OneDrive via Group Policy
    Write-Log "Disabling OneDrive via Group Policy..."
    $OneDriveKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
    if (-not (Test-Path $OneDriveKey)) { New-Item -Path $OneDriveKey -Force | Out-Null }
    Set-ItemProperty -Path $OneDriveKey -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -Force
    Write-Log "OneDrive disabled via policy" "SUCCESS"
    
    # Remove OneDrive from Explorer
    Write-Log "Removing OneDrive from Explorer..."
    $CLSID1 = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    $CLSID2 = "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    if (Test-Path $CLSID1) {
        Set-ItemProperty -Path $CLSID1 -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -Force
    }
    if (Test-Path $CLSID2) {
        Set-ItemProperty -Path $CLSID2 -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -Force
    }
    Write-Log "OneDrive removed from Explorer" "SUCCESS"
    
    Write-Log "OneDrive removal completed" "SUCCESS"
}

# ============================================================================
# SECTION 9: SYSTEM MAINTENANCE
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


# ============================================================================
# SECTION 10: WIFI PASSWORD EXTRACTION
# ============================================================================
function Get-WifiPasswords {
    Write-Log "EXTRACTING WI-FI PASSWORDS" "SECTION"
    
    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
        ($_ -split ":")[1].Trim()
    }
    
    if ($profiles.Count -eq 0) {
        Write-Log "No Wi-Fi profiles found" "WARNING"
        return
    }
    
    $wifiData = @()
    foreach ($profile in $profiles) {
        $profileInfo = netsh wlan show profile name="$profile" key=clear 2>$null
        $password = ($profileInfo | Select-String "Key Content") -replace ".*:\s*", ""
        
        if ([string]::IsNullOrEmpty($password)) {
            $password = "(No password / Open network)"
        }
        
        $wifiData += [PSCustomObject]@{
            SSID = $profile
            Password = $password
        }
        
        Write-Log "SSID: $profile | Password: $password" "INFO"
    }
    
    # Save to file
    $wifiFile = "C:\temp\wifi_passwords_$(Get-Date -Format 'yyyy-MM-dd').txt"
    $wifiData | Format-Table -AutoSize | Out-String | Set-Content -Path $wifiFile
    Write-Log "Wi-Fi passwords saved to: $wifiFile" "SUCCESS"
    
    # Display table
    Write-Host ""
    $wifiData | Format-Table -AutoSize
}

# ============================================================================
# SECTION 11: PATCHMYPC - SOFTWARE UPDATER
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
                # Download exe
                $exeUrl = "https://patchmypc.com/freeupdater/PatchMyPC.exe"
                Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing
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
                # Download exe only (no ini = user selects)
                $exeUrl = "https://patchmypc.com/freeupdater/PatchMyPC.exe"
                Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing
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

# Helper function to set Adobe Reader as default PDF viewer
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
            
            # Remove existing UserChoice (requires special handling)
            # Windows protects UserChoice with a hash, so we use assoc/ftype or the Settings app
            
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

# Helper function to install RustDesk
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
                iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                
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
        Create-RustDeskShortcut
    }
}

# Helper function to create RustDesk desktop shortcut
function Create-RustDeskShortcut {
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

# Helper function to install AnyDesk
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
                iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                
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
        Create-AnyDeskShortcut
    }
}

# Helper function to create AnyDesk desktop shortcut
function Create-AnyDeskShortcut {
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

# ============================================================================
# SECURITY TOOLS INSTALLATION MENU
# ============================================================================
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

# Helper function to install a single security tool
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

# Helper function to enable and configure Windows Defender
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

# Helper function to install all security tools (not recommended)
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
                }
            } catch {
                Write-Log "Error installing $($pkg.Name): $_" "WARNING"
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

# ============================================================================
# SECTION 12: OFFICE TOOL PLUS
# ============================================================================
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
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
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
            irm https://officetool.plus | iex
            Write-Log "Office Tool Plus launched via web installer" "SUCCESS"
        } catch {
            Write-Log "Web installer also failed: $_" "ERROR"
            Write-Host "Manual download: https://otp.landian.vip/" -ForegroundColor Cyan
        }
    }
}

# ============================================================================
# SECTION 13: MICROSOFT ACTIVATION SCRIPT (MAS)
# ============================================================================
function Run-MAS {
    Write-Log "LAUNCHING MICROSOFT ACTIVATION SCRIPT" "SECTION"
    
    Write-Host ""
    Write-Host "This will launch the Microsoft Activation Script (MAS)." -ForegroundColor Yellow
    Write-Host "A new window will open with activation options." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        # Updated MAS link as of 2025
        Write-Log "Downloading and running MAS from get.activated.win..."
        irm https://get.activated.win | iex
        Write-Log "MAS launched successfully" "SUCCESS"
    } catch {
        Write-Log "Primary method failed, trying alternative..." "WARNING"
        try {
            # Alternative method with DoH
            iex (curl.exe -s --doh-url https://1.1.1.1/dns-query https://get.activated.win | Out-String)
            Write-Log "MAS launched via alternative method" "SUCCESS"
        } catch {
            Write-Log "Failed to launch MAS: $_" "ERROR"
            Write-Host "Manual method: Open PowerShell and run:" -ForegroundColor Yellow
            Write-Host "irm https://get.activated.win | iex" -ForegroundColor Cyan
        }
    }
}


# ============================================================================
# SECTION 14: VERIFICATION
# ============================================================================
function Verify-OptimizationStatus {
    Write-Log "VERIFYING OPTIMIZATION STATUS" "SECTION"
    
    Write-Host ""
    Write-Host "=== SYSTEM STATUS ===" -ForegroundColor Cyan
    
    # Memory Usage
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMem = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMem = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMem = $totalMem - $freeMem
    $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 1)
    Write-Host "Memory: $usedMem GB / $totalMem GB ($memPercent% used)" -ForegroundColor $(if ($memPercent -lt 50) { "Green" } else { "Yellow" })
    
    # Running Services
    $runningServices = (Get-Service | Where-Object { $_.Status -eq 'Running' }).Count
    Write-Host "Running Services: $runningServices" -ForegroundColor $(if ($runningServices -lt 100) { "Green" } else { "Yellow" })
    
    # Startup Programs
    $startupItems = (Get-CimInstance Win32_StartupCommand).Count
    Write-Host "Startup Items: $startupItems" -ForegroundColor $(if ($startupItems -lt 10) { "Green" } else { "Yellow" })
    
    # Power Plan
    $powerPlan = powercfg /getactivescheme
    $planName = if ($powerPlan -match '"([^"]+)"') { $matches[1] } else { "Unknown" }
    Write-Host "Power Plan: $planName" -ForegroundColor $(if ($planName -like "*High*" -or $planName -like "*Ultimate*") { "Green" } else { "Yellow" })
    
    Write-Host ""
    Write-Host "=== KEY SETTINGS ===" -ForegroundColor Cyan
    
    # Check Telemetry
    $telemetry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    $telemetryStatus = if ($telemetry.AllowTelemetry -eq 0) { "Disabled" } else { "Enabled" }
    Write-Host "Telemetry: $telemetryStatus" -ForegroundColor $(if ($telemetryStatus -eq "Disabled") { "Green" } else { "Red" })
    
    # Check Game Bar
    $gameBar = Get-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue
    $gameBarStatus = if ($gameBar.GameDVR_Enabled -eq 0) { "Disabled" } else { "Enabled" }
    Write-Host "Game Bar: $gameBarStatus" -ForegroundColor $(if ($gameBarStatus -eq "Disabled") { "Green" } else { "Red" })
    
    # Check VBS
    $vbs = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -ErrorAction SilentlyContinue
    $vbsStatus = if ($vbs.Enabled -eq 0) { "Disabled" } else { "Enabled" }
    Write-Host "VBS/Memory Integrity: $vbsStatus" -ForegroundColor $(if ($vbsStatus -eq "Disabled") { "Green" } else { "Red" })
    
    # Check Defender Real-time
    $defender = Get-MpPreference -ErrorAction SilentlyContinue
    $defenderStatus = if ($defender.DisableRealtimeMonitoring -eq $true) { "Disabled" } else { "Enabled" }
    Write-Host "Defender Real-time: $defenderStatus" -ForegroundColor $(if ($defenderStatus -eq "Disabled") { "Green" } else { "Yellow" })
    
    # Check IPv6
    $ipv6 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -ErrorAction SilentlyContinue
    $ipv6Status = if ($ipv6.DisabledComponents -eq 255) { "Disabled" } else { "Enabled" }
    Write-Host "IPv6: $ipv6Status" -ForegroundColor $(if ($ipv6Status -eq "Disabled") { "Green" } else { "Yellow" })
    
    # Check Background Apps
    $bgApps = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
    $bgAppsStatus = if ($bgApps.GlobalUserDisabled -eq 1) { "Disabled" } else { "Enabled" }
    Write-Host "Background Apps: $bgAppsStatus" -ForegroundColor $(if ($bgAppsStatus -eq "Disabled") { "Green" } else { "Red" })
    
    Write-Host ""
    Write-Host "=== DISABLED SERVICES ===" -ForegroundColor Cyan
    $criticalServices = @("DiagTrack", "WSearch", "SysMain", "dmwappushservice")
    foreach ($svc in $criticalServices) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            $status = $service.Status
            $startType = $service.StartType
            $color = if ($startType -eq "Disabled") { "Green" } else { "Yellow" }
            Write-Host "$svc : $status ($startType)" -ForegroundColor $color
        }
    }
    
    Write-Host ""
    Write-Log "Verification completed" "SUCCESS"
}

# ============================================================================
# SECTION 15: POWER PLAN
# ============================================================================
function Set-PowerPlan {
    Set-ConsoleSize
    Clear-Host
    Write-Log "POWER PLAN SETTINGS" "SECTION"
    
    Write-Host ""
    Write-Host "Power Plan Options:" -ForegroundColor Cyan
    Write-Host "  [1] High Performance"
    Write-Host "  [2] Ultimate Performance (creates if not exists)"
    Write-Host "  [3] Balanced (default)"
    Write-Host "  [0] Cancel"
    Write-Host ""
    
    $choice = Read-Host "Select option"
    
    switch ($choice) {
        "1" {
            Write-Log "Setting High Performance power plan..."
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
            Set-NeverSleepOnAC
            Write-Log "High Performance power plan activated" "SUCCESS"
        }
        "2" {
            Write-Log "Creating/Setting Ultimate Performance power plan..."
            # Create Ultimate Performance plan (may already exist)
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            # Find and activate it
            $ultimate = powercfg /list | Select-String "Ultimate Performance"
            if ($ultimate) {
                $guid = ($ultimate -split '\s+')[3]
                powercfg /setactive $guid
                Write-Log "Ultimate Performance power plan activated" "SUCCESS"
            } else {
                # Fallback to High Performance
                powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
                Write-Log "Ultimate not available, set High Performance" "WARNING"
            }
            Set-NeverSleepOnAC
        }
        "3" {
            Write-Log "Setting Balanced power plan..."
            powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
            Set-NeverSleepOnAC
            Write-Log "Balanced power plan activated" "SUCCESS"
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Set-NeverSleepOnAC {
    Write-Log "Configuring power settings..."
    
    # === AC POWER (Plugged In) - Never sleep/hibernate/turn off screen ===
    powercfg /change standby-timeout-ac 0
    Write-Log "Sleep on AC: Never" "SUCCESS"
    
    powercfg /change hibernate-timeout-ac 0
    Write-Log "Hibernate on AC: Never" "SUCCESS"
    
    powercfg /change monitor-timeout-ac 0
    Write-Log "Turn off screen on AC: Never" "SUCCESS"
    
    # Disable hybrid sleep on AC
    powercfg /setacvalueindex scheme_current sub_sleep hybridsleep 0
    Write-Log "Hybrid sleep on AC: Disabled" "SUCCESS"
    
    # === BATTERY POWER - Reasonable timeouts ===
    powercfg /change monitor-timeout-dc 30
    Write-Log "Turn off screen on Battery: 30 minutes" "SUCCESS"
    
    powercfg /change standby-timeout-dc 60
    Write-Log "Sleep on Battery: 1 hour" "SUCCESS"
    
    powercfg /change hibernate-timeout-dc 120
    Write-Log "Hibernate on Battery: 2 hours" "SUCCESS"
    
    # Apply changes
    powercfg /setactive scheme_current
    
    Write-Log "Power settings configured - AC: never sleep | Battery: screen 30min, sleep 1hr" "SUCCESS"
}

# ============================================================================
# SECTION 16: O&O SHUTUP10
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
                # Download OOSU10
                Write-Log "Downloading O&O ShutUp10..."
                Invoke-WebRequest -Uri "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -OutFile $exePath -UseBasicParsing
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
                # Download OOSU10
                Write-Log "Downloading O&O ShutUp10..."
                Invoke-WebRequest -Uri "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -OutFile $exePath -UseBasicParsing
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

# ============================================================================
# SECTION 17: RESET GROUP POLICY
# ============================================================================
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

# ============================================================================
# SECTION 18: RESET WMI
# ============================================================================
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

# ============================================================================
# SECTION 19: DISK CLEANUP
# ============================================================================
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

# ============================================================================
# SECTION 20: WINDOWS UPDATE CONTROL
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

# Helper function for AIO Update Pause Task
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

# Helper function for AIO WUpdater GUI
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

# Helper function to install Windows Updates via PowerShell
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

# Helper function to update drivers via Windows Update
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

# ============================================================================
# SECTION 21: DRIVER MANAGEMENT
# ============================================================================
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
                
                $result = DISM /Online /Export-Driver /Destination:$BackupDir 2>&1
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
                    $result = DISM /Online /Add-Driver /Driver:$BackupDir /Recurse 2>&1
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

# ============================================================================
# SECTION 22: NETWORK RESET
# ============================================================================
function Reset-Network {
    Write-Log "RESETTING NETWORK CONFIGURATION" "SECTION"
    
    Write-Host ""
    Write-Host "This will reset all network settings to defaults." -ForegroundColor Yellow
    Write-Host "You may lose custom network configurations." -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (Y/N)"
    
    if ($confirm -eq "Y" -or $confirm -eq "y") {
        try {
            # Reset WinSock catalog
            Write-Log "Resetting WinSock catalog..."
            netsh winsock reset | Out-Null
            Write-Log "WinSock reset" "SUCCESS"
            
            # Reset WinHTTP proxy
            Write-Log "Resetting WinHTTP proxy..."
            netsh winhttp reset proxy | Out-Null
            Write-Log "WinHTTP proxy reset" "SUCCESS"
            
            # Reset IP configuration
            Write-Log "Resetting IP configuration..."
            netsh int ip reset | Out-Null
            Write-Log "IP configuration reset" "SUCCESS"
            
            # Flush DNS
            Write-Log "Flushing DNS cache..."
            ipconfig /flushdns | Out-Null
            Write-Log "DNS cache flushed" "SUCCESS"
            
            # Release and renew IP
            Write-Log "Releasing and renewing IP..."
            ipconfig /release | Out-Null
            ipconfig /renew | Out-Null
            Write-Log "IP renewed" "SUCCESS"
            
            Write-Log "Network reset completed" "SUCCESS"
            Write-Host ""
            Write-Host "Please reboot your computer to complete the reset." -ForegroundColor Yellow
        } catch {
            Write-Log "Error: $_" "ERROR"
        }
    } else {
        Write-Log "Cancelled" "INFO"
    }
}

# ============================================================================
# SECTION 23: WINDOWS UPDATE REPAIR
# ============================================================================
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

# ============================================================================
# SECTION 24: RUN ALL OPTIMIZATIONS
# ============================================================================
function Run-AllOptimizations {
    Write-Log "RUNNING ALL OPTIMIZATIONS" "SECTION"
    Write-Host ""
    Write-Host "This will apply ALL optimizations. Some changes require a reboot." -ForegroundColor Yellow
    Write-Host "Press any key to continue or Ctrl+C to cancel..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    Disable-Telemetry
    Disable-Services
    Remove-BloatwareApps
    Disable-ScheduledTasks
    Set-RegistryOptimizations
    Disable-VBS
    Set-NetworkOptimizations
    
    Write-Host ""
    Write-Log "ALL OPTIMIZATIONS COMPLETED" "SECTION"
    Write-Host ""
    Write-Host "A reboot is recommended to apply all changes." -ForegroundColor Yellow
    Write-Host ""
    
    $reboot = Read-Host "Reboot now? (Y/N)"
    if ($reboot -eq "Y" -or $reboot -eq "y") {
        Write-Log "Rebooting system..."
        Restart-Computer -Force
    }
}

# ============================================================================
# SECTION 25: FULL SETUP WORKFLOW
# ============================================================================
function Run-FullSetup {
    Write-Log "RUNNING FULL SETUP WORKFLOW" "SECTION"
    Write-Host ""
    Write-Host "This will run the full setup workflow:" -ForegroundColor Yellow
    Write-Host "  1. PatchMyPC (install/update software)" -ForegroundColor Gray
    Write-Host "  2. Office Tool Plus (install Office)" -ForegroundColor Gray
    Write-Host "  3. Re-run Services optimization" -ForegroundColor Gray
    Write-Host "  4. Microsoft Activation Script (MAS)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press any key to continue or Ctrl+C to cancel..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Step 1: PatchMyPC
    Write-Host ""
    Write-Host "=== STEP 1: PatchMyPC ===" -ForegroundColor Cyan
    Write-Host "Install/update common software first." -ForegroundColor Gray
    Start-PatchMyPC
    
    Write-Host ""
    Write-Host "Press any key when PatchMyPC is done..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Step 2: Office Tool Plus
    Write-Host ""
    Write-Host "=== STEP 2: Office Tool Plus ===" -ForegroundColor Cyan
    Write-Host "Install Microsoft Office." -ForegroundColor Gray
    Start-OfficeTool
    
    Write-Host ""
    Write-Host "Press any key when Office installation is done..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Step 3: Re-run Services optimization
    Write-Host ""
    Write-Host "=== STEP 3: Services Optimization ===" -ForegroundColor Cyan
    Write-Host "Re-running services optimization after software installs..." -ForegroundColor Gray
    Disable-Services
    
    # Step 4: MAS
    Write-Host ""
    Write-Host "=== STEP 4: Microsoft Activation Script ===" -ForegroundColor Cyan
    Write-Host "Activate Windows and Office." -ForegroundColor Gray
    Run-MAS
    
    Write-Host ""
    Write-Log "FULL SETUP WORKFLOW COMPLETED" "SECTION"
    Write-Host ""
}

# ============================================================================
# SECTION 24: WINDOWS DEFENDER CONTROL
# ============================================================================
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

# ============================================================================
# SECTION 25: ADVANCED DEBLOAT SCRIPTS (AIO)
# ============================================================================
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

# ============================================================================
# SECTION 26: WINGET/CHOCOLATEY HELPER FUNCTIONS
# ============================================================================
# Note: These functions are called from the PatchMyPC menu (Option 11)

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
        
        $result = winget install $pkg --accept-package-agreements --accept-source-agreements 2>&1
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
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
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

function Install-ChocoGUI {
    Write-Log "INSTALLING CHOCOLATEY GUI" "SECTION"
    
    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoPath) {
        Write-Log "Chocolatey not installed. Run option 6 first." "ERROR"
        return
    }
    
    Write-Host "Installing Chocolatey GUI..." -ForegroundColor Cyan
    choco install chocolateygui -y
    
    Write-Log "Chocolatey GUI installed" "SUCCESS"
    Write-Host "You can now run 'chocolateygui' from Start Menu" -ForegroundColor Green
}

# ============================================================================
# SECTION 27: DISM++ STYLE TWEAKS
# ============================================================================
function Start-DismPlusTweaks {
    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  DISM++ Style Tweaks" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Taskbar & Start Menu Tweaks"
        Write-Host "  [2] Explorer Tweaks"
        Write-Host "  [3] Desktop Icons"
        Write-Host "  [4] Context Menu Tweaks"
        Write-Host "  [5] Security Settings"
        Write-Host "  [6] Windows Experience"
        Write-Host "  [7] Windows Photo Viewer (Enable)"
        Write-Host "  [8] Notepad, Media Player & Services"
        Write-Host "  [9] Internet Explorer / IE Mode"
        Write-Host "  [10] Apply ALL Tweaks"
        Write-Host "  [0] Back to main menu"
        Write-Host ""
        
        $choice = Read-Host "Select option"
        
        switch ($choice) {
            "1" { Apply-TaskbarTweaks }
            "2" { Apply-ExplorerTweaks }
            "3" { Apply-DesktopIcons }
            "4" { Apply-ContextMenuTweaks }
            "5" { Apply-SecurityTweaks }
            "6" { Apply-WindowsExperienceTweaks }
            "7" { Enable-WindowsPhotoViewer }
            "8" { Apply-NotepadMediaTweaks }
            "9" { Apply-InternetExplorerTweaks }
            "10" {
                Write-Log "Applying ALL DISM++ style tweaks..."
                Apply-TaskbarTweaks
                Apply-ExplorerTweaks
                Apply-DesktopIcons
                Apply-ContextMenuTweaks
                Apply-SecurityTweaks
                Apply-WindowsExperienceTweaks
                Enable-WindowsPhotoViewer
                Apply-NotepadMediaTweaks
                Apply-InternetExplorerTweaks
                Write-Log "All DISM++ tweaks applied!" "SUCCESS"
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

function Apply-TaskbarTweaks {
    Write-Log "TASKBAR & START MENU TWEAKS" "SECTION"
    
    # Hide People on Taskbar
    Write-Log "Hiding People on Taskbar..."
    $People = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People"
    if (-not (Test-Path $People)) { New-Item -Path $People -Force | Out-Null }
    Set-ItemProperty -Path $People -Name "PeopleBand" -Value 0 -Type DWord -Force
    Write-Log "People hidden" "SUCCESS"
    
    # Show clock on taskbar
    Write-Log "Ensuring clock is visible on taskbar..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSecondsInSystemClock" -Value 1 -Type DWord -Force
    Write-Log "Clock configured" "SUCCESS"
    
    # Show color on Start Menu, Taskbar, Action Center, Title bar
    Write-Log "Enabling color on Start Menu, Taskbar, Action Center..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "ColorPrevalence" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\DWM" -Name "ColorPrevalence" -Value 1 -Type DWord -Force
    Write-Log "Color enabled on system elements" "SUCCESS"
    
    # Make Start Menu, Taskbar, Action Center transparent
    Write-Log "Enabling transparency..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Type DWord -Force
    Write-Log "Transparency enabled" "SUCCESS"
    
    # Hide Language Bar from taskbar
    Write-Log "Hiding Language Bar..."
    $LangBar = "HKCU:\SOFTWARE\Microsoft\CTF\LangBar"
    if (-not (Test-Path $LangBar)) { New-Item -Path $LangBar -Force | Out-Null }
    Set-ItemProperty -Path $LangBar -Name "ShowStatus" -Value 3 -Type DWord -Force
    Write-Log "Language Bar hidden" "SUCCESS"
    
    # Hide Help button on Language Bar
    Write-Log "Hiding Help button on Language Bar..."
    Set-ItemProperty -Path $LangBar -Name "ExtraIconsOnMinimized" -Value 0 -Type DWord -Force
    Write-Log "Help button hidden" "SUCCESS"
    
    # Windows 11: Align Start Menu to Left
    Write-Log "Aligning Start Menu to Left (Windows 11)..."
    $Win11Taskbar = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $Win11Taskbar -Name "TaskbarAl" -Value 0 -Type DWord -Force
    Write-Log "Start Menu aligned to left" "SUCCESS"
    
    Write-Log "Taskbar tweaks completed" "SUCCESS"
}

function Apply-ExplorerTweaks {
    Write-Log "EXPLORER TWEAKS" "SECTION"
    
    $Advanced = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    
    # Open File Explorer to This PC
    Write-Log "Setting Explorer to open to This PC..."
    Set-ItemProperty -Path $Advanced -Name "LaunchTo" -Value 1 -Type DWord -Force
    Write-Log "Explorer opens to This PC" "SUCCESS"
    
    # Show extensions for all file types
    Write-Log "Showing file extensions..."
    Set-ItemProperty -Path $Advanced -Name "HideFileExt" -Value 0 -Type DWord -Force
    Write-Log "File extensions visible" "SUCCESS"
    
    # Show all hidden files
    Write-Log "Showing hidden files..."
    Set-ItemProperty -Path $Advanced -Name "Hidden" -Value 1 -Type DWord -Force
    Write-Log "Hidden files visible" "SUCCESS"
    
    # Show protected operating system files
    Write-Log "Showing protected OS files..."
    Set-ItemProperty -Path $Advanced -Name "ShowSuperHidden" -Value 1 -Type DWord -Force
    Write-Log "Protected OS files visible" "SUCCESS"
    
    # Launch folder windows in separate process
    Write-Log "Enabling separate process for folders..."
    Set-ItemProperty -Path $Advanced -Name "SeparateProcess" -Value 1 -Type DWord -Force
    Write-Log "Separate process enabled" "SUCCESS"
    
    # Show full path in title bar
    Write-Log "Showing full path in title bar..."
    $CabinetState = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CabinetState"
    if (-not (Test-Path $CabinetState)) { New-Item -Path $CabinetState -Force | Out-Null }
    Set-ItemProperty -Path $CabinetState -Name "FullPath" -Value 1 -Type DWord -Force
    Write-Log "Full path shown" "SUCCESS"
    
    # Disable video file preview (performance)
    Write-Log "Disabling video preview in Explorer..."
    $Preview = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
    Set-ItemProperty -Path $Preview -Name "DisableThumbnailCache" -Value 1 -Type DWord -Force
    Write-Log "Video preview disabled" "SUCCESS"
    
    # Do not display Frequently Used Folders in Quick Access
    Write-Log "Disabling frequent folders in Quick Access..."
    Set-ItemProperty -Path $Advanced -Name "ShowFrequent" -Value 0 -Type DWord -Force
    Write-Log "Frequent folders disabled" "SUCCESS"
    
    # Do not display Recently Used Files in Quick Access
    Write-Log "Disabling recent files in Quick Access..."
    Set-ItemProperty -Path $Advanced -Name "ShowRecent" -Value 0 -Type DWord -Force
    Write-Log "Recent files disabled" "SUCCESS"
    
    Write-Log "Explorer tweaks completed" "SUCCESS"
}

function Apply-DesktopIcons {
    Set-ConsoleSize
    Clear-Host
    Write-Log "DESKTOP ICONS" "SECTION"
    
    Write-Host ""
    Write-Host "Select desktop icons to show:" -ForegroundColor Cyan
    Write-Host "  [1] This PC"
    Write-Host "  [2] Recycle Bin"
    Write-Host "  [3] Control Panel"
    Write-Host "  [4] User Folder"
    Write-Host "  [5] Network"
    Write-Host "  [6] Show ALL icons"
    Write-Host "  [0] Skip"
    Write-Host ""
    
    $iconChoice = Read-Host "Select option"
    
    $DesktopIcons = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
    if (-not (Test-Path $DesktopIcons)) { New-Item -Path $DesktopIcons -Force | Out-Null }
    
    # CLSID values: 0 = show, 1 = hide
    # {20D04FE0-3AEA-1069-A2D8-08002B30309D} = This PC
    # {645FF040-5081-101B-9F08-00AA002F954E} = Recycle Bin
    # {5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0} = Control Panel
    # {59031a47-3f72-44a7-89c5-5595fe6b30ee} = User Folder
    # {F02C1A0D-BE21-4350-88B0-7367FC96EF3C} = Network
    
    switch ($iconChoice) {
        "1" {
            Set-ItemProperty -Path $DesktopIcons -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Type DWord -Force
            Write-Log "This PC icon shown" "SUCCESS"
        }
        "2" {
            Set-ItemProperty -Path $DesktopIcons -Name "{645FF040-5081-101B-9F08-00AA002F954E}" -Value 0 -Type DWord -Force
            Write-Log "Recycle Bin icon shown" "SUCCESS"
        }
        "3" {
            Set-ItemProperty -Path $DesktopIcons -Name "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" -Value 0 -Type DWord -Force
            Write-Log "Control Panel icon shown" "SUCCESS"
        }
        "4" {
            Set-ItemProperty -Path $DesktopIcons -Name "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Value 0 -Type DWord -Force
            Write-Log "User Folder icon shown" "SUCCESS"
        }
        "5" {
            Set-ItemProperty -Path $DesktopIcons -Name "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" -Value 0 -Type DWord -Force
            Write-Log "Network icon shown" "SUCCESS"
        }
        "6" {
            Set-ItemProperty -Path $DesktopIcons -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $DesktopIcons -Name "{645FF040-5081-101B-9F08-00AA002F954E}" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $DesktopIcons -Name "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $DesktopIcons -Name "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $DesktopIcons -Name "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" -Value 0 -Type DWord -Force
            Write-Log "All desktop icons shown" "SUCCESS"
        }
        "0" { Write-Log "Skipped" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
    
    # Refresh desktop
    $code = @'
[System.Runtime.InteropServices.DllImport("Shell32.dll")]
private static extern int SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
public static void Refresh() { SHChangeNotify(0x8000000, 0x1000, IntPtr.Zero, IntPtr.Zero); }
'@
    Add-Type -MemberDefinition $code -Namespace WinAPI -Name Explorer -ErrorAction SilentlyContinue
    [WinAPI.Explorer]::Refresh()
    
    Write-Log "Desktop icons configured" "SUCCESS"
}

function Apply-ContextMenuTweaks {
    Write-Log "CONTEXT MENU TWEAKS" "SECTION"
    
    # Enable "End Task" in taskbar context menu (Windows 11) - Safe, HKCU only
    Write-Log "Enabling 'End Task' in taskbar context menu..."
    try {
        $EndTask = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
        if (-not (Test-Path $EndTask)) { New-Item -Path $EndTask -Force | Out-Null }
        Set-ItemProperty -Path $EndTask -Name "TaskbarEndTask" -Value 1 -Type DWord -Force
        Write-Log "End Task enabled in taskbar" "SUCCESS"
    } catch {
        Write-Log "Could not enable End Task: $_" "WARNING"
    }
    
    # Restore classic context menu (Windows 11) - Safe, HKCU only
    Write-Log "Restoring classic context menu (Windows 11)..."
    try {
        $ClassicMenu = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        if (-not (Test-Path $ClassicMenu)) { 
            New-Item -Path $ClassicMenu -Force | Out-Null 
        }
        Set-ItemProperty -Path $ClassicMenu -Name "(Default)" -Value "" -Force
        Write-Log "Classic context menu restored" "SUCCESS"
    } catch {
        Write-Log "Could not restore classic menu: $_" "WARNING"
    }
    
    # Disable "Scan with Windows Defender" context menu (HKCR - may need admin)
    Write-Log "Removing 'Scan with Defender' from context menu..."
    try {
        $defenderPath = "Registry::HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\EPP"
        if (Test-Path $defenderPath) {
            Remove-Item -Path $defenderPath -Recurse -Force -ErrorAction Stop
            Write-Log "Defender scan removed from context menu" "SUCCESS"
        } else {
            Write-Log "Defender context menu entry not found (may already be removed)" "INFO"
        }
    } catch {
        Write-Log "Could not remove Defender scan (may need TrustedInstaller): $_" "WARNING"
    }
    
    # Hide BitLocker context menu entries (safer than delete)
    Write-Log "Hiding BitLocker from context menu..."
    $BitLockerKeys = @(
        "encrypt-bde", "encrypt-bde-elev", "manage-bde", 
        "resume-bde", "resume-bde-elev", "unlock-bde"
    )
    foreach ($keyName in $BitLockerKeys) {
        try {
            $keyPath = "Registry::HKEY_CLASSES_ROOT\Drive\shell\$keyName"
            if (Test-Path $keyPath) {
                Set-ItemProperty -Path $keyPath -Name "ProgrammaticAccessOnly" -Value "" -Force -ErrorAction Stop
            }
        } catch {
            # Silently skip - these may not exist or need higher permissions
        }
    }
    Write-Log "BitLocker context menu entries processed" "SUCCESS"
    
    Write-Log "Context menu tweaks completed" "SUCCESS"
    Write-Host ""
    Write-Host "Note: Some changes require Explorer restart or logoff to take effect." -ForegroundColor Yellow
}

function Apply-SecurityTweaks {
    Write-Log "SECURITY SETTINGS" "SECTION"
    
    # Administrator approval mode for built-in administrator
    Write-Log "Configuring Admin Approval Mode..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "FilterAdministratorToken" -Value 1 -Type DWord -Force
    Write-Log "Admin Approval Mode configured" "SUCCESS"
    
    # Disable SmartScreen Filter
    Write-Log "Disabling SmartScreen Filter..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force
    $SmartScreen = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
    if (-not (Test-Path $SmartScreen)) { New-Item -Path $SmartScreen -Force | Out-Null }
    Set-ItemProperty -Path $SmartScreen -Name "EnableWebContentEvaluation" -Value 0 -Type DWord -Force
    Write-Log "SmartScreen disabled" "SUCCESS"
    
    # Disable safety warning when opening programs
    Write-Log "Disabling 'Open File - Security Warning'..."
    $Associations = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations"
    if (-not (Test-Path $Associations)) { New-Item -Path $Associations -Force | Out-Null }
    Set-ItemProperty -Path $Associations -Name "LowRiskFileTypes" -Value ".exe;.msi;.bat;.cmd;.ps1;.reg;.vbs;.js" -Force
    
    $Attachments = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments"
    if (-not (Test-Path $Attachments)) { New-Item -Path $Attachments -Force | Out-Null }
    Set-ItemProperty -Path $Attachments -Name "SaveZoneInformation" -Value 1 -Type DWord -Force
    Write-Log "Security warnings disabled" "SUCCESS"
    
    Write-Log "Security tweaks completed" "SUCCESS"
}

function Apply-WindowsExperienceTweaks {
    Write-Log "WINDOWS EXPERIENCE TWEAKS" "SECTION"
    
    $CDM = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    
    # Disable suggestions in Start Menu
    Write-Log "Disabling Start Menu suggestions..."
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force
    Write-Log "Start Menu suggestions disabled" "SUCCESS"
    
    # Disable search for apps in Windows Store
    Write-Log "Disabling Store app search..."
    $StoreSearch = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $StoreSearch)) { New-Item -Path $StoreSearch -Force | Out-Null }
    Set-ItemProperty -Path $StoreSearch -Name "NoUseStoreOpenWith" -Value 1 -Type DWord -Force
    Write-Log "Store app search disabled" "SUCCESS"
    
    # Disable ads from Windows Store
    Write-Log "Disabling Store ads..."
    Set-ItemProperty -Path $CDM -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Write-Log "Store ads disabled" "SUCCESS"
    
    # Disable Windows Spotlight on lock screen
    Write-Log "Disabling Windows Spotlight..."
    Set-ItemProperty -Path $CDM -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord -Force
    $LockScreen = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $LockScreen)) { New-Item -Path $LockScreen -Force | Out-Null }
    Set-ItemProperty -Path $LockScreen -Name "DisableWindowsSpotlightFeatures" -Value 1 -Type DWord -Force
    Write-Log "Windows Spotlight disabled" "SUCCESS"
    
    # Disable "Get suggestions when using Windows"
    Write-Log "Disabling Windows suggestions..."
    Set-ItemProperty -Path $CDM -Name "SoftLandingEnabled" -Value 0 -Type DWord -Force
    Write-Log "Windows suggestions disabled" "SUCCESS"
    
    # Disable "Highlight newly installed programs"
    Write-Log "Disabling new program highlighting..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_NotifyNewApps" -Value 0 -Type DWord -Force
    Write-Log "New program highlighting disabled" "SUCCESS"
    
    # Disable automatic installation of recommended apps
    Write-Log "Disabling auto-install of recommended apps..."
    Set-ItemProperty -Path $CDM -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "PreInstalledAppsEverEnabled" -Value 0 -Type DWord -Force
    Write-Log "Auto-install disabled" "SUCCESS"
    
    # Disable Game DVR/Recorder
    Write-Log "Disabling Game DVR..."
    $GameDVR = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    if (-not (Test-Path $GameDVR)) { New-Item -Path $GameDVR -Force | Out-Null }
    Set-ItemProperty -Path $GameDVR -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
    $GameBar = "HKCU:\System\GameConfigStore"
    if (-not (Test-Path $GameBar)) { New-Item -Path $GameBar -Force | Out-Null }
    Set-ItemProperty -Path $GameBar -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
    Write-Log "Game DVR disabled" "SUCCESS"
    
    # Disable First Logon Animation
    Write-Log "Disabling First Logon Animation..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord -Force
    Write-Log "First Logon Animation disabled" "SUCCESS"
    
    Write-Log "Windows Experience tweaks completed" "SUCCESS"
}

function Enable-WindowsPhotoViewer {
    Write-Log "ENABLING WINDOWS PHOTO VIEWER" "SECTION"
    
    Write-Host ""
    Write-Host "This will enable the classic Windows Photo Viewer for image files." -ForegroundColor Yellow
    Write-Host "It will be available as an option in 'Open with' menu." -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Log "Cancelled" "INFO"
        return
    }
    
    # Register Windows Photo Viewer for image types
    $PhotoViewer = "PhotoViewer.FileAssoc.Tiff"
    
    # File types to associate
    $imageTypes = @(".jpg", ".jpeg", ".png", ".bmp", ".gif", ".tif", ".tiff", ".ico")
    
    foreach ($ext in $imageTypes) {
        $regPath = "HKCU:\SOFTWARE\Classes\$ext"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "(Default)" -Value $PhotoViewer -Force
    }
    
    # Register the Photo Viewer application
    $PhotoViewerPath = "HKCU:\SOFTWARE\Classes\$PhotoViewer\shell\open\command"
    if (-not (Test-Path $PhotoViewerPath)) { 
        New-Item -Path $PhotoViewerPath -Force | Out-Null 
    }
    Set-ItemProperty -Path $PhotoViewerPath -Name "(Default)" -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1" -Force
    
    # Add friendly name
    $FriendlyPath = "HKCU:\SOFTWARE\Classes\$PhotoViewer"
    Set-ItemProperty -Path $FriendlyPath -Name "(Default)" -Value "Windows Photo Viewer" -Force
    
    # Register for Open With
    $OpenWith = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"
    foreach ($ext in $imageTypes) {
        $extPath = "$OpenWith\$ext\OpenWithProgids"
        if (-not (Test-Path $extPath)) { New-Item -Path $extPath -Force | Out-Null }
        Set-ItemProperty -Path $extPath -Name $PhotoViewer -Value ([byte[]]@()) -Force
    }
    
    Write-Log "Windows Photo Viewer enabled for: $($imageTypes -join ', ')" "SUCCESS"
    Write-Host "You can now right-click images and choose 'Open with' > 'Windows Photo Viewer'" -ForegroundColor Green
}

function Apply-NotepadMediaTweaks {
    Write-Log "NOTEPAD & MEDIA PLAYER TWEAKS" "SECTION"
    
    # Notepad: Enable word wrap
    Write-Log "Enabling Notepad word wrap..."
    $Notepad = "HKCU:\SOFTWARE\Microsoft\Notepad"
    if (-not (Test-Path $Notepad)) { New-Item -Path $Notepad -Force | Out-Null }
    Set-ItemProperty -Path $Notepad -Name "fWrap" -Value 1 -Type DWord -Force
    Write-Log "Notepad word wrap enabled" "SUCCESS"
    
    # Notepad: Show status bar
    Write-Log "Enabling Notepad status bar..."
    Set-ItemProperty -Path $Notepad -Name "StatusBar" -Value 1 -Type DWord -Force
    Write-Log "Notepad status bar enabled" "SUCCESS"
    
    # Windows Media Player: Hide First Run Wizard
    Write-Log "Disabling Media Player First Run Wizard..."
    $WMP = "HKCU:\SOFTWARE\Microsoft\MediaPlayer\Preferences"
    if (-not (Test-Path $WMP)) { New-Item -Path $WMP -Force | Out-Null }
    Set-ItemProperty -Path $WMP -Name "AcceptedPrivacyStatement" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $WMP -Name "FirstTime" -Value 1 -Type DWord -Force
    
    $WMPSetup = "HKLM:\SOFTWARE\Microsoft\MediaPlayer\Setup\Completed"
    if (-not (Test-Path $WMPSetup)) { New-Item -Path $WMPSetup -Force | Out-Null }
    Set-ItemProperty -Path $WMPSetup -Name "FirstTime" -Value 1 -Type DWord -Force
    Write-Log "Media Player wizard disabled" "SUCCESS"
    
    # Disable Customer Experience Improvement Program
    Write-Log "Disabling CEIP..."
    $CEIP = "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows"
    if (-not (Test-Path $CEIP)) { New-Item -Path $CEIP -Force | Out-Null }
    Set-ItemProperty -Path $CEIP -Name "CEIPEnable" -Value 0 -Type DWord -Force
    Write-Log "CEIP disabled" "SUCCESS"
    
    # Disable NTFS Link Tracking Service
    Write-Log "Disabling NTFS Link Tracking Service (TrkWks)..."
    try {
        Stop-Service -Name "TrkWks" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "TrkWks" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "TrkWks service disabled" "SUCCESS"
    } catch {
        Write-Log "Could not disable TrkWks" "WARNING"
    }
    
    # Windows Update: Exclude Malware Removal Tool
    Write-Log "Excluding Malware Removal Tool from Windows Update..."
    $WUPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\MRT"
    if (-not (Test-Path $WUPolicy)) { New-Item -Path $WUPolicy -Force | Out-Null }
    Set-ItemProperty -Path $WUPolicy -Name "DontOfferThroughWUAU" -Value 1 -Type DWord -Force
    Write-Log "Malware Removal Tool excluded from WU" "SUCCESS"
    
    Write-Log "Notepad & Media Player tweaks completed" "SUCCESS"
}

function Apply-InternetExplorerTweaks {
    Write-Log "INTERNET EXPLORER TWEAKS" "SECTION"
    
    Write-Host ""
    Write-Host "Note: These settings apply to IE Mode in Edge and legacy IE installations." -ForegroundColor Yellow
    Write-Host ""
    
    $IEMain = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Main"
    $IENew = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\New Windows"
    $IETabs = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\TabbedBrowsing"
    $IESetup = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Main"
    $IESuggest = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Suggested Sites"
    $IEToolbar = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Toolbar"
    $IEDownload = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
    
    # Ensure paths exist
    foreach ($path in @($IEMain, $IENew, $IETabs, $IESuggest, $IEToolbar, $IEDownload)) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    }
    
    # Open links from other programs in a new tab in current window
    Write-Log "Setting links to open in new tab..."
    Set-ItemProperty -Path $IETabs -Name "PopupsUseNewWindow" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $IENew -Name "PopupMgr" -Value "yes" -Force
    Write-Log "Links open in new tab" "SUCCESS"
    
    # Display all websites in Compatibility View
    Write-Log "Enabling Compatibility View for all sites..."
    $IECompat = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\BrowserEmulation"
    if (-not (Test-Path $IECompat)) { New-Item -Path $IECompat -Force | Out-Null }
    Set-ItemProperty -Path $IECompat -Name "AllSitesCompatibilityMode" -Value 1 -Type DWord -Force
    Write-Log "Compatibility View enabled" "SUCCESS"
    
    # Enable AutoComplete
    Write-Log "Enabling AutoComplete..."
    Set-ItemProperty -Path $IEMain -Name "Use FormSuggest" -Value "yes" -Force
    Set-ItemProperty -Path $IEMain -Name "FormSuggest Passwords" -Value "yes" -Force
    Set-ItemProperty -Path $IEMain -Name "FormSuggest PW Ask" -Value "yes" -Force
    $IEAutoComplete = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete"
    if (-not (Test-Path $IEAutoComplete)) { New-Item -Path $IEAutoComplete -Force | Out-Null }
    Set-ItemProperty -Path $IEAutoComplete -Name "AutoSuggest" -Value "yes" -Force
    Write-Log "AutoComplete enabled" "SUCCESS"
    
    # Turn off Suggested Sites
    Write-Log "Disabling Suggested Sites..."
    Set-ItemProperty -Path $IESuggest -Name "Enabled" -Value 0 -Type DWord -Force
    $IESuggestPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Suggested Sites"
    if (-not (Test-Path $IESuggestPolicy)) { New-Item -Path $IESuggestPolicy -Force | Out-Null }
    Set-ItemProperty -Path $IESuggestPolicy -Name "Enabled" -Value 0 -Type DWord -Force
    Write-Log "Suggested Sites disabled" "SUCCESS"
    
    # Prevent running First Run wizard
    Write-Log "Disabling First Run wizard..."
    Set-ItemProperty -Path $IEMain -Name "DisableFirstRunCustomize" -Value 1 -Type DWord -Force
    $IEPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main"
    if (-not (Test-Path $IEPolicy)) { New-Item -Path $IEPolicy -Force | Out-Null }
    Set-ItemProperty -Path $IEPolicy -Name "DisableFirstRunCustomize" -Value 1 -Type DWord -Force
    Write-Log "First Run wizard disabled" "SUCCESS"
    
    # Regional information does not save attachments (security)
    Write-Log "Configuring attachment security..."
    $IEAttach = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments"
    if (-not (Test-Path $IEAttach)) { New-Item -Path $IEAttach -Force | Out-Null }
    Set-ItemProperty -Path $IEAttach -Name "SaveZoneInformation" -Value 1 -Type DWord -Force
    Write-Log "Attachment zone info preserved" "SUCCESS"
    
    # Lock Internet Explorer toolbar
    Write-Log "Locking IE toolbar..."
    Set-ItemProperty -Path $IEToolbar -Name "Locked" -Value 1 -Type DWord -Force
    Write-Log "Toolbar locked" "SUCCESS"
    
    # Adjust number of simultaneous downloads to 10
    Write-Log "Setting max simultaneous downloads to 10..."
    Set-ItemProperty -Path $IEDownload -Name "MaxConnectionsPerServer" -Value 10 -Type DWord -Force
    Set-ItemProperty -Path $IEDownload -Name "MaxConnectionsPer1_0Server" -Value 10 -Type DWord -Force
    Write-Log "Max downloads set to 10" "SUCCESS"
    
    # Always display pop-up windows in new tab
    Write-Log "Setting pop-ups to open in new tab..."
    Set-ItemProperty -Path $IETabs -Name "PopupsUseNewWindow" -Value 0 -Type DWord -Force
    Write-Log "Pop-ups open in new tab" "SUCCESS"
    
    # Hide feedback smile face (top-right)
    Write-Log "Hiding feedback button..."
    $IEFeedback = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Suggested Sites"
    Set-ItemProperty -Path $IEMain -Name "EnableSuggestedSites" -Value 0 -Type DWord -Force
    # Disable feedback via policy
    $IEFeedbackPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Restrictions"
    if (-not (Test-Path $IEFeedbackPolicy)) { New-Item -Path $IEFeedbackPolicy -Force | Out-Null }
    Set-ItemProperty -Path $IEFeedbackPolicy -Name "NoHelpItemSendFeedback" -Value 1 -Type DWord -Force
    Write-Log "Feedback button hidden" "SUCCESS"
    
    Write-Log "Internet Explorer tweaks completed" "SUCCESS"
}

# ============================================================================
# SECTION 30: WINDOWS IMAGE TOOL
# ============================================================================
function Start-WindowsImageTool {
    Write-Log "WINDOWS IMAGE TOOL" "SECTION"
    
    $toolUrl = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/Windows-Image-Tool.ps1"
    $toolPath = "C:\System_Optimizer\Windows-Image-Tool.ps1"
    
    # Ensure directory exists
    if (-not (Test-Path "C:\System_Optimizer")) {
        New-Item -ItemType Directory -Path "C:\System_Optimizer" -Force | Out-Null
    }
    
    Write-Log "Downloading Windows Image Tool..."
    try {
        Invoke-WebRequest -Uri $toolUrl -OutFile $toolPath -UseBasicParsing
        Write-Log "Downloaded Windows Image Tool" "SUCCESS"
        
        Write-Log "Launching Windows Image Tool..."
        & $toolPath
    } catch {
        Write-Log "Failed to download: $_" "ERROR"
        Write-Host ""
        Write-Host "Trying to run locally if available..." -ForegroundColor Yellow
        
        # Try local path
        $localPath = Join-Path $PSScriptRoot "configs\Windows-Image-Tool.ps1"
        if (Test-Path $localPath) {
            & $localPath
        } else {
            Write-Log "Windows Image Tool not found locally either" "ERROR"
        }
    }
}

# ============================================================================
# USER PROFILE BACKUP & RESTORE
# ============================================================================
function Start-UserProfileBackup {
    Write-Log "USER PROFILE BACKUP & RESTORE" "SECTION"
    
    $scriptUrl = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/User_profile_Backup_and_Restore.ps1"
    $scriptPath = "C:\System_Optimizer\User_profile_Backup_and_Restore.ps1"
    
    # Ensure directory exists
    if (-not (Test-Path "C:\System_Optimizer")) {
        New-Item -ItemType Directory -Path "C:\System_Optimizer" -Force | Out-Null
    }
    
    Write-Log "Loading User Profile Backup & Restore tool..."
    try {
        # Try to download latest version
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
        Write-Log "Downloaded latest User Profile Backup tool" "SUCCESS"
    } catch {
        Write-Log "Could not download latest version: $_" "WARNING"
        
        # Try local path
        $localPath = Join-Path $PSScriptRoot "configs\User_profile_Backup_and_Restore.ps1"
        if (Test-Path $localPath) {
            Copy-Item $localPath $scriptPath -Force
            Write-Log "Using local version of User Profile Backup tool" "INFO"
        } else {
            Write-Log "User Profile Backup tool not found" "ERROR"
            return
        }
    }
    
    # Execute the script in the current session to access functions
    try {
        . $scriptPath
        Show-UserBackupMenu
    } catch {
        Write-Log "Error loading User Profile Backup tool: $_" "ERROR"
    }
}

# ============================================================================
# LOG VIEWER
# ============================================================================
function Show-LogViewer {
    Set-ConsoleSize
    Clear-Host
    Write-Log "LOG VIEWER" "SECTION"
    
    Write-Host ""
    Write-Host "  Log Directory: $LogDir" -ForegroundColor Cyan
    Write-Host "  Current Log:   $LogFile" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Options:" -ForegroundColor Gray
    Write-Host "  [1] View current session log"
    Write-Host "  [2] View recent log files"
    Write-Host "  [3] Open log folder in Explorer"
    Write-Host "  [4] Export log summary"
    Write-Host "  [5] Clear old logs (30+ days)"
    Write-Host "  [0] Back"
    Write-Host ""
    
    $choice = Read-Host "Select option"
    
    switch ($choice) {
        "1" {
            # View current log
            if ($LogFile -and (Test-Path $LogFile)) {
                Write-Host ""
                Write-Host "  Current Session Log (last 100 lines):" -ForegroundColor Cyan
                Write-Host ("-" * 70) -ForegroundColor Gray
                Get-Content $LogFile -Tail 100
                Write-Host ("-" * 70) -ForegroundColor Gray
            } else {
                Write-Host "  No log file for current session" -ForegroundColor Yellow
            }
        }
        "2" {
            # View recent logs
            Write-Host ""
            Write-Host "  Recent Log Files:" -ForegroundColor Cyan
            $logs = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending | Select-Object -First 15
            
            if ($logs) {
                $i = 1
                foreach ($log in $logs) {
                    $errors = (Select-String -Path $log.FullName -Pattern "\[ERROR\]" -ErrorAction SilentlyContinue).Count
                    $warnings = (Select-String -Path $log.FullName -Pattern "\[WARNING\]" -ErrorAction SilentlyContinue).Count
                    $sizeKB = [math]::Round($log.Length / 1KB, 1)
                    $color = if ($errors -gt 0) { "Red" } elseif ($warnings -gt 0) { "Yellow" } else { "Gray" }
                    Write-Host "    [$i] $($log.Name) - ${sizeKB}KB - E:$errors W:$warnings" -ForegroundColor $color
                    $i++
                }
                Write-Host ""
                $viewChoice = Read-Host "Enter number to view log (or Enter to skip)"
                if ($viewChoice -match '^\d+$' -and [int]$viewChoice -le $logs.Count) {
                    $selectedLog = $logs[[int]$viewChoice - 1]
                    if ($selectedLog) {
                        Write-Host ""
                        Write-Host "  Last 50 lines of $($selectedLog.Name):" -ForegroundColor Cyan
                        Write-Host ("-" * 70) -ForegroundColor Gray
                        Get-Content $selectedLog.FullName -Tail 50
                    }
                }
            } else {
                Write-Host "    No log files found" -ForegroundColor Yellow
            }
        }
        "3" {
            # Open log folder
            if (Test-Path $LogDir) {
                Start-Process explorer.exe -ArgumentList $LogDir
                Write-Log "Opened log folder: $LogDir" "SUCCESS"
            } else {
                Write-Log "Log folder does not exist" "WARNING"
            }
        }
        "4" {
            # Export summary
            $summaryPath = "$LogDir\LogSummary_$(Get-Date -Format 'yyyy-MM-dd').txt"
            $summary = @"
================================================================================
SYSTEM OPTIMIZER - LOG SUMMARY
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
================================================================================

LOG FILES IN $LogDir`:

"@
            $logs = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending
            
            foreach ($log in $logs) {
                $errors = (Select-String -Path $log.FullName -Pattern "\[ERROR\]" -ErrorAction SilentlyContinue).Count
                $warnings = (Select-String -Path $log.FullName -Pattern "\[WARNING\]" -ErrorAction SilentlyContinue).Count
                $successes = (Select-String -Path $log.FullName -Pattern "\[SUCCESS\]" -ErrorAction SilentlyContinue).Count
                $summary += "  $($log.Name)`n"
                $summary += "    Date: $($log.LastWriteTime)`n"
                $summary += "    Size: $([math]::Round($log.Length / 1KB, 1)) KB`n"
                $summary += "    Errors: $errors | Warnings: $warnings | Successes: $successes`n`n"
            }
            
            $summary | Out-File $summaryPath -Force
            Write-Log "Summary exported to: $summaryPath" "SUCCESS"
            Start-Process notepad.exe -ArgumentList $summaryPath
        }
        "5" {
            # Clear old logs
            $oldLogs = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue | 
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
            
            if ($oldLogs.Count -gt 0) {
                Write-Host ""
                Write-Host "  Found $($oldLogs.Count) logs older than 30 days" -ForegroundColor Yellow
                $confirm = Read-Host "Delete them? (Y/N)"
                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    $oldLogs | Remove-Item -Force
                    Write-Log "Deleted $($oldLogs.Count) old log files" "SUCCESS"
                }
            } else {
                Write-Host "  No logs older than 30 days found" -ForegroundColor Green
            }
        }
    }
}

# ============================================================================
# MAIN MENU LOOP
# ============================================================================
function Start-MainMenu {
    do {
        Show-Menu
        $choice = Read-Host "Select an option"
        
        switch ($choice) {
            "1" { Run-AllOptimizations }
            "2" { Disable-Telemetry }
            "3" { Disable-Services }
            "4" { Remove-BloatwareApps }
            "5" { Disable-ScheduledTasks }
            "6" { Set-RegistryOptimizations }
            "7" { Disable-VBS }
            "8" { Set-NetworkOptimizations }
            "9" { Remove-OneDrive }
            "10" { Start-SystemMaintenance }
            "11" { Start-PatchMyPC }
            "12" { Start-OfficeTool }
            "13" { Run-MAS }
            "14" { Get-WifiPasswords }
            "15" { Verify-OptimizationStatus }
            "16" { Run-FullSetup }
            "17" { Set-PowerPlan }
            "18" { Start-OOShutUp10 }
            "19" { Reset-GroupPolicy }
            "20" { Reset-WMI }
            "21" { Start-DiskCleanup }
            "22" { Set-WindowsUpdateControl }
            "23" { Start-SnappyDriverInstaller }
            "24" { Reset-Network }
            "25" { Repair-WindowsUpdate }
            "26" { Set-DefenderControl }
            "27" { Start-AdvancedDebloat }
            "28" { Sync-WinUtilServices }
            "29" { Start-DismPlusTweaks }
            "30" { Start-WindowsImageTool }
            "31" { Show-LogViewer }
            "32" { Start-UserProfileBackup }
            "33" { Show-ShutdownMenu }
            "0" { 
                Write-Host "Exiting... Log saved to: $LogFile" -ForegroundColor Cyan
                return 
            }
            default { Write-Host "Invalid option. Please try again." -ForegroundColor Red }
        }
        
        if ($choice -ne "0") {
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } while ($true)
}

# ============================================================================
# SHUTDOWN & RESTART MENU
# ============================================================================
function Show-ShutdownMenu {
    do {
        Set-ConsoleSize
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Shutdown & Restart Options" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Immediate Actions:" -ForegroundColor Gray
        Write-Host "  [1] Shutdown Now"
        Write-Host "  [2] Restart Now"
        Write-Host "  [3] Log Off Current User"
        Write-Host "  [4] Lock Workstation"
        Write-Host ""
        Write-Host "  Scheduled Actions:" -ForegroundColor Gray
        Write-Host "  [5] Schedule Shutdown (Custom Time)"
        Write-Host "  [6] Schedule Restart (Custom Time)"
        Write-Host "  [7] Schedule Shutdown (Timer in Minutes)"
        Write-Host "  [8] Schedule Restart (Timer in Minutes)"
        Write-Host ""
        Write-Host "  Advanced Options:" -ForegroundColor Gray
        Write-Host "  [9] Force Shutdown (Kill All Processes)"
        Write-Host "  [10] Force Restart (Kill All Processes)"
        Write-Host "  [11] Hibernate (if enabled)"
        Write-Host "  [12] Sleep/Suspend"
        Write-Host ""
        Write-Host "  Schedule Management:" -ForegroundColor Gray
        Write-Host "  [13] View Scheduled Shutdowns"
        Write-Host "  [14] Cancel All Scheduled Shutdowns"
        Write-Host ""
        Write-Host "  [0] Back to main menu"
        Write-Host ""
        
        $choice = Read-Host "Select option"
        
        switch ($choice) {
            "1" { Invoke-ImmediateShutdown }
            "2" { Invoke-ImmediateRestart }
            "3" { Invoke-LogOff }
            "4" { Invoke-LockWorkstation }
            "5" { Schedule-ShutdownAtTime }
            "6" { Schedule-RestartAtTime }
            "7" { Schedule-ShutdownTimer }
            "8" { Schedule-RestartTimer }
            "9" { Invoke-ForceShutdown }
            "10" { Invoke-ForceRestart }
            "11" { Invoke-Hibernate }
            "12" { Invoke-Sleep }
            "13" { Show-ScheduledShutdowns }
            "14" { Cancel-AllScheduledShutdowns }
            "0" { return }
            default { Write-Host "Invalid option" -ForegroundColor Red }
        }
        
        if ($choice -ne "0" -and $choice -notin @("1","2","9","10")) {
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } while ($true)
}

# Immediate shutdown functions
function Invoke-ImmediateShutdown {
    Write-Log "IMMEDIATE SHUTDOWN REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "WARNING: This will shutdown the computer immediately!" -ForegroundColor Red
    Write-Host "All unsaved work will be lost!" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Are you sure? Type 'SHUTDOWN' to confirm"
    
    if ($confirm -eq "SHUTDOWN") {
        Write-Log "Initiating immediate shutdown..." "WARNING"
        Write-Host "Shutting down in 10 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 3
        Write-Host "7..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "6..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "5..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "4..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "3..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "2..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "1..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "Goodbye!" -ForegroundColor Red
        Start-Sleep -Seconds 1
        shutdown /s /t 0
    } else {
        Write-Log "Shutdown cancelled by user" "INFO"
    }
}

function Invoke-ImmediateRestart {
    Write-Log "IMMEDIATE RESTART REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "WARNING: This will restart the computer immediately!" -ForegroundColor Red
    Write-Host "All unsaved work will be lost!" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Are you sure? Type 'RESTART' to confirm"
    
    if ($confirm -eq "RESTART") {
        Write-Log "Initiating immediate restart..." "WARNING"
        Write-Host "Restarting in 10 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 3
        Write-Host "7..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "6..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "5..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "4..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "3..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "2..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "1..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "See you soon!" -ForegroundColor Red
        Start-Sleep -Seconds 1
        shutdown /r /t 0
    } else {
        Write-Log "Restart cancelled by user" "INFO"
    }
}

function Invoke-LogOff {
    Write-Log "LOG OFF REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "This will log off the current user." -ForegroundColor Yellow
    Write-Host "All unsaved work will be lost!" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Continue? (y/N)"
    
    if ($confirm -eq "y" -or $confirm -eq "Y") {
        Write-Log "Logging off current user..." "INFO"
        shutdown /l
    } else {
        Write-Log "Log off cancelled by user" "INFO"
    }
}

function Invoke-LockWorkstation {
    Write-Log "LOCKING WORKSTATION" "INFO"
    Write-Host "Locking workstation..." -ForegroundColor Green
    rundll32.exe user32.dll,LockWorkStation
}

# Scheduled shutdown functions
function Schedule-ShutdownAtTime {
    Write-Log "SCHEDULE SHUTDOWN AT SPECIFIC TIME" "SECTION"
    Write-Host ""
    Write-Host "Schedule shutdown at a specific time (24-hour format)" -ForegroundColor Cyan
    Write-Host "Examples: 14:30, 23:45, 09:15" -ForegroundColor Gray
    Write-Host ""
    
    $timeInput = Read-Host "Enter time (HH:MM)"
    
    try {
        $targetTime = [DateTime]::ParseExact($timeInput, "HH:mm", $null)
        $currentTime = Get-Date
        
        # If time is earlier than now, assume it's for tomorrow
        if ($targetTime.TimeOfDay -lt $currentTime.TimeOfDay) {
            $targetTime = $targetTime.AddDays(1)
        }
        
        $timeUntil = ($targetTime - $currentTime).TotalSeconds
        
        if ($timeUntil -lt 60) {
            Write-Host "Time must be at least 1 minute in the future!" -ForegroundColor Red
            return
        }
        
        Write-Host ""
        Write-Host "Shutdown scheduled for: $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        Write-Host "Time until shutdown: $([Math]::Round($timeUntil / 60, 1)) minutes" -ForegroundColor Yellow
        Write-Host ""
        
        $confirm = Read-Host "Confirm schedule? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            shutdown /s /t $([Math]::Round($timeUntil))
            Write-Log "Shutdown scheduled for $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" "SUCCESS"
            Write-Host "Shutdown scheduled successfully!" -ForegroundColor Green
            Write-Host "Use option 14 to cancel if needed." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Invalid time format! Use HH:MM (24-hour format)" -ForegroundColor Red
    }
}

function Schedule-RestartAtTime {
    Write-Log "SCHEDULE RESTART AT SPECIFIC TIME" "SECTION"
    Write-Host ""
    Write-Host "Schedule restart at a specific time (24-hour format)" -ForegroundColor Cyan
    Write-Host "Examples: 14:30, 23:45, 09:15" -ForegroundColor Gray
    Write-Host ""
    
    $timeInput = Read-Host "Enter time (HH:MM)"
    
    try {
        $targetTime = [DateTime]::ParseExact($timeInput, "HH:mm", $null)
        $currentTime = Get-Date
        
        # If time is earlier than now, assume it's for tomorrow
        if ($targetTime.TimeOfDay -lt $currentTime.TimeOfDay) {
            $targetTime = $targetTime.AddDays(1)
        }
        
        $timeUntil = ($targetTime - $currentTime).TotalSeconds
        
        if ($timeUntil -lt 60) {
            Write-Host "Time must be at least 1 minute in the future!" -ForegroundColor Red
            return
        }
        
        Write-Host ""
        Write-Host "Restart scheduled for: $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        Write-Host "Time until restart: $([Math]::Round($timeUntil / 60, 1)) minutes" -ForegroundColor Yellow
        Write-Host ""
        
        $confirm = Read-Host "Confirm schedule? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            shutdown /r /t $([Math]::Round($timeUntil))
            Write-Log "Restart scheduled for $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" "SUCCESS"
            Write-Host "Restart scheduled successfully!" -ForegroundColor Green
            Write-Host "Use option 14 to cancel if needed." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Invalid time format! Use HH:MM (24-hour format)" -ForegroundColor Red
    }
}

function Schedule-ShutdownTimer {
    Write-Log "SCHEDULE SHUTDOWN TIMER" "SECTION"
    Write-Host ""
    Write-Host "Schedule shutdown after a specific number of minutes" -ForegroundColor Cyan
    Write-Host "Examples: 30 (30 minutes), 120 (2 hours), 5 (5 minutes)" -ForegroundColor Gray
    Write-Host ""
    
    $minutesInput = Read-Host "Enter minutes until shutdown"
    
    try {
        $minutes = [int]$minutesInput
        
        if ($minutes -lt 1) {
            Write-Host "Minutes must be at least 1!" -ForegroundColor Red
            return
        }
        
        if ($minutes -gt 1440) {
            Write-Host "Maximum is 1440 minutes (24 hours)!" -ForegroundColor Red
            return
        }
        
        $seconds = $minutes * 60
        $targetTime = (Get-Date).AddMinutes($minutes)
        
        Write-Host ""
        Write-Host "Shutdown scheduled for: $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        Write-Host "Time until shutdown: $minutes minutes" -ForegroundColor Yellow
        Write-Host ""
        
        $confirm = Read-Host "Confirm schedule? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            shutdown /s /t $seconds
            Write-Log "Shutdown scheduled for $minutes minutes ($($targetTime.ToString('yyyy-MM-dd HH:mm:ss')))" "SUCCESS"
            Write-Host "Shutdown scheduled successfully!" -ForegroundColor Green
            Write-Host "Use option 14 to cancel if needed." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Invalid number! Enter a whole number of minutes." -ForegroundColor Red
    }
}

function Schedule-RestartTimer {
    Write-Log "SCHEDULE RESTART TIMER" "SECTION"
    Write-Host ""
    Write-Host "Schedule restart after a specific number of minutes" -ForegroundColor Cyan
    Write-Host "Examples: 30 (30 minutes), 120 (2 hours), 5 (5 minutes)" -ForegroundColor Gray
    Write-Host ""
    
    $minutesInput = Read-Host "Enter minutes until restart"
    
    try {
        $minutes = [int]$minutesInput
        
        if ($minutes -lt 1) {
            Write-Host "Minutes must be at least 1!" -ForegroundColor Red
            return
        }
        
        if ($minutes -gt 1440) {
            Write-Host "Maximum is 1440 minutes (24 hours)!" -ForegroundColor Red
            return
        }
        
        $seconds = $minutes * 60
        $targetTime = (Get-Date).AddMinutes($minutes)
        
        Write-Host ""
        Write-Host "Restart scheduled for: $($targetTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        Write-Host "Time until restart: $minutes minutes" -ForegroundColor Yellow
        Write-Host ""
        
        $confirm = Read-Host "Confirm schedule? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            shutdown /r /t $seconds
            Write-Log "Restart scheduled for $minutes minutes ($($targetTime.ToString('yyyy-MM-dd HH:mm:ss')))" "SUCCESS"
            Write-Host "Restart scheduled successfully!" -ForegroundColor Green
            Write-Host "Use option 14 to cancel if needed." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Invalid number! Enter a whole number of minutes." -ForegroundColor Red
    }
}

# Force shutdown functions
function Invoke-ForceShutdown {
    Write-Log "FORCE SHUTDOWN REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "WARNING: This will FORCE shutdown the computer!" -ForegroundColor Red
    Write-Host "All running programs will be terminated without saving!" -ForegroundColor Red
    Write-Host "This may cause data loss!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Are you absolutely sure? Type 'FORCE SHUTDOWN' to confirm"
    
    if ($confirm -eq "FORCE SHUTDOWN") {
        Write-Log "Initiating force shutdown..." "WARNING"
        Write-Host "Force shutting down in 5 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "4..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "3..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "2..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "1..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        shutdown /s /f /t 0
    } else {
        Write-Log "Force shutdown cancelled by user" "INFO"
    }
}

function Invoke-ForceRestart {
    Write-Log "FORCE RESTART REQUESTED" "SECTION"
    Write-Host ""
    Write-Host "WARNING: This will FORCE restart the computer!" -ForegroundColor Red
    Write-Host "All running programs will be terminated without saving!" -ForegroundColor Red
    Write-Host "This may cause data loss!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Are you absolutely sure? Type 'FORCE RESTART' to confirm"
    
    if ($confirm -eq "FORCE RESTART") {
        Write-Log "Initiating force restart..." "WARNING"
        Write-Host "Force restarting in 5 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "4..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "3..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "2..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        Write-Host "1..." -ForegroundColor Red
        Start-Sleep -Seconds 1
        shutdown /r /f /t 0
    } else {
        Write-Log "Force restart cancelled by user" "INFO"
    }
}

# Power state functions
function Invoke-Hibernate {
    Write-Log "HIBERNATE REQUESTED" "SECTION"
    
    # Check if hibernation is enabled
    $hibernateEnabled = (powercfg /a | Select-String "hibernate" -Quiet)
    
    if (-not $hibernateEnabled) {
        Write-Host "Hibernation is not enabled on this system." -ForegroundColor Red
        Write-Host ""
        $enable = Read-Host "Would you like to enable hibernation? (y/N)"
        
        if ($enable -eq "y" -or $enable -eq "Y") {
            Write-Log "Enabling hibernation..." "INFO"
            powercfg /hibernate on
            Write-Host "Hibernation enabled!" -ForegroundColor Green
            Write-Host ""
        } else {
            Write-Log "Hibernation not enabled by user" "INFO"
            return
        }
    }
    
    Write-Host "This will hibernate the computer (save state to disk and power off)." -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (y/N)"
    
    if ($confirm -eq "y" -or $confirm -eq "Y") {
        Write-Log "Hibernating system..." "INFO"
        shutdown /h
    } else {
        Write-Log "Hibernation cancelled by user" "INFO"
    }
}

function Invoke-Sleep {
    Write-Log "SLEEP REQUESTED" "SECTION"
    Write-Host "This will put the computer to sleep (low power mode)." -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (y/N)"
    
    if ($confirm -eq "y" -or $confirm -eq "Y") {
        Write-Log "Putting system to sleep..." "INFO"
        rundll32.exe powrprof.dll,SetSuspendState 0,1,0
    } else {
        Write-Log "Sleep cancelled by user" "INFO"
    }
}

# Schedule management functions
function Show-ScheduledShutdowns {
    Write-Log "VIEWING SCHEDULED SHUTDOWNS" "SECTION"
    Write-Host ""
    Write-Host "Checking for scheduled shutdowns..." -ForegroundColor Cyan
    
    try {
        # Check for shutdown tasks
        $tasks = schtasks /query /fo csv | ConvertFrom-Csv | Where-Object { $_.TaskName -like "*shutdown*" -or $_.TaskName -like "*restart*" }
        
        if ($tasks) {
            Write-Host "Scheduled shutdown/restart tasks found:" -ForegroundColor Green
            $tasks | Format-Table TaskName, Status, "Next Run Time" -AutoSize
        } else {
            Write-Host "No scheduled shutdown/restart tasks found via Task Scheduler." -ForegroundColor Yellow
        }
        
        # Check shutdown.exe status (this is harder to detect reliably)
        Write-Host ""
        Write-Host "Note: shutdown.exe scheduled shutdowns are not easily detectable." -ForegroundColor Gray
        Write-Host "If you scheduled a shutdown using options 5-8, use option 14 to cancel." -ForegroundColor Gray
        
    } catch {
        Write-Host "Error checking scheduled tasks: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "You can manually check with: schtasks /query" -ForegroundColor Gray
    }
}

function Cancel-AllScheduledShutdowns {
    Write-Log "CANCELLING SCHEDULED SHUTDOWNS" "SECTION"
    Write-Host ""
    Write-Host "This will cancel any pending shutdown/restart scheduled with shutdown.exe" -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "Cancel all scheduled shutdowns? (y/N)"
    
    if ($confirm -eq "y" -or $confirm -eq "Y") {
        try {
            shutdown /a
            Write-Log "Cancelled scheduled shutdowns" "SUCCESS"
            Write-Host "All scheduled shutdowns have been cancelled!" -ForegroundColor Green
        } catch {
            Write-Host "No scheduled shutdowns to cancel, or cancellation failed." -ForegroundColor Yellow
            Write-Log "Shutdown cancellation failed or no shutdowns scheduled: $_" "WARNING"
        }
    } else {
        Write-Log "Shutdown cancellation cancelled by user" "INFO"
    }
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================
Write-Host ""
Write-Host "Ultimate Windows 11 Optimization Script" -ForegroundColor Cyan
Write-Host "Log file: $LogFile" -ForegroundColor Gray
Write-Host ""

# Start the menu
Start-MainMenu
