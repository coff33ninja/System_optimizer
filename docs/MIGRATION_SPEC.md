# Migration Spec: Go TUI + PowerShell Hybrid

> Version: 1.0.0-draft
> Date: July 9, 2026
> Status: Planning
> Replaces: ps2exe-compiled SystemOptimizer.exe

---

## 1. Architecture Overview

### Current State
PowerShell scripts compiled into a single EXE via ps2exe. Causes AV false positives, no code signing, BOM/encoding issues on PS5.1, fragile module embedding, and the self-updater generates inline scripts at runtime.

### Target State
A Go binary provides the TUI (Bubble Tea) and acts as an orchestrator. PowerShell modules (`.ps1`/`.psm1`) are embedded in the Go binary, extracted on first run, and individually updated from GitHub when selected.

```
┌─────────────────────────────────────────────────┐
│                Go Binary (TUI)                  │
│  ┌───────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Bubble Tea│  │  Cobra   │  │  Embedded    │  │
│  │   Menu    │  │  Args    │  │  .psm1 files │  │
│  │  System   │  │  Parser  │  │  (fallback)  │  │
│  └─────┬─────┘  └────┬─────┘  └──────┬───────┘  │
│        │              │               │          │
│        └──────────────┼───────────────┘          │
│                       │                          │
│              ┌────────▼────────┐                 │
│              │  Module Manager │                 │
│              │  - version.json │                 │
│              │  - cache dir    │                 │
│              │  - git updater  │                 │
│              └────────┬────────┘                 │
│                       │                          │
│              ┌────────▼────────┐                 │
│              │  PS Executor    │                 │
│              │  powershell.exe │                 │
│              │  -NoProfile     │                 │
│              │  -ExecutionPolicy Bypass          │
│              └─────────────────┘                 │
└─────────────────────────────────────────────────┘
```

### Why Hybrid
- All Windows-specific optimizations ARE PowerShell commands (`Set-MpPreference`, `Get-AppxPackage`, `powercfg`, registry manipulation via `Set-ItemProperty`).
- Porting these to Go would mean reimplementing the entire Windows API surface the scripts use. Not worth it.
- Go handles what it's good at: TUI rendering, file I/O, HTTP downloads, process management, version comparison.
- PowerShell handles what IT'S good at: Windows system administration.

---

## 2. Go Project Structure

```
system-optimizer/
├── main.go                         # Entry point, arg parsing, version info
├── go.mod
├── go.sum
│
├── cmd/                            # Cobra command definitions
│   ├── root.go                     # Root command, global flags
│   └── version.go                  # `system-optimizer version` command
│
├── internal/
│   ├── tui/                        # Bubble Tea TUI models
│   │   ├── app.go                  # Root model, menu routing
│   │   ├── menu.go                 # Main menu view
│   │   ├── submenu.go              # Generic submenu view
│   │   ├── progress.go             # Execution progress view
│   │   ├── confirm.go              # Confirmation dialogs
│   │   ├── status.go               # System status display
│   │   └── styles.go               # Lip Gloss style definitions
│   │
│   ├── modules/                    # Module management
│   │   ├── manager.go              # Download, cache, version check
│   │   ├── registry.go             # Module metadata (name, version, deps)
│   │   ├── updater.go              # GitHub API, per-module update check
│   │   └── executor.go             # Execute .psm1 functions via powershell.exe
│   │
│   ├── system/                     # System detection
│   │   ├── arch.go                 # Processor architecture detection
│   │   ├── os.go                   # Windows version, build number
│   │   ├── hardware.go             # RAM, CPU, GPU, disk info
│   │   └── installed.go            # Installed software/AV detection
│   │
│   ├── config/                     # Application configuration
│   │   ├── config.go               # Load/save config
│   │   └── paths.go                # Data dirs, cache paths, log paths
│   │
│   └── download/                   # Secure download utilities
│       ├── client.go               # HTTPS-only, host allowlist
│       ├── hash.go                 # SHA256 verification
│       └── progress.go             # Download progress reporting
│
├── embed/                          # Embedded fallback PS1 files
│   └── modules/                    # Backup copies shipped with binary
│       ├── Antivirus.psm1
│       ├── Backup.psm1
│       ├── ... (all 30 modules)
│       └── modules.json            # Embedded version manifest
│
├── scripts/                        # Build and dev scripts
│   ├── build.ps1                   # Cross-compile for Windows (amd64, arm64)
│   ├── embed-modules.ps1           # Copy .psm1 files into embed/modules/
│   └── generate-version.ps1        # Generate version.go from git tag
│
├── .github/workflows/
│   ├── ci.yml                      # Lint, test, build on push/PR
│   ├── release.yml                 # Build + GitHub Release on tag push
│   └── module-check.yml            # Validate PS1 module versions on push
│
└── docs/
    ├── MIGRATION_SPEC.md           # This document
    ├── BRANCH_ANALYSIS.md          # Historical branch findings
    ├── ESET_Installer_Links_and_Version_History.md
    ├── FEATURES.md
    ├── ROADMAP.md
    └── STRUCTURE.md
```

