#Requires -Version 5.1
<#
.SYNOPSIS
    UITweaks Module - System Optimizer
.DESCRIPTION
    Provides DISM++ style UI/UX tweaks for Windows customization.
    Includes taskbar, Explorer, desktop, and context menu modifications.

Exported Functions:
    Start-DISMStyleTweaks     - Interactive UI tweaks menu
    Set-TaskbarTweaks         - Taskbar and Start Menu tweaks
    Set-ExplorerTweaks        - File Explorer customizations
    Set-DesktopIconTweaks     - Desktop icon visibility
    Set-ContextMenuTweaks     - Context menu modifications
    Set-SecurityTweaks        - SmartScreen and security settings
    Set-WindowsExperienceTweaks - Windows Experience settings
    Set-PhotoViewerTweaks     - Classic Photo Viewer enable
    Set-NotepadMediaTweaks    - Notepad and Media Player tweaks
    Set-IEModeTweaks          - Internet Explorer mode settings

Tweak Categories:
    1. Taskbar & Start Menu - Seconds on clock, alignment
    2. Explorer - Extensions, hidden files, full path
    3. Desktop Icons - This PC, Recycle Bin, Control Panel
    4. Context Menu - Classic menu (Win11), End Task
    5. Security - SmartScreen, download warnings
    6. Windows Experience - Suggestions, Spotlight
    7. Photo Viewer - Re-enable classic viewer
    8. Notepad & Media - Word wrap, WMP wizard
    9. IE Mode - Compatibility settings

Requires Admin: Yes (some tweaks)

Version: 1.0.0
#>

