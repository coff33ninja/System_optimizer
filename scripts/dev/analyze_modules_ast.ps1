# AST-Based Module Analysis
# Uses PowerShell AST for accurate function analysis (no regex lies)

param(
    [string]$ModuleFilter = "*",
    [switch]$ShowDetails,
    [switch]$ExportReport
)

# Enable UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== AST-Based Module Analysis ===" -ForegroundColor Cyan
Write-Host ""

function Get-ModuleAnalysis {
    param([string]$ModulePath)
    
    $content = Get-Content $ModulePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }
    
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
    
    # Get defined functions
    $definedFunctions = $ast.FindAll({
        param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | ForEach-Object { $_.Name }
    
    # Get exported functions - fixed parsing for CommandParameterAst
    $exportedFunctions = @()
    $exportCommands = $ast.FindAll({
        param($n) 
        $n -is [System.Management.Automation.Language.CommandAst] -and 
        $n.GetCommandName() -eq 'Export-ModuleMember'
    }, $true)
    
    foreach ($exportCmd in $exportCommands) {
        # Look for -Function parameter (can be CommandParameterAst or StringConstantExpressionAst)
        for ($i = 0; $i -lt $exportCmd.CommandElements.Count; $i++) {
            $elem = $exportCmd.CommandElements[$i]
            $isFunctionParam = $false
            
            if ($elem -is [System.Management.Automation.Language.CommandParameterAst] -and $elem.ParameterName -eq 'Function') {
                $isFunctionParam = $true
            } elseif ($elem -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $elem.Value -eq '-Function') {
                $isFunctionParam = $true
            }
            
            if ($isFunctionParam -and $i + 1 -lt $exportCmd.CommandElements.Count) {
                $functionParam = $exportCmd.CommandElements[$i + 1]
                
                # Handle array expression @('func1', 'func2')
                if ($functionParam -is [System.Management.Automation.Language.ArrayExpressionAst]) {
                    if ($functionParam.SubExpression -is [System.Management.Automation.Language.StatementBlockAst]) {
                        foreach ($statement in $functionParam.SubExpression.Statements) {
                            if ($statement -is [System.Management.Automation.Language.PipelineAst]) {
                                foreach ($element in $statement.PipelineElements) {
                                    if ($element -is [System.Management.Automation.Language.CommandExpressionAst]) {
                                        $expr = $element.Expression
                                        if ($expr -is [System.Management.Automation.Language.ArrayLiteralAst]) {
                                            foreach ($arrayElement in $expr.Elements) {
                                                if ($arrayElement -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                                                    $exportedFunctions += $arrayElement.Value
                                                }
                                            }
                                        } elseif ($expr -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                                            $exportedFunctions += $expr.Value
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        # Fallback for simpler array structures
                        foreach ($element in $functionParam.SubExpression.Elements) {
                            if ($element -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                                $exportedFunctions += $element.Value
                            }
                        }
                    }
                }
                # Handle simple string 'func1'
                elseif ($functionParam -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    $exportedFunctions += $functionParam.Value
                }
                break
            }
        }
    }
    
    # Get function calls
    $functionCalls = $ast.FindAll({
        param($n) $n -is [System.Management.Automation.Language.CommandAst]
    }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { 
        $_ -and $_ -notmatch '^(Get|Set|New|Remove|Test|Write|Start|Stop|Import|Export|Add|Clear|Copy|Move|Join|Split|Select|Where|ForEach|Sort|Group|Measure)-'
    } | Sort-Object -Unique
    
    return @{
        Defined = $definedFunctions
        Exported = $exportedFunctions
        Called = $functionCalls
        ExportedNotDefined = $exportedFunctions | Where-Object { $_ -notin $definedFunctions }
        DefinedNotExported = $definedFunctions | Where-Object { $_ -notin $exportedFunctions }
    }
}

# Analyze all modules
$moduleFiles = Get-ChildItem -Path ".\modules" -Filter "*.psm1" | Where-Object { $_.Name -like $ModuleFilter }
$allAnalysis = @{}
$allExported = @()

foreach ($module in $moduleFiles) {
    $moduleName = $module.BaseName
    Write-Host "Analyzing $moduleName..." -ForegroundColor Yellow
    
    $analysis = Get-ModuleAnalysis -ModulePath $module.FullName
    if ($analysis) {
        $allAnalysis[$moduleName] = $analysis
        $allExported += $analysis.Exported
    }
}

Write-Host ""
Write-Host "=== RESULTS ===" -ForegroundColor Cyan
Write-Host ""

# Check for broken exports
Write-Host "BROKEN EXPORTS (Exported but not defined):" -ForegroundColor Red
$totalBroken = 0
foreach ($moduleName in ($allAnalysis.Keys | Sort-Object)) {
    $broken = $allAnalysis[$moduleName].ExportedNotDefined
    if ($broken.Count -gt 0) {
        $totalBroken += $broken.Count
        Write-Host "  ${moduleName}:" -ForegroundColor Yellow
        foreach ($func in $broken) {
            Write-Host "    - $func [MISSING DEFINITION]" -ForegroundColor Red
        }
    }
}
if ($totalBroken -eq 0) {
    Write-Host "  ✅ No broken exports found!" -ForegroundColor Green
}
Write-Host ""

# Check main script references
Write-Host "MAIN SCRIPT ANALYSIS:" -ForegroundColor Green
$mainContent = Get-Content ".\Start-SystemOptimizer.ps1" -Raw -ErrorAction SilentlyContinue
if ($mainContent) {
    $mainAst = [System.Management.Automation.Language.Parser]::ParseInput($mainContent, [ref]$null, [ref]$null)
    
    # Find Invoke-OptFunction calls
    $invokeMatches = [regex]::Matches($mainContent, "Invoke-OptFunction\s+[`"']([^`"']+)[`"']")
    $mainReferences = @()
    foreach ($match in $invokeMatches) {
        $mainReferences += $match.Groups[1].Value
    }
    
    $missingRefs = @()
    foreach ($ref in $mainReferences) {
        if ($ref -notin $allExported) {
            $missingRefs += $ref
        }
    }
    
    Write-Host "  Total function references: $($mainReferences.Count)"
    Write-Host "  Missing references: $($missingRefs.Count)"
    
    if ($missingRefs.Count -gt 0) {
        Write-Host "  Missing functions:" -ForegroundColor Red
        foreach ($func in ($missingRefs | Sort-Object)) {
            Write-Host "    - $func [NOT EXPORTED BY ANY MODULE]" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✅ All references found!" -ForegroundColor Green
    }
}
Write-Host ""

# Summary by module
if ($ShowDetails) {
    Write-Host "DETAILED MODULE ANALYSIS:" -ForegroundColor Green
    Write-Host ""
    
    foreach ($moduleName in ($allAnalysis.Keys | Sort-Object)) {
        $analysis = $allAnalysis[$moduleName]
        Write-Host "  $moduleName" -ForegroundColor Cyan
        Write-Host "    Defined: $($analysis.Defined.Count) functions"
        Write-Host "    Exported: $($analysis.Exported.Count) functions"
        Write-Host "    Called: $($analysis.Called.Count) unique function calls"
        
        if ($analysis.DefinedNotExported.Count -gt 0) {
            Write-Host "    Unexported: $($analysis.DefinedNotExported.Count) functions" -ForegroundColor Yellow
            if ($analysis.DefinedNotExported.Count -le 5) {
                foreach ($func in $analysis.DefinedNotExported) {
                    Write-Host "      - $func" -ForegroundColor Yellow
                }
            } else {
                Write-Host "      - $($analysis.DefinedNotExported[0..4] -join ', ')..." -ForegroundColor Yellow
            }
        }
        Write-Host ""
    }
}

# Final summary
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
$totalModules = $allAnalysis.Count
$totalExported = ($allAnalysis.Values | ForEach-Object { $_.Exported.Count } | Measure-Object -Sum).Sum
$totalDefined = ($allAnalysis.Values | ForEach-Object { $_.Defined.Count } | Measure-Object -Sum).Sum
$totalBrokenExports = ($allAnalysis.Values | ForEach-Object { $_.ExportedNotDefined.Count } | Measure-Object -Sum).Sum

Write-Host "Modules analyzed: $totalModules"
Write-Host "Functions defined: $totalDefined"
Write-Host "Functions exported: $totalExported"
Write-Host "Broken exports: $totalBrokenExports" -ForegroundColor $(if ($totalBrokenExports -eq 0) { 'Green' } else { 'Red' })

if ($totalBrokenExports -eq 0) {
    Write-Host "✅ Module system is healthy!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Fix broken exports before proceeding" -ForegroundColor Yellow
}