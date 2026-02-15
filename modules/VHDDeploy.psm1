# ============================================================================
# VHDDeploy Module - System Optimizer
# ============================================================================
# VHD Native Boot Deployment Tool
# ============================================================================
# ============================================================================
# VHD DEPLOYMENT TOOL - Native Boot VHD Creation
# ============================================================================
# Part of System Optimizer - https://github.com/coff33ninja/System_Optimizer
# Based on Kari's DeployVHD script from TenForums.com
# ============================================================================
# Creates a bootable VHD/VHDX file for dual/multi-boot Windows installations
# ============================================================================


$ErrorActionPreference = 'SilentlyContinue'
$script:WorkDir = "C:\System_Optimizer\VHD"
$script:MountDir = "$WorkDir\Mount"
$script:DriverDir = "$WorkDir\Drivers"
$script:LogDir = "C:\System_Optimizer\Logs"
$script:LogFile = $null

function Initialize-VHDLogging {
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $script:LogFile = "$LogDir\VHD-Deploy_$timestamp.log"

    $header = @"
================================================================================
VHD DEPLOYMENT TOOL LOG
================================================================================
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
================================================================================

"@
    Add-Content -Path $LogFile -Value $header -ErrorAction SilentlyContinue
}

function Write-VHDLog {
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

function Initialize-VHDDirectories {
    Initialize-VHDLogging
    Set-ConsoleSize
    @($WorkDir, $MountDir, $DriverDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
}

function Show-VHDMenu {
    Set-ConsoleSize
    Clear-Host
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  VHD DEPLOYMENT TOOL - Native Boot VHD" -ForegroundColor Yellow
    Write-Host "=" -ForegroundColor Cyan -NoNewline; Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  VHD Creation:" -ForegroundColor Gray
    Write-Host "  [1] Quick Deploy - Create bootable VHD from ISO/WIM"
    Write-Host "  [2] Create Empty VHD (GPT/UEFI)"
    Write-Host "  [3] Create Empty VHD (MBR/Legacy)"
    Write-Host ""
    Write-Host "  VHD Management:" -ForegroundColor Gray
    Write-Host "  [4] Mount Existing VHD"
    Write-Host "  [5] Dismount VHD"
    Write-Host "  [6] Deploy Windows to Mounted VHD"
    Write-Host "  [7] Add VHD to Boot Menu"
    Write-Host ""
    Write-Host "  Customization:" -ForegroundColor Gray
    Write-Host "  [8] Inject Drivers into VHD"
    Write-Host "  [9] Enable Features (Hyper-V, WSL)"
    Write-Host ""
    Write-Host "  [0] Back to Main Menu"
    Write-Host ""
}

# ============================================================================
# VHD CREATION FUNCTIONS
# ============================================================================
function New-EmptyVHD {
    param(
        [string]$VHDPath,
        [int]$SizeMB = 102400,
        [string]$PartitionStyle = "GPT",
        [string]$DriveLetter = "W"
    )

    Write-VHDLog "Creating $PartitionStyle VHD: $VHDPath ($([math]::Round($SizeMB/1024, 0)) GB)"

    $diskpartScript = "$env:TEMP\vhd_create.txt"

    if ($PartitionStyle -eq "GPT") {
        $script = @"
create vdisk file="$VHDPath" maximum=$SizeMB type=expandable
attach vdisk
convert gpt
create partition efi size=100
format quick fs=fat32 label="System"
create partition msr size=16
create partition primary
shrink minimum=550
format quick fs=ntfs label="Windows"
assign letter=$DriveLetter
create partition primary
format quick fs=ntfs label="WinRE"
set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
gpt attributes=0x8000000000000001
exit
"@
    } else {
        $script = @"
create vdisk file="$VHDPath" maximum=$SizeMB type=expandable
attach vdisk
create partition primary size=500
format quick fs=fat32 label="System"
create partition primary
shrink minimum=550
format quick fs=ntfs label="Windows"
assign letter=$DriveLetter
create partition primary
format quick fs=ntfs label="WinRE"
set id=27
exit
"@
    }

    $script | Out-File -FilePath $diskpartScript -Encoding ASCII -Force

    $process = Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$diskpartScript`"" -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-VHDLog "VHD created and mounted at ${DriveLetter}:" "SUCCESS"
        return $true
    } else {
        Write-VHDLog "Failed to create VHD" "ERROR"
        return $false
    }
}

function Start-CreateEmptyVHD {
    param([string]$Style = "GPT")

    Write-VHDLog "CREATE EMPTY VHD ($Style)" "SECTION"

    # Get VHD path
    Write-Host ""
    $defaultPath = "$WorkDir\Windows.vhdx"
    Write-Host "  Default path: $defaultPath" -ForegroundColor Gray
    $vhdPath = Read-Host "Enter VHD path (or press Enter for default)"
    if ([string]::IsNullOrEmpty($vhdPath)) { $vhdPath = $defaultPath }

    # Check if file exists
    if (Test-Path $vhdPath) {
        Write-VHDLog "VHD already exists at $vhdPath" "WARNING"
        $overwrite = Read-Host "Overwrite? (Y/N)"
        if ($overwrite -ne "Y" -and $overwrite -ne "y") { return }

        # Try to dismount first
        try { Dismount-VHD -Path $vhdPath -ErrorAction SilentlyContinue } catch { }
        Remove-Item $vhdPath -Force -ErrorAction SilentlyContinue
    }

    # Get size
    Write-Host ""
    $sizeGB = Read-Host "Enter VHD size in GB (default: 100)"
    if ([string]::IsNullOrEmpty($sizeGB)) { $sizeGB = 100 }
    $sizeMB = [int]$sizeGB * 1024

    # Get drive letter
    Write-Host ""
    $driveLetter = Read-Host "Enter drive letter for VHD (default: W)"
    if ([string]::IsNullOrEmpty($driveLetter)) { $driveLetter = "W" }

    # Create VHD
    $result = New-EmptyVHD -VHDPath $vhdPath -SizeMB $sizeMB -PartitionStyle $Style -DriveLetter $driveLetter

    if ($result) {
        Write-Host ""
        Write-Host "  VHD is ready at ${driveLetter}:" -ForegroundColor Cyan
        Write-Host "  You can now deploy Windows to it using Option 6" -ForegroundColor Gray
    }
}

# ============================================================================
# VHD MANAGEMENT
# ============================================================================
function Mount-ExistingVHD {
    Write-VHDLog "MOUNT EXISTING VHD" "SECTION"

    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "VHD files (*.vhd;*.vhdx)|*.vhd;*.vhdx"
    $dialog.Title = "Select VHD file to mount"

    if ($dialog.ShowDialog() -eq 'OK') {
        $vhdPath = $dialog.FileName

        Write-VHDLog "Mounting $vhdPath..."
        try {
            Mount-VHD -Path $vhdPath -PassThru
            Write-VHDLog "VHD mounted successfully" "SUCCESS"

            # Show mounted volumes
            $disk = Get-VHD -Path $vhdPath
            $partitions = Get-Partition -DiskNumber $disk.DiskNumber -ErrorAction SilentlyContinue
            Write-Host ""
            Write-Host "  Mounted partitions:" -ForegroundColor Cyan
            foreach ($part in $partitions) {
                if ($part.DriveLetter) {
                    Write-Host "    $($part.DriveLetter): - $($part.Type)" -ForegroundColor Gray
                }
            }
        } catch {
            Write-VHDLog "Failed to mount VHD: $_" "ERROR"
        }
    }
}

function Dismount-ExistingVHD {
    Write-VHDLog "DISMOUNT VHD" "SECTION"

    # List mounted VHDs
    $mountedVHDs = Get-VHD -Path * -ErrorAction SilentlyContinue | Where-Object { $_.Attached }

    if (-not $mountedVHDs -or $mountedVHDs.Count -eq 0) {
        Write-VHDLog "No VHDs currently mounted" "WARNING"
        return
    }

    Write-Host ""
    Write-Host "  Mounted VHDs:" -ForegroundColor Cyan
    $i = 1
    foreach ($vhd in $mountedVHDs) {
        Write-Host "  [$i] $($vhd.Path)" -ForegroundColor Gray
        $i++
    }
    Write-Host "  [A] Dismount all"
    Write-Host ""

    $choice = Read-Host "Select VHD to dismount"

    if ($choice -eq "A" -or $choice -eq "a") {
        foreach ($vhd in $mountedVHDs) {
            Write-VHDLog "Dismounting $($vhd.Path)..."
            Dismount-VHD -Path $vhd.Path
        }
        Write-VHDLog "All VHDs dismounted" "SUCCESS"
    } elseif ([int]::TryParse($choice, [ref]$null)) {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $mountedVHDs.Count) {
            $vhdPath = $mountedVHDs[$index].Path
            Write-VHDLog "Dismounting $vhdPath..."
            Dismount-VHD -Path $vhdPath
            Write-VHDLog "VHD dismounted" "SUCCESS"
        }
    }
}

# ============================================================================
# WINDOWS DEPLOYMENT TO VHD
# ============================================================================
function Deploy-WindowsToVHD {
    Write-VHDLog "DEPLOY WINDOWS TO VHD" "SECTION"

    # Check for mounted VHD with W: drive
    if (-not (Test-Path "W:\")) {
        Write-VHDLog "W: drive not found. Please mount a VHD first (Options 2-4)" "ERROR"
        return
    }

    Write-Host ""
    Write-Host "  Select Windows source:" -ForegroundColor Cyan
    Write-Host "  [1] Select ISO file"
    Write-Host "  [2] Select WIM file directly"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $sourceChoice = Read-Host "Select option"

    $wimPath = $null
    $isoPath = $null

    switch ($sourceChoice) {
        "1" {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "ISO files (*.iso)|*.iso"
            $dialog.Title = "Select Windows ISO"

            if ($dialog.ShowDialog() -eq 'OK') {
                $isoPath = $dialog.FileName
                Write-VHDLog "Mounting ISO..."
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
        "0" { return }
    }

    if (-not $wimPath -or -not (Test-Path $wimPath)) {
        Write-VHDLog "WIM/ESD file not found" "ERROR"
        return
    }

    Write-VHDLog "Found: $wimPath" "SUCCESS"

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
    Write-VHDLog "Applying Windows image to W: drive..."
    Write-Host "This may take 10-20 minutes..." -ForegroundColor Yellow

    try {
        Expand-WindowsImage -ImagePath $wimPath -Index $index -ApplyPath "W:\" -ErrorAction Stop
        Write-VHDLog "Windows image applied successfully" "SUCCESS"
    } catch {
        Write-VHDLog "PowerShell method failed, trying DISM..." "WARNING"
        dism /Apply-Image /ImageFile:"$wimPath" /Index:$index /ApplyDir:W:\
    }

    # Unmount ISO if we mounted one
    if ($isoPath) {
        Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue
    }

    Write-VHDLog "Windows deployed to VHD" "SUCCESS"
    Write-Host ""
    Write-Host "  Next: Use Option 7 to add VHD to boot menu" -ForegroundColor Cyan
}

# ============================================================================
# BOOT MENU
# ============================================================================
function Add-VHDToBootMenu {
    Write-VHDLog "ADD VHD TO BOOT MENU" "SECTION"

    if (-not (Test-Path "W:\Windows")) {
        Write-VHDLog "W:\Windows not found. Deploy Windows first (Option 6)" "ERROR"
        return
    }

    Write-Host ""
    $bootName = Read-Host "Enter boot menu name (default: Windows-VHD)"
    if ([string]::IsNullOrEmpty($bootName)) { $bootName = "Windows-VHD" }

    Write-VHDLog "Creating boot entry..."

    # Create boot files
    $result = & W:\Windows\System32\bcdboot.exe W:\Windows

    if ($LASTEXITCODE -eq 0) {
        # Rename boot entry
        bcdedit /set "{default}" description "$bootName"
        Write-VHDLog "Boot entry '$bootName' created" "SUCCESS"

        Write-Host ""
        Write-Host "  VHD has been added to boot menu." -ForegroundColor Cyan
        Write-Host "  Restart your computer to boot into the VHD." -ForegroundColor Gray
    } else {
        Write-VHDLog "Failed to create boot entry" "ERROR"
    }
}

# ============================================================================
# DRIVER INJECTION
# ============================================================================
function Add-DriversToVHD {
    Set-ConsoleSize
    Clear-Host
    Write-VHDLog "INJECT DRIVERS INTO VHD" "SECTION"

    if (-not (Test-Path "W:\Windows")) {
        Write-VHDLog "W:\Windows not found. Deploy Windows first" "ERROR"
        return
    }

    Write-Host ""
    Write-Host "  [1] Export drivers from current system"
    Write-Host "  [2] Select driver folder manually"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            if (Test-Path $DriverDir) { Remove-Item $DriverDir -Recurse -Force }
            New-Item -ItemType Directory -Path $DriverDir -Force | Out-Null

            Write-VHDLog "Exporting drivers from current system..."
            dism /Online /Export-Driver /Destination:"$DriverDir"

            Write-VHDLog "Injecting drivers into VHD..."
            dism /Image:W:\ /Add-Driver /Driver:"$DriverDir" /Recurse
            Write-VHDLog "Drivers injected" "SUCCESS"
        }
        "2" {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Select folder containing drivers"

            if ($dialog.ShowDialog() -eq 'OK') {
                $driverPath = $dialog.SelectedPath
                Write-VHDLog "Injecting drivers from $driverPath..."
                dism /Image:W:\ /Add-Driver /Driver:"$driverPath" /Recurse
                Write-VHDLog "Drivers injected" "SUCCESS"
            }
        }
    }
}

# ============================================================================
# FEATURE ENABLEMENT
# ============================================================================
function Enable-VHDFeatures {
    Set-ConsoleSize
    Clear-Host
    Write-VHDLog "ENABLE WINDOWS FEATURES" "SECTION"

    if (-not (Test-Path "W:\Windows")) {
        Write-VHDLog "W:\Windows not found. Deploy Windows first" "ERROR"
        return
    }

    Write-Host ""
    Write-Host "  [1] Enable Hyper-V"
    Write-Host "  [2] Enable Windows Subsystem for Linux (WSL)"
    Write-Host "  [3] Enable both Hyper-V and WSL"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Write-VHDLog "Enabling Hyper-V..."
            dism /Image:W:\ /Enable-Feature /FeatureName:Microsoft-Hyper-V-All /All
            Write-VHDLog "Hyper-V enabled" "SUCCESS"
        }
        "2" {
            Write-VHDLog "Enabling WSL..."
            dism /Image:W:\ /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux /All
            Write-VHDLog "WSL enabled" "SUCCESS"
        }
        "3" {
            Write-VHDLog "Enabling Hyper-V..."
            dism /Image:W:\ /Enable-Feature /FeatureName:Microsoft-Hyper-V-All /All
            Write-VHDLog "Enabling WSL..."
            dism /Image:W:\ /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux /All
            Write-VHDLog "Both features enabled" "SUCCESS"
        }
    }
}

# ============================================================================
# QUICK DEPLOY (ALL-IN-ONE)
# ============================================================================
function Start-QuickVHDDeploy {
    Write-VHDLog "QUICK DEPLOY - CREATE BOOTABLE VHD" "SECTION"

    Write-Host ""
    Write-Host "  This wizard will:" -ForegroundColor Cyan
    Write-Host "    1. Create a new VHD file" -ForegroundColor Gray
    Write-Host "    2. Deploy Windows from ISO/WIM" -ForegroundColor Gray
    Write-Host "    3. Optionally inject drivers" -ForegroundColor Gray
    Write-Host "    4. Add to boot menu" -ForegroundColor Gray
    Write-Host ""

    # Step 1: VHD settings
    Write-Host "Step 1: VHD Settings" -ForegroundColor Yellow

    $defaultPath = "$WorkDir\Windows.vhdx"
    $vhdPath = Read-Host "VHD path (default: $defaultPath)"
    if ([string]::IsNullOrEmpty($vhdPath)) { $vhdPath = $defaultPath }

    $sizeGB = Read-Host "VHD size in GB (default: 100)"
    if ([string]::IsNullOrEmpty($sizeGB)) { $sizeGB = 100 }

    Write-Host ""
    Write-Host "  [1] GPT (UEFI) - Recommended"
    Write-Host "  [2] MBR (Legacy BIOS)"
    $styleChoice = Read-Host "Partition style"
    $style = if ($styleChoice -eq "2") { "MBR" } else { "GPT" }

    # Check if exists
    if (Test-Path $vhdPath) {
        try { Dismount-VHD -Path $vhdPath -ErrorAction SilentlyContinue } catch { }
        Remove-Item $vhdPath -Force -ErrorAction SilentlyContinue
    }

    # Create VHD
    Write-Host ""
    Write-Host "Step 2: Creating VHD..." -ForegroundColor Yellow
    $result = New-EmptyVHD -VHDPath $vhdPath -SizeMB ([int]$sizeGB * 1024) -PartitionStyle $style -DriveLetter "W"
    if (-not $result) { return }

    # Step 3: Select Windows source
    Write-Host ""
    Write-Host "Step 3: Select Windows ISO" -ForegroundColor Yellow

    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "ISO files (*.iso)|*.iso"
    $dialog.Title = "Select Windows ISO"

    if ($dialog.ShowDialog() -ne 'OK') {
        Write-VHDLog "No ISO selected" "ERROR"
        return
    }

    $isoPath = $dialog.FileName
    Write-VHDLog "Mounting ISO..."
    $mount = Mount-DiskImage -ImagePath $isoPath -PassThru
    $driveLetter = ($mount | Get-Volume).DriveLetter
    $wimPath = "${driveLetter}:\sources\install.wim"

    if (-not (Test-Path $wimPath)) {
        $wimPath = "${driveLetter}:\sources\install.esd"
    }

    # Select edition
    Write-Host ""
    Write-Host "  Available editions:" -ForegroundColor Cyan
    $images = Get-WindowsImage -ImagePath $wimPath
    foreach ($img in $images) {
        Write-Host "    [$($img.ImageIndex)] $($img.ImageName)" -ForegroundColor Gray
    }
    $index = Read-Host "Select edition index"

    # Deploy
    Write-Host ""
    Write-Host "Step 4: Deploying Windows (this takes 10-20 minutes)..." -ForegroundColor Yellow

    try {
        Expand-WindowsImage -ImagePath $wimPath -Index $index -ApplyPath "W:\" -ErrorAction Stop
    } catch {
        dism /Apply-Image /ImageFile:"$wimPath" /Index:$index /ApplyDir:W:\
    }

    Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue

    # Drivers?
    Write-Host ""
    $addDrivers = Read-Host "Inject current system drivers? (Y/N)"
    if ($addDrivers -eq "Y" -or $addDrivers -eq "y") {
        Write-Host "Step 5: Injecting drivers..." -ForegroundColor Yellow
        if (Test-Path $DriverDir) { Remove-Item $DriverDir -Recurse -Force }
        New-Item -ItemType Directory -Path $DriverDir -Force | Out-Null
        dism /Online /Export-Driver /Destination:"$DriverDir"
        dism /Image:W:\ /Add-Driver /Driver:"$DriverDir" /Recurse
    }

    # Boot menu
    Write-Host ""
    Write-Host "Step 6: Adding to boot menu..." -ForegroundColor Yellow

    $bootName = Read-Host "Boot menu name (default: Windows-VHD)"
    if ([string]::IsNullOrEmpty($bootName)) { $bootName = "Windows-VHD" }

    & W:\Windows\System32\bcdboot.exe W:\Windows
    bcdedit /set "{default}" description "$bootName"

    # Add System Optimizer shortcut
    Write-VHDLog "Adding System Optimizer shortcut..."
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
        $vbsPath = "$env:TEMP\create_shortcut_vhd.vbs"
        $vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force
        & cscript.exe //nologo $vbsPath
        Write-VHDLog "Desktop shortcut created" "SUCCESS"
    } catch {
        Write-VHDLog "Could not create shortcut: $($_.Exception.Message)" "WARNING"
    }

    Write-VHDLog "VHD deployment complete!" "SUCCESS"

    Write-Host ""
    Write-Host "  VHD: $vhdPath" -ForegroundColor Cyan
    Write-Host "  Boot entry: $bootName" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Restart your computer to boot into the VHD." -ForegroundColor Yellow
    Write-Host ""

    $restart = Read-Host "Restart now? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        shutdown /r /t 5 /c "Restarting to boot VHD..."
    }
}

# ============================================================================
# MAIN MENU LOOP
# ============================================================================
function Start-VHDMenu {
    Initialize-VHDDirectories

    do {
        Show-VHDMenu
        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Start-QuickVHDDeploy }
            "2" { Start-CreateEmptyVHD -Style "GPT" }
            "3" { Start-CreateEmptyVHD -Style "MBR" }
            "4" { Mount-ExistingVHD }
            "5" { Dismount-ExistingVHD }
            "6" { Deploy-WindowsToVHD }
            "7" { Add-VHDToBootMenu }
            "8" { Add-DriversToVHD }
            "9" { Enable-VHDFeatures }
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
    'Initialize-VHDLogging',
    'Write-VHDLog',
    'Set-ConsoleSize',
    'Initialize-VHDDirectories',
    'Show-VHDMenu',
    'New-EmptyVHD',
    'Start-CreateEmptyVHD',
    'Mount-ExistingVHD',
    'Dismount-ExistingVHD',
    'Deploy-WindowsToVHD',
    'Add-VHDToBootMenu',
    'Add-DriversToVHD',
    'Enable-VHDFeatures',
    'Start-QuickVHDDeploy',
    'Start-VHDMenu'
)
