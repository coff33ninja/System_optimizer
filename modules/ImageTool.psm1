# ============================================================================
# ImageTool Module - System Optimizer
# ============================================================================
# Converted from Windows-Image-Tool.ps1
# ISO Creation, Windows Installation, and Image Modification Tools
# ============================================================================
# ============================================================================
# WINDOWS IMAGE TOOL - ISO Creation & Windows Installation
# ============================================================================
# Part of System Optimizer - https://github.com/coff33ninja/System_Optimizer
# Inspired by WinUtil MicroWin and NexTool Windows Install
# ============================================================================


$ErrorActionPreference = 'SilentlyContinue'

# ============================================================================
# LOGGING SETUP
# ============================================================================
$script:LogDir = "C:\System_Optimizer\Logs"
$script:LogFile = $null

function Initialize-ImageToolLogging {
    # Ensure log directory exists
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    # Create log file
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $script:LogFile = "$LogDir\ImageTool_$timestamp.log"

    # Write header
    $header = @"
================================================================================
WINDOWS IMAGE TOOL LOG
================================================================================
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Work Directory: $WorkDir
================================================================================

"@
    Add-Content -Path $LogFile -Value $header -ErrorAction SilentlyContinue

    # Cleanup old logs (keep last 30 days)
    Get-ChildItem -Path $LogDir -Filter "ImageTool_*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# Default work directory - can be changed via Settings menu to protect SSD
$script:ConfigFile = "$env:LOCALAPPDATA\System_Optimizer\ImageTool_Config.json"
$script:WorkDir = "C:\System_Optimizer\ImageTool"

# Load saved config if exists
if (Test-Path $ConfigFile) {
    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if ($config.WorkDir -and (Test-Path (Split-Path $config.WorkDir -Parent))) {
            $script:WorkDir = $config.WorkDir
        }
    } catch { }
}

$script:MountDir = "$WorkDir\Mount"
$script:ScratchDir = "$WorkDir\Scratch"
$script:ISODir = "$WorkDir\ISO"

