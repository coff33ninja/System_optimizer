# Changelog

All notable changes to System Optimizer will be documented in this file.

## [2.0.0] - 2026-02-21

### Major Release - Code Quality & Architecture Overhaul

This release represents a significant milestone in code quality, documentation, and architecture improvements.

### PowerShell Standards Compliance
- **PSScriptAnalyzer Compliance** - Full audit and fix of all analyzer warnings
  - Fixed 8 unapproved verb usages across Services, Utilities, and Shutdown modules
  - Fixed automatic variable conflict (`$profile` → `$wifiProfile`)
  - Added `[CmdletBinding(SupportsShouldProcess)]` to state-changing functions
  - All functions now use Microsoft-approved PowerShell verbs

### Security Enhancements
- **Invoke-Expression Hardening** - Added comprehensive safeguards:
  - User confirmation prompts before executing external scripts
  - Download validation (empty script detection)
  - Timeout protection for network requests
  - User-Agent headers for traceability
  - Affected functions: `Install-Chocolatey`, `Start-MAS`, Office Tool web installer

### Menu Architecture Redesign
- **Hierarchical Menu System** - Implemented sub-menu pattern for better organization:
  - **Maintenance Tools** sub-menu consolidates 5 items: System Maintenance, Disk Cleanup, Reset Group Policy, Reset WMI, Repair Windows Updates
  - **Network Tools** sub-menu consolidates 2 items: Network Optimizations, Reset Network
  - Main menu reduced from 38 to 34 items for cleaner UI
  - Sequential renumbering of all menu items (fixed gaps: 31-38 → 27-34)
  - Two-column layout maintained for compact display

### Help System Modularization
- **Centralized Help Module** - Moved help content to Help.psm1
  - Created `Show-ComprehensiveHelp` function for command-line help
  - Reduced main script size by ~200 lines
  - Consistent help between interactive (`?`) and CLI (`-Help`)
  - Dynamic module loading with fallback handling

### Documentation Transformation
- **Module Documentation** - Added comprehensive comment-based help to all 27 modules:
  - Standardized SYNOPSIS, DESCRIPTION, and Exported Functions sections
  - Menu structure documentation for modules with sub-menus
  - Requirements and compatibility notes
  - Version tracking (1.0.0)
- **Repository Wiki** - Created extensive `.qoder/repowiki/` documentation:
  - Core Architecture documentation
  - Module Reference (40+ pages)
  - User Interface Guide
  - Troubleshooting and FAQ
  - Advanced Topics and Configuration Management
- **Repository Skills** - Created 6 Qoder skills for development standards:
  - `powershell-approved-verbs` - Verb compliance guidelines
  - `menu-architecture` - Menu system patterns
  - `module-documentation` - Documentation standards
  - `function-module-map` - Auto-reload maintenance
  - `powershell-analyzer-fixes` - Common issue resolution
  - `changelog-maintenance` - Changelog update guidelines
- **TODO.md** - Created comprehensive refactoring roadmap
  - High priority: Module refactoring tasks
  - Medium priority: Code quality improvements
  - Testing checklists and guidelines

### FunctionModuleMap Expansion
- **Auto-Reload Support** - Expanded map to include all 80+ exported functions:
  - Organized by category (Core, Telemetry, Services, Network, etc.)
  - Enables dynamic module reloading when functions are missing
  - Supports GitHub download fallback for missing modules

### Enhanced Features
- **Network Module** - Expanded from 4 to 12 functions:
  - Wi-Fi password extraction
  - Proxy configuration
  - Network diagnostics
  - Firewall status
  - Network speed testing
- **Maintenance Module** - Expanded from 4 to 19 functions:
  - Disk health monitoring
  - System repair utilities
  - Startup program manager
  - Drive optimization
  - Search index rebuild

### Launcher Improvements
- **Batch Script Cleanup** - Updated `run_optimization.bat`:
  - Removed legacy project name references
  - Modernized exit messages
  - Updated header comments