---

## 3. PowerShell Module Structure

Modules stay as `.psm1` files in the repo root `modules/` directory. They are the source of truth. The Go binary embeds fallback copies, but the runtime copies live in the local cache.

### Module File Format (Standardized)

Every module MUST follow this format:

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Module Name - System Optimizer
.DESCRIPTION
    What this module does.
#Version: X.Y.Z
Exported Functions:
    Function-Name    - Description
Requires Admin: Yes/No
#>

# ============================================================================
# PUBLIC FUNCTIONS
# ============================================================================

function Verb-Noun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ParamName
    )
    # ... implementation
}

# ============================================================================
# MODULE METADATA (for Go module manager)
# ============================================================================

$script:ModuleMeta = @{
    Name        = 'ModuleName'
    Version     = 'X.Y.Z'
    MinVersion  = 'X.Y.Z'       # Minimum Go binary version required
    RequiresAdmin = $true
    Dependencies  = @('OtherModule')  # Other modules this needs loaded first
    Description = 'One-line description'
}

Export-ModuleMember -Function @(
    'Function-Name'
)
```

The `$script:ModuleMeta` block is new. The Go module manager reads this to determine version, dependencies, and admin requirements without parsing the full file.

### Module Header Convention

| Element | Convention | Example |
|---------|-----------|---------|
| Requires | First line | `#Requires -Version 5.1` |
| Synopsis | `<# .SYNOPSIS` block | Module name + System Optimizer |
| Version | `#Version: X.Y.Z` in header | `#Version: 2.0.0` |
| Meta | `$script:ModuleMeta` hashtable | See above |
| Exports | `Export-ModuleMember` at end | Function list |

---

## 4. Versioning System

### Separate Versioning Model

| Component | Version Source | Update Frequency |
|-----------|---------------|-----------------|
| Go binary | `internal/version/version.go` (compiled from git tag) | On release |
| Each PS1 module | `$script:ModuleMeta.Version` inside the .psm1 file | When that module changes |
| Module registry | `modules.json` in repo root | On any module change |

### version.go (Auto-generated)

```go
package version

const (
    Version   = "2.1.0"    // Set by build script from git tag
    BuildDate = "2026-07-09"
    Commit    = "abc1234"  // Git short hash
)
```

Generated by `scripts/generate-version.ps1` during build:
```powershell
$tag = git describe --tags --abbrev=0
$hash = git rev-parse --short HEAD
@"
package version

const (
    Version   = "$($tag -replace '^v','')"
    BuildDate = "$(Get-Date -Format 'yyyy-MM-dd')"
    Commit    = "$hash"
)
"@ | Set-Content "internal/version/version.go" -Encoding UTF8
```

### modules.json (Module Registry)

Lives in the repo root. The Go module manager fetches this from GitHub to check for updates without downloading every .psm1 file.

```json
{
    "schema": 1,
    "modules": {
        "Antivirus": {
            "version": "1.0.0",
            "file": "Antivirus.psm1",
            "sha256": "abc123...",
            "admin": true,
            "dependencies": []
        },
        "Backup": {
            "version": "1.0.0",
            "file": "Backup.psm1",
            "sha256": "def456...",
            "admin": true,
            "dependencies": ["Logging"]
        },
        "Security": {
            "version": "1.0.0",
            "file": "Security.psm1",
            "sha256": "ghi789...",
            "admin": true,
            "dependencies": ["Antivirus"]
        }
    }
}
```

### Version Comparison Rules

