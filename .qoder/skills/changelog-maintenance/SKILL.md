---
name: changelog-maintenance
description: Maintains and updates the CHANGELOG.md for System Optimizer. Use when adding new features, fixing bugs, or releasing new versions to ensure proper changelog documentation.
---

# Changelog Maintenance Skill

## Overview

System Optimizer uses [Keep a Changelog](https://keepachangelog.com/) format with semantic versioning. The changelog documents all notable changes to help users track what's new, changed, fixed, or removed.

## Changelog Structure

```markdown
# Changelog

All notable changes to System Optimizer will be documented in this file.

## [Unreleased]

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security improvements

## [2.0.0] - YYYY-MM-DD
...
```

## When to Update

Update the changelog when:
- Adding new features or modules
- Fixing bugs
- Changing existing functionality
- Deprecating features
- Removing features
- Security fixes
- Performance improvements
- Documentation updates (significant)
- Menu/architecture changes

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (X.0.0) - Breaking changes, major rewrites
- **MINOR** (x.X.0) - New features, backwards compatible
- **PATCH** (x.x.X) - Bug fixes, backwards compatible

## Adding Entries

### For Unreleased Changes

Add to the `[Unreleased]` section at the top:

```markdown
## [Unreleased]

### Added
- **New Module** - Description of what it does

### Fixed
- **Bug Description** - Brief explanation of the fix
```

### For New Releases

When releasing, convert `[Unreleased]` to a version:

```markdown
## [2.1.0] - 2026-03-15

### Added
- Feature from unreleased

## [Unreleased]

(empty or remove until new changes)
```

## Entry Format

### Good Entries
```markdown
### Added
- **Network Diagnostics** - Added comprehensive network troubleshooting tools with ping, traceroute, and DNS resolution tests

### Fixed
- **Service Restart** - Fixed issue where services with dependencies would fail to restart in correct order
```

### Bad Entries
```markdown
- Fixed stuff
- Updated code
- Changes
```

## Categories to Use

| Category | Use For |
|----------|---------|
| `Added` | New features, modules, functions |
| `Changed` | Changes to existing functionality |
| `Deprecated` | Features marked for removal |
| `Removed` | Deleted features |
| `Fixed` | Bug fixes |
| `Security` | Security fixes and improvements |

## Module-Specific Entries

When documenting module changes:

```markdown
### Added
- **Telemetry Module** - Added Copilot disable option for Windows 11 24H2

### Changed
- **Services Module** - Renamed `Apply-WinUtilServiceConfig` to `Set-WinUtilServiceConfig` for PSScriptAnalyzer compliance
```

## Menu Changes

Document menu changes with before/after:

```markdown
### Changed
- **Menu Architecture** - Consolidated Maintenance items into sub-menu (reduced from 38 to 34 items)
```

## Function Renames

Document function renames clearly:

```markdown
### Changed
- **Function Renames** - Updated for PowerShell approved verbs:
  - `Apply-Config` → `Set-Config`
  - `Verify-Status` → `Test-Status`
```

## Statistics Section

For major releases, include statistics:

```markdown
### Statistics
- 3 new modules added
- 15 new functions
- 8 bug fixes
- 27 modules documented
```

## Workflow

1. **During Development**
   - Add entries to `[Unreleased]` as changes are made
   - Be specific and descriptive

2. **Before Release**
   - Review all `[Unreleased]` entries
   - Determine version bump (major/minor/patch)
   - Move entries to new version section
   - Add release date
   - Create new empty `[Unreleased]` section

3. **After Release**
   - Ensure version matches in all files:
     - `CHANGELOG.md`
     - `configs/VERSION.json`
     - `Start-SystemOptimizer.ps1` (if applicable)

## Quick Checklist

When updating changelog:
- [ ] Entry is under correct category
- [ ] Description is clear and specific
- [ ] Module names are bolded (**Module Name**)
- [ ] Function names use backticks (`Function-Name`)
- [ ] Version follows semver
- [ ] Date format is YYYY-MM-DD
- [ ] Links to issues/PRs included if applicable

## Example Complete Entry

```markdown
## [2.1.0] - 2026-03-15

### Added
- **Hardware Module** - Added GPU temperature monitoring for NVIDIA and AMD cards
- **Network Module** - New bandwidth test function with speed test integration

### Changed
- **Menu Layout** - Reorganized Software section for better discoverability
- **Logging** - Improved log rotation to keep 30 days instead of 7

### Fixed
- **Backup Module** - Fixed issue where Outlook backup would fail with large PST files
- **Installer Module** - Corrected drive detection on systems with multiple NVMe drives

### Security
- **Software Module** - Added certificate validation for all downloaded executables
```
