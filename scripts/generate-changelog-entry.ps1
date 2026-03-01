<#
.SYNOPSIS
    Generates a changelog entry for a semantic version from recent commits.
.DESCRIPTION
    Adds a new section to CHANGELOG.md when the target version section does not
    already exist. Commit subjects are collected from git history since the
    latest version tag and used as change bullets.
#>

param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [string]$ChangelogPath = "CHANGELOG.md",

    [int]$MaxChanges = 20
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ChangelogPath)) {
    throw "Changelog file not found: $ChangelogPath"
}

$content = Get-Content -Path $ChangelogPath -Raw
$escapedVersion = [regex]::Escape($Version)

if ($content -match "(?m)^## \[$escapedVersion\]") {
    Write-Host "CHANGELOG already contains section [$Version]." -ForegroundColor Green
    exit 0
}

$latestTag = (git tag --list "v*.*.*" --sort=-creatordate | Select-Object -First 1)

$commitSubjects = @()
if (-not [string]::IsNullOrWhiteSpace($latestTag)) {
    $range = "$latestTag..HEAD"
    $commitSubjects = git log $range --no-merges --pretty=format:%s
} else {
    $commitSubjects = git log --no-merges --pretty=format:%s -n $MaxChanges
}

$filtered = @()
foreach ($subject in $commitSubjects) {
    if ([string]::IsNullOrWhiteSpace($subject)) { continue }
    if ($subject -match '^\s*chore\(release\):\s*sync version metadata') { continue }
    if ($subject -match '^\s*docs\(changelog\):\s*') { continue }
    $filtered += $subject.Trim()
}

$uniqueChanges = $filtered | Select-Object -Unique | Select-Object -First $MaxChanges
if (-not $uniqueChanges -or $uniqueChanges.Count -eq 0) {
    $uniqueChanges = @("Release metadata and maintenance updates.")
}

$date = Get-Date -Format "yyyy-MM-dd"
$bulletLines = $uniqueChanges | ForEach-Object { "- $_" }

$entryLines = @(
    "## [$Version] - $date",
    "",
    "### Changes"
) + $bulletLines + @("")

$entry = $entryLines -join "`r`n"

$firstSection = [regex]::Match($content, '(?m)^## \[')
if ($firstSection.Success) {
    $updated = $content.Insert($firstSection.Index, "$entry`r`n")
} else {
    if ($content -notmatch "(\r?\n)$") {
        $content += "`r`n"
    }
    $updated = "$content`r`n$entry`r`n"
}

Set-Content -Path $ChangelogPath -Value $updated -Encoding UTF8 -NoNewline
Write-Host "Added changelog section [$Version] using recent commits." -ForegroundColor Yellow