function Write-ImageLog {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $shortTime = Get-Date -Format "HH:mm:ss"

    # Write to log file
    if ($LogFile) {
        $logMessage = "[$timestamp] [$Type] $Message"
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }

    # Write to console with colors
    switch ($Type) {
        "SUCCESS" { Write-Host "[$shortTime] [OK] " -ForegroundColor Green -NoNewline; Write-Host $Message }
        "ERROR"   { Write-Host "[$shortTime] [X] " -ForegroundColor Red -NoNewline; Write-Host $Message }
        "WARNING" { Write-Host "[$shortTime] [!] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "SECTION" { Write-Host "`n[$shortTime] === " -ForegroundColor Cyan -NoNewline; Write-Host $Message -ForegroundColor Cyan -NoNewline; Write-Host " ===" -ForegroundColor Cyan }
        default   { Write-Host "[$shortTime] [-] " -ForegroundColor Gray -NoNewline; Write-Host $Message }
    }
}

# ============================================================================
# CONSOLE WINDOW SIZING - Consistent terminal size
# ============================================================================
$script:ConsoleWidth = 85
$script:ConsoleHeight = 45

function Set-ConsoleSize {
    try {
        if ($Host.Name -eq 'ConsoleHost') {
            $maxWidth = $Host.UI.RawUI.MaxPhysicalWindowSize.Width
            $maxHeight = $Host.UI.RawUI.MaxPhysicalWindowSize.Height
            $Width = [Math]::Min($ConsoleWidth, $maxWidth)
            $Height = [Math]::Min($ConsoleHeight, $maxHeight)

            $bufferSize = $Host.UI.RawUI.BufferSize
            $bufferSize.Width = [Math]::Max($Width, $bufferSize.Width)
            $bufferSize.Height = 9999
            $Host.UI.RawUI.BufferSize = $bufferSize

            $windowSize = $Host.UI.RawUI.WindowSize
            $windowSize.Width = $Width
            $windowSize.Height = $Height
            $Host.UI.RawUI.WindowSize = $windowSize
        }
    } catch { }
}

function Initialize-WorkDirectories {
    # Initialize logging first
    Initialize-ImageToolLogging

    # Set consistent console size
    Set-ConsoleSize

    Write-ImageLog "Initializing work directories..."

    @($WorkDir, $MountDir, $ScratchDir, $ISODir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    Write-ImageLog "Work directories ready at $WorkDir" "SUCCESS"
}

function Update-WorkDirectoryPaths {
    # Update all path variables when WorkDir changes
    $script:MountDir = "$WorkDir\Mount"
    $script:ScratchDir = "$WorkDir\Scratch"
    $script:ISODir = "$WorkDir\ISO"
}

function Show-SettingsMenu {
    Set-ConsoleSize
    Clear-Host
    Write-ImageLog "SETTINGS" "SECTION"

    # Get drive info
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 } |
        Select-Object Name, @{N='FreeGB';E={[math]::Round($_.Free/1GB,1)}}, @{N='UsedGB';E={[math]::Round($_.Used/1GB,1)}}

    Write-Host ""
    Write-Host "  Current Work Directory:" -ForegroundColor Cyan
    Write-Host "    $WorkDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Available Drives:" -ForegroundColor Cyan
    foreach ($drive in $drives) {
        Write-Host "    $($drive.Name): - $($drive.FreeGB) GB free" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  TIP: Use a secondary HDD/SSD to avoid heavy writes on your main drive." -ForegroundColor DarkGray
    Write-Host "       WIM mounting can cause significant disk activity." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Options:" -ForegroundColor Cyan
    Write-Host "  [1] Change work directory"
    Write-Host "  [2] Reset to default (C:\System_Optimizer\ImageTool)"
    Write-Host "  [3] View current paths"
    Write-Host "  [4] View recent logs"
    Write-Host "  [5] Open log folder"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "  Enter new work directory path:" -ForegroundColor Cyan
            Write-Host "  Examples: D:\ImageTool, E:\System_Optimizer\ImageTool" -ForegroundColor Gray
            Write-Host ""
            $newPath = Read-Host "New path"

            if ([string]::IsNullOrEmpty($newPath)) {
                Write-ImageLog "No path entered" "WARNING"
                return
            }

            # Validate drive exists
            $driveLetter = Split-Path $newPath -Qualifier
            if (-not (Test-Path $driveLetter)) {
                Write-ImageLog "Drive $driveLetter does not exist" "ERROR"
                return
            }

            # Check if there are mounted images in current location
            $mounted = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$ScratchDir*" }
            if ($mounted) {
                Write-ImageLog "Cannot change directory while images are mounted!" "ERROR"
                Write-Host "  Please dismount all images first (Option 16)" -ForegroundColor Yellow
                return
            }

            # Ask about moving existing files
            if (Test-Path $WorkDir) {
                Write-Host ""
                $moveFiles = Read-Host "Move existing files to new location? (Y/N)"
                if ($moveFiles -eq "Y" -or $moveFiles -eq "y") {
                    Write-ImageLog "Moving files to $newPath..."
                    if (-not (Test-Path $newPath)) {
                        New-Item -ItemType Directory -Path $newPath -Force | Out-Null
                    }
                    Copy-Item -Path "$WorkDir\*" -Destination $newPath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-ImageLog "Files moved" "SUCCESS"
                }
            }

            # Update and save
            $script:WorkDir = $newPath
            Update-WorkDirectoryPaths

            # Save config
            $configDir = Split-Path $ConfigFile -Parent
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            @{ WorkDir = $newPath } | ConvertTo-Json | Out-File $ConfigFile -Force

            Initialize-WorkDirectories
            Write-ImageLog "Work directory changed to $newPath" "SUCCESS"
        }
        "2" {
            # Check for mounted images
            $mounted = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$ScratchDir*" }
            if ($mounted) {
                Write-ImageLog "Cannot change directory while images are mounted!" "ERROR"
                return
            }

            $script:WorkDir = "C:\System_Optimizer\ImageTool"
            Update-WorkDirectoryPaths

            # Remove config file
            if (Test-Path $ConfigFile) {
                Remove-Item $ConfigFile -Force
            }

            Initialize-WorkDirectories
            Write-ImageLog "Reset to default: $WorkDir" "SUCCESS"
        }
        "3" {
            Write-Host ""
            Write-Host "  Current Paths:" -ForegroundColor Cyan
            Write-Host "    Work Dir:    $WorkDir" -ForegroundColor Gray
            Write-Host "    Mount Dir:   $MountDir" -ForegroundColor Gray
            Write-Host "    Scratch Dir: $ScratchDir" -ForegroundColor Gray
            Write-Host "    ISO Dir:     $ISODir" -ForegroundColor Gray
            Write-Host "    Config File: $ConfigFile" -ForegroundColor Gray
            Write-Host "    Log Dir:     $LogDir" -ForegroundColor Gray
            Write-Host "    Current Log: $LogFile" -ForegroundColor Gray
            Write-Host ""

            # Show disk usage
            if (Test-Path $WorkDir) {
                $size = (Get-ChildItem $WorkDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                $sizeGB = [math]::Round($size / 1GB, 2)
                Write-Host "    Current Usage: $sizeGB GB" -ForegroundColor Yellow
            }
        }
        "4" {
            # View recent logs
            Write-Host ""
            Write-Host "  Recent Log Files:" -ForegroundColor Cyan
            $logs = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 10

            if ($logs) {
                $i = 1
                foreach ($log in $logs) {
                    $errors = (Select-String -Path $log.FullName -Pattern "\[ERROR\]" -ErrorAction SilentlyContinue).Count
                    $warnings = (Select-String -Path $log.FullName -Pattern "\[WARNING\]" -ErrorAction SilentlyContinue).Count
                    $color = if ($errors -gt 0) { "Red" } elseif ($warnings -gt 0) { "Yellow" } else { "Gray" }
                    Write-Host "    [$i] $($log.Name) - E:$errors W:$warnings" -ForegroundColor $color
                    $i++
                }
                Write-Host ""
                $viewChoice = Read-Host "Enter number to view log (or Enter to skip)"
                if ($viewChoice -match '^\d+$') {
                    $selectedLog = $logs[[int]$viewChoice - 1]
                    if ($selectedLog) {
                        Write-Host ""
                        Write-Host "  Last 50 lines of $($selectedLog.Name):" -ForegroundColor Cyan
                        Write-Host ("-" * 60) -ForegroundColor Gray
                        Get-Content $selectedLog.FullName -Tail 50
                    }
                }
            } else {
                Write-Host "    No log files found" -ForegroundColor Yellow
            }
        }
        "5" {
            # Open log folder
            if (Test-Path $LogDir) {
                Start-Process explorer.exe -ArgumentList $LogDir
                Write-ImageLog "Opened log folder: $LogDir" "SUCCESS"
            } else {
                Write-ImageLog "Log folder does not exist yet" "WARNING"
            }
        }
    }
}

function Show-ImageToolMenu {
    Set-ConsoleSize
    Clear-Host
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  WINDOWS IMAGE TOOL" -ForegroundColor Yellow
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ISO Creation & Modification:" -ForegroundColor Gray
    Write-Host "  [1] Create Custom Windows ISO (MicroWin Style)"
    Write-Host "  [2] Mount Windows ISO/WIM for Editing"
    Write-Host "  [3] Apply Tweaks to Mounted Image"
    Write-Host "  [4] Inject Drivers into Image"
    Write-Host "  [5] Remove Bloatware from Image"
    Write-Host "  [6] Create Unattended Answer File"
    Write-Host "  [7] Export/Save Modified Image"
    Write-Host ""
    Write-Host "  Windows Installation:" -ForegroundColor Gray
    Write-Host "  [8] Create Bootable USB from ISO"
    Write-Host "  [9] Download Windows ISO (Official)"
    Write-Host "  [10] Bypass TPM/SecureBoot Requirements"
    Write-Host "  [11] Deploy Windows to Blank Drive" -ForegroundColor Green
    Write-Host ""
    Write-Host "  VHD & Utilities:" -ForegroundColor Gray
    Write-Host "  [12] VHD Native Boot Deployment" -ForegroundColor Green
    Write-Host "  [13] Optimize/Cleanup WIM Image" -ForegroundColor Yellow
    Write-Host "  [14] Download oscdimg.exe (ISO Creator)"
    Write-Host "  [15] Cleanup Work Directories"
    Write-Host "  [16] View Mounted Images"
    Write-Host "  [17] Settings (Change Work Directory)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Current Work Dir: $WorkDir" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [0] Back to Main Menu"
    Write-Host ""
}

# ============================================================================
# ISO SELECTION AND MOUNTING
# ============================================================================
function Select-WindowsISO {
    Write-ImageLog "SELECT WINDOWS ISO" "SECTION"

    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "ISO files (*.iso)|*.iso|All files (*.*)|*.*"
    $dialog.Title = "Select Windows ISO"
    $dialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')

    if ($dialog.ShowDialog() -eq 'OK') {
        return $dialog.FileName
    }
    return $null
}

function Mount-WindowsISO {
    param([string]$ISOPath)

    Write-ImageLog "Mounting ISO: $ISOPath"

    try {
        # Mount the ISO
        $mountResult = Mount-DiskImage -ImagePath $ISOPath -PassThru
        $driveLetter = ($mountResult | Get-Volume).DriveLetter

        if ($driveLetter) {
            Write-ImageLog "ISO mounted at drive $driveLetter`:" "SUCCESS"
            return "${driveLetter}:"
        } else {
            Write-ImageLog "Failed to get drive letter" "ERROR"
            return $null
        }
    } catch {
        Write-ImageLog "Error mounting ISO: $_" "ERROR"
        return $null
    }
}

