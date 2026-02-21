# System Optimizer - TODO List

## High Priority - Code Refactoring

### ✅ Completed
- [x] Fix menu numbering (changed 31-38 to 27-34 for sequential order)
- [x] Move help text to Help.psm1 module
- [x] Add Show-ComprehensiveHelp function to Help module

### 🔄 In Progress

#### Create Warning.psm1 Module (First-Run Safety)
Create a first-run warning system to inform users about the tool:
- [ ] Create modules/Warning.psm1 file
- [ ] Create `Show-FirstRunWarning` function with comprehensive disclaimer
- [ ] Explain what System Optimizer does (system modifications, service changes, etc.)
- [ ] List potential risks and system changes
- [ ] Require explicit user consent before proceeding
- [ ] Store consent flag in registry or config file (HKCU:\Software\SystemOptimizer\FirstRun)
- [x] Add option to view warning again from menu
- [ ] Include backup recommendation before running optimizations
- [ ] Add "I understand and accept the risks" confirmation
- [ ] Create restore point recommendation
- [ ] Export `Show-FirstRunWarning`, `Test-FirstRunComplete`, `Set-FirstRunComplete`
- [ ] Integrate into main script entry point (before menu loads)
- [ ] Test warning display and consent flow
- [ ] Add to FunctionModuleMap

Warning Content Should Include:
- Project purpose: Windows 10/11 optimization toolkit
- What it modifies: Services, telemetry, registry, scheduled tasks, bloatware
- Risks: System instability if not used correctly, potential compatibility issues
- Recommendations: Create restore point, backup important data
- Reversibility: Mention rollback system availability
- Admin requirement: Explain why admin rights are needed
- Support: Link to GitHub issues for problems

#### Create Menu.psm1 Module
Move all menu-related functions from main script to new Menu.psm1:
- [ ] Create modules/Menu.psm1 file
- [ ] Move `Test-FunctionAvailable` function
- [ ] Move `Get-MenuItemColor` function
- [ ] Move `Write-MenuItem` function
- [ ] Move `Write-MenuItemCompact` function
- [ ] Move `Invoke-OptFunction` function
- [ ] Move `Get-QuickHardwareSummary` function
- [ ] Move `Show-MainMenu` function
- [ ] Move `Start-MainMenu` function
- [ ] Move `$FunctionModuleMap` variable
- [ ] Export all public functions
- [ ] Update main script to import Menu module
- [ ] Test menu functionality after refactoring

#### Refactor Core.psm1 Module
Move core system functions from main script:
- [ ] Check what's already in Core.psm1
- [ ] Move `Get-LatestVersion` function
- [ ] Move `Test-UpdateAvailable` function
- [ ] Move `Update-SystemOptimizer` function
- [ ] Move `Import-OptimizerModules` function
- [ ] Move `Update-ModulesFromGitHub` function
- [ ] Export all public functions
- [ ] Update main script to use Core module functions
- [ ] Test update and module loading functionality

#### Refactor Logging.psm1 Module
Consolidate logging functions:
- [ ] Check what's already in Logging.psm1
- [ ] Move `Initialize-Logging` function (if not already there)
- [ ] Move `Write-Log` function (if not already there)
- [ ] Ensure consistent logging across all modules
- [ ] Export all public functions
- [ ] Update main script to use Logging module
- [ ] Test logging functionality

#### Refactor Utilities.psm1 Module
Move utility functions:
- [ ] Check what's already in Utilities.psm1
- [ ] Move `Set-ConsoleSize` function
- [ ] Review other utility functions that could be consolidated
- [ ] Export all public functions
- [ ] Update main script to use Utilities module
- [ ] Test console and utility functions

#### Simplify Main Script
After moving functions to modules:
- [ ] Remove moved function definitions
- [ ] Keep only configuration setup
- [ ] Keep only parameter handling
- [ ] Keep only UTF-8 encoding setup
- [ ] Keep only module loading calls
- [ ] Keep only entry point logic
- [ ] Target: Reduce main script to ~200 lines
- [ ] Add clear comments for each section
- [ ] Test full application flow

## Medium Priority - Code Quality

### Module Documentation
- [ ] Add comprehensive header comments to Menu.psm1
- [ ] Review and update all module .SYNOPSIS sections
- [ ] Ensure all exported functions have proper help text
- [ ] Add usage examples to module headers
- [ ] Document module dependencies

### Error Handling
- [ ] Review error handling in all moved functions
- [ ] Add try-catch blocks where needed
- [ ] Ensure graceful degradation when modules fail to load
- [ ] Add meaningful error messages
- [ ] Test error scenarios

### Testing
- [ ] Create test script for Menu module
- [ ] Create test script for Core module
- [ ] Test module loading in different scenarios
- [ ] Test with missing modules
- [ ] Test with corrupted modules
- [ ] Test update functionality
- [ ] Test all menu options
- [ ] Test direct run mode (-RunOption)

## Low Priority - Enhancements

### Code Consistency
- [ ] Standardize function naming conventions
- [ ] Standardize parameter naming
- [ ] Standardize comment styles
- [ ] Review and fix any PowerShell script analyzer warnings
- [ ] Ensure consistent indentation

### Performance
- [ ] Profile module loading time
- [ ] Optimize menu rendering
- [ ] Cache hardware summary data
- [ ] Review and optimize update check logic

### Documentation
- [ ] Update STRUCTURE.md with new module organization
- [ ] Update README.md with refactoring notes
- [ ] Document module architecture
- [ ] Create module dependency diagram
- [ ] Update FEATURES.md if needed

## Future Considerations

### Architecture Improvements
- [ ] Consider creating a Config.psm1 for configuration management
- [ ] Consider creating an Update.psm1 specifically for update logic
- [ ] Evaluate if FunctionModuleMap should be auto-generated
- [ ] Consider lazy loading for modules to improve startup time

### Feature Additions
- [ ] Add module version checking
- [ ] Add module dependency validation
- [ ] Add module auto-repair functionality
- [ ] Add telemetry for module load failures (opt-in)

### Build Process
- [ ] Update build_exe.ps1 to include new modules
- [ ] Test EXE build with refactored code
- [ ] Verify embedded modules work correctly
- [ ] Update CI/CD pipeline if needed

## Notes

### Refactoring Guidelines
1. Move one module at a time
2. Test after each move
3. Keep git commits small and focused
4. Maintain backward compatibility
5. Document breaking changes
6. Update version number after major refactoring

### Testing Checklist
- [ ] Interactive menu works
- [ ] All menu options function correctly
- [ ] Direct run mode works (-RunOption)
- [ ] Help system works (-Help and ? in menu)
- [ ] Module loading works (local and download)
- [ ] Update system works
- [ ] Logging works
- [ ] Console sizing works
- [ ] Hardware detection works
- [ ] EXE build works

### Dependencies to Verify
- Menu.psm1 depends on: Core, Logging, Utilities
- Core.psm1 depends on: Logging
- All modules depend on: PowerShell 5.1+
- Main script depends on: All modules

---

**Last Updated:** 2025-01-24
**Status:** Refactoring in progress
**Target Completion:** TBD
