#Requires -Version 5.1
<#
.SYNOPSIS
    Help Module - System Optimizer
.DESCRIPTION
    Provides dynamic help functionality by parsing FEATURES.md and displaying
    detailed descriptions for all menu items. Enables transparency by making
    feature documentation accessible directly from the UI.

Exported Functions:
    Show-MenuHelp        - Display help for all menu items
    Get-MenuItemHelp     - Get help for specific menu item
    Find-FeaturesFile    - Locate FEATURES.md locally or download
    Parse-FeaturesFile   - Parse FEATURES.md into structured data
    Show-FeatureDetails  - Display detailed feature information

Help Features:
    - Parses FEATURES.md for current descriptions
    - Downloads from GitHub if local file not found
    - Caches parsed data for performance
    - Matches menu numbers to documentation
    - Displays in formatted console output

Documentation Source:
    Local: docs/FEATURES.md
    Fallback: GitHub raw content

Integration:
    - Called from main menu [?] option
    - Provides transparency for all optimizations
    - References full documentation

Requires Admin: No

Version: 1.0.0
#>

# Cache for parsed menu data
$script:MenuCache = $null
$script:FeaturesPath = $null
$script:GitHubRawUrl = "https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/docs/FEATURES.md"

function Find-FeaturesFile {
    <#
    .SYNOPSIS
        Finds FEATURES.md locally or downloads from GitHub
    #>
    # Check local paths first
    $localPaths = @(
        (Join-Path $PSScriptRoot "..\docs\FEATURES.md"),
        (Join-Path (Get-Location) "docs\FEATURES.md"),
        (Join-Path (Get-Location) "FEATURES.md"),
        (Join-Path $PSScriptRoot "..\..\docs\FEATURES.md"),
        "C:\System_Optimizer\docs\FEATURES.md"
    )
    
    foreach ($path in $localPaths) {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
        if (Test-Path $resolved) {
            return $resolved
        }
    }
    
    # Not found locally - try to download from GitHub
    try {
        $tempDir = Join-Path $env:TEMP "SystemOptimizer"
        $tempFile = Join-Path $tempDir "FEATURES.md"
        
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        # Download FEATURES.md from GitHub
        Invoke-WebRequest -Uri $script:GitHubRawUrl -OutFile $tempFile -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        
        if (Test-Path $tempFile) {
            return $tempFile
        }
    } catch {
        # Download failed - will return null
    }
    
    return $null
}

function Initialize-HelpCache {
    <#
    .SYNOPSIS
        Parses FEATURES.md and caches menu item data
    #>
    if ($null -ne $script:MenuCache) { return }
    
    $script:MenuCache = @{}
    
    # Find or download FEATURES.md
    $script:FeaturesPath = Find-FeaturesFile
    
    if (-not $script:FeaturesPath -or -not (Test-Path $script:FeaturesPath)) {
        return
    }
    
    $content = Get-Content $script:FeaturesPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return }
    
    # Parse menu items using regex
    # Pattern matches: ### [Number] Title followed by description
    # Description continues until next ### or ## header
    $pattern = '###\s*\[(\d+)\]\s*(.+?)(?:\r?\n)+([\s\S]*?)(?=###|\r?\n##|$)'
    $regexMatches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    foreach ($match in $regexMatches) {
        $number = $match.Groups[1].Value.Trim()
        $title = $match.Groups[2].Value.Trim()
        $description = $match.Groups[3].Value.Trim()
        
        # Clean up description - remove markdown formatting
        $description = $description -replace '\*\*', ''  # Remove bold
        $description = $description -replace '\*', ''     # Remove italic
        $description = $description -replace '`', ''      # Remove code
        $description = $description -replace '\|', ' | '  # Space out tables
        $description = $description -replace '^\s*[-*]\s*', '  - '  # Standardize bullets
        $description = $description -replace '\n{3,}', "`n`n"  # Max 2 newlines
        
        $script:MenuCache[$number] = @{
            Number = $number
            Title = $title
            Description = $description
        }
    }
}