# Helper function to safely write log messages (handles missing Write-Log)
function script:Safe-WriteLog {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    if (Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
        Write-Log $Message $Type
    } else {
        switch ($Type) {
            "SUCCESS" { Write-Host "  [OK] $Message" -ForegroundColor Green }
            "WARNING" { Write-Host "  [!] $Message" -ForegroundColor Yellow }
            "ERROR"   { Write-Host "  [X] $Message" -ForegroundColor Red }
            "SECTION" { Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
            default   { Write-Host "  [-] $Message" }
        }
    }
}

function Apply-TaskbarTweaks {
    Safe-WriteLog "TASKBAR & START MENU TWEAKS" "SECTION"

    # Hide People on Taskbar
    Safe-WriteLog "Hiding People on Taskbar..."
    $People = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People"
    if (-not (Test-Path $People)) { New-Item -Path $People -Force | Out-Null }
    Set-ItemProperty -Path $People -Name "PeopleBand" -Value 0 -Type DWord -Force
    Safe-WriteLog "People hidden" "SUCCESS"

    # Show clock on taskbar
    Safe-WriteLog "Ensuring clock is visible on taskbar..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSecondsInSystemClock" -Value 1 -Type DWord -Force
    Safe-WriteLog "Clock configured" "SUCCESS"

    # Show color on Start Menu, Taskbar, Action Center, Title bar
    Safe-WriteLog "Enabling color on Start Menu, Taskbar, Action Center..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "ColorPrevalence" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\DWM" -Name "ColorPrevalence" -Value 1 -Type DWord -Force
    Safe-WriteLog "Color enabled on system elements" "SUCCESS"

    # Make Start Menu, Taskbar, Action Center transparent
    Safe-WriteLog "Enabling transparency..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Type DWord -Force
    Safe-WriteLog "Transparency enabled" "SUCCESS"

    # Hide Language Bar from taskbar
    Safe-WriteLog "Hiding Language Bar..."
    $LangBar = "HKCU:\SOFTWARE\Microsoft\CTF\LangBar"
    if (-not (Test-Path $LangBar)) { New-Item -Path $LangBar -Force | Out-Null }
    Set-ItemProperty -Path $LangBar -Name "ShowStatus" -Value 3 -Type DWord -Force
    Safe-WriteLog "Language Bar hidden" "SUCCESS"

    # Hide Help button on Language Bar
    Safe-WriteLog "Hiding Help button on Language Bar..."
    Set-ItemProperty -Path $LangBar -Name "ExtraIconsOnMinimized" -Value 0 -Type DWord -Force
    Safe-WriteLog "Help button hidden" "SUCCESS"

    # Windows 11: Align Start Menu to Left
    Safe-WriteLog "Aligning Start Menu to Left (Windows 11)..."
    $Win11Taskbar = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $Win11Taskbar -Name "TaskbarAl" -Value 0 -Type DWord -Force
    Safe-WriteLog "Start Menu aligned to left" "SUCCESS"

    Safe-WriteLog "Taskbar tweaks completed" "SUCCESS"
}

function Apply-ExplorerTweaks {
    Safe-WriteLog "EXPLORER TWEAKS" "SECTION"

    $Advanced = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    # Open File Explorer to This PC
    Safe-WriteLog "Setting Explorer to open to This PC..."
    Set-ItemProperty -Path $Advanced -Name "LaunchTo" -Value 1 -Type DWord -Force
    Safe-WriteLog "Explorer opens to This PC" "SUCCESS"

    # Show extensions for all file types
    Safe-WriteLog "Showing file extensions..."
    Set-ItemProperty -Path $Advanced -Name "HideFileExt" -Value 0 -Type DWord -Force
    Safe-WriteLog "File extensions visible" "SUCCESS"

    # Show all hidden files
    Safe-WriteLog "Showing hidden files..."
    Set-ItemProperty -Path $Advanced -Name "Hidden" -Value 1 -Type DWord -Force
    Safe-WriteLog "Hidden files visible" "SUCCESS"

    # Show protected operating system files
    Safe-WriteLog "Showing protected OS files..."
    Set-ItemProperty -Path $Advanced -Name "ShowSuperHidden" -Value 1 -Type DWord -Force
    Safe-WriteLog "Protected OS files visible" "SUCCESS"

    # Launch folder windows in separate process
    Safe-WriteLog "Enabling separate process for folders..."
    Set-ItemProperty -Path $Advanced -Name "SeparateProcess" -Value 1 -Type DWord -Force
    Safe-WriteLog "Separate process enabled" "SUCCESS"

    # Show full path in title bar
    Safe-WriteLog "Showing full path in title bar..."
    $CabinetState = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CabinetState"
    if (-not (Test-Path $CabinetState)) { New-Item -Path $CabinetState -Force | Out-Null }
    Set-ItemProperty -Path $CabinetState -Name "FullPath" -Value 1 -Type DWord -Force
    Safe-WriteLog "Full path shown" "SUCCESS"

    # Disable video file preview (performance)
    Safe-WriteLog "Disabling video preview in Explorer..."
    $Preview = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
    Set-ItemProperty -Path $Preview -Name "DisableThumbnailCache" -Value 1 -Type DWord -Force
    Safe-WriteLog "Video preview disabled" "SUCCESS"

    # Do not display Frequently Used Folders in Quick Access
    Safe-WriteLog "Disabling frequent folders in Quick Access..."
    Set-ItemProperty -Path $Advanced -Name "ShowFrequent" -Value 0 -Type DWord -Force
    Safe-WriteLog "Frequent folders disabled" "SUCCESS"

    # Do not display Recently Used Files in Quick Access
    Safe-WriteLog "Disabling recent files in Quick Access..."
    Set-ItemProperty -Path $Advanced -Name "ShowRecent" -Value 0 -Type DWord -Force
    Safe-WriteLog "Recent files disabled" "SUCCESS"

    Safe-WriteLog "Explorer tweaks completed" "SUCCESS"
}

function Apply-ContextMenuTweaks {
    # Check if Safe-WriteLog is available, fallback to Write-Host if not
    $hasWriteLog = Get-Command 'Safe-WriteLog' -ErrorAction SilentlyContinue
    $script:wl = if ($hasWriteLog) { 'Safe-WriteLog' } else { 'Write-Host' }
    
    & $script:wl "CONTEXT MENU TWEAKS" $(if ($hasWriteLog) { "SECTION" })

    # Enable "End Task" in taskbar context menu (Windows 11) - Safe, HKCU only
    & $script:wl "Enabling 'End Task' in taskbar context menu..."
    try {
        $EndTask = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
        if (-not (Test-Path $EndTask)) { New-Item -Path $EndTask -Force | Out-Null }
        Set-ItemProperty -Path $EndTask -Name "TaskbarEndTask" -Value 1 -Type DWord -Force
        & $script:wl "End Task enabled in taskbar" $(if ($hasWriteLog) { "SUCCESS" })
    } catch {
        & $script:wl "Could not enable End Task: $_" $(if ($hasWriteLog) { "WARNING" })
    }

    # Restore classic context menu (Windows 11) - Safe, HKCU only
    & $script:wl "Restoring classic context menu (Windows 11)..."
    try {
        $ClassicMenu = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        if (-not (Test-Path $ClassicMenu)) {
            New-Item -Path $ClassicMenu -Force | Out-Null
        }
        Set-ItemProperty -Path $ClassicMenu -Name "(Default)" -Value "" -Force
        & $script:wl "Classic context menu restored" $(if ($hasWriteLog) { "SUCCESS" })
    } catch {
        & $script:wl "Could not restore classic menu: $_" $(if ($hasWriteLog) { "WARNING" })
    }

    # Disable "Scan with Windows Defender" context menu (HKCR - may need admin)
    & $script:wl "Removing 'Scan with Defender' from context menu..."
    try {
        $defenderPath = "Registry::HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\EPP"
        if (Test-Path $defenderPath) {
            Remove-Item -Path $defenderPath -Recurse -Force -ErrorAction Stop
            & $script:wl "Defender scan removed from context menu" $(if ($hasWriteLog) { "SUCCESS" })
        } else {
            & $script:wl "Defender context menu entry not found (may already be removed)" $(if ($hasWriteLog) { "INFO" })
        }
    } catch {
        & $script:wl "Could not remove Defender scan (may need TrustedInstaller): $_" $(if ($hasWriteLog) { "WARNING" })
    }

    # Hide BitLocker context menu entries (safer than delete)
    & $script:wl "Hiding BitLocker from context menu..."
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
    & $script:wl "BitLocker context menu entries processed" $(if ($hasWriteLog) { "SUCCESS" })

    & $script:wl "Context menu tweaks completed" $(if ($hasWriteLog) { "SUCCESS" })
    Write-Host ""
    Write-Host "Note: Some changes require Explorer restart or logoff to take effect." -ForegroundColor Yellow
}

function Apply-SecurityTweaks {
    Safe-WriteLog "SECURITY SETTINGS" "SECTION"

    # Administrator approval mode for built-in administrator
    Safe-WriteLog "Configuring Admin Approval Mode..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "FilterAdministratorToken" -Value 1 -Type DWord -Force
    Safe-WriteLog "Admin Approval Mode configured" "SUCCESS"

    # Disable SmartScreen Filter
    Safe-WriteLog "Disabling SmartScreen Filter..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force
    $SmartScreen = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
    if (-not (Test-Path $SmartScreen)) { New-Item -Path $SmartScreen -Force | Out-Null }
    Set-ItemProperty -Path $SmartScreen -Name "EnableWebContentEvaluation" -Value 0 -Type DWord -Force
    Safe-WriteLog "SmartScreen disabled" "SUCCESS"

    # Disable safety warning when opening programs
    Safe-WriteLog "Disabling 'Open File - Security Warning'..."
    $Associations = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations"
    if (-not (Test-Path $Associations)) { New-Item -Path $Associations -Force | Out-Null }
    Set-ItemProperty -Path $Associations -Name "LowRiskFileTypes" -Value ".exe;.msi;.bat;.cmd;.ps1;.reg;.vbs;.js" -Force

    $Attachments = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments"
    if (-not (Test-Path $Attachments)) { New-Item -Path $Attachments -Force | Out-Null }
    Set-ItemProperty -Path $Attachments -Name "SaveZoneInformation" -Value 1 -Type DWord -Force
    Safe-WriteLog "Security warnings disabled" "SUCCESS"

    Safe-WriteLog "Security tweaks completed" "SUCCESS"
}

function Apply-WindowsExperienceTweaks {
    Safe-WriteLog "WINDOWS EXPERIENCE TWEAKS" "SECTION"

    $CDM = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"

    # Disable suggestions in Start Menu
    Safe-WriteLog "Disabling Start Menu suggestions..."
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force
    Safe-WriteLog "Start Menu suggestions disabled" "SUCCESS"

    # Disable search for apps in Windows Store
    Safe-WriteLog "Disabling Store app search..."
    $StoreSearch = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $StoreSearch)) { New-Item -Path $StoreSearch -Force | Out-Null }
    Set-ItemProperty -Path $StoreSearch -Name "NoUseStoreOpenWith" -Value 1 -Type DWord -Force
    Safe-WriteLog "Store app search disabled" "SUCCESS"

    # Disable ads from Windows Store
    Safe-WriteLog "Disabling Store ads..."
    Set-ItemProperty -Path $CDM -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Safe-WriteLog "Store ads disabled" "SUCCESS"

    # Disable Windows Spotlight on lock screen
    Safe-WriteLog "Disabling Windows Spotlight..."
    Set-ItemProperty -Path $CDM -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord -Force
    $LockScreen = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $LockScreen)) { New-Item -Path $LockScreen -Force | Out-Null }
    Set-ItemProperty -Path $LockScreen -Name "DisableWindowsSpotlightFeatures" -Value 1 -Type DWord -Force
    Safe-WriteLog "Windows Spotlight disabled" "SUCCESS"

    # Disable "Get suggestions when using Windows"
    Safe-WriteLog "Disabling Windows suggestions..."
    Set-ItemProperty -Path $CDM -Name "SoftLandingEnabled" -Value 0 -Type DWord -Force
    Safe-WriteLog "Windows suggestions disabled" "SUCCESS"

    # Disable "Highlight newly installed programs"
    Safe-WriteLog "Disabling new program highlighting..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_NotifyNewApps" -Value 0 -Type DWord -Force
    Safe-WriteLog "New program highlighting disabled" "SUCCESS"

    # Disable automatic installation of recommended apps
    Safe-WriteLog "Disabling auto-install of recommended apps..."
    Set-ItemProperty -Path $CDM -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CDM -Name "PreInstalledAppsEverEnabled" -Value 0 -Type DWord -Force
    Safe-WriteLog "Auto-install disabled" "SUCCESS"

    # Disable Game DVR/Recorder
    Safe-WriteLog "Disabling Game DVR..."
    $GameDVR = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    if (-not (Test-Path $GameDVR)) { New-Item -Path $GameDVR -Force | Out-Null }
    Set-ItemProperty -Path $GameDVR -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
    $GameBar = "HKCU:\System\GameConfigStore"
    if (-not (Test-Path $GameBar)) { New-Item -Path $GameBar -Force | Out-Null }
    Set-ItemProperty -Path $GameBar -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
    Safe-WriteLog "Game DVR disabled" "SUCCESS"

    # Disable First Logon Animation
    Safe-WriteLog "Disabling First Logon Animation..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord -Force
    Safe-WriteLog "First Logon Animation disabled" "SUCCESS"

    Safe-WriteLog "Windows Experience tweaks completed" "SUCCESS"
}

