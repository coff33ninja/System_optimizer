---
name: function-module-map
description: Maintains the FunctionModuleMap for auto-reload functionality. Use when adding new functions to ensure they can be auto-reloaded if missing.
---

# FunctionModuleMap Skill

## Overview

The FunctionModuleMap in Start-SystemOptimizer.ps1 maps function names to their source modules. This enables:
- Auto-reload of missing modules
- Module identification for error messages
- Dynamic function discovery

## Location

```powershell
# In Start-SystemOptimizer.ps1
$script:FunctionModuleMap = @{
    'Function-Name' = 'ModuleName'
}
```

## When to Update

Add entries when:
- Creating new exported functions
- Renaming existing functions
- Creating new modules

## Entry Format

```powershell
'Function-Name' = 'ModuleName'
```

Note: ModuleName is the base name without .psm1 extension.

## Categories

Organize entries by category:

```powershell
# Core Modules
'Run-AllOptimizations' = 'Core'

# System Modules
'Disable-Telemetry' = 'Telemetry'
'Show-ServicesMenu' = 'Services'

# Utility Modules
'Get-WifiPasswords' = 'Utilities'
```

## Complete Update Checklist

When adding a new function:

1. [ ] Add function to module's Export-ModuleMember
2. [ ] Add entry to FunctionModuleMap
3. [ ] Add menu item (if user-facing)
4. [ ] Add to switch statement (if menu item)
5. [ ] Update module documentation header

## Example

Adding a new Network function:

```powershell
# In Network.psm1
function Get-NetworkStatus { }

Export-ModuleMember -Function @(
    'Get-NetworkStatus'  # Add to exports
)

# In Start-SystemOptimizer.ps1
$script:FunctionModuleMap = @{
    # Network
    'Get-NetworkStatus' = 'Network'  # Add to map
}
```

## Auto-Reload Behavior

When `Invoke-OptFunction` can't find a function:

1. Looks up module name in FunctionModuleMap
2. Attempts to reload that module
3. If module missing, offers to download from GitHub
4. Retries function call after reload

## Troubleshooting

If auto-reload fails:
- Verify function name spelling matches
- Check module name is correct
- Ensure function is exported in module
- Verify module file exists in modules/ directory
