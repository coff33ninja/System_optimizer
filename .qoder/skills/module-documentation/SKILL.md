---
name: module-documentation
description: Creates standardized comment-based help documentation for PowerShell modules. Use when creating new modules or updating existing module documentation in System Optimizer.
---

# Module Documentation Skill

## Overview

All System Optimizer modules must have standardized comment-based help documentation following PowerShell conventions.

## Documentation Template

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    [Module Name] Module - System Optimizer
.DESCRIPTION
    [Detailed description of module purpose and capabilities]

Exported Functions:
    [Function-Name]    - [Brief description]
    [Function-Name]    - [Brief description]

[Category-specific sections]:
    - [Feature/capability details]
    - [Configuration options]

[Requirements/Notes]:
    - Admin requirements
    - Compatibility info
    - Work directories

Version: 1.0.0
#>
```

## Required Sections

### 1. SYNOPSIS
- Module name and system context
- Keep under 80 characters

### 2. DESCRIPTION
- What the module does
- Key features
- Integration points

### 3. Exported Functions
List all exported functions with brief descriptions:
```powershell
Exported Functions:
    Get-WifiPasswords           - Extract saved Wi-Fi passwords
    Test-OptimizationStatus     - Check optimization status
    Show-LogViewer              - Interactive log viewer
```

### 4. Category Sections
Include relevant sections:
- **Features** - What the module provides
- **Configuration** - Config files used
- **Integration** - Other modules/tools used

### 5. Requirements
```powershell
Requires Admin: Yes/No
Work Directory: C:\System_Optimizer\ModuleName\
Version: 1.0.0
```

## Sub-Menu Documentation

For modules with sub-menus, include menu structure:

```powershell
# Menu Structure:
#   [1]  Option One
#   [2]  Option Two
#   [0]  Back to Main Menu
```

## Examples

### Simple Module
```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    OneDrive Module - System Optimizer
.DESCRIPTION
    Provides complete OneDrive removal and cleanup functionality.

Exported Functions:
    Remove-OneDrive   - Complete OneDrive uninstallation
    Install-OneDrive  - Reinstall OneDrive (if needed)

Actions Performed:
    - Stop OneDrive processes
    - Uninstall OneDrive application
    - Remove from Explorer sidebar
    - Disable via Group Policy
    - Clean up registry entries

Requires Admin: Yes
Version: 1.0.0
#>
```

### Complex Module with Sub-Menu
```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Maintenance Module - System Optimizer
.DESCRIPTION
    Provides comprehensive system maintenance and repair tools.

Exported Functions:
    Start-SystemMaintenance    - Automated maintenance
    Start-DiskCleanup          - Advanced disk cleanup
    Reset-GroupPolicy          - Reset GPO to defaults
    Start-MaintenanceMenu      - Interactive menu

Menu Structure:
    [1]  Run Automated Maintenance
    [2]  Disk Cleanup
    [3]  Reset Group Policy
    [0]  Back to Main Menu

Requires Admin: Yes
Version: 1.0.0
#>
```

## Placement

Documentation must be at the **very beginning** of the .psm1 file:

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    ...
#>

# Module code starts here
function Get-Example { }
```

## Export-ModuleMember

Always explicitly export functions:

```powershell
Export-ModuleMember -Function @(
    'Function-One',
    'Function-Two',
    'Function-Three'
)
```