function Copy-ISOContents {
    param([string]$SourceDrive)

    Write-ImageLog "Copying ISO contents to work directory..."
    Write-Host "This may take several minutes..." -ForegroundColor Yellow

    # Clean and create mount directory
    if (Test-Path $MountDir) {
        Remove-Item -Path $MountDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $MountDir -Force | Out-Null

    # Copy all files
    $source = "$SourceDrive\*"
    Copy-Item -Path $source -Destination $MountDir -Recurse -Force

    # Make install.wim writable
    $installWim = "$MountDir\sources\install.wim"
    $installEsd = "$MountDir\sources\install.esd"

    if (Test-Path $installWim) {
        attrib -R $installWim
        Write-ImageLog "ISO contents copied (WIM format)" "SUCCESS"
    } elseif (Test-Path $installEsd) {
        Write-ImageLog "ESD format detected - will convert to WIM" "WARNING"
    }

    return $true
}

function Get-WindowsImageIndex {
    Write-ImageLog "Available Windows Editions:" "SECTION"

    $wimPath = "$MountDir\sources\install.wim"
    $esdPath = "$MountDir\sources\install.esd"

    $imagePath = if (Test-Path $wimPath) { $wimPath } else { $esdPath }

    if (-not (Test-Path $imagePath)) {
        Write-ImageLog "No install.wim or install.esd found" "ERROR"
        return $null
    }

    $images = Get-WindowsImage -ImagePath $imagePath

    Write-Host ""
    foreach ($img in $images) {
        Write-Host "  [$($img.ImageIndex)] $($img.ImageName)" -ForegroundColor Cyan
        Write-Host "      Size: $([math]::Round($img.ImageSize / 1GB, 2)) GB" -ForegroundColor Gray
    }
    Write-Host ""

    $index = Read-Host "Select edition index"
    return [int]$index
}


# ============================================================================
# IMAGE MODIFICATION FUNCTIONS
# ============================================================================
function Mount-WindowsWIM {
    param([int]$Index)

    Write-ImageLog "Mounting Windows image (Index: $Index)..." "SECTION"

    $wimPath = "$MountDir\sources\install.wim"
    $esdPath = "$MountDir\sources\install.esd"

    # Convert ESD to WIM if needed
    if (-not (Test-Path $wimPath) -and (Test-Path $esdPath)) {
        Write-ImageLog "Converting ESD to WIM format..."
        try {
            Export-WindowsImage -SourceImagePath $esdPath -SourceIndex $Index -DestinationImagePath $wimPath -CompressionType Max
            Remove-Item $esdPath -Force
            $Index = 1  # After export, index becomes 1
            Write-ImageLog "Converted to WIM format" "SUCCESS"
        } catch {
            dism /english /export-image /sourceimagefile:"$esdPath" /sourceindex:$Index /destinationimagefile:"$wimPath" /compress:max
            Remove-Item $esdPath -Force
            $Index = 1
        }
    }

    # Clean scratch directory
    if (Test-Path $ScratchDir) {
        Remove-Item -Path $ScratchDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null

    # Mount the image
    try {
        Mount-WindowsImage -ImagePath $wimPath -Index $Index -Path $ScratchDir
        Write-ImageLog "Image mounted at $ScratchDir" "SUCCESS"
        return $true
    } catch {
        Write-ImageLog "Error mounting image: $_" "ERROR"
        return $false
    }
}

function Apply-ImageTweaks {
    Set-ConsoleSize
    Clear-Host
    Write-ImageLog "APPLYING TWEAKS TO MOUNTED IMAGE" "SECTION"

    if (-not (Test-Path "$ScratchDir\Windows")) {
        Write-ImageLog "No image mounted at $ScratchDir" "ERROR"
        return
    }

    Write-Host ""
    Write-Host "  [1] Apply ALL tweaks (recommended)"
    Write-Host "  [2] Bypass TPM/SecureBoot/RAM checks"
    Write-Host "  [3] Disable telemetry & tracking"
    Write-Host "  [4] Disable sponsored apps & suggestions"
    Write-Host "  [5] Enable local account on OOBE"
    Write-Host "  [6] Skip first logon animation"
    Write-Host "  [7] Set dark theme"
    Write-Host "  [8] Disable Teams auto-install"
    Write-Host "  [9] Create System Optimizer desktop shortcut"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "Select tweak"

    # Load registry hives
    Write-ImageLog "Loading registry hives..."
    reg load HKLM\zSOFTWARE "$ScratchDir\Windows\System32\config\SOFTWARE" 2>$null
    reg load HKLM\zSYSTEM "$ScratchDir\Windows\System32\config\SYSTEM" 2>$null
    reg load HKLM\zDEFAULT "$ScratchDir\Windows\System32\config\default" 2>$null
    reg load HKLM\zNTUSER "$ScratchDir\Users\Default\ntuser.dat" 2>$null

    switch ($choice) {
        "1" {
            Apply-BypassChecks
            Apply-TelemetryTweaks
            Apply-SponsoredAppsTweaks
            Apply-LocalAccountTweaks
            Apply-SkipAnimationTweaks
            Apply-DarkThemeTweaks
            Apply-TeamsDisable
            Create-SystemOptimizerShortcut
        }
        "2" { Apply-BypassChecks }
        "3" { Apply-TelemetryTweaks }
        "4" { Apply-SponsoredAppsTweaks }
        "5" { Apply-LocalAccountTweaks }
        "6" { Apply-SkipAnimationTweaks }
        "7" { Apply-DarkThemeTweaks }
        "8" { Apply-TeamsDisable }
        "9" { Create-SystemOptimizerShortcut }
        "0" { }
    }

    # Unload registry hives
    Write-ImageLog "Unloading registry hives..."
    reg unload HKLM\zSOFTWARE 2>$null
    reg unload HKLM\zSYSTEM 2>$null
    reg unload HKLM\zDEFAULT 2>$null
    reg unload HKLM\zNTUSER 2>$null

    Write-ImageLog "Tweaks applied" "SUCCESS"
}

function Apply-BypassChecks {
    Write-ImageLog "Applying TPM/SecureBoot/RAM bypass..."
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f >$null
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f >$null
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d 1 /f >$null
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassStorageCheck" /t REG_DWORD /d 1 /f >$null
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassCPUCheck" /t REG_DWORD /d 1 /f >$null
    reg add "HKLM\zSYSTEM\Setup\MoSetup" /v "AllowUpgradesWithUnsupportedTPMOrCPU" /t REG_DWORD /d 1 /f >$null
    reg add "HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV1" /t REG_DWORD /d 0 /f >$null
    reg add "HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v "SV2" /t REG_DWORD /d 0 /f >$null
    Write-ImageLog "Bypass checks applied" "SUCCESS"
}

function Apply-TelemetryTweaks {
    Write-ImageLog "Disabling telemetry in image..."
    reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f >$null
    reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f >$null
    reg add "HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d 0 /f >$null
    Write-ImageLog "Telemetry disabled" "SUCCESS"
}

function Apply-SponsoredAppsTweaks {
    Write-ImageLog "Disabling sponsored apps..."
    reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "OemPreInstalledAppsEnabled" /t REG_DWORD /d 0 /f >$null
    reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "PreInstalledAppsEnabled" /t REG_DWORD /d 0 /f >$null
    reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d 0 /f >$null
    reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d 1 /f >$null
    reg add "HKLM\zSOFTWARE\Microsoft\PolicyManager\current\device\Start" /v "ConfigureStartPins" /t REG_SZ /d '{"pinnedList": [{}]}' /f >$null
    Write-ImageLog "Sponsored apps disabled" "SUCCESS"
}

function Apply-LocalAccountTweaks {
    Write-ImageLog "Enabling local account on OOBE..."
    reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v "BypassNRO" /t REG_DWORD /d 1 /f >$null
    # Create bypass directory
    New-Item -ItemType Directory -Force -Path "$ScratchDir\Windows\System32\OOBE\BYPASSNRO" | Out-Null
    Write-ImageLog "Local account enabled" "SUCCESS"
}

function Apply-SkipAnimationTweaks {
    Write-ImageLog "Skipping first logon animation..."
    reg add "HKLM\zSOFTWARE\Microsoft\Active Setup\Installed Components\CMP_NoFla" /f >$null
    reg add "HKLM\zSOFTWARE\Microsoft\Active Setup\Installed Components\CMP_NoFla" /ve /t REG_SZ /d "Stop First Logon Animation" /f >$null
    reg add "HKLM\zSOFTWARE\Microsoft\Active Setup\Installed Components\CMP_NoFla" /v StubPath /t REG_EXPAND_SZ /d '"%WINDIR%\System32\cmd.exe" /C "taskkill /f /im firstlogonanim.exe"' /f >$null
    Write-ImageLog "First logon animation disabled" "SUCCESS"
}

function Apply-DarkThemeTweaks {
    Write-ImageLog "Setting dark theme..."
    reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t REG_DWORD /d 0 /f >$null
    reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "SystemUsesLightTheme" /t REG_DWORD /d 0 /f >$null
    Write-ImageLog "Dark theme set" "SUCCESS"
}

function Apply-TeamsDisable {
    Write-ImageLog "Disabling Teams auto-install..."
    reg add "HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v "ConfigureChatAutoInstall" /t REG_DWORD /d 0 /f >$null
    reg add "HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v "ChatIcon" /t REG_DWORD /d 2 /f >$null
    reg add "HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarMn" /t REG_DWORD /d 0 /f >$null
    Write-ImageLog "Teams disabled" "SUCCESS"
}


# ============================================================================
# DRIVER INJECTION
# ============================================================================
function Inject-Drivers {
    Set-ConsoleSize
    Clear-Host
    Write-ImageLog "INJECT DRIVERS INTO IMAGE" "SECTION"

    if (-not (Test-Path "$ScratchDir\Windows")) {
        Write-ImageLog "No image mounted at $ScratchDir" "ERROR"
        return
    }

    Write-Host ""
    Write-Host "  [1] Export drivers from current system"
    Write-Host "  [2] Select driver folder manually"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            $driverExport = "$WorkDir\DriverExport"
            if (Test-Path $driverExport) { Remove-Item $driverExport -Recurse -Force }
            New-Item -ItemType Directory -Path $driverExport -Force | Out-Null

            Write-ImageLog "Exporting drivers from current system..."
            dism /online /export-driver /destination:"$driverExport"

            Write-ImageLog "Injecting drivers into image..."
            dism /image:"$ScratchDir" /add-driver /driver:"$driverExport" /recurse
            Write-ImageLog "Drivers injected" "SUCCESS"
        }
        "2" {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Select folder containing drivers"

            if ($dialog.ShowDialog() -eq 'OK') {
                $driverPath = $dialog.SelectedPath
                Write-ImageLog "Injecting drivers from $driverPath..."
                dism /image:"$ScratchDir" /add-driver /driver:"$driverPath" /recurse
                Write-ImageLog "Drivers injected" "SUCCESS"
            }
        }
    }
}