1. Go binary checks `modules.json` on GitHub `raw.githubusercontent.com` for each module.
2. Compares remote `version` against local cached module's `$script:ModuleMeta.Version`.
3. If remote is newer (semver comparison) -> download updated .psm1.
4. If module not cached locally -> download from GitHub.
5. If GitHub unreachable -> fall back to embedded copy in `embed/modules/`.

---

## 5. Module Download & Cache System

### Cache Directory

```
C:\System_Optimizer\
├── modules\                    # Cached PS1 modules
│   ├── Antivirus.psm1
│   ├── Backup.psm1
│   ├── ...
│   └── modules.json            # Local copy of registry
├── logs\                       # Application logs
├── config\                     # User configuration
│   └── settings.json
└── temp\                       # Download staging area
```

### Update Flow (Per-Module, On Selection)

```
User selects "Antivirus" from menu
  │
  ├─ Go reads C:\System_Optimizer\modules\modules.json
  │
  ├─ Go fetches https://raw.githubusercontent.com/.../modules.json
  │
  ├─ Compare versions:
  │   ├─ Local missing      -> Download .psm1 + update modules.json
  │   ├─ Local older        -> Download .psm1 + update modules.json
  │   ├─ Local same         -> Use cached
  │   └─ GitHub unreachable -> Use cached (or embedded fallback)
  │
  └─ Execute: powershell.exe -NoProfile -ExecutionPolicy Bypass
              -File "C:\System_Optimizer\modules\Antivirus.psm1"
              -Command "Show-AntivirusMenu"
```

### Execution Model

The Go executor spawns `powershell.exe` for each function call:

```go
func ExecuteModuleFunction(modulePath string, functionName string) error {
    cmd := exec.Command("powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", fmt.Sprintf(
            "Import-Module '%s' -Force; %s",
            modulePath, functionName,
        ),
    )
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    cmd.Stdin = os.Stdin
    return cmd.Run()
}
```

For interactive submenus (functions that use `Read-Host`, `do/while` loops), the PowerShell process runs interactively with full stdin/stdout/stderr passthrough. The Go TUI pauses and lets PowerShell take over the terminal for that session.

### First-Run Bootstrap

```
Go binary launches for first time
  │
  ├─ Check C:\System_Optimizer\modules\modules.json
  │   └─ Not found -> First run
  │
  ├─ Create C:\System_Optimizer\modules\ directory
  │
  ├─ Extract embedded .psm1 files from embed/modules/ to cache
  │
  ├─ Attempt GitHub fetch of modules.json
  │   ├─ Success -> Replace embedded versions with latest
  │   └─ Failure -> Use embedded (will try again next time)
  │
  └─ Ready
```

---

## 6. Naming Conventions

### Go Code

| Element | Convention | Example |
|---------|-----------|---------|
| Packages | lowercase, short | `tui`, `modules`, `system`, `download` |
| Files | lowercase, underscore | `module_manager.go`, `system_info.go` |
| Types | PascalCase | `ModuleRegistry`, `MenuItem`, `SystemInfo` |
| Functions | PascalCase | `CheckForUpdates()`, `ExecutePS1()` |
| Methods | PascalCase | `mgr.DownloadModule()` |
| Constants | PascalCase | `Version`, `CacheDir` |
| Interfaces | -er suffix | `Executor`, `Downloader` |
| Package-level vars | camelCase | `defaultConfig`, `psExecPath` |

### PowerShell Modules

| Element | Convention | Example |
|---------|-----------|---------|
| Module files | PascalCase.psm1 | `Antivirus.psm1` |
| Public functions | Verb-Noun | `Show-AntivirusMenu`, `Install-EsetProduct` |
| Private functions | Verb-Noun (not exported) | `Get-EsetDownloadUrl` |
| Script vars | `$script:Name` | `$script:ModuleMeta` |
| Parameter names | PascalCase | `$ProductName`, `$ArchSuffix` |
| Log messages | UPPERCASE header | `Write-Log "INSTALLING ESET" "SECTION"` |

### Git

| Element | Convention | Example |
|---------|-----------|---------|
| Branches | type/description | `feat/go-migration`, `fix/eset-arm64` |
| Commits | type(scope): description | `feat(modules): add lazy download` |
| Tags | vMAJOR.MINOR.PATCH | `v2.1.0` |
| PR titles | Same as commit convention | |

### Menu Numbering

