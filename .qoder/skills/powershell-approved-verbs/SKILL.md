---
name: powershell-approved-verbs
description: Enforces PowerShell approved verb usage in System Optimizer modules. Use when creating or modifying PowerShell functions to ensure compliance with PSScriptAnalyzer PSUseApprovedVerbs rule.
---

# PowerShell Approved Verbs Skill

## Overview

System Optimizer requires strict adherence to PowerShell approved verbs for all cmdlet naming. This ensures compatibility with PSScriptAnalyzer and follows PowerShell best practices.

## Approved Verbs by Category

### Common Verbs (Most Used)
- `Get-` - Retrieves data
- `Set-` - Changes data or settings
- `Test-` - Verifies conditions (replaces "Verify", "Check")
- `Show-` - Displays information (replaces "Preview", "Display")
- `Start-` - Begins an operation
- `Stop-` - Ends an operation
- `New-` - Creates new items
- `Remove-` - Deletes items
- `Invoke-` - Executes actions (replaces "Run", "Execute")

### Verbs to AVOID
| Avoid | Use Instead |
|-------|-------------|
| `Apply-` | `Set-` |
| `Verify-` | `Test-` |
| `Preview-` | `Show-` |
| `Schedule-` | `Set-` |
| `Cancel-` | `Stop-` |
| `Ensure-` | `Set-` or `Test-` |
| `Run-` | `Start-` or `Invoke-` |
| `Compare-` | Use `Get-` and compare results |

## When Creating Functions

1. **Check verb approval**: Run `Get-Verb` in PowerShell to see approved verbs
2. **Choose the right category**: Use Data, Lifecycle, or Diagnostic verbs appropriately
3. **Use singular nouns**: `Get-User` not `Get-Users`

## Fixing Existing Code

When renaming functions:

1. Update function definition
2. Update all internal calls
3. Update Export-ModuleMember
4. Update FunctionModuleMap in Start-SystemOptimizer.ps1
5. Update documentation headers
6. Update any external references

## Example Renames

```powershell
# Before
function Apply-WinUtilServiceConfig { }
function Preview-WinUtilServiceChanges { }
function Schedule-ShutdownAtTime { }
function Cancel-AllScheduledShutdowns { }

# After
function Set-WinUtilServiceConfig { }
function Show-WinUtilServiceChanges { }
function Set-ShutdownAtTime { }
function Stop-ScheduledShutdown { }
```

## References

- [PowerShell Approved Verbs](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
