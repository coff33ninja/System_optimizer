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

function Show-ComprehensiveHelp {
    <#
    .SYNOPSIS
        Displays comprehensive help with all usage information
    .DESCRIPTION
        Shows detailed help including all command-line options, examples,
        menu navigation, requirements, and support information.
    #>
    [CmdletBinding()]
    param(
        [string]$Version = "1.0.0"
    )
    
    Write-Host @"

SYSTEM OPTIMIZER v$Version
================================

USAGE:
  .\Start-SystemOptimizer.ps1 [OPTIONS]
  .\SystemOptimizer.exe [OPTIONS]

BASIC OPTIONS:
  -Help              Show this comprehensive help message
  -SkipModuleLoad    Start without loading modules (limited functionality)
  -RunOption <opt>   Run specific optimization and exit (see options below)

RUN OPTIONS (-RunOption):
  Core Optimizations:
    all                Run ALL optimizations (telemetry, services, bloatware, etc.)
    telemetry          Disable telemetry, data collection, ads, feedback, Cortana
    services           Disable unnecessary Windows services (interactive menu)
    bloatware          Remove pre-installed apps (Xbox, Mail, Weather, etc.)
    tasks              Disable scheduled maintenance tasks
    registry           Apply registry performance tweaks and SSD optimizations
    vbs                Disable VBS/Memory Integrity (improves gaming performance)
    network            Optimize TCP/IP, DNS, and network adapter settings
    onedrive           Completely remove OneDrive cloud storage
    maintenance        Run system maintenance (DISM, SFC, temp cleanup)

  Software & Tools:
    software           Launch PatchMyPC for software installation/updates
    office             Launch Office Tool Plus for Microsoft Office installation
    activation         Run Microsoft Activation Script (MAS) for Windows/Office
    drivers            Launch Snappy Driver Installer for driver management
    
  Advanced Operations:
    power              Set power plan (High Performance, Ultimate, Balanced)
    shutup10           Launch O&O ShutUp10 privacy tool
    reset-gpo          Reset Group Policy to defaults
    reset-wmi          Repair Windows Management Instrumentation
    cleanup            Run advanced disk cleanup
    updates            Control Windows Update settings
    reset-network      Reset all network settings to defaults
    repair-updates     Repair broken Windows Update components
    defender           Manage Windows Defender settings
    debloat-all        Remove ALL pre-installed apps (aggressive)
    winutil-services   Apply ChrisTitusTech WinUtil service configurations
    privacy            Advanced privacy tweaks and data collection controls
    
  Utilities:
    wifi               Extract saved Wi-Fi passwords
    verify             Check current optimization status
    logs               View operation logs and history
    backup             User profile backup/restore menu
    shutdown           Shutdown/restart options menu
    rollback           Undo previous optimizations
    hardware           Hardware detection and analysis
    profiles           Optimization profiles (Gaming, Developer, Office)
    
  Deployment Tools:
    vhd                VHD Native Boot creation menu
    installer          Windows deployment to blank drives
    image-tool         Windows image modification and ISO creation

EXAMPLES:
  Interactive Menu:
    .\Start-SystemOptimizer.ps1
    .\SystemOptimizer.exe

  Quick Optimizations:
    .\Start-SystemOptimizer.ps1 -RunOption all
    .\Start-SystemOptimizer.ps1 -RunOption telemetry
    .\Start-SystemOptimizer.ps1 -RunOption bloatware

  Specific Tools:
    .\Start-SystemOptimizer.ps1 -RunOption software
    .\Start-SystemOptimizer.ps1 -RunOption office
    .\Start-SystemOptimizer.ps1 -RunOption activation

  System Maintenance:
    .\Start-SystemOptimizer.ps1 -RunOption maintenance
    .\Start-SystemOptimizer.ps1 -RunOption cleanup
    .\Start-SystemOptimizer.ps1 -RunOption repair-updates

  Advanced Operations:
    .\Start-SystemOptimizer.ps1 -RunOption debloat-all
    .\Start-SystemOptimizer.ps1 -RunOption reset-network
    .\Start-SystemOptimizer.ps1 -RunOption privacy

MENU NAVIGATION:
  When running interactively, use these menu numbers:
  
  Quick Actions:
    [1]  Run ALL Optimizations    [16] Full Setup Workflow
    
  Core Optimizations:
    [2]  Disable Telemetry        [3]  Disable Services
    [4]  Remove Bloatware         [5]  Disable Scheduled Tasks
    [6]  Registry Optimizations   [7]  Disable VBS/Memory Integrity
    [8]  Network Tools            [9]  Remove OneDrive
    [10] Maintenance Tools
    
  Software & Activation:
    [11] Software Installation    [12] Office Tool Plus
    [13] Microsoft Activation
    
  Advanced Tools:
    [17] Power Plan              [18] O&O ShutUp10
    [19] Windows Update Control  [20] Driver Management
    [21] Repair Windows Update   [22] Defender Control
    [23] Full Debloat           [24] WinUtil Service Sync
    [25] Privacy Tweaks         [26] Windows Image Tool
    
  Utilities & Management:
    [14] Wi-Fi Passwords         [15] Verify Status
    [27] View Logs              [28] Profile Backup/Restore
    [29] Shutdown Options       [30] VHD Native Boot
    [31] Windows Installer      [32] Undo/Rollback Center
    [33] Hardware Detection     [34] Optimization Profiles

FIRST TIME SETUP:
  1. Ensure you're running as Administrator
  2. Run: .\Start-SystemOptimizer.ps1 (starts interactive menu)
  
  OR use the standalone EXE:
  1. Download SystemOptimizer.exe
  2. Run as Administrator
  3. All modules are embedded - no setup required

REQUIREMENTS:
  - Windows 10/11 (some features work on Windows 7/8.1)
  - PowerShell 5.1+ (PowerShell 7+ recommended)
  - Administrator privileges
  - Internet connection (for downloads and updates)

LOGGING:
  All operations are logged to: C:\System_Optimizer\Logs\
  Logs include timestamps, operation details, and error information
  Old logs are automatically cleaned up after 30 days

SAFETY FEATURES:
  - Automatic system restore point creation (optional)
  - Rollback system to undo changes
  - Service backup before modifications
  - Registry backup before tweaks
  - Comprehensive logging for troubleshooting

SUPPORT:
  - GitHub: https://github.com/coff33ninja/System_optimizer
  - Issues: Report bugs and feature requests on GitHub
  - Documentation: README.md and wiki on GitHub repository

"@
}

# Export functions
Export-ModuleMember -Function Show-MenuHelp, Get-MenuItemDescription, Initialize-HelpCache, Show-ComprehensiveHelp
