<#
.SYNOPSIS
    System Optimizer Version Manager
.DESCRIPTION
    Manages versioning across all modules and the main script.
    - Tracks individual module versions
    - Manages top-level version
    - Updates CHANGELOG.md
    - Creates git tags
    - Validates version consistency
.EXAMPLE
    .\version_manager.ps1 -Action Report
    .\version_manager.ps1 -Action BumpModule -Module Services -Type Patch
    .\version_manager.ps1 -Action BumpAll -Type Minor
    .\version_manager.ps1 -Action Release -Version "2.2.0" -Message "New features"
#>

param(
    [ValidateSet('Report', 'BumpModule', 'BumpAll', 'Release', 'Validate', 'Sync', 'Changelog')]
    [string]$Action = 'Report',
    
    [string]$Module,
    
    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$Type = 'Patch',
    
    [string]$Version,
    [string]$Message,
    [switch]$NoGit,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$ModulesPath = Join-Path $ScriptRoot "modules"
$MainScript = Join-Path $ScriptRoot "Start-SystemOptimizer.ps1"
$ChangelogPath = Join-Path $ScriptRoot "CHANGELOG.md"
$VersionFile = Join-Path $ScriptRoot "configs\VERSION.json"

# ============================================================================
# VERSION DATA STRUCTURE
# ============================================================================
function Get-VersionData {
    if (Test-Path $VersionFile) {
        return Get-Content $VersionFile -Raw | ConvertFrom-Json
    }
    
    # Initialize version data with PSCustomObject for Modules
    return [PSCustomObject]@{
        Version = "2.1.0"
        LastUpdated = (Get-Date -Format "o")
        Modules = [PSCustomObject]@{}
    }
}

function Save-VersionData {
    param($Data)
    $Data.LastUpdated = Get-Date -Format "o"
    $Data | ConvertTo-Json -Depth 5 | Set-Content $VersionFile -Encoding UTF8
}

# ============================================================================
# VERSION PARSING
# ============================================================================
function Parse-Version {
    param([string]$Ver)
    if ($Ver -match '^(\d+)\.(\d+)\.(\d+)$') {
        return @{
            Major = [int]$matches[1]
            Minor = [int]$matches[2]
            Patch = [int]$matches[3]
            String = $Ver
        }
    }
    return $null
}

function Bump-Version {
    param(
        [string]$CurrentVersion,
        [string]$BumpType
    )
    
    $v = Parse-Version $CurrentVersion
    if (-not $v) { $v = @{ Major = 1; Minor = 0; Patch = 0 } }
    
    switch ($BumpType) {
        'Major' { $v.Major++; $v.Minor = 0; $v.Patch = 0 }
        'Minor' { $v.Minor++; $v.Patch = 0 }
        'Patch' { $v.Patch++ }
    }
    
    return "$($v.Major).$($v.Minor).$($v.Patch)"
}

# ============================================================================
# MODULE VERSION EXTRACTION
# ============================================================================
function Get-ModuleVersion {
    param([string]$ModulePath)
    
    $content = Get-Content $ModulePath -Raw -ErrorAction SilentlyContinue
    
    # Look for version patterns
    if ($content -match '#\s*Version:\s*(\d+\.\d+\.\d+)') {
        return $matches[1]
    }
    if ($content -match '\$ModuleVersion\s*=\s*[''"](\d+\.\d+\.\d+)[''"]') {
        return $matches[1]
    }
    
    return "1.0.0"  # Default
}

function Set-ModuleVersion {
    param(
        [string]$ModulePath,
        [string]$NewVersion
    )
    
    $content = Get-Content $ModulePath -Raw
    
    # Update or add version header
    if ($content -match '#\s*Version:\s*\d+\.\d+\.\d+') {
        $content = $content -replace '#\s*Version:\s*\d+\.\d+\.\d+', "# Version: $NewVersion"
    } else {
        # Add version after the module header
        $headerPattern = '# ={10,}\r?\n# .+ Module'
        if ($content -match $headerPattern) {
            $content = $content -replace "($headerPattern[^\n]*\n# ={10,})", "`$1`n# Version: $NewVersion"
        }
    }
    
    Set-Content $ModulePath -Value $content -Encoding UTF8 -NoNewline
    return $true
}

function Get-MainScriptVersion {
    $content = Get-Content $MainScript -Raw
    if ($content -match 'Version\s*=\s*"(\d+\.\d+\.\d+)"') {
        return $matches[1]
    }
    return "1.0.0"
}

function Set-MainScriptVersion {
    param([string]$NewVersion)
    
    $content = Get-Content $MainScript -Raw
    $content = $content -replace 'Version\s*=\s*"\d+\.\d+\.\d+"', "Version = `"$NewVersion`""
    Set-Content $MainScript -Value $content -Encoding UTF8 -NoNewline
}


# ============================================================================
# CHANGELOG MANAGEMENT
# ============================================================================
function Get-ChangelogEntry {
    param(
        [string]$Ver,
        [string]$Msg,
        [string[]]$Changes
    )
    
    $date = Get-Date -Format "yyyy-MM-dd"
    $entry = @"

## [$Ver] - $date

$Msg

"@
    
    if ($Changes -and $Changes.Count -gt 0) {
        $entry += "### Changes`n"
        foreach ($change in $Changes) {
            $entry += "- $change`n"
        }
    }
    
    return $entry
}

