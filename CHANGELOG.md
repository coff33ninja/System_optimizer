# Changelog

All notable changes to System Optimizer will be documented in this file.

## [1.0.0] - 2025-12-23

### Initial Release 🎉

System Optimizer is a comprehensive Windows 10/11 optimization toolkit that consolidates features from AIO, NexTool, and WinUtil into a modular PowerShell solution.

> **Note:** This project replaces both [AIO](https://github.com/coff33ninja/AIO) (archived) and [NexTool Windows Suite](https://github.com/coff33ninja/NexTool-Windows-Suite) (discontinued).

### Architecture
- **27 PowerShell modules** with 196+ functions
- **Standalone EXE** with all modules embedded (100% loading success)
- **Modular design** for easy maintenance and extensibility
- **Version management system** for tracking all components

### Core Features (38 Menu Options)

#### Core Optimizations
- **Telemetry & Privacy** - 35+ tweaks including Copilot, Recall, advertising ID, Cortana
- **Services** - Disable 90+ unnecessary services (Safe/Aggressive modes)
- **Bloatware Removal** - Remove 40+ apps (Xbox, TikTok, Candy Crush, etc.)
- **Scheduled Tasks** - Disable 19 telemetry/diagnostic tasks
- **Registry Tweaks** - 20+ performance optimizations
- **VBS/Memory Integrity** - Disable core isolation, credential guard
- **Network** - IPv6, Nagle's algorithm, network throttling
- **OneDrive** - Complete removal with policy disable

#### Software & Tools
- **Software Installation** - PatchMyPC, Winget presets, Chocolatey, RustDesk/AnyDesk
- **Office Tool Plus** - Auto-detect latest version from GitHub
- **MAS Activation** - Microsoft Activation Script integration
- **O&O ShutUp10** - Privacy tool with recommended config
- **Snappy Driver Installer** - Driver management with backup/restore

#### Advanced Features
- **Progress Tracking System** - Real-time progress with ETA for all operations
- **Hardware Detection** - CPU, GPU, RAM, Storage analysis with health status
- **Optimization Profiles** - Gaming, Developer, Office, Content Creator, Laptop, LowSpec
- **Rollback System** - Complete undo functionality with session management
- **User Profile Backup** - Full backup/restore with external drive support
- **Windows Image Tool** - Create custom ISOs, VHD deployment, bootable USB
- **Centralized Logging** - All operations logged to C:\System_Optimizer\Logs\

#### System Management
- **Power Plan** - High/Ultimate Performance with optimized battery settings
- **Windows Update Control** - Pause, disable, repair
- **Windows Defender Control** - Disable/enable, exceptions
- **Network Reset** - WinSock, DNS, IP configuration reset
- **Group Policy Reset** - Registry cleanup + folder removal
- **WMI Reset** - Quick salvage or full reset
- **Disk Cleanup** - Quick/full/GUI options

### Installation
- **Standalone EXE**: Just download and run as Administrator
- **Script Version**: Clone repo and run `Start-SystemOptimizer.ps1`
- Tools directory: `C:\System_Optimizer\`
- Backup directory: `C:\System_Optimizer_Backup\`
- Logs: `C:\System_Optimizer\Logs\`

### Credits
- [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)
- [O&O ShutUp10](https://www.oo-software.com/en/shutup10)
- [Snappy Driver Installer](https://sdi-tool.org/)
- [massgravel/MAS](https://github.com/massgravel/Microsoft-Activation-Scripts)
- [YerongAI/Office-Tool](https://github.com/YerongAI/Office-Tool)
