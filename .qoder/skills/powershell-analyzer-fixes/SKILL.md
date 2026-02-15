---
name: powershell-analyzer-fixes
description: Fixes common PSScriptAnalyzer issues in System Optimizer modules. Use when encountering PSUseApprovedVerbs, PSAvoidAssignmentToAutomaticVariable, or other analyzer warnings.
---

# PowerShell Analyzer Fixes Skill

## Overview

System Optimizer enforces clean PSScriptAnalyzer output. This skill helps resolve common analyzer warnings.

## Common Issues and Fixes

### PSUseApprovedVerbs

**Problem**: Function uses unapproved verb

**Fix**: Rename to approved verb

```powershell
# Before
function Apply-Config { }
function Verify-Status { }
function Schedule-Task { }
function Cancel-Operation { }

# After
function Set-Config { }
function Test-Status { }
function Set-Task { }
function Stop-Operation { }
```

**Update Checklist**:
- [ ] Function definition
- [ ] All internal calls
- [ ] Export-ModuleMember
- [ ] FunctionModuleMap
- [ ] Documentation header

### PSAvoidAssignmentToAutomaticVariable

**Problem**: Variable name conflicts with PowerShell automatic variable

**Common conflicts**:
- `$profile` → Use `$userProfile` or `$wifiProfile`
- `$error` → Use `$err` or `$lastError`
- `$input` → Use `$userInput` or `$dataInput`
- `$host` → Use `$computer` or `$targetHost`

**Fix**: Rename variable

```powershell
# Before
foreach ($profile in $profiles) { }

# After
foreach ($wifiProfile in $profiles) { }
```

### PSUseSingularNouns

**Problem**: Plural noun in function name

**Fix**: Use singular noun

```powershell
# Before
function Get-Users { }
function Get-Services { }

# After
function Get-User { }
function Get-Service { }
```

### PSUseShouldProcessForStateChangingFunctions

**Problem**: Function changes system state without -WhatIf support

**Fix**: Add [CmdletBinding(SupportsShouldProcess)]

```powershell
function Set-RegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    if ($PSCmdlet.ShouldProcess("Registry", "Set value")) {
        # Do the change
    }
}
```

## Quick Fix Workflow

1. **Identify the issue** from analyzer output
2. **Locate the file and line** in the error message
3. **Apply the fix** using patterns above
4. **Update all references** (exports, maps, docs)
5. **Verify fix** by re-running analyzer

## Verification

Check for remaining issues:

```powershell
# Run PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path .\modules\ModuleName.psm1
```

## Prevention

- Use approved verbs from the start
- Avoid common automatic variable names
- Use singular nouns for function names
- Test with PSScriptAnalyzer before committing
