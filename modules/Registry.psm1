# ============================================================================
# Registry Module - System Optimizer
# ============================================================================

function Set-RegistryOptimizations {
    Write-Log "APPLYING REGISTRY OPTIMIZATIONS" "SECTION"

    # Use progress tracking if available
    $hasProgress = Get-Command 'Start-ProgressOperation' -ErrorAction SilentlyContinue
    $tweakCount = 20  # Total number of registry tweaks
    if ($hasProgress) {
        Start-ProgressOperation -Name "Applying Registry Optimizations" -TotalItems $tweakCount
    }

    # Helper function for progress updates
    function Update-RegProgress {
        param([string]$Name, [string]$Status = 'Success', [string]$Message = "")
        if ($hasProgress) {
            Update-ProgressItem -ItemName $Name -Status $Status -Message $Message
        } else {
            Write-Log "$Name" "SUCCESS"
        }
    }

    # Disable Game Bar/DVR
    try {
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
        Update-RegProgress -Name "Game Bar/DVR"
    } catch { Update-RegProgress -Name "Game Bar/DVR" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Background Apps
    try {
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BackgroundAppGlobalToggle" -Value 0 -Type DWord -Force
        Update-RegProgress -Name "Background Apps"
    } catch { Update-RegProgress -Name "Background Apps" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Transparency Effects
    try {
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force
        Update-RegProgress -Name "Transparency Effects"
    } catch { Update-RegProgress -Name "Transparency Effects" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Animations
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force
        Update-RegProgress -Name "Animations"
    } catch { Update-RegProgress -Name "Animations" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Startup Delay
    try {
        $Serialize = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        if (-not (Test-Path $Serialize)) { New-Item -Path $Serialize -Force | Out-Null }
        Set-ItemProperty -Path $Serialize -Name "StartupDelayInMSec" -Value 0 -Type DWord -Force
        Update-RegProgress -Name "Startup Delay"
    } catch { Update-RegProgress -Name "Startup Delay" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Mouse Acceleration
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Force
        Update-RegProgress -Name "Mouse Acceleration"
    } catch { Update-RegProgress -Name "Mouse Acceleration" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Edge PDF Takeover
    try {
        $NoPDF = "HKCR:\.pdf"
        if (Test-Path $NoPDF) {
            New-ItemProperty -Path $NoPDF -Name "NoOpenWith" -Value "" -Force -ErrorAction SilentlyContinue
            New-ItemProperty -Path $NoPDF -Name "NoStaticDefaultVerb" -Value "" -Force -ErrorAction SilentlyContinue
        }
        Update-RegProgress -Name "Edge PDF Takeover"
    } catch { Update-RegProgress -Name "Edge PDF Takeover" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Hibernation
    try {
        powercfg.exe /hibernate off
        $HibPath = "HKLM:\System\CurrentControlSet\Control\Session Manager\Power"
        Set-ItemProperty -Path $HibPath -Name "HibernateEnabled" -Value 0 -Type DWord -Force
        Update-RegProgress -Name "Hibernation"
    } catch { Update-RegProgress -Name "Hibernation" -Status 'Failed' -Message $_.Exception.Message }

    # ============================================================================
    # ADDITIONAL PERFORMANCE TWEAKS
    # ============================================================================

    # Reduce Menu Show Delay (400ms -> 0ms)
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Force
        Update-RegProgress -Name "Menu Show Delay"
    } catch { Update-RegProgress -Name "Menu Show Delay" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Thumbnail Cache Cleanup
    try {
        $Maintenance = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache"
        if (Test-Path $Maintenance) {
            Set-ItemProperty -Path $Maintenance -Name "Autorun" -Value 0 -Type DWord -Force
        }
        Update-RegProgress -Name "Thumbnail Cache"
    } catch { Update-RegProgress -Name "Thumbnail Cache" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Low Disk Space Warning
    try {
        $Explorer = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        if (-not (Test-Path $Explorer)) { New-Item -Path $Explorer -Force | Out-Null }
        Set-ItemProperty -Path $Explorer -Name "NoLowDiskSpaceChecks" -Value 1 -Type DWord -Force
        Update-RegProgress -Name "Low Disk Warning"
    } catch { Update-RegProgress -Name "Low Disk Warning" -Status 'Failed' -Message $_.Exception.Message }

    # Disable NTFS Last Access Timestamp (SSD optimization)
    try {
        fsutil behavior set disablelastaccess 1 | Out-Null
        Update-RegProgress -Name "NTFS Last Access"
    } catch { Update-RegProgress -Name "NTFS Last Access" -Status 'Failed' -Message $_.Exception.Message }

    # Disable 8.3 Filename Creation (legacy DOS names)
    try {
        fsutil behavior set disable8dot3 1 | Out-Null
        Update-RegProgress -Name "8.3 Filename Creation"
    } catch { Update-RegProgress -Name "8.3 Filename Creation" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Fullscreen Optimizations (FSO) system-wide
    try {
        $GameCompat = "HKCU:\System\GameConfigStore"
        Set-ItemProperty -Path $GameCompat -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord -Force
        Set-ItemProperty -Path $GameCompat -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -Force
        Update-RegProgress -Name "Fullscreen Optimizations"
    } catch { Update-RegProgress -Name "Fullscreen Optimizations" -Status 'Failed' -Message $_.Exception.Message }

    # Enable Hardware GPU Scheduling (Win10 2004+)
    try {
        $GraphicsDrivers = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        Set-ItemProperty -Path $GraphicsDrivers -Name "HwSchMode" -Value 2 -Type DWord -Force
        Update-RegProgress -Name "GPU Scheduling"
    } catch { Update-RegProgress -Name "GPU Scheduling" -Status 'Failed' -Message $_.Exception.Message }

    # Optimize Split Threshold for Memory Management
    try {
        $MemMgmt = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        # SplitThreshold: Optimize for systems with 8GB+ RAM
        $RAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
        if ($RAM -ge 8) {
            Set-ItemProperty -Path $MemMgmt -Name "LargeSystemCache" -Value 1 -Type DWord -Force
        }
        Update-RegProgress -Name "Memory Management"
    } catch { Update-RegProgress -Name "Memory Management" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Prefetch for SSD (if SSD detected)
    try {
        $Prefetch = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
        # Check if system drive is SSD
        $SystemDrive = $env:SystemDrive.TrimEnd(':')
        $DiskNum = (Get-Partition -DriveLetter $SystemDrive -ErrorAction SilentlyContinue).DiskNumber
        $MediaType = (Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq $DiskNum }).MediaType
        if ($MediaType -eq 'SSD') {
            Set-ItemProperty -Path $Prefetch -Name "EnablePrefetcher" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path $Prefetch -Name "EnableSuperfetch" -Value 0 -Type DWord -Force
            Update-RegProgress -Name "Prefetch (SSD)"
        } else {
            Update-RegProgress -Name "Prefetch (SSD)" -Status 'Skipped' -Message "HDD detected"
        }
    } catch { Update-RegProgress -Name "Prefetch (SSD)" -Status 'Skipped' -Message "Could not detect drive type" }

    # Disable Windows Tips and Suggestions
    try {
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353696Enabled" -Value 0 -Type DWord -Force
        Update-RegProgress -Name "Windows Tips"
    } catch { Update-RegProgress -Name "Windows Tips" -Status 'Failed' -Message $_.Exception.Message }

    # Disable Sticky Keys Prompt
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Value "58" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "122" -Force
        Update-RegProgress -Name "Sticky Keys Prompt"
    } catch { Update-RegProgress -Name "Sticky Keys Prompt" -Status 'Failed' -Message $_.Exception.Message }

    # Increase Icon Cache Size
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "Max Cached Icons" -Value "8192" -Force
        Update-RegProgress -Name "Icon Cache Size"
    } catch { Update-RegProgress -Name "Icon Cache Size" -Status 'Failed' -Message $_.Exception.Message }

    if ($hasProgress) {
        Complete-ProgressOperation
    } else {
        Write-Log "Registry optimizations completed" "SUCCESS"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Set-RegistryOptimizations'
)
