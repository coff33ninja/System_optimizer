# Simple EXE builder for System Optimizer
# This script builds the EXE locally for testing

param(
    [string]$Version = "1.0.0",
    [string]$Suffix = ""  # e.g., "-dev" for dev builds
)

$exeName = "SystemOptimizer$Suffix.exe"
Write-Host "Building System Optimizer EXE ($exeName)..." -ForegroundColor Cyan

# Clean up temp files first
Write-Host "Cleaning up temp files..." -ForegroundColor Yellow
try {
    Remove-Item "$env:TEMP\SystemOptimizer" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\temp\test_exe" -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem "$env:TEMP" -Filter "*SystemOptimizer*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem "$env:TEMP" -Filter "*optimize*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem "$env:TEMP" -Filter "*.cs" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Temp files cleaned" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Some temp files couldn't be cleaned (may be in use)" -ForegroundColor Yellow
}

# Check if PS2EXE is installed
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Installing PS2EXE module..." -ForegroundColor Yellow
    Install-Module ps2exe -Force -Scope CurrentUser
}

Import-Module ps2exe

# Build the EXE with embedded modules
try {
    $inputFile = Join-Path (Split-Path $PSScriptRoot -Parent) "Start-SystemOptimizer.ps1"
    $outputFile = Join-Path (Split-Path $PSScriptRoot -Parent) $exeName
    $modulesDir = Join-Path (Split-Path $PSScriptRoot -Parent) "modules"
    
    if (-not (Test-Path $inputFile)) {
        throw "Input file not found: $inputFile"
    }
    
    if (-not (Test-Path $modulesDir)) {
        throw "Modules directory not found: $modulesDir"
    }
    
    # Create embed files hash table for all modules
    $embedFiles = @{}
    $moduleFiles = Get-ChildItem -Path $modulesDir -Filter "*.psm1"
    
    Write-Host "Found $($moduleFiles.Count) modules to embed:" -ForegroundColor Cyan
    foreach ($moduleFile in $moduleFiles) {
        $targetPath = ".\modules\$($moduleFile.Name)"
        $embedFiles[$targetPath] = $moduleFile.FullName
        Write-Host "  - $($moduleFile.Name)" -ForegroundColor Gray
    }
    
    Write-Host "`nBuilding EXE with embedded modules..." -ForegroundColor Yellow
    
    Invoke-PS2EXE `
        -InputFile $inputFile `
        -OutputFile $outputFile `
        -RequireAdmin `
        -Title "Coff33Ninja System Optimizer" `
        -Company "Coff33Ninja" `
        -Product "System Optimizer" `
        -Version $Version `
        -embedFiles $embedFiles `
        -Verbose

    if (Test-Path $outputFile) {
        Write-Host "✅ EXE built successfully: $outputFile" -ForegroundColor Green
        $size = (Get-Item $outputFile).Length / 1MB
        Write-Host "📦 Size: $([math]::Round($size, 2)) MB" -ForegroundColor Gray
        Write-Host "🚀 Run with: .\SystemOptimizer.exe" -ForegroundColor Cyan
        Write-Host "📁 Modules embedded: $($moduleFiles.Count)" -ForegroundColor Green
    } else {
        Write-Host "❌ EXE build failed!" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error building EXE: $_" -ForegroundColor Red
}