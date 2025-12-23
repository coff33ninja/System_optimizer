# Test CI Validation Logic
Write-Host "Testing CI validation logic..." -ForegroundColor Cyan

# Run the AST analyzer and capture output
$output = & ./scripts/analyze_modules_ast.ps1 | Out-String

Write-Host "Checking for broken exports..." -ForegroundColor Yellow
$ciWouldFail = $false

# Check for issues in a simpler way
if ($output -like "*Fix broken exports before proceeding*") {
    Write-Host "Found broken exports warning!" -ForegroundColor Red
    $ciWouldFail = $true
}

if ($output -match "Missing references: [1-9]") {
    Write-Host "Found missing references!" -ForegroundColor Red
    $ciWouldFail = $true
}

if ($output -like "*All references found*") {
    Write-Host "All references found!" -ForegroundColor Green
}

if ($ciWouldFail) {
    Write-Host ""
    Write-Host "CI VALIDATION WOULD FAIL" -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "CI VALIDATION WOULD PASS" -ForegroundColor Green
}