# ============================================================================
# BLOATWARE REMOVAL FROM IMAGE
# ============================================================================
function Remove-ImageBloatware {
    Set-ConsoleSize
    Clear-Host
    Write-ImageLog "REMOVE BLOATWARE FROM IMAGE" "SECTION"

    if (-not (Test-Path "$ScratchDir\Windows")) {
        Write-ImageLog "No image mounted at $ScratchDir" "ERROR"
        return
    }

    Write-Host ""
    Write-Host "  [1] Remove ALL bloatware (recommended)"
    Write-Host "  [2] Remove provisioned packages only"
    Write-Host "  [3] Remove Windows features"
    Write-Host "  [4] Remove specific folders (OneDrive, IE, etc.)"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Remove-ProvisionedPackages
            Remove-WindowsFeatures
            Remove-BloatFolders
        }
        "2" { Remove-ProvisionedPackages }
        "3" { Remove-WindowsFeatures }
        "4" { Remove-BloatFolders }
    }
}

function Remove-ProvisionedPackages {
    Write-ImageLog "Removing provisioned packages..."

    $packagesToRemove = @(
        "*3DBuilder*", "*3DViewer*", "*BingWeather*", "*BingNews*",
        "*GetHelp*", "*Getstarted*", "*MicrosoftOfficeHub*",
        "*MicrosoftSolitaireCollection*", "*MixedReality*",
        "*OneNote*", "*People*", "*Print3D*", "*SkypeApp*",
        "*Wallet*", "*WindowsAlarms*", "*WindowsFeedbackHub*",
        "*WindowsMaps*", "*WindowsSoundRecorder*", "*Xbox*",
        "*YourPhone*", "*ZuneMusic*", "*ZuneVideo*",
        "*Clipchamp*", "*Teams*", "*ToDo*", "*Family*"
    )

    $packages = Get-AppxProvisionedPackage -Path $ScratchDir

    foreach ($pattern in $packagesToRemove) {
        $matches = $packages | Where-Object { $_.PackageName -like $pattern }
        foreach ($pkg in $matches) {
            try {
                Remove-AppxProvisionedPackage -Path $ScratchDir -PackageName $pkg.PackageName -ErrorAction SilentlyContinue
                Write-ImageLog "Removed: $($pkg.DisplayName)" "SUCCESS"
            } catch {
                Write-ImageLog "Could not remove: $($pkg.DisplayName)" "WARNING"
            }
        }
    }
}

function Remove-WindowsFeatures {
    Write-ImageLog "Removing Windows features..."

    $featuresToDisable = @(
        "Internet-Explorer-Optional-amd64",
        "MediaPlayback",
        "WindowsMediaPlayer",
        "WorkFolders-Client"
    )

    foreach ($feature in $featuresToDisable) {
        try {
            Disable-WindowsOptionalFeature -Path $ScratchDir -FeatureName $feature -Remove -ErrorAction SilentlyContinue
            Write-ImageLog "Disabled: $feature" "SUCCESS"
        } catch {
            Write-ImageLog "Could not disable: $feature" "WARNING"
        }
    }
}

function Remove-BloatFolders {
    Write-ImageLog "Removing bloat folders..."

    $foldersToRemove = @(
        "$ScratchDir\Windows\System32\OneDriveSetup.exe",
        "$ScratchDir\Windows\System32\OneDrive.ico",
        "$ScratchDir\Windows\DiagTrack",
        "$ScratchDir\Windows\InboxApps",
        "$ScratchDir\Program Files\Windows Media Player",
        "$ScratchDir\Program Files (x86)\Windows Media Player",
        "$ScratchDir\Program Files\Internet Explorer",
        "$ScratchDir\Program Files (x86)\Internet Explorer",
        "$ScratchDir\Windows\GameBarPresenceWriter"
    )

    foreach ($folder in $foldersToRemove) {
        if (Test-Path $folder) {
            try {
                Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                Write-ImageLog "Removed: $folder" "SUCCESS"
            } catch {
                Write-ImageLog "Could not remove: $folder" "WARNING"
            }
        }
    }
}

# ============================================================================
# UNATTENDED ANSWER FILE
# ============================================================================
function Create-UnattendFile {
    Write-ImageLog "CREATE UNATTENDED ANSWER FILE" "SECTION"

    Write-Host ""
    $userName = Read-Host "Enter default username (or press Enter for 'User')"
    if ([string]::IsNullOrEmpty($userName)) { $userName = "User" }

    $userPassword = Read-Host "Enter password (or press Enter for no password)"

    $unattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserData>
                <ProductKey>
                    <Key></Key>
                    <WillShowUI>OnError</WillShowUI>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
            </UserData>
        </component>
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>false</HideLocalAccountScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>false</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Name>$userName</Name>
                        <Group>Administrators</Group>
                        <DisplayName>$userName</DisplayName>
"@

    if (-not [string]::IsNullOrEmpty($userPassword)) {
        $unattendContent += @"

                        <Password>
                            <Value>$userPassword</Value>
                            <PlainText>true</PlainText>
                        </Password>
"@
    }

    $unattendContent += @"

                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>powershell -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/run_optimization.bat' -OutFile '$env:TEMP\SystemOptimizer.bat'; & '$env:TEMP\SystemOptimizer.bat'"</CommandLine>
                    <Description>Run System Optimizer</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
"@

    # Save unattend file
    $unattendPath = "$env:TEMP\unattend.xml"
    $unattendContent | Out-File -FilePath $unattendPath -Encoding UTF8 -Force

    Write-ImageLog "Unattend file created at $unattendPath" "SUCCESS"

    # Copy to image if mounted
    if (Test-Path "$ScratchDir\Windows") {
        New-Item -ItemType Directory -Force -Path "$ScratchDir\Windows\Panther" | Out-Null
        Copy-Item $unattendPath "$ScratchDir\Windows\Panther\unattend.xml" -Force
        New-Item -ItemType Directory -Force -Path "$ScratchDir\Windows\System32\Sysprep" | Out-Null
        Copy-Item $unattendPath "$ScratchDir\Windows\System32\Sysprep\unattend.xml" -Force
        Write-ImageLog "Unattend file copied to mounted image" "SUCCESS"
    }
}