function Add-ChangelogEntry {
    param(
        [string]$Ver,
        [string]$Msg,
        [string[]]$Changes
    )
    
    $entry = Get-ChangelogEntry -Ver $Ver -Msg $Msg -Changes $Changes
    
    if (Test-Path $ChangelogPath) {
        $content = Get-Content $ChangelogPath -Raw
        # Insert after the header
        if ($content -match '(# Changelog\r?\n)') {
            $content = $content -replace '(# Changelog\r?\n)', "`$1$entry"
        } else {
            $content = "# Changelog`n$entry`n$content"
        }
        Set-Content $ChangelogPath -Value $content -Encoding UTF8
    } else {
        "# Changelog`n$entry" | Set-Content $ChangelogPath -Encoding UTF8
    }
}

# ============================================================================
# GIT OPERATIONS
# ============================================================================
function New-GitTag {
    param(
        [string]$Ver,
        [string]$Msg
    )
    
    if ($NoGit) { return }
    
    try {
        # Check if tag exists
        $existingTag = git tag -l "v$Ver" 2>$null
        if ($existingTag) {
            if ($Force) {
                git tag -d "v$Ver" 2>$null
                git push origin --delete "v$Ver" 2>$null
            } else {
                Write-Host "Tag v$Ver already exists. Use -Force to overwrite." -ForegroundColor Yellow
                return
            }
        }
        
        git add -A
        git commit -m "Release v$Ver - $Msg" 2>$null
        git tag -a "v$Ver" -m "$Msg"
        Write-Host "[+] Created tag v$Ver" -ForegroundColor Green
    } catch {
        Write-Host "[-] Git operation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Push-GitChanges {
    if ($NoGit) { return }
    
    try {
        git push origin main --tags
        Write-Host "[+] Pushed to origin with tags" -ForegroundColor Green
    } catch {
        Write-Host "[-] Push failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================================
# ACTIONS
# ============================================================================
function Show-VersionReport {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  SYSTEM OPTIMIZER - VERSION REPORT" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Cyan
    
    $mainVersion = Get-MainScriptVersion
    Write-Host "`n  Main Script: v$mainVersion" -ForegroundColor White
    
    $versionData = Get-VersionData
    Write-Host "  VERSION.json: v$($versionData.Version)" -ForegroundColor $(if ($versionData.Version -eq $mainVersion) { 'Green' } else { 'Red' })
    
    Write-Host "`n  Module Versions:" -ForegroundColor Gray
    Write-Host "  " + ("-" * 50)
    
    $modules = Get-ChildItem $ModulesPath -Filter "*.psm1" | Sort-Object Name
    $moduleVersions = @{}
    
    foreach ($mod in $modules) {
        $ver = Get-ModuleVersion $mod.FullName
        $moduleVersions[$mod.BaseName] = $ver
        
        $storedVer = $versionData.Modules.($mod.BaseName)
        $match = if ($storedVer -eq $ver) { "[OK]" } else { "[MISMATCH]" }
        $color = if ($storedVer -eq $ver) { 'Green' } else { 'Yellow' }
        
        Write-Host "  $($mod.BaseName.PadRight(20)) v$ver " -NoNewline
        Write-Host $match -ForegroundColor $color
    }
    
    Write-Host "`n  Total Modules: $($modules.Count)"
    
    # Git info
    Write-Host "`n  Git Status:" -ForegroundColor Gray
    try {
        $branch = git branch --show-current 2>$null
        $lastTag = git describe --tags --abbrev=0 2>$null
        $commits = git rev-list --count HEAD 2>$null
        Write-Host "    Branch: $branch"
        Write-Host "    Last Tag: $lastTag"
        Write-Host "    Commits: $commits"
    } catch {
        Write-Host "    Git not available" -ForegroundColor DarkGray
    }
    
    Write-Host ""
}

function Invoke-BumpModule {
    param(
        [string]$ModuleName,
        [string]$BumpType
    )
    
    $modulePath = Join-Path $ModulesPath "$ModuleName.psm1"
    if (-not (Test-Path $modulePath)) {
        Write-Host "[-] Module not found: $ModuleName" -ForegroundColor Red
        return
    }
    
    $currentVer = Get-ModuleVersion $modulePath
    $newVer = Bump-Version $currentVer $BumpType
    
    Write-Host "[*] Bumping $ModuleName`: v$currentVer -> v$newVer" -ForegroundColor Yellow
    
    Set-ModuleVersion -ModulePath $modulePath -NewVersion $newVer
    
    # Update VERSION.json
    $versionData = Get-VersionData
    if (-not $versionData.Modules) { $versionData | Add-Member -NotePropertyName Modules -NotePropertyValue ([PSCustomObject]@{}) -Force }
    $versionData.Modules | Add-Member -NotePropertyName $ModuleName -NotePropertyValue $newVer -Force
    Save-VersionData $versionData
    
    Write-Host "[+] Module $ModuleName updated to v$newVer" -ForegroundColor Green
}

function Invoke-BumpAll {
    param([string]$BumpType)
    
    Write-Host "[*] Bumping all modules ($BumpType)..." -ForegroundColor Yellow
    
    $modules = Get-ChildItem $ModulesPath -Filter "*.psm1"
    $versionData = Get-VersionData
    if (-not $versionData.Modules) { $versionData | Add-Member -NotePropertyName Modules -NotePropertyValue ([PSCustomObject]@{}) -Force }
    
    foreach ($mod in $modules) {
        $currentVer = Get-ModuleVersion $mod.FullName
        $newVer = Bump-Version $currentVer $BumpType
        
        Set-ModuleVersion -ModulePath $mod.FullName -NewVersion $newVer
        $versionData.Modules | Add-Member -NotePropertyName $mod.BaseName -NotePropertyValue $newVer -Force
        
        Write-Host "  [+] $($mod.BaseName): v$currentVer -> v$newVer" -ForegroundColor Green
    }
    
    # Bump main version too
    $mainVer = Get-MainScriptVersion
    $newMainVer = Bump-Version $mainVer $BumpType
    Set-MainScriptVersion $newMainVer
    $versionData.Version = $newMainVer
    
    Save-VersionData $versionData
    
    Write-Host "`n[+] All versions bumped. Main: v$mainVer -> v$newMainVer" -ForegroundColor Green
}

function Invoke-Release {
    param(
        [string]$ReleaseVersion,
        [string]$ReleaseMessage
    )
    
    if (-not $ReleaseVersion) {
        # Auto-bump patch if no version specified
        $currentVer = Get-MainScriptVersion
        $ReleaseVersion = Bump-Version $currentVer 'Patch'
    }
    
    if (-not $ReleaseMessage) {
        $ReleaseMessage = "Release v$ReleaseVersion"
    }
    
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  RELEASE: v$ReleaseVersion" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
    
    # 1. Update main script version
    Write-Host "[1/5] Updating main script version..." -ForegroundColor Yellow
    Set-MainScriptVersion $ReleaseVersion
    Write-Host "  [+] Start-SystemOptimizer.ps1 -> v$ReleaseVersion" -ForegroundColor Green
    
    # 2. Update VERSION.json
    Write-Host "[2/5] Updating VERSION.json..." -ForegroundColor Yellow
    $versionData = Get-VersionData
    $versionData.Version = $ReleaseVersion
    Save-VersionData $versionData
    Write-Host "  [+] VERSION.json -> v$ReleaseVersion" -ForegroundColor Green
    
    # 3. Sync module versions to VERSION.json
    Write-Host "[3/5] Syncing module versions..." -ForegroundColor Yellow
    $modules = Get-ChildItem $ModulesPath -Filter "*.psm1"
    if (-not $versionData.Modules) { $versionData | Add-Member -NotePropertyName Modules -NotePropertyValue ([PSCustomObject]@{}) -Force }
    foreach ($mod in $modules) {
        $ver = Get-ModuleVersion $mod.FullName
        $versionData.Modules | Add-Member -NotePropertyName $mod.BaseName -NotePropertyValue $ver -Force
    }
    Save-VersionData $versionData
    Write-Host "  [+] $($modules.Count) modules synced" -ForegroundColor Green
    
    # 4. Update changelog
    Write-Host "[4/5] Updating CHANGELOG.md..." -ForegroundColor Yellow
    $changes = @()
    # Collect recent git commits if available
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
        if ($lastTag) {
            $commits = git log "$lastTag..HEAD" --oneline 2>$null
            if ($commits) {
                $changes = $commits | ForEach-Object { $_ -replace '^\w+\s+', '' } | Select-Object -First 10
            }
        }
    } catch { }
    
    Add-ChangelogEntry -Ver $ReleaseVersion -Msg $ReleaseMessage -Changes $changes
    Write-Host "  [+] Changelog updated" -ForegroundColor Green
    
    # 5. Git operations
    Write-Host "[5/5] Git operations..." -ForegroundColor Yellow
    if (-not $NoGit) {
        New-GitTag -Ver $ReleaseVersion -Msg $ReleaseMessage
        
        Write-Host ""
        Write-Host "Push to remote? (Y/N)" -ForegroundColor Yellow -NoNewline
        $response = Read-Host " "
        if ($response -match '^[Yy]') {
            Push-GitChanges
        }
    } else {
        Write-Host "  [!] Git operations skipped (-NoGit)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host "  RELEASE v$ReleaseVersion COMPLETE!" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Green
}

function Invoke-Validate {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  VERSION VALIDATION" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
    
    $issues = @()
    $versionData = Get-VersionData
    $mainVersion = Get-MainScriptVersion
    
    # Check main script vs VERSION.json
    Write-Host "[*] Checking main script version..." -ForegroundColor Yellow
    if ($versionData.Version -ne $mainVersion) {
        $issues += "Main script ($mainVersion) != VERSION.json ($($versionData.Version))"
        Write-Host "  [X] Mismatch: Script=$mainVersion, JSON=$($versionData.Version)" -ForegroundColor Red
    } else {
        Write-Host "  [OK] Main version: v$mainVersion" -ForegroundColor Green
    }
    
    # Check each module
    Write-Host "[*] Checking module versions..." -ForegroundColor Yellow
    $modules = Get-ChildItem $ModulesPath -Filter "*.psm1"
    
    foreach ($mod in $modules) {
        $fileVer = Get-ModuleVersion $mod.FullName
        $jsonVer = $versionData.Modules.($mod.BaseName)
        
        if (-not $jsonVer) {
            $issues += "$($mod.BaseName): Not in VERSION.json"
            Write-Host "  [!] $($mod.BaseName): Not tracked in VERSION.json" -ForegroundColor Yellow
        } elseif ($fileVer -ne $jsonVer) {
            $issues += "$($mod.BaseName): File=$fileVer, JSON=$jsonVer"
            Write-Host "  [X] $($mod.BaseName): File=$fileVer, JSON=$jsonVer" -ForegroundColor Red
        }
    }
    
    # Check for orphaned entries in VERSION.json
    if ($versionData.Modules) {
        $moduleNames = $modules | ForEach-Object { $_.BaseName }
        $versionData.Modules.PSObject.Properties | ForEach-Object {
            if ($_.Name -notin $moduleNames) {
                $issues += "$($_.Name): In VERSION.json but module file missing"
                Write-Host "  [!] $($_.Name): Orphaned entry (no .psm1 file)" -ForegroundColor Yellow
            }
        }
    }
    
    # Check git tag
    Write-Host "[*] Checking git tags..." -ForegroundColor Yellow
    try {
        $latestTag = git describe --tags --abbrev=0 2>$null
        if ($latestTag) {
            $tagVer = $latestTag -replace '^v', ''
            if ($tagVer -ne $mainVersion) {
                Write-Host "  [!] Latest tag ($latestTag) != current version (v$mainVersion)" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK] Tag matches: $latestTag" -ForegroundColor Green
            }
        } else {
            Write-Host "  [!] No git tags found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [!] Git not available" -ForegroundColor DarkGray
    }
    
    # Summary
    Write-Host ""
    if ($issues.Count -eq 0) {
        Write-Host "[+] All versions are consistent!" -ForegroundColor Green
    } else {
        Write-Host "[-] Found $($issues.Count) issue(s):" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "    - $issue" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Run with -Action Sync to fix mismatches" -ForegroundColor Cyan
    }
}

function Invoke-Sync {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  SYNCING VERSION DATA" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
    
    $versionData = Get-VersionData
    $mainVersion = Get-MainScriptVersion
    
    # Sync main version
    Write-Host "[*] Syncing main version..." -ForegroundColor Yellow
    $versionData.Version = $mainVersion
    Write-Host "  [+] VERSION.json set to v$mainVersion" -ForegroundColor Green
    
    # Sync all modules
    Write-Host "[*] Syncing module versions..." -ForegroundColor Yellow
    if (-not $versionData.Modules) { 
        $versionData | Add-Member -NotePropertyName Modules -NotePropertyValue ([PSCustomObject]@{}) -Force 
    }
    
    $modules = Get-ChildItem $ModulesPath -Filter "*.psm1"
    $synced = 0
    
    foreach ($mod in $modules) {
        $fileVer = Get-ModuleVersion $mod.FullName
        $versionData.Modules | Add-Member -NotePropertyName $mod.BaseName -NotePropertyValue $fileVer -Force
        Write-Host "  [+] $($mod.BaseName): v$fileVer" -ForegroundColor Green
        $synced++
    }
    
    # Remove orphaned entries
    $moduleNames = $modules | ForEach-Object { $_.BaseName }
    $toRemove = @()
    if ($versionData.Modules.PSObject.Properties) {
        $versionData.Modules.PSObject.Properties | ForEach-Object {
            if ($_.Name -notin $moduleNames) {
                $toRemove += $_.Name
            }
        }
    }
    
    foreach ($orphan in $toRemove) {
        $versionData.Modules.PSObject.Properties.Remove($orphan)
        Write-Host "  [-] Removed orphan: $orphan" -ForegroundColor Yellow
    }
    
    Save-VersionData $versionData
    
    Write-Host ""
    Write-Host "[+] Synced $synced modules to VERSION.json" -ForegroundColor Green
}

function Show-ChangelogPreview {
    param(
        [string]$Ver,
        [string]$Msg
    )
    
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  CHANGELOG PREVIEW" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Cyan
    
    if (-not $Ver) { $Ver = Get-MainScriptVersion }
    if (-not $Msg) { $Msg = "Release notes here..." }
    
    $entry = Get-ChangelogEntry -Ver $Ver -Msg $Msg -Changes @()
    Write-Host $entry -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Add this entry to CHANGELOG.md? (Y/N)" -ForegroundColor Yellow -NoNewline
    $response = Read-Host " "
    if ($response -match '^[Yy]') {
        Add-ChangelogEntry -Ver $Ver -Msg $Msg -Changes @()
        Write-Host "[+] Changelog updated" -ForegroundColor Green
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
switch ($Action) {
    'Report' {
        Show-VersionReport
    }
    'BumpModule' {
        if (-not $Module) {
            Write-Host "[-] Module name required. Use -Module <name>" -ForegroundColor Red
            Write-Host "    Available modules:" -ForegroundColor Gray
            Get-ChildItem $ModulesPath -Filter "*.psm1" | ForEach-Object { Write-Host "      $($_.BaseName)" }
            exit 1
        }
        Invoke-BumpModule -ModuleName $Module -BumpType $Type
    }
    'BumpAll' {
        Invoke-BumpAll -BumpType $Type
    }
    'Release' {
        Invoke-Release -ReleaseVersion $Version -ReleaseMessage $Message
    }
    'Validate' {
        Invoke-Validate
    }
    'Sync' {
        Invoke-Sync
    }
    'Changelog' {
        Show-ChangelogPreview -Ver $Version -Msg $Message
    }
    default {
        Show-VersionReport
    }
}
