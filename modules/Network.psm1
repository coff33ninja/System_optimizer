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

function Get-WiFiNetwork {
    <#
    .SYNOPSIS
        Display and manage Wi-Fi networks
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "WI-FI NETWORK MANAGEMENT" "SECTION"

    Write-Host ""
    Write-Host "  [1] Show saved Wi-Fi networks"
    Write-Host "  [2] Show current Wi-Fi connection"
    Write-Host "  [3] Forget a Wi-Fi network"
    Write-Host "  [4] Show Wi-Fi signal strength"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Retrieving saved Wi-Fi networks..."
            $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
                ($_ -split ":")[1].Trim()
            }
            if ($profiles) {
                Write-Host ""
                Write-Host "  Saved Wi-Fi Networks:" -ForegroundColor Cyan
                $i = 1
                foreach ($wifiProfile in $profiles) {
                    Write-Host "  [$i] $wifiProfile" -ForegroundColor White
                    $i++
                }
            } else {
                Write-Log "No saved Wi-Fi networks found" "WARNING"
            }
        }
        "2" {
            Write-Log "Current Wi-Fi connection:" "SECTION"
            netsh wlan show interfaces | Select-String "Name|SSID|State|Signal|Channel|Authentication" | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Gray
            }
        }
        "3" {
            $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
                ($_ -split ":")[1].Trim()
            }
            if ($profiles) {
                Write-Host ""
                Write-Host "  Select network to forget:" -ForegroundColor Cyan
                $i = 1
                $profileMap = @{}
                foreach ($wifiProfile in $profiles) {
                    Write-Host "  [$i] $wifiProfile" -ForegroundColor White
                    $profileMap[$i] = $wifiProfile
                    $i++
                }
                Write-Host "  [0] Cancel" -ForegroundColor Gray
                Write-Host ""
                $sel = Read-Host "  Select network"
                if ($sel -ne "0" -and $profileMap[[int]$sel]) {
                    $toRemove = $profileMap[[int]$sel]
                    Write-Log "Removing Wi-Fi profile: $toRemove"
                    netsh wlan delete profile name="$toRemove" | Out-Null
                    Write-Log "Profile removed" "SUCCESS"
                }
            }
        }
        "4" {
            Write-Log "Wi-Fi Signal Strength:" "SECTION"
            netsh wlan show interfaces | Select-String "SSID|Signal|Channel|Receive rate|Transmit rate" | ForEach-Object {
                if ($_ -match "Signal\s+:\s+(\d+)%") {
                    $signal = $matches[1]
                    $color = if ([int]$signal -gt 80) { "Green" } elseif ([int]$signal -gt 50) { "Yellow" } else { "Red" }
                    Write-Host "  $_" -ForegroundColor $color
                } else {
                    Write-Host "  $_" -ForegroundColor Gray
                }
            }
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Get-NetworkAdapter {
    <#
    .SYNOPSIS
        Display and manage network adapters
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "NETWORK ADAPTER MANAGEMENT" "SECTION"

    Write-Host ""
    Write-Host "  [1] Show all network adapters"
    Write-Host "  [2] Enable/Disable adapter"
    Write-Host "  [3] Rename adapter"
    Write-Host "  [4] Show adapter statistics"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Network Adapters:" "SECTION"
            Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress | Format-Table -AutoSize
        }
        "2" {
            $adapters = Get-NetAdapter | Where-Object { $_.HardwareInterface -eq $true }
            Write-Host ""
            Write-Host "  Select adapter to toggle:" -ForegroundColor Cyan
            $i = 1
            $adapterMap = @{}
            foreach ($adapter in $adapters) {
                $status = if ($adapter.Status -eq "Up") { "(Enabled)" } else { "(Disabled)" }
                Write-Host "  [$i] $($adapter.Name) $status" -ForegroundColor $(if($adapter.Status -eq "Up"){"Green"}else{"Red"})
                $adapterMap[$i] = $adapter
                $i++
            }
            Write-Host "  [0] Cancel" -ForegroundColor Gray
            Write-Host ""
            $sel = Read-Host "  Select adapter"
            if ($sel -ne "0" -and $adapterMap[[int]$sel]) {
                $selected = $adapterMap[[int]$sel]
                if ($selected.Status -eq "Up") {
                    Write-Log "Disabling $($selected.Name)..."
                    Disable-NetAdapter -Name $selected.Name -Confirm:$false
                    Write-Log "Adapter disabled" "SUCCESS"
                } else {
                    Write-Log "Enabling $($selected.Name)..."
                    Enable-NetAdapter -Name $selected.Name -Confirm:$false
                    Write-Log "Adapter enabled" "SUCCESS"
                }
            }
        }
        "3" {
            $adapters = Get-NetAdapter
            Write-Host ""
            Write-Host "  Select adapter to rename:" -ForegroundColor Cyan
            $i = 1
            $adapterMap = @{}
            foreach ($adapter in $adapters) {
                Write-Host "  [$i] $($adapter.Name)" -ForegroundColor White
                $adapterMap[$i] = $adapter
                $i++
            }
            Write-Host "  [0] Cancel" -ForegroundColor Gray
            Write-Host ""
            $sel = Read-Host "  Select adapter"
            if ($sel -ne "0" -and $adapterMap[[int]$sel]) {
                $selected = $adapterMap[[int]$sel]
                $newName = Read-Host "  Enter new name"
                if ($newName) {
                    Rename-NetAdapter -Name $selected.Name -NewName $newName
                    Write-Log "Adapter renamed to $newName" "SUCCESS"
                }
            }
        }
        "4" {
            Write-Log "Adapter Statistics:" "SECTION"
            Get-NetAdapterStatistics | Select-Object Name, ReceivedBytes, SentBytes, ReceivedUnicastPackets, SentUnicastPackets | Format-Table -AutoSize
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Set-ProxyConfiguration {
    <#
    .SYNOPSIS
        Configure system proxy settings
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "PROXY CONFIGURATION" "SECTION"

    Write-Host ""
    Write-Host "  [1] Show current proxy settings"
    Write-Host "  [2] Set manual proxy"
    Write-Host "  [3] Set automatic configuration (PAC)"
    Write-Host "  [4] Disable proxy"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Current Proxy Settings:" "SECTION"
            $proxy = netsh winhttp show proxy
            Write-Host "  WinHTTP Proxy: $proxy" -ForegroundColor Gray

            $ieProxy = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -ErrorAction SilentlyContinue
            $ieEnable = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -ErrorAction SilentlyContinue
            Write-Host "  IE Proxy Server: $($ieProxy.ProxyServer)" -ForegroundColor Gray
            Write-Host "  IE Proxy Enabled: $($ieEnable.ProxyEnable)" -ForegroundColor Gray
        }
        "2" {
            $proxyServer = Read-Host "  Enter proxy server (e.g., http://proxy.company.com:8080)"
            $bypassList = Read-Host "  Enter bypass list (comma-separated, or leave blank)"
            if ($proxyServer) {
                netsh winhttp set proxy $proxyServer $bypassList | Out-Null
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value $proxyServer -Force
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1 -Force
                Write-Log "Proxy configured" "SUCCESS"
            }
        }
        "3" {
            $pacUrl = Read-Host "  Enter PAC file URL (e.g., http://proxy.company.com/proxy.pac)"
            if ($pacUrl) {
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name AutoConfigURL -Value $pacUrl -Force
                Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name AutoDetect -Value 0 -Force
                Write-Log "PAC configuration set" "SUCCESS"
            }
        }
        "4" {
            netsh winhttp reset proxy | Out-Null
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0 -Force
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name AutoConfigURL -Force -ErrorAction SilentlyContinue
            Write-Log "Proxy disabled" "SUCCESS"
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Edit-HostsFile {
    <#
    .SYNOPSIS
        View and edit hosts file entries
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "HOSTS FILE EDITOR" "SECTION"

    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

    Write-Host ""
    Write-Host "  [1] View hosts file"
    Write-Host "  [2] Add entry"
    Write-Host "  [3] Remove entry"
    Write-Host "  [4] Backup hosts file"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Hosts File Contents:" "SECTION"
            if (Test-Path $hostsPath) {
                Get-Content $hostsPath | ForEach-Object {
                    if ($_ -match "^#" -or $_ -match "^$") {
                        Write-Host "  $_" -ForegroundColor DarkGray
                    } else {
                        Write-Host "  $_" -ForegroundColor White
                    }
                }
            } else {
                Write-Log "Hosts file not found" "ERROR"
            }
        }
        "2" {
            $ip = Read-Host "  Enter IP address"
            $hostname = Read-Host "  Enter hostname"
            if ($ip -and $hostname) {
                Add-Content -Path $hostsPath -Value "$ip $hostname" -Force
                Write-Log "Entry added: $ip $hostname" "SUCCESS"
                Write-Log "Flush DNS to apply changes" "INFO"
            }
        }
        "3" {
            $entries = Get-Content $hostsPath | Where-Object { $_ -notmatch "^#" -and $_ -match "\S" }
            if ($entries) {
                Write-Host ""
                Write-Host "  Select entry to remove:" -ForegroundColor Cyan
                $i = 1
                $entryMap = @{}
                foreach ($entry in $entries) {
                    Write-Host "  [$i] $entry" -ForegroundColor White
                    $entryMap[$i] = $entry
                    $i++
                }
                Write-Host "  [0] Cancel" -ForegroundColor Gray
                Write-Host ""
                $sel = Read-Host "  Select entry"
                if ($sel -ne "0" -and $entryMap[[int]$sel]) {
                    $toRemove = $entryMap[[int]$sel]
                    $content = Get-Content $hostsPath | Where-Object { $_ -ne $toRemove }
                    Set-Content -Path $hostsPath -Value $content -Force
                    Write-Log "Entry removed" "SUCCESS"
                }
            }
        }
        "4" {
            $backupPath = "$env:USERPROFILE\hosts_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            Copy-Item $hostsPath $backupPath -Force
            Write-Log "Hosts file backed up to: $backupPath" "SUCCESS"
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-NetworkDiagnostic {
    <#
    .SYNOPSIS
        Run network diagnostics (ping, traceroute, etc.)
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "NETWORK DIAGNOSTICS" "SECTION"

    Write-Host ""
    Write-Host "  [1] Ping test"
    Write-Host "  [2] Traceroute"
    Write-Host "  [3] PathPing"
    Write-Host "  [4] DNS lookup"
    Write-Host "  [5] Check open ports"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            $target = Read-Host "  Enter target (IP or hostname, default: 8.8.8.8)"
            if (-not $target) { $target = "8.8.8.8" }
            $count = Read-Host "  Number of pings (default: 4)"
            if (-not $count) { $count = 4 }
            Write-Log "Pinging $target..." "SECTION"
            Test-Connection -ComputerName $target -Count $count | Format-Table -AutoSize
        }
        "2" {
            $target = Read-Host "  Enter target (IP or hostname)"
            if ($target) {
                Write-Log "Tracing route to $target..." "SECTION"
                tracert -d $target
            }
        }
        "3" {
            $target = Read-Host "  Enter target (IP or hostname)"
            if ($target) {
                Write-Log "PathPing to $target..." "SECTION"
                pathping -n $target
            }
        }
        "4" {
            $hostname = Read-Host "  Enter hostname to lookup"
            if ($hostname) {
                Write-Log "DNS Lookup for ${hostname}:" "SECTION"
                Resolve-DnsName $hostname | Select-Object Name, Type, TTL, Section, IPAddress | Format-Table -AutoSize
            }
        }
        "5" {
            $target = Read-Host "  Enter target (default: localhost)"
            if (-not $target) { $target = "localhost" }
            $port = Read-Host "  Enter port to test (default: 80)"
            if (-not $port) { $port = 80 }
            Write-Log "Testing $target port $port..." "SECTION"
            $result = Test-NetConnection -ComputerName $target -Port $port
            if ($result.TcpTestSucceeded) {
                Write-Log "Port $port is OPEN" "SUCCESS"
            } else {
                Write-Log "Port $port is CLOSED or filtered" "WARNING"
            }
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Get-FirewallStatus {
    <#
    .SYNOPSIS
        Display firewall status and rules
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "FIREWALL STATUS" "SECTION"

    Write-Host ""
    Write-Host "  [1] Show firewall profile status"
    Write-Host "  [2] Show active firewall rules"
    Write-Host "  [3] Test firewall ports"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Firewall Profile Status:" "SECTION"
            Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize
        }
        "2" {
            Write-Log "Active Firewall Rules (showing first 20):" "SECTION"
            Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' } | Select-Object -First 20 DisplayName, Direction, Action, Profile | Format-Table -AutoSize
        }
        "3" {
            Write-Log "Common Ports Status:" "SECTION"
            $ports = @(80, 443, 3389, 445, 22, 21)
            foreach ($port in $ports) {
                $result = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue
                $status = if ($result.TcpTestSucceeded) { "OPEN" } else { "CLOSED" }
                $color = if ($result.TcpTestSucceeded) { "Green" } else { "Red" }
                Write-Host "  Port $port : $status" -ForegroundColor $color
            }
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Test-NetworkSpeed {
    <#
    .SYNOPSIS
        Basic network speed test
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "NETWORK SPEED TEST" "SECTION"

    Write-Host ""
    Write-Host "  This will download a test file to measure speed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Quick test (10 MB file)"
    Write-Host "  [2] Standard test (50 MB file)"
    Write-Host "  [3] Large test (100 MB file)"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    $testUrls = @{
        "1" = "http://speedtest.tele2.net/10MB.zip"
        "2" = "http://speedtest.tele2.net/50MB.zip"
        "3" = "http://speedtest.tele2.net/100MB.zip"
    }

    if ($choice -ne "0" -and $testUrls[$choice]) {
        $url = $testUrls[$choice]
        $outFile = "$env:TEMP\speedtest_$(Get-Random).zip"

        try {
            Write-Log "Starting download test..." "SECTION"
            $startTime = Get-Date
            Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
            $endTime = Get-Date

            $duration = ($endTime - $startTime).TotalSeconds
            $fileSizeMB = (Get-Item $outFile).Length / 1MB
            $speedMbps = ($fileSizeMB * 8) / $duration

            Write-Host ""
            Write-Host "  Download completed:" -ForegroundColor Cyan
            Write-Host "  File size: $([math]::Round($fileSizeMB, 2)) MB" -ForegroundColor Gray
            Write-Host "  Duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Gray
            Write-Host "  Speed: $([math]::Round($speedMbps, 2)) Mbps" -ForegroundColor $(if($speedMbps -gt 50){"Green"}elseif($speedMbps -gt 10){"Yellow"}else{"Red"})

            Remove-Item $outFile -Force
            Write-Log "Speed test completed" "SUCCESS"
        } catch {
            Write-Log "Speed test failed: $_" "ERROR"
        }
    } elseif ($choice -eq "0") {
        Write-Log "Cancelled" "INFO"
    } else {
        Write-Host "Invalid option" -ForegroundColor Red
    }
}

function Set-NetworkProfile {
    <#
    .SYNOPSIS
        Configure network profile (Public/Private) and metered connection
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "NETWORK PROFILE SETTINGS" "SECTION"

    Write-Host ""
    Write-Host "  [1] Show current network profile"
    Write-Host "  [2] Set profile to Private"
    Write-Host "  [3] Set profile to Public"
    Write-Host "  [4] Toggle metered connection"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Current Network Profile:" "SECTION"
            Get-NetConnectionProfile | Select-Object Name, InterfaceAlias, NetworkCategory, IPv4Connectivity | Format-Table -AutoSize
        }
        "2" {
            $netProfiles = Get-NetConnectionProfile
            Write-Host ""
            Write-Host "  Select connection to set Private:" -ForegroundColor Cyan
            $i = 1
            $profileMap = @{}
            foreach ($netProfile in $netProfiles) {
                Write-Host "  [$i] $($netProfile.Name) ($($netProfile.InterfaceAlias))" -ForegroundColor White
                $profileMap[$i] = $netProfile
                $i++
            }
            Write-Host "  [0] Cancel" -ForegroundColor Gray
            Write-Host ""
            $sel = Read-Host "  Select connection"
            if ($sel -ne "0" -and $profileMap[[int]$sel]) {
                Set-NetConnectionProfile -InterfaceIndex $profileMap[[int]$sel].InterfaceIndex -NetworkCategory Private
                Write-Log "Profile set to Private" "SUCCESS"
            }
        }
        "3" {
            $netProfiles = Get-NetConnectionProfile
            Write-Host ""
            Write-Host "  Select connection to set Public:" -ForegroundColor Cyan
            $i = 1
            $profileMap = @{}
            foreach ($netProfile in $netProfiles) {
                Write-Host "  [$i] $($netProfile.Name) ($($netProfile.InterfaceAlias))" -ForegroundColor White
                $profileMap[$i] = $netProfile
                $i++
            }
            Write-Host "  [0] Cancel" -ForegroundColor Gray
            Write-Host ""
            $sel = Read-Host "  Select connection"
            if ($sel -ne "0" -and $profileMap[[int]$sel]) {
                Set-NetConnectionProfile -InterfaceIndex $profileMap[[int]$sel].InterfaceIndex -NetworkCategory Public
                Write-Log "Profile set to Public" "SUCCESS"
            }
        }
        "4" {
            Write-Log "Metered connection settings require manual configuration." "WARNING"
            Write-Host ""
            Write-Host "  To configure metered connection:" -ForegroundColor Cyan
            Write-Host "  1. Open Settings > Network & Internet" -ForegroundColor Gray
            Write-Host "  2. Select Wi-Fi or Ethernet" -ForegroundColor Gray
            Write-Host "  3. Click on your connection" -ForegroundColor Gray
            Write-Host "  4. Toggle 'Set as metered connection'" -ForegroundColor Gray
            Write-Host ""
            Start-Process "ms-settings:network-wifi"
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Set-AdvancedTCPSetting {
    <#
    .SYNOPSIS
        Configure advanced TCP settings
    #>
    Set-ConsoleSize
    Clear-Host
    Write-Log "ADVANCED TCP SETTINGS" "SECTION"

    Write-Host ""
    Write-Host "  [1] Show current TCP settings"
    Write-Host "  [2] Optimize for gaming (low latency)"
    Write-Host "  [3] Optimize for throughput (high bandwidth)"
    Write-Host "  [4] Reset to Windows defaults"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "  Select option"

    switch ($choice) {
        "1" {
            Write-Log "Current TCP Settings:" "SECTION"
            $tcpParams = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -ErrorAction SilentlyContinue
            Write-Host "  TCP Window Size: $($tcpParams.TcpWindowSize)" -ForegroundColor Gray
            Write-Host "  Global Max TCP Window Size: $($tcpParams.GlobalMaxTcpWindowSize)" -ForegroundColor Gray
            Write-Host "  TCP 1323 Options: $($tcpParams.Tcp1323Opts)" -ForegroundColor Gray
            Write-Host "  Max Free TCBs: $($tcpParams.MaxFreeTcbs)" -ForegroundColor Gray
            Write-Host "  Max Hash Table Size: $($tcpParams.MaxHashTableSize)" -ForegroundColor Gray

            netsh interface tcp show global | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
        "2" {
            Write-Log "Applying gaming optimizations..."
            # Disable Window Scaling heuristics
            netsh interface tcp set heuristics disabled | Out-Null
            # Set congestion provider to CTCP (Compound TCP)
            netsh interface tcp set supplemental template=custom icw=10 | Out-Null
            # Enable ECN
            netsh interface tcp set global ecncapability=enabled | Out-Null
            # Disable Receive Side Scaling (can reduce latency)
            netsh interface tcp set global rss=disabled | Out-Null
            Write-Log "Gaming optimizations applied" "SUCCESS"
            Write-Host "  Note: Some settings require reboot" -ForegroundColor Yellow
        }
        "3" {
            Write-Log "Applying throughput optimizations..."
            # Enable Window Scaling
            netsh interface tcp set heuristics enabled | Out-Null
            # Set congestion provider to DCTCP (Data Center TCP)
            netsh interface tcp set supplemental template=datacenter | Out-Null
            # Enable RSS
            netsh interface tcp set global rss=enabled | Out-Null
            # Enable Chimney Offload
            netsh interface tcp set global chimney=enabled | Out-Null
            Write-Log "Throughput optimizations applied" "SUCCESS"
            Write-Host "  Note: Some settings require reboot" -ForegroundColor Yellow
        }
        "4" {
            Write-Log "Resetting TCP settings to defaults..."
            netsh interface tcp set heuristics default | Out-Null
            netsh interface tcp set supplemental template=default | Out-Null
            netsh interface tcp set global ecncapability=default | Out-Null
            netsh interface tcp set global rss=default | Out-Null
            netsh interface tcp set global chimney=default | Out-Null
            Write-Log "TCP settings reset to defaults" "SUCCESS"
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Start-NetworkMenu {
    <#
    .SYNOPSIS
        Network management menu
    #>
    do {
        Set-ConsoleSize
        Clear-Host
        Write-Log "NETWORK MANAGEMENT" "SECTION"

        Write-Host ""
        Write-Host "  [1] Apply Network Optimizations"
        Write-Host "  [2] Reset Network Configuration"
        Write-Host "  [3] Wi-Fi Network Management"
        Write-Host "  [4] Network Adapter Management"
        Write-Host "  [5] Proxy Configuration"
        Write-Host "  [6] Hosts File Editor"
        Write-Host "  [7] Network Diagnostics"
        Write-Host "  [8] Firewall Status"
        Write-Host "  [9] Network Speed Test"
        Write-Host "  [10] Network Profile Settings"
        Write-Host "  [11] Advanced TCP Settings"
        Write-Host "  [0] Back to Main Menu"
        Write-Host ""

        $choice = Read-Host "  Select an option"

        switch ($choice) {
            "1" { Set-NetworkOptimizations }
            "2" { Reset-Network }
            "3" { Get-WiFiNetwork }
            "4" { Get-NetworkAdapter }
            "5" { Set-ProxyConfiguration }
            "6" { Edit-HostsFile }
            "7" { Start-NetworkDiagnostic }
            "8" { Get-FirewallStatus }
            "9" { Test-NetworkSpeed }
            "10" { Set-NetworkProfile }
            "11" { Set-AdvancedTCPSetting }
            "0" { return }
            default { Write-Host "Invalid option" -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }

        if ($choice -ne "0") {
            Write-Host ""
            Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
    } while ($choice -ne "0")
}

# Export functions
Export-ModuleMember -Function @(
    'Set-NetworkOptimizations',
    'Reset-Network',
    'Get-WiFiNetwork',
    'Get-NetworkAdapter',
    'Set-ProxyConfiguration',
    'Edit-HostsFile',
    'Start-NetworkDiagnostic',
    'Get-FirewallStatus',
    'Test-NetworkSpeed',
    'Set-NetworkProfile',
    'Set-AdvancedTCPSetting',
    'Start-NetworkMenu'
)