# ============================================================================
# CREATE DESKTOP SHORTCUT FOR SYSTEM OPTIMIZER
# ============================================================================
function Create-SystemOptimizerShortcut {
    Write-ImageLog "Creating System Optimizer desktop shortcut..."

    if (-not (Test-Path "$ScratchDir\Windows")) {
        Write-ImageLog "No image mounted" "ERROR"
        return
    }

    # Create shortcut in Default User's Desktop (appears for all new users)
    $defaultDesktop = "$ScratchDir\Users\Default\Desktop"

    # Also create in Public Desktop (appears for all users immediately)
    $publicDesktop = "$ScratchDir\Users\Public\Desktop"

    # Ensure directories exist
    New-Item -ItemType Directory -Force -Path $defaultDesktop -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Force -Path $publicDesktop -ErrorAction SilentlyContinue | Out-Null

    # Create a proper .lnk shortcut that downloads and runs the batch file
    try {
        $vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
Set shortcut = WshShell.CreateShortcut("$defaultDesktop\System Optimizer.lnk")
shortcut.TargetPath = "powershell.exe"
shortcut.Arguments = "-ExecutionPolicy Bypass -Command ""irm 'https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/run_optimization.bat' -OutFile """"%TEMP%\SystemOptimizer.bat""""; & """"%TEMP%\SystemOptimizer.bat"""""""
shortcut.Description = "System Optimizer - Windows Optimization Toolkit"
shortcut.WorkingDirectory = "%USERPROFILE%"
shortcut.IconLocation = "%SystemRoot%\System32\shell32.dll,14"
shortcut.Save

Set shortcut2 = WshShell.CreateShortcut("$publicDesktop\System Optimizer.lnk")
shortcut2.TargetPath = "powershell.exe"
shortcut2.Arguments = "-ExecutionPolicy Bypass -Command ""irm 'https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/run_optimization.bat' -OutFile """"%TEMP%\SystemOptimizer.bat""""; & """"%TEMP%\SystemOptimizer.bat"""""""
shortcut2.Description = "System Optimizer - Windows Optimization Toolkit"
shortcut2.WorkingDirectory = "%USERPROFILE%"
shortcut2.IconLocation = "%SystemRoot%\System32\shell32.dll,14"
shortcut2.Save
"@
        $vbsPath = "$env:TEMP\create_shortcut.vbs"
        $vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force

        # Execute VBS to create .lnk files
        & cscript.exe //nologo $vbsPath

        Write-ImageLog "Desktop shortcut created in Default and Public profiles" "SUCCESS"
    } catch {
        Write-ImageLog "Could not create shortcut: $($_.Exception.Message)" "WARNING"
    }
}

# ============================================================================
# SAVE/EXPORT IMAGE
# ============================================================================
function Save-ModifiedImage {
    Write-ImageLog "SAVE MODIFIED IMAGE" "SECTION"

    if (-not (Test-Path "$ScratchDir\Windows")) {
        Write-ImageLog "No image mounted at $ScratchDir" "ERROR"
        return
    }

    # Optional cleanup - only offer if user wants to optimize size
    Write-Host ""
    Write-Host "  Options:" -ForegroundColor Cyan
    Write-Host "  [1] Save only (fast, recommended)"
    Write-Host "  [2] Cleanup + Save (slower, reduces WIM size)"
    Write-Host ""
    $saveChoice = Read-Host "Select option (default: 1)"

    if ($saveChoice -eq "2") {
        Write-ImageLog "Running image cleanup (this may take a while)..."
        $cleanupResult = dism /image:$ScratchDir /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ImageLog "Cleanup failed - continuing with save..." "WARNING"
        } else {
            Write-ImageLog "Cleanup completed" "SUCCESS"
        }
    }

    Write-ImageLog "Unmounting and saving image..."
    Dismount-WindowsImage -Path $ScratchDir -Save

    Write-ImageLog "Image saved successfully" "SUCCESS"

    # Ask if user wants to create ISO
    Write-Host ""
    $createISO = Read-Host "Create ISO from modified image? (Y/N)"
    if ($createISO -eq "Y" -or $createISO -eq "y") {
        Create-CustomISO
    }
}

# ============================================================================
# WIM IMAGE OPTIMIZATION/CLEANUP
# ============================================================================
function Optimize-WIMImage {
    Set-ConsoleSize
    Clear-Host
    Write-ImageLog "OPTIMIZE/CLEANUP WIM IMAGE" "SECTION"

    Write-Host ""
    Write-Host "  This tool optimizes WIM files to reduce size." -ForegroundColor Cyan
    Write-Host "  Works on both mounted images and standalone WIM files." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [1] Optimize mounted image (at $ScratchDir)"
    Write-Host "  [2] Optimize standalone WIM file"
    Write-Host "  [3] Export single edition from multi-edition WIM (reduces size)"
    Write-Host "  [4] Convert ESD to WIM"
    Write-Host "  [5] Compress WIM (recompress with max compression)"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            # Optimize mounted image
            if (-not (Test-Path "$ScratchDir\Windows")) {
                Write-ImageLog "No image mounted at $ScratchDir" "ERROR"
                return
            }

            Write-Host ""
            Write-Host "  Cleanup options:" -ForegroundColor Cyan
            Write-Host "  [1] Quick cleanup (StartComponentCleanup)"
            Write-Host "  [2] Full cleanup with ResetBase (removes rollback ability)"
            Write-Host "  [3] Analyze only (show reclaimable space)"
            Write-Host ""
            $cleanType = Read-Host "Select cleanup type"

            switch ($cleanType) {
                "1" {
                    Write-ImageLog "Running quick cleanup..."
                    dism /image:$ScratchDir /Cleanup-Image /StartComponentCleanup
                }
                "2" {
                    Write-ImageLog "Running full cleanup with ResetBase..."
                    Write-Host "  Warning: This removes ability to uninstall updates!" -ForegroundColor Yellow
                    $confirm = Read-Host "Continue? (Y/N)"
                    if ($confirm -eq "Y" -or $confirm -eq "y") {
                        dism /image:$ScratchDir /Cleanup-Image /StartComponentCleanup /ResetBase
                    }
                }
                "3" {
                    Write-ImageLog "Analyzing image..."
                    dism /image:$ScratchDir /Cleanup-Image /AnalyzeComponentStore
                }
            }
        }
        "2" {
            # Optimize standalone WIM
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "WIM files (*.wim)|*.wim"
            $dialog.Title = "Select WIM file to optimize"

            if ($dialog.ShowDialog() -eq 'OK') {
                $wimPath = $dialog.FileName
                $tempMount = "$WorkDir\TempMount"

                # Create temp mount point
                if (-not (Test-Path $tempMount)) {
                    New-Item -ItemType Directory -Path $tempMount -Force | Out-Null
                }

                Write-ImageLog "Mounting WIM for cleanup..."
                Mount-WindowsImage -ImagePath $wimPath -Index 1 -Path $tempMount

                Write-ImageLog "Running cleanup..."
                dism /image:$tempMount /Cleanup-Image /StartComponentCleanup /ResetBase

                Write-ImageLog "Saving changes..."
                Dismount-WindowsImage -Path $tempMount -Save

                Write-ImageLog "WIM optimized" "SUCCESS"
            }
        }
        "3" {
            # Export single edition
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "WIM/ESD files (*.wim;*.esd)|*.wim;*.esd"
            $dialog.Title = "Select source WIM/ESD"

            if ($dialog.ShowDialog() -eq 'OK') {
                $sourcePath = $dialog.FileName

                # Show editions
                Write-Host ""
                Write-Host "  Available editions:" -ForegroundColor Cyan
                $images = Get-WindowsImage -ImagePath $sourcePath
                foreach ($img in $images) {
                    $sizeGB = [math]::Round($img.ImageSize / 1GB, 2)
                    Write-Host "    [$($img.ImageIndex)] $($img.ImageName) - $sizeGB GB" -ForegroundColor Gray
                }
                Write-Host ""

                $index = Read-Host "Select edition index to export"

                $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
                $saveDialog.Filter = "WIM files (*.wim)|*.wim"
                $saveDialog.Title = "Save exported WIM"
                $saveDialog.FileName = "install.wim"

                if ($saveDialog.ShowDialog() -eq 'OK') {
                    $destPath = $saveDialog.FileName

                    Write-ImageLog "Exporting edition $index..."
                    Export-WindowsImage -SourceImagePath $sourcePath -SourceIndex $index -DestinationImagePath $destPath -CompressionType Max

                    $newSize = [math]::Round((Get-Item $destPath).Length / 1GB, 2)
                    Write-ImageLog "Exported to $destPath ($newSize GB)" "SUCCESS"
                }
            }
        }
        "4" {
            # Convert ESD to WIM
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "ESD files (*.esd)|*.esd"
            $dialog.Title = "Select ESD file"

            if ($dialog.ShowDialog() -eq 'OK') {
                $esdPath = $dialog.FileName

                # Show editions
                Write-Host ""
                Write-Host "  Available editions:" -ForegroundColor Cyan
                $images = Get-WindowsImage -ImagePath $esdPath
                foreach ($img in $images) {
                    Write-Host "    [$($img.ImageIndex)] $($img.ImageName)" -ForegroundColor Gray
                }
                Write-Host ""

                $index = Read-Host "Select edition index (or 'all' for all editions)"

                $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
                $saveDialog.Filter = "WIM files (*.wim)|*.wim"
                $saveDialog.Title = "Save WIM file"
                $saveDialog.FileName = "install.wim"

                if ($saveDialog.ShowDialog() -eq 'OK') {
                    $wimPath = $saveDialog.FileName

                    if ($index -eq "all") {
                        Write-ImageLog "Converting all editions..."
                        foreach ($img in $images) {
                            Write-ImageLog "Exporting $($img.ImageName)..."
                            Export-WindowsImage -SourceImagePath $esdPath -SourceIndex $img.ImageIndex -DestinationImagePath $wimPath -CompressionType Max
                        }
                    } else {
                        Write-ImageLog "Converting edition $index..."
                        Export-WindowsImage -SourceImagePath $esdPath -SourceIndex $index -DestinationImagePath $wimPath -CompressionType Max
                    }

                    Write-ImageLog "Converted to $wimPath" "SUCCESS"
                }
            }
        }
        "5" {
            # Recompress WIM
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "WIM files (*.wim)|*.wim"
            $dialog.Title = "Select WIM to recompress"

            if ($dialog.ShowDialog() -eq 'OK') {
                $sourcePath = $dialog.FileName

                $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
                $saveDialog.Filter = "WIM files (*.wim)|*.wim"
                $saveDialog.Title = "Save recompressed WIM"
                $saveDialog.FileName = "install_compressed.wim"

                if ($saveDialog.ShowDialog() -eq 'OK') {
                    $destPath = $saveDialog.FileName

                    $origSize = [math]::Round((Get-Item $sourcePath).Length / 1GB, 2)
                    Write-ImageLog "Original size: $origSize GB"

                    Write-ImageLog "Recompressing with maximum compression..."
                    $images = Get-WindowsImage -ImagePath $sourcePath
                    foreach ($img in $images) {
                        Write-ImageLog "Processing $($img.ImageName)..."
                        Export-WindowsImage -SourceImagePath $sourcePath -SourceIndex $img.ImageIndex -DestinationImagePath $destPath -CompressionType Max
                    }

                    $newSize = [math]::Round((Get-Item $destPath).Length / 1GB, 2)
                    $saved = $origSize - $newSize
                    Write-ImageLog "New size: $newSize GB (saved $saved GB)" "SUCCESS"
                }
            }
        }
    }
}

