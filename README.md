# System Optimizer 🛠️

A comprehensive Windows 10/11 optimization toolkit - 27 modules, 38 menu options, one EXE.

> Replaces [AIO](https://github.com/coff33ninja/AIO) (archived) and [NexTool](https://github.com/coff33ninja/NexTool-Windows-Suite) (discontinued).

## Quick Start

### Standalone EXE (Recommended)

1. Download [SystemOptimizer.exe](https://github.com/coff33ninja/System_optimizer/releases/latest)
2. Run as Administrator
3. Select optimizations from menu

```powershell
# Or via PowerShell
irm "https://github.com/coff33ninja/System_optimizer/releases/latest/download/SystemOptimizer.exe" -OutFile "SystemOptimizer.exe"
```

### Script Version

```powershell
git clone https://github.com/coff33ninja/System_optimizer.git
cd System_optimizer
.\Start-SystemOptimizer.ps1
```

## Requirements

- Windows 10/11
- Administrator privileges
- That's it! (EXE has no dependencies)

## Features

| Category | Highlights |
|----------|------------|
| **Privacy** | 35+ telemetry tweaks, Copilot/Recall disable |
| **Services** | 90+ services, Safe/Aggressive modes |
| **Bloatware** | 40+ app removal |
| **Performance** | Registry tweaks, VBS control, network optimization |
| **Tools** | PatchMyPC, Winget, Office Tool, MAS activation |
| **Advanced** | Hardware detection, profiles, rollback system |
| **Deployment** | Windows Image Tool, VHD boot, installer |

See [docs/FEATURES.md](docs/FEATURES.md) for detailed menu reference.

## Menu Overview

```
Quick Actions:     [1] Run ALL  [16] Full Setup
Core:              [2-10] Telemetry, Services, Bloatware, Tasks, Registry, VBS, Network, OneDrive, Maintenance
Software:          [11-13] Software Install, Office Tool, MAS
Utilities:         [14-15] Wi-Fi Passwords, Verify Status
Power & System:    [17-26] Power Plan, ShutUp10, GPO Reset, WMI, Cleanup, Updates, Drivers, Network Reset, Defender
Advanced:          [27-30] Debloat Scripts, WinUtil Sync, UI Tweaks, Image Tool
Tools:             [31-35] Logs, Backup, Shutdown, VHD Boot, Installer
Management:        [36-38] Rollback, Hardware, Profiles
```

## Documentation

- [FEATURES.md](docs/FEATURES.md) - Detailed feature & menu reference
- [STRUCTURE.md](docs/STRUCTURE.md) - Project structure & modules
- [ROADMAP.md](docs/ROADMAP.md) - Implementation status & future plans
- [CHANGELOG.md](CHANGELOG.md) - Release history

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

**Made with ☕ by [coff33ninja](https://github.com/coff33ninja)**
