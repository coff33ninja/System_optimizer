<#
.SYNOPSIS
    Enhanced PSScriptAnalyzer script for System Optimizer code quality checks.

.DESCRIPTION
    This script provides comprehensive code analysis and auto-fix capabilities:
    - Installs PSScriptAnalyzer if not present
    - Runs analysis with multiple severity levels
    - Auto-fixes trailing whitespace
    - Generates detailed reports
    - Groups issues by rule type
    - Checks PowerShell 5.1 and 7.x compatibility

.PARAMETER Mode
    Analysis mode: Full, Quick, ErrorsOnly, AutoFix, or Compatibility

.EXAMPLE
    .\run_analysis.ps1 -Mode Full
    Runs complete analysis and generates reports

.EXAMPLE
    .\run_analysis.ps1 -Mode AutoFix
    Automatically fixes trailing whitespace issues

.EXAMPLE
    .\run_analysis.ps1 -Mode ErrorsOnly
    Shows only Error severity issues
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Full', 'Quick', 'ErrorsOnly', 'AutoFix', 'Compatibility', 'Interactive')]
    [string]$Mode = 'Interactive'
)

#Requires -Version 5.1

# Configuration
$ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
$ModulesPath = Join-Path $ProjectRoot "modules"
$ReportsPath = Join-Path $ProjectRoot "reports"
$ReportFile = Join-Path $ReportsPath "PSScriptAnalyzer_Report.txt"
$ReportMD = Join-Path $ReportsPath "PSScriptAnalyzer_Report.md"
$SummaryFile = Join-Path $ReportsPath "Analysis_Summary.txt"

# Ensure reports directory exists
if (-not (Test-Path $ReportsPath)) {
    New-Item -ItemType Directory -Path $ReportsPath -Force | Out-Null
}

# Function to check and install PSScriptAnalyzer
function Install-PSScriptAnalyzerIfNeeded {
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Host "PSScriptAnalyzer module not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -ErrorAction Stop
            Write-Host "PSScriptAnalyzer installed successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to install PSScriptAnalyzer: $_" -ForegroundColor Red
            exit 1
        }
    }
    Import-Module PSScriptAnalyzer -ErrorAction Stop
}

# Function to display interactive menu
function Show-AnalysisMenu {
    Clear-Host
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "  System Optimizer - PSScriptAnalyzer Code Quality Tool" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Full Analysis (All issues + detailed report)" -ForegroundColor White
    Write-Host "  2. Quick Analysis (Errors and Warnings only)" -ForegroundColor White
    Write-Host "  3. Errors Only (Critical issues)" -ForegroundColor White
    Write-Host "  4. Auto-Fix (Fix trailing whitespace)" -ForegroundColor Yellow
    Write-Host "  5. Compatibility Check (PS 5.1 + 7.x)" -ForegroundColor White
    Write-Host "  6. View Last Report" -ForegroundColor White
    Write-Host "  7. Group by Rule Type" -ForegroundColor White
    Write-Host "  8. Exit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host ""
    
    $choice = Read-Host "Select option (1-8)"
    return $choice
}

# Function to run full analysis
function Invoke-FullAnalysis {
    Write-Host "`nRunning full analysis on modules folder..." -ForegroundColor Cyan
    $results = Invoke-ScriptAnalyzer -Path $ModulesPath -Recurse
    
    # Save to text file
    $results | Out-File -FilePath $ReportFile -Force
    
    # Generate markdown report
    Generate-MarkdownReport -Results $results
    
    # Display summary
    Show-ResultsSummary -Results $results
    
    Write-Host "`nReports saved to:" -ForegroundColor Green
    Write-Host "  - $ReportFile" -ForegroundColor Gray
    Write-Host "  - $ReportMD" -ForegroundColor Gray
}

# Function to run quick analysis
function Invoke-QuickAnalysis {
    Write-Host "`nRunning quick analysis (Errors and Warnings only)..." -ForegroundColor Cyan
    $results = Invoke-ScriptAnalyzer -Path $ModulesPath -Recurse -Severity Error,Warning
    
    Show-ResultsSummary -Results $results
    
    if ($results.Count -gt 0) {
        Write-Host "`nTop 10 issues:" -ForegroundColor Yellow
        $results | Select-Object -First 10 | Format-Table RuleName, ScriptName, Line, Message -AutoSize
    }
}