function Enable-WindowsPhotoViewer {
    Safe-WriteLog "ENABLING WINDOWS PHOTO VIEWER" "SECTION"

    Write-Host ""
    Write-Host "This will enable the classic Windows Photo Viewer for image files." -ForegroundColor Yellow
    Write-Host "It will be available as an option in 'Open with' menu." -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Safe-WriteLog "Cancelled" "INFO"
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

    Safe-WriteLog "Windows Photo Viewer enabled for: $($imageTypes -join ', ')" "SUCCESS"
    Write-Host "You can now right-click images and choose 'Open with' > 'Windows Photo Viewer'" -ForegroundColor Green
}

function Apply-NotepadMediaTweaks {
    Safe-WriteLog "NOTEPAD & MEDIA PLAYER TWEAKS" "SECTION"

    # Notepad: Enable word wrap
    Safe-WriteLog "Enabling Notepad word wrap..."
    $Notepad = "HKCU:\SOFTWARE\Microsoft\Notepad"
    if (-not (Test-Path $Notepad)) { New-Item -Path $Notepad -Force | Out-Null }
    Set-ItemProperty -Path $Notepad -Name "fWrap" -Value 1 -Type DWord -Force
    Safe-WriteLog "Notepad word wrap enabled" "SUCCESS"

    # Notepad: Show status bar
    Safe-WriteLog "Enabling Notepad status bar..."
    Set-ItemProperty -Path $Notepad -Name "StatusBar" -Value 1 -Type DWord -Force
    Safe-WriteLog "Notepad status bar enabled" "SUCCESS"

    # Windows Media Player: Hide First Run Wizard
    Safe-WriteLog "Disabling Media Player First Run Wizard..."
    $WMP = "HKCU:\SOFTWARE\Microsoft\MediaPlayer\Preferences"
    if (-not (Test-Path $WMP)) { New-Item -Path $WMP -Force | Out-Null }
    Set-ItemProperty -Path $WMP -Name "AcceptedPrivacyStatement" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $WMP -Name "FirstTime" -Value 1 -Type DWord -Force

    $WMPSetup = "HKLM:\SOFTWARE\Microsoft\MediaPlayer\Setup\Completed"
    if (-not (Test-Path $WMPSetup)) { New-Item -Path $WMPSetup -Force | Out-Null }
    Set-ItemProperty -Path $WMPSetup -Name "FirstTime" -Value 1 -Type DWord -Force
    Safe-WriteLog "Media Player wizard disabled" "SUCCESS"

    # Disable Customer Experience Improvement Program
    Safe-WriteLog "Disabling CEIP..."
    $CEIP = "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows"
    if (-not (Test-Path $CEIP)) { New-Item -Path $CEIP -Force | Out-Null }
    Set-ItemProperty -Path $CEIP -Name "CEIPEnable" -Value 0 -Type DWord -Force
    Safe-WriteLog "CEIP disabled" "SUCCESS"

    # Disable NTFS Link Tracking Service
    Safe-WriteLog "Disabling NTFS Link Tracking Service (TrkWks)..."
    try {
        Stop-Service -Name "TrkWks" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "TrkWks" -StartupType Disabled -ErrorAction SilentlyContinue
        Safe-WriteLog "TrkWks service disabled" "SUCCESS"
    } catch {
        Safe-WriteLog "Could not disable TrkWks" "WARNING"
    }

    # Windows Update: Exclude Malware Removal Tool
    Safe-WriteLog "Excluding Malware Removal Tool from Windows Update..."
    $WUPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\MRT"
    if (-not (Test-Path $WUPolicy)) { New-Item -Path $WUPolicy -Force | Out-Null }
    Set-ItemProperty -Path $WUPolicy -Name "DontOfferThroughWUAU" -Value 1 -Type DWord -Force
    Safe-WriteLog "Malware Removal Tool excluded from WU" "SUCCESS"

    Safe-WriteLog "Notepad & Media Player tweaks completed" "SUCCESS"
}

