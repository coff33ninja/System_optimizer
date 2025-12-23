<#
.SYNOPSIS
    Interactive PSScriptAnalyzer issue fixer - Easy to Hard
.DESCRIPTION
    Filters and fixes PSScriptAnalyzer issues by difficulty level.
    Starts with auto-fixable issues, then progresses to manual fixes.
#>

param(
    [ValidateSet('Auto', 'Easy', 'Medium', 'Hard', 'All', 'Report')]
    [string]$Level = 'Report'
)

$ErrorActionPreference = 'SilentlyContinue'
$ModulesPath = Join-Path $PSScriptRoot "..\modules"

# Issue categories by difficulty
$Categories = @{
    # AUTO-FIXABLE (run with -Fix)
    Auto = @(
        'PSAvoidTrailingWhitespace'
    )
    
    # EASY - Simple find/replace or one-line fixes
    Easy = @(
        'PSAvoidUsingCmdletAliases',      # iex -> Invoke-Expression
        'PSAvoidUsingPositionalParameters' # Add parameter names
    )
    
    # MEDIUM - Requires understanding context
    Medium = @(
        'PSUseDeclaredVarsMoreThanAssignments',  # Unused variables
        'PSAvoidUsingEmptyCatchBlock',           # Add error handling
        'PSAvoidUsingWMICmdlet',                 # Get-WmiObject -> Get-CimInstance
        'PSReviewUnusedParameter'                # Unused function parameters
    )
    
    # HARD - Requires refactoring or design decisions
    Hard = @(
        'PSUseShouldProcessForStateChangingFunctions',  # Add -WhatIf support
        'PSUseSingularNouns',                           # Rename functions
        'PSUseApprovedVerbs',                           # Rename functions
        'PSUseOutputTypeCorrectly',                     # Add [OutputType()]
        'PSAvoidUsingInvokeExpression',                 # Security refactor
        'PSAvoidOverwritingBuiltInCmdlets',             # Rename functions
        'PSUseSupportsShouldProcess'                    # Add CmdletBinding
    )
    
    # IGNORE - Intentional or low priority
    Ignore = @(
        'PSAvoidUsingWriteHost',    # Intentional for console UI
        'PSProvideCommentHelp'      # Documentation, low priority
    )
}

function Get-FilteredIssues {
    param([string[]]$Rules)
    
    $allIssues = Invoke-ScriptAnalyzer -Path $ModulesPath -Recurse
    if ($Rules) {
        $allIssues | Where-Object { $_.RuleName -in $Rules }
    } else {
        $allIssues
    }
}

function Show-IssueReport {
    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "  PSScriptAnalyzer Issue Report - By Difficulty" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Cyan
    
    $all = Invoke-ScriptAnalyzer -Path $ModulesPath -Recurse
    
    Write-Host "`n[AUTO-FIXABLE] Run with -Level Auto" -ForegroundColor Green
    $auto = $all | Where-Object { $_.RuleName -in $Categories.Auto }
    $auto | Group-Object RuleName | ForEach-Object { "  $($_.Count) - $($_.Name)" }
    
    Write-Host "`n[EASY] Simple replacements" -ForegroundColor Green
    $easy = $all | Where-Object { $_.RuleName -in $Categories.Easy }
    $easy | Group-Object RuleName | ForEach-Object { "  $($_.Count) - $($_.Name)" }
    
    Write-Host "`n[MEDIUM] Requires context understanding" -ForegroundColor Yellow
    $medium = $all | Where-Object { $_.RuleName -in $Categories.Medium }
    $medium | Group-Object RuleName | ForEach-Object { "  $($_.Count) - $($_.Name)" }
    
    Write-Host "`n[HARD] Requires refactoring" -ForegroundColor Red
    $hard = $all | Where-Object { $_.RuleName -in $Categories.Hard }
    $hard | Group-Object RuleName | ForEach-Object { "  $($_.Count) - $($_.Name)" }
    
    Write-Host "`n[IGNORED] Intentional/Low priority" -ForegroundColor DarkGray
    $ignored = $all | Where-Object { $_.RuleName -in $Categories.Ignore }
    $ignored | Group-Object RuleName | ForEach-Object { "  $($_.Count) - $($_.Name)" }
    
    $total = $all.Count - $ignored.Count
    Write-Host "`n" + ("-" * 70) -ForegroundColor Gray
    Write-Host "  Total actionable: $total issues" -ForegroundColor White
    Write-Host "  Auto-fixable: $($auto.Count) | Easy: $($easy.Count) | Medium: $($medium.Count) | Hard: $($hard.Count)"
}

function Fix-AutoIssues {
    Write-Host "`n[AUTO-FIX] Fixing trailing whitespace..." -ForegroundColor Cyan
    Invoke-ScriptAnalyzer -Path $ModulesPath -Recurse -Fix
    Write-Host "[DONE] Auto-fix complete. Review changes with 'git diff'" -ForegroundColor Green
}

