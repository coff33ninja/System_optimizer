#Requires -Version 5.1
<#
.SYNOPSIS
    Bloatware Module - System Optimizer
.DESCRIPTION
    Provides Windows 10/11 debloating functions to remove pre-installed apps
    and privacy-invasive components. Compatible with Windows 7+ and PowerShell 2.0+.

Exported Functions:
    Test-AppxSupport          - Check if AppX cmdlets are available
    Get-AppxPackageSafe       - Get AppX packages with fallback
    Remove-AppxPackageSafe    - Remove AppX package with error handling
    Add-AppxPackageSafe       - Add AppX package with error handling
    DebloatBlacklist          - Remove blacklisted bloatware apps
    DebloatAll                - Aggressive debloating (all removable apps)
    Protect-Privacy           - Apply privacy tweaks without app removal
    Block-TelemetryHosts      - Block telemetry via hosts file

Apps Removed:
    - Xbox apps (Game Bar, Identity Provider, etc.)
    - Microsoft apps (Solitaire, News, Weather, etc.)
    - Third-party (TikTok, Candy Crush, Spotify, etc.)
    - Clipchamp, Phone Link, Quick Assist

Compatibility:
    - Windows 7+: Core functions work
    - Windows 8+: AppX functions available
    - Windows 10/11: Full functionality

Notes:
    - Keeps Teams and Phone Companion by default (startup disabled only)
    - Creates restore point before aggressive debloating
    - Supports both AppX and traditional uninstall methods

Requires Admin: Yes

Version: 1.0.0
#>

# ============================================================================
# COMPATIBILITY HELPERS
# ============================================================================
$script:PSVersionMajor = $PSVersionTable.PSVersion.Major
$script:WinBuild = [System.Environment]::OSVersion.Version.Build
$script:IsWin8OrNewer = $WinBuild -ge 9200   # Windows 8 = 9200
$script:IsWin10OrNewer = $WinBuild -ge 10240 # Windows 10 = 10240
$script:HasAppxCmdlets = $script:IsWin8OrNewer -and (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)

function Test-AppxSupport {
    <#
    .SYNOPSIS
        Check if AppX cmdlets are available (Windows 8+)
    #>
    if (-not $script:HasAppxCmdlets) {
        Write-Host "[!] AppX packages not supported on this Windows version" -ForegroundColor Yellow
        Write-Host "    Requires Windows 8 or newer" -ForegroundColor DarkGray
        return $false
    }
    return $true
}

function Get-AppxPackageSafe {
    <#
    .SYNOPSIS
        Safe wrapper for Get-AppxPackage with version check
    #>
    param(
        [string]$Name,
        [switch]$AllUsers
    )

    if (-not $script:HasAppxCmdlets) { return $null }

    if ($Name -and $AllUsers) {
        Get-AppxPackage -Name $Name -AllUsers -ErrorAction SilentlyContinue
    } elseif ($Name) {
        Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue
    } elseif ($AllUsers) {
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    } else {
        Get-AppxPackage -ErrorAction SilentlyContinue
    }
}

function Remove-AppxPackageSafe {
    <#
    .SYNOPSIS
        Safe wrapper for Remove-AppxPackage with version check
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Package
    )

    process {
        if (-not $script:HasAppxCmdlets) { return }
        if ($Package) {
            $Package | Remove-AppxPackage -ErrorAction SilentlyContinue
        }
    }
}

function Add-AppxPackageSafe {
    <#
    .SYNOPSIS
        Safe wrapper for Add-AppxPackage with version check
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Register,
        [switch]$DisableDevelopmentMode
    )

    if (-not $script:HasAppxCmdlets) { return }

    if ($DisableDevelopmentMode) {
        Add-AppxPackage -Register $Register -DisableDevelopmentMode -ErrorAction SilentlyContinue
    } else {
        Add-AppxPackage -Register $Register -ErrorAction SilentlyContinue
    }
}

$ErrorActionPreference = 'SilentlyContinue'

$DebloatFolder = "C:\Temp\Windows10Debloater"
If (Test-Path $DebloatFolder) {
    Write-Output "$DebloatFolder exists. Skipping."
}
Else {
    Write-Output "The folder '$DebloatFolder' doesn't exist. This folder will be used for storing logs created after the script runs. Creating now."
    Start-Sleep 1
    New-Item -Path "$DebloatFolder" -ItemType Directory
    Write-Output "The folder $DebloatFolder was successfully created."
}

Start-Transcript -OutputDirectory "$DebloatFolder"

Add-Type -AssemblyName PresentationCore, PresentationFramework

