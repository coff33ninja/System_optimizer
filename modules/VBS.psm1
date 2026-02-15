#Requires -Version 5.1
<#
.SYNOPSIS
    VBS Module - System Optimizer
.DESCRIPTION
    Provides Virtualization-Based Security (VBS) and Memory Integrity control.
    Disables security features that impact gaming performance.

Exported Functions:
    Disable-VBS   - Disable VBS, Memory Integrity, and Credential Guard
    Enable-VBS    - Re-enable VBS security features

Features Disabled:
    - Core Isolation / Memory Integrity (HVCI)
    - Credential Guard
    - Hypervisor-protected Code Integrity

Warning:
    Improves gaming performance but reduces system security.
    Only recommended for dedicated gaming systems.

Registry Areas:
    - HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard
    - HKLM:\SYSTEM\CurrentControlSet\Control\Lsa

Requires Admin: Yes
Requires Reboot: Yes

Version: 1.0.0
#>

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

# Export functions
Export-ModuleMember -Function @(
    'Disable-VBS'
)