function Apply-InternetExplorerTweaks {
    Safe-WriteLog "INTERNET EXPLORER TWEAKS" "SECTION"

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
    Safe-WriteLog "Setting links to open in new tab..."
    Set-ItemProperty -Path $IETabs -Name "PopupsUseNewWindow" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $IENew -Name "PopupMgr" -Value "yes" -Force
    Safe-WriteLog "Links open in new tab" "SUCCESS"

    # Display all websites in Compatibility View
    Safe-WriteLog "Enabling Compatibility View for all sites..."
    $IECompat = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\BrowserEmulation"
    if (-not (Test-Path $IECompat)) { New-Item -Path $IECompat -Force | Out-Null }
    Set-ItemProperty -Path $IECompat -Name "AllSitesCompatibilityMode" -Value 1 -Type DWord -Force
    Safe-WriteLog "Compatibility View enabled" "SUCCESS"

    # Enable AutoComplete
    Safe-WriteLog "Enabling AutoComplete..."
    Set-ItemProperty -Path $IEMain -Name "Use FormSuggest" -Value "yes" -Force
    Set-ItemProperty -Path $IEMain -Name "FormSuggest Passwords" -Value "yes" -Force
    Set-ItemProperty -Path $IEMain -Name "FormSuggest PW Ask" -Value "yes" -Force
    $IEAutoComplete = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete"
    if (-not (Test-Path $IEAutoComplete)) { New-Item -Path $IEAutoComplete -Force | Out-Null }
    Set-ItemProperty -Path $IEAutoComplete -Name "AutoSuggest" -Value "yes" -Force
    Safe-WriteLog "AutoComplete enabled" "SUCCESS"

    # Turn off Suggested Sites
    Safe-WriteLog "Disabling Suggested Sites..."
    Set-ItemProperty -Path $IESuggest -Name "Enabled" -Value 0 -Type DWord -Force
    $IESuggestPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Suggested Sites"
    if (-not (Test-Path $IESuggestPolicy)) { New-Item -Path $IESuggestPolicy -Force | Out-Null }
    Set-ItemProperty -Path $IESuggestPolicy -Name "Enabled" -Value 0 -Type DWord -Force
    Safe-WriteLog "Suggested Sites disabled" "SUCCESS"

    # Prevent running First Run wizard
    Safe-WriteLog "Disabling First Run wizard..."
    Set-ItemProperty -Path $IEMain -Name "DisableFirstRunCustomize" -Value 1 -Type DWord -Force
    $IEPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main"
    if (-not (Test-Path $IEPolicy)) { New-Item -Path $IEPolicy -Force | Out-Null }
    Set-ItemProperty -Path $IEPolicy -Name "DisableFirstRunCustomize" -Value 1 -Type DWord -Force
    Safe-WriteLog "First Run wizard disabled" "SUCCESS"

    # Regional information does not save attachments (security)
    Safe-WriteLog "Configuring attachment security..."
    $IEAttach = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments"
    if (-not (Test-Path $IEAttach)) { New-Item -Path $IEAttach -Force | Out-Null }
    Set-ItemProperty -Path $IEAttach -Name "SaveZoneInformation" -Value 1 -Type DWord -Force
    Safe-WriteLog "Attachment zone info preserved" "SUCCESS"

    # Lock Internet Explorer toolbar
    Safe-WriteLog "Locking IE toolbar..."
    Set-ItemProperty -Path $IEToolbar -Name "Locked" -Value 1 -Type DWord -Force
    Safe-WriteLog "Toolbar locked" "SUCCESS"

    # Adjust number of simultaneous downloads to 10
    Safe-WriteLog "Setting max simultaneous downloads to 10..."
    Set-ItemProperty -Path $IEDownload -Name "MaxConnectionsPerServer" -Value 10 -Type DWord -Force
    Set-ItemProperty -Path $IEDownload -Name "MaxConnectionsPer1_0Server" -Value 10 -Type DWord -Force
    Safe-WriteLog "Max downloads set to 10" "SUCCESS"

    # Always display pop-up windows in new tab
    Safe-WriteLog "Setting pop-ups to open in new tab..."
    Set-ItemProperty -Path $IETabs -Name "PopupsUseNewWindow" -Value 0 -Type DWord -Force
    Safe-WriteLog "Pop-ups open in new tab" "SUCCESS"

    # Hide feedback smile face (top-right)
    Safe-WriteLog "Hiding feedback button..."
    $IEFeedback = "HKCU:\SOFTWARE\Microsoft\Internet Explorer\Suggested Sites"
    Set-ItemProperty -Path $IEMain -Name "EnableSuggestedSites" -Value 0 -Type DWord -Force
    # Disable feedback via policy
    $IEFeedbackPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Restrictions"
    if (-not (Test-Path $IEFeedbackPolicy)) { New-Item -Path $IEFeedbackPolicy -Force | Out-Null }
    Set-ItemProperty -Path $IEFeedbackPolicy -Name "NoHelpItemSendFeedback" -Value 1 -Type DWord -Force
    Safe-WriteLog "Feedback button hidden" "SUCCESS"

    Safe-WriteLog "Internet Explorer tweaks completed" "SUCCESS"
}