# Function to show errors only
function Invoke-ErrorsOnlyAnalysis {
    Write-Host "`nScanning for critical errors..." -ForegroundColor Red
    $results = Invoke-ScriptAnalyzer -Path $ModulesPath -Recurse -Severity Error
    
    if ($results.Count -eq 0) {
        Write-Host "`n? No critical errors found!" -ForegroundColor Green
    }
    else {
        Write-Host "`n? Found $($results.Count) critical errors:" -ForegroundColor Red
        $results | Format-Table RuleName, ScriptName, Line, Message -AutoSize
    }
}

# Function to auto-fix issues
function Invoke-AutoFix {
    Write-Host "`nAuto-fixing trailing whitespace issues..." -ForegroundColor Yellow
    
    if ($Mode -eq 'Interactive') {
        Write-Host "This will modify files in the modules folder." -ForegroundColor Yellow
        $confirm = Read-Host "Continue? (Y/N)"
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Host "Auto-fix cancelled." -ForegroundColor Gray
            return
        }
    }

    try {
        $files = Get-ChildItem -Path $ModulesPath -Recurse -Include *.ps1, *.psm1
        $filesFixed = 0
        $filesChecked = 0
        $totalFiles = $files.Count

        Write-Host "Found $totalFiles script files to check in '$ModulesPath'..."

        foreach ($file in $files) {
            $filesChecked++
            Write-Progress -Activity "Auto-fixing trailing whitespace" `
                           -Status "Processing $($file.Name) ($filesChecked/$totalFiles)" `
                           -PercentComplete ($filesChecked / $totalFiles * 100)

            $fileContent = Get-Content -Path $file.FullName
            $needsFix = $false
            # Check if any line has trailing whitespace
            foreach ($line in $fileContent) {
                if ($line.Length -gt $line.TrimEnd().Length) {
                    $needsFix = $true
                    break
                }
            }

            if ($needsFix) {
                Write-Host "Fixing trailing whitespace in: $($file.Name)" -ForegroundColor Green
                # Trim lines and write back. Set-Content adds a final newline by default.
                $fileContent | ForEach-Object { $_.TrimEnd() } | Set-Content -Path $file.FullName -Encoding utf8
                $filesFixed++
            }
        }

        Write-Progress -Activity "Auto-fixing trailing whitespace" -Completed

        Write-Host "`n? Auto-fix completed!" -ForegroundColor Green
        if ($filesFixed -gt 0) {
            Write-Host "Processed $totalFiles files and fixed $filesFixed files with trailing whitespace." -ForegroundColor Green
        }
        else {
            Write-Host "Processed $totalFiles files. No trailing whitespace found." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error during auto-fix: $_" -ForegroundColor Red
    }
}

# Function to check compatibility
function Invoke-CompatibilityCheck {
    Write-Host "`nChecking PowerShell 5.1 and 7.x compatibility..." -ForegroundColor Cyan
    
    $settings = @{
        Rules = @{
            PSUseCompatibleSyntax = @{
                Enable = $true
                TargetVersions = @('5.1', '7.0')
            }
        }
    }
    
    $results = Invoke-ScriptAnalyzer -Path $ModulesPath -Recurse -Settings $settings
    
    if ($results.Count -eq 0) {
        Write-Host "`n? All scripts are compatible with PS 5.1 and 7.x!" -ForegroundColor Green
    }
    else {
        Write-Host "`n? Found $($results.Count) compatibility issues:" -ForegroundColor Yellow
        $results | Format-Table RuleName, ScriptName, Line, Message -AutoSize
    }
}

