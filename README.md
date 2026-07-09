# System Optimizer

A comprehensive Windows 10/11 optimization toolkit - 30 modules, 35 menu options.

> Replaces [AIO](https://github.com/coff33ninja/AIO) (archived) and [NexTool](https://github.com/coff33ninja/NexTool-Windows-Suite) (discontinued).

## Project History

| Phase | Project | Stack |
|-------|---------|-------|
| 1st Gen | AIO | Batch scripts |
| 2nd Gen | NexTool | Python GUI |
| 3rd Gen | System Optimizer | PowerShell + Go (hybrid) |

## Quick Start

```powershell
irm "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/run_optimization.bat" -OutFile "run_optimization.bat"
.\run_optimization.bat
```

Requires Windows 10/11, Administrator privileges, and PowerShell 5.1+.

## Requirements

- Windows 10/11
- Administrator privileges
- PowerShell 5.1 or newer (7 recommended if available)

## Features

| Category | Highlights |
|----------|------------|
| **Privacy** | 35+ telemetry tweaks, Copilot/Recall disable |
| **Services** | 90+ services, Safe/Aggressive modes |
| **Bloatware** | 40+ app removal |
| **Performance** | Registry tweaks, VBS control, network optimization |
| **Antivirus** | ESET CDN install (6 products), Defender control, AV scan |
| **Tools** | PatchMyPC, Winget, Office Tool, MAS activation |
| **Advanced** | Hardware detection, profiles, rollback system |
| **Deployment** | Windows Image Tool, VHD boot, installer |

See [docs/FEATURES.md](docs/FEATURES.md) for detailed menu reference.

## Menu Overview

```
Quick Actions:     [1] Run ALL  [16] Full Setup
Core:              [2-10] Telemetry, Services, Bloatware, Tasks, Registry, VBS, Network Tools, OneDrive, Maintenance Tools
Software:          [11-13] Software Install, Office Tool, MAS
Utilities:         [14-15] Wi-Fi Passwords, Verify Status
Power & System:    [17-22] Power Plan, ShutUp10, Updates, Drivers, Repair Updates, Defender
Advanced:          [23-26] Debloat Scripts, WinUtil Sync, UI Tweaks, Image Tool
Tools:             [27-31] Logs, Backup, Shutdown, VHD Boot, Installer
Management:        [32-35] Rollback, Hardware, Profiles, Antivirus
Safety:            [W] View First-Run Warning Again
```

## Documentation

- [FEATURES.md](docs/FEATURES.md) - Detailed feature & menu reference
- [STRUCTURE.md](docs/STRUCTURE.md) - Project structure & modules
- [ROADMAP.md](docs/ROADMAP.md) - Implementation status & future plans
- [CHANGELOG.md](CHANGELOG.md) - Release history
- [MIGRATION_SPEC.md](docs/MIGRATION_SPEC.md) - Go hybrid architecture spec

## What's Next

Migrating from PowerShell + ps2exe to a Go TUI + PowerShell hybrid. The Go binary handles the menu, progress display, module management, and secure downloads. PowerShell modules stay as `.psm1` files — they own the Windows system administration work. See [MIGRATION_SPEC.md](docs/MIGRATION_SPEC.md) for full architecture.

## Credits

Built upon:
- [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)
- [O&O ShutUp10](https://www.oo-software.com/en/shutup10)
- [Snappy Driver Installer](https://sdi-tool.org/)
- [massgravel/MAS](https://github.com/massgravel/Microsoft-Activation-Scripts)
- [YerongAI/Office-Tool](https://github.com/YerongAI/Office-Tool)

## Disclaimer

Use at your own risk. Some optimizations may reduce system security. Create a backup first.

## License

Provided as-is for educational and personal use.

---

**Made with [coff33ninja](https://github.com/coff33ninja)**