function Apply-DesktopIconTweaks {
    Set-ConsoleSize
    Clear-Host
    Safe-WriteLog "DESKTOP ICONS" "SECTION"

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

    switch ($iconChoice) {
        "1" {
            Set-ItemProperty -Path $DesktopIcons -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Type DWord -Force
            Safe-WriteLog "This PC icon shown" "SUCCESS"
        }
        "2" {
            Set-ItemProperty -Path $DesktopIcons -Name "{645FF040-5081-101B-9F08-00AA002F954E}" -Value 0 -Type DWord -Force
            Safe-WriteLog "Recycle Bin icon shown" "SUCCESS"
        }
        "3" {
            Set-ItemProperty -Path $DesktopIcons -Name "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" -Value 0 -Type DWord -Force
            Safe-WriteLog "Control Panel icon shown" "SUCCESS"
        }
        "4" {
            Set-ItemProperty -Path $DesktopIcons -Name "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Value 0 -Type DWord -Force
            Safe-WriteLog "User Folder icon shown" "SUCCESS"
        }
        "5" {
            Set-ItemProperty -Path $DesktopIcons -Name "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" -Value 0 -Type DWord -Force
            Safe-WriteLog "Network icon shown" "SUCCESS"
        }
        "6" {
            Set-ItemProperty -Path $DesktopIcons -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $DesktopIcons -Name "{645FF040-5081-101B-9F08-00AA002F954E}" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $DesktopIcons -Name "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $DesktopIcons -Name "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $DesktopIcons -Name "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" -Value 0 -Type DWord -Force
            Safe-WriteLog "All desktop icons shown" "SUCCESS"
        }
        "0" { Safe-WriteLog "Skipped" "INFO" }
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

    Safe-WriteLog "Desktop icons configured" "SUCCESS"
}

function Start-DISMStyleTweaks {
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
            "3" { Apply-DesktopIconTweaks }
            "4" { Apply-ContextMenuTweaks }
            "5" { Apply-SecurityTweaks }
            "6" { Apply-WindowsExperienceTweaks }
            "7" { Enable-WindowsPhotoViewer }
            "8" { Apply-NotepadMediaTweaks }
            "9" { Apply-InternetExplorerTweaks }
            "10" {
                Safe-WriteLog "Applying ALL DISM++ style tweaks..."
                Apply-TaskbarTweaks
                Apply-ExplorerTweaks
                Apply-DesktopIconTweaks
                Apply-ContextMenuTweaks
                Apply-SecurityTweaks
                Apply-WindowsExperienceTweaks
                Enable-WindowsPhotoViewer
                Apply-NotepadMediaTweaks
                Apply-InternetExplorerTweaks
                Safe-WriteLog "All DISM++ tweaks applied!" "SUCCESS"
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
    'Apply-TaskbarTweaks',
    'Apply-ExplorerTweaks',
    'Apply-DesktopIconTweaks',
    'Apply-ContextMenuTweaks',
    'Apply-SecurityTweaks',
    'Apply-WindowsExperienceTweaks',
    'Enable-WindowsPhotoViewer',
    'Apply-NotepadMediaTweaks',
    'Apply-InternetExplorerTweaks',
    'Start-DISMStyleTweaks'
)