The Go TUI uses string-based menu routing, not numbered positions. This eliminates the fragile number-to-function mapping that caused issues in the PowerShell version:

```go
type MenuItem struct {
    ID          string   // Stable identifier: "antivirus", "eset", "defender"
    Label       string   // Display text
    Description string   // Tooltip/help text
    Module      string   // PS1 module to load (empty = built-in Go)
    Function    string   // Function to call (empty = show submenu)
    Children    []MenuItem // Submenu items
    Admin       bool    // Requires elevation
}
```

Menu items are identified by string IDs, not numbers. This means reordering the menu doesn't break anything, and the help system references IDs not positions.

---

## 7. TUI Design (Bubble Tea)

### Main Menu Layout

```
┌──────────────────────────────────────────────────────────────┐
│  SYSTEM OPTIMIZER v2.1.0                    [Update: v2.2.0] │
│  AMD64 | Windows 11 23H2 | Profile: Gaming                  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Quick Actions:                                              │
│  ┌─────────────────────────┐  ┌─────────────────────────┐   │
│  │ ▸ Run All Optimizations │  │   Full Setup             │   │
│  └─────────────────────────┘  └─────────────────────────┘   │
│                                                              │
│  Core:                          Tools:                       │
│  ┌─────────────────────────┐  ┌─────────────────────────┐   │
│  │ ▸ Telemetry             │  │ ▸ Software Install       │   │
│  │   Services              │  │   Office Tool Plus       │   │
│  │   Bloatware             │  │   MAS Activation         │   │
│  │   Scheduled Tasks       │  │   Wi-Fi Passwords        │   │
│  │   Registry              │  │   Verify Status          │   │
│  │   VBS/Memory Integrity  │  │                          │   │
│  │   Network               │  │                          │   │
│  │   OneDrive              │  │                          │   │
│  │   Maintenance           │  │                          │   │
│  └─────────────────────────┘  └─────────────────────────┘   │
│                                                              │
│  Advanced:                       Management:                 │
│  ┌─────────────────────────┐  ┌─────────────────────────┐   │
│  │   Power Plan            │  │ ▸ Antivirus              │   │
│  │   O&O ShutUp10          │  │   Defender Control       │   │
│  │   Windows Update        │  │   Shutdown Options       │   │
│  │   Driver Management     │  │   Profile Backup         │   │
│  │   Repair Updates        │  │   Undo/Rollback          │   │
│  │   Full Debloat          │  │   Hardware Detection     │   │
│  │   WinUtil Sync          │  │   Optimization Profiles  │   │
│  │   Privacy Tweaks        │  │                          │   │
│  │   Image Tool            │  │                          │   │
│  └─────────────────────────┘  └─────────────────────────┘   │
│                                                              │
│  ▸ = submenu   ? = help   q = quit                          │
└──────────────────────────────────────────────────────────────┘
```

### Execution View (when running a PS1 function)