function Create-CustomISO {
    Write-ImageLog "CREATE CUSTOM ISO" "SECTION"

    # Check for oscdimg
    $oscdimgPath = "$WorkDir\oscdimg.exe"
    if (-not (Test-Path $oscdimgPath)) {
        $oscdimgPath = Get-Command oscdimg.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if (-not $oscdimgPath) {
            Write-ImageLog "oscdimg.exe not found. Downloading..." "WARNING"
            Download-Oscdimg
            $oscdimgPath = "$WorkDir\oscdimg.exe"
        }
    }

    if (-not (Test-Path $oscdimgPath)) {
        Write-ImageLog "oscdimg.exe still not found. Cannot create ISO." "ERROR"
        return
    }

    # Get output path
    Add-Type -AssemblyName System.Windows.Forms
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "ISO files (*.iso)|*.iso"
    $saveDialog.Title = "Save Custom Windows ISO"
    $saveDialog.FileName = "Windows_Custom_$(Get-Date -Format 'yyyyMMdd').iso"
    $saveDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')

    if ($saveDialog.ShowDialog() -ne 'OK') {
        Write-ImageLog "ISO creation cancelled" "WARNING"
        return
    }

    $outputISO = $saveDialog.FileName

    Write-ImageLog "Creating ISO at $outputISO..."
    Write-Host "This may take several minutes..." -ForegroundColor Yellow

    # Build ISO using oscdimg
    $bootData = "2#p0,e,b`"$MountDir\boot\etfsboot.com`"#pEF,e,b`"$MountDir\efi\microsoft\boot\efisys.bin`""

    $process = Start-Process -FilePath $oscdimgPath -ArgumentList "-m -o -u2 -udfver102 -bootdata:$bootData `"$MountDir`" `"$outputISO`"" -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-ImageLog "ISO created successfully: $outputISO" "SUCCESS"

        # Get file size
        $size = [math]::Round((Get-Item $outputISO).Length / 1GB, 2)
        Write-Host "ISO Size: $size GB" -ForegroundColor Cyan
    } else {
        Write-ImageLog "ISO creation failed with exit code $($process.ExitCode)" "ERROR"
    }
}

# ============================================================================
# BOOTABLE USB CREATION
# ============================================================================
function Create-BootableUSB {
    Write-ImageLog "CREATE BOOTABLE USB" "SECTION"

    # List available USB drives
    $usbDrives = Get-Disk | Where-Object { $_.BusType -eq 'USB' }

    if ($usbDrives.Count -eq 0) {
        Write-ImageLog "No USB drives detected" "ERROR"
        return
    }

    Write-Host ""
    Write-Host "Available USB Drives:" -ForegroundColor Cyan
    foreach ($drive in $usbDrives) {
        $size = [math]::Round($drive.Size / 1GB, 2)
        Write-Host "  Disk $($drive.Number): $($drive.FriendlyName) - $size GB" -ForegroundColor Yellow
    }
    Write-Host ""

    $diskNum = Read-Host "Enter disk number (WARNING: ALL DATA WILL BE ERASED)"
    $confirm = Read-Host "Are you sure you want to format Disk $diskNum? (YES to confirm)"

    if ($confirm -ne "YES") {
        Write-ImageLog "USB creation cancelled" "WARNING"
        return
    }

    # Select ISO source
    Write-Host ""
    Write-Host "  [1] Use modified image from work directory"
    Write-Host "  [2] Select ISO file"
    Write-Host ""
    $sourceChoice = Read-Host "Select source"

    $sourcePath = $null
    switch ($sourceChoice) {
        "1" {
            if (Test-Path "$MountDir\sources\install.wim") {
                $sourcePath = $MountDir
            } else {
                Write-ImageLog "No modified image found in work directory" "ERROR"
                return
            }
        }
        "2" {
            $isoPath = Select-WindowsISO
            if ($isoPath) {
                $mountedDrive = Mount-WindowsISO -ISOPath $isoPath
                $sourcePath = $mountedDrive
            }
        }
    }

    if (-not $sourcePath) {
        Write-ImageLog "No source selected" "ERROR"
        return
    }

    Write-ImageLog "Formatting USB drive..."

    # Format the USB drive
    $disk = Get-Disk -Number $diskNum
    $disk | Clear-Disk -RemoveData -Confirm:$false
    $disk | Initialize-Disk -PartitionStyle GPT

    # Create EFI partition
    $efiPartition = New-Partition -DiskNumber $diskNum -Size 100MB -GptType "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"
    Format-Volume -Partition $efiPartition -FileSystem FAT32 -NewFileSystemLabel "EFI" -Confirm:$false
    $efiPartition | Add-PartitionAccessPath -AssignDriveLetter
    $efiLetter = $efiPartition.DriveLetter

    # Create main partition
    $mainPartition = New-Partition -DiskNumber $diskNum -UseMaximumSize
    Format-Volume -Partition $mainPartition -FileSystem NTFS -NewFileSystemLabel "WINDOWS" -Confirm:$false
    $mainPartition | Add-PartitionAccessPath -AssignDriveLetter
    $mainLetter = $mainPartition.DriveLetter

    Write-ImageLog "Copying files to USB..."

    # Copy boot files to EFI partition
    robocopy "$sourcePath\efi" "${efiLetter}:\efi" /E /NFL /NDL /NJH /NJS

    # Copy all files to main partition
    robocopy "$sourcePath" "${mainLetter}:\" /E /NFL /NDL /NJH /NJS

    Write-ImageLog "Bootable USB created successfully!" "SUCCESS"

    # Unmount ISO if we mounted one
    if ($sourceChoice -eq "2" -and $isoPath) {
        Dismount-DiskImage -ImagePath $isoPath
    }
}

