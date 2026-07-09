# Branch Analysis: dev & TEST

> Generated: July 9, 2026
> Purpose: Record what was attempted on historical branches, findings, and adoption recommendations.

---

## Branch Overview

```
main  ── c0842b5 (v2.0.0 merge)  ── CURRENT LOCAL + REMOTE HEAD
                                          │
origin/TEST ── 25 commits ahead ── 1509eda ── ALL v2.0.1-v2.0.4 work
origin/dev  ── 4 commits ahead  ── 5549b4c ── Abandoned early dev attempt
```

Both `dev` and `TEST` were never merged back to `main`. The `main` branch is stuck at the v2.0.0 merge commit while all subsequent release work was done on `TEST`.

---

## origin/dev (Abandoned)

**4 commits, superseded by TEST. Safe to ignore entirely.**

### What Was Attempted

| Commit | Description |
|--------|-------------|
| `a5d93ce` | Initial release - System Optimizer v1.0.0 |
| `3ab9472` | Add before/after comparison system with snapshots and reports |
| `5cb9c80` | Add menu status indicators showing applied optimizations |
| `5549b4c` | Use configured branch for module downloads, add -Suffix param to build script |

### Summary

An early development branch that explored two features: a before/after optimization snapshot/comparison system, and build script improvements. The branch also cleaned up a large amount of documentation and module code (deleted the entire `.qoder/` wiki, `Help.psm1`, `Warning.psm1`, `CHANGELOG.md`, `TODO.md`). These changes were superseded by the work done on `TEST` and the module restructuring that followed.

### Verdict: Bench

Nothing from `dev` needs to be recovered. The snapshot/comparison features were not completed and the cleanup was aggressive (deleted files that were later restored on `TEST`).

---

## origin/TEST (Active Development)

**25 commits ahead of main, +3050/-938 lines across 51 files.**

This branch contains ALL work from v2.0.1 through v2.0.4 plus additional unreleased changes. It is effectively the "real main" that was never merged.

### Commit History

| Commit | Description |
|--------|-------------|
| `105a2ec` | Fix core command wiring and align CI/release behavior |
| `33c36fc` | Create SECURITY.md |
| `b83532d` | Centralize version source and harden release workflow |
| `ce7e9c2` | Merge branch 'main' of origin (parallel push resolution) |
| `2809c71` | Define supported PowerShell versions and reporting policy |
| `e957a8f` | Resolve analyzer warnings across modules |
| `1e38c04` | Update changelog for analyzer remediation |
| `3de3ae8` | Auto-tag from version and generate changelog notes |
| `33045fd` | Trigger release workflow after auto-tag |
| `c8e1fa6` | Support manual tag release dispatch |
| `df47202` | Pass explicit tag name to release action |
| `dab878f` | Add CodeQL workflow for GitHub Actions |
| `edffc5b` | Upgrade CodeQL action to v4 |
| `e193502` | Set explicit permissions for code-analysis workflow |
| `32c7e47` | Add dependency review workflow |
| `7ba8788` | Restore historical workflow filenames for code scanning references |
| `d88c39f` | Accept consent input case-insensitively and harden prompt flow |
| `15b0c9a` | Accept consent with trailing punctuation |
| `4c0d543` | **Release v2.0.2** - sync version metadata and changelog |
| `803ac9f` | Add EXE in-place updater and startup module cache sync |
| `73f1d82` | Test self-updating |
| `cfd563b` | **Release v2.0.3** - sync version metadata and changelog |
| `e8c2fe2` | Restore BOM module compatibility and force EXE cache refresh |
| `1a6a6d4` | **Release v2.0.4** - sync version metadata and changelog |
| `1509eda` | Centralize logging resolution and module initialization |

---

### Detailed Findings by Area

#### 1. CI/CD Workflows (.github/workflows/)

**What changed:**

