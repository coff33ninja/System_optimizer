# ============================================================================
# Modular Windows 10/11 Optimization Toolkit
# Run: .\Start-SystemOptimizer.ps1
# ============================================================================

#Requires -RunAsAdministrator

param(
    [switch]$SkipModuleLoad,
    [string]$RunOption,
    [switch]$Help
)

# ============================================================================
# UTF-8 ENCODING SUPPORT
# ============================================================================
# Enable UTF-8 output for special characters (checkmarks, boxes, etc.)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
# Set code page to UTF-8 (65001) for cmd.exe compatibility
if ($Host.Name -eq 'ConsoleHost') {
    try { chcp 65001 | Out-Null } catch { }
}

# ============================================================================
# CONFIGURATION
# ============================================================================
# Handle path detection for both script and EXE execution
$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptRoot) -or $scriptRoot -eq "") {
    # When running as EXE, use current directory
    $scriptRoot = Get-Location | Select-Object -ExpandProperty Path
}

# Check if we're running as EXE with embedded modules
$isEmbeddedEXE = $false
if ([string]::IsNullOrEmpty($PSScriptRoot) -and (Test-Path ".\modules")) {
    $isEmbeddedEXE = $true
    Write-Host "Running as EXE with embedded modules" -ForegroundColor Green
    
    # Clean up any old temp files when running as EXE
    try {
        $tempCleanupPaths = @(
            "$env:TEMP\SystemOptimizer",
            "C:\temp\test_exe"
        )
        foreach ($path in $tempCleanupPaths) {
            if (Test-Path $path) {
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # Ignore cleanup errors
    }
}

$script:Config = @{
    Version = "1.0.0"
    Root = $scriptRoot
    ModulesDir = if ($isEmbeddedEXE) { ".\modules" } else { "$scriptRoot\modules" }
    LogDir = "C:\System_Optimizer\Logs"
    BackupDir = "C:\System_Optimizer_Backup"
    ConsoleWidth = 90
    ConsoleHeight = 38
    GitHubRepo = "coff33ninja/System_Optimizer"
    GitHubBranch = "main"
}

$script:LogFile = $null

# ============================================================================
# VERSION CHECK
# ============================================================================
function Get-LatestVersion {
    try {
        $url = "https://raw.githubusercontent.com/$($Config.GitHubRepo)/$($Config.GitHubBranch)/Start-SystemOptimizer.ps1"
        $content = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).Content
        if ($content -match 'Version\s*=\s*"([^"]+)"') {
            return $matches[1]
        }
    } catch {
        # Silently fail - no internet or GitHub down
    }
    return $null
}

function Test-UpdateAvailable {
    $latestVersion = Get-LatestVersion
    if ($latestVersion -and $latestVersion -ne $Config.Version) {
        return @{
            Available = $true
            Current = $Config.Version
            Latest = $latestVersion
        }
    }
    return @{ Available = $false; Current = $Config.Version; Latest = $Config.Version }
}

function Update-SystemOptimizer {
    param([switch]$Force)
    
    $update = Test-UpdateAvailable
    if (-not $update.Available -and -not $Force) {
        Write-Host "Already running latest version ($($Config.Version))" -ForegroundColor Green
        return $false
    }
    
    Write-Host ""
    Write-Host "Update available: v$($update.Current) -> v$($update.Latest)" -ForegroundColor Yellow
    
    if (-not $Force) {
        $response = Read-Host "Download update? (Y/N)"
        if ($response -notmatch '^[Yy]') { return $false }
    }
    
    $persistentPath = "C:\System_Optimizer"
    
    try {
        # Download main script
        Write-Host "[*] Downloading System Optimizer v$($update.Latest)..." -ForegroundColor Yellow
        $scriptUrl = "https://raw.githubusercontent.com/$($Config.GitHubRepo)/$($Config.GitHubBranch)/Start-SystemOptimizer.ps1"
        $scriptPath = Join-Path $persistentPath "Start-SystemOptimizer.ps1"
        New-Item -ItemType Directory -Path $persistentPath -Force | Out-Null
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        Write-Host "  [+] Main script updated" -ForegroundColor Green
        
        # Download modules
        $modulesPath = Join-Path $persistentPath "modules"
        Update-ModulesFromGitHub -TargetPath $modulesPath -Version $update.Latest | Out-Null
        
        Write-Host ""
        Write-Host "[+] Update complete! Restart to use v$($update.Latest)" -ForegroundColor Green
        Write-Host "    Run: C:\System_Optimizer\Start-SystemOptimizer.ps1" -ForegroundColor Cyan
        return $true
    } catch {
        Write-Host "[-] Update failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# HELP
# ============================================================================
if ($Help) {
    Write-Host @"

SYSTEM OPTIMIZER v$($Config.Version)
================================

USAGE:
  .\Start-SystemOptimizer.ps1 [OPTIONS]
  .\SystemOptimizer.exe [OPTIONS]

BASIC OPTIONS:
  -Help              Show this comprehensive help message
  -SkipModuleLoad    Start without loading modules (limited functionality)
  -RunOption <opt>   Run specific optimization and exit (see options below)

RUN OPTIONS (-RunOption):
  Core Optimizations:
    all                Run ALL optimizations (telemetry, services, bloatware, etc.)
    telemetry          Disable telemetry, data collection, ads, feedback, Cortana
    services           Disable unnecessary Windows services (interactive menu)
    bloatware          Remove pre-installed apps (Xbox, Mail, Weather, etc.)
    tasks              Disable scheduled maintenance tasks
    registry           Apply registry performance tweaks and SSD optimizations
    vbs                Disable VBS/Memory Integrity (improves gaming performance)
    network            Optimize TCP/IP, DNS, and network adapter settings
    onedrive           Completely remove OneDrive cloud storage
    maintenance        Run system maintenance (DISM, SFC, temp cleanup)

  Software & Tools:
    software           Launch PatchMyPC for software installation/updates
    office             Launch Office Tool Plus for Microsoft Office installation
    activation         Run Microsoft Activation Script (MAS) for Windows/Office
    drivers            Launch Snappy Driver Installer for driver management
    
  Advanced Operations:
    power              Set power plan (High Performance, Ultimate, Balanced)
    shutup10           Launch O&O ShutUp10 privacy tool
    reset-gpo          Reset Group Policy to defaults
    reset-wmi          Repair Windows Management Instrumentation
    cleanup            Run advanced disk cleanup
    updates            Control Windows Update settings
    reset-network      Reset all network settings to defaults
    repair-updates     Repair broken Windows Update components
    defender           Manage Windows Defender settings
    debloat-all        Remove ALL pre-installed apps (aggressive)
    winutil-services   Apply ChrisTitusTech WinUtil service configurations
    privacy            Advanced privacy tweaks and data collection controls
    
  Utilities:
    wifi               Extract saved Wi-Fi passwords
    verify             Check current optimization status
    logs               View operation logs and history
    backup             User profile backup/restore menu
    shutdown           Shutdown/restart options menu
    rollback           Undo previous optimizations
    hardware           Hardware detection and analysis
    profiles           Optimization profiles (Gaming, Developer, Office)
    
  Deployment Tools:
    vhd                VHD Native Boot creation menu
    installer          Windows deployment to blank drives
    image-tool         Windows image modification and ISO creation

EXAMPLES:
  Interactive Menu:
    .\Start-SystemOptimizer.ps1
    .\SystemOptimizer.exe

  Quick Optimizations:
    .\Start-SystemOptimizer.ps1 -RunOption all
    .\Start-SystemOptimizer.ps1 -RunOption telemetry
    .\Start-SystemOptimizer.ps1 -RunOption bloatware

  Specific Tools:
    .\Start-SystemOptimizer.ps1 -RunOption software
    .\Start-SystemOptimizer.ps1 -RunOption office
    .\Start-SystemOptimizer.ps1 -RunOption activation

  System Maintenance:
    .\Start-SystemOptimizer.ps1 -RunOption maintenance
    .\Start-SystemOptimizer.ps1 -RunOption cleanup
    .\Start-SystemOptimizer.ps1 -RunOption repair-updates

  Advanced Operations:
    .\Start-SystemOptimizer.ps1 -RunOption debloat-all
    .\Start-SystemOptimizer.ps1 -RunOption reset-network
    .\Start-SystemOptimizer.ps1 -RunOption privacy

MENU NAVIGATION:
  When running interactively, use these menu numbers:
  
  Quick Actions:
    [1]  Run ALL Optimizations    [16] Full Setup Workflow
    
  Core Optimizations:
    [2]  Disable Telemetry        [3]  Disable Services
    [4]  Remove Bloatware         [5]  Disable Scheduled Tasks
    [6]  Registry Optimizations   [7]  Disable VBS/Memory Integrity
    [8]  Network Optimizations    [9]  Remove OneDrive
    [10] System Maintenance
    
  Software & Activation:
    [11] Software Installation    [12] Office Tool Plus
    [13] Microsoft Activation
    
  Advanced Tools:
    [17] Power Plan              [18] O&O ShutUp10
    [19] Reset Group Policy      [20] Reset WMI
    [21] Disk Cleanup            [22] Windows Update Control
    [23] Driver Management       [24] Reset Network
    [25] Repair Windows Update   [26] Defender Control
    [27] Full Debloat           [28] WinUtil Service Sync
    [29] Privacy Tweaks         [30] Windows Image Tool
    
  Deployment Tools:
    [34] VHD Native Boot         [35] Windows Installer
    
  Utilities:
    [14] Wi-Fi Passwords         [15] Verify Status
    [31] View Logs              [32] Profile Backup/Restore
    [33] Shutdown Options       [36] Undo/Rollback Center
    [37] Hardware Detection     [38] Optimization Profiles

FIRST TIME SETUP:
  1. Ensure you're running as Administrator
  2. Run: .\Start-SystemOptimizer.ps1 (starts interactive menu)
  
  OR use the standalone EXE:
  1. Download SystemOptimizer.exe
  2. Run as Administrator
  3. All modules are embedded - no setup required

REQUIREMENTS:
  - Windows 10/11 (some features work on Windows 7/8.1)
  - PowerShell 5.1+ (PowerShell 7+ recommended)
  - Administrator privileges
  - Internet connection (for downloads and updates)

LOGGING:
  All operations are logged to: C:\System_Optimizer\Logs\
  Logs include timestamps, operation details, and error information
  Old logs are automatically cleaned up after 30 days

SAFETY FEATURES:
  - Automatic system restore point creation (optional)
  - Rollback system to undo changes
  - Service backup before modifications
  - Registry backup before tweaks
  - Comprehensive logging for troubleshooting

SUPPORT:
  - GitHub: https://github.com/coff33ninja/System_optimizer
  - Issues: Report bugs and feature requests on GitHub
  - Documentation: README.md and wiki on GitHub repository

"@
    exit 0
}

# ============================================================================
# LOGGING
# ============================================================================
function Initialize-Logging {
    if (-not (Test-Path $Config.LogDir)) {
        New-Item -ItemType Directory -Path $Config.LogDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $script:LogFile = "$($Config.LogDir)\SystemOptimizer_$timestamp.log"
    
    $header = @"
================================================================================
SYSTEM OPTIMIZER v$($Config.Version)
================================================================================
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $((Get-CimInstance Win32_OperatingSystem).Caption)
PowerShell: $($PSVersionTable.PSVersion)
================================================================================

"@
    Add-Content -Path $LogFile -Value $header -ErrorAction SilentlyContinue
    
    # Cleanup old logs
    Get-ChildItem -Path $Config.LogDir -Filter "SystemOptimizer_*.log" -ErrorAction SilentlyContinue | 
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $shortTime = Get-Date -Format "HH:mm:ss"
    
    if ($LogFile) {
        Add-Content -Path $LogFile -Value "[$timestamp] [$Type] $Message" -ErrorAction SilentlyContinue
    }
    
    switch ($Type) {
        "SUCCESS" { Write-Host "[$shortTime] [OK] " -ForegroundColor Green -NoNewline; Write-Host $Message }
        "ERROR"   { Write-Host "[$shortTime] [X] " -ForegroundColor Red -NoNewline; Write-Host $Message }
        "WARNING" { Write-Host "[$shortTime] [!] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "SECTION" { Write-Host "`n[$shortTime] === " -ForegroundColor Cyan -NoNewline; Write-Host $Message -ForegroundColor Cyan -NoNewline; Write-Host " ===" -ForegroundColor Cyan }
        default   { Write-Host "[$shortTime] [-] " -ForegroundColor Gray -NoNewline; Write-Host $Message }
    }
}

# ============================================================================
# CONSOLE
# ============================================================================
function Set-ConsoleSize {
    param([int]$Width = $Config.ConsoleWidth, [int]$Height = $Config.ConsoleHeight)
    try {
        if ($Host.Name -eq 'ConsoleHost') {
            $max = $Host.UI.RawUI.MaxPhysicalWindowSize
            $Width = [Math]::Min($Width, $max.Width)
            $Height = [Math]::Min($Height, $max.Height)
            
            $buf = $Host.UI.RawUI.BufferSize
            $buf.Width = [Math]::Max($Width, $buf.Width)
            $buf.Height = 9999
            $Host.UI.RawUI.BufferSize = $buf
            
            $win = $Host.UI.RawUI.WindowSize
            $win.Width = $Width
            $win.Height = $Height
            $Host.UI.RawUI.WindowSize = $win
        }
    } catch { }
}

# ============================================================================
# MODULE LOADER
# ============================================================================
function Import-OptimizerModules {
    $persistentModulesPath = "C:\System_Optimizer\modules"
    $versionFile = "C:\System_Optimizer\modules\.version"
    $currentVersion = $Config.Version
    
    # Check if we should use local modules first
    if (Test-Path $Config.ModulesDir) {
        # Local modules exist, use them
        $modulesPath = $Config.ModulesDir
    } elseif (Test-Path $persistentModulesPath) {
        # Check if cached version matches current version
        $cachedVersion = if (Test-Path $versionFile) { Get-Content $versionFile -ErrorAction SilentlyContinue } else { "" }
        
        if ($cachedVersion -eq $currentVersion) {
            Write-Log "Using cached modules v$cachedVersion from $persistentModulesPath" "INFO"
            $script:Config.ModulesDir = $persistentModulesPath
            $modulesPath = $persistentModulesPath
        } else {
            Write-Log "Version mismatch (cached: $cachedVersion, current: $currentVersion) - updating modules..." "WARNING"
            $modulesPath = Update-ModulesFromGitHub -TargetPath $persistentModulesPath -Version $currentVersion
        }
    } else {
        # No modules anywhere, download fresh
        Write-Log "No modules found, downloading to $persistentModulesPath..." "WARNING"
        $modulesPath = Update-ModulesFromGitHub -TargetPath $persistentModulesPath -Version $currentVersion
    }
    
    if (-not $modulesPath) { return $false }
    
    $modules = Get-ChildItem -Path $modulesPath -Filter "*.psm1" -ErrorAction SilentlyContinue
    if ($modules.Count -eq 0) {
        Write-Log "No modules found in $modulesPath" "WARNING"
        return $false
    }
    
    $loaded = 0
    $failed = @()
    
    foreach ($mod in $modules) {
        try {
            Import-Module $mod.FullName -Force -Global -DisableNameChecking -ErrorAction Stop
            $loaded++
        } catch {
            $failed += $mod.Name
            Write-Log "Module $($mod.Name) failed: $($_.Exception.Message)" "DEBUG"
        }
    }
    
    Write-Log "Loaded $loaded/$($modules.Count) modules" "SUCCESS"
    if ($failed.Count -gt 0) {
        Write-Log "Failed: $($failed -join ', ')" "WARNING"
    }
    
    return ($loaded -gt 0)
}

function Update-ModulesFromGitHub {
    param(
        [string]$TargetPath,
        [string]$Version
    )
    
    try {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
        
        $moduleList = @('Backup','Bloatware','Core','Drivers','Hardware','ImageTool','Installer',
                       'Logging','Maintenance','Network','OneDrive','Power','Privacy','Profiles',
                       'Registry','Rollback','Security','Services','Shutdown','Software','Tasks',
                       'Telemetry','UITweaks','Utilities','VBS','VHDDeploy','WindowsUpdate')
        
        Write-Host "[*] Downloading modules from GitHub (v$Version)..." -ForegroundColor Yellow
        $downloaded = 0
        foreach ($mod in $moduleList) {
            try {
                $url = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/modules/$mod.psm1"
                $outPath = Join-Path $TargetPath "$mod.psm1"
                Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing -ErrorAction Stop
                $downloaded++
                Write-Host "  [+] $mod" -ForegroundColor Green
            } catch {
                Write-Host "  [-] $mod failed" -ForegroundColor Red
            }
        }
        
        # Save version file
        $Version | Out-File (Join-Path $TargetPath ".version") -Force
        
        Write-Host "[+] Downloaded $downloaded/$($moduleList.Count) modules" -ForegroundColor Green
        $script:Config.ModulesDir = $TargetPath
        return $TargetPath
    } catch {
        Write-Log "Failed to download modules: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# ============================================================================
# SAFE FUNCTION CALLER
# ============================================================================

# Function to Module mapping for validation
$script:FunctionModuleMap = @{
    'Run-AllOptimizations' = 'Core'
    'Disable-Telemetry' = 'Telemetry'
    'Show-ServicesMenu' = 'Services'
    'DebloatBlacklist' = 'Bloatware'
    'Disable-ScheduledTasks' = 'Tasks'
    'Set-RegistryOptimizations' = 'Registry'
    'Disable-VBS' = 'VBS'
    'Set-NetworkOptimizations' = 'Network'
    'Remove-OneDrive' = 'OneDrive'
    'Start-SystemMaintenance' = 'Maintenance'
    'Start-PatchMyPC' = 'Software'
    'Start-OfficeTool' = 'Software'
    'Run-MAS' = 'Software'
    'Get-WifiPasswords' = 'Utilities'
    'Verify-OptimizationStatus' = 'Utilities'
    'Run-FullSetup' = 'Core'
    'Set-PowerPlan' = 'Power'
    'Start-OOShutUp10' = 'Privacy'
    'Reset-GroupPolicy' = 'Maintenance'
    'Reset-WMI' = 'Maintenance'
    'Start-DiskCleanup' = 'Maintenance'
    'Set-WindowsUpdateControl' = 'WindowsUpdate'
    'Start-SnappyDriverInstaller' = 'Drivers'
    'Reset-Network' = 'Network'
    'Repair-WindowsUpdate' = 'WindowsUpdate'
    'Set-DefenderControl' = 'Security'
    'DebloatAll' = 'Bloatware'
    'Sync-WinUtilServices' = 'Services'
    'Start-DISMStyleTweaks' = 'UITweaks'
    'Start-ImageToolMenu' = 'ImageTool'
    'Show-LogViewer' = 'Utilities'
    'Show-UserBackupMenu' = 'Backup'
    'Show-ShutdownMenu' = 'Shutdown'
    'Start-VHDMenu' = 'VHDDeploy'
    'Start-InstallerMenu' = 'Installer'
    'Show-RollbackMenu' = 'Rollback'
    'Show-HardwareSummary' = 'Hardware'
    'Show-ProfileMenu' = 'Profiles'
    'Protect-Privacy' = 'Bloatware'
}

function Test-FunctionAvailable {
    param([string]$FunctionName)
    return [bool](Get-Command $FunctionName -ErrorAction SilentlyContinue)
}

function Get-MenuItemColor {
    param([string]$FunctionName)
    if (Test-FunctionAvailable $FunctionName) {
        return 'White'
    } else {
        return 'DarkGray'
    }
}

function Write-MenuItem {
    param(
        [string]$Number,
        [string]$Text,
        [string]$Description,
        [string]$FunctionName
    )
    
    $available = Test-FunctionAvailable $FunctionName
    $numColor = if ($available) { 'Cyan' } else { 'DarkGray' }
    $textColor = if ($available) { 'White' } else { 'DarkGray' }
    $descColor = 'DarkGray'
    $marker = if ($available) { '' } else { ' [X]' }
    
    Write-Host "  [$Number]" -ForegroundColor $numColor -NoNewline
    Write-Host " $Text$marker" -ForegroundColor $textColor -NoNewline
    Write-Host " - $Description" -ForegroundColor $descColor
}

function Write-MenuItemCompact {
    param(
        [string]$Number,
        [string]$Text,
        [string]$FunctionName,
        [int]$Width = 38
    )

    $available = Test-FunctionAvailable $FunctionName
    $numColor = if ($available) { 'Cyan' } else { 'DarkGray' }
    $textColor = if ($available) { 'White' } else { 'DarkGray' }
    $marker = if ($available) { '' } else { ' [X]' }

    $textPart = " $Text$marker".PadRight($Width - $Number.Length - 1)
    Write-Host "  [" -ForegroundColor $textColor -NoNewline
    Write-Host $Number -ForegroundColor $numColor -NoNewline
    Write-Host "]$textPart" -ForegroundColor $textColor -NoNewline
}

function Invoke-OptFunction {
    param([string]$FunctionName)
    
    if (Get-Command $FunctionName -ErrorAction SilentlyContinue) {
        & $FunctionName
    } else {
        Write-Log "Function not available: $FunctionName" "ERROR"
        
        # Try to identify and reload the module
        $moduleName = $FunctionModuleMap[$FunctionName]
        if ($moduleName) {
            $modulePath = Join-Path $Config.ModulesDir "$moduleName.psm1"
            if (Test-Path $modulePath) {
                Write-Log "Attempting to reload module: $moduleName" "INFO"
                try {
                    Import-Module $modulePath -Force -Global -DisableNameChecking -ErrorAction Stop
                    if (Get-Command $FunctionName -ErrorAction SilentlyContinue) {
                        Write-Log "Module reloaded successfully, retrying..." "SUCCESS"
                        & $FunctionName
                        return
                    }
                } catch {
                    Write-Log "Failed to reload module: $($_.Exception.Message)" "ERROR"
                }
            } else {
                Write-Log "Module file not found: $modulePath" "ERROR"
                Write-Host ""
                Write-Host "Would you like to download the missing module? (Y/N)" -ForegroundColor Yellow
                $response = Read-Host
                if ($response -match '^[Yy]') {
                    try {
                        $url = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/modules/$moduleName.psm1"
                        Write-Log "Downloading $moduleName.psm1 from GitHub..." "INFO"
                        Invoke-WebRequest -Uri $url -OutFile $modulePath -UseBasicParsing
                        Import-Module $modulePath -Force -Global -DisableNameChecking
                        if (Get-Command $FunctionName -ErrorAction SilentlyContinue) {
                            Write-Log "Module downloaded and loaded successfully!" "SUCCESS"
                            & $FunctionName
                            return
                        }
                    } catch {
                        Write-Log "Download failed: $($_.Exception.Message)" "ERROR"
                    }
                }
            }
        }
        Write-Log "Check modules folder or download from GitHub" "WARNING"
    }
}

# ============================================================================
# MAIN MENU
# ============================================================================
function Get-QuickHardwareSummary {
    # Compact one-line hardware summary for menu header
    # Uses fallback for PS2/Win7 compatibility
    try {
        # Use Get-CimInstance on PS3+, Get-WmiObject on PS2
        $useCim = $PSVersionTable.PSVersion.Major -ge 3
        
        if ($useCim) {
            $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
            $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'Basic|Virtual' } | Select-Object -First 1
            $mem = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        } else {
            $cpu = Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
            $gpu = Get-WmiObject Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'Basic|Virtual' } | Select-Object -First 1
            $mem = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue
        }
        
        # Get-Volume only available on Win8+
        $diskFree = "?"
        $winBuild = [System.Environment]::OSVersion.Version.Build
        if ($winBuild -ge 9200) {
            $disk = Get-Volume -DriveLetter C -ErrorAction SilentlyContinue
            if ($disk) { $diskFree = [math]::Round($disk.SizeRemaining / 1GB) }
        } else {
            # Fallback for Win7
            $logicalDisk = if ($useCim) {
                Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
            } else {
                Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
            }
            if ($logicalDisk) { $diskFree = [math]::Round($logicalDisk.FreeSpace / 1GB) }
        }
        
        $cpuShort = if ($cpu.Name -match '(i[3579]-\d+|Ryzen\s*\d\s*\d+|Core\s*Ultra)') { $Matches[0] } else { $cpu.Name.Split(' ')[0..2] -join ' ' }
        $gpuShort = if ($gpu.Name -match '(GTX|RTX|RX|Arc|Radeon)\s*\d+') { $Matches[0] } else { $gpu.Name.Split(' ')[0..1] -join ' ' }
        $memGB = [math]::Round($mem.TotalPhysicalMemory / 1GB)
        
        return "CPU: $cpuShort | GPU: $gpuShort | RAM: ${memGB}GB | C: ${diskFree}GB free"
    } catch {
        return $null
    }
}

function Show-MainMenu {
    Set-ConsoleSize
    Clear-Host
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  SYSTEM OPTIMIZER v$($Config.Version)" -ForegroundColor Yellow -NoNewline
    
    # Check for updates (cached, don't check every time)
    if (-not $script:UpdateChecked) {
        $script:UpdateInfo = Test-UpdateAvailable
        $script:UpdateChecked = $true
    }
    if ($script:UpdateInfo.Available) {
        Write-Host "  [UPDATE: v$($script:UpdateInfo.Latest) available]" -ForegroundColor Magenta
    } else {
        Write-Host ""
    }
    
    # Show compact hardware summary
    $hwSummary = Get-QuickHardwareSummary
    if ($hwSummary) {
        Write-Host "  $hwSummary" -ForegroundColor DarkGray
    }
    
    # Show profile info if module loaded
    try {
        if (Get-Command 'Get-ActiveProfile' -ErrorAction SilentlyContinue) {
            $activeProfile = Get-ActiveProfile
            $suggestedProfile = $null
            if (Get-Command 'Get-SuggestedProfile' -ErrorAction SilentlyContinue) {
                $suggestedProfile = Get-SuggestedProfile
            }
            
            if ($activeProfile -and $activeProfile.Name) {
                Write-Host "  Profile: $($activeProfile.Name)" -ForegroundColor Green -NoNewline
                if ($suggestedProfile -and $suggestedProfile.Profile -and $suggestedProfile.Profile -ne $activeProfile.Name) {
                    Write-Host " (Suggested: $($suggestedProfile.Profile))" -ForegroundColor DarkYellow
                } else {
                    Write-Host ""
                }
            } elseif ($suggestedProfile -and $suggestedProfile.Profile) {
                Write-Host "  Profile: None - Suggested: $($suggestedProfile.Profile)" -ForegroundColor DarkYellow
            }
        }
    } catch {
        # Silently ignore profile errors
    }
    
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""
    
    # Quick Actions (Full Width)
    Write-Host "  Quick Actions:" -ForegroundColor Green
    Write-MenuItem "1" "Run ALL Optimizations       " "Apply all optimizations" 'Run-AllOptimizations'
    Write-MenuItem "16" "Full Setup                  " "Software + Office + Activation" 'Run-FullSetup'
    Write-Host ""
    
    # Two-Column Layout for remaining options
    Write-Host "  Core Optimizations:           Software & Tools:" -ForegroundColor Gray
    Write-MenuItemCompact "2" "Disable Telemetry" 'Disable-Telemetry'
    Write-MenuItemCompact "11" "Software Install" 'Start-PatchMyPC'
    Write-Host ""
    
    Write-MenuItemCompact "3" "Disable Services" 'Show-ServicesMenu'
    Write-MenuItemCompact "12" "Office Tool Plus" 'Start-OfficeTool'
    Write-Host ""
    
    Write-MenuItemCompact "4" "Remove Bloatware" 'DebloatBlacklist'
    Write-MenuItemCompact "13" "MAS Activation" 'Run-MAS'
    Write-Host ""
    
    Write-MenuItemCompact "5" "Disable Scheduled Tasks" 'Disable-ScheduledTasks'
    Write-MenuItemCompact "14" "Wi-Fi Passwords" 'Get-WifiPasswords'
    Write-Host ""
    
    Write-MenuItemCompact "6" "Registry Optimizations" 'Set-RegistryOptimizations'
    Write-MenuItemCompact "15" "Verify Status" 'Verify-OptimizationStatus'
    Write-Host ""
    
    Write-MenuItemCompact "7" "Disable VBS/Memory" 'Disable-VBS'
    Write-MenuItemCompact "31" "View Logs" 'Show-LogViewer'
    Write-Host ""
    
    Write-MenuItemCompact "8" "Network Optimizations" 'Set-NetworkOptimizations'
    Write-MenuItemCompact "32" "Profile Backup" 'Show-UserBackupMenu'
    Write-Host ""
    
    Write-MenuItemCompact "9" "Remove OneDrive" 'Remove-OneDrive'
    Write-MenuItemCompact "33" "Shutdown Options" 'Show-ShutdownMenu'
    Write-Host ""
    
    Write-MenuItemCompact "10" "System Maintenance" 'Start-SystemMaintenance'
    Write-MenuItemCompact "34" "VHD Native Boot" 'Start-VHDMenu'
    Write-Host ""
    
    Write-Host "  Advanced Tools:               Management:" -ForegroundColor Gray
    Write-MenuItemCompact "17" "Power Plan" 'Set-PowerPlan'
    Write-MenuItemCompact "35" "Windows Installer" 'Start-InstallerMenu'
    Write-Host ""
    
    Write-MenuItemCompact "18" "O&O ShutUp10" 'Start-OOShutUp10'
    Write-MenuItemCompact "36" "Undo/Rollback" 'Show-RollbackMenu'
    Write-Host ""
    
    Write-MenuItemCompact "19" "Reset Group Policy" 'Reset-GroupPolicy'
    Write-MenuItemCompact "37" "Hardware Detection" 'Show-HardwareSummary'
    Write-Host ""
    
    Write-MenuItemCompact "20" "Reset WMI" 'Reset-WMI'
    Write-MenuItemCompact "38" "Optimization Profiles" 'Show-ProfileMenu'
    Write-Host ""
    
    Write-MenuItemCompact "21" "Disk Cleanup" 'Start-DiskCleanup'
    Write-Host ""
    
    Write-MenuItemCompact "22" "Windows Update" 'Set-WindowsUpdateControl'
    Write-Host ""
    
    Write-MenuItemCompact "23" "Driver Management" 'Start-SnappyDriverInstaller'
    Write-Host ""
    
    Write-MenuItemCompact "24" "Reset Network" 'Reset-Network'
    Write-Host ""
    
    Write-MenuItemCompact "25" "Repair Updates" 'Repair-WindowsUpdate'
    Write-Host ""
    
    Write-MenuItemCompact "26" "Defender Control" 'Set-DefenderControl'
    Write-Host ""
    
    Write-MenuItemCompact "27" "Full Debloat" 'DebloatAll'
    Write-Host ""
    
    Write-MenuItemCompact "28" "WinUtil Sync" 'Sync-WinUtilServices'
    Write-Host ""
    
    Write-MenuItemCompact "29" "Privacy Tweaks" 'Start-DISMStyleTweaks'
    Write-Host ""
    
    Write-MenuItemCompact "30" "Image Tool" 'Start-ImageToolMenu'
    Write-Host ""
    
    Write-Host ("-" * 80) -ForegroundColor DarkGray
    Write-Host "  Log: $LogFile" -ForegroundColor DarkGray
    Write-Host "  [?] Help  |  [X] = Module not loaded  |  [U] Check for Updates" -NoNewline
    if ($script:UpdateInfo.Available) {
        Write-Host " (v$($script:UpdateInfo.Latest) available!)" -ForegroundColor Magenta
    } else {
        Write-Host ""
    }
    Write-Host "  [0] Exit"
    Write-Host ""
}

function Start-MainMenu {
    do {
        Show-MainMenu
        $choice = Read-Host "Select option"
        
        switch ($choice) {
            "1"  { Invoke-OptFunction 'Run-AllOptimizations' }
            "2"  { Invoke-OptFunction 'Disable-Telemetry' }
            "3"  { Invoke-OptFunction 'Show-ServicesMenu' }
            "4"  { Invoke-OptFunction 'DebloatBlacklist' }           # Bloatware.psm1
            "5"  { Invoke-OptFunction 'Disable-ScheduledTasks' }
            "6"  { Invoke-OptFunction 'Set-RegistryOptimizations' }
            "7"  { Invoke-OptFunction 'Disable-VBS' }
            "8"  { Invoke-OptFunction 'Set-NetworkOptimizations' }
            "9"  { Invoke-OptFunction 'Remove-OneDrive' }
            "10" { Invoke-OptFunction 'Start-SystemMaintenance' }
            "11" { Invoke-OptFunction 'Start-PatchMyPC' }
            "12" { Invoke-OptFunction 'Start-OfficeTool' }
            "13" { Invoke-OptFunction 'Run-MAS' }
            "14" { Invoke-OptFunction 'Get-WifiPasswords' }
            "15" { Invoke-OptFunction 'Verify-OptimizationStatus' }
            "16" { Invoke-OptFunction 'Run-FullSetup' }
            "17" { Invoke-OptFunction 'Set-PowerPlan' }
            "18" { Invoke-OptFunction 'Start-OOShutUp10' }
            "19" { Invoke-OptFunction 'Reset-GroupPolicy' }
            "20" { Invoke-OptFunction 'Reset-WMI' }
            "21" { Invoke-OptFunction 'Start-DiskCleanup' }
            "22" { Invoke-OptFunction 'Set-WindowsUpdateControl' }
            "23" { Invoke-OptFunction 'Start-SnappyDriverInstaller' }
            "24" { Invoke-OptFunction 'Reset-Network' }
            "25" { Invoke-OptFunction 'Repair-WindowsUpdate' }
            "26" { Invoke-OptFunction 'Set-DefenderControl' }
            "27" { Invoke-OptFunction 'DebloatAll' }                 # Bloatware.psm1 - advanced debloat
            "28" { Invoke-OptFunction 'Sync-WinUtilServices' }
            "29" { Invoke-OptFunction 'Start-DISMStyleTweaks' }      # UITweaks.psm1 - DISM++ style tweaks
            "30" { Invoke-OptFunction 'Start-ImageToolMenu' }        # ImageTool.psm1
            "31" { Invoke-OptFunction 'Show-LogViewer' }
            "32" { Invoke-OptFunction 'Show-UserBackupMenu' }        # Backup.psm1
            "33" { Invoke-OptFunction 'Show-ShutdownMenu' }
            "34" { Invoke-OptFunction 'Start-VHDMenu' }              # VHDDeploy.psm1
            "35" { Invoke-OptFunction 'Start-InstallerMenu' }        # Installer.psm1
            "36" { Invoke-OptFunction 'Show-RollbackMenu' }          # Rollback.psm1
            "37" { Invoke-OptFunction 'Show-HardwareSummary' }       # Hardware.psm1
            "38" { Invoke-OptFunction 'Show-ProfileMenu' }           # Profiles.psm1
            "U"  { Update-SystemOptimizer }
            "u"  { Update-SystemOptimizer }
            "?"  { 
                if (Get-Command 'Show-MenuHelp' -ErrorAction SilentlyContinue) {
                    Show-MenuHelp
                } else {
                    Write-Host "`nHelp module not loaded. See docs\FEATURES.md for descriptions." -ForegroundColor Yellow
                }
            }
            "0"  { 
                Write-Log "Exiting" "INFO"
                return 
            }
            default { Write-Host "Invalid option" -ForegroundColor Red }
        }
        
        if ($choice -ne "0") {
            # Ensure progress displays are cleaned up after each operation
            if (Get-Command 'Ensure-ProgressCleanup' -ErrorAction SilentlyContinue) {
                Ensure-ProgressCleanup
            }
            
            Write-Host "`nPress any key..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } while ($true)
}

# ============================================================================
# ENTRY POINT
# ============================================================================
Initialize-Logging
Write-Log "System Optimizer v$($Config.Version) starting" "SECTION"

# Load modules
if (-not $SkipModuleLoad) {
    $loaded = Import-OptimizerModules
    if (-not $loaded) {
        Write-Host ""
        Write-Host "Modules not loaded. Check modules folder exists." -ForegroundColor Yellow
        Write-Host "Or use the original: .\win11_ultimate_optimization.ps1" -ForegroundColor Yellow
        Write-Host ""
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            exit 1
        }
    }
}

# Direct run mode
if ($RunOption) {
    $optMap = @{
        # Core Optimizations
        'all' = 'Run-AllOptimizations'
        'telemetry' = 'Disable-Telemetry'
        'services' = 'Show-ServicesMenu'
        'bloatware' = 'DebloatBlacklist'
        'tasks' = 'Disable-ScheduledTasks'
        'registry' = 'Set-RegistryOptimizations'
        'vbs' = 'Disable-VBS'
        'network' = 'Set-NetworkOptimizations'
        'onedrive' = 'Remove-OneDrive'
        'maintenance' = 'Start-SystemMaintenance'
        
        # Software & Tools
        'software' = 'Start-PatchMyPC'
        'office' = 'Start-OfficeTool'
        'activation' = 'Run-MAS'
        'drivers' = 'Start-SnappyDriverInstaller'
        
        # Advanced Operations
        'power' = 'Set-PowerPlan'
        'shutup10' = 'Start-OOShutUp10'
        'reset-gpo' = 'Reset-GroupPolicy'
        'reset-wmi' = 'Reset-WMI'
        'cleanup' = 'Start-DiskCleanup'
        'updates' = 'Set-WindowsUpdateControl'
        'reset-network' = 'Reset-Network'
        'repair-updates' = 'Repair-WindowsUpdate'
        'defender' = 'Set-DefenderControl'
        'debloat-all' = 'DebloatAll'
        'winutil-services' = 'Sync-WinUtilServices'
        'privacy' = 'Start-DISMStyleTweaks'
        
        # Utilities
        'wifi' = 'Get-WifiPasswords'
        'verify' = 'Verify-OptimizationStatus'
        'logs' = 'Show-LogViewer'
        'backup' = 'Show-UserBackupMenu'
        'shutdown' = 'Show-ShutdownMenu'
        'rollback' = 'Show-RollbackMenu'
        'hardware' = 'Show-HardwareSummary'
        'profiles' = 'Show-ProfileMenu'
        
        # Deployment Tools
        'vhd' = 'Start-VHDMenu'
        'installer' = 'Start-InstallerMenu'
        'image-tool' = 'Start-ImageToolMenu'
    }
    
    if ($optMap.ContainsKey($RunOption.ToLower())) {
        Write-Log "Running option: $RunOption" "INFO"
        Invoke-OptFunction $optMap[$RunOption.ToLower()]
        
        # Ensure progress displays are cleaned up after direct execution
        if (Get-Command 'Ensure-ProgressCleanup' -ErrorAction SilentlyContinue) {
            Ensure-ProgressCleanup
        }
    } else {
        Write-Log "Unknown option: $RunOption" "ERROR"
        Write-Host ""
        Write-Host "Valid options:" -ForegroundColor Yellow
        Write-Host "Core: $($optMap.Keys | Where-Object { $_ -in @('all','telemetry','services','bloatware','tasks','registry','vbs','network','onedrive','maintenance') } | Sort-Object)" -ForegroundColor Gray
        Write-Host "Software: $($optMap.Keys | Where-Object { $_ -in @('software','office','activation','drivers') } | Sort-Object)" -ForegroundColor Gray
        Write-Host "Advanced: $($optMap.Keys | Where-Object { $_ -like '*-*' -or $_ -in @('power','shutup10','cleanup','updates','defender','privacy') } | Sort-Object)" -ForegroundColor Gray
        Write-Host "Utilities: $($optMap.Keys | Where-Object { $_ -in @('wifi','verify','logs','backup','shutdown','rollback','hardware','profiles') } | Sort-Object)" -ForegroundColor Gray
        Write-Host "Deployment: $($optMap.Keys | Where-Object { $_ -in @('vhd','installer','image-tool') } | Sort-Object)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Use -Help for detailed information about all options" -ForegroundColor Cyan
    }
} else {
    # Interactive mode
    Start-MainMenu
}

Write-Log "Session ended" "INFO"
