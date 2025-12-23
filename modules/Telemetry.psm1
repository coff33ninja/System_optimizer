# ============================================================================
# Telemetry Module - System Optimizer
# ============================================================================

function Disable-Telemetry {
    Write-Log "DISABLING TELEMETRY & PRIVACY TWEAKS" "SECTION"

    # Use progress tracking if available
    $hasProgress = Get-Command 'Start-ProgressOperation' -ErrorAction SilentlyContinue
    $tweakCount = 25  # Total number of tweaks
    if ($hasProgress) {
        Start-ProgressOperation -Name "Disabling Telemetry & Privacy Tweaks" -TotalItems $tweakCount
    }

    # Helper function for progress updates
    function Update-TelemetryProgress {
        param([string]$Name, [string]$Status = 'Success', [string]$Message = "")
        if ($hasProgress) {
            Update-ProgressItem -ItemName $Name -Status $Status -Message $Message
        } else {
            Write-Log "$Name" "SUCCESS"
        }
    }

    # Disable Advertising ID
    try {
        $AdvPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        if (-not (Test-Path $AdvPath)) { New-Item -Path $AdvPath -Force | Out-Null }
        Set-ItemProperty -Path $AdvPath -Name "Enabled" -Value 0 -Type DWord -Force
        Update-TelemetryProgress -Name "Advertising ID"
    } catch { Update-TelemetryProgress -Name "Advertising ID" -Status 'Failed' -Message $_.Exception.Message }

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




function Block-TelemetryDomains {
    <#
    .SYNOPSIS
    Blocks telemetry domains via hosts file and firewall rules
    .DESCRIPTION
    Adds telemetry-related domains to the hosts file and blocks IPs via Windows Firewall.
    Adapted from Debloat-Windows-10 and SharpApp projects.
    #>

    Write-Log "BLOCKING TELEMETRY DOMAINS" "SECTION"

#   Description:
# This script blocks telemetry related domains via the hosts file and related
# IPs via Windows Firewall.
#
# Please note that adding these domains may break certain software like iTunes
# or Skype. As this issue is location dependent for some domains, they are not
# commented by default. The domains known to cause issues marked accordingly.
# Please see the related issue:
# <https://github.com/W4RH4WK/Debloat-Windows-10/issues/79>
# -----------------------------------------------------------------------------
# THIS TOOL HAS BEEN ADAPTED FROM BUILDBYBEL/SharpApp
# Entries related to Akamai have been reported to cause issues with Widevine
# DRM.

Write-Output "Adding telemetry domains to hosts file"
$hosts_file = "$env:systemroot\System32\drivers\etc\hosts"
$domains = @(
    "184-86-53-99.deploy.static.akamaitechnologies.com"
    "a-0001.a-msedge.net"
    "a-0002.a-msedge.net"
    "a-0003.a-msedge.net"
    "a-0004.a-msedge.net"
    "a-0005.a-msedge.net"
    "a-0006.a-msedge.net"
    "a-0007.a-msedge.net"
    "a-0008.a-msedge.net"
    "a-0009.a-msedge.net"
    "a1621.g.akamai.net"
    "a1856.g2.akamai.net"
    "a1961.g.akamai.net"
    #"a248.e.akamai.net"            # makes iTunes download button disappear (#43)
    "a978.i6g1.akamai.net"
    "a.ads1.msn.com"
    "a.ads2.msads.net"
    "a.ads2.msn.com"
    "ac3.msn.com"
    "ad.doubleclick.net"
    "adnexus.net"
    "adnxs.com"
    "ads1.msads.net"
    "ads1.msn.com"
    "ads.msn.com"
    "aidps.atdmt.com"
    "aka-cdn-ns.adtech.de"
    "a-msedge.net"
    "any.edge.bing.com"
    "a.rad.msn.com"
    "az361816.vo.msecnd.net"
    "az512334.vo.msecnd.net"
    "b.ads1.msn.com"
    "b.ads2.msads.net"
    "bingads.microsoft.com"
    "b.rad.msn.com"
    "bs.serving-sys.com"
    "c.atdmt.com"
    "cdn.atdmt.com"
    "cds26.ams9.msecn.net"
    "choice.microsoft.com"
    "choice.microsoft.com.nsatc.net"
    "compatexchange.cloudapp.net"
    "corpext.msitadfs.glbdns2.microsoft.com"
    "corp.sts.microsoft.com"
    "cs1.wpc.v0cdn.net"
    "db3aqu.atdmt.com"
    "df.telemetry.microsoft.com"
    "diagnostics.support.microsoft.com"
    "e2835.dspb.akamaiedge.net"
    "e7341.g.akamaiedge.net"
    "e7502.ce.akamaiedge.net"
    "e8218.ce.akamaiedge.net"
    "ec.atdmt.com"
    "fe2.update.microsoft.com.akadns.net"
    "feedback.microsoft-hohm.com"
    "feedback.search.microsoft.com"
    "feedback.windows.com"
    "flex.msn.com"
    "g.msn.com"
    "h1.msn.com"
    "h2.msn.com"
    "hostedocsp.globalsign.com"
    "i1.services.social.microsoft.com"
    "i1.services.social.microsoft.com.nsatc.net"
    #"ipv6.msftncsi.com"                    # Issues may arise where Windows 10 thinks it doesn't have internet
    #"ipv6.msftncsi.com.edgesuite.net"      # Issues may arise where Windows 10 thinks it doesn't have internet
    "lb1.www.ms.akadns.net"
    "live.rads.msn.com"
    "m.adnxs.com"
    "msedge.net"
    #"msftncsi.com"
    "msnbot-65-55-108-23.search.msn.com"
    "msntest.serving-sys.com"
    "oca.telemetry.microsoft.com"
    "oca.telemetry.microsoft.com.nsatc.net"
    "onesettings-db5.metron.live.nsatc.net"
    "pre.footprintpredict.com"
    "preview.msn.com"
    "rad.live.com"
    "rad.msn.com"
    "redir.metaservices.microsoft.com"
    "reports.wes.df.telemetry.microsoft.com"
    "schemas.microsoft.akadns.net"
    "secure.adnxs.com"
    "secure.flashtalking.com"
    "services.wes.df.telemetry.microsoft.com"
    "settings-sandbox.data.microsoft.com"
    #"settings-win.data.microsoft.com"       # may cause issues with Windows Updates
    "sls.update.microsoft.com.akadns.net"
    #"sls.update.microsoft.com.nsatc.net"    # may cause issues with Windows Updates
    "sqm.df.telemetry.microsoft.com"
    "sqm.telemetry.microsoft.com"
    "sqm.telemetry.microsoft.com.nsatc.net"
    "ssw.live.com"
    "static.2mdn.net"
    "statsfe1.ws.microsoft.com"
    "statsfe2.update.microsoft.com.akadns.net"
    "statsfe2.ws.microsoft.com"
    "survey.watson.microsoft.com"
    "telecommand.telemetry.microsoft.com"
    "telecommand.telemetry.microsoft.com.nsatc.net"
    "telemetry.appex.bing.net"
    "telemetry.microsoft.com"
    "telemetry.urs.microsoft.com"
    "vortex-bn2.metron.live.com.nsatc.net"
    "vortex-cy2.metron.live.com.nsatc.net"
    "vortex.data.microsoft.com"
    "vortex-sandbox.data.microsoft.com"
    "vortex-win.data.microsoft.com"
    "cy2.vortex.data.microsoft.com.akadns.net"
    "watson.live.com"
    "watson.microsoft.com"
    "watson.ppe.telemetry.microsoft.com"
    "watson.telemetry.microsoft.com"
    "watson.telemetry.microsoft.com.nsatc.net"
    "wes.df.telemetry.microsoft.com"
    "win10.ipv6.microsoft.com"
    "www.bingads.microsoft.com"
    "www.go.microsoft.akadns.net"
    #"www.msftncsi.com"                         # Issues may arise where Windows 10 thinks it doesn't have internet
    "client.wns.windows.com"
    #"wdcp.microsoft.com"                       # may cause issues with Windows Defender Cloud-based protection
    #"dns.msftncsi.com"                         # This causes Windows to think it doesn't have internet
    #"storeedgefd.dsx.mp.microsoft.com"         # breaks Windows Store
    "wdcpalt.microsoft.com"
    "settings-ssl.xboxlive.com"
    "settings-ssl.xboxlive.com-c.edgekey.net"
    "settings-ssl.xboxlive.com-c.edgekey.net.globalredir.akadns.net"
    "e87.dspb.akamaidege.net"
    "insiderservice.microsoft.com"
    "insiderservice.trafficmanager.net"
    "e3843.g.akamaiedge.net"
    "flightingserviceweurope.cloudapp.net"
    #"sls.update.microsoft.com"                 # may cause issues with Windows Updates
    "static.ads-twitter.com"                    # may cause issues with Twitter login
    "www-google-analytics.l.google.com"
    "p.static.ads-twitter.com"                  # may cause issues with Twitter login
    "hubspot.net.edge.net"
    "e9483.a.akamaiedge.net"

    #"www.google-analytics.com"
    #"padgead2.googlesyndication.com"
    #"mirror1.malwaredomains.com"
    #"mirror.cedia.org.ec"
    "stats.g.doubleclick.net"
    "stats.l.doubleclick.net"
    "adservice.google.de"
    "adservice.google.com"
    "googleads.g.doubleclick.net"
    "pagead46.l.doubleclick.net"
    "hubspot.net.edgekey.net"
    "insiderppe.cloudapp.net"                   # Feedback-Hub
    "livetileedge.dsx.mp.microsoft.com"

    # extra
    "fe2.update.microsoft.com.akadns.net"
    "s0.2mdn.net"
    "statsfe2.update.microsoft.com.akadns.net"
    "survey.watson.microsoft.com"
    "view.atdmt.com"
    "watson.microsoft.com"
    "watson.ppe.telemetry.microsoft.com"
    "watson.telemetry.microsoft.com"
    "watson.telemetry.microsoft.com.nsatc.net"
    "wes.df.telemetry.microsoft.com"
    "m.hotmail.com"

    # can cause issues with Skype (#79) or other services (#171)
    "apps.skype.com"
    "c.msn.com"
    # "login.live.com"                  # prevents login to outlook and other live apps
    "pricelist.skype.com"
    "s.gateway.messenger.live.com"
    "ui.skype.com"
)
Write-Output "" | Out-File -Encoding ASCII -Append $hosts_file
foreach ($domain in $domains) {
    if (-Not (Select-String -Path $hosts_file -Pattern $domain)) {
        Write-Output "0.0.0.0 $domain" | Out-File -Encoding ASCII -Append $hosts_file
    }
}

Write-Output "Adding telemetry ips to firewall"
$ips = @(
    # Windows telemetry
    "134.170.30.202"
    "137.116.81.24"
    "157.56.106.189"
    "184.86.53.99"
    "2.22.61.43"
    "2.22.61.66"
    "204.79.197.200"
    "23.218.212.69"
    "65.39.117.230"
    "65.52.108.33"   # Causes problems with Microsoft Store
    "65.55.108.23"
    "64.4.54.254"

    # NVIDIA telemetry
    "8.36.80.197"
    "8.36.80.224"
    "8.36.80.252"
    "8.36.113.118"
    "8.36.113.141"
    "8.36.80.230"
    "8.36.80.231"
    "8.36.113.126"
    "8.36.80.195"
    "8.36.80.217"
    "8.36.80.237"
    "8.36.80.246"
    "8.36.113.116"
    "8.36.113.139"
    "8.36.80.244"
    "216.228.121.209"
)
Remove-NetFirewallRule -DisplayName "Block Telemetry IPs" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Block Telemetry IPs" -Direction Outbound `
    -Action Block -RemoteAddress ([string[]]$ips)


    Write-Log "Telemetry domains blocked" "SUCCESS"
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================
Export-ModuleMember -Function @(
    'Disable-Telemetry',
    'Block-TelemetryDomains'
)