function Show-EasyIssues {
    Write-Host "`n[EASY ISSUES] - Simple find/replace fixes" -ForegroundColor Green
    Write-Host ("-" * 60)
    
    $issues = Get-FilteredIssues -Rules $Categories.Easy
    
    foreach ($issue in $issues) {
        $file = Split-Path $issue.ScriptPath -Leaf
        Write-Host "`n$file`:$($issue.Line)" -ForegroundColor White
        Write-Host "  Rule: $($issue.RuleName)" -ForegroundColor Yellow
        Write-Host "  $($issue.Message)" -ForegroundColor Gray
        
        # Show fix suggestion
        switch ($issue.RuleName) {
            'PSAvoidUsingCmdletAliases' {
                $alias = $issue.Message -replace ".*'([^']+)'.*", '$1'
                Write-Host "  FIX: Replace '$alias' with full cmdlet name" -ForegroundColor Cyan
            }
            'PSAvoidUsingPositionalParameters' {
                Write-Host "  FIX: Add explicit parameter names" -ForegroundColor Cyan
            }
        }
    }
    
    Write-Host "`n[Total: $($issues.Count) easy issues]" -ForegroundColor Green
}

function Show-MediumIssues {
    Write-Host "`n[MEDIUM ISSUES] - Requires context understanding" -ForegroundColor Yellow
    Write-Host ("-" * 60)
    
    $issues = Get-FilteredIssues -Rules $Categories.Medium
    $grouped = $issues | Group-Object RuleName
    
    foreach ($group in $grouped) {
        Write-Host "`n=== $($group.Name) ($($group.Count) issues) ===" -ForegroundColor Yellow
        
        foreach ($issue in ($group.Group | Select-Object -First 5)) {
            $file = Split-Path $issue.ScriptPath -Leaf
            Write-Host "  $file`:$($issue.Line) - $($issue.Message)" -ForegroundColor Gray
        }
        
        if ($group.Count -gt 5) {
            Write-Host "  ... and $($group.Count - 5) more" -ForegroundColor DarkGray
        }
        
        # Show fix guidance
        switch ($group.Name) {
            'PSUseDeclaredVarsMoreThanAssignments' {
                Write-Host "  FIX: Use the variable or pipe to Out-Null" -ForegroundColor Cyan
            }
            'PSAvoidUsingEmptyCatchBlock' {
                Write-Host "  FIX: Add error handling or comment explaining why empty" -ForegroundColor Cyan
            }
            'PSAvoidUsingWMICmdlet' {
                Write-Host "  FIX: Replace Get-WmiObject with Get-CimInstance" -ForegroundColor Cyan
            }
        }
    }
    
    Write-Host "`n[Total: $($issues.Count) medium issues]" -ForegroundColor Yellow
}

function Show-HardIssues {
    Write-Host "`n[HARD ISSUES] - Requires refactoring" -ForegroundColor Red
    Write-Host ("-" * 60)
    
    $issues = Get-FilteredIssues -Rules $Categories.Hard
    $grouped = $issues | Group-Object RuleName
    
    foreach ($group in $grouped) {
        Write-Host "`n=== $($group.Name) ($($group.Count) issues) ===" -ForegroundColor Red
        
        # Just show count per file
        $byFile = $group.Group | Group-Object { Split-Path $_.ScriptPath -Leaf }
        foreach ($f in $byFile) {
            Write-Host "  $($f.Name): $($f.Count)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n[Total: $($issues.Count) hard issues - consider prioritizing]" -ForegroundColor Red
}


# Main execution
Import-Module PSScriptAnalyzer -Force -ErrorAction Stop

switch ($Level) {
    'Report' { Show-IssueReport }
    'Auto'   { Fix-AutoIssues }
    'Easy'   { Show-EasyIssues }
    'Medium' { Show-MediumIssues }
    'Hard'   { Show-HardIssues }
    'All'    {
        Show-IssueReport
        Write-Host "`n`nPress any key for Easy issues..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Show-EasyIssues
        Write-Host "`n`nPress any key for Medium issues..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Show-MediumIssues
        Write-Host "`n`nPress any key for Hard issues..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Show-HardIssues
    }
}

Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
Write-Host "Usage:" -ForegroundColor White
Write-Host "  .\fix_analyzer_issues.ps1 -Level Report  # Show summary"
Write-Host "  .\fix_analyzer_issues.ps1 -Level Auto    # Auto-fix whitespace"
Write-Host "  .\fix_analyzer_issues.ps1 -Level Easy    # Show easy fixes"
Write-Host "  .\fix_analyzer_issues.ps1 -Level Medium  # Show medium fixes"
Write-Host "  .\fix_analyzer_issues.ps1 -Level Hard    # Show hard fixes"
Write-Host "  .\fix_analyzer_issues.ps1 -Level All     # Interactive walkthrough"
Write-Host ("=" * 70) -ForegroundColor Cyan