# ============================================================================
# DOWNLOAD WINDOWS ISO
# ============================================================================
function Download-WindowsISO {
    Write-ImageLog "DOWNLOAD WINDOWS ISO" "SECTION"

    Write-Host ""
    Write-Host "  [1] Open Microsoft Software Download page"
    Write-Host "  [2] Use Media Creation Tool"
    Write-Host "  [3] Direct download links (unofficial)"
    Write-Host "  [0] Back"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Start-Process "https://www.microsoft.com/software-download/windows11"
            Write-ImageLog "Opened Microsoft download page" "SUCCESS"
        }
        "2" {
            $mctUrl = "https://go.microsoft.com/fwlink/?linkid=2156295"
            $mctPath = "$WorkDir\MediaCreationTool.exe"

            Write-ImageLog "Downloading Media Creation Tool..."
            Invoke-WebRequest -Uri $mctUrl -OutFile $mctPath -UseBasicParsing

            Write-ImageLog "Launching Media Creation Tool..."
            Start-Process -FilePath $mctPath -Wait
        }
        "3" {
            Write-Host ""
            Write-Host "Unofficial direct download sources:" -ForegroundColor Yellow
            Write-Host "  - https://massgrave.dev/windows_11_links" -ForegroundColor Cyan
            Write-Host "  - https://files.rg-adguard.net/" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Press any key to open massgrave.dev..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Start-Process "https://massgrave.dev/windows_11_links"
        }
    }
}

# ============================================================================
# UTILITIES
# ============================================================================
function Download-Oscdimg {
    Write-ImageLog "Downloading oscdimg.exe..."

    # Try to download from WinUtil releases or other source
    $oscdimgUrl = "https://github.com/ChrisTitusTech/winutil/raw/main/releases/oscdimg.exe"
    $oscdimgPath = "$WorkDir\oscdimg.exe"

    try {
        Invoke-WebRequest -Uri $oscdimgUrl -OutFile $oscdimgPath -UseBasicParsing
        Write-ImageLog "oscdimg.exe downloaded" "SUCCESS"
    } catch {
        Write-ImageLog "Failed to download oscdimg.exe: $_" "ERROR"
        Write-Host ""
        Write-Host "You can manually download oscdimg.exe from:" -ForegroundColor Yellow
        Write-Host "  - Windows ADK (Assessment and Deployment Kit)" -ForegroundColor Cyan
        Write-Host "  - https://github.com/ChrisTitusTech/winutil/raw/main/releases/oscdimg.exe" -ForegroundColor Cyan
    }
}

function Cleanup-WorkDirectories {
    Write-ImageLog "CLEANUP WORK DIRECTORIES" "SECTION"

    Write-Host ""
    Write-Host "This will delete all files in:" -ForegroundColor Yellow
    Write-Host "  $WorkDir" -ForegroundColor Cyan
    Write-Host ""

    $confirm = Read-Host "Are you sure? (YES to confirm)"

    if ($confirm -eq "YES") {
        # Unmount any mounted images first
        try {
            Dismount-WindowsImage -Path $ScratchDir -Discard -ErrorAction SilentlyContinue
        } catch { }

        # Unmount any mounted ISOs
        Get-DiskImage | Where-Object { $_.ImagePath -like "*.iso" } | Dismount-DiskImage -ErrorAction SilentlyContinue

        # Remove directories
        if (Test-Path $WorkDir) {
            Remove-Item -Path $WorkDir -Recurse -Force
            Write-ImageLog "Work directories cleaned" "SUCCESS"
        }
    } else {
        Write-ImageLog "Cleanup cancelled" "WARNING"
    }
}

