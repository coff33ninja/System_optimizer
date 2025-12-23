# ============================================================================
# HARDWARE MODULE - System Optimizer
# ============================================================================
# Detects CPU, GPU, Storage, Memory for smart optimization recommendations
# Compatible with: Windows 7+ and PowerShell 2.0+
# ============================================================================

# ============================================================================
# COMPATIBILITY HELPERS
# ============================================================================
# Detect PowerShell and Windows version for fallback logic
$script:PSVersionMajor = $PSVersionTable.PSVersion.Major
$script:WinBuild = [System.Environment]::OSVersion.Version.Build
$script:IsWin8OrNewer = $WinBuild -ge 9200  # Windows 8 = 9200
$script:HasCimCmdlets = $PSVersionMajor -ge 3

function Get-CimOrWmi {
    <#
    .SYNOPSIS
        Wrapper that uses Get-CimInstance on PS3+ or Get-WmiObject on PS2
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ClassName,
        [string]$Filter,
        [string]$Namespace = "root\cimv2"
    )

    if ($script:HasCimCmdlets) {
        if ($Filter) {
            Get-CimInstance -ClassName $ClassName -Filter $Filter -Namespace $Namespace -ErrorAction SilentlyContinue
        } else {
            Get-CimInstance -ClassName $ClassName -Namespace $Namespace -ErrorAction SilentlyContinue
        }
    } else {
        # Fallback for PowerShell 2.0
        if ($Filter) {
            Get-WmiObject -Class $ClassName -Filter $Filter -Namespace $Namespace -ErrorAction SilentlyContinue
        } else {
            Get-WmiObject -Class $ClassName -Namespace $Namespace -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# CPU DETECTION
# ============================================================================
function Get-CPUInfo {
    <#
    .SYNOPSIS
        Detect CPU manufacturer, model, cores, and capabilities
    .OUTPUTS
        PSCustomObject with CPU details
    #>
    [CmdletBinding()]
    param()

    try {
        $cpu = Get-CimOrWmi -ClassName Win32_Processor
        if (-not $cpu) { throw "Failed to query Win32_Processor" }
        $cpuName = $cpu.Name.Trim()

        # Determine manufacturer
        $manufacturer = switch -Regex ($cpuName) {
            'Intel'     { 'Intel' }
            'AMD'       { 'AMD' }
            'Qualcomm'  { 'Qualcomm' }
            'Apple'     { 'Apple' }
            'ARM'       { 'ARM' }
            'VIA'       { 'VIA' }
            default     { 'Unknown' }
        }

        # Detect Intel generation (1st gen to 14th gen+)
        $generation = $null
        $architecture = $null
        if ($manufacturer -eq 'Intel') {
            # Core Ultra (Meteor Lake+)
            if ($cpuName -match 'Core\s*Ultra') {
                $generation = "Core Ultra (Meteor Lake+)"
                $architecture = "Intel 4 / TSMC N3B"
            }
            # 10th gen+ uses 5-digit model (i7-14700K, i5-12600K)
            elseif ($cpuName -match 'i[3579]-(\d{2})(\d{3})') {
                $genNum = [int]$Matches[1]
                $generation = switch ($genNum) {
                    14 { "14th Gen (Raptor Lake Refresh)"; $architecture = "Intel 7" }
                    13 { "13th Gen (Raptor Lake)"; $architecture = "Intel 7" }
                    12 { "12th Gen (Alder Lake)"; $architecture = "Intel 7" }
                    11 { "11th Gen (Rocket/Tiger Lake)"; $architecture = "10nm/14nm" }
                    10 { "10th Gen (Ice/Comet Lake)"; $architecture = "10nm/14nm" }
                    default { "${genNum}th Gen" }
                }
            }
            # 9th gen and older uses 4-digit model (i7-9700K, i5-8600K)
            elseif ($cpuName -match 'i[3579]-(\d)(\d{3})') {
                $genNum = [int]$Matches[1]
                $generation = switch ($genNum) {
                    9 { "9th Gen (Coffee Lake Refresh)"; $architecture = "14nm++" }
                    8 { "8th Gen (Coffee Lake)"; $architecture = "14nm++" }
                    7 { "7th Gen (Kaby Lake)"; $architecture = "14nm+" }
                    6 { "6th Gen (Skylake)"; $architecture = "14nm" }
                    5 { "5th Gen (Broadwell)"; $architecture = "14nm" }
                    4 { "4th Gen (Haswell)"; $architecture = "22nm" }
                    3 { "3rd Gen (Ivy Bridge)"; $architecture = "22nm" }
                    2 { "2nd Gen (Sandy Bridge)"; $architecture = "32nm" }
                    default { "${genNum}th Gen" }
                }
            }
            # 1st gen (i7-920, i5-750)
            elseif ($cpuName -match 'i[357]-[789]\d{2}[^0-9]') {
                $generation = "1st Gen (Nehalem/Lynnfield)"
                $architecture = "45nm"
            }
            # Core 2 series
            elseif ($cpuName -match 'Core.*2\s*(Duo|Quad|Extreme)') {
                $generation = "Core 2 (Conroe/Penryn)"
                $architecture = "65nm/45nm"
            }
            # Pentium/Celeron
            elseif ($cpuName -match 'Pentium') {
                $generation = "Pentium"
            }
            elseif ($cpuName -match 'Celeron') {
                $generation = "Celeron"
            }
            # Xeon
            elseif ($cpuName -match 'Xeon') {
                $generation = "Xeon Server"
            }
        }

        # Detect AMD series
        if ($manufacturer -eq 'AMD') {
            # Ryzen 9000 series (Zen 5)
            if ($cpuName -match 'Ryzen\s*[3579]\s*9\d{3}') {
                $generation = "Ryzen 9000 (Zen 5)"
                $architecture = "TSMC 4nm"
            }
            # Ryzen 8000 series (Zen 4 APU)
            elseif ($cpuName -match 'Ryzen\s*[3579]\s*8\d{3}') {
                $generation = "Ryzen 8000 (Zen 4)"
                $architecture = "TSMC 4nm"
            }
            # Ryzen 7000 series (Zen 4)
            elseif ($cpuName -match 'Ryzen\s*[3579]\s*7[0-9]{3}') {
                $generation = "Ryzen 7000 (Zen 4)"
                $architecture = "TSMC 5nm"
            }
            # Ryzen 5000 series (Zen 3)
            elseif ($cpuName -match 'Ryzen\s*[3579]\s*5[0-9]{3}') {
                $generation = "Ryzen 5000 (Zen 3)"
                $architecture = "TSMC 7nm"
            }
            # Ryzen 4000 series (Zen 2 APU)
            elseif ($cpuName -match 'Ryzen\s*[3579]\s*4[0-9]{3}') {
                $generation = "Ryzen 4000 (Zen 2)"
                $architecture = "TSMC 7nm"
            }
            # Ryzen 3000 series (Zen 2)
            elseif ($cpuName -match 'Ryzen\s*[3579]\s*3[0-9]{3}') {
                $generation = "Ryzen 3000 (Zen 2)"
                $architecture = "TSMC 7nm"
            }
            # Ryzen 2000 series (Zen+)
            elseif ($cpuName -match 'Ryzen\s*[357]\s*2[0-9]{3}') {
                $generation = "Ryzen 2000 (Zen+)"
                $architecture = "GF 12nm"
            }
            # Ryzen 1000 series (Zen)
            elseif ($cpuName -match 'Ryzen\s*[357]\s*1[0-9]{3}') {
                $generation = "Ryzen 1000 (Zen)"
                $architecture = "GF 14nm"
            }
            # EPYC
            elseif ($cpuName -match 'EPYC') {
                $generation = "EPYC Server"
            }
            # Threadripper
            elseif ($cpuName -match 'Threadripper') {
                if ($cpuName -match '7\d{3}') { $generation = "Threadripper 7000 (Zen 4)" }
                elseif ($cpuName -match '5\d{3}') { $generation = "Threadripper 5000 (Zen 3)" }
                elseif ($cpuName -match '3\d{3}') { $generation = "Threadripper 3000 (Zen 2)" }
                else { $generation = "Threadripper HEDT" }
            }
            # FX series (Bulldozer/Piledriver)
            elseif ($cpuName -match 'FX-') {
                $generation = "FX (Bulldozer/Piledriver)"
                $architecture = "32nm"
            }
            # Phenom
            elseif ($cpuName -match 'Phenom') {
                $generation = "Phenom II"
                $architecture = "45nm"
            }
            # Athlon
            elseif ($cpuName -match 'Athlon') {
                if ($cpuName -match '3\d{3}') { $generation = "Athlon 3000 (Zen+)" }
                else { $generation = "Athlon" }
            }
        }

        # Check for hybrid architecture (P-cores + E-cores)
        $isHybrid = $false
        $pCores = $null
        $eCores = $null
        if ($manufacturer -eq 'Intel' -and $generation -match '12th|13th|14th|Ultra') {
            $isHybrid = $true
            # Try to detect P/E core split
            $coreInfo = Get-HybridCoreInfo
            if ($coreInfo) {
                $pCores = $coreInfo.PCores
                $eCores = $coreInfo.ECores
            }
        }

        # Hyperthreading/SMT detection
        $htEnabled = $cpu.NumberOfLogicalProcessors -gt $cpu.NumberOfCores

        return [PSCustomObject]@{
            Name = $cpuName
            Manufacturer = $manufacturer
            Generation = $generation
            Architecture = $architecture
            Cores = $cpu.NumberOfCores
            Threads = $cpu.NumberOfLogicalProcessors
            HyperthreadingEnabled = $htEnabled
            IsHybrid = $isHybrid
            PCores = $pCores
            ECores = $eCores
            MaxClockSpeedMHz = $cpu.MaxClockSpeed
            CurrentClockSpeedMHz = $cpu.CurrentClockSpeed
            L2CacheKB = $cpu.L2CacheSize
            L3CacheKB = $cpu.L3CacheSize
            Socket = $cpu.SocketDesignation
            AddressWidth = $cpu.AddressWidth
            VirtualizationEnabled = $cpu.VirtualizationFirmwareEnabled
        }
    } catch {
        Write-Warning "Failed to get CPU info: $($_.Exception.Message)"
        return $null
    }
}

function Get-HybridCoreInfo {
    <#
    .SYNOPSIS
        Detect P-core and E-core counts on Intel hybrid CPUs
    .DESCRIPTION
        Uses processor efficiency class from Windows to distinguish core types.
        P-cores have EfficiencyClass = 0, E-cores have EfficiencyClass = 1
        Uses Get-CimOrWmi wrapper for PS2/Win7 compatibility
    #>
    [CmdletBinding()]
    param()

    try {
        # Get processor info using wrapper
        $processors = Get-CimOrWmi -ClassName Win32_Processor
        if (-not $processors) { return $null }

        # Get additional info from registry (Family, Model, Stepping, MHz)
        $regPath = "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0"
        $cpuReg = Get-Item $regPath -ErrorAction SilentlyContinue
        $cpuIdentifier = $null
        $cpuMHz = $null
        if ($cpuReg) {
            $cpuIdentifier = $cpuReg.GetValue("Identifier")  # e.g., "AMD64 Family 23 Model 8 Stepping 2"
            $cpuMHz = $cpuReg.GetValue("~MHz")  # Actual current MHz
        }

        # Calculate P/E cores for Intel hybrid CPUs
        # P-cores have HT (2 threads each), E-cores don't (1 thread each)
        # Formula: Threads = (PCores * 2) + ECores, and Cores = PCores + ECores
        $totalCores = $processors.NumberOfCores
        $totalThreads = $processors.NumberOfLogicalProcessors

        if ($totalThreads -gt $totalCores) {
            # Has hyperthreading - likely hybrid
            # E-cores = Cores - (Threads - Cores) = 2*Cores - Threads
            # P-cores = Threads - Cores
            $eCores = (2 * $totalCores) - $totalThreads
            $pCores = $totalThreads - $totalCores

            # Validate - E-cores should be non-negative
            if ($eCores -ge 0 -and $pCores -gt 0) {
                return [PSCustomObject]@{
                    PCores = $pCores
                    ECores = $eCores
                    TotalCores = $totalCores
                    TotalThreads = $totalThreads
                    Identifier = $cpuIdentifier
                    CurrentMHz = $cpuMHz
                }
            }
        }

        # Return basic info even if not hybrid
        if ($cpuIdentifier -or $cpuMHz) {
            return [PSCustomObject]@{
                PCores = $null
                ECores = $null
                TotalCores = $totalCores
                TotalThreads = $totalThreads
                Identifier = $cpuIdentifier
                CurrentMHz = $cpuMHz
            }
        }

        return $null
    } catch {
        return $null
    }
}

# ============================================================================
# GPU DETECTION
# ============================================================================
function Get-GPUInfo {
    <#
    .SYNOPSIS
        Detect GPU(s), manufacturer, VRAM, and driver info
    .OUTPUTS
        Array of PSCustomObject with GPU details
    #>
    [CmdletBinding()]
    param()

    try {
        $gpus = Get-CimOrWmi -ClassName Win32_VideoController
        if (-not $gpus) { throw "Failed to query Win32_VideoController" }
        $results = @()

        foreach ($gpu in $gpus) {
            $gpuName = $gpu.Name

            # Determine manufacturer
            $manufacturer = switch -Regex ($gpuName) {
                'NVIDIA|GeForce|Quadro|RTX|GTX|Tesla' { 'NVIDIA' }
                'AMD|Radeon|RX\s*\d|Vega|FirePro'     { 'AMD' }
                'Intel|UHD|Iris|Arc|HD Graphics'      { 'Intel' }
                'Matrox'                              { 'Matrox' }
                'ASPEED'                              { 'ASPEED' }
                'Microsoft Basic'                     { 'Microsoft Basic' }
                'VMware|VirtualBox|Hyper-V'           { 'Virtual' }
                default                               { 'Unknown' }
            }

            # Determine if dedicated or integrated
            $isDedicated = $false
            if ($manufacturer -eq 'NVIDIA' -and $gpuName -notmatch 'Tegra') {
                $isDedicated = $true
            } elseif ($manufacturer -eq 'AMD' -and $gpuName -match 'RX|Vega\s*\d|FirePro|W\d{4}') {
                $isDedicated = $true
            } elseif ($manufacturer -eq 'Intel' -and $gpuName -match 'Arc\s*[AB]\d') {
                $isDedicated = $true
            }

            # VRAM and additional info from registry
            $vramBytes = $gpu.AdapterRAM
            $vramGB = $null
            $biosVersion = $null
            $chipType = $null

            if ($vramBytes -and $vramBytes -gt 0 -and $vramBytes -lt 4GB) {
                # WMI value is valid (under 4GB, no overflow)
                $vramGB = [math]::Round($vramBytes / 1GB, 1)
            }

            # Get extended info from registry (handles >4GB VRAM)
            $regInfo = Get-DedicatedVRAMFromRegistry -AdapterName $gpuName
            if ($regInfo.VRAM_GB) { $vramGB = $regInfo.VRAM_GB }
            if ($regInfo.BiosVersion) { $biosVersion = $regInfo.BiosVersion }
            if ($regInfo.ChipType) { $chipType = $regInfo.ChipType }

            # Detect GPU series/generation
            $series = $null
            $architecture = $null

            if ($manufacturer -eq 'NVIDIA') {
                $series = switch -Regex ($gpuName) {
                    # RTX 50 series (Blackwell)
                    'RTX\s*50[789]0' { "RTX 50 Series"; $architecture = "Blackwell" }
                    # RTX 40 series (Ada Lovelace)
                    'RTX\s*40[6789]0' { "RTX 40 Series"; $architecture = "Ada Lovelace" }
                    # RTX 30 series (Ampere)
                    'RTX\s*30[5678]0' { "RTX 30 Series"; $architecture = "Ampere" }
                    # RTX 20 series (Turing)
                    'RTX\s*20[678]0' { "RTX 20 Series"; $architecture = "Turing" }
                    # GTX 16 series (Turing)
                    'GTX\s*16[56]0' { "GTX 16 Series"; $architecture = "Turing" }
                    # GTX 10 series (Pascal)
                    'GTX\s*10[5678]0' { "GTX 10 Series"; $architecture = "Pascal" }
                    # GTX 900 series (Maxwell)
                    'GTX\s*9[5678]0' { "GTX 900 Series"; $architecture = "Maxwell" }
                    # GTX 700 series (Kepler)
                    'GTX\s*7[5678]0' { "GTX 700 Series"; $architecture = "Kepler" }
                    # GTX 600 series (Kepler)
                    'GTX\s*6[5678]0' { "GTX 600 Series"; $architecture = "Kepler" }
                    # GTX 500 series (Fermi)
                    'GTX\s*5[5678]0' { "GTX 500 Series"; $architecture = "Fermi" }
                    # GTX 400 series (Fermi)
                    'GTX\s*4[5678]0' { "GTX 400 Series"; $architecture = "Fermi" }
                    # GT/GTS series
                    'GT\s*[1-9]\d{2}' { "GeForce GT"; $architecture = "Various" }
                    # Quadro
                    'Quadro' { "Quadro Professional"; $architecture = "Various" }
                    # Tesla
                    'Tesla' { "Tesla Compute"; $architecture = "Various" }
                    default { $null }
                }
            }
            elseif ($manufacturer -eq 'AMD') {
                $series = switch -Regex ($gpuName) {
                    # RX 9000 series (RDNA 4)
                    'RX\s*9[0-9]{3}' { "RX 9000 Series"; $architecture = "RDNA 4" }
                    # RX 7000 series (RDNA 3)
                    'RX\s*7[0-9]{3}' { "RX 7000 Series"; $architecture = "RDNA 3" }
                    # RX 6000 series (RDNA 2)
                    'RX\s*6[0-9]{3}' { "RX 6000 Series"; $architecture = "RDNA 2" }
                    # RX 5000 series (RDNA)
                    'RX\s*5[0-9]{3}' { "RX 5000 Series"; $architecture = "RDNA" }
                    # RX Vega
                    'Vega\s*(56|64)' { "RX Vega"; $architecture = "Vega (GCN 5)" }
                    # RX 500 series (Polaris)
                    'RX\s*5[0-9]0' { "RX 500 Series"; $architecture = "Polaris (GCN 4)" }
                    # RX 400 series (Polaris)
                    'RX\s*4[0-9]0' { "RX 400 Series"; $architecture = "Polaris (GCN 4)" }
                    # R9 series (GCN 2/3)
                    'R9\s*(290|390|Fury|Nano)' { "R9 Series"; $architecture = "GCN 2/3" }
                    # R7 series
                    'R7\s*[23][0-9]0' { "R7 Series"; $architecture = "GCN" }
                    # HD 7000 series
                    'HD\s*7[0-9]{3}' { "HD 7000 Series"; $architecture = "GCN 1" }
                    # HD 6000 series
                    'HD\s*6[0-9]{3}' { "HD 6000 Series"; $architecture = "TeraScale 2" }
                    # HD 5000 series
                    'HD\s*5[0-9]{3}' { "HD 5000 Series"; $architecture = "TeraScale 2" }
                    # FirePro
                    'FirePro' { "FirePro Professional"; $architecture = "Various" }
                    default { $null }
                }
            }
            elseif ($manufacturer -eq 'Intel') {
                $series = switch -Regex ($gpuName) {
                    # Arc discrete
                    'Arc\s*A[357][0-9]0' { "Intel Arc A-Series"; $architecture = "Xe HPG (Alchemist)" }
                    'Arc\s*B[0-9]{3}' { "Intel Arc B-Series"; $architecture = "Xe2 (Battlemage)" }
                    # Iris Xe
                    'Iris\s*Xe' { "Iris Xe"; $architecture = "Xe LP (Gen 12)" }
                    # Iris Plus
                    'Iris\s*Plus' { "Iris Plus"; $architecture = "Gen 11" }
                    # UHD 700 series
                    'UHD\s*7[0-9]{2}' { "UHD 700 Series"; $architecture = "Xe LP (Gen 12)" }
                    # UHD 600 series
                    'UHD\s*6[0-9]{2}' { "UHD 600 Series"; $architecture = "Gen 9.5" }
                    # HD 600 series
                    'HD\s*6[0-9]{2}' { "HD 600 Series"; $architecture = "Gen 9" }
                    # HD 500 series
                    'HD\s*5[0-9]{2}' { "HD 500 Series"; $architecture = "Gen 8" }
                    # HD 4000/5000
                    'HD\s*(4[0-9]{3}|5[0-9]{3})' { "HD 4000/5000"; $architecture = "Gen 7/7.5" }
                    # HD 3000/2000
                    'HD\s*(3000|2[05]00)' { "HD 2000/3000"; $architecture = "Gen 6" }
                    # HD Graphics (generic)
                    'HD\s*Graphics' { "HD Graphics"; $architecture = "Various" }
                    default { $null }
                }
            }

            $results += [PSCustomObject]@{
                Name = $gpuName
                Manufacturer = $manufacturer
                Series = $series
                Architecture = $architecture
                IsDedicated = $isDedicated
                VRAM_GB = $vramGB
                BiosVersion = $biosVersion
                ChipType = $chipType
                DriverVersion = $gpu.DriverVersion
                DriverDate = $gpu.DriverDate
                Status = $gpu.Status
                CurrentResolution = "$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution)"
                RefreshRate = $gpu.CurrentRefreshRate
            }
        }

        return $results
    } catch {
        Write-Warning "Failed to get GPU info: $($_.Exception.Message)"
        return @()
    }
}

function Get-DedicatedVRAMFromRegistry {
    <#
    .SYNOPSIS
        Get dedicated VRAM and additional GPU info from registry (handles >4GB overflow)
    #>
    [CmdletBinding()]
    param([string]$AdapterName)

    $result = @{
        VRAM_GB = $null
        BiosVersion = $null
        ChipType = $null
    }

    try {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
        $subkeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\\\d{4}$' }

        foreach ($key in $subkeys) {
            $props = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
            if ($props.DriverDesc -and ($props.DriverDesc -like "*$AdapterName*" -or $AdapterName -like "*$($props.DriverDesc)*")) {
                # Get VRAM (qwMemorySize is 64-bit, handles >4GB)
                if ($props.'HardwareInformation.qwMemorySize') {
                    $result.VRAM_GB = [math]::Round($props.'HardwareInformation.qwMemorySize' / 1GB, 1)
                }
                # Get BIOS version
                if ($props.'HardwareInformation.BiosString') {
                    $result.BiosVersion = $props.'HardwareInformation.BiosString'
                }
                # Get chip type
                if ($props.'HardwareInformation.ChipType') {
                    $result.ChipType = $props.'HardwareInformation.ChipType'
                }
                break
            }
        }
    } catch { }

    return $result
}

# ============================================================================
# STORAGE DETECTION
# ============================================================================
function Get-StorageInfo {
    <#
    .SYNOPSIS
        Detect storage devices, type (SSD/HDD/NVMe), health, and free space
    .DESCRIPTION
        Uses Storage module cmdlets on Win8+, falls back to WMI on Win7
    .OUTPUTS
        Array of PSCustomObject with storage details
    #>
    [CmdletBinding()]
    param()

    # Windows 8+ has Storage module with Get-PhysicalDisk
    if ($script:IsWin8OrNewer) {
        return Get-StorageInfoModern
    } else {
        return Get-StorageInfoLegacy
    }
}

function Get-StorageInfoModern {
    <#
    .SYNOPSIS
        Storage detection using Windows 8+ Storage module
    #>
    try {
        $disks = Get-PhysicalDisk -ErrorAction Stop
        $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
        $partitions = Get-Partition -ErrorAction SilentlyContinue
        $results = @()

        foreach ($disk in $disks) {
            # Determine type
            $type = switch ($disk.MediaType) {
                'SSD'   { 'SSD' }
                'HDD'   { 'HDD' }
                'Unspecified' {
                    # Try to detect from bus type
                    if ($disk.BusType -eq 'NVMe') { 'NVMe' }
                    elseif ($disk.SpindleSpeed -eq 0) { 'SSD' }
                    else { 'Unknown' }
                }
                default { $disk.MediaType }
            }

            # Override to NVMe if bus type indicates
            if ($disk.BusType -eq 'NVMe') {
                $type = 'NVMe'
            }

            # Size in GB
            $sizeGB = [math]::Round($disk.Size / 1GB, 1)

            # Health status
            $health = $disk.HealthStatus
            $opStatus = $disk.OperationalStatus

            # Check TRIM support for SSDs
            $trimSupported = $null
            if ($type -in @('SSD', 'NVMe')) {
                try {
                    $trimStatus = fsutil behavior query DisableDeleteNotify 2>$null
                    $trimSupported = $trimStatus -match 'DisableDeleteNotify\s*=\s*0'
                } catch {
                    $trimSupported = $null
                }
            }

            # Get partitions and volumes on this disk for free space calculation
            $diskPartitions = $partitions | Where-Object { $_.DiskNumber -eq $disk.DeviceId }
            $diskVolumes = @()
            $totalUsed = 0
            $totalFree = 0

            foreach ($part in $diskPartitions) {
                $vol = $volumes | Where-Object { $_.DriveLetter -eq $part.DriveLetter }
                if ($vol) {
                    $volSizeGB = [math]::Round($vol.Size / 1GB, 1)
                    $volFreeGB = [math]::Round($vol.SizeRemaining / 1GB, 1)
                    $volUsedGB = $volSizeGB - $volFreeGB
                    $volUsedPercent = if ($volSizeGB -gt 0) { [math]::Round(($volUsedGB / $volSizeGB) * 100, 0) } else { 0 }

                    $totalUsed += $volUsedGB
                    $totalFree += $volFreeGB

                    $diskVolumes += [PSCustomObject]@{
                        DriveLetter = $vol.DriveLetter
                        Label = $vol.FileSystemLabel
                        FileSystem = $vol.FileSystem
                        Size_GB = $volSizeGB
                        Free_GB = $volFreeGB
                        Used_GB = $volUsedGB
                        UsedPercent = $volUsedPercent
                    }
                }
            }

            # Calculate overall disk usage
            $usedPercent = if ($sizeGB -gt 0 -and $totalUsed -gt 0) {
                [math]::Round(($totalUsed / $sizeGB) * 100, 0)
            } else { 0 }

            $results += [PSCustomObject]@{
                FriendlyName = $disk.FriendlyName
                Type = $type
                BusType = $disk.BusType
                Size_GB = $sizeGB
                Used_GB = [math]::Round($totalUsed, 1)
                Free_GB = [math]::Round($totalFree, 1)
                UsedPercent = $usedPercent
                HealthStatus = $health
                OperationalStatus = $opStatus
                TRIMEnabled = $trimSupported
                SerialNumber = $disk.SerialNumber
                FirmwareVersion = $disk.FirmwareVersion
                DeviceId = $disk.DeviceId
                Volumes = $diskVolumes
            }
        }

        return $results
    } catch {
        Write-Warning "Failed to get storage info: $($_.Exception.Message)"
        return @()
    }
}

function Get-StorageInfoLegacy {
    <#
    .SYNOPSIS
        Storage detection using WMI for Windows 7/PowerShell 2.0 compatibility
    .DESCRIPTION
        Falls back to Win32_DiskDrive and Win32_LogicalDisk when Storage module unavailable
    #>
    try {
        $results = @()

        # Get physical disks via WMI
        $physicalDisks = Get-CimOrWmi -ClassName Win32_DiskDrive
        $logicalDisks = Get-CimOrWmi -ClassName Win32_LogicalDisk -Filter "DriveType=3"  # Local disks only

        # Get disk-to-partition-to-logical mapping
        $diskPartitions = Get-CimOrWmi -ClassName Win32_DiskDriveToDiskPartition
        $partitionLogical = Get-CimOrWmi -ClassName Win32_LogicalDiskToPartition

        foreach ($disk in $physicalDisks) {
            # Determine type based on media type and interface
            $type = 'Unknown'
            $busType = $disk.InterfaceType

            # Check for SSD indicators
            if ($disk.Model -match 'SSD|Solid State|NVMe') {
                $type = if ($busType -eq 'SCSI' -and $disk.Model -match 'NVMe') { 'NVMe' } else { 'SSD' }
            }
            elseif ($disk.MediaType -match 'Fixed hard disk') {
                # Could be HDD or SSD - check for rotation
                # Win32_DiskDrive doesn't have SpindleSpeed, so use heuristics
                if ($disk.Model -match 'WD|Seagate|Hitachi|HGST|Toshiba' -and $disk.Model -notmatch 'SSD') {
                    $type = 'HDD'
                } else {
                    $type = 'SSD'  # Default to SSD for unknown fixed disks
                }
            }

            # Size in GB
            $sizeGB = [math]::Round($disk.Size / 1GB, 1)

            # Find logical disks on this physical disk
            $diskVolumes = @()
            $totalUsed = 0
            $totalFree = 0

            # Map physical disk -> partitions -> logical disks
            $diskParts = $diskPartitions | Where-Object { $_.Antecedent -match [regex]::Escape($disk.DeviceID) }
            foreach ($dp in $diskParts) {
                $partId = if ($dp.Dependent -match 'DeviceID="([^"]+)"') { $Matches[1] } else { $null }
                if ($partId) {
                    $logicalMap = $partitionLogical | Where-Object { $_.Antecedent -match [regex]::Escape($partId) }
                    foreach ($lm in $logicalMap) {
                        $logicalId = if ($lm.Dependent -match 'DeviceID="([^"]+)"') { $Matches[1] } else { $null }
                        if ($logicalId) {
                            $vol = $logicalDisks | Where-Object { $_.DeviceID -eq $logicalId }
                            if ($vol) {
                                $volSizeGB = [math]::Round($vol.Size / 1GB, 1)
                                $volFreeGB = [math]::Round($vol.FreeSpace / 1GB, 1)
                                $volUsedGB = $volSizeGB - $volFreeGB
                                $volUsedPercent = if ($volSizeGB -gt 0) { [math]::Round(($volUsedGB / $volSizeGB) * 100, 0) } else { 0 }

                                $totalUsed += $volUsedGB
                                $totalFree += $volFreeGB

                                $diskVolumes += [PSCustomObject]@{
                                    DriveLetter = $vol.DeviceID.TrimEnd(':')
                                    Label = $vol.VolumeName
                                    FileSystem = $vol.FileSystem
                                    Size_GB = $volSizeGB
                                    Free_GB = $volFreeGB
                                    Used_GB = $volUsedGB
                                    UsedPercent = $volUsedPercent
                                }
                            }
                        }
                    }
                }
            }

            # If no volumes found via mapping, try direct match by index
            if ($diskVolumes.Count -eq 0) {
                foreach ($vol in $logicalDisks) {
                    $volSizeGB = [math]::Round($vol.Size / 1GB, 1)
                    $volFreeGB = [math]::Round($vol.FreeSpace / 1GB, 1)
                    $volUsedGB = $volSizeGB - $volFreeGB
                    $volUsedPercent = if ($volSizeGB -gt 0) { [math]::Round(($volUsedGB / $volSizeGB) * 100, 0) } else { 0 }

                    $totalUsed += $volUsedGB
                    $totalFree += $volFreeGB

                    $diskVolumes += [PSCustomObject]@{
                        DriveLetter = $vol.DeviceID.TrimEnd(':')
                        Label = $vol.VolumeName
                        FileSystem = $vol.FileSystem
                        Size_GB = $volSizeGB
                        Free_GB = $volFreeGB
                        Used_GB = $volUsedGB
                        UsedPercent = $volUsedPercent
                    }
                }
            }

            # Calculate overall disk usage
            $usedPercent = if ($sizeGB -gt 0 -and $totalUsed -gt 0) {
                [math]::Round(($totalUsed / $sizeGB) * 100, 0)
            } else { 0 }

            # Check TRIM support for SSDs
            $trimSupported = $null
            if ($type -in @('SSD', 'NVMe')) {
                try {
                    $trimStatus = fsutil behavior query DisableDeleteNotify 2>$null
                    $trimSupported = $trimStatus -match 'DisableDeleteNotify\s*=\s*0'
                } catch {
                    $trimSupported = $null
                }
            }

            # Extract device index for DeviceId
            $deviceId = if ($disk.DeviceID -match '(\d+)$') { [int]$Matches[1] } else { 0 }

            $results += [PSCustomObject]@{
                FriendlyName = $disk.Model
                Type = $type
                BusType = $busType
                Size_GB = $sizeGB
                Used_GB = [math]::Round($totalUsed, 1)
                Free_GB = [math]::Round($totalFree, 1)
                UsedPercent = $usedPercent
                HealthStatus = if ($disk.Status -eq 'OK') { 'Healthy' } else { $disk.Status }
                OperationalStatus = $disk.Status
                TRIMEnabled = $trimSupported
                SerialNumber = $disk.SerialNumber
                FirmwareVersion = $disk.FirmwareRevision
                DeviceId = $deviceId
                Volumes = $diskVolumes
            }
        }

        return $results
    } catch {
        Write-Warning "Failed to get storage info (legacy): $($_.Exception.Message)"
        return @()
    }
}

# ============================================================================
# MEMORY DETECTION
# ============================================================================
function Get-MemoryInfo {
    <#
    .SYNOPSIS
        Detect RAM amount, speed, and configuration
    .DESCRIPTION
        Uses Get-CimOrWmi wrapper for PS2/Win7 compatibility
    .OUTPUTS
        PSCustomObject with memory details
    #>
    [CmdletBinding()]
    param()

    try {
        $memory = Get-CimOrWmi -ClassName Win32_PhysicalMemory
        $os = Get-CimOrWmi -ClassName Win32_OperatingSystem
        if (-not $memory -or -not $os) { throw "Failed to query WMI" }

        $totalGB = [math]::Round(($memory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 1)
        $sticks = $memory.Count
        $speeds = $memory | Select-Object -ExpandProperty Speed -Unique
        $configuredSpeeds = $memory | Select-Object -ExpandProperty ConfiguredClockSpeed -Unique
        $types = $memory | Select-Object -ExpandProperty SMBIOSMemoryType -Unique

        # Memory type mapping
        $memoryType = switch ($types | Select-Object -First 1) {
            20 { 'DDR' }
            21 { 'DDR2' }
            22 { 'DDR2 FB-DIMM' }
            24 { 'DDR3' }
            26 { 'DDR4' }
            34 { 'DDR5' }
            default { 'Unknown' }
        }

        # Available memory
        $availableGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $usedGB = [math]::Round($totalGB - $availableGB, 1)
        $usagePercent = [math]::Round(($usedGB / $totalGB) * 100, 0)

        # Check for dual channel (rough estimate based on stick count)
        $channelMode = switch ($sticks) {
            1 { 'Single Channel' }
            2 { 'Dual Channel (likely)' }
            4 { 'Dual/Quad Channel' }
            8 { 'Quad Channel (likely)' }
            default { "$sticks sticks" }
        }

        # Get detailed stick info
        $stickDetails = @()
        foreach ($stick in $memory) {
            $stickDetails += [PSCustomObject]@{
                Manufacturer = $stick.Manufacturer
                PartNumber = if ($stick.PartNumber) { $stick.PartNumber.Trim() } else { $null }
                Capacity_GB = [math]::Round($stick.Capacity / 1GB, 1)
                Speed_MHz = $stick.Speed
                ConfiguredSpeed_MHz = $stick.ConfiguredClockSpeed
                Voltage_mV = $stick.ConfiguredVoltage
                Slot = $stick.DeviceLocator
                Bank = $stick.BankLabel
                FormFactor = switch ($stick.FormFactor) {
                    8 { 'DIMM' }
                    12 { 'SODIMM' }
                    default { $stick.FormFactor }
                }
            }
        }

        # Check if XMP/DOCP might be enabled (configured speed > base JEDEC)
        $maxSpeed = ($speeds | Measure-Object -Maximum).Maximum
        $maxConfigured = ($configuredSpeeds | Measure-Object -Maximum).Maximum
        $xmpEnabled = $maxConfigured -gt 2133 -and $memoryType -eq 'DDR4'  # DDR4 JEDEC base is 2133
        if ($memoryType -eq 'DDR5') {
            $xmpEnabled = $maxConfigured -gt 4800  # DDR5 JEDEC base is 4800
        }

        return [PSCustomObject]@{
            Total_GB = $totalGB
            Available_GB = $availableGB
            Used_GB = $usedGB
            UsagePercent = $usagePercent
            Sticks = $sticks
            Speed_MHz = $maxSpeed
            ConfiguredSpeed_MHz = $maxConfigured
            Type = $memoryType
            ChannelMode = $channelMode
            XMPEnabled = $xmpEnabled
            Manufacturers = ($memory | Select-Object -ExpandProperty Manufacturer -Unique | Where-Object { $_ }) -join ', '
            StickDetails = $stickDetails
        }
    } catch {
        Write-Warning "Failed to get memory info: $($_.Exception.Message)"
        return $null
    }
}


# ============================================================================
# SYSTEM SUMMARY
# ============================================================================
function Get-HardwareProfile {
    <#
    .SYNOPSIS
        Get complete hardware profile for the system
    .OUTPUTS
        PSCustomObject with all hardware info
    #>
    [CmdletBinding()]
    param()

    $cpu = Get-CPUInfo
    $gpus = Get-GPUInfo
    $storage = Get-StorageInfo
    $memory = Get-MemoryInfo

    # Determine primary GPU (dedicated if available)
    $primaryGPU = $gpus | Where-Object { $_.IsDedicated } | Select-Object -First 1
    if (-not $primaryGPU) {
        $primaryGPU = $gpus | Select-Object -First 1
    }

    # Determine primary storage (boot drive)
    $bootDrive = $storage | Where-Object { $_.DeviceId -eq 0 } | Select-Object -First 1
    if (-not $bootDrive) {
        $bootDrive = $storage | Select-Object -First 1
    }

    # System recommendations based on hardware
    $recommendations = Get-HardwareRecommendation -CPU $cpu -GPU $primaryGPU -Storage $bootDrive -Memory $memory

    return [PSCustomObject]@{
        Timestamp = Get-Date -Format "o"
        ComputerName = $env:COMPUTERNAME
        CPU = $cpu
        GPUs = $gpus
        PrimaryGPU = $primaryGPU
        Storage = $storage
        BootDrive = $bootDrive
        Memory = $memory
        Recommendations = $recommendations
    }
}

function Get-HardwareRecommendation {
    <#
    .SYNOPSIS
        Generate optimization recommendations based on detected hardware
    #>
    [CmdletBinding()]
    param(
        $CPU,
        $GPU,
        $Storage,
        $Memory
    )

    $recommendations = @()

    # CPU recommendations
    if ($CPU) {
        if ($CPU.Manufacturer -eq 'Intel' -and $CPU.IsHybrid) {
            $recommendations += "Intel hybrid CPU detected - Thread Director optimization available"
        }
        if ($CPU.Manufacturer -eq 'AMD') {
            $recommendations += "AMD CPU detected - Consider enabling PBO (Precision Boost Overdrive)"
        }
        if (-not $CPU.HyperthreadingEnabled -and $CPU.Cores -lt 8) {
            $recommendations += "Hyperthreading/SMT is disabled - Consider enabling for better multitasking"
        }
        if ($CPU.VirtualizationEnabled -eq $false) {
            $recommendations += "Hardware virtualization disabled - Enable in BIOS for WSL2/Docker"
        }
    }

    # GPU recommendations
    if ($GPU) {
        if ($GPU.Manufacturer -eq 'NVIDIA') {
            $recommendations += "NVIDIA GPU detected - GPU scheduling and CUDA optimizations available"
        }
        if ($GPU.Manufacturer -eq 'AMD') {
            $recommendations += "AMD GPU detected - Radeon Anti-Lag and SAM optimizations available"
        }
        if (-not $GPU.IsDedicated) {
            $recommendations += "Integrated graphics only - Consider reducing visual effects"
        }
    }

    # Storage recommendations
    if ($Storage) {
        if ($Storage.Type -eq 'HDD') {
            $recommendations += "HDD boot drive detected - Consider SSD upgrade for major performance boost"
            $recommendations += "Enable scheduled defragmentation for HDD"
        }
        if ($Storage.Type -in @('SSD', 'NVMe') -and $Storage.TRIMEnabled -eq $false) {
            $recommendations += "TRIM is disabled on SSD - Enable for better performance and longevity"
        }
        if ($Storage.Type -eq 'NVMe') {
            $recommendations += "NVMe drive detected - Disable defragmentation, enable TRIM"
        }
        if ($Storage.HealthStatus -ne 'Healthy') {
            $recommendations += "WARNING: Boot drive health is $($Storage.HealthStatus) - Consider backup/replacement"
        }
        if ($Storage.UsedPercent -and $Storage.UsedPercent -gt 90) {
            $recommendations += "WARNING: Boot drive is $($Storage.UsedPercent)% full - Free up space for better performance"
        }
        elseif ($Storage.UsedPercent -and $Storage.UsedPercent -gt 75) {
            $recommendations += "Boot drive is $($Storage.UsedPercent)% full - Consider cleanup"
        }
        if ($Storage.Free_GB -and $Storage.Free_GB -lt 20) {
            $recommendations += "WARNING: Only $($Storage.Free_GB) GB free on boot drive"
        }
    }

    # Memory recommendations
    if ($Memory) {
        if ($Memory.Total_GB -lt 8) {
            $recommendations += "Low RAM ($($Memory.Total_GB)GB) - Consider upgrade, disable memory-heavy features"
        }
        if ($Memory.Total_GB -ge 16) {
            $recommendations += "Sufficient RAM - Can enable memory compression and SuperFetch"
        }
        if ($Memory.UsagePercent -gt 80) {
            $recommendations += "High memory usage ($($Memory.UsagePercent)%) - Close background apps or add RAM"
        }
        if ($Memory.ChannelMode -eq 'Single Channel') {
            $recommendations += "Single channel RAM - Add matching stick for dual channel (2x performance)"
        }
    }

    return $recommendations
}

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================
function Show-HardwareSummary {
    <#
    .SYNOPSIS
        Display a formatted hardware summary
    #>
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  HARDWARE DETECTION" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor Cyan

    $hwProfile = Get-HardwareProfile

    # CPU
    Write-Host ""
    Write-Host "  CPU:" -ForegroundColor Gray
    if ($hwProfile.CPU) {
        Write-Host "    $($hwProfile.CPU.Name)"
        Write-Host "    $($hwProfile.CPU.Manufacturer)" -NoNewline
        if ($hwProfile.CPU.Generation) { Write-Host " - $($hwProfile.CPU.Generation)" -NoNewline }
        Write-Host ""
        if ($hwProfile.CPU.Architecture) { Write-Host "    Architecture: $($hwProfile.CPU.Architecture)" -ForegroundColor DarkGray }
        Write-Host "    $($hwProfile.CPU.Cores) cores / $($hwProfile.CPU.Threads) threads" -NoNewline
        if ($hwProfile.CPU.HyperthreadingEnabled) { Write-Host " (HT/SMT enabled)" -ForegroundColor Green -NoNewline }
        Write-Host ""
        if ($hwProfile.CPU.IsHybrid) {
            Write-Host "    Hybrid architecture" -ForegroundColor Cyan -NoNewline
            if ($hwProfile.CPU.PCores -and $hwProfile.CPU.ECores) {
                Write-Host " ($($hwProfile.CPU.PCores) P-cores + $($hwProfile.CPU.ECores) E-cores)" -ForegroundColor Cyan
            } else {
                Write-Host " (P+E cores)" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host "    Detection failed" -ForegroundColor Red
    }

    # GPU
    Write-Host ""
    Write-Host "  GPU:" -ForegroundColor Gray
    if ($hwProfile.GPUs.Count -gt 0) {
        foreach ($gpu in $hwProfile.GPUs) {
            $typeLabel = if ($gpu.IsDedicated) { "[Dedicated]" } else { "[Integrated]" }
            Write-Host "    $($gpu.Name) $typeLabel"
            if ($gpu.VRAM_GB) { Write-Host "    VRAM: $($gpu.VRAM_GB) GB" }
            if ($gpu.Series) {
                Write-Host "    Series: $($gpu.Series)" -ForegroundColor DarkGray -NoNewline
                if ($gpu.Architecture) { Write-Host " ($($gpu.Architecture))" -ForegroundColor DarkGray }
                else { Write-Host "" }
            }
            if ($gpu.BiosVersion) { Write-Host "    BIOS: $($gpu.BiosVersion)" -ForegroundColor DarkGray }
        }
    } else {
        Write-Host "    Detection failed" -ForegroundColor Red
    }

    # Storage
    Write-Host ""
    Write-Host "  Storage:" -ForegroundColor Gray
    if ($hwProfile.Storage.Count -gt 0) {
        foreach ($disk in $hwProfile.Storage) {
            $healthColor = if ($disk.HealthStatus -eq 'Healthy') { 'Green' } else { 'Yellow' }
            Write-Host "    $($disk.FriendlyName)"
            Write-Host "    $($disk.Type) ($($disk.BusType)) - $($disk.Size_GB) GB - " -NoNewline
            Write-Host $disk.HealthStatus -ForegroundColor $healthColor

            # Show usage if available
            if ($disk.Free_GB -and $disk.UsedPercent) {
                $usageColor = if ($disk.UsedPercent -gt 90) { 'Red' } elseif ($disk.UsedPercent -gt 75) { 'Yellow' } else { 'Gray' }
                Write-Host "    Used: $($disk.Used_GB)/$($disk.Size_GB) GB ($($disk.UsedPercent)%) - " -NoNewline
                Write-Host "Free: $($disk.Free_GB) GB" -ForegroundColor $usageColor
            }

            # Show volumes
            if ($disk.Volumes -and $disk.Volumes.Count -gt 0) {
                foreach ($vol in $disk.Volumes) {
                    $volColor = if ($vol.UsedPercent -gt 90) { 'Red' } elseif ($vol.UsedPercent -gt 75) { 'Yellow' } else { 'DarkGray' }
                    $label = if ($vol.Label) { " ($($vol.Label))" } else { "" }
                    Write-Host "      $($vol.DriveLetter):$label $($vol.Free_GB)/$($vol.Size_GB) GB free" -ForegroundColor $volColor
                }
            }

            if ($disk.Type -in @('SSD', 'NVMe') -and $null -ne $disk.TRIMEnabled) {
                $trimStatus = if ($disk.TRIMEnabled) { "Enabled" } else { "Disabled" }
                $trimColor = if ($disk.TRIMEnabled) { 'Green' } else { 'Yellow' }
                Write-Host "    TRIM: " -NoNewline
                Write-Host $trimStatus -ForegroundColor $trimColor
            }
        }
    } else {
        Write-Host "    Detection failed" -ForegroundColor Red
    }

    # Memory
    Write-Host ""
    Write-Host "  Memory:" -ForegroundColor Gray
    if ($hwProfile.Memory) {
        Write-Host "    $($hwProfile.Memory.Total_GB) GB $($hwProfile.Memory.Type) @ $($hwProfile.Memory.ConfiguredSpeed_MHz) MHz"
        Write-Host "    $($hwProfile.Memory.ChannelMode) ($($hwProfile.Memory.Sticks) stick(s))"
        if ($hwProfile.Memory.XMPEnabled) {
            Write-Host "    XMP/DOCP: " -NoNewline
            Write-Host "Enabled" -ForegroundColor Green
        }
        if ($hwProfile.Memory.Manufacturers) {
            Write-Host "    Brands: $($hwProfile.Memory.Manufacturers)" -ForegroundColor DarkGray
        }
        Write-Host "    Usage: $($hwProfile.Memory.Used_GB)/$($hwProfile.Memory.Total_GB) GB ($($hwProfile.Memory.UsagePercent)%)"
    } else {
        Write-Host "    Detection failed" -ForegroundColor Red
    }

    # Recommendations
    if ($hwProfile.Recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "  Recommendations:" -ForegroundColor Yellow
        foreach ($rec in $hwProfile.Recommendations) {
            if ($rec -match '^WARNING') {
                Write-Host "    ! $rec" -ForegroundColor Red
            } else {
                Write-Host "    - $rec" -ForegroundColor Gray
            }
        }
    }

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan

    if ($Detailed) {
        return $hwProfile
    }
}

function Export-HardwareProfile {
    <#
    .SYNOPSIS
        Export hardware profile to JSON file
    #>
    [CmdletBinding()]
    param(
        [string]$Path = "C:\System_Optimizer\hardware_profile.json"
    )

    $hwProfile = Get-HardwareProfile

    # Ensure directory exists
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $hwProfile | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8

    Write-Host "Hardware profile exported to: $Path" -ForegroundColor Green
    return $Path
}

# ============================================================================
# OPTIMIZATION HELPERS
# ============================================================================
function Test-IsGamingCapable {
    <#
    .SYNOPSIS
        Check if system has dedicated GPU suitable for gaming
    #>
    [CmdletBinding()]
    param()

    $gpus = Get-GPUInfo
    $dedicatedGPU = $gpus | Where-Object { $_.IsDedicated -and $_.VRAM_GB -ge 4 }
    return ($null -ne $dedicatedGPU)
}

function Test-IsLaptop {
    <#
    .SYNOPSIS
        Detect if system is a laptop (has battery)
    #>
    [CmdletBinding()]
    param()

    $battery = Get-CimOrWmi -ClassName Win32_Battery
    return ($null -ne $battery)
}

function Test-HasSSD {
    <#
    .SYNOPSIS
        Check if boot drive is SSD/NVMe
    #>
    [CmdletBinding()]
    param()

    $storage = Get-StorageInfo
    $bootDrive = $storage | Where-Object { $_.DeviceId -eq 0 } | Select-Object -First 1
    return ($bootDrive.Type -in @('SSD', 'NVMe'))
}

function Test-HasNVMe {
    <#
    .SYNOPSIS
        Check if system has NVMe storage
    #>
    [CmdletBinding()]
    param()

    $storage = Get-StorageInfo
    return ($storage | Where-Object { $_.Type -eq 'NVMe' }).Count -gt 0
}

function Get-RecommendedProfile {
    <#
    .SYNOPSIS
        Suggest an optimization profile based on hardware
    #>
    [CmdletBinding()]
    param()

    $isLaptop = Test-IsLaptop
    $isGaming = Test-IsGamingCapable
    $memory = Get-MemoryInfo
    $cpu = Get-CPUInfo

    # Determine best profile
    if ($isGaming -and $memory.Total_GB -ge 16) {
        return "Gaming"
    }
    if ($cpu.Cores -ge 8 -and $memory.Total_GB -ge 16) {
        return "Developer"
    }
    if ($isLaptop) {
        return "Laptop"
    }
    if ($memory.Total_GB -lt 8) {
        return "LowSpec"
    }

    return "Balanced"
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================
Export-ModuleMember -Function @(
    # Compatibility
    'Get-CimOrWmi',

    # Detection
    'Get-CPUInfo',
    'Get-GPUInfo',
    'Get-StorageInfo',
    'Get-MemoryInfo',
    'Get-HardwareProfile',
    'Get-HardwareRecommendation',
    'Get-HybridCoreInfo',

    # Display
    'Show-HardwareSummary',
    'Export-HardwareProfile',

    # Helpers
    'Test-IsGamingCapable',
    'Test-IsLaptop',
    'Test-HasSSD',
    'Test-HasNVMe',
    'Get-RecommendedProfile'
)
