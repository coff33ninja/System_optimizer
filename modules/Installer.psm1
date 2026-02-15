# ============================================================================
# Installer Module - System Optimizer
# ============================================================================
# Windows Deployment to Blank Drives
# ============================================================================
# ============================================================================
# WINDOWS INSTALLER - Deploy Windows to Blank Drive
# ============================================================================
# Part of System Optimizer - https://github.com/coff33ninja/System_Optimizer
# Based on AIO Windows Install scripts
# ============================================================================
# WARNING: This script will ERASE data on selected disks!
# Use with caution - designed for clean installations only.
# ============================================================================


$ErrorActionPreference = 'SilentlyContinue'
$script:WorkDir = "C:\System_Optimizer\Installer"
$script:DiskpartDir = "$WorkDir\Diskpart"
$script:LogDir = "C:\System_Optimizer\Logs"
$script:LogFile = $null

function Initialize-InstallerLogging {
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $script:LogFile = "$LogDir\WindowsInstaller_$timestamp.log"

    $header = @"
================================================================================
WINDOWS INSTALLER LOG
================================================================================
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
WARNING: This tool can ERASE disks!
================================================================================

"@
    Add-Content -Path $LogFile -Value $header -ErrorAction SilentlyContinue
}

function Write-InstallerLog {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $shortTime = Get-Date -Format "HH:mm:ss"

    # Write to log file
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

# Console sizing
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

function Initialize-InstallerDirectories {
    Initialize-InstallerLogging
    Set-ConsoleSize
    @($WorkDir, $DiskpartDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
}

function Show-InstallerMenu {
    Set-ConsoleSize
    Clear-Host
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  WINDOWS INSTALLER - Deploy to Blank Drive" -ForegroundColor Yellow
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  !! WARNING: These options will ERASE selected disks !!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Disk Preparation:" -ForegroundColor Gray
    Write-Host "  [1] Prepare Single Disk (GPT/UEFI)"
    Write-Host "  [2] Prepare Dual Disk - Windows on Primary"
    Write-Host "  [3] Prepare Dual Disk - Windows on Secondary"
    Write-Host "  [4] Custom Disk Preparation"
    Write-Host ""
    Write-Host "  Windows Deployment:" -ForegroundColor Gray
    Write-Host "  [5] Deploy Windows from ISO/WIM"
    Write-Host "  [6] Quick Install (Prepare + Deploy)"
    Write-Host ""
    Write-Host "  Utilities:" -ForegroundColor Gray
    Write-Host "  [7] View Available Disks"
    Write-Host "  [8] View Disk Partitions"
    Write-Host "  [9] Download WinNTSetup (GUI Installer)"
    Write-Host ""
    Write-Host "  [0] Back to Main Menu"
    Write-Host ""
}

# ============================================================================
# DISK INFORMATION
# ============================================================================
function Show-AvailableDisks {
    Write-InstallerLog "AVAILABLE DISKS" "SECTION"

    $disks = Get-Disk | Select-Object Number, FriendlyName, Size, PartitionStyle, OperationalStatus

    Write-Host ""
    Write-Host "  #   Size        Style    Status       Name" -ForegroundColor Cyan
    Write-Host "  --- ----------- -------- ------------ --------------------------------" -ForegroundColor Gray

    foreach ($disk in $disks) {
        $sizeGB = [math]::Round($disk.Size / 1GB, 1)
        $style = if ($disk.PartitionStyle -eq "RAW") { "RAW" } else { $disk.PartitionStyle }
        Write-Host ("  {0,-3} {1,-11} {2,-8} {3,-12} {4}" -f $disk.Number, "$sizeGB GB", $style, $disk.OperationalStatus, $disk.FriendlyName)
    }
    Write-Host ""
}

function Show-DiskPartitions {
    Write-InstallerLog "DISK PARTITIONS" "SECTION"

    $diskNum = Read-Host "Enter disk number to view"

    $partitions = Get-Partition -DiskNumber $diskNum -ErrorAction SilentlyContinue

    if (-not $partitions) {
        Write-InstallerLog "No partitions found on Disk $diskNum" "WARNING"
        return
    }

    Write-Host ""
    Write-Host "  Partitions on Disk $diskNum`:" -ForegroundColor Cyan
    Write-Host "  # Type              Size        Letter  Label" -ForegroundColor Gray
    Write-Host "  - ----------------- ----------- ------- ---------------" -ForegroundColor Gray

    foreach ($part in $partitions) {
        $sizeGB = [math]::Round($part.Size / 1GB, 2)
        $letter = if ($part.DriveLetter) { $part.DriveLetter } else { "-" }
        $volume = Get-Volume -Partition $part -ErrorAction SilentlyContinue
        $label = if ($volume.FileSystemLabel) { $volume.FileSystemLabel } else { "-" }
        Write-Host ("  {0} {1,-17} {2,-11} {3,-7} {4}" -f $part.PartitionNumber, $part.Type, "$sizeGB GB", $letter, $label)
    }
    Write-Host ""
}

# ============================================================================
# DISKPART SCRIPT GENERATION
# ============================================================================
function Create-SingleDiskScript {
    param([int]$DiskNumber = 0)

    $script = @"
rem DISKPART script for single disk system (GPT/UEFI)
rem Generated by System Optimizer Windows Installer
rem ---------------------------------------------------
rem Select disk, wipe it empty, convert to GPT
select disk $DiskNumber
clean
convert gpt
rem
rem ---------------------------------------------------
rem Create & format 100 MB EFI System partition
create partition efi size=100
format quick fs=fat32 label="System"
assign letter="S"
rem
rem ---------------------------------------------------
rem Create 16 MB MSR partition (will not be formatted)
create partition msr size=16
rem
rem ---------------------------------------------------
rem Create OS partition using all available space,
rem shrink it with 550 MB to leave space for WinRE
create partition primary
shrink minimum=550
format quick fs=ntfs label="Windows"
assign letter="W"
rem
rem ---------------------------------------------------
rem Create WinRE recovery partition at end of disk
create partition primary
format quick fs=ntfs label="WinRE"
assign letter="R"
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001
rem
rem ---------------------------------------------------
exit
"@
    return $script
}

function Create-DualDiskPrimaryScript {
    param([int]$PrimaryDisk = 0, [int]$SecondaryDisk = 1)

    $script = @"
rem DISKPART script for dual disk - Windows on primary
rem Generated by System Optimizer Windows Installer
rem ---------------------------------------------------
rem Prepare PRIMARY disk for Windows
select disk $PrimaryDisk
clean
convert gpt
rem
rem Create EFI partition
create partition efi size=100
format quick fs=fat32 label="System"
assign letter="S"
rem
rem Create MSR partition
create partition msr size=128
rem
rem Create OS partition
create partition primary
shrink minimum=550
format quick fs=ntfs label="Windows"
assign letter="W"
rem
rem Create WinRE partition
create partition primary
format quick fs=ntfs label="WinRE"
assign letter="R"
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001
rem
rem ---------------------------------------------------
rem Prepare SECONDARY disk for Data
select disk $SecondaryDisk
clean
convert gpt
rem
rem Create MSR partition
create partition msr size=128
rem
rem Create data partition
create partition primary
format quick fs=ntfs label="Data"
assign
rem
exit
"@
    return $script
}

function Create-DualDiskSecondaryScript {
    param([int]$PrimaryDisk = 0, [int]$SecondaryDisk = 1)

    $script = @"
rem DISKPART script for dual disk - Windows on secondary
rem Generated by System Optimizer Windows Installer
rem ---------------------------------------------------
rem Prepare SECONDARY disk for Windows
select disk $SecondaryDisk
clean
convert gpt
rem
rem Create EFI partition
create partition efi size=100
format quick fs=fat32 label="System"
assign letter="S"
rem
rem Create MSR partition
create partition msr size=128
rem
rem Create OS partition
create partition primary
shrink minimum=550
format quick fs=ntfs label="Windows"
assign letter="W"
rem
rem Create WinRE partition
create partition primary
format quick fs=ntfs label="WinRE"
assign letter="R"
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001
rem
rem ---------------------------------------------------
rem Prepare PRIMARY disk for Data
select disk $PrimaryDisk
clean
convert gpt
rem
rem Create MSR partition
create partition msr size=128
rem
rem Create data partition
create partition primary
format quick fs=ntfs label="Data"
assign
rem
exit
"@
    return $script
}


# ============================================================================
# DISK PREPARATION FUNCTIONS
# ============================================================================
function Prepare-SingleDisk {
    Write-InstallerLog "PREPARE SINGLE DISK (GPT/UEFI)" "SECTION"

    Show-AvailableDisks

    $diskNum = Read-Host "Enter disk number to prepare (WARNING: ALL DATA WILL BE ERASED)"

    # Confirm
    Write-Host ""
    Write-Host "  WARNING: This will ERASE ALL DATA on Disk $diskNum!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Type 'YES' to confirm"

    if ($confirm -ne "YES") {
        Write-InstallerLog "Operation cancelled" "WARNING"
        return $false
    }

    # Generate and save diskpart script
    $script = Create-SingleDiskScript -DiskNumber $diskNum
    $scriptPath = "$DiskpartDir\SingleDisk.txt"
    $script | Out-File -FilePath $scriptPath -Encoding ASCII -Force

    Write-InstallerLog "Running diskpart..."
    $process = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$scriptPath`"" -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-InstallerLog "Disk prepared successfully" "SUCCESS"
        Write-Host ""
        Write-Host "  Partitions created:" -ForegroundColor Cyan
        Write-Host "    S: - EFI System (100 MB)" -ForegroundColor Gray
        Write-Host "    W: - Windows OS" -ForegroundColor Gray
        Write-Host "    R: - WinRE Recovery (550 MB)" -ForegroundColor Gray
        return $true
    } else {
        Write-InstallerLog "Diskpart failed with exit code $($process.ExitCode)" "ERROR"
        return $false
    }
}

function Prepare-DualDiskPrimary {
    Write-InstallerLog "PREPARE DUAL DISK - WINDOWS ON PRIMARY" "SECTION"

    Show-AvailableDisks

    $primaryDisk = Read-Host "Enter PRIMARY disk number (for Windows)"
    $secondaryDisk = Read-Host "Enter SECONDARY disk number (for Data)"

    Write-Host ""
    Write-Host "  WARNING: This will ERASE ALL DATA on Disk $primaryDisk AND Disk $secondaryDisk!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Type 'YES' to confirm"

    if ($confirm -ne "YES") {
        Write-InstallerLog "Operation cancelled" "WARNING"
        return $false
    }

    $script = Create-DualDiskPrimaryScript -PrimaryDisk $primaryDisk -SecondaryDisk $secondaryDisk
    $scriptPath = "$DiskpartDir\DualDisk.txt"
    $script | Out-File -FilePath $scriptPath -Encoding ASCII -Force

    Write-InstallerLog "Running diskpart..."
    $process = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$scriptPath`"" -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-InstallerLog "Disks prepared successfully" "SUCCESS"
        return $true
    } else {
        Write-InstallerLog "Diskpart failed" "ERROR"
        return $false
    }
}

function Prepare-DualDiskSecondary {
    Write-InstallerLog "PREPARE DUAL DISK - WINDOWS ON SECONDARY" "SECTION"

    Show-AvailableDisks

    $primaryDisk = Read-Host "Enter PRIMARY disk number (for Data)"
    $secondaryDisk = Read-Host "Enter SECONDARY disk number (for Windows)"

    Write-Host ""
    Write-Host "  WARNING: This will ERASE ALL DATA on Disk $primaryDisk AND Disk $secondaryDisk!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Type 'YES' to confirm"

    if ($confirm -ne "YES") {
        Write-InstallerLog "Operation cancelled" "WARNING"
        return $false
    }

    $script = Create-DualDiskSecondaryScript -PrimaryDisk $primaryDisk -SecondaryDisk $secondaryDisk
    $scriptPath = "$DiskpartDir\DualDisk.txt"
    $script | Out-File -FilePath $scriptPath -Encoding ASCII -Force

    Write-InstallerLog "Running diskpart..."
    $process = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$scriptPath`"" -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-InstallerLog "Disks prepared successfully" "SUCCESS"
        return $true
    } else {
        Write-InstallerLog "Diskpart failed" "ERROR"
        return $false
    }
}

function Prepare-CustomDisk {
    Write-InstallerLog "CUSTOM DISK PREPARATION" "SECTION"

    Show-AvailableDisks

    Write-Host ""
    Write-Host "  Custom partition layout options:" -ForegroundColor Cyan
    Write-Host "  [1] GPT with EFI (UEFI boot) - Recommended"
    Write-Host "  [2] MBR (Legacy BIOS boot)"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $style = Read-Host "Select partition style"
    if ($style -eq "0") { return $false }

    $diskNum = Read-Host "Enter disk number"

    Write-Host ""
    Write-Host "  WARNING: This will ERASE ALL DATA on Disk $diskNum!" -ForegroundColor Red
    $confirm = Read-Host "Type 'YES' to confirm"

    if ($confirm -ne "YES") {
        Write-InstallerLog "Operation cancelled" "WARNING"
        return $false
    }

    if ($style -eq "1") {
        # GPT/UEFI
        $script = @"
select disk $diskNum
clean
convert gpt
create partition efi size=100
format quick fs=fat32 label="System"
assign letter="S"
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
assign letter="W"
exit
"@
    } else {
        # MBR/Legacy
        $script = @"
select disk $diskNum
clean
convert mbr
create partition primary size=100
format quick fs=ntfs label="System Reserved"
active
assign letter="S"
create partition primary
format quick fs=ntfs label="Windows"
assign letter="W"
exit
"@
    }

    $scriptPath = "$DiskpartDir\Custom.txt"
    $script | Out-File -FilePath $scriptPath -Encoding ASCII -Force

    Write-InstallerLog "Running diskpart..."
    $process = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$scriptPath`"" -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-InstallerLog "Disk prepared successfully" "SUCCESS"
        return $true
    } else {
        Write-InstallerLog "Diskpart failed" "ERROR"
        return $false
    }
}