Function DebloatAll {
    <#
    .SYNOPSIS
        Remove all non-essential AppX packages
    .DESCRIPTION
        Removes AppxPackages except whitelisted essential apps.
        Only works on Windows 8+ where AppX is available.
    #>

    if (-not (Test-AppxSupport)) { return }

    # Use progress tracking if available
    $hasProgress = Get-Command 'Start-ProgressOperation' -ErrorAction SilentlyContinue
    if ($hasProgress) {
        Start-ProgressOperation -Name "Removing All Non-Essential Apps" -TotalItems 3
    }

    #Credit to /u/GavinEke for a modified version of my whitelist code
    $WhitelistedApps = 'Microsoft.ScreenSketch|Microsoft.Paint3D|Microsoft.WindowsCalculator|Microsoft.WindowsStore|Microsoft.Windows.Photos|CanonicalGroupLimited.UbuntuonWindows|`
    Microsoft.XboxGameCallableUI|Microsoft.XboxGamingOverlay|Microsoft.Xbox.TCUI|Microsoft.XboxGamingOverlay|Microsoft.XboxIdentityProvider|Microsoft.MicrosoftStickyNotes|Microsoft.MSPaint|Microsoft.WindowsCamera|.NET|Framework|`
    Microsoft.HEIFImageExtension|Microsoft.ScreenSketch|Microsoft.StorePurchaseApp|Microsoft.VP9VideoExtensions|Microsoft.WebMediaExtensions|Microsoft.WebpImageExtension|Microsoft.DesktopAppInstaller|WindSynthBerry|MIDIBerry|Slack'
    #NonRemovable Apps that where getting attempted and the system would reject the uninstall, speeds up debloat and prevents 'initalizing' overlay when removing apps
    $NonRemovable = '1527c705-839a-4832-9118-54d4Bd6a0c89|c5e2524a-ea46-4f67-841f-6a9465d9d515|E2A4F912-2574-4A75-9BB0-0D023378592B|F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE|InputApp|Microsoft.AAD.BrokerPlugin|Microsoft.AccountsControl|`
    Microsoft.BioEnrollment|Microsoft.CredDialogHost|Microsoft.ECApp|Microsoft.LockApp|Microsoft.MicrosoftEdgeDevToolsClient|Microsoft.MicrosoftEdge|Microsoft.PPIProjection|Microsoft.Win32WebViewHost|Microsoft.Windows.Apprep.ChxApp|`
    Microsoft.Windows.AssignedAccessLockApp|Microsoft.Windows.CapturePicker|Microsoft.Windows.CloudExperienceHost|Microsoft.Windows.ContentDeliveryManager|Microsoft.Windows.Cortana|Microsoft.Windows.NarratorQuickStart|`
    Microsoft.Windows.ParentalControls|Microsoft.Windows.PeopleExperienceHost|Microsoft.Windows.PinningConfirmationDialog|Microsoft.Windows.SecHealthUI|Microsoft.Windows.SecureAssessmentBrowser|Microsoft.Windows.ShellExperienceHost|`
    Microsoft.Windows.XGpuEjectDialog|Microsoft.XboxGameCallableUI|Windows.CBSPreview|windows.immersivecontrolpanel|Windows.PrintDialog|Microsoft.VCLibs.140.00|Microsoft.Services.Store.Engagement|Microsoft.UI.Xaml.2.0|*Nvidia*'

    try {
        # Remove for all users
        if ($hasProgress) {
            Update-ProgressItem -ItemName "Removing apps for all users" -Status 'Success'
        }
        $allUserApps = Get-AppxPackageSafe -AllUsers | Where-Object {$_.Name -NotMatch $WhitelistedApps -and $_.Name -NotMatch $NonRemovable}
        $allUserApps | Remove-AppxPackageSafe

        # Remove for current user
        if ($hasProgress) {
            Update-ProgressItem -ItemName "Removing apps for current user" -Status 'Success'
        }
        $currentUserApps = Get-AppxPackageSafe | Where-Object {$_.Name -NotMatch $WhitelistedApps -and $_.Name -NotMatch $NonRemovable}
        $currentUserApps | Remove-AppxPackageSafe

        # Remove provisioned packages (prevents reinstall on new users) - Win10+ only
        if ($script:IsWin10OrNewer) {
            if ($hasProgress) {
                Update-ProgressItem -ItemName "Removing provisioned packages" -Status 'Success'
            }
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object {$_.PackageName -NotMatch $WhitelistedApps -and $_.PackageName -NotMatch $NonRemovable} |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        } else {
            if ($hasProgress) {
                Update-ProgressItem -ItemName "Removing provisioned packages" -Status 'Skipped' -Message "Not supported on this Windows version"
            }
        }
    } catch {
        if ($hasProgress) {
            Update-ProgressItem -ItemName "App removal process" -Status 'Failed' -Message $_.Exception.Message
        }
        Write-Host "Error during app removal: $($_.Exception.Message)" -ForegroundColor Red
    }

    if ($hasProgress) {
        Complete-ProgressOperation
    }
    
    # Ensure progress cleanup to prevent UI issues
    if (Get-Command 'Ensure-ProgressCleanup' -ErrorAction SilentlyContinue) {
        Ensure-ProgressCleanup
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function DebloatBlacklist {

    $Bloatware = @(

        # ============================================
        # Windows 10/11 Built-in Bloatware
        # ============================================
        "Microsoft.BingNews"
        "Microsoft.BingWeather"
        "Microsoft.BingFinance"
        "Microsoft.BingSports"
        "Microsoft.BingTranslator"
        "Microsoft.BingTravel"
        "Microsoft.BingHealthAndFitness"
        "Microsoft.BingFoodAndDrink"
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
        "Microsoft.RemoteDesktop"
        "Microsoft.SkypeApp"
        "Microsoft.StorePurchaseApp"
        "Microsoft.Office.Todo.List"
        "Microsoft.Whiteboard"
        "Microsoft.WindowsAlarms"
        #"Microsoft.WindowsCamera"
        "microsoft.windowscommunicationsapps"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.WindowsMaps"
        "Microsoft.WindowsSoundRecorder"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
        "Microsoft.MixedReality.Portal"
        "Microsoft.ScreenSketch"
        #"Microsoft.YourPhone"  # Keep Phone Companion - useful for phone integration
        "Microsoft.MicrosoftEdge.Stable"
        "Microsoft.Todos"
        "Microsoft.PowerAutomateDesktop"
        "Microsoft.549981C3F5F10"  # Cortana
        "MicrosoftCorporationII.QuickAssist"
        "Microsoft.WindowsTerminal"  # Optional - some users want this

        # ============================================
        # Windows 11 Specific Bloatware
        # ============================================
        "Microsoft.GamingApp"
        "Microsoft.WindowsMeetNow"
        #"MicrosoftTeams"  # Keep - just disable startup instead
        #"Microsoft.Teams.Free"  # Keep - just disable startup instead
        #"MSTeams"  # Keep - just disable startup instead
        "Clipchamp.Clipchamp"
        "Microsoft.Clipchamp"
        "Microsoft.Windows.DevHome"
        "Microsoft.WindowsNotepad"  # New Notepad app (optional)
        "Microsoft.Paint"  # New Paint app (optional)
        "Microsoft.OutlookForWindows"  # New Outlook
        "Microsoft.Windows.Ai.Copilot.Provider"
        "Microsoft.Copilot"
        "Microsoft.Windows.Photos"  # Optional - new Photos app

        # ============================================
        # Xbox Related (Gaming)
        # ============================================
        "Microsoft.Xbox.TCUI"
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxGamingOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.GamingServices"
        "Microsoft.XboxGameCallableUI"

        # ============================================
        # Sponsored/Third-Party Bloatware
        # ============================================
        "*EclipseManager*"
        "*ActiproSoftwareLLC*"
        "*AdobeSystemsIncorporated.AdobePhotoshopExpress*"
        "*Duolingo-LearnLanguagesforFree*"
        "*PandoraMediaInc*"
        "*CandyCrush*"
        "*BubbleWitch3Saga*"
        "*Wunderlist*"
        "*Flipboard*"
        "*Twitter*"
        "*Facebook*"
        "*Spotify*"
        "*Minecraft*"
        "*Royal Revolt*"
        "*Sway*"
        "*Speed Test*"
        "*Dolby*"
        "*Disney*"
        "*Netflix*"
        "*Hulu*"
        "*Amazon*"
        "*TikTok*"
        "*Instagram*"
        "*WhatsApp*"
        "*LinkedIn*"
        "*Phototastic*"
        "*PicsArt*"
        "*Viber*"
        "*Shazam*"
        "*Keeper*"
        "*iHeartRadio*"
        "*Drawboard*"
        "*FarmVille*"
        "*MarchofEmpires*"
        "*Asphalt*"
        "*HiddenCity*"
        "*HiddenCityMysteryofShadows*"
        "*AgeOfEmpires*"
        "*Roblox*"
        "*king.com*"
        "*Zynga*"
        "*BytedancePte*"
        "*COOKINGFEVER*"
        "*PrimeVideo*"
        "*DisneyMagicKingdoms*"
        "*DragonManiaLegends*"
        "*Fitbit*"
        "*Plex*"
        "*SlingTV*"
        "*HPPrinter*"
        "*HPJumpStart*"
        "*HPPCHardwareDiagnosticsWindows*"
        "*HPPrivacySettings*"
        #"*HPSupportAssistant*"  # Keep - useful for hardware diagnostics
        "*HPQuickDrop*"
        "*HPSystemInformation*"
        "*HPWorkWell*"
        "*myHP*"
        #"*DellSupportAssist*"  # Keep - useful for hardware diagnostics
        "*DellDigitalDelivery*"
        "*DellMobileConnect*"
        #"*LenovoCompanion*"  # Keep - useful for hardware diagnostics
        "*LenovoSettings*"
        "*LenovoUtility*"
        "*McAfee*"
        "*Norton*"
        "*Avast*"
        "*AVG*"
        "*ExpressVPN*"
        "*NordVPN*"
        "*Dashlane*"
        "*LastPass*"
        "*Booking*"
        "*Expedia*"
        "*Kayak*"
        "*Tripadvisor*"

        # ============================================
        # Windows 8/8.1 Legacy Apps (if present)
        # ============================================
        "Microsoft.Reader"
        "Microsoft.BingMaps"
        "Microsoft.WindowsReadingList"
        "Microsoft.WindowsScan"

        #Optional: Typically not removed but you can if you need to for some reason
        #"*Microsoft.Advertising.Xaml_10.1712.5.0_x64__8wekyb3d8bbwe*"
        #"*Microsoft.Advertising.Xaml_10.1712.5.0_x86__8wekyb3d8bbwe*"
        #"*Microsoft.MSPaint*"
        #"*Microsoft.MicrosoftStickyNotes*"
        #"*Microsoft.WindowsCalculator*"
        #"*Microsoft.WindowsStore*"
    )

    # Use progress tracking if available
    $hasProgress = Get-Command 'Start-ProgressOperation' -ErrorAction SilentlyContinue
    if ($hasProgress) {
        Start-ProgressOperation -Name "Removing Bloatware" -TotalItems $Bloatware.Count
    }

    # Check AppX support once
    $canUseAppx = Test-AppxSupport

    foreach ($Bloat in $Bloatware) {
        $removed = $false
        try {
            if ($canUseAppx) {
                $pkg = Get-AppxPackageSafe -Name $Bloat
                if ($pkg) {
                    $pkg | Remove-AppxPackageSafe
                    $removed = $true
                }
                # Provisioned packages only on Win10+
                if ($script:IsWin10OrNewer) {
                    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -like $Bloat
                    if ($prov) {
                        $prov | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                        $removed = $true
                    }
                }
            }

            if ($hasProgress) {
                if ($removed) {
                    Update-ProgressItem -ItemName $Bloat -Status 'Success'
                } else {
                    Update-ProgressItem -ItemName $Bloat -Status 'Skipped' -Message "Not installed"
                }
            } else {
                Write-Output "Trying to remove $Bloat."
            }
        } catch {
            if ($hasProgress) {
                Update-ProgressItem -ItemName $Bloat -Status 'Failed' -Message $_.Exception.Message
            }
        }
    }

    if ($hasProgress) {
        Complete-ProgressOperation
    }
    
    # Ensure progress cleanup to prevent UI issues
    if (Get-Command 'Ensure-ProgressCleanup' -ErrorAction SilentlyContinue) {
        Ensure-ProgressCleanup
    }
}

Function Remove-Key {
    <#
    .SYNOPSIS
        Remove leftover registry keys from bloatware apps
    .DESCRIPTION
        Removes registry keys that may remain after AppX package removal.
        Dynamically searches for keys matching bloatware patterns.
    #>

    # Static keys known to cause issues
    $StaticKeys = @(
        # Eclipse Manager
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\46928bounde.EclipseManager_*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\46928bounde.EclipseManager_*"

        # Actipro Software
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\ActiproSoftwareLLC.*"
        "HKCR:\Extensions\ContractId\Windows.File\PackageId\ActiproSoftwareLLC.*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\ActiproSoftwareLLC.*"
        "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\ActiproSoftwareLLC.*"
        "HKCR:\Extensions\ContractId\Windows.ShareTarget\PackageId\ActiproSoftwareLLC.*"

        # Microsoft Office Hub
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.MicrosoftOfficeHub_*"
        "HKCR:\Extensions\ContractId\Windows.PreInstalledConfigTask\PackageId\Microsoft.MicrosoftOfficeHub_*"

        # Xbox related
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.XboxGameCallableUI_*"
        "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.XboxGameCallableUI_*"
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxApp_*"
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGamingOverlay_*"

        # PPIProjection (Connect app)
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.PPIProjection_*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.PPIProjection_*"
        "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.PPIProjection_*"

        # Candy Crush and King games
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\king.com.*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\king.com.*"

        # Facebook
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\*Facebook*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\*Facebook*"
        "HKCR:\Extensions\ContractId\Windows.ShareTarget\PackageId\*Facebook*"

        # Twitter
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\*Twitter*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\*Twitter*"
        "HKCR:\Extensions\ContractId\Windows.ShareTarget\PackageId\*Twitter*"

        # Spotify
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\*Spotify*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\*Spotify*"

        # Disney+
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\*Disney*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\*Disney*"

        # TikTok
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\*TikTok*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\*TikTok*"
        "HKCR:\Extensions\ContractId\Windows.ShareTarget\PackageId\*TikTok*"

        # Instagram
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\*Instagram*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\*Instagram*"
        "HKCR:\Extensions\ContractId\Windows.ShareTarget\PackageId\*Instagram*"

        # Clipchamp
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\*Clipchamp*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\*Clipchamp*"
        "HKCR:\Extensions\ContractId\Windows.File\PackageId\*Clipchamp*"

        # Teams - commented out, keeping Teams (just disable startup)
        #"HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\*Teams*"
        #"HKCR:\Extensions\ContractId\Windows.Launch\PackageId\*Teams*"
        #"HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\*Teams*"

        # Cortana
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.549981C3F5F10_*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.549981C3F5F10_*"

        # Your Phone / Phone Link
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.YourPhone_*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.YourPhone_*"

        # Mixed Reality Portal
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.MixedReality.Portal_*"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.MixedReality.Portal_*"
    )

    # Create HKCR drive if not exists
    if (-not (Test-Path "HKCR:")) {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
    }

    $removedCount = 0
    $failedCount = 0

    foreach ($keyPattern in $StaticKeys) {
        try {
            # Handle wildcard patterns
            $matchingKeys = Get-Item -Path $keyPattern -ErrorAction SilentlyContinue

            if ($matchingKeys) {
                foreach ($key in $matchingKeys) {
                    try {
                        Write-Output "Removing: $($key.PSPath)"
                        Remove-Item $key.PSPath -Recurse -Force -ErrorAction Stop
                        $removedCount++
                    } catch {
                        $failedCount++
                    }
                }
            }
        } catch {
            # Key pattern didn't match anything - that's fine
        }
    }

    Write-Output "Registry cleanup complete: $removedCount keys removed, $failedCount failed"
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function Protect-Privacy {

    #Disables Windows Feedback Experience
    Write-Output "Disabling Windows Feedback Experience program"
    $Advertising = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    If (Test-Path $Advertising) {
        Set-ItemProperty $Advertising Enabled -Value 0
    }

    #Stops Cortana from being used as part of your Windows Search Function
    Write-Output "Stopping Cortana from being used as part of your Windows Search Function"
    $Search = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    If (Test-Path $Search) {
        Set-ItemProperty $Search AllowCortana -Value 0
    }

    #Disables Web Search in Start Menu
    Write-Output "Disabling Bing Search in Start Menu"
    $WebSearch = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" BingSearchEnabled -Value 0
    If (!(Test-Path $WebSearch)) {
        New-Item $WebSearch
    }
    Set-ItemProperty $WebSearch DisableWebSearch -Value 1

    #Stops the Windows Feedback Experience from sending anonymous data
    Write-Output "Stopping the Windows Feedback Experience program"
    $Period = "HKCU:\Software\Microsoft\Siuf\Rules"
    If (!(Test-Path $Period)) {
        New-Item $Period
    }
    Set-ItemProperty $Period PeriodInNanoSeconds -Value 0

    #Prevents bloatware applications from returning and removes Start Menu suggestions
    Write-Output "Adding Registry key to prevent bloatware apps from returning"
    $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    $registryOEM = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    If (!(Test-Path $registryPath)) {
        New-Item $registryPath
    }
    Set-ItemProperty $registryPath DisableWindowsConsumerFeatures -Value 1

    If (!(Test-Path $registryOEM)) {
        New-Item $registryOEM
    }
    Set-ItemProperty $registryOEM  ContentDeliveryAllowed -Value 0
    Set-ItemProperty $registryOEM  OemPreInstalledAppsEnabled -Value 0
    Set-ItemProperty $registryOEM  PreInstalledAppsEnabled -Value 0
    Set-ItemProperty $registryOEM  PreInstalledAppsEverEnabled -Value 0
    Set-ItemProperty $registryOEM  SilentInstalledAppsEnabled -Value 0
    Set-ItemProperty $registryOEM  SystemPaneSuggestionsEnabled -Value 0

    #Preping mixed Reality Portal for removal
    Write-Output "Setting Mixed Reality Portal value to 0 so that you can uninstall it in Settings"
    $Holo = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Holographic"
    If (Test-Path $Holo) {
        Set-ItemProperty $Holo  FirstRunSucceeded -Value 0
    }

    #Disables Wi-fi Sense
    Write-Output "Disabling Wi-Fi Sense"
    $WifiSense1 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting"
    $WifiSense2 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots"
    $WifiSense3 = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"
    If (!(Test-Path $WifiSense1)) {
        New-Item $WifiSense1
    }
    Set-ItemProperty $WifiSense1  Value -Value 0
    If (!(Test-Path $WifiSense2)) {
        New-Item $WifiSense2
    }
    Set-ItemProperty $WifiSense2  Value -Value 0
    Set-ItemProperty $WifiSense3  AutoConnectAllowedOEM -Value 0

    #Disables live tiles
    Write-Output "Disabling live tiles"
    $Live = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
    If (!(Test-Path $Live)) {
        New-Item $Live
    }
    Set-ItemProperty $Live  NoTileApplicationNotification -Value 1

    #Turns off Data Collection via the AllowTelemtry key by changing it to 0
    Write-Output "Turning off Data Collection"
    $DataCollection1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    $DataCollection2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    $DataCollection3 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    If (Test-Path $DataCollection1) {
        Set-ItemProperty $DataCollection1  AllowTelemetry -Value 0
    }
    If (Test-Path $DataCollection2) {
        Set-ItemProperty $DataCollection2  AllowTelemetry -Value 0
    }
    If (Test-Path $DataCollection3) {
        Set-ItemProperty $DataCollection3  AllowTelemetry -Value 0
    }

    #Disabling Location Tracking
    Write-Output "Disabling Location Tracking"
    $SensorState = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"
    $LocationConfig = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"
    If (!(Test-Path $SensorState)) {
        New-Item $SensorState
    }
    Set-ItemProperty $SensorState SensorPermissionState -Value 0
    If (!(Test-Path $LocationConfig)) {
        New-Item $LocationConfig
    }
    Set-ItemProperty $LocationConfig Status -Value 0

    #Disables People icon on Taskbar
    Write-Output "Disabling People icon on Taskbar"
    $People = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People'
    If (Test-Path $People) {
        Set-ItemProperty $People -Name PeopleBand -Value 0
    }

    #Disables scheduled tasks that are considered unnecessary
    Write-Output "Disabling scheduled tasks"
    Get-ScheduledTask  XblGameSaveTaskLogon | Disable-ScheduledTask
    Get-ScheduledTask  XblGameSaveTask | Disable-ScheduledTask
    Get-ScheduledTask  Consolidator | Disable-ScheduledTask
    Get-ScheduledTask  UsbCeip | Disable-ScheduledTask
    Get-ScheduledTask  DmClient | Disable-ScheduledTask
    Get-ScheduledTask  DmClientOnScenarioDownload | Disable-ScheduledTask

    Write-Output "Stopping and disabling Diagnostics Tracking Service"
    #Disabling the Diagnostics Tracking Service
    Stop-Service "DiagTrack"
    Set-Service "DiagTrack" -StartupType Disabled


    Write-Output "Removing CloudStore from registry if it exists"
    $CloudStore = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore'
    If (Test-Path $CloudStore) {
        Stop-Process Explorer.exe -Force
        Remove-Item $CloudStore -Recurse -Force
        Start-Process Explorer.exe -Wait
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function DisableCortana {
    Write-Host "Disabling Cortana"
    $Cortana1 = "HKCU:\SOFTWARE\Microsoft\Personalization\Settings"
    $Cortana2 = "HKCU:\SOFTWARE\Microsoft\InputPersonalization"
    $Cortana3 = "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"
    If (!(Test-Path $Cortana1)) {
        New-Item $Cortana1
    }
    Set-ItemProperty $Cortana1 AcceptedPrivacyPolicy -Value 0
    If (!(Test-Path $Cortana2)) {
        New-Item $Cortana2
    }
    Set-ItemProperty $Cortana2 RestrictImplicitTextCollection -Value 1
    Set-ItemProperty $Cortana2 RestrictImplicitInkCollection -Value 1
    If (!(Test-Path $Cortana3)) {
        New-Item $Cortana3
    }
    Set-ItemProperty $Cortana3 HarvestContacts -Value 0

}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function EnableCortana {
    Write-Host "Re-enabling Cortana"
    $Cortana1 = "HKCU:\SOFTWARE\Microsoft\Personalization\Settings"
    $Cortana2 = "HKCU:\SOFTWARE\Microsoft\InputPersonalization"
    $Cortana3 = "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"
    If (!(Test-Path $Cortana1)) {
        New-Item $Cortana1
    }
    Set-ItemProperty $Cortana1 AcceptedPrivacyPolicy -Value 1
    If (!(Test-Path $Cortana2)) {
        New-Item $Cortana2
    }
    Set-ItemProperty $Cortana2 RestrictImplicitTextCollection -Value 0
    Set-ItemProperty $Cortana2 RestrictImplicitInkCollection -Value 0
    If (!(Test-Path $Cortana3)) {
        New-Item $Cortana3
    }
    Set-ItemProperty $Cortana3 HarvestContacts -Value 1
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function Stop-EdgePDF {

    #Stops edge from taking over as the default .PDF viewer
    Write-Output "Stopping Edge from taking over as the default .PDF viewer"
    $NoPDF = "HKCR:\.pdf"
    $NoProgids = "HKCR:\.pdf\OpenWithProgids"
    $NoWithList = "HKCR:\.pdf\OpenWithList"
    If (!(Get-ItemProperty $NoPDF  NoOpenWith)) {
        New-ItemProperty $NoPDF NoOpenWith
    }
    If (!(Get-ItemProperty $NoPDF  NoStaticDefaultVerb)) {
        New-ItemProperty $NoPDF  NoStaticDefaultVerb
    }
    If (!(Get-ItemProperty $NoProgids  NoOpenWith)) {
        New-ItemProperty $NoProgids  NoOpenWith
    }
    If (!(Get-ItemProperty $NoProgids  NoStaticDefaultVerb)) {
        New-ItemProperty $NoProgids  NoStaticDefaultVerb
    }
    If (!(Get-ItemProperty $NoWithList  NoOpenWith)) {
        New-ItemProperty $NoWithList  NoOpenWith
    }
    If (!(Get-ItemProperty $NoWithList  NoStaticDefaultVerb)) {
        New-ItemProperty $NoWithList  NoStaticDefaultVerb
    }

    #Appends an underscore '_' to the Registry key for Edge
    $Edge = "HKCR:\AppXd4nrz8ff68srnhf9t5a8sbjyar1cr723_"
    If (Test-Path $Edge) {
        Set-Item $Edge AppXd4nrz8ff68srnhf9t5a8sbjyar1cr723_
    }
}

Function Restore-BloatwareChange {
    <#
    .SYNOPSIS
        Revert debloat changes - reinstall removed apps and restore settings
    .DESCRIPTION
        This function will revert the changes made by Start-Debloat function.
        Compatible with Windows 8+ for AppX, registry changes work on all versions.
    #>

    # Reinstall all AppX packages (Windows 8+ only)
    if (Test-AppxSupport) {
        Write-Output "Reinstalling AppX packages..."
        Get-AppxPackageSafe -AllUsers | ForEach-Object {
            if ($_.InstallLocation) {
                Add-AppxPackageSafe -Register "$($_.InstallLocation)\AppXManifest.xml" -DisableDevelopmentMode
            }
        }
    }

    #Tells Windows to enable your advertising information.
    Write-Output "Re-enabling key to show advertisement information"
    $Advertising = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    If (Test-Path $Advertising) {
        Set-ItemProperty $Advertising  Enabled -Value 1
    }

    #Enables Cortana to be used as part of your Windows Search Function
    Write-Output "Re-enabling Cortana to be used in your Windows Search"
    $Search = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    If (Test-Path $Search) {
        Set-ItemProperty $Search  AllowCortana -Value 1
    }

    #Re-enables the Windows Feedback Experience for sending anonymous data
    Write-Output "Re-enabling Windows Feedback Experience"
    $Period = "HKCU:\Software\Microsoft\Siuf\Rules"
    If (!(Test-Path $Period)) {
        New-Item $Period
    }
    Set-ItemProperty $Period PeriodInNanoSeconds -Value 1

    #Enables bloatware applications
    Write-Output "Adding Registry key to allow bloatware apps to return"
    $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    If (!(Test-Path $registryPath)) {
        New-Item $registryPath
    }
    Set-ItemProperty $registryPath  DisableWindowsConsumerFeatures -Value 0

    #Changes Mixed Reality Portal Key 'FirstRunSucceeded' to 1
    Write-Output "Setting Mixed Reality Portal value to 1"
    $Holo = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Holographic"
    If (Test-Path $Holo) {
        Set-ItemProperty $Holo  FirstRunSucceeded -Value 1
    }

    #Re-enables live tiles
    Write-Output "Enabling live tiles"
    $Live = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
    If (!(Test-Path $Live)) {
        New-Item $Live
    }
    Set-ItemProperty $Live  NoTileApplicationNotification -Value 0

    #Re-enables data collection
    Write-Output "Re-enabling data collection"
    $DataCollection = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    If (!(Test-Path $DataCollection)) {
        New-Item $DataCollection
    }
    Set-ItemProperty $DataCollection  AllowTelemetry -Value 1

    #Re-enables People Icon on Taskbar
    Write-Output "Enabling People icon on Taskbar"
    $People = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People"
    If (!(Test-Path $People)) {
        New-Item $People
    }
    Set-ItemProperty $People  PeopleBand -Value 1

    #Re-enables suggestions on start menu
    Write-Output "Enabling suggestions on the Start Menu"
    $Suggestions = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    If (!(Test-Path $Suggestions)) {
        New-Item $Suggestions
    }
    Set-ItemProperty $Suggestions  SystemPaneSuggestionsEnabled -Value 1

    #Re-enables scheduled tasks that were disabled when running the Debloat switch
    Write-Output "Enabling scheduled tasks that were disabled"
    Get-ScheduledTask XblGameSaveTaskLogon | Enable-ScheduledTask
    Get-ScheduledTask  XblGameSaveTask | Enable-ScheduledTask
    Get-ScheduledTask  Consolidator | Enable-ScheduledTask
    Get-ScheduledTask  UsbCeip | Enable-ScheduledTask
    Get-ScheduledTask  DmClient | Enable-ScheduledTask
    Get-ScheduledTask  DmClientOnScenarioDownload | Enable-ScheduledTask

    Write-Output "Re-enabling and starting WAP Push Service"
    #Enable and start WAP Push Service
    Set-Service "dmwappushservice" -StartupType Automatic
    Start-Service "dmwappushservice"

    Write-Output "Re-enabling and starting the Diagnostics Tracking Service"
    #Enabling the Diagnostics Tracking Service
    Set-Service "DiagTrack" -StartupType Automatic
    Start-Service "DiagTrack"

    Write-Output "Restoring 3D Objects in the 'My Computer' submenu in explorer"
    #Restoring 3D Objects in the 'My Computer' submenu in explorer
    Restore3dObjects
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Debloat
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
Function CheckDMWService {

    Param([switch]$Debloat)

    If (Get-Service -Name dmwappushservice | Where-Object {$_.StartType -eq "Disabled"}) {
        Set-Service -Name dmwappushservice -StartupType Automatic
    }

    If (Get-Service -Name dmwappushservice | Where-Object {$_.Status -eq "Stopped"}) {
        Start-Service -Name dmwappushservice
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function Enable-EdgePDF {
    Write-Output "Setting Edge back to default"
    $NoPDF = "HKCR:\.pdf"
    $NoProgids = "HKCR:\.pdf\OpenWithProgids"
    $NoWithList = "HKCR:\.pdf\OpenWithList"
    #Sets edge back to default
    If (Get-ItemProperty $NoPDF  NoOpenWith) {
        Remove-ItemProperty $NoPDF  NoOpenWith
    }
    If (Get-ItemProperty $NoPDF  NoStaticDefaultVerb) {
        Remove-ItemProperty $NoPDF  NoStaticDefaultVerb
    }
    If (Get-ItemProperty $NoProgids  NoOpenWith) {
        Remove-ItemProperty $NoProgids  NoOpenWith
    }
    If (Get-ItemProperty $NoProgids  NoStaticDefaultVerb) {
        Remove-ItemProperty $NoProgids  NoStaticDefaultVerb
    }
    If (Get-ItemProperty $NoWithList  NoOpenWith) {
        Remove-ItemProperty $NoWithList  NoOpenWith
    }
    If (Get-ItemProperty $NoWithList  NoStaticDefaultVerb) {
        Remove-ItemProperty $NoWithList  NoStaticDefaultVerb
    }

    #Removes an underscore '_' from the Registry key for Edge
    $Edge2 = "HKCR:\AppXd4nrz8ff68srnhf9t5a8sbjyar1cr723_"
    If (Test-Path $Edge2) {
        Set-Item $Edge2 AppXd4nrz8ff68srnhf9t5a8sbjyar1cr723
    }
}

Function FixWhitelistedApps {
    <#
    .SYNOPSIS
        Reinstall essential Windows apps that may have been removed
    .DESCRIPTION
        Reinstalls Paint3D, Calculator, Store, and Photos if missing.
        Only works on Windows 8+ where AppX is available.
    #>

    if (-not (Test-AppxSupport)) { return }

    $essentialApps = @(
        'Microsoft.Paint3D',
        'Microsoft.WindowsCalculator',
        'Microsoft.WindowsStore',
        'Microsoft.Windows.Photos'
    )

    foreach ($appName in $essentialApps) {
        $app = Get-AppxPackageSafe -Name $appName -AllUsers
        if ($app -and $app.InstallLocation) {
            Add-AppxPackageSafe -Register "$($app.InstallLocation)\AppXManifest.xml" -DisableDevelopmentMode
        }
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function UninstallOneDrive {

    Write-Host "Checking for pre-existing files and folders located in the OneDrive folders..."
    Start-Sleep 1
    If (Test-Path "$env:USERPROFILE\OneDrive\*") {
        Write-Host "Files found within the OneDrive folder! Checking to see if a folder named OneDriveBackupFiles exists."
        Start-Sleep 1

        If (Test-Path "$env:USERPROFILE\Desktop\OneDriveBackupFiles") {
            Write-Host "A folder named OneDriveBackupFiles already exists on your desktop. All files from your OneDrive location will be moved to that folder."
        }
        else {
            If (!(Test-Path "$env:USERPROFILE\Desktop\OneDriveBackupFiles")) {
                Write-Host "A folder named OneDriveBackupFiles will be created and will be located on your desktop. All files from your OneDrive location will be located in that folder."
                New-item -Path "$env:USERPROFILE\Desktop" -Name "OneDriveBackupFiles"-ItemType Directory -Force
                Write-Host "Successfully created the folder 'OneDriveBackupFiles' on your desktop."
            }
        }
        Start-Sleep 1
        Move-Item -Path "$env:USERPROFILE\OneDrive\*" -Destination "$env:USERPROFILE\Desktop\OneDriveBackupFiles" -Force
        Write-Host "Successfully moved all files/folders from your OneDrive folder to the folder 'OneDriveBackupFiles' on your desktop."
        Start-Sleep 1
        Write-Host "Proceeding with the removal of OneDrive."
        Start-Sleep 1
    }
    Else {
        Write-Host "Either the OneDrive folder does not exist or there are no files to be found in the folder. Proceeding with removal of OneDrive."
        Start-Sleep 1
        Write-Host "Enabling the Group Policy 'Prevent the usage of OneDrive for File Storage'."
        $OneDriveKey = 'HKLM:Software\Policies\Microsoft\Windows\OneDrive'
        If (!(Test-Path $OneDriveKey)) {
            Mkdir $OneDriveKey
            Set-ItemProperty $OneDriveKey -Name OneDrive -Value DisableFileSyncNGSC
        }
        Set-ItemProperty $OneDriveKey -Name OneDrive -Value DisableFileSyncNGSC
    }

    Write-Host "Uninstalling OneDrive. Please wait..."


    New-PSDrive  HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
    $onedrive = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
    $ExplorerReg1 = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    $ExplorerReg2 = "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    Stop-Process -Name "OneDrive*"
    Start-Sleep 2
    If (!(Test-Path $onedrive)) {
        $onedrive = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"

        New-PSDrive  HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
        $onedrive = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
        $ExplorerReg1 = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
        $ExplorerReg2 = "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
        Stop-Process -Name "OneDrive*"
        Start-Sleep 2
        If (!(Test-Path $onedrive)) {
            $onedrive = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
        }
        Start-Process $onedrive "/uninstall" -NoNewWindow -Wait
        Start-Sleep 2
        Write-Output "Stopping explorer"
        Start-Sleep 1
        taskkill.exe /F /IM explorer.exe
        Start-Sleep 3
        Write-Output "Removing leftover files"
        Remove-Item "$env:USERPROFILE\OneDrive" -Force -Recurse
        Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Force -Recurse
        Remove-Item "$env:PROGRAMDATA\Microsoft OneDrive" -Force -Recurse
        If (Test-Path "$env:SYSTEMDRIVE\OneDriveTemp") {
            Remove-Item "$env:SYSTEMDRIVE\OneDriveTemp" -Force -Recurse
        }
        Write-Output "Removing OneDrive from windows explorer"
        If (!(Test-Path $ExplorerReg1)) {
            New-Item $ExplorerReg1
        }
        Set-ItemProperty $ExplorerReg1 System.IsPinnedToNameSpaceTree -Value 0
        If (!(Test-Path $ExplorerReg2)) {
            New-Item $ExplorerReg2
        }
        Set-ItemProperty $ExplorerReg2 System.IsPinnedToNameSpaceTree -Value 0
        Write-Output "Restarting Explorer that was shut down before."
        Start-Process explorer.exe -NoNewWindow

        Write-Host "Enabling the Group Policy 'Prevent the usage of OneDrive for File Storage'."
        $OneDriveKey = 'HKLM:Software\Policies\Microsoft\Windows\OneDrive'
        If (!(Test-Path $OneDriveKey)) {
            Mkdir $OneDriveKey
        }
        Start-Process $onedrive "/uninstall" -NoNewWindow -Wait
        Start-Sleep 2
        Write-Host "Stopping explorer"
        Start-Sleep 1
        taskkill.exe /F /IM explorer.exe
        Start-Sleep 3
        Write-Host "Removing leftover files"
        If (Test-Path "$env:USERPROFILE\OneDrive") {
            Remove-Item "$env:USERPROFILE\OneDrive" -Force -Recurse
        }
        If (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive") {
            Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Force -Recurse
        }
        If (Test-Path "$env:PROGRAMDATA\Microsoft OneDrive") {
            Remove-Item "$env:PROGRAMDATA\Microsoft OneDrive" -Force -Recurse
        }
        If (Test-Path "$env:SYSTEMDRIVE\OneDriveTemp") {
            Remove-Item "$env:SYSTEMDRIVE\OneDriveTemp" -Force -Recurse
        }
        Write-Host "Removing OneDrive from windows explorer"
        If (!(Test-Path $ExplorerReg1)) {
            New-Item $ExplorerReg1
        }
        Set-ItemProperty $ExplorerReg1 System.IsPinnedToNameSpaceTree -Value 0
        If (!(Test-Path $ExplorerReg2)) {
            New-Item $ExplorerReg2
        }
        Set-ItemProperty $ExplorerReg2 System.IsPinnedToNameSpaceTree -Value 0
        Write-Host "Restarting Explorer that was shut down before."
        Start-Process explorer.exe -NoNewWindow
        Write-Host "OneDrive has been successfully uninstalled!"

        Remove-item env:OneDrive
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function UnpinStart {
    # https://superuser.com/a/1442733
    # Note: Requires admin - main script handles this via #Requires -RunAsAdministrator

$START_MENU_LAYOUT = @"
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
    <LayoutOptions StartTileGroupCellWidth="6" />
    <DefaultLayoutOverride>
        <StartLayoutCollection>
            <defaultlayout:StartLayout GroupCellWidth="6" />
        </StartLayoutCollection>
    </DefaultLayoutOverride>
</LayoutModificationTemplate>
"@

    $layoutFile="C:\Windows\StartMenuLayout.xml"

    #Delete layout file if it already exists
    If(Test-Path $layoutFile)
    {
        Remove-Item $layoutFile
    }

    #Creates the blank layout file
    $START_MENU_LAYOUT | Out-File $layoutFile -Encoding ASCII

    $regAliases = @("HKLM", "HKCU")

    #Assign the start layout and force it to apply with "LockedStartLayout" at both the machine and user level
    foreach ($regAlias in $regAliases){
        $basePath = $regAlias + ":\SOFTWARE\Policies\Microsoft\Windows"
        $keyPath = $basePath + "\Explorer"
        IF(!(Test-Path -Path $keyPath)) {
            New-Item -Path $basePath -Name "Explorer"
        }
        Set-ItemProperty -Path $keyPath -Name "LockedStartLayout" -Value 1
        Set-ItemProperty -Path $keyPath -Name "StartLayoutFile" -Value $layoutFile
    }

    #Restart Explorer, open the start menu (necessary to load the new layout), and give it a few seconds to process
    Stop-Process -name explorer
    Start-Sleep -s 5
    $wshell = New-Object -ComObject wscript.shell; $wshell.SendKeys('^{ESCAPE}')
    Start-Sleep -s 5

    #Enable the ability to pin items again by disabling "LockedStartLayout"
    foreach ($regAlias in $regAliases){
        $basePath = $regAlias + ":\SOFTWARE\Policies\Microsoft\Windows"
        $keyPath = $basePath + "\Explorer"
        Set-ItemProperty -Path $keyPath -Name "LockedStartLayout" -Value 0
    }

    #Restart Explorer and delete the layout file
    Stop-Process -name explorer

    # Uncomment the next line to make clean start menu default for all new users
    #Import-StartLayout -LayoutPath $layoutFile -MountPath $env:SystemDrive\

    Remove-Item $layoutFile
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function Remove3dObjects {
    #Removes 3D Objects from the 'My Computer' submenu in explorer
    Write-Host "Removing 3D Objects from explorer 'My Computer' submenu"
    $Objects32 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
    $Objects64 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
    If (Test-Path $Objects32) {
        Remove-Item $Objects32 -Recurse
    }
    If (Test-Path $Objects64) {
        Remove-Item $Objects64 -Recurse
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
General notes
#>
Function Restore3dObjects {
    #Restores 3D Objects from the 'My Computer' submenu in explorer
    Write-Host "Restoring 3D Objects from explorer 'My Computer' submenu"
    $Objects32 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
    $Objects64 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
    If (!(Test-Path $Objects32)) {
        New-Item $Objects32
    }
    If (!(Test-Path $Objects64)) {
        New-Item $Objects64
    }
}

#Function DisableLastUsedFilesAndFolders {
#	Write-Host = "Disable Explorer to show last used files and folders."
#	Invoke-Item (start powershell ((Split-Path $MyInvocation.InvocationName) + "\Individual Scripts\Disable Last Used Files and Folders View.ps1"))
#}


# ============================================================================
# MODULE EXPORTS
# ============================================================================
Export-ModuleMember -Function @(
    # Compatibility helpers
    'Test-AppxSupport',
    'Get-AppxPackageSafe',
    'Remove-AppxPackageSafe',
    'Add-AppxPackageSafe',
    # Debloat functions
    'DebloatAll',
    'DebloatBlacklist',
    'Remove-Key',
    'Protect-Privacy',
    'DisableCortana',
    'EnableCortana',
    'Stop-EdgePDF',
    'Restore-BloatwareChange',  # Renamed from Revert-Changes (approved verb)
    'CheckDMWService',
    'Enable-EdgePDF',
    'FixWhitelistedApps',
    'UninstallOneDrive',
    'UnpinStart',
    'Remove3dObjects',
    'Restore3dObjects'
)