### Files Modified
- **All 27 modules** - Documentation headers added
- **Start-SystemOptimizer.ps1** - Menu restructure, FunctionModuleMap expansion, help system integration
- **modules/Help.psm1** - Added `Show-ComprehensiveHelp` function
- **run_optimization.bat** - Removed legacy references
- **Documentation** - FEATURES.md, ROADMAP.md, STRUCTURE.md updated
- **New Skills** - 6 skill files in `.qoder/skills/`
- **TODO.md** - New refactoring roadmap

### Statistics
- 27 modules with standardized documentation
- 80+ functions in FunctionModuleMap
- 40+ wiki documentation pages
- 6 development skills created
- 8 unapproved verbs fixed
- 4 Invoke-Expression calls hardened
- 25+ commits since v1.0.0
- Menu items: 38 → 34 (optimized)
- Function count: 196+ → 223+

## [1.0.0] - 2025-12-23

### Major Release - Code Quality & Architecture Overhaul

This release represents a significant milestone in code quality, documentation, and architecture improvements.

### PowerShell Standards Compliance
- **PSScriptAnalyzer Compliance** - Full audit and fix of all analyzer warnings
  - Fixed 8 unapproved verb usages across Services, Utilities, and Shutdown modules
  - Fixed automatic variable conflict (`$profile` → `$wifiProfile`)
  - Added `[CmdletBinding(SupportsShouldProcess)]` to state-changing functions
  - All functions now use Microsoft-approved PowerShell verbs

### Security Enhancements
- **Invoke-Expression Hardening** - Added comprehensive safeguards:
  - User confirmation prompts before executing external scripts
  - Download validation (empty script detection)
  - Timeout protection for network requests
  - User-Agent headers for traceability
  - Affected functions: `Install-Chocolatey`, `Start-MAS`, Office Tool web installer

### Menu Architecture Redesign
- **Hierarchical Menu System** - Implemented sub-menu pattern for better organization:
  - **Maintenance Tools** sub-menu consolidates 5 items: System Maintenance, Disk Cleanup, Reset Group Policy, Reset WMI, Repair Windows Updates
  - **Network Tools** sub-menu consolidates 2 items: Network Optimizations, Reset Network
  - Main menu reduced from 38 to 34 items for cleaner UI
  - Sequential renumbering of all menu items
  - Two-column layout maintained for compact display

### Documentation Transformation
- **Module Documentation** - Added comprehensive comment-based help to all 27 modules:
  - Standardized SYNOPSIS, DESCRIPTION, and Exported Functions sections
  - Menu structure documentation for modules with sub-menus
  - Requirements and compatibility notes
  - Version tracking (1.0.0)
- **Repository Wiki** - Created extensive `.qoder/repowiki/` documentation:
  - Core Architecture documentation
  - Module Reference (40+ pages)
  - User Interface Guide
  - Troubleshooting and FAQ
  - Advanced Topics and Configuration Management
- **Repository Skills** - Created 5 Qoder skills for development standards:
  - `powershell-approved-verbs` - Verb compliance guidelines
  - `menu-architecture` - Menu system patterns
  - `module-documentation` - Documentation standards
  - `function-module-map` - Auto-reload maintenance
  - `powershell-analyzer-fixes` - Common issue resolution

### FunctionModuleMap Expansion
- **Auto-Reload Support** - Expanded map to include all 80+ exported functions:
  - Organized by category (Core, Telemetry, Services, Network, etc.)
  - Enables dynamic module reloading when functions are missing
  - Supports GitHub download fallback for missing modules

### Files Modified
- **All 27 modules** - Documentation headers added
- **Start-SystemOptimizer.ps1** - Menu restructure, FunctionModuleMap expansion
- **Documentation** - FEATURES.md, ROADMAP.md, STRUCTURE.md updated
- **New Skills** - 5 skill files in `.qoder/skills/`

### Statistics
- 27 modules with standardized documentation
- 80+ functions in FunctionModuleMap
- 40+ wiki documentation pages
- 5 development skills created
- 8 unapproved verbs fixed
- 4 Invoke-Expression calls hardened

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