- `code-analysis.yml` -- Added explicit `permissions: read`, switched to `PSScriptAnalyzerSettings.psd1`, added `exit 1` on failures (was non-blocking before).
- `release.yml` -- Added `workflow_dispatch` with manual tag input, tag validation, version metadata sync via new scripts, CHANGELOG.md validation, EXE build now embeds all `.psm1` modules + `version.psd1`.
- New `auto-tag-from-version.yml` -- Auto-creates git tags from `version.psd1` pushes on `main`.
- New `security.yml` -- CodeQL for GitHub Actions, weekly schedule + push/PR triggers.
- New `dependency-review.yml` -- Dependency review on PRs.
- New `codacy.yml`, `powershell.yml` -- Stub files (manual trigger, echo only).

**Assessment:** Mostly good. The release pipeline is significantly more robust. The `exit-on-failure` in `code-analysis.yml` will now actually block PRs with issues.

**Red flags:**
- `auto-tag-from-version.yml` re-fetches and pushes to `main` inside the workflow -- could cause race conditions on concurrent pushes.
- `codacy.yml` and `powershell.yml` are noise unless there is a historical scanning reference requirement.

---

#### 2. Main Script (Start-SystemOptimizer.ps1, ~400 lines added)

**What changed:**

- **Version system:** Now reads from `version.psd1` via `Get-SystemOptimizerVersionInfo` (checks multiple candidate paths, falls back to `"2.0.4"`). Config `Version` is now dynamic, not hardcoded.
- **Secure downloads:** New `Invoke-TrustedGitHubRawDownload` and `Invoke-TrustedGitHubReleaseDownload` -- validates HTTPS scheme and host (only `raw.githubusercontent.com` / `github.com`). Replaced bare `Invoke-WebRequest` calls.
- **Module cache:** `Initialize-ModuleCache` copies embedded EXE modules to `C:\System_Optimizer\modules` with atomic swap (staging, backup, rename). Caches version to avoid redundant copies.
- **EXE self-update:** `Start-ExecutableInPlaceUpdate` downloads new EXE, writes a temp updater script, launches hidden PowerShell to swap at exit.
- **Module loading:** Logging module loaded first via `Sort-Object` priority. `Resolve-LoggingCommand` provides graceful fallback if Logging.psm1 is unavailable.
- **Function renames:** `Run-AllOptimizations` -> `Start-AllOptimization`, `Run-FullSetup` -> `Start-FullSetup`. Function-to-module map updated accordingly.
- **Hardcoded URL removed:** `coff33ninja/System_Optimizer/main/...` replaced with `$Config.GitHubRepo/$Config.GitHubBranch` references throughout.
- **Update flow:** Now downloads `version.psd1` too, uses staging file pattern (`.new` then `Move-Item`) instead of direct overwrite.

**Assessment:** Significantly improved. Secure downloads, dynamic versioning, and the module cache are all valuable additions.

**Red flags:**
- `Get-SystemOptimizerVersionInfo` hardcodes fallback to `"2.0.4"` in four places -- should come from a constant.
- The EXE self-update launches a background PowerShell process -- the updater script is generated inline (cannot be reviewed before execution).
- `Write-Log` function in main script now delegates to Logging module but also has a bootstrap fallback -- possible confusion about which implementation is active.

---

#### 3. Versioning System (version.psd1, scripts/)

**What changed:**

- **New `version.psd1`:** Canonical version source: `@{ Version = '2.0.4' }`.
- **New `scripts/sync-version.ps1`:** Updates `version.psd1`, main script version, `Help.psm1`, `Backup.psm1`, and 5 other modules with the canonical version. Also updates `run_optimization.bat` release tag. Has `-CheckOnly` and `-StampModuleHeaders` flags.
- **New `scripts/stamp-version.ps1`:** Updates `Version: x.y.z` header lines in all `.psm1` files.
- **New `scripts/generate-changelog-entry.ps1`:** Auto-generates a CHANGELOG.md section from commits since last tag.
- **`scripts/build_exe.ps1`:** Now reads version from `version.psd1` (auto-detect), embeds `version.psd1` into EXE.
- **`scripts/version_manager.ps1`:** Migrated from `configs/VERSION.json` to `version.psd1`. Functions renamed: `Parse-Version` -> `ConvertTo-VersionParts`, `Bump-Version` -> `Update-VersionNumber`.

