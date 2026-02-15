---
name: menu-architecture
description: Manages the hierarchical menu system for System Optimizer. Use when adding new menu items, creating sub-menus, or modifying the main menu structure in Start-SystemOptimizer.ps1.
---

# Menu Architecture Skill

## Overview

System Optimizer uses a hierarchical menu architecture with:
- Main menu (Start-SystemOptimizer.ps1)
- Sub-menus within modules (e.g., Maintenance, Network)
- Two-column layout for compact display

## Main Menu Structure

### Menu Numbering
```
1-16   Quick Actions & Core
17-26  Advanced Tools
27-34  Tools & Management
```

### Adding New Menu Items

1. **Assign menu number** - Use next available number
2. **Add to Show-MainMenu** - Use Write-MenuItemCompact
3. **Add to switch statement** - Map number to function
4. **Add to FunctionModuleMap** - For reload support
5. **Update help text** - Both in-script and FEATURES.md

## Two-Column Layout

```powershell
Write-Host "  Category 1:               Category 2:" -ForegroundColor Gray
Write-MenuItemCompact "2" "Item Name" 'Function-Name'
Write-MenuItemCompact "11" "Other Item" 'Other-Function'
Write-Host ""
```

## Sub-Menu Pattern

Modules with sub-menus export a `Start-*Menu` function:

```powershell
# In Module.psm1
function Start-ModuleMenu {
    do {
        Clear-Host
        Write-Log "MODULE MENU" "SECTION"
        
        Write-Host "  [1] Option One"
        Write-Host "  [2] Option Two"
        Write-Host "  [0] Back"
        
        $choice = Read-Host "Select option"
        
        switch ($choice) {
            "1" { Function-One }
            "2" { Function-Two }
            "0" { return }
        }
    } while ($choice -ne "0")
}
```

## Consolidation Strategy

When menu items become too numerous:

1. **Group related functions** into sub-menus
2. **Replace individual items** with sub-menu entry
3. **Renumber remaining items** sequentially
4. **Update all references** (menu, switch, docs)

## Menu Item Display

### Full Width (Quick Actions)
```powershell
Write-MenuItem "1" "Run ALL Optimizations" "Description" 'Function-Name'
```

### Compact (Two-Column)
```powershell
Write-MenuItemCompact "2" "Menu Text" 'Function-Name'
```

## FunctionModuleMap Updates

Always add new functions to the map for auto-reload:

```powershell
$script:FunctionModuleMap = @{
    'New-Function' = 'ModuleName'
}
```

## Documentation Updates

When changing menus:
1. Update in-script help text (MENU NAVIGATION section)
2. Update FEATURES.md
3. Update README.md menu overview
4. Update module documentation headers