# Function to view last report
function Show-LastReport {
    if (Test-Path $ReportFile) {
        Write-Host "`nDisplaying last analysis report..." -ForegroundColor Cyan
        $content = Get-Content $ReportFile
        $content | Select-Object -First 50 | Out-Host
        
        if ($content.Count -gt 50) {
            Write-Host "`n... (Showing first 50 lines. Full report: $ReportFile)" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "`nNo previous report found. Run an analysis first." -ForegroundColor Yellow
    }
}

# Function to group results by rule
function Show-GroupedByRule {
    Write-Host "`nRunning analysis and grouping by rule type..." -ForegroundColor Cyan
    $results = Invoke-ScriptAnalyzer -Path $ModulesPath -Recurse
    
    $grouped = $results | Group-Object RuleName | Sort-Object Count -Descending
    
    Write-Host "`n" + "=" * 70 -ForegroundColor Cyan
    Write-Host " Issue Summary by Rule Type" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    
    $grouped | Select-Object @{Name='Count';Expression={$_.Count}}, 
                             @{Name='Rule';Expression={$_.Name}} | 
        Format-Table -AutoSize
    
    Write-Host "`nTotal Rules Violated: $($grouped.Count)" -ForegroundColor Yellow
    Write-Host "Total Issues: $($results.Count)" -ForegroundColor Yellow
}

# Function to show results summary
function Show-ResultsSummary {
    param($Results)
    
    $summary = $Results | Group-Object Severity | Select-Object Name, Count
    
    Write-Host "`n" + "=" * 70 -ForegroundColor Cyan
    Write-Host " Analysis Summary" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    
    foreach ($item in $summary) {
        $color = switch ($item.Name) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Information' { 'Gray' }
            default { 'White' }
        }
        Write-Host "  $($item.Name): $($item.Count)" -ForegroundColor $color
    }
    
    Write-Host "`n  Total Issues: $($Results.Count)" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    
    # Save summary
    $summaryText = @"
Analysis Summary - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
================================================================

$(foreach ($item in $summary) { "$($item.Name): $($item.Count)" })

Total Issues: $($Results.Count)

Top 10 Rules Violated:
$(($Results | Group-Object RuleName | Sort-Object Count -Descending | Select-Object -First 10 | 
    ForEach-Object { "  - $($_.Name): $($_.Count)" }) -join "`n")
"@
    
    $summaryText | Out-File -FilePath $SummaryFile -Force
}

# Function to generate markdown report
function Generate-MarkdownReport {
    param($Results)
    
    $grouped = $Results | Group-Object Severity
    
    $mdContent = @"
# PSScriptAnalyzer Report
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary

| Severity | Count |
|----------|-------|
$(foreach ($item in $grouped) { "| $($item.Name) | $($item.Count) |" })
| **Total** | **$($Results.Count)** |

## Issues by Rule

| Rule | Count | Severity |
|------|-------|----------|
$(($Results | Group-Object RuleName | Sort-Object Count -Descending | ForEach-Object {
    $severity = ($Results | Where-Object { $_.RuleName -eq $_.Name } | Select-Object -First 1).Severity
    "| $($_.Name) | $($_.Count) | $severity |"
}) -join "`n")

## Detailed Issues

$(foreach ($result in ($Results | Select-Object -First 100)) {
@"
### $($result.RuleName) - $($result.Severity)
- **File:** $($result.ScriptName)
- **Line:** $($result.Line)
- **Message:** $($result.Message)

"@
})

$(if ($Results.Count -gt 100) { "*Showing first 100 issues. See $ReportFile for complete list.*" })

---
*Generated by System Optimizer PSScriptAnalyzer Tool*
"@
    
    $mdContent | Out-File -FilePath $ReportMD -Force
}

# Main execution
try {
    Install-PSScriptAnalyzerIfNeeded
    
    if ($Mode -eq 'Interactive') {
        do {
            $choice = Show-AnalysisMenu
            
            switch ($choice) {
                '1' { Invoke-FullAnalysis }
                '2' { Invoke-QuickAnalysis }
                '3' { Invoke-ErrorsOnlyAnalysis }
                '4' { Invoke-AutoFix }
                '5' { Invoke-CompatibilityCheck }
                '6' { Show-LastReport }
                '7' { Show-GroupedByRule }
                '8' { Write-Host "`nExiting..." -ForegroundColor Gray; break }
                default { Write-Host "`nInvalid choice. Please select 1-8." -ForegroundColor Red }
            }
            
            if ($choice -ne '8') {
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
        } while ($choice -ne '8')
    }
    else {
        # Non-interactive mode
        switch ($Mode) {
            'Full' { Invoke-FullAnalysis }
            'Quick' { Invoke-QuickAnalysis }
            'ErrorsOnly' { Invoke-ErrorsOnlyAnalysis }
            'AutoFix' { Invoke-AutoFix }
            'Compatibility' { Invoke-CompatibilityCheck }
        }
    }
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
    exit 1
}