**Assessment:** Good -- centralizing version in `version.psd1` is the right move.

**Red flags:**
- `sync-version.ps1` has a `$releaseInfoModules` list that does not include all modules (only 5 + Help).
- `version_manager.ps1` still writes to `configs/VERSION.json` as legacy -- creates confusion about which file is canonical.
- Default fallback to `"2.0.1"` in `build_exe.ps1` vs `"2.0.4"` in other files -- drift risk.

---

#### 4. New Files (SECURITY.md, PSScriptAnalyzerSettings.psd1)

**What changed:**

- `SECURITY.md` -- Defines supported runtimes (PS 5.1, PS 7.2+), reporting via GitHub Security Advisories, 72-hour acknowledgement target.
- `PSScriptAnalyzerSettings.psd1` -- Excludes `PSAvoidUsingWriteHost`, `PSUseShouldProcessForStateChangingFunctions`, `PSUseSingularNouns`.

**Assessment:** Good additions. The analyzer exclusions are appropriate for a console-based UI tool.

---

#### 5. Core Infrastructure (Core.psm1, Logging.psm1, Utilities.psm1)

**What changed:**

- `Core.psm1` -- `Start-Download` rewritten: replaced `WebClient` async download with progress callback with simpler `Invoke-WebRequest` + timeout (900s). `Start-AllOptimization` calls `DebloatBlacklist` instead of `Remove-BloatwareApps`.
- `Logging.psm1` -- Added `Write-Log` as a compatibility wrapper around `Write-OptLog`. Exported `Write-Log` in module exports.
- `Utilities.psm1` -- Renamed `Initialize-Logging` -> `Initialize-UtilitiesLogging`, `Write-Log` -> `Write-UtilitiesLog`. New `Get-UtilitiesLoggerCommand` tries to delegate to `Write-Log` or `Write-OptLog` from Logging module. Added script-level defaults for `LogDir`, `LogFile`, console dimensions.

**Assessment:** Mixed.

**Good:** `Start-Download` simplification removes complex event-based code that was prone to leaks (unregistered events).

**Problematic:** `Utilities.psm1` renamed its own `Write-Log` to `Write-UtilitiesLog` but `Core.psm1` and many other modules still call `Write-Log` -- will now resolve to `Logging\Write-Log` (the wrapper) instead of the old `Utilities\Write-Log`. This is intentional but introduces a mandatory dependency on `Logging.psm1` being loaded first.

---

#### 6. Large Module Changes (Backup.psm1, ImageTool.psm1, Installer.psm1)

**What changed:**

- **Backup.psm1:** Replaced local `Write-Log` fallback with `Write-BackupLog` that delegates to Logging module. New `Get-SystemOptimizerVersion` reads from `version.psd1`. `Get-WmiObject` -> `Get-CimInstance` (modern PowerShell best practice). `SystemOptimizerVersion` in manifest now dynamic instead of hardcoded.
- **ImageTool.psm1:** Massive rename: `Apply-*` -> `Set-*`, `Inject-Drivers` -> `Add-DriversToImage`, `Create-*` -> `New-*`, `Download-*` -> `Get-*`, `Cleanup-*` -> `Clear-*`. `Start-WindowsInstaller` and `Start-VHDDeployment` no longer download external scripts -- now call module commands directly. `New-UnattendFile` adds username validation, secure string for password. Bootstrap command now downloads `SystemOptimizer.exe` from GitHub releases instead of `run_optimization.bat`. Legacy aliases added via `Set-Alias`.
- **Installer.psm1:** `$ErrorActionPreference` changed from `SilentlyContinue` to `Continue`. New input validation functions (`Read-InstallerDiskNumber`, `Read-InstallerImageIndex`, `Confirm-InstallerAction`). `Get-TrustedToolFile` with hash verification for `WinNTSetup.zip`. Function renames: `Prepare-*` -> `Initialize-*`, `Create-*` -> `New-*`.