# ============================================================================
# WINDOWS DEPLOYMENT
# ============================================================================
function Deploy-Windows {
    Write-InstallerLog "DEPLOY WINDOWS FROM ISO/WIM" "SECTION"

    # Check if W: drive exists (prepared disk)
    if (-not (Test-Path "W:\")) {
        Write-InstallerLog "W: drive not found. Please prepare disk first (Options 1-4)" "ERROR"
        return
    }

    Write-Host ""
    Write-Host "  Select Windows source:" -ForegroundColor Cyan
    Write-Host "  [1] Select ISO file"
    Write-Host "  [2] Select WIM file directly"
    Write-Host "  [3] Use mounted ISO (if already mounted)"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $sourceChoice = Read-Host "Select option"

    $wimPath = $null

    switch ($sourceChoice) {
        "1" {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "ISO files (*.iso)|*.iso"
            $dialog.Title = "Select Windows ISO"

            if ($dialog.ShowDialog() -eq 'OK') {
                $isoPath = $dialog.FileName
                Write-InstallerLog "Mounting ISO..."
                $mount = Mount-DiskImage -ImagePath $isoPath -PassThru
                $driveLetter = ($mount | Get-Volume).DriveLetter
                $wimPath = "${driveLetter}:\sources\install.wim"

                if (-not (Test-Path $wimPath)) {
                    $wimPath = "${driveLetter}:\sources\install.esd"
                }
            }
        }
        "2" {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "WIM/ESD files (*.wim;*.esd)|*.wim;*.esd"
            $dialog.Title = "Select install.wim or install.esd"

            if ($dialog.ShowDialog() -eq 'OK') {
                $wimPath = $dialog.FileName
            }
        }
        "3" {
            # Find mounted ISO
            $volumes = Get-Volume | Where-Object { $_.DriveType -eq 'CD-ROM' }
            foreach ($vol in $volumes) {
                $testPath = "$($vol.DriveLetter):\sources\install.wim"
                if (Test-Path $testPath) {
                    $wimPath = $testPath
                    break
                }
                $testPath = "$($vol.DriveLetter):\sources\install.esd"
                if (Test-Path $testPath) {
                    $wimPath = $testPath
                    break
                }
            }

            if (-not $wimPath) {
                Write-InstallerLog "No mounted Windows ISO found" "ERROR"
                return
            }
        }
        "0" { return }
    }

    if (-not $wimPath -or -not (Test-Path $wimPath)) {
        Write-InstallerLog "WIM/ESD file not found" "ERROR"
        return
    }

    Write-InstallerLog "Found: $wimPath" "SUCCESS"

    # Show available editions
    Write-Host ""
    Write-Host "  Available Windows editions:" -ForegroundColor Cyan
    $images = Get-WindowsImage -ImagePath $wimPath
    foreach ($img in $images) {
        Write-Host "    [$($img.ImageIndex)] $($img.ImageName)" -ForegroundColor Gray
    }
    Write-Host ""

    $index = Read-Host "Select edition index"

    # Apply image
    Write-InstallerLog "Applying Windows image to W: drive..."
    Write-Host "This may take 10-20 minutes..." -ForegroundColor Yellow

    try {
        $result = Expand-WindowsImage -ImagePath $wimPath -Index $index -ApplyPath "W:\" -ErrorAction Stop
        Write-InstallerLog "Windows image applied successfully" "SUCCESS"
    } catch {
        Write-InstallerLog "PowerShell method failed, trying DISM..." "WARNING"
        dism /Apply-Image /ImageFile:"$wimPath" /Index:$index /ApplyDir:W:\
    }

    # Create boot entry
    Write-InstallerLog "Creating boot entry..."
    if (Test-Path "S:\") {
        W:\Windows\System32\bcdboot W:\Windows /s S: /f UEFI
    } else {
        W:\Windows\System32\bcdboot W:\Windows
    }
    Write-InstallerLog "Boot entry created" "SUCCESS"

    # Setup recovery environment if R: exists
    if (Test-Path "R:\") {
        Write-InstallerLog "Setting up recovery environment..."
        New-Item -ItemType Directory -Force -Path "R:\Recovery\WinRE" | Out-Null
        Copy-Item "W:\Windows\System32\Recovery\Winre.wim" "R:\Recovery\WinRE\" -Force -ErrorAction SilentlyContinue
        W:\Windows\System32\Reagentc /Setreimage /Path R:\Recovery\WinRE /Target W:\Windows
    }

    # Copy System Optimizer shortcut
    Write-InstallerLog "Adding System Optimizer shortcut..."
    $defaultDesktop = "W:\Users\Default\Desktop"
    $publicDesktop = "W:\Users\Public\Desktop"
    New-Item -ItemType Directory -Force -Path $defaultDesktop | Out-Null
    New-Item -ItemType Directory -Force -Path $publicDesktop | Out-Null

    # Create .lnk shortcut using VBScript
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
        $vbsPath = "$env:TEMP\create_shortcut_installer.vbs"
        $vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force
        & cscript.exe //nologo $vbsPath
        Write-InstallerLog "Desktop shortcut created" "SUCCESS"
    } catch {
        Write-InstallerLog "Could not create shortcut: $($_.Exception.Message)" "WARNING"
    }

    Write-InstallerLog "Windows deployment complete!" "SUCCESS"

    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Cyan
    Write-Host "    1. Remove installation media" -ForegroundColor Gray
    Write-Host "    2. Restart computer" -ForegroundColor Gray
    Write-Host "    3. Complete Windows OOBE setup" -ForegroundColor Gray
    Write-Host "    4. Run System Optimizer from desktop shortcut" -ForegroundColor Gray
    Write-Host ""

    $restart = Read-Host "Restart now? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        shutdown /r /t 5 /c "Restarting to complete Windows installation..."
    }
}


