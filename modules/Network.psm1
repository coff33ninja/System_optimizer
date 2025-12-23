# ============================================================================
# Network Module - System Optimizer
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

# Export functions
Export-ModuleMember -Function @(
    'Set-NetworkOptimizations',
    'Reset-Network'
)
