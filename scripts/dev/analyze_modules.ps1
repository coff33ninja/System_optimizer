#Requires -Module PSScriptAnalyzer
Import-Module PSScriptAnalyzer -ErrorAction Stop

$modules = Get-ChildItem -Path 'e:\SCRIPTS\System_optimizer\modules' -Filter '*.psm1'

foreach ($module in $modules) {
    Write-Host ""
    Write-Host "=== $($module.Name) ===" -ForegroundColor Cyan
    $issues = Invoke-ScriptAnalyzer -Path $module.FullName -Severity Warning | Where-Object {
        $_.RuleName -notlike '*WriteHost*' -and 
        $_.RuleName -notlike '*ShouldProcess*'
    }
    if ($issues) {
        $issues | Select-Object RuleName, Line, Message | Format-Table -AutoSize
    } else {
        Write-Host "No critical issues found" -ForegroundColor Green
    }
}
