#Requires -Version 5.1
<#
.SYNOPSIS
    Backup Module - System Optimizer
.DESCRIPTION
    Provides comprehensive user profile backup and restore functionality.
    Supports browsers, applications, and full profile backup.

Exported Functions:
    Show-UserBackupMenu      - Interactive backup/restore menu
    Backup-UserProfile       - Backup user data
    Restore-UserProfile      - Restore from backup
    Backup-BrowserData       - Backup browser profiles
    Backup-ApplicationData   - Backup app settings

Backup Types:
    Essential: Desktop, Documents, Downloads
    Browsers: Firefox, Chrome, Edge, Brave, Opera, Vivaldi
    Applications: Outlook, Thunderbird, Discord, Spotify
    Full Profile: Complete user folder
    Custom: User-selected items

Features:
    - External drive detection
    - Cross-computer restore
    - JSON manifests
    - PST file handling
    - Progress tracking
    - Integrity verification

Backup Location:
    C:\System_Optimizer_Backup\

Requires Admin: No

Version: 1.0.0
#>
# ============================================================================


# Import logging and progress functions if available
$script:HasWriteLog = Get-Command Write-Log -ErrorAction SilentlyContinue
$script:HasProgress = Get-Command Start-ProgressOperation -ErrorAction SilentlyContinue

# Fallback Write-Log if not available from Logging module
if (-not $script:HasWriteLog) {
    function Write-Log {
        param([string]$Message, [string]$Type = "INFO")
        $time = Get-Date -Format "HH:mm:ss"
        switch ($Type) {
            "SUCCESS" { Write-Host "[$time] [OK] $Message" -ForegroundColor Green }
            "ERROR"   { Write-Host "[$time] [X] $Message" -ForegroundColor Red }
            "WARNING" { Write-Host "[$time] [!] $Message" -ForegroundColor Yellow }
            "SECTION" { Write-Host "`n[$time] === $Message ===" -ForegroundColor Cyan }
            default   { Write-Host "[$time] [-] $Message" -ForegroundColor Gray }
        }
    }
}

function Show-UserBackupMenu {
    do {
        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  User Profile Backup & Restore" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Backup User Profile" -ForegroundColor Green
        Write-Host "  [2] Restore User Profile"
        Write-Host "  [3] Backup Browser Data Only"
        Write-Host "  [4] Backup Outlook Data Only"
        Write-Host "  [5] View Backup Status"
        Write-Host "  [0] Back to main menu"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Start-UserProfileBackup }
            "2" { Start-UserProfileRestore }
            "3" { Start-BrowserBackup }
            "4" { Start-OutlookBackup }
            "5" { Show-BackupStatus }
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

function Get-BackupDestination {
    param([string]$DefaultPath = "C:\System_Optimizer_Backup\UserProfiles")

    Write-Host ""
    Write-Host "Select backup destination:" -ForegroundColor Cyan
    Write-Host "  [1] Use default location: $DefaultPath"
    Write-Host "  [2] Browse for custom location"
    Write-Host "  [3] Auto-detect external drives"
    Write-Host "  [4] Search for existing backups"
    Write-Host ""

    $choice = Read-Host "Select option (1-4)"

    switch ($choice) {
        "2" {
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $browser = New-Object System.Windows.Forms.FolderBrowserDialog
                $browser.Description = "Select backup destination folder"
                $browser.SelectedPath = $DefaultPath

                if ($browser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    return $browser.SelectedPath
                } else {
                    Write-Log "No folder selected, using default" "WARNING"
                    return $DefaultPath
                }
            } catch {
                Write-Log "Error opening folder browser, using default: $_" "WARNING"
                return $DefaultPath
            }
        }
        "3" {
            return Get-ExternalDriveDestination -DefaultPath $DefaultPath
        }
        "4" {
            return Search-ExistingBackups -DefaultPath $DefaultPath
        }
        default {
            return $DefaultPath
        }
    }
}

function Get-ExternalDriveDestination {
    param([string]$DefaultPath)

    Write-Host ""
    Write-Host "Detecting external drives..." -ForegroundColor Cyan

    # Get all removable and external drives
    $externalDrives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {
        $_.DriveType -eq 2 -or $_.DriveType -eq 3 -and $_.DeviceID -ne "C:"
    } | Sort-Object DeviceID

    if ($externalDrives.Count -eq 0) {
        Write-Host "No external drives detected. Using default location." -ForegroundColor Yellow
        return $DefaultPath
    }

    Write-Host ""
    Write-Host "Available external drives:" -ForegroundColor Cyan

    $driveIndex = 1
    $driveList = @()

    foreach ($drive in $externalDrives) {
        $driveType = switch ($drive.DriveType) {
            2 { "Removable" }
            3 { "Fixed" }
            default { "Unknown" }
        }

        $freeSpaceGB = [Math]::Round($drive.FreeSpace / 1GB, 1)
        $totalSpaceGB = [Math]::Round($drive.Size / 1GB, 1)

        # Check if this drive already has backups
        $backupPath = "$($drive.DeviceID)\System_Optimizer_Backup\UserProfiles"
        $hasBackups = Test-Path $backupPath
        $backupIndicator = if ($hasBackups) { " [Has Backups]" } else { "" }

        Write-Host "  [$driveIndex] $($drive.DeviceID) ($driveType) - $freeSpaceGB GB free / $totalSpaceGB GB total$backupIndicator" -ForegroundColor Gray

        $driveList += @{
            Index = $driveIndex
            Drive = $drive
            BackupPath = $backupPath
            HasBackups = $hasBackups
        }
        $driveIndex++
    }

    Write-Host "  [0] Use default location instead" -ForegroundColor Gray
    Write-Host ""

    $selection = Read-Host "Select drive (0-$($externalDrives.Count))"

    if ($selection -eq "0" -or $selection -eq "") {
        return $DefaultPath
    }

    try {
        $selectedIndex = [int]$selection
        if ($selectedIndex -gt 0 -and $selectedIndex -le $driveList.Count) {
            $selectedDrive = $driveList[$selectedIndex - 1]
            $destinationPath = $selectedDrive.BackupPath

            # Create backup directory if it doesn't exist
            if (-not (Test-Path $destinationPath)) {
                New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
                Write-Log "Created backup directory: $destinationPath" "SUCCESS"
            }

            if ($selectedDrive.HasBackups) {
                Write-Log "Selected drive already contains backups" "INFO"
            }

            return $destinationPath
        } else {
            Write-Log "Invalid selection, using default" "WARNING"
            return $DefaultPath
        }
    } catch {
        Write-Log "Invalid input, using default" "WARNING"
        return $DefaultPath
    }
}

function Search-ExistingBackups {
    param([string]$DefaultPath)

    Write-Host ""
    Write-Host "Searching for existing backups..." -ForegroundColor Cyan

    $searchPaths = @()

    # Add default path
    $searchPaths += $DefaultPath

    # Add all drives
    $allDrives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -in @(2,3) }
    foreach ($drive in $allDrives) {
        $searchPaths += "$($drive.DeviceID)\System_Optimizer_Backup\UserProfiles"
    }

    # Add common backup locations
    $searchPaths += @(
        "$env:USERPROFILE\Documents\System_Optimizer_Backup\UserProfiles",
        "D:\System_Optimizer_Backup\UserProfiles",
        "E:\System_Optimizer_Backup\UserProfiles"
    )

    $foundBackups = @()

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            # Look for user folders with manifests
            $userFolders = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue

            foreach ($userFolder in $userFolders) {
                $manifestPath = Join-Path $userFolder.FullName "backup_manifest.json"
                if (Test-Path $manifestPath) {
                    try {
                        $manifest = Get-Content $manifestPath | ConvertFrom-Json
                        $foundBackups += @{
                            Path = $userFolder.FullName
                            ParentPath = $path
                            Manifest = $manifest
                            LastModified = $userFolder.LastWriteTime
                        }
                    } catch {
                        # Skip invalid manifests
                    }
                }
            }
        }
    }

    if ($foundBackups.Count -eq 0) {
        Write-Host "No existing backups found. Using default location." -ForegroundColor Yellow
        return $DefaultPath
    }

    Write-Host ""
    Write-Host "Found existing backups:" -ForegroundColor Cyan

    $backupIndex = 1
    foreach ($backup in $foundBackups) {
        $manifest = $backup.Manifest
        $ageInDays = [Math]::Round((Get-Date - $backup.LastModified).TotalDays, 1)

        Write-Host "  [$backupIndex] User: $($manifest.Username)" -ForegroundColor Gray
        Write-Host "      Location: $($backup.ParentPath)" -ForegroundColor DarkGray
        Write-Host "      Date: $($manifest.BackupDate) ($ageInDays days ago)" -ForegroundColor DarkGray
        Write-Host "      Type: $($manifest.BackupType) - $($manifest.TotalSizeMB) MB" -ForegroundColor DarkGray
        Write-Host ""

        $backupIndex++
    }

    Write-Host "  [0] Use default location instead" -ForegroundColor Gray
    Write-Host ""

    $selection = Read-Host "Select backup location to use (0-$($foundBackups.Count))"

    if ($selection -eq "0" -or $selection -eq "") {
        return $DefaultPath
    }

    try {
        $selectedIndex = [int]$selection
        if ($selectedIndex -gt 0 -and $selectedIndex -le $foundBackups.Count) {
            $selectedBackup = $foundBackups[$selectedIndex - 1]
            Write-Log "Selected existing backup location: $($selectedBackup.ParentPath)" "SUCCESS"
            return $selectedBackup.ParentPath
        } else {
            Write-Log "Invalid selection, using default" "WARNING"
            return $DefaultPath
        }
    } catch {
        Write-Log "Invalid input, using default" "WARNING"
        return $DefaultPath
    }
}

# Enhanced folder list with more browser support and user data
$script:BackupFolders = @{
    "Essential" = @(
        "Desktop",
        "Downloads",
        "Favorites",
        "Documents",
        "Music",
        "Pictures",
        "Videos"
    )
    "Browsers" = @(
        "AppData\Local\Mozilla",           # Firefox
        "AppData\Roaming\Mozilla",         # Firefox profiles
        "AppData\Local\Google",            # Chrome
        "AppData\Local\Microsoft\Edge",    # Edge
        "AppData\Local\BraveSoftware",     # Brave
        "AppData\Roaming\Opera Software",  # Opera
        "AppData\Local\Vivaldi"            # Vivaldi
    )
    "Applications" = @(
        "AppData\Roaming\Microsoft\Outlook",     # Outlook profiles
        "AppData\Local\Microsoft\Outlook",       # Outlook data
        "AppData\Roaming\Thunderbird",           # Thunderbird
        "AppData\Local\Discord",                 # Discord
        "AppData\Roaming\Spotify",               # Spotify
        "AppData\Roaming\Slack",                 # Slack
        "AppData\Local\WhatsApp"                 # WhatsApp Desktop
    )
}

function Get-CustomBackupSelection {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  Custom Backup Selection" -ForegroundColor Yellow
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Select folders and locations to backup:" -ForegroundColor Cyan
    Write-Host ""

    $selectedFolders = @()
    $customPaths = @()

    do {
        # Show current selections
        if ($selectedFolders.Count -gt 0 -or $customPaths.Count -gt 0) {
            Write-Host ""
            Write-Host "Current selections:" -ForegroundColor Green

            if ($selectedFolders.Count -gt 0) {
                Write-Host "  Standard folders:" -ForegroundColor Cyan
                foreach ($folder in $selectedFolders) {
                    Write-Host "    • $folder" -ForegroundColor Gray
                }
            }

            if ($customPaths.Count -gt 0) {
                Write-Host "  Custom paths:" -ForegroundColor Cyan
                foreach ($path in $customPaths) {
                    $displayPath = if ($path.StartsWith($UserProfile)) {
                        $path.Replace($UserProfile, "~")
                    } else { $path }
                    Write-Host "    • $displayPath" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }

        Write-Host "Available options:" -ForegroundColor Cyan
        Write-Host ""

        # Essential folders
        Write-Host "  Essential Folders:" -ForegroundColor Yellow
        $essentialIndex = 1
        foreach ($folder in $BackupFolders.Essential) {
            $isSelected = $selectedFolders -contains $folder
            $marker = if ($isSelected) { "X" } else { " " }
            Write-Host "    [$essentialIndex] [$marker] $folder" -ForegroundColor Gray
            $essentialIndex++
        }

        Write-Host ""
        Write-Host "  Browser Data:" -ForegroundColor Yellow
        $browserIndex = 10
        foreach ($folder in $BackupFolders.Browsers) {
            $isSelected = $selectedFolders -contains $folder
            $marker = if ($isSelected) { "X" } else { " " }
            Write-Host "    [$browserIndex] [$marker] $folder" -ForegroundColor Gray
            $browserIndex++
        }

        Write-Host ""
        Write-Host "  Application Data:" -ForegroundColor Yellow
        $appIndex = 20
        foreach ($folder in $BackupFolders.Applications) {
            $isSelected = $selectedFolders -contains $folder
            $marker = if ($isSelected) { "X" } else { " " }
            Write-Host "    [$appIndex] [$marker] $folder" -ForegroundColor Gray
            $appIndex++
        }

        Write-Host ""
        Write-Host "  Custom Options:" -ForegroundColor Yellow
        Write-Host "    [30] Add custom folder/file path"
        Write-Host "    [31] Add game saves location"
        Write-Host "    [32] Add application data folder"
        Write-Host "    [33] Remove a selection"
        Write-Host ""
        Write-Host "  [99] Done - Start backup with selected items" -ForegroundColor Green
        Write-Host "  [0] Cancel custom selection" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            # Essential folders (1-7)
            { $_ -in 1..7 } {
                $folderIndex = [int]$_ - 1
                if ($folderIndex -lt $BackupFolders.Essential.Count) {
                    $folder = $BackupFolders.Essential[$folderIndex]
                    if ($selectedFolders -contains $folder) {
                        $selectedFolders = $selectedFolders | Where-Object { $_ -ne $folder }
                        Write-Host "Removed: $folder" -ForegroundColor Yellow
                    } else {
                        $selectedFolders += $folder
                        Write-Host "Added: $folder" -ForegroundColor Green
                    }
                }
            }

            # Browser folders (10-16)
            { $_ -in 10..16 } {
                $folderIndex = [int]$_ - 10
                if ($folderIndex -lt $BackupFolders.Browsers.Count) {
                    $folder = $BackupFolders.Browsers[$folderIndex]
                    if ($selectedFolders -contains $folder) {
                        $selectedFolders = $selectedFolders | Where-Object { $_ -ne $folder }
                        Write-Host "Removed: $folder" -ForegroundColor Yellow
                    } else {
                        $selectedFolders += $folder
                        Write-Host "Added: $folder" -ForegroundColor Green
                    }
                }
            }

            # Application folders (20-27)
            { $_ -in 20..27 } {
                $folderIndex = [int]$_ - 20
                if ($folderIndex -lt $BackupFolders.Applications.Count) {
                    $folder = $BackupFolders.Applications[$folderIndex]
                    if ($selectedFolders -contains $folder) {
                        $selectedFolders = $selectedFolders | Where-Object { $_ -ne $folder }
                        Write-Host "Removed: $folder" -ForegroundColor Yellow
                    } else {
                        $selectedFolders += $folder
                        Write-Host "Added: $folder" -ForegroundColor Green
                    }
                }
            }

            "30" {
                # Add custom path
                $customPath = Add-CustomPath
                if ($customPath -and $customPaths -notcontains $customPath) {
                    $customPaths += $customPath
                    Write-Host "Added custom path: $customPath" -ForegroundColor Green
                }
            }

            "31" {
                # Add game saves
                $gamePath = Add-GameSavesPath
                if ($gamePath -and $customPaths -notcontains $gamePath) {
                    $customPaths += $gamePath
                    Write-Host "Added game saves path: $gamePath" -ForegroundColor Green
                }
            }

            "32" {
                # Add application data
                $appPath = Add-ApplicationDataPath
                if ($appPath -and $customPaths -notcontains $appPath) {
                    $customPaths += $appPath
                    Write-Host "Added application data path: $appPath" -ForegroundColor Green
                }
            }

            "33" {
                # Remove selection
                Remove-Selection -SelectedFolders ([ref]$selectedFolders) -CustomPaths ([ref]$customPaths)
            }

            "99" {
                # Done
                if ($selectedFolders.Count -eq 0 -and $customPaths.Count -eq 0) {
                    Write-Host "No items selected. Please select at least one item to backup." -ForegroundColor Red
                    Start-Sleep 2
                } else {
                    break
                }
            }

            "0" {
                # Cancel
                Write-Host "Custom selection cancelled" -ForegroundColor Yellow
                return $BackupFolders.Essential  # Return default
            }

            default {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep 1
            }
        }

        Clear-Host
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host "  Custom Backup Selection" -ForegroundColor Yellow
        Write-Host "======================================" -ForegroundColor Cyan

    } while ($true)

    # Combine selected folders and custom paths
    $allSelections = $selectedFolders + $customPaths

    Write-Host ""
    Write-Host "Final backup selection:" -ForegroundColor Green
    foreach ($item in $allSelections) {
        Write-Host "  • $item" -ForegroundColor Gray
    }

    return $allSelections
}

function Add-CustomPath {
    Write-Host ""
    Write-Host "Add Custom Path:" -ForegroundColor Cyan
    Write-Host "Enter the full path to backup (relative to user profile or absolute path)"
    Write-Host "Examples:"
    Write-Host "  AppData\Local\MyApp"
    Write-Host "  C:\MyFolder"
    Write-Host "  Documents\MyProject"
    Write-Host ""

    $path = Read-Host "Enter path (or press Enter to cancel)"

    if ([string]::IsNullOrWhiteSpace($path)) {
        return $null
    }

    # Convert to relative path if it's under user profile
    if ($path.StartsWith($UserProfile)) {
        $path = $path.Substring($UserProfile.Length + 1)
    }

    # Check if path exists
    $fullPath = if ([System.IO.Path]::IsPathRooted($path)) {
        $path
    } else {
        Join-Path $UserProfile $path
    }

    if (-not (Test-Path $fullPath)) {
        Write-Host "Warning: Path does not exist: $fullPath" -ForegroundColor Yellow
        $confirm = Read-Host "Add anyway? (Y/N)"
        if ($confirm -ne "Y" -and $confirm -ne "y") {
            return $null
        }
    } else {
        $size = try {
            (Get-ChildItem -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue |
             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB
        } catch { 0 }
        Write-Host "Path exists. Size: $([Math]::Round($size, 1)) MB" -ForegroundColor Green
    }

    return $path
}

function Add-GameSavesPath {
    Write-Host ""
    Write-Host "Common Game Save Locations:" -ForegroundColor Cyan
    Write-Host "  [1] Documents\My Games"
    Write-Host "  [2] AppData\Local\[Game Name]"
    Write-Host "  [3] AppData\Roaming\[Game Name]"
    Write-Host "  [4] Documents\[Game Name]"
    Write-Host "  [5] Custom game save path"
    Write-Host ""

    $choice = Read-Host "Select option (1-5)"

    switch ($choice) {
        "1" { return "Documents\My Games" }
        "2" {
            $gameName = Read-Host "Enter game name"
            if ($gameName) { return "AppData\Local\$gameName" }
        }
        "3" {
            $gameName = Read-Host "Enter game name"
            if ($gameName) { return "AppData\Roaming\$gameName" }
        }
        "4" {
            $gameName = Read-Host "Enter game name"
            if ($gameName) { return "Documents\$gameName" }
        }
        "5" {
            return Add-CustomPath
        }
    }

    return $null
}

function Add-ApplicationDataPath {
    Write-Host ""
    Write-Host "Common Application Data Locations:" -ForegroundColor Cyan
    Write-Host "  [1] AppData\Local\[App Name]"
    Write-Host "  [2] AppData\Roaming\[App Name]"
    Write-Host "  [3] Documents\[App Name]"
    Write-Host "  [4] Program Files application data"
    Write-Host "  [5] Custom application path"
    Write-Host ""

    $choice = Read-Host "Select option (1-5)"

    switch ($choice) {
        "1" {
            $appName = Read-Host "Enter application name"
            if ($appName) { return "AppData\Local\$appName" }
        }
        "2" {
            $appName = Read-Host "Enter application name"
            if ($appName) { return "AppData\Roaming\$appName" }
        }
        "3" {
            $appName = Read-Host "Enter application name"
            if ($appName) { return "Documents\$appName" }
        }
        "4" {
            Write-Host "Enter full path to Program Files application data folder:"
            $path = Read-Host "Path"
            return $path
        }
        "5" {
            return Add-CustomPath
        }
    }

    return $null
}

function Remove-Selection {
    param(
        [ref]$SelectedFolders,
        [ref]$CustomPaths
    )

    $allItems = @()
    $allItems += $SelectedFolders.Value | ForEach-Object { @{ Type = "Standard"; Path = $_ } }
    $allItems += $CustomPaths.Value | ForEach-Object { @{ Type = "Custom"; Path = $_ } }

    if ($allItems.Count -eq 0) {
        Write-Host "No items to remove" -ForegroundColor Yellow
        Start-Sleep 1
        return
    }

    Write-Host ""
    Write-Host "Select item to remove:" -ForegroundColor Cyan

    for ($i = 0; $i -lt $allItems.Count; $i++) {
        $item = $allItems[$i]
        Write-Host "  [$($i + 1)] [$($item.Type)] $($item.Path)" -ForegroundColor Gray
    }

    Write-Host "  [0] Cancel" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "Select item to remove"

    if ($choice -eq "0" -or [string]::IsNullOrWhiteSpace($choice)) {
        return
    }

    try {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $allItems.Count) {
            $itemToRemove = $allItems[$index]

            if ($itemToRemove.Type -eq "Standard") {
                $SelectedFolders.Value = $SelectedFolders.Value | Where-Object { $_ -ne $itemToRemove.Path }
            } else {
                $CustomPaths.Value = $CustomPaths.Value | Where-Object { $_ -ne $itemToRemove.Path }
            }

            Write-Host "Removed: $($itemToRemove.Path)" -ForegroundColor Yellow
            Start-Sleep 1
        }
    } catch {
        Write-Host "Invalid selection" -ForegroundColor Red
        Start-Sleep 1
    }
}

# Script variables
$script:Username = $env:USERNAME
$script:UserProfile = $env:USERPROFILE
$script:AppData = $env:LOCALAPPDATA


function Start-UserProfileBackup {
    Write-Log "USER PROFILE BACKUP" "SECTION"

    $destination = Get-BackupDestination
    $backupPath = "$destination\$Username"

    # Check if backup already exists
    if (Test-Path $backupPath) {
        Write-Host ""
        Write-Host "Existing backup found for user: $Username" -ForegroundColor Yellow
        $overwrite = Read-Host "Overwrite existing backup? (Y/N)"
        if ($overwrite -ne "Y" -and $overwrite -ne "y") {
            Write-Log "Backup cancelled by user" "INFO"
            return
        }

        # Rename existing backup
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $oldBackupPath = "$destination\${Username}_old_$timestamp"
        Rename-Item $backupPath $oldBackupPath -ErrorAction SilentlyContinue
        Write-Log "Previous backup moved to: $oldBackupPath" "INFO"
    }

    # Create backup directory
    if (-not (Test-Path $destination)) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
    }

    Write-Host ""
    Write-Host "Select what to backup:" -ForegroundColor Cyan
    Write-Host "  [1] Essential folders only (Desktop, Documents, etc.)"
    Write-Host "  [2] Essential + Browser data"
    Write-Host "  [3] Essential + Applications data"
    Write-Host "  [4] Everything (Full backup)"
    Write-Host "  [5] Custom selection (Choose your own folders)"
    Write-Host ""

    $backupChoice = Read-Host "Select option (1-5)"

    $foldersToBackup = @()
    switch ($backupChoice) {
        "1" { $foldersToBackup = $BackupFolders.Essential }
        "2" { $foldersToBackup = $BackupFolders.Essential + $BackupFolders.Browsers }
        "3" { $foldersToBackup = $BackupFolders.Essential + $BackupFolders.Applications }
        "4" { $foldersToBackup = $BackupFolders.Essential + $BackupFolders.Browsers + $BackupFolders.Applications }
        "5" { $foldersToBackup = Get-CustomBackupSelection }
        default {
            Write-Log "Invalid selection, using essential folders only" "WARNING"
            $foldersToBackup = $BackupFolders.Essential
        }
    }

    # Close Outlook if backing up application data
    if ($backupChoice -in @("3", "4")) {
        Write-Host ""
        Write-Host "Closing Outlook and other applications..." -ForegroundColor Yellow
        Get-Process | Where-Object { $_.Name -in @("OUTLOOK", "Thunderbird", "Discord", "Spotify") } | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
    }

    Write-Log "Starting backup for user: $Username" "INFO"
    Write-Log "Backup destination: $backupPath" "INFO"

    $backupStartTime = Get-Date
    $totalFolders = $foldersToBackup.Count
    $currentFolder = 0
    $totalSize = 0
    $successCount = 0
    $failedCount = 0
    $skippedCount = 0

    # Use progress tracking if available
    $hasProgress = Get-Command 'Start-ProgressOperation' -ErrorAction SilentlyContinue
    if ($hasProgress) {
        Start-ProgressOperation -Name "Backing Up User Profile" -TotalItems $totalFolders
    }

    foreach ($folder in $foldersToBackup) {
        $currentFolder++

        # Handle both relative and absolute paths
        if ([System.IO.Path]::IsPathRooted($folder)) {
            $currentLocalFolder = $folder
            $relativePath = $folder.Replace(":", "_drive")  # Convert C: to C_drive for backup structure
        } else {
            $currentLocalFolder = Join-Path $UserProfile $folder
            $relativePath = $folder
        }

        $currentRemoteFolder = Join-Path $backupPath $relativePath
        $displayName = Split-Path $relativePath -Leaf

        if (Test-Path $currentLocalFolder) {
            try {
                # Calculate folder size
                $folderSize = (Get-ChildItem -Path $currentLocalFolder -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB
                $folderSizeRounded = [Math]::Round($folderSize, 1)
                $totalSize += $folderSizeRounded

                if (-not $hasProgress) {
                    Write-Progress -Activity "Backing up user profile" -Status "Processing $relativePath" -PercentComplete (($currentFolder / $totalFolders) * 100)
                    Write-Log "Backing up: $relativePath - $folderSizeRounded MB" "INFO"
                }

                # Create parent directory if needed
                $parentDir = Split-Path $currentRemoteFolder -Parent
                if (-not (Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }

                # Copy folder
                Copy-Item -Path $currentLocalFolder -Destination $currentRemoteFolder -Recurse -Force -ErrorAction SilentlyContinue

                if ($hasProgress) {
                    Update-ProgressItem -ItemName $displayName -Status 'Success' -Message "${folderSizeRounded} MB"
                } else {
                    Write-Log "Successfully backed up: $relativePath" "SUCCESS"
                }
                $successCount++

            } catch {
                if ($hasProgress) {
                    Update-ProgressItem -ItemName $displayName -Status 'Failed' -Message $_.Exception.Message
                } else {
                    Write-Log "Failed to backup $relativePath`: $_" "ERROR"
                }
                $failedCount++
            }
        } else {
            if ($hasProgress) {
                Update-ProgressItem -ItemName $displayName -Status 'Skipped' -Message "Not found"
            } else {
                Write-Log "Folder not found, skipping: $relativePath" "WARNING"
            }
            $skippedCount++
        }
    }

    # Backup Outlook PST files separately
    if ($backupChoice -in @("3", "4")) {
        Backup-OutlookPSTFiles -BackupPath $backupPath
    }

    if ($hasProgress) {
        Complete-ProgressOperation
    } else {
        Write-Progress -Activity "Backing up user profile" -Completed
    }

    # Create backup manifest with enhanced metadata
    $manifest = @{
        Username = $Username
        ComputerName = $env:COMPUTERNAME
        BackupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        BackupTimestamp = (Get-Date).Ticks
        BackupType = switch ($backupChoice) {
            "1" { "Essential" }
            "2" { "Essential + Browsers" }
            "3" { "Essential + Applications" }
            "4" { "Full Backup" }
            "5" { "Custom Selection" }
        }
        TotalSizeMB = [Math]::Round($totalSize, 1)
        FoldersBackedUp = $foldersToBackup
        BackupLocation = $backupPath
        SystemInfo = @{
            OSVersion = (Get-CimInstance Win32_OperatingSystem).Caption
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            SystemOptimizerVersion = "2.1.0"
        }
        BackupStats = @{
            TotalFolders = $totalFolders
            SuccessfulBackups = $successCount
            FailedBackups = $failedCount
            SkippedBackups = $skippedCount
            BackupDuration = $null  # Will be calculated
        }
    }

    # Calculate backup duration
    $backupEndTime = Get-Date
    $backupDuration = ($backupEndTime - $backupStartTime).TotalMinutes
    $manifest.BackupStats.BackupDuration = [Math]::Round($backupDuration, 2)

    $manifest | ConvertTo-Json -Depth 4 | Out-File "$backupPath\backup_manifest.json" -Encoding UTF8

    # Show detailed summary
    Write-Host ""
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  User Profile Backup Complete" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  User: $Username" -ForegroundColor Gray
    Write-Host "  Type: $($manifest.BackupType)" -ForegroundColor Gray
    Write-Host "  Size: $([Math]::Round($totalSize, 1)) MB" -ForegroundColor Gray
    Write-Host "  Duration: $([Math]::Round($backupDuration, 1)) min" -ForegroundColor DarkGray
    Write-Host "  Success: $successCount | Failed: $failedCount | Skipped: $skippedCount" -ForegroundColor Gray
    Write-Host "  Location: $backupPath" -ForegroundColor DarkGray
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    Write-Log "Backup completed successfully!" "SUCCESS"

    # Open backup folder
    $openFolder = Read-Host "Open backup folder? (Y/N)"
    if ($openFolder -eq "Y" -or $openFolder -eq "y") {
        Start-Process explorer.exe -ArgumentList $backupPath
    }
}

function Start-UserProfileRestore {
    Write-Log "USER PROFILE RESTORE" "SECTION"

    # First, search for all available backups
    Write-Host ""
    Write-Host "Searching for available backups..." -ForegroundColor Cyan

    $searchPaths = @()

    # Add default path
    $searchPaths += "C:\System_Optimizer_Backup\UserProfiles"

    # Add all drives
    $allDrives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -in @(2,3) }
    foreach ($drive in $allDrives) {
        $searchPaths += "$($drive.DeviceID)\System_Optimizer_Backup\UserProfiles"
    }

    $availableBackups = @()

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $userFolders = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue

            foreach ($userFolder in $userFolders) {
                $manifestPath = Join-Path $userFolder.FullName "backup_manifest.json"
                if (Test-Path $manifestPath) {
                    try {
                        $manifest = Get-Content $manifestPath | ConvertFrom-Json
                        $availableBackups += @{
                            Path = $userFolder.FullName
                            ParentPath = $path
                            Manifest = $manifest
                            LastModified = $userFolder.LastWriteTime
                        }
                    } catch {
                        # Skip invalid manifests
                    }
                }
            }
        }
    }

    if ($availableBackups.Count -eq 0) {
        Write-Log "No backups found on any drive" "ERROR"
        Write-Host ""
        Write-Host "No backups were found. Please create a backup first." -ForegroundColor Yellow
        return
    }

    # Filter backups for current user or show all
    $currentUserBackups = $availableBackups | Where-Object { $_.Manifest.Username -eq $Username }
    $otherUserBackups = $availableBackups | Where-Object { $_.Manifest.Username -ne $Username }

    Write-Host ""
    Write-Host "Available backups:" -ForegroundColor Cyan

    $backupIndex = 1
    $backupList = @()

    if ($currentUserBackups.Count -gt 0) {
        Write-Host ""
        Write-Host "  Backups for current user ($Username):" -ForegroundColor Green
        foreach ($backup in $currentUserBackups) {
            $manifest = $backup.Manifest
            $ageInDays = [Math]::Round((Get-Date - $backup.LastModified).TotalDays, 1)
            $driveInfo = Split-Path $backup.ParentPath -Qualifier

            Write-Host "    [$backupIndex] $($manifest.BackupType) - $($manifest.TotalSizeMB) MB" -ForegroundColor Gray
            Write-Host "        Date: $($manifest.BackupDate) - $ageInDays days ago" -ForegroundColor DarkGray
            Write-Host "        Location: $driveInfo" -ForegroundColor DarkGray
            if ($manifest.ComputerName -and $manifest.ComputerName -ne $env:COMPUTERNAME) {
                Write-Host "        From computer: $($manifest.ComputerName)" -ForegroundColor DarkYellow
            }
            Write-Host ""

            $backupList += $backup
            $backupIndex++
        }
    }

    if ($otherUserBackups.Count -gt 0) {
        Write-Host "  Backups for other users:" -ForegroundColor Yellow
        foreach ($backup in $otherUserBackups) {
            $manifest = $backup.Manifest
            $ageInDays = [Math]::Round((Get-Date - $backup.LastModified).TotalDays, 1)
            $driveInfo = Split-Path $backup.ParentPath -Qualifier

            Write-Host "    [$backupIndex] User: $($manifest.Username) - $($manifest.BackupType)" -ForegroundColor Gray
            Write-Host "        Date: $($manifest.BackupDate) - $ageInDays days ago" -ForegroundColor DarkGray
            Write-Host "        Location: $driveInfo - $($manifest.TotalSizeMB) MB" -ForegroundColor DarkGray
            if ($manifest.ComputerName) {
                Write-Host "        From computer: $($manifest.ComputerName)" -ForegroundColor DarkGray
            }
            Write-Host ""

            $backupList += $backup
            $backupIndex++
        }
    }

    Write-Host "  [0] Cancel restore" -ForegroundColor Gray
    Write-Host ""

    $selection = Read-Host "Select backup to restore (0-$($backupList.Count))"

    if ($selection -eq "0" -or $selection -eq "") {
        Write-Log "Restore cancelled by user" "INFO"
        return
    }

    try {
        $selectedIndex = [int]$selection
        if ($selectedIndex -gt 0 -and $selectedIndex -le $backupList.Count) {
            $selectedBackup = $backupList[$selectedIndex - 1]
            $backupPath = $selectedBackup.Path
            $manifest = $selectedBackup.Manifest
        } else {
            Write-Log "Invalid selection" "ERROR"
            return
        }
    } catch {
        Write-Log "Invalid input" "ERROR"
        return
    }

    # Show detailed backup information
    Write-Host ""
    Write-Host "Selected Backup Details:" -ForegroundColor Cyan
    Write-Host "  User: $($manifest.Username)" -ForegroundColor Gray
    Write-Host "  Backup Date: $($manifest.BackupDate)" -ForegroundColor Gray
    Write-Host "  Backup Type: $($manifest.BackupType)" -ForegroundColor Gray
    Write-Host "  Total Size: $($manifest.TotalSizeMB) MB" -ForegroundColor Gray
    Write-Host "  Location: $backupPath" -ForegroundColor Gray
    if ($manifest.ComputerName -and $manifest.ComputerName -ne $env:COMPUTERNAME) {
        Write-Host "  Original Computer: $($manifest.ComputerName)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  WARNING: This backup is from a different computer!" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "WARNING: This will overwrite existing user data!" -ForegroundColor Red
    Write-Host "Existing folders will be renamed with .old extension" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Continue with restore? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Log "Restore cancelled by user" "INFO"
        return
    }

    Write-Log "Starting restore from: $backupPath" "INFO"

    # Get list of folders to restore from manifest or directory listing
    if ($manifest.FoldersBackedUp) {
        $foldersToRestore = $manifest.FoldersBackedUp
    } else {
        # Fallback for legacy backups without manifest
        $foldersToRestore = Get-ChildItem -Path $backupPath -Directory | Where-Object { $_.Name -ne "backup_manifest.json" } | ForEach-Object { $_.Name }
    }

    # Use progress tracking if available
    $hasProgress = Get-Command 'Start-ProgressOperation' -ErrorAction SilentlyContinue
    if ($hasProgress) {
        Start-ProgressOperation -Name "Restoring User Profile" -TotalItems $foldersToRestore.Count
    }

    $restoredCount = 0
    $failedCount = 0
    foreach ($folderName in $foldersToRestore) {
        $sourcePath = Join-Path $backupPath $folderName
        $targetPath = Join-Path $UserProfile $folderName
        $displayName = Split-Path $folderName -Leaf

        if (Test-Path $sourcePath) {
            try {
                if (-not $hasProgress) {
                    Write-Log "Restoring: $folderName" "INFO"
                }

                # Backup existing folder if it exists
                if (Test-Path $targetPath) {
                    $oldPath = "$targetPath.old"
                    if (Test-Path $oldPath) {
                        Remove-Item $oldPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Rename-Item $targetPath $oldPath -ErrorAction SilentlyContinue
                }

                # Create parent directory if needed
                $parentDir = Split-Path $targetPath -Parent
                if (-not (Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }

                # Copy restored data
                Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force -ErrorAction Stop

                if ($hasProgress) {
                    Update-ProgressItem -ItemName $displayName -Status 'Success'
                } else {
                    Write-Log "Successfully restored: $folderName" "SUCCESS"
                }
                $restoredCount++

            } catch {
                if ($hasProgress) {
                    Update-ProgressItem -ItemName $displayName -Status 'Failed' -Message $_.Exception.Message
                } else {
                    Write-Log "Failed to restore $folderName`: $_" "ERROR"
                }
                $failedCount++
            }
        } else {
            if ($hasProgress) {
                Update-ProgressItem -ItemName $displayName -Status 'Skipped' -Message "Not found"
            } else {
                Write-Log "Source folder not found: $folderName" "WARNING"
            }
        }
    }

    if ($hasProgress) {
        Complete-ProgressOperation
    }

    # Create restore log
    $restoreLog = @{
        RestoreDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        RestoredFrom = $backupPath
        OriginalBackup = $manifest
        RestoredToUser = $Username
        RestoredToComputer = $env:COMPUTERNAME
        FoldersRestored = $restoredCount
        FoldersFailed = $failedCount
        TotalFolders = $foldersToRestore.Count
    }

    $restoreLog | ConvertTo-Json -Depth 4 | Out-File "$backupPath\restore_log_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').json" -Encoding UTF8

    # Show detailed summary
    Write-Host ""
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  User Profile Restore Complete" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  User: $Username" -ForegroundColor Gray
    Write-Host "  From: $($manifest.BackupDate)" -ForegroundColor Gray
    Write-Host "  Restored: $restoredCount | Failed: $failedCount / $($foldersToRestore.Count) total" -ForegroundColor Gray
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    Write-Log "Restore completed! ($restoredCount/$($foldersToRestore.Count) folders)" "SUCCESS"
    Write-Log "Please restart applications to see restored data" "INFO"
}

function Start-BrowserBackup {
    Write-Log "BROWSER DATA BACKUP" "SECTION"

    $destination = Get-BackupDestination
    $backupPath = "$destination\$Username\BrowsersOnly"

    if (-not (Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    }

    Write-Host ""
    Write-Host "Closing browsers..." -ForegroundColor Yellow
    Get-Process | Where-Object { $_.Name -in @("chrome", "firefox", "msedge", "brave", "opera", "vivaldi") } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 2

    foreach ($folder in $BackupFolders.Browsers) {
        $sourcePath = Join-Path $UserProfile $folder
        $targetPath = Join-Path $backupPath $folder

        if (Test-Path $sourcePath) {
            try {
                $folderSize = (Get-ChildItem -Path $sourcePath -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB

                Write-Log "Backing up browser data: $folder ($([Math]::Round($folderSize, 1)) MB)" "INFO"

                $parentDir = Split-Path $targetPath -Parent
                if (-not (Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }

                Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force -ErrorAction Stop
                Write-Log "Successfully backed up: $folder" "SUCCESS"

            } catch {
                Write-Log "Failed to backup $folder`: $_" "ERROR"
            }
        }
    }

    Write-Log "Browser backup completed!" "SUCCESS"
}

function Start-OutlookBackup {
    Write-Log "OUTLOOK DATA BACKUP" "SECTION"

    $destination = Get-BackupDestination
    $backupPath = "$destination\$Username\OutlookOnly"

    if (-not (Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    }

    Write-Host ""
    Write-Host "Closing Outlook..." -ForegroundColor Yellow
    Get-Process | Where-Object { $_.Name -eq "OUTLOOK" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 3

    Backup-OutlookPSTFiles -BackupPath $backupPath

    # Backup Outlook profile folders
    $outlookFolders = @(
        "AppData\Roaming\Microsoft\Outlook",
        "AppData\Local\Microsoft\Outlook"
    )

    foreach ($folder in $outlookFolders) {
        $sourcePath = Join-Path $UserProfile $folder
        $targetPath = Join-Path $backupPath $folder

        if (Test-Path $sourcePath) {
            try {
                Write-Log "Backing up Outlook folder: $folder" "INFO"

                $parentDir = Split-Path $targetPath -Parent
                if (-not (Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }

                Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force -ErrorAction Stop
                Write-Log "Successfully backed up: $folder" "SUCCESS"

            } catch {
                Write-Log "Failed to backup $folder`: $_" "ERROR"
            }
        }
    }

    Write-Log "Outlook backup completed!" "SUCCESS"
}

function Backup-OutlookPSTFiles {
    param([string]$BackupPath)

    Write-Log "Backing up Outlook PST files..." "INFO"

    # Common PST file locations
    $pstLocations = @(
        "$AppData\Microsoft\Outlook",
        "$UserProfile\Documents\Outlook Files",
        "$UserProfile\AppData\Local\Microsoft\Outlook"
    )

    $pstBackupPath = "$BackupPath\Documents\Outlook Files"
    if (-not (Test-Path $pstBackupPath)) {
        New-Item -ItemType Directory -Path $pstBackupPath -Force | Out-Null
    }

    $pstCount = 0
    foreach ($location in $pstLocations) {
        if (Test-Path $location) {
            $pstFiles = Get-ChildItem -Path $location -Filter "*.pst" -Recurse -ErrorAction SilentlyContinue

            foreach ($pst in $pstFiles) {
                try {
                    $pstSize = [Math]::Round($pst.Length / 1MB, 1)
                    Write-Log "Backing up PST file: $($pst.Name) ($pstSize MB)" "INFO"

                    Copy-Item -Path $pst.FullName -Destination $pstBackupPath -Force -ErrorAction Stop
                    $pstCount++
                    Write-Log "Successfully backed up PST: $($pst.Name)" "SUCCESS"

                } catch {
                    Write-Log "Failed to backup PST $($pst.Name): $_" "ERROR"
                }
            }
        }
    }

    if ($pstCount -eq 0) {
        Write-Log "No PST files found to backup" "INFO"
    } else {
        Write-Log "Backed up $pstCount PST files" "SUCCESS"
    }
}

function Show-BackupStatus {
    Write-Log "BACKUP STATUS" "SECTION"

    Write-Host ""
    Write-Host "Searching all locations for backups..." -ForegroundColor Cyan

    $searchPaths = @()

    # Add default path
    $searchPaths += "C:\System_Optimizer_Backup\UserProfiles"

    # Add all drives
    $allDrives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -in @(2,3) }
    foreach ($drive in $allDrives) {
        $searchPaths += "$($drive.DeviceID)\System_Optimizer_Backup\UserProfiles"
    }

    $allBackups = @()
    $currentUserBackups = @()

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $userFolders = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue

            foreach ($userFolder in $userFolders) {
                $manifestPath = Join-Path $userFolder.FullName "backup_manifest.json"
                if (Test-Path $manifestPath) {
                    try {
                        $manifest = Get-Content $manifestPath | ConvertFrom-Json
                        $backupInfo = @{
                            Path = $userFolder.FullName
                            ParentPath = $path
                            Manifest = $manifest
                            LastModified = $userFolder.LastWriteTime
                            DriveInfo = Split-Path $path -Qualifier
                        }

                        $allBackups += $backupInfo
                        if ($manifest.Username -eq $Username) {
                            $currentUserBackups += $backupInfo
                        }
                    } catch {
                        # Skip invalid manifests
                    }
                }
            }
        }
    }

    if ($allBackups.Count -eq 0) {
        Write-Host ""
        Write-Host "No backups found on any drive" -ForegroundColor Yellow
        Write-Host "Create a backup using option 1 in the backup menu" -ForegroundColor Gray
        return
    }

    # Show current user backups first
    if ($currentUserBackups.Count -gt 0) {
        Write-Host ""
        Write-Host "Backups for current user ($Username):" -ForegroundColor Green
        Write-Host ("=" * 60) -ForegroundColor Gray

        foreach ($backup in ($currentUserBackups | Sort-Object { $_.Manifest.BackupDate } -Descending)) {
            $manifest = $backup.Manifest
            $ageInDays = [Math]::Round((Get-Date - $backup.LastModified).TotalDays, 1)

            Write-Host ""
            Write-Host "  Backup Type: $($manifest.BackupType)" -ForegroundColor Cyan
            Write-Host "  Date: $($manifest.BackupDate) ($ageInDays days ago)" -ForegroundColor Gray
            Write-Host "  Size: $($manifest.TotalSizeMB) MB" -ForegroundColor Gray
            Write-Host "  Location: $($backup.DriveInfo) ($($backup.ParentPath))" -ForegroundColor Gray

            if ($manifest.ComputerName -and $manifest.ComputerName -ne $env:COMPUTERNAME) {
                Write-Host "  Original Computer: $($manifest.ComputerName)" -ForegroundColor Yellow
            }

            if ($manifest.BackupStats) {
                Write-Host "  Duration: $($manifest.BackupStats.BackupDuration) minutes" -ForegroundColor DarkGray
                Write-Host "  Success Rate: $($manifest.BackupStats.SuccessfulBackups)/$($manifest.BackupStats.TotalFolders) folders" -ForegroundColor DarkGray
            }

            # Show folder status
            Write-Host "  Folders:" -ForegroundColor DarkCyan
            foreach ($folder in $manifest.FoldersBackedUp) {
                $folderPath = Join-Path $backup.Path $folder
                if (Test-Path $folderPath) {
                    $folderSize = try {
                        (Get-ChildItem -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue |
                         Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB
                    } catch { 0 }
                    Write-Host "    + $folder ($([Math]::Round($folderSize, 1)) MB)" -ForegroundColor Green
                } else {
                    Write-Host "    - $folder (missing)" -ForegroundColor Red
                }
            }
        }
    }

    # Show other user backups
    $otherUserBackups = $allBackups | Where-Object { $_.Manifest.Username -ne $Username }
    if ($otherUserBackups.Count -gt 0) {
        Write-Host ""
        Write-Host ""
        Write-Host "Backups for other users:" -ForegroundColor Yellow
        Write-Host ("=" * 60) -ForegroundColor Gray

        $groupedByUser = $otherUserBackups | Group-Object { $_.Manifest.Username }

        foreach ($userGroup in $groupedByUser) {
            Write-Host ""
            Write-Host "  User: $($userGroup.Name)" -ForegroundColor Cyan

            foreach ($backup in ($userGroup.Group | Sort-Object { $_.Manifest.BackupDate } -Descending)) {
                $manifest = $backup.Manifest
                $ageInDays = [Math]::Round((Get-Date - $backup.LastModified).TotalDays, 1)

                Write-Host "    • $($manifest.BackupType) - $($manifest.TotalSizeMB) MB" -ForegroundColor Gray
                Write-Host "      $($manifest.BackupDate) ($ageInDays days ago)" -ForegroundColor DarkGray
                Write-Host "      Location: $($backup.DriveInfo)" -ForegroundColor DarkGray
                if ($manifest.ComputerName) {
                    Write-Host "      Computer: $($manifest.ComputerName)" -ForegroundColor DarkGray
                }
            }
        }
    }

    # Summary statistics
    Write-Host ""
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Gray
    Write-Host "  Total backups found: $($allBackups.Count)" -ForegroundColor Gray
    Write-Host "  Your backups: $($currentUserBackups.Count)" -ForegroundColor Gray
    Write-Host "  Other users: $($otherUserBackups.Count)" -ForegroundColor Gray

    $totalSize = ($allBackups | ForEach-Object { $_.Manifest.TotalSizeMB } | Measure-Object -Sum).Sum
    Write-Host "  Total backup size: $([Math]::Round($totalSize, 1)) MB" -ForegroundColor Gray

    $driveUsage = $allBackups | Group-Object DriveInfo
    Write-Host "  Drives used:" -ForegroundColor Gray
    foreach ($drive in $driveUsage) {
        $driveSize = ($drive.Group | ForEach-Object { $_.Manifest.TotalSizeMB } | Measure-Object -Sum).Sum
        Write-Host "    $($drive.Name): $($drive.Count) backups, $([Math]::Round($driveSize, 1)) MB" -ForegroundColor DarkGray
    }
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================
Export-ModuleMember -Function @(
    'Show-UserBackupMenu',
    'Get-BackupDestination',
    'Get-ExternalDriveDestination',
    'Search-ExistingBackups',
    'Get-CustomBackupSelection',
    'Add-CustomPath',
    'Add-GameSavesPath',
    'Add-ApplicationDataPath',
    'Remove-Selection',
    'Start-UserProfileBackup',
    'Start-UserProfileRestore',
    'Start-BrowserBackup',
    'Start-OutlookBackup',
    'Backup-OutlookPSTFiles',
    'Show-BackupStatus'
)


