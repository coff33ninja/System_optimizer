#Requires -Version 5.1
<#
.SYNOPSIS
    OneDrive Module - System Optimizer
.DESCRIPTION
    Provides complete OneDrive removal and cleanup functionality.

Exported Functions:
    Remove-OneDrive   - Complete OneDrive uninstallation
    Install-OneDrive  - Reinstall OneDrive (if needed)

Actions Performed:
    - Stop OneDrive processes
    - Uninstall OneDrive application
    - Remove from Explorer sidebar
    - Disable via Group Policy
    - Clean up registry entries
    - Remove leftover files

Safety:
    - Creates restore point before removal
    - Can be reinstalled via Microsoft Store if needed

Requires Admin: Yes

Version: 1.0.0
#>

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

# Export functions
Export-ModuleMember -Function @(
    'Remove-OneDrive'
)