**Assessment:** Mostly excellent. The rename convention now follows PowerShell best practices. Input validation added to destructive operations. Hash-verified tool downloads.

**Red flags:**
- `ImageTool.psm1`'s `Start-WindowsInstaller` now requires the Installer module to be present -- previously it worked standalone via web download.
- `Get-TrustedToolFile` is duplicated identically across Installer, Drivers, Security, and WindowsUpdate modules (violates DRY).
- Hardcoded SHA256 hash values will become stale when tools are updated with no update mechanism.

---

#### 7. Software/Security (Security.psm1, Software.psm1, Drivers.psm1)

**What changed:**

- **Security.psm1:** Added `Get-SystemOptimizerVersionInfo`, `Test-TrustedFileHash`, `Get-TrustedToolFile` (for `Defender_Tools.exe`, `install_wim_tweak.exe`). Tool download URLs changed from raw GitHub to release download with hash verification.
- **Software.psm1:** New `Invoke-TrustedDownload` -- validates HTTPS + allowlisted hosts (`raw.githubusercontent.com`, `github.com`, `community.chocolatey.org`, `patchmypc.com`). New `Install-ChocolateyBootstrap` -- requires explicit confirmation, downloads to temp file instead of `Invoke-Expression` from web. `Start-MAS` changed from `irm https://get.activated.win | iex` to downloading `MAS_AIO.cmd` from official GitHub + running via cmd.exe. `Start-OfficeTool` removed dangerous web installer fallback.
- **Drivers.psm1:** Added trusted tool download with hash verification for `SNAPPY_DRIVER.zip`.

**Assessment:** Significant security improvements. The removal of bare `iex` from web is critical.

**Red flags:**
- `Get-TrustedToolFile` is copy-pasted across 4 modules (Security, Drivers, WindowsUpdate, Installer) -- tech debt.
- Hardcoded hashes are brittle.
- The MAS source (`massgravel/Microsoft-Activation-Scripts`) should be verified as the official MAS project.

---

#### 8. Feature Modules (UITweaks.psm1, VHDDeploy.psm1, WindowsUpdate.psm1, Privacy.psm1)

**What changed:**

- **UITweaks.psm1:** `Safe-WriteLog` -> `Write-UITweaksLog` (delegates to Logging module). `Apply-*` -> `Set-*` across all functions.
- **VHDDeploy.psm1:** `$ErrorActionPreference` changed to `Continue`. New input validation functions (`Read-VHDSizeGB`, `Read-VHDDriveLetter`, `Read-VHDBootName`, `Read-VHDImageIndex`, `Test-VHDPathValue`, `Confirm-VHDAction`). Bootstrap shortcut changed to release EXE. Overwrite and boot entry additions now require explicit typed confirmation.
- **WindowsUpdate.psm1:** Added `Get-TrustedToolFile` for `WUpdater.exe` with hash verification. Update pause days now bounded (1-365). Full repair requires typed confirmation (`"FULL REPAIR"`).
- **Privacy.psm1:** New `Get-TrustedConfigFile` with allowlisted config file names (`ooshutup10.cfg`, `block-telemetry.ps1`, `DEBLOATER.ps1`). Validates HTTPS + host.

**Assessment:** Strong improvements across the board.

**Red flags:**
- `Get-TrustedToolFile` pattern duplicated again in WindowsUpdate.
- Privacy module's allowlist approach is cleaner but still hardcodes URLs.
- `VHDDeploy.psm1` exports may not include the new validation functions -- needs verification.

---