function Show-MenuHelp {
    <#
    .SYNOPSIS
        Displays help for a specific menu item or shows help menu
    .PARAMETER MenuNumber
        Specific menu number to show help for. If not specified, shows help menu.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$MenuNumber = $null
    )
    
    Initialize-HelpCache
    
    Clear-Host
    Write-Host ""
    Write-Host "  === SYSTEM OPTIMIZER HELP ===" -ForegroundColor Cyan
    Write-Host ""
    
    if ($MenuNumber -and $script:MenuCache.ContainsKey($MenuNumber)) {
        # Show specific item help
        $item = $script:MenuCache[$MenuNumber]
        
        Write-Host "  [$($item.Number)] " -ForegroundColor Cyan -NoNewline
        Write-Host "$($item.Title)" -ForegroundColor White
        Write-Host ""
        
        # Print description with word wrapping
        $lines = $item.Description -split "`n"
        foreach ($line in $lines) {
            if ($line.Trim() -eq '') {
                Write-Host ""
                continue
            }
            
            # Wrap long lines
            $maxWidth = 76
            if ($line.Length -le $maxWidth) {
                Write-Host "  $line"
            } else {
                $words = $line -split ' '
                $currentLine = "  "
                foreach ($word in $words) {
                    if (($currentLine + $word).Length -gt $maxWidth) {
                        Write-Host $currentLine
                        $currentLine = "  $word "
                    } else {
                        $currentLine += "$word "
                    }
                }
                if ($currentLine.Trim()) {
                    Write-Host $currentLine
                }
            }
        }
    } else {
        # Show help menu with all items
        if ($script:MenuCache.Count -eq 0) {
            Write-Host "  " -NoNewline
            Write-Host "[!] " -ForegroundColor Yellow -NoNewline
            Write-Host "Help documentation not available." -ForegroundColor White
            Write-Host ""
            Write-Host "  The help system requires FEATURES.md which is included with the" -ForegroundColor Gray
            Write-Host "  full download but not when running from GitHub directly." -ForegroundColor Gray
            Write-Host ""
            Write-Host "  To access help:" -ForegroundColor Gray
            Write-Host "    1. Download the full repository from GitHub" -ForegroundColor Gray
            Write-Host "    2. Or view online:" -ForegroundColor Gray
            Write-Host "       https://github.com/coff33ninja/System_Optimizer/blob/main/docs/FEATURES.md" -ForegroundColor Cyan
        } else {
            Write-Host "  Enter a menu number to view detailed description." -ForegroundColor Gray
            Write-Host ""
            
            # Display items in columns
            $items = $script:MenuCache.Values | Sort-Object { [int]$_.Number }
            $col1 = @()
            $col2 = @()
            
            $midPoint = [math]::Ceiling($items.Count / 2)
            for ($i = 0; $i -lt $items.Count; $i++) {
                if ($i -lt $midPoint) {
                    $col1 += $items[$i]
                } else {
                    $col2 += $items[$i]
                }
            }
            
            for ($i = 0; $i -lt $col1.Count; $i++) {
                $left = $col1[$i]
                $leftText = "[$($left.Number)] $($left.Title)"
                $leftPadded = $leftText.PadRight(38)
                
                Write-Host "  " -NoNewline
                Write-Host $leftPadded -ForegroundColor White -NoNewline
                
                if ($i -lt $col2.Count) {
                    $right = $col2[$i]
                    Write-Host "[$($right.Number)] $($right.Title)" -ForegroundColor White
                } else {
                    Write-Host ""
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "  ------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    
    if ($MenuNumber) {
        Write-Host "  Press any key to return..." -ForegroundColor Gray -NoNewline
        $null = [System.Console]::ReadKey($true)
    } else {
        Write-Host "  Options: " -ForegroundColor Gray -NoNewline
        Write-Host "[1-38]" -ForegroundColor Cyan -NoNewline
        Write-Host " View Item | " -ForegroundColor Gray -NoNewline
        Write-Host "[Enter]" -ForegroundColor Cyan -NoNewline
        Write-Host " Return to Menu" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Select: " -ForegroundColor White -NoNewline
        
        $choice = Read-Host
        
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le 38) {
            Show-MenuHelp -MenuNumber $choice
        }
    }
}

function Get-MenuItemDescription {
    <#
    .SYNOPSIS
        Returns a brief description for a menu item (for inline display)
    .PARAMETER MenuNumber
        The menu number to get description for
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$MenuNumber
    )
    
    Initialize-HelpCache
    
    if ($script:MenuCache.ContainsKey([string]$MenuNumber)) {
        $item = $script:MenuCache[[string]$MenuNumber]
        # Get first line or first sentence
        $desc = $item.Description -split "`n" | Select-Object -First 1
        $desc = $desc.Trim()
        if ($desc.Length -gt 50) {
            $desc = $desc.Substring(0, 47) + "..."
        }
        return $desc
    }
    
    return $null
}

# Export functions
Export-ModuleMember -Function Show-MenuHelp, Get-MenuItemDescription, Initialize-HelpCache
