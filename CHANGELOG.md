# Changelog

All notable changes to System Optimizer will be documented in this file.

## [2.0.3] - 2026-03-01

### Changes
- Updated version to test self updating.
- feat(update): add EXE in-place updater and startup module cache sync

## [2.0.2] - 2026-03-01

### Changes
- fix(warning): accept consent with trailing punctuation
- fix(warning): accept consent input case-insensitively and harden prompt flow
- ci(legacy): restore historical workflow filenames for code scanning references
- ci(security): add dependency review workflow
- ci(security): set explicit permissions for code-analysis workflow
- ci(security): upgrade CodeQL action to v4
- ci(security): add CodeQL workflow for GitHub Actions
- fix(ci): pass explicit tag name to release action
- fix(ci): support manual tag release dispatch
- fix(ci): trigger release workflow after auto-tag

## [2.0.1] - 2026-03-01

### Security & Reliability Hardening

- Hardened high-risk download/execute flows across installer and deployment paths:
  - Replaced direct raw config/script pulls in `Privacy.psm1` with trusted helper (`Get-TrustedConfigFile`) pinned to release tag.
  - Pinned `Help.psm1` `FEATURES.md` fallback to tagged source and added strict HTTPS/host validation.
  - Replaced ImageTool remote launcher scripts with local module dispatch (`Start-InstallerMenu`, `Start-VHDMenu`) to remove script-download execution.
- Added explicit destructive-operation confirmations and stronger input validation:
  - Installer: disk operations now require typed confirmation phrases.
  - VHD deploy: overwrite and BCD entry actions now require explicit confirmation.
  - ImageTool bootable USB flow now validates disk input and enforces USB-only targeting.
- Strengthened trusted artifact handling:
  - Installer `WinNTSetup.zip` now uses pinned release + SHA256 validation.
  - Driver/Security/WindowsUpdate external binaries continue under hash-verified trusted retrieval.
- Reduced hidden failures:
  - Switched module-wide `ErrorActionPreference` from `SilentlyContinue` to `Continue` in Installer, ImageTool, and VHDDeploy.

### Version Alignment

- Updated runtime version to `2.0.1` in `Start-SystemOptimizer.ps1`.
- Aligned help and backup metadata version strings to `2.0.1`.

### Version Source Of Truth Automation

- Established `version.psd1` as the single canonical version source with one key:
  - `Version = '2.0.1'`
- Updated runtime/version helpers to derive release tags from `Version` (`vX.Y.Z`) instead of storing a separate tag field.
- Removed remaining hardcoded release tag/version fallbacks in runtime pull paths and helper logic.
- Added dedicated module-header stamping script:
  - `scripts/stamp-version.ps1`
  - Stamps `Version:` headers in all module files from the canonical version.
- Hardened release pipeline version validation (`.github/workflows/release.yml`):
  - Parses version from pushed tag (`vX.Y.Z`).
  - Runs version sync + header stamp scripts.
  - Loads `version.psd1` and fails if loaded version does not equal tag version.
  - Verifies `CHANGELOG.md` contains `## [X.Y.Z]`.
  - Fails workflow on any version drift/mismatch.

### Analyzer Remediation Pass

- Resolved module analyzer warnings under repository analyzer settings (`Found 42 issues` -> `Found 0 issues`).
- Replaced WMI usage with CIM in active modules:
  - `Backup.psm1`, `Maintenance.psm1`, `Services.psm1`
- Reworked logging wrappers to avoid overriding built-in cmdlets:
  - `Backup.psm1`: introduced `Write-BackupLog` wrapper and updated call sites.
  - `Utilities.psm1`: renamed local logger to `Write-UtilitiesLog`.
- Cleaned empty catch blocks and unused parameter/variable warnings across touched modules.
- Updated UI Tweaks function names to approved verbs and restored IE path variable usage in context:
  - kept and used `$IESetup` and `$IEFeedback` in `Set-IEModeTweaks`.
- Normalized BOM encoding for previously flagged module files.

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