```
┌──────────────────────────────────────────────────────────────┐
│  ESET Internet Security - Installing...                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Product:   ESET Internet Security                           │
│  Arch:      x64 (Intel/AMD 64-bit)                          │
│  Source:    Official ESET CDN                                │
│                                                              │
│  Downloading eis_nt64.exe...                                 │
│  ████████████████████████░░░░░░░░  67%  (57.2 / 85.5 MB)   │
│                                                              │
│  [Press Ctrl+C to cancel]                                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Key Bindings

| Key | Action |
|-----|--------|
| `↑`/`↓` or `j`/`k` | Navigate menu items |
| `Enter` | Select item / enter submenu |
| `Esc` | Back to parent menu |
| `q` | Quit (from main menu) |
| `?` | Show help for current item |
| `Tab` | Switch between menu columns |
| `Ctrl+R` | Refresh (re-check for updates) |

---

## 8. Menu Structure

The menu hierarchy mirrors the current PowerShell structure but uses string IDs:

```
root
├── run-all              -> Core.Start-AllOptimization
├── full-setup           -> Core.Start-FullSetup
│
├── telemetry            -> Telemetry.Disable-Telemetry
├── services             -> Services.Show-ServicesMenu
├── bloatware            -> Bloatware.DebloatBlacklist
├── tasks                -> Tasks.Disable-ScheduledTasks
├── registry             -> Registry.Set-RegistryOptimizations
├── vbs                  -> VBS.Disable-VBS
├── network              -> Network.Start-NetworkMenu
├── onedrive             -> OneDrive.Remove-OneDrive
├── maintenance          -> Maintenance.Start-MaintenanceMenu
│
├── software             -> Software.Start-PatchMyPC
├── office               -> Software.Start-OfficeTool
├── activation           -> Software.Start-MAS
├── wifi                 -> Utilities.Get-WifiPasswords
├── verify               -> Utilities.Test-OptimizationStatus
│
├── power                -> Power.Set-PowerPlan
├── shutup10             -> Privacy.Start-OOShutUp10
├── updates              -> WindowsUpdate.Set-WindowsUpdateControl
├── drivers              -> Drivers.Start-SnappyDriverInstaller
├── repair-updates       -> WindowsUpdate.Repair-WindowsUpdate
├── full-debloat         -> Bloatware.DebloatAll
├── winutil              -> Services.Sync-WinUtilServices
├── privacy-tweaks       -> UITweaks.Start-DISMStyleTweaks
├── image-tool           -> ImageTool.Start-ImageToolMenu
│
├── antivirus            -> [SUBMENU]
│   ├── eset             -> [SUBMENU]
│   │   ├── eset-eav     -> Antivirus.Install-EsetProduct -Product EAV
│   │   ├── eset-eis     -> Antivirus.Install-EsetProduct -Product EIS
│   │   ├── eset-essp    -> Antivirus.Install-EsetProduct -Product ESSP
│   │   ├── eset-esu     -> Antivirus.Install-EsetProduct -Product ESU
│   │   ├── eset-esbs    -> Antivirus.Install-EsetProduct -Product ESBS
│   │   ├── eset-essv    -> Antivirus.Install-EsetProduct -Product ESSV
│   │   ├── eset-compare -> Antivirus.Show-EsetComparison
│   │   └── eset-scan    -> Antivirus.Get-InstalledAvProducts
│   ├── defender         -> Security.Set-DefenderControl
│   ├── malwarebytes     -> [inline winget install]
│   └── av-scan          -> Antivirus.Get-InstalledAvProducts
│
├── defender             -> Security.Set-DefenderControl
├── shutdown             -> Shutdown.Show-ShutdownMenu
├── backup               -> Backup.Show-UserBackupMenu
├── rollback             -> Rollback.Show-RollbackMenu
├── hardware             -> Hardware.Show-HardwareSummary
└── profiles             -> Profiles.Show-ProfileMenu
```

---

## 9. CI/CD Pipeline

### ci.yml (Push/PR)

```yaml
name: CI
on: [push, pull_request]
jobs:
  lint-go:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.22' }
      - run: golangci-lint run

  test-go:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.22' }
      - run: go test ./...

  lint-ps1:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          Install-Module PSScriptAnalyzer -Force
          $results = Invoke-ScriptAnalyzer -Path ./modules -Severity Error,Warning
          if ($results) { $results | Format-Table; exit 1 }

  validate-modules:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          # Verify modules.json matches actual module versions
          .\scripts\validate-modules.ps1
```

### release.yml (Tag Push)

```yaml
name: Release
on:
  push:
    tags: ['v*.*.*']
jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.22' }

      - name: Embed PS1 modules
        run: .\scripts\embed-modules.ps1

      - name: Generate version.go
        run: .\scripts\generate-version.ps1

      - name: Build (amd64)
        run: GOOS=windows GOARCH=amd64 go build -o SystemOptimizer-amd64.exe .

      - name: Build (arm64)
        run: GOOS=windows GOARCH=arm64 go build -o SystemOptimizer-arm64.exe .

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            SystemOptimizer-amd64.exe
            SystemOptimizer-arm64.exe
