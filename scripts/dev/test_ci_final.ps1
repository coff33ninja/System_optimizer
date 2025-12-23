# Test Final CI Logic
Write-Host "Testing final CI validation logic..." -ForegroundColor Cyan

# Run the AST analyzer and capture both output and exit code
$output = & ./scripts/analyze_modules_ast.ps1 2>&1
$exitCode = $LASTEXITCODE

# Display the output
$output | ForEach-Object { Write-Host $_ }

# Check for broken exports in output
$outputString = $output -join "`n"
$hasBrokenExports = $outputString -like "*Fix broken exports before proceeding*"
$hasMissingRefs = $outputString -like "*Missing references: [1-9]*"

Write-Host ""
Write-Host "=== CI VALIDATION RESULTS ===" -ForegroundColor Cyan
Write-Host "Has broken exports: $hasBrokenExports" -ForegroundColor $(if ($hasBrokenExports) { 'Red' } else { 'Green' })
Write-Host "Has missing refs: $hasMissingRefs" -ForegroundColor $(if ($hasMissingRefs) { 'Red' } else { 'Green' })

if ($hasBrokenExports) {
  Write-Host "CI would FAIL: Broken exports found!" -ForegroundColor Red
  exit 1
}

if ($hasMissingRefs) {
  Write-Host "CI would FAIL: Missing function references found!" -ForegroundColor Red
  exit 1
}

Write-Host "CI would PASS: Module validation successful!" -ForegroundColor Green