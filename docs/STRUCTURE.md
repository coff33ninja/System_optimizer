# Project Structure

```
System_Optimizer/
│
├── Start-SystemOptimizer.ps1    # Main entry point script
├── SystemOptimizer.exe          # Standalone EXE (recommended)
├── run_optimization.bat         # Batch launcher with options
├── README.md                    # Quick start guide
├── CHANGELOG.md                 # Release history
│
├── configs/                     # Configuration files
│   ├── VERSION.json             # Version tracking for all components
│   ├── ooshutup10.cfg           # O&O ShutUp10 recommended settings
│   ├── PatchMyPC.ini            # Pre-selected software list
│   └── winget_packages.json     # Winget package definitions
│
├── modules/                     # 27 PowerShell modules
│   └── [see Module Reference below]
│
├── scripts/                     # Build and development scripts
│   ├── build_exe.ps1            # PS2EXE builder for standalone EXE
│   ├── version_manager.ps1      # Version control tool
│   ├── dev/                     # Development/analysis scripts
│   └── legacy/                  # Legacy monolithic script
│
├── tools/                       # Bundled third-party utilities
│   └── [see Tools Reference below]
│
└── docs/                        # Documentation
    ├── FEATURES.md              # Detailed feature reference
    ├── STRUCTURE.md             # This file
    └── ROADMAP.md               # Implementation status & plans
```

---

## Module Reference

### Core Modules

| Module | Functions | Description |
|--------|-----------|-------------|
| **Core.psm1** | 7 | Progress tracking, ETA calculation, download helpers |
| **Logging.psm1** | 13 | Centralized logging, timestamps, color output |
| **Utilities.psm1** | 7 | Wi-Fi passwords, status verification, log viewer |

### Optimization Modules

| Module | Functions | Description |
|--------|-----------|-------------|
| **Telemetry.psm1** | 3 | 35+ privacy tweaks, Copilot, Recall, advertising |
| **Services.psm1** | 5 | 90+ services, Safe/Aggressive modes, Teams control |
| **Bloatware.psm1** | 15 | 40+ app removal, privacy tweaks, registry cleanup |
| **Tasks.psm1** | 2 | 19 scheduled task management |
| **Registry.psm1** | 3 | 20+ performance tweaks, SSD optimization |
| **VBS.psm1** | 2 | Memory Integrity, Credential Guard control |
| **Network.psm1** | 12 | TCP/IP, DNS, adapter optimization, Wi-Fi, proxy, diagnostics |
| **OneDrive.psm1** | 2 | Complete OneDrive removal |
| **Privacy.psm1** | 3 | Additional privacy controls |
| **UITweaks.psm1** | 10 | DISM++ style UI/UX tweaks |

### System Modules

| Module | Functions | Description |
|--------|-----------|-------------|
| **Maintenance.psm1** | 19 | DISM, SFC, cleanup, disk tools, system repair, startup manager |
| **Power.psm1** | 3 | Power plans, battery settings |
| **Security.psm1** | 5 | Defender control, security tools |
| **WindowsUpdate.psm1** | 6 | Update control, pause, repair |
| **Shutdown.psm1** | 15 | Power state controls |

### Software Modules

| Module | Functions | Description |
|--------|-----------|-------------|
| **Software.psm1** | 13 | PatchMyPC, Winget, Chocolatey, remote desktop |
| **Drivers.psm1** | 5 | SDI, DISM backup/restore |

### Advanced Modules

| Module | Functions | Description |
|--------|-----------|-------------|
| **Hardware.psm1** | 18 | CPU, GPU, RAM, Storage detection |
| **Profiles.psm1** | 12 | 6 optimization profiles, auto-suggest |
| **Rollback.psm1** | 25 | Session tracking, undo system |
| **Backup.psm1** | 15 | User profile backup/restore |

### Deployment Modules

| Module | Functions | Description |
|--------|-----------|-------------|
| **ImageTool.psm1** | 39 | ISO creation, WIM editing, custom images |
| **Installer.psm1** | 18 | Windows deployment to drives |
| **VHDDeploy.psm1** | 15 | VHD native boot deployment |

**Total: 27 modules, 223+ functions**

---

## Tools Reference

| Tool | Purpose |
|------|---------|
| **ooshutup10.exe** | O&O ShutUp10 privacy tool |
| **WUpdater.exe** | Windows Update GUI control |
| **Defender_Tools.exe** | Windows Defender management |
| **install_wim_tweak.exe** | WIM modification utility |
| **SNAPPY_DRIVER.zip** | Snappy Driver Installer |
| **WinNTSetup.zip** | Windows deployment tool |
| **WinNTSetup/** | Extracted WinNTSetup with DISM, BootICE |

---

## Runtime Directories

When System Optimizer runs, it creates these directories:

| Directory | Purpose |
|-----------|---------|
| `C:\System_Optimizer\` | Main tool storage |
| `C:\System_Optimizer\modules\` | Cached modules (persistent) |
| `C:\System_Optimizer\Logs\` | Operation logs (30-day retention) |
| `C:\System_Optimizer\ImageTool\` | Image Tool work directory |
| `C:\System_Optimizer\VHD\` | VHD deployment work |
| `C:\System_Optimizer\Installer\` | Windows Installer work |
| `C:\System_Optimizer_Backup\` | User profile backups |

---

## Version Management

Version tracking uses `configs/VERSION.json`:

```json
{
  "Version": "1.0.0",
  "LastUpdated": "2025-12-23T...",
  "Modules": {
    "Backup": "1.0.0",
    "Bloatware": "1.0.0",
    ...
  }
}
```

Use `scripts/version_manager.ps1` to manage versions:

```powershell
# View status
.\scripts\version_manager.ps1 -Action Report

# Bump versions
.\scripts\version_manager.ps1 -Action BumpAll -Type Minor

# Create release
.\scripts\version_manager.ps1 -Action Release -Version "1.1.0"
```