```

---

## 10. Patterns Adopted from TEST Branch

These patterns from `origin/TEST` are carried forward into the Go+PS1 architecture:

| Pattern | From TEST | In New Architecture |
|---------|----------|-------------------|
| **Secure downloads** | `Invoke-TrustedGitHubRawDownload`, host allowlisting | `internal/download/client.go` with HTTPS-only + host allowlist |
| **SHA256 verification** | `Test-TrustedFileHash` | `internal/download/hash.go` (centralized, not duplicated) |
| **Input validation** | Typed confirmations for destructive ops | Go confirms before spawning PS1 for destructive actions |
| **Function Verb-Noun naming** | `Apply-*` -> `Set-*`, `Create-*` -> `New-*` | Enforced in module header convention |
| **Case-insensitive consent** | Warning.psm1 `-imatch` | Carried forward in PS1 modules |
| **`Get-CimInstance`** | Replaced `Get-WmiObject` | All PS1 modules use CIM |
| **CodeQL + dependency review** | CI workflows | `ci.yml` includes Go linting + PS1 analysis |
| **Module-load cleanup** | Bloatware.psm1 side-effect removal | Standard: no side effects at module load |
| **Host allowlisting** | `Invoke-TrustedDownload` | `internal/download/client.go` |

### Patterns Dropped from TEST

| Pattern | Reason |
|---------|--------|
| **EXE self-updater** | Go binary is a simple file replacement, no inline scripts needed |
| **ps2exe embedding** | Replaced by Go `embed` package |
| **`version.psd1` + `VERSION.json` dual system** | Single `modules.json` registry + per-module `$script:ModuleMeta` |
| **`Get-TrustedToolFile` duplication** | Centralized in `internal/download/` |
| **Hardcoded version fallbacks** | Version comes from `version.go` (compiled) or `modules.json` (fetched) |
| **`auto-tag-from-version.yml`** | Tags are manual git operations, not workflow-pushed |
| **Stub workflows** | Deleted |

---

## 11. Migration Checklist

### Phase 1: Go Skeleton
- [ ] Initialize Go module (`go mod init`)
- [ ] Set up Bubble Tea + Lip Gloss + Bubbles + Cobra
- [ ] Implement `internal/version/version.go` (manual initially)
- [ ] Implement `internal/config/paths.go` (cache dir, log dir)
- [ ] Implement `internal/modules/manager.go` (download, cache, version check)
- [ ] Implement `internal/modules/executor.go` (spawn powershell.exe)
- [ ] Implement `internal/system/arch.go` (ARM64/x64/x86 detection)
- [ ] Implement `internal/download/client.go` (HTTPS + host allowlist)
- [ ] Build main menu TUI (mirrors current 34 options)

### Phase 2: Module Standardization
- [ ] Add `$script:ModuleMeta` to all 30 PS1 modules
- [ ] Standardize module headers (`#Version:` tag)
- [ ] Generate `modules.json` from existing `configs/VERSION.json`
- [ ] Centralize `Get-TrustedToolFile` into shared pattern (remove duplication)
- [ ] Add `Export-ModuleMember` to Help.psm1, Warning.psm1

### Phase 3: TUI Completion
- [ ] All submenu views (Antivirus, Network, Maintenance, etc.)
- [ ] Progress display during PS1 execution
- [ ] System info display in header (arch, OS, profile)
- [ ] Update notification (compare Go binary version vs GitHub tag)
- [ ] Keyboard navigation, help overlay

### Phase 4: CI/CD
- [ ] `ci.yml` (Go lint + test, PS1 lint, module validation)
- [ ] `release.yml` (build amd64 + arm64, create GitHub Release)
- [ ] `validate-modules.ps1` (check modules.json matches actual files)
- [ ] `embed-modules.ps1` (copy PS1 into embed/ for Go build)

### Phase 5: Polish
- [ ] First-run bootstrap (extract embedded modules)
- [ ] Offline fallback (embedded modules when GitHub unreachable)
- [ ] Auto-update prompt for Go binary
- [ ] Logging integration (PS1 `Write-Log` -> Go log file)
- [ ] Error handling for missing powershell.exe

---

## 12. Decisions (Confirmed)

| Question | Decision | Notes |
|----------|----------|-------|
| Cache directory | `C:\System_Optimizer` | Matches current structure, keeps backwards compat |
| Download progress | Bubble Tea progress bar | Visible during module downloads from GitHub |
| PS1 output handling | **Per-module** | Depends on module type: some raw passthrough (interactive menus), some formatted by Go (progress output) |
| SHA256 verification | **Yes** | `modules.json` includes hashes; Go verifies on download |
| PowerShell version | **Check >=5.1, prefer PS7 if available** | Detect `pwsh.exe` (PS7) vs `powershell.exe` (5.1). Modules can declare `MinPSVersion` in `$script:ModuleMeta`. Warn if not met. Some modules are version-specific. |