# ============================================================================
# QUICK INSTALL (PREPARE + DEPLOY)
# ============================================================================
function Start-QuickInstall {
    Write-InstallerLog "QUICK INSTALL - PREPARE & DEPLOY" "SECTION"

    Write-Host ""
    Write-Host "  This will prepare a disk and deploy Windows in one step." -ForegroundColor Cyan
    Write-Host "  WARNING: Selected disk will be COMPLETELY ERASED!" -ForegroundColor Red
    Write-Host ""

    Show-AvailableDisks

    $diskNum = Read-Host "Enter disk number for Windows installation"

    Write-Host ""
    Write-Host "  Disk $diskNum will be:" -ForegroundColor Yellow
    Write-Host "    - Completely erased" -ForegroundColor Red
    Write-Host "    - Converted to GPT (UEFI)" -ForegroundColor Gray
    Write-Host "    - Partitioned for Windows" -ForegroundColor Gray
    Write-Host "    - Windows will be installed" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "Type 'YES' to proceed"
    if ($confirm -ne "YES") {
        Write-InstallerLog "Operation cancelled" "WARNING"
        return
    }

    # Step 1: Prepare disk
    Write-Host ""
    Write-Host "Step 1: Preparing disk..." -ForegroundColor Yellow

    $script = Create-SingleDiskScript -DiskNumber $diskNum
    $scriptPath = "$DiskpartDir\QuickInstall.txt"
    $script | Out-File -FilePath $scriptPath -Encoding ASCII -Force

    $process = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$scriptPath`"" -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -ne 0) {
        Write-InstallerLog "Disk preparation failed" "ERROR"
        return
    }
    Write-InstallerLog "Disk prepared" "SUCCESS"

    # Step 2: Deploy Windows
    Write-Host ""
    Write-Host "Step 2: Deploying Windows..." -ForegroundColor Yellow
    Deploy-Windows
}

# ============================================================================
# WINNTSETUP DOWNLOAD
# ============================================================================
function Download-WinNTSetup {
    Set-ConsoleSize
    Clear-Host
    Write-InstallerLog "DOWNLOAD WINNTSETUP" "SECTION"

    $setupDir = "$WorkDir\WinNTSetup"
    $zipUrl = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/tools/WinNTSetup.zip"
    $zipPath = "$WorkDir\WinNTSetup.zip"

    Write-Host ""
    Write-Host "  WinNTSetup is a GUI tool for installing Windows." -ForegroundColor Cyan
    Write-Host "  It provides more options than the built-in installer." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [1] Download from System Optimizer repo (v4.6.2)"
    Write-Host "  [2] Launch WinNTSetup (if already downloaded)"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Write-InstallerLog "Downloading WinNTSetup from System Optimizer repo..."
            try {
                # Create directory
                if (-not (Test-Path $setupDir)) {
                    New-Item -ItemType Directory -Path $setupDir -Force | Out-Null
                }

                # Download zip
                Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

                # Extract
                Expand-Archive -Path $zipPath -DestinationPath $setupDir -Force
                Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

                Write-InstallerLog "WinNTSetup downloaded to $setupDir" "SUCCESS"

                # Launch it
                $exePath = "$setupDir\WinNTSetup_x64.exe"
                if (Test-Path $exePath) {
                    Write-InstallerLog "Launching WinNTSetup..."
                    Start-Process -FilePath $exePath
                }
            } catch {
                Write-InstallerLog "Download failed: $_" "ERROR"
                Write-Host ""
                Write-Host "  Manual download: https://github.com/coff33ninja/System_Optimizer/tree/main/tools/WinNTSetup" -ForegroundColor Yellow
            }
        }
        "2" {
            $exePath = "$setupDir\WinNTSetup_x64.exe"
            if (Test-Path $exePath) {
                Write-InstallerLog "Launching WinNTSetup..."
                Start-Process -FilePath $exePath
            } else {
                Write-InstallerLog "WinNTSetup not found. Please download first (Option 1)" "ERROR"
            }
        }
    }
}

# ============================================================================
# MAIN MENU LOOP
# ============================================================================
function Start-InstallerMenu {
    Initialize-InstallerDirectories

    do {
        Show-InstallerMenu
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Prepare-SingleDisk }
            "2" { Prepare-DualDiskPrimary }
            "3" { Prepare-DualDiskSecondary }
            "4" { Prepare-CustomDisk }
            "5" { Deploy-Windows }
            "6" { Start-QuickInstall }
            "7" { Show-AvailableDisks }
            "8" { Show-DiskPartitions }
            "9" { Download-WinNTSetup }
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
# ============================================================================
# MODULE EXPORTS
# ============================================================================
Export-ModuleMember -Function @(
    'Initialize-InstallerLogging',
    'Write-InstallerLog',
    'Set-ConsoleSize',
    'Initialize-InstallerDirectories',
    'Show-InstallerMenu',
    'Show-AvailableDisks',
    'Show-DiskPartitions',
    'Create-SingleDiskScript',
    'Create-DualDiskPrimaryScript',
    'Create-DualDiskSecondaryScript',
    'Prepare-SingleDisk',
    'Prepare-DualDiskPrimary',
    'Prepare-DualDiskSecondary',
    'Prepare-CustomDisk',
    'Deploy-Windows',
    'Start-QuickInstall',
    'Download-WinNTSetup',
    'Start-InstallerMenu'
)
