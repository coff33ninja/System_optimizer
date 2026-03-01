<#
.SYNOPSIS
    Syncs repository version metadata from a single semantic version.
.DESCRIPTION
    Updates version.psd1 and key runtime references that should match the
    release version. Can run in check-only mode to fail when drift is found.

    Optional header stamping updates "Version: x.y.z" lines in module headers.
#>

param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    [switch]$CheckOnly,
    [switch]$StampModuleHeaders
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseTag = "v$Version"
$changedFiles = [System.Collections.Generic.List[string]]::new()

function Update-FileContent {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,
        [Parameter(Mandatory)]
        [scriptblock]$Transform
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path $path)) {
        throw "File not found: $RelativePath"
    }

    $original = Get-Content -Path $path -Raw
    $updated = & $Transform $original

    $normalizedOriginal = ($original -replace "`r`n", "`n").TrimEnd("`r", "`n")
    $normalizedUpdated = ($updated -replace "`r`n", "`n").TrimEnd("`r", "`n")

    if ($normalizedUpdated -ne $normalizedOriginal) {
        $changedFiles.Add($RelativePath) | Out-Null
        if (-not $CheckOnly) {
            Set-Content -Path $path -Value $updated -Encoding UTF8 -NoNewline
        }
    }
}

Update-FileContent -RelativePath "version.psd1" -Transform {
@"
@{
    Version = '$Version'
}
"@
}

Update-FileContent -RelativePath "Start-SystemOptimizer.ps1" -Transform {
    param($content)
    $updated = $content -replace '(?m)^\s*Version\s*=\s*"\d+\.\d+\.\d+"\s*$', "        Version = `"$Version`""
    $updated = $updated -replace '(?m)^\s*ReleaseTag\s*=\s*"v\d+\.\d+\.\d+"\s*$', "        ReleaseTag = `"$releaseTag`""
    $updated
}

Update-FileContent -RelativePath "modules\Help.psm1" -Transform {
    param($content)
    $updated = $content -replace '(?m)^\s*Version\s*=\s*"\d+\.\d+\.\d+"\s*$', "        Version = `"$Version`""
    $updated = $updated -replace '(?m)^\s*ReleaseTag\s*=\s*"v\d+\.\d+\.\d+"\s*$', "        ReleaseTag = `"$releaseTag`""
    $updated
}

$releaseInfoModules = @(
    "modules\Drivers.psm1",
    "modules\Installer.psm1",
    "modules\Privacy.psm1",
    "modules\Security.psm1",
    "modules\WindowsUpdate.psm1"
)

foreach ($modulePath in $releaseInfoModules) {
    Update-FileContent -RelativePath $modulePath -Transform {
        param($content)
        $updated = $content -replace '(?m)^\s*Version\s*=\s*"\d+\.\d+\.\d+"\s*$', "        Version = `"$Version`""
        $updated = $updated -replace '(?m)^\s*ReleaseTag\s*=\s*"v\d+\.\d+\.\d+"\s*$', "        ReleaseTag = `"$releaseTag`""
        $updated
    }
}

Update-FileContent -RelativePath "modules\Backup.psm1" -Transform {
    param($content)
    $content -replace '(?m)^\s*\$script:SystemOptimizerVersion\s*=\s*"\d+\.\d+\.\d+"\s*$', "    `$script:SystemOptimizerVersion = `"$Version`""
}

Update-FileContent -RelativePath "run_optimization.bat" -Transform {
    param($content)
    $content -replace "\$releaseTag = 'v\d+\.\d+\.\d+'", "`$releaseTag = '$releaseTag'"
}

if ($StampModuleHeaders) {
    $modulesPath = Join-Path $repoRoot "modules"
    $moduleFiles = Get-ChildItem -Path $modulesPath -Filter "*.psm1" -File
    foreach ($moduleFile in $moduleFiles) {
        $relative = "modules\$($moduleFile.Name)"
        Update-FileContent -RelativePath $relative -Transform {
            param($content)
            if ($content -match '(?m)^\s*(#\s*)?Version:\s*\d+\.\d+\.\d+\s*$') {
                return ($content -replace '(?m)^(\s*(?:#\s*)?)Version:\s*\d+\.\d+\.\d+\s*$', "`$1Version: $Version")
            }

            if ($content -match '(?s)\A(#\s*=+\s*\r?\n#.*\r?\n#\s*=+\s*\r?\n)') {
                return ($content -replace '(?s)\A(#\s*=+\s*\r?\n#.*\r?\n#\s*=+\s*\r?\n)', "`$1# Version: $Version`r`n")
            }

            return $content
        }
    }
}

if ($CheckOnly -and $changedFiles.Count -gt 0) {
    $list = ($changedFiles | Sort-Object -Unique) -join ", "
    throw "Version drift detected for $Version. Files needing sync: $list"
}

if ($changedFiles.Count -gt 0) {
    Write-Host "Updated files:" -ForegroundColor Yellow
    $changedFiles | Sort-Object -Unique | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
} else {
    Write-Host "Version metadata already in sync ($Version)." -ForegroundColor Green
}