function Show-MountedImages {
    Write-ImageLog "MOUNTED IMAGES" "SECTION"

    $mounted = Get-WindowsImage -Mounted

    if ($mounted.Count -eq 0) {
        Write-Host "No Windows images currently mounted" -ForegroundColor Yellow
    } else {
        foreach ($img in $mounted) {
            Write-Host ""
            Write-Host "Path: $($img.Path)" -ForegroundColor Cyan
            Write-Host "Image: $($img.ImagePath)" -ForegroundColor Gray
            Write-Host "Index: $($img.ImageIndex)" -ForegroundColor Gray
            Write-Host "Status: $($img.MountStatus)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    $dismount = Read-Host "Dismount all images? (Y/N)"
    if ($dismount -eq "Y" -or $dismount -eq "y") {
        foreach ($img in $mounted) {
            Write-ImageLog "Dismounting $($img.Path)..."
            Dismount-WindowsImage -Path $img.Path -Discard
        }
        Write-ImageLog "All images dismounted" "SUCCESS"
    }
}


# ============================================================================
# QUICK CREATE CUSTOM ISO (ALL-IN-ONE)
# ============================================================================
function Start-QuickCustomISO {
    Write-ImageLog "QUICK CREATE CUSTOM WINDOWS ISO" "SECTION"

    Write-Host ""
    Write-Host "This wizard will guide you through creating a custom Windows ISO" -ForegroundColor Cyan
    Write-Host "with bloatware removed, tweaks applied, and System Optimizer auto-run." -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Select ISO
    Write-Host "Step 1: Select Windows ISO" -ForegroundColor Yellow
    $isoPath = Select-WindowsISO
    if (-not $isoPath) {
        Write-ImageLog "No ISO selected" "ERROR"
        return
    }

    # Step 2: Mount and copy
    Write-Host ""
    Write-Host "Step 2: Mounting ISO and copying contents..." -ForegroundColor Yellow
    Initialize-WorkDirectories
    $mountedDrive = Mount-WindowsISO -ISOPath $isoPath
    if (-not $mountedDrive) { return }

    Copy-ISOContents -SourceDrive $mountedDrive
    Dismount-DiskImage -ImagePath $isoPath

    # Step 3: Select edition
    Write-Host ""
    Write-Host "Step 3: Select Windows Edition" -ForegroundColor Yellow
    $index = Get-WindowsImageIndex
    if (-not $index) { return }

    # Step 4: Mount WIM
    Write-Host ""
    Write-Host "Step 4: Mounting Windows image..." -ForegroundColor Yellow
    $mounted = Mount-WindowsWIM -Index $index
    if (-not $mounted) { return }

    # Step 5: Apply tweaks
    Write-Host ""
    Write-Host "Step 5: Applying tweaks..." -ForegroundColor Yellow

    # Load registry
    reg load HKLM\zSOFTWARE "$ScratchDir\Windows\System32\config\SOFTWARE" 2>$null
    reg load HKLM\zSYSTEM "$ScratchDir\Windows\System32\config\SYSTEM" 2>$null
    reg load HKLM\zDEFAULT "$ScratchDir\Windows\System32\config\default" 2>$null
    reg load HKLM\zNTUSER "$ScratchDir\Users\Default\ntuser.dat" 2>$null

    Apply-BypassChecks
    Apply-TelemetryTweaks
    Apply-SponsoredAppsTweaks
    Apply-LocalAccountTweaks
    Apply-SkipAnimationTweaks
    Apply-DarkThemeTweaks
    Apply-TeamsDisable

    # Unload registry
    reg unload HKLM\zSOFTWARE 2>$null
    reg unload HKLM\zSYSTEM 2>$null
    reg unload HKLM\zDEFAULT 2>$null
    reg unload HKLM\zNTUSER 2>$null

    # Step 6: Remove bloatware
    Write-Host ""
    Write-Host "Step 6: Removing bloatware..." -ForegroundColor Yellow
    Remove-ProvisionedPackages
    Remove-BloatFolders

    # Step 7: Create unattend with System Optimizer
    Write-Host ""
    Write-Host "Step 7: Creating unattend file with System Optimizer auto-run..." -ForegroundColor Yellow

    $unattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserData>
                <AcceptEula>true</AcceptEula>
            </UserData>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>powershell -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/run_optimization.bat' -OutFile '$env:TEMP\SystemOptimizer.bat'; & '$env:TEMP\SystemOptimizer.bat'"</CommandLine>
                    <Description>Run System Optimizer</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
"@

    New-Item -ItemType Directory -Force -Path "$ScratchDir\Windows\Panther" | Out-Null
    $unattendContent | Out-File -FilePath "$ScratchDir\Windows\Panther\unattend.xml" -Encoding UTF8 -Force
    New-Item -ItemType Directory -Force -Path "$ScratchDir\Windows\System32\Sysprep" | Out-Null
    $unattendContent | Out-File -FilePath "$ScratchDir\Windows\System32\Sysprep\unattend.xml" -Encoding UTF8 -Force

    # Step 7b: Create desktop shortcut for System Optimizer in Default User profile
    Write-Host "Creating System Optimizer shortcut on default desktop..." -ForegroundColor Yellow
    Create-SystemOptimizerShortcut

    # Step 8: Save and create ISO
    Write-Host ""
    Write-Host "Step 8: Saving image..." -ForegroundColor Yellow

    Write-ImageLog "Unmounting and saving image (skipping cleanup to avoid errors)..."
    Write-Host "  Tip: You can optimize WIM size later by mounting and running cleanup separately." -ForegroundColor Gray
    Dismount-WindowsImage -Path $ScratchDir -Save

    Create-CustomISO

    Write-ImageLog "Custom Windows ISO creation complete!" "SUCCESS"
}

# ============================================================================
# WINDOWS INSTALLER (DEPLOY TO BLANK DRIVE)
# ============================================================================
function Start-WindowsInstaller {
    Write-ImageLog "WINDOWS INSTALLER" "SECTION"

    $installerUrl = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/Windows-Installer.ps1"
    $installerPath = "$WorkDir\Windows-Installer.ps1"

    Write-ImageLog "Downloading Windows Installer..."
    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        Write-ImageLog "Downloaded Windows Installer" "SUCCESS"

        Write-ImageLog "Launching Windows Installer..."
        & $installerPath
    } catch {
        Write-ImageLog "Failed to download: $_" "ERROR"
        Write-Host ""
        Write-Host "You can manually download from:" -ForegroundColor Yellow
        Write-Host "  $installerUrl" -ForegroundColor Cyan
    }
}

# ============================================================================
# VHD NATIVE BOOT DEPLOYMENT
# ============================================================================
function Start-VHDDeployment {
    Write-ImageLog "VHD DEPLOYMENT TOOL" "SECTION"

    $vhdUrl = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/VHD-Deploy.ps1"
    $vhdPath = "$WorkDir\VHD-Deploy.ps1"

    Write-ImageLog "Downloading VHD Deployment Tool..."
    try {
        Invoke-WebRequest -Uri $vhdUrl -OutFile $vhdPath -UseBasicParsing
        Write-ImageLog "Downloaded VHD Deployment Tool" "SUCCESS"

        Write-ImageLog "Launching VHD Deployment Tool..."
        & $vhdPath
    } catch {
        Write-ImageLog "Failed to download: $_" "ERROR"
        Write-Host ""
        Write-Host "You can manually download from:" -ForegroundColor Yellow
        Write-Host "  $vhdUrl" -ForegroundColor Cyan
    }
}

# ============================================================================
# MAIN MENU LOOP
# ============================================================================
function Start-ImageToolMenu {
    Initialize-WorkDirectories

    do {
        Show-ImageToolMenu
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Start-QuickCustomISO }
            "2" {
                $iso = Select-WindowsISO
                if ($iso) {
                    $drive = Mount-WindowsISO -ISOPath $iso
                    if ($drive) {
                        Copy-ISOContents -SourceDrive $drive
                        Dismount-DiskImage -ImagePath $iso
                        $index = Get-WindowsImageIndex
                        if ($index) { Mount-WindowsWIM -Index $index }
                    }
                }
            }
            "3" { Apply-ImageTweaks }
            "4" { Inject-Drivers }
            "5" { Remove-ImageBloatware }
            "6" { Create-UnattendFile }
            "7" { Save-ModifiedImage }
            "8" { Create-BootableUSB }
            "9" { Download-WindowsISO }
            "10" {
                Write-ImageLog "Applying TPM/SecureBoot bypass to current system..."
                reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f
                reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f
                reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d 1 /f
                reg add "HKLM\SYSTEM\Setup\MoSetup" /v "AllowUpgradesWithUnsupportedTPMOrCPU" /t REG_DWORD /d 1 /f
                Write-ImageLog "Bypass applied to current system" "SUCCESS"
            }
            "11" { Start-WindowsInstaller }
            "12" { Start-VHDDeployment }
            "13" { Optimize-WIMImage }
            "14" { Download-Oscdimg }
            "15" { Cleanup-WorkDirectories }
            "16" { Show-MountedImages }
            "17" { Show-SettingsMenu }
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

# ============================================================================
# MODULE EXPORTS
# ============================================================================
Export-ModuleMember -Function @(
    'Initialize-ImageToolLogging',
    'Write-ImageLog',
    'Set-ConsoleSize',
    'Initialize-WorkDirectories',
    'Update-WorkDirectoryPaths',
    'Show-SettingsMenu',
    'Show-ImageToolMenu',
    'Select-WindowsISO',
    'Mount-WindowsISO',
    'Copy-ISOContents',
    'Get-WindowsImageIndex',
    'Mount-WindowsWIM',
    'Apply-ImageTweaks',
    'Apply-BypassChecks',
    'Apply-TelemetryTweaks',
    'Apply-SponsoredAppsTweaks',
    'Apply-LocalAccountTweaks',
    'Apply-SkipAnimationTweaks',
    'Apply-DarkThemeTweaks',
    'Apply-TeamsDisable',
    'Inject-Drivers',
    'Remove-ImageBloatware',
    'Remove-ProvisionedPackages',
    'Remove-WindowsFeatures',
    'Remove-BloatFolders',
    'Create-UnattendFile',
    'Create-SystemOptimizerShortcut',
    'Save-ModifiedImage',
    'Optimize-WIMImage',
    'Create-CustomISO',
    'Create-BootableUSB',
    'Download-WindowsISO',
    'Download-Oscdimg',
    'Cleanup-WorkDirectories',
    'Show-MountedImages',
    'Start-QuickCustomISO',
    'Start-WindowsInstaller',
    'Start-VHDDeployment',
    'Start-ImageToolMenu'
)
