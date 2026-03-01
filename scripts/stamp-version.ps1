<#
.SYNOPSIS
    Stamps module header Version lines from the canonical repository version.
.DESCRIPTION
    Updates "Version: x.y.z" (or "# Version: x.y.z") across modules/*.psm1.
    If a module has no version header, one is inserted below a top banner when detected.
#>

param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$versionPath = Join-Path $repoRoot "version.psd1"
$modulesPath = Join-Path $repoRoot "modules"

if ([string]::IsNullOrWhiteSpace($Version)) {
    if (-not (Test-Path $versionPath)) {
        throw "version.psd1 not found at repository root."
    }

    $versionData = Import-PowerShellDataFile -Path $versionPath
    if (-not $versionData.Version) {
        throw "version.psd1 is missing Version."
    }

    $Version = [string]$versionData.Version
}

if (-not (Test-Path $modulesPath)) {
    throw "Modules directory not found: $modulesPath"
}

$changed = [System.Collections.Generic.List[string]]::new()

$moduleFiles = Get-ChildItem -Path $modulesPath -Filter "*.psm1" -File
foreach ($moduleFile in $moduleFiles) {
    $path = $moduleFile.FullName
    $content = Get-Content -Path $path -Raw
    $updated = $content

    if ($updated -match '(?m)^\s*(#\s*)?Version:\s*\d+\.\d+\.\d+\s*$') {
        $updated = $updated -replace '(?m)^(\s*(?:#\s*)?)Version:\s*\d+\.\d+\.\d+\s*$', "`$1Version: $Version"
    } elseif ($updated -match '(?s)\A(#\s*=+\s*\r?\n#.*\r?\n#\s*=+\s*\r?\n)') {
        $updated = $updated -replace '(?s)\A(#\s*=+\s*\r?\n#.*\r?\n#\s*=+\s*\r?\n)', "`$1# Version: $Version`r`n"
    }

    $normalizedOriginal = ($content -replace "`r`n", "`n").TrimEnd("`r", "`n")
    $normalizedUpdated = ($updated -replace "`r`n", "`n").TrimEnd("`r", "`n")
    if ($normalizedUpdated -ne $normalizedOriginal) {
        Set-Content -Path $path -Value $updated -Encoding UTF8 -NoNewline
        $changed.Add("modules\$($moduleFile.Name)") | Out-Null
    }
}

if ($changed.Count -gt 0) {
    Write-Host "Stamped module headers to ${Version}:" -ForegroundColor Yellow
    $changed | Sort-Object | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
} else {
    Write-Host "Module headers already stamped to $Version." -ForegroundColor Green
}
