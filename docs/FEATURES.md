# Features & Menu Reference

## Quick Actions

### [1] Run ALL Optimizations
Applies all core optimizations in sequence:
- Disables telemetry and data collection
- Stops unnecessary services
- Removes bloatware apps
- Disables scheduled tasks
- Applies registry tweaks
- Optimizes network settings

**Use when:** Fresh Windows install or full system cleanup.

### [16] Full Setup Workflow
Complete setup sequence for new machines:
1. PatchMyPC software installation
2. Office Tool Plus for Microsoft Office
3. Service optimization
4. MAS activation

**Use when:** Setting up a new PC from scratch.

---

## Core Optimizations

### [2] Disable Telemetry
35+ privacy tweaks including:
- Windows telemetry and diagnostics
- Advertising ID and personalization
- Activity history and timeline
- Cortana and web search
- Copilot and Recall (Windows 11)
- Feedback and error reporting
- PowerShell 7 telemetry

### [3] Disable Services
Interactive service management with two modes:

**Safe Mode (~45 services):**
- Telemetry services (DiagTrack, dmwappushservice)
- Xbox services (all gaming-related)
- Hyper-V guest services
- Rarely used features

**Aggressive Mode (~90 services):**
- All Safe Mode services plus:
- Print Spooler (if no printer)
- Windows Search
- Remote Desktop
- Camera/Notifications

Also includes:
- Teams startup control (disable without removing)
- WinUtil service sync integration
- Export current states to JSON

### [4] Remove Bloatware
Removes 40+ pre-installed apps:
- Xbox apps (Game Bar, Identity Provider, etc.)
- Microsoft apps (Solitaire, News, Weather, etc.)
- Third-party (TikTok, Candy Crush, Spotify, etc.)
- Clipchamp, Phone Link, Quick Assist

**Keeps by default:** Teams, Phone Companion (startup disabled only)

### [5] Disable Scheduled Tasks
Disables 19 telemetry/diagnostic tasks:
- Customer Experience Improvement Program
- Application Experience tasks
- Disk Diagnostic tasks
- Windows Error Reporting
- Cloud Experience Host
- Feedback notifications

### [6] Registry Optimizations
20+ performance tweaks:
- Menu show delay (400ms → 0ms)
- Disable Game Bar and DVR
- Disable animations and transparency
- Startup delay removal
- Mouse acceleration disable
- Thumbnail cache optimization
- NTFS last access timestamp disable
- 8.3 filename creation disable
- Fullscreen optimizations disable
- Hardware GPU scheduling enable
- Memory management (LargeSystemCache)
- Prefetch/Superfetch on SSD
- Icon cache size increase

### [7] Disable VBS/Memory Integrity
Disables virtualization-based security:
- Core Isolation / Memory Integrity
- Credential Guard
- HVCI (Hypervisor-protected Code Integrity)

**Warning:** Improves gaming performance but reduces security.

### [8] Network Optimizations
TCP/IP and adapter tweaks:
- Disable IPv6 (optional)
- Disable Nagle's algorithm
- Disable network throttling
- DNS optimization
- TCP auto-tuning

### [9] Remove OneDrive
Complete OneDrive removal:
- Uninstall OneDrive application
- Remove from Explorer sidebar
- Disable via Group Policy
- Clean up registry entries

### [10] System Maintenance
System health and cleanup:
- DISM RestoreHealth
- SFC /scannow
- Temporary file cleanup
- Windows Update cache clear
- Component store cleanup

---

## Software & Tools

### [11] Software Installation
Multiple package managers:

**PatchMyPC:**
- Pre-configured selection (see configs/PatchMyPC.ini)
- Or launch for self-selection

**Winget Presets:**
- Essential (browsers, 7-Zip, VLC, etc.)
- Runtimes (VC++, .NET, Java)
- Developer (VS Code, Git, Python)
- Gaming (Steam, Discord, etc.)
- Security (Malwarebytes, etc.)

**Security Tools Submenu:**
| Category | Tools |
|----------|-------|
| Antivirus | ESET NOD32, Windows Defender config |
| Anti-Malware | Malwarebytes, AdwCleaner |
| Network | Wireshark, Nmap |
| Privacy | BleachBit, Eraser |

**Chocolatey:**
- Install Chocolatey package manager
- Essential apps bundle

**Remote Desktop:**
- RustDesk installation + shortcuts
- AnyDesk installation + shortcuts

### [12] Office Tool Plus
Microsoft Office deployment tool:
- Auto-detects latest version from GitHub
- Fallback to known working version
- Web installer option

### [13] MAS Activation
Microsoft Activation Script:
- Windows activation
- Office activation
- Digital license method

### [14] Wi-Fi Passwords
Extracts all saved Wi-Fi passwords:
- Lists all known networks
- Shows passwords in plain text
- Export option

### [15] Verify Status
Checks current optimization status:
- Telemetry settings
- Service states
- Registry values
- Applied tweaks

---

## Power & System

### [17] Power Plan
Power configuration:

| Setting | AC Power | Battery |
|---------|----------|---------|
| Screen off | Never | 30 min |
| Sleep | Never | 1 hour |
| Hibernate | Never | 2 hours |

Options:
- High Performance plan
- Ultimate Performance plan (unhides it)
- Balanced with custom settings

### [18] O&O ShutUp10
Privacy tool with recommended config:
- Downloads O&O ShutUp10
- Applies configs/ooshutup10.cfg
- 100+ privacy settings

### [19] Reset Group Policy
Resets GPO to defaults:
- Deletes registry policy keys
- Removes GroupPolicy folders
- Runs gpupdate /force

### [20] Reset WMI
Windows Management Instrumentation repair:

**Quick Salvage:**
- Verifies WMI repository
- Attempts repair

**Full Reset:**
- Stops WMI service
- Rebuilds repository
- Re-registers DLLs

### [21] Disk Cleanup
Three cleanup modes:
- **Quick:** Temp files, thumbnails
- **Full:** + Windows Update, logs
- **GUI:** Opens cleanmgr with all options

### [22] Windows Update Control
8 options for update management:
- Pause updates (registry method)
- Pause updates (scheduled task)
- Disable Windows Update service
- Enable Windows Update service
- Launch WUpdater GUI
- Configure driver updates
- Check for updates
- View update history

### [23] Driver Management
Driver tools:
- Windows Update drivers
- Snappy Driver Installer (SDI) Lite
- SDI with auto-update
- Backup drivers via DISM
- Restore drivers from backup

### [24] Network Reset
Complete network stack reset:
- WinSock reset
- WinHTTP reset
- IP configuration reset
- DNS cache flush
- Firewall reset (optional)

### [25] Windows Update Repair
Repairs broken Windows Update:
- Stops update services
- Clears update cache
- Re-registers 36 DLLs
- Restarts services

### [26] Windows Defender Control
Defender management:
- Disable real-time protection
- Enable real-time protection
- Add exclusions
- Remove Defender (advanced)
- Configure cloud protection

### [27] Advanced Debloat Scripts
Additional debloating:
- Hosts file blocking (150+ telemetry domains)
- Firewall rules for telemetry
- Additional registry tweaks

### [28] WinUtil Service Sync
Syncs with Chris Titus Tech's WinUtil:
- Downloads latest tweaks.json
- Applies ~150 service configurations
- Safe mode (Manual) or Aggressive (Disabled)
- Preview before applying
- Export current states

### [29] DISM++ Style Tweaks
9 categories of UI tweaks:

1. **Taskbar & Start Menu**
   - Show seconds on clock
   - Disable transparency
   - Left-align taskbar (Win11)

2. **Explorer**
   - Open to This PC
   - Show file extensions
   - Show hidden files
   - Show full path in title

3. **Desktop Icons**
   - This PC
   - Recycle Bin
   - Control Panel
   - User folder

4. **Context Menu**
   - Classic context menu (Win11)
   - Add "End Task" option
   - Remove Defender scan

5. **Security**
   - SmartScreen settings
   - File download warnings

6. **Windows Experience**
   - Disable suggestions
   - Disable Spotlight
   - Disable auto-install apps

7. **Windows Photo Viewer**
   - Re-enable classic viewer

8. **Notepad & Media**
   - Word wrap default
   - WMP first-run wizard

9. **IE Mode**
   - Compatibility settings
   - Autocomplete options

---

## Advanced Tools

### [30] Windows Image Tool
Complete Windows image management:

- **Quick Create** - Wizard for custom ISO
- **Mount/Edit Images** - Mount ISO/WIM
- **Apply Tweaks** - TPM bypass, telemetry, dark theme
- **Inject Drivers** - From current system or folder
- **Remove Bloatware** - From offline image
- **Unattend File** - Answer file with System Optimizer auto-run
- **Create Bootable USB** - Format and copy
- **WIM Optimization** - Cleanup, export, ESD→WIM

### [31] View Logs
Log management:
- View current session log
- Browse recent logs
- Error/warning counts
- Export summary
- Clear old logs (30+ days)

Location: `C:\System_Optimizer\Logs\`

### [32] User Profile Backup
Comprehensive backup system:

**Backup Types:**
- Essential (Desktop, Documents, Downloads)
- Browsers (Firefox, Chrome, Edge, Brave, Opera, Vivaldi)
- Applications (Outlook, Thunderbird, Discord, Spotify)
- Full profile
- Custom selection

**Features:**
- External drive detection
- Cross-computer restore
- JSON manifests
- PST file handling
- Progress tracking
- Integrity verification

### [33] Shutdown Options
Power state controls:
- Restart
- Shutdown
- Sleep
- Hibernate
- Sign out
- Lock

### [34] VHD Native Boot
VHD deployment for dual/multi-boot:
- Quick Deploy wizard
- Create empty VHD (GPT/MBR)
- Mount/dismount VHD
- Deploy Windows to VHD
- Inject drivers
- Enable features (Hyper-V, WSL)
- Add to boot menu

### [35] Windows Installer
Deploy Windows to blank drives:
- Disk preparation (diskpart scripts)
- Single disk / Dual disk layouts
- GPT/UEFI or MBR/Legacy
- Windows deployment from ISO/WIM
- Edition selection
- Quick Install wizard
- Auto-creates System Optimizer shortcut

### [36] Undo/Rollback Center
Complete rollback system:
- Session management
- Registry change tracking
- Service state snapshots
- Auto-generated reverse scripts
- System restore point integration
- Interactive rollback menu

### [37] Hardware Detection
System analysis:

**CPU:**
- Intel 1st-14th gen, Core Ultra
- AMD Ryzen, FX, Phenom
- P-core/E-core detection

**GPU:**
- NVIDIA GTX 200-900, 10/16/20-50 series
- AMD HD 5000-7000, R7/R9, RX, Vega
- Intel Arc, UHD, Iris

**Storage:**
- SSD/HDD/NVMe detection
- TRIM status
- Free space per volume

**Memory:**
- DDR type detection
- XMP status
- Per-stick details

### [38] Optimization Profiles
Hardware-based profiles:

| Profile | Description |
|---------|-------------|
| Gaming | Max performance, minimal services |
| Developer | WSL, Hyper-V, dev tools friendly |
| Office | Balanced, productivity focused |
| Content Creator | Media tools, performance |
| Laptop | Battery optimization |
| LowSpec | Minimal resource usage |

Features:
- Auto-suggest based on hardware
- WhatIf preview mode
- Profile comparison
- Rollback integration