#### 9. Smaller Modules (Help.psm1, Warning.psm1, Bloatware.psm1)

**What changed:**

- **Help.psm1:** `Get-SystemOptimizerVersionInfo` added. `$script:GitHubRawUrl` now uses `PinnedReleaseTag` instead of hardcoded `main` branch. New `Invoke-TrustedFeaturesDownload` validates host before download.
- **Warning.psm1:** Consent check made case-insensitive (`-imatch`), allows trailing punctuation. Added `Read-Host` fallback if `ReadKey` fails, and "Press Enter to exit" on rejection path.
- **Bloatware.psm1:** Removed `$ErrorActionPreference`, `$DebloatFolder` creation, `Start-Transcript`, and `Add-Type PresentationCore` from module root (side-effect code at load time). `CheckDMWService` now swallows unused `$Debloat` param.

**Assessment:** Warning.psm1 improvements are user-friendly. Bloatware.psm1 cleanup of module-load side effects is good.

**Red flags:**
- Help.psm1 still downloads `FEATURES.md` from web -- no offline fallback.
- Bloatware.psm1's `CheckDMWService` has a dead param (`$null = $Debloat`) -- should be removed.

---

## Consolidated Red Flags

| Priority | Issue | Impact |
|----------|-------|--------|
| **High** | `Get-TrustedToolFile` duplicated across 4 modules | Code duplication, maintenance burden |
| **High** | Hardcoded `"2.0.4"` fallback in every module's version detection | Version drift |
| **High** | Hardcoded SHA256 hashes with no update mechanism | Breaks on tool updates |
| **Medium** | Dual version system (`version.psd1` + `configs/VERSION.json`) | Confusion about canonical source |
| **Medium** | `auto-tag-from-version.yml` pushes to `main` inside workflow | Race condition risk |
| **Medium** | Logging dependency chain (Utilities -> Logging wrapper) | Fragile, works but brittle |
| **Low** | `codacy.yml` and `powershell.yml` stub workflows | Noise |
| **Low** | Help.psm1 requires web access for FEATURES.md | No offline fallback |
| **Low** | `VHDDeploy.psm1` may not export new validation functions | Function unavailability |
| **Low** | Dead `$Debloat` param in `Bloatware.psm1` `CheckDMWService` | Dead code |

---

## Recommendations for Main

### Adopt As-Is

- SECURITY.md
- PSScriptAnalyzerSettings.psd1
- Warning.psm1 improvements (case-insensitive consent, ReadKey fallback)
- Bloatware.psm1 module-load cleanup
- CodeQL + dependency-review workflows
- `code-analysis.yml` exit-on-failure behavior
- `Get-CimInstance` instead of `Get-WmiObject` in Backup.psm1

### Adopt After Refactoring

- **Secure downloads** (`Invoke-TrustedGitHubRawDownload`, host allowlisting) -- extract shared `Get-TrustedToolFile` to a single location before adopting.
- **Function renames** (Verb-Noun convention) -- adopt but add legacy aliases for backwards compatibility.
- **Input validation on destructive operations** -- adopt for Installer, VHDDeploy, WindowsUpdate.
- **Version system** -- pick `version.psd1` as single canonical source, remove `configs/VERSION.json` from the version flow entirely.
- **Module cache for embedded EXE** -- adopt, but remove hardcoded fallback versions.

### Skip

- `auto-tag-from-version.yml` (rework the push mechanism first)
- `codacy.yml`, `powershell.yml` stubs
- EXE self-updater (inline generated script is a security concern -- revisit later with proper code signing)
- Hardcoded SHA256 hashes (need a registry file or auto-fetch mechanism first)

### Verify Before Adopting

- MAS source (`massgravel/Microsoft-Activation-Scripts`) is the official project
- `VHDDeploy.psm1` exports include all new functions
- `Start-AllOptimization` calling `DebloatBlacklist` vs `Remove-BloatwareApps` is intentional
- 900s download timeout is appropriate for target users
