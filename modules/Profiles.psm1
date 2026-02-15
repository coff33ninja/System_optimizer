#Requires -Version 5.1
<#
.SYNOPSIS
    Profiles Module - System Optimizer
.DESCRIPTION
    Provides hardware-based optimization profiles with auto-suggestion.
    Integrates with existing modules for profile-specific optimizations.

Exported Functions:
    Show-ProfileMenu         - Interactive profile selection menu
    Get-ActiveProfile        - Get currently active profile
    Set-OptimizationProfile  - Apply optimization profile
    Get-SuggestedProfile     - Get hardware-based suggestion
    Compare-Profiles         - Compare profile settings
    Export-ProfileConfig     - Export profile to file

Available Profiles:
    Gaming          - Max performance, minimal services
    Developer       - WSL, Hyper-V, dev tools friendly
    Office          - Balanced, productivity focused
    Content Creator - Media tools, performance
    Laptop          - Battery optimization
    LowSpec         - Minimal resource usage

Profile Features:
    - Auto-suggest based on hardware detection
    - WhatIf preview mode
    - Profile comparison
    - Rollback integration
    - Custom profile creation

Integration:
    - Services module for service configurations
    - Registry module for performance tweaks
    - Hardware module for detection

Requires Admin: Yes

Version: 1.0.0
#>

# ============================================================================
# CONFIGURATION
# ============================================================================
$script:ProfilesDir = "C:\System_Optimizer\Profiles"
$script:ActiveProfileFile = "$script:ProfilesDir\active_profile.json"

# ============================================================================
# PROFILE DEFINITIONS
# ============================================================================
# Each profile defines WHICH existing module functions to call and with what parameters
$script:ProfilePresets = @{
    Gaming = @{
        Name = "Gaming"
        Description = "Maximum performance for gaming - disables background apps, prioritizes GPU"
        Icon = "[G]"
        Color = "Green"
        # Which module functions to run
        Actions = @{
            RunTelemetry = $true           # Disable-Telemetry from Telemetry.psm1
            RunServices = $true            # Disable-Services from Services.psm1
            RunBloatware = $true           # DebloatBlacklist from Bloatware.psm1
            RunBloatwareAggressive = $false
            RunRegistry = $true            # Set-RegistryOptimizations from Registry.psm1
            RunNetwork = $true             # Set-NetworkOptimizations from Network.psm1
            RunPrivacy = $true             # Protect-Privacy from Bloatware.psm1
            RemoveOneDrive = $false        # Optional - user choice
            PowerPlan = "High"             # High Performance
            DisableVBS = $true             # Disable-VBS from VBS.psm1
        }
        # Additional profile-specific registry tweaks (on top of module defaults)
        ExtraRegistry = @(
            # GPU Hardware Scheduling
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "HwSchMode"; Value = 2; Type = "DWord" }
            # Disable fullscreen optimizations globally
            @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_FSEBehaviorMode"; Value = 2; Type = "DWord" }
        )
        Requirements = @{
            MinRAM_GB = 8
            DedicatedGPU = $true
            RecommendedFor = @("Desktop with dedicated GPU", "Gaming laptop")
        }
    }

    Developer = @{
        Name = "Developer"
        Description = "Optimized for development - keeps WSL, Docker, search indexing"
        Icon = "[D]"
        Color = "Cyan"
        Actions = @{
            RunTelemetry = $true
            RunServices = $false           # Don't disable services - need many for dev
            RunBloatware = $true
            RunBloatwareAggressive = $false
            RunRegistry = $false           # Keep animations, etc.
            RunNetwork = $false            # Keep default network settings
            RunPrivacy = $true
            RemoveOneDrive = $false
            PowerPlan = "Balanced"
            DisableVBS = $false            # Keep VBS for Hyper-V/WSL2
        }
        # Developer-specific tweaks
        ExtraRegistry = @(
            # Disable Game Bar only
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Value = 0; Type = "DWord" }
            # Enable long paths
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "LongPathsEnabled"; Value = 1; Type = "DWord" }
        )
        # Services to explicitly keep enabled
        KeepServices = @('WSearch', 'SysMain', 'LxssManager', 'HvHost', 'vmcompute')
        Requirements = @{
            MinRAM_GB = 16
            DedicatedGPU = $false
            RecommendedFor = @("Development workstation", "Multi-tasking")
        }
    }

    Office = @{
        Name = "Office"
        Description = "Balanced for productivity - keeps OneDrive, minimal tweaks"
        Icon = "[O]"
        Color = "Yellow"
        Actions = @{
            RunTelemetry = $false          # Keep some telemetry for Office features
            RunServices = $false
            RunBloatware = $false          # Keep apps
            RunBloatwareAggressive = $false
            RunRegistry = $false
            RunNetwork = $false
            RunPrivacy = $false
            RemoveOneDrive = $false
            PowerPlan = "Balanced"
            DisableVBS = $false
        }
        ExtraRegistry = @(
            # Just disable Game Bar
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Value = 0; Type = "DWord" }
        )
        Requirements = @{
            MinRAM_GB = 4
            DedicatedGPU = $false
            RecommendedFor = @("Office work", "Light usage", "Business laptop")
        }
    }

    ContentCreator = @{
        Name = "Content Creator"
        Description = "Optimized for video/audio production - low latency, GPU priority"
        Icon = "[C]"
        Color = "Magenta"
        Actions = @{
            RunTelemetry = $true
            RunServices = $false           # Keep services for media apps
            RunBloatware = $true
            RunBloatwareAggressive = $false
            RunRegistry = $false           # Keep some visual effects
            RunNetwork = $true             # Network optimizations help
            RunPrivacy = $true
            RemoveOneDrive = $false
            PowerPlan = "High"
            DisableVBS = $true
        }
        ExtraRegistry = @(
            # GPU Hardware Scheduling
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "HwSchMode"; Value = 2; Type = "DWord" }
            # Low latency audio
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness"; Value = 0; Type = "DWord" }
            # Large system cache for video editing
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "LargeSystemCache"; Value = 1; Type = "DWord" }
        )
        Requirements = @{
            MinRAM_GB = 16
            DedicatedGPU = $true
            RecommendedFor = @("Video editing", "Audio production", "3D rendering")
        }
    }

    Laptop = @{
        Name = "Laptop / Battery"
        Description = "Power saving optimizations - extends battery life"
        Icon = "[L]"
        Color = "DarkYellow"
        Actions = @{
            RunTelemetry = $true
            RunServices = $true
            RunBloatware = $true
            RunBloatwareAggressive = $false
            RunRegistry = $true            # Disable animations saves battery
            RunNetwork = $false
            RunPrivacy = $true
            RemoveOneDrive = $false
            PowerPlan = "Balanced"         # Not power saver - too slow
            DisableVBS = $false
        }
        ExtraRegistry = @(
            # Disable transparency
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; Name = "EnableTransparency"; Value = 0; Type = "DWord" }
        )
        Requirements = @{
            MinRAM_GB = 4
            DedicatedGPU = $false
            RecommendedFor = @("Laptop on battery", "Ultrabook", "Travel")
        }
    }

    LowSpec = @{
        Name = "Low Spec"
        Description = "Maximum optimization for older/slower hardware"
        Icon = "[S]"
        Color = "Gray"
        Actions = @{
            RunTelemetry = $true
            RunServices = $true
            RunBloatware = $true
            RunBloatwareAggressive = $true  # Remove more apps
            RunRegistry = $true
            RunNetwork = $false
            RunPrivacy = $true
            RemoveOneDrive = $true          # Save resources
            PowerPlan = "High"
            DisableVBS = $true
        }
        ExtraRegistry = @(
            # Disable all visual effects
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name = "VisualFXSetting"; Value = 2; Type = "DWord" }
            # Reduce menu delay
            @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay"; Value = "0"; Type = "String" }
        )
        Requirements = @{
            MinRAM_GB = 2
            DedicatedGPU = $false
            RecommendedFor = @("Older hardware", "Low RAM systems", "Budget PCs")
        }
    }
}

# ============================================================================
# PROFILE FUNCTIONS
# ============================================================================
function Get-ProfileList {
    <#
    .SYNOPSIS
        Get list of available profiles
    #>
    [CmdletBinding()]
    param()

    return $script:ProfilePresets.Keys | ForEach-Object {
        $p = $script:ProfilePresets[$_]
        [PSCustomObject]@{
            Name = $p.Name
            Description = $p.Description
            Icon = $p.Icon
            Color = $p.Color
            MinRAM = $p.Requirements.MinRAM_GB
            NeedsGPU = $p.Requirements.DedicatedGPU
            RecommendedFor = $p.Requirements.RecommendedFor -join ", "
        }
    }
}

function Get-Profile {
    <#
    .SYNOPSIS
        Get a specific profile by name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $key = $script:ProfilePresets.Keys | Where-Object { $_ -eq $Name -or $script:ProfilePresets[$_].Name -eq $Name }
    if ($key) {
        return $script:ProfilePresets[$key]
    }
    return $null
}

function Get-SuggestedProfile {
    <#
    .SYNOPSIS
        Auto-suggest best profile based on hardware detection
    #>
    [CmdletBinding()]
    param()

    try {
        # Get hardware info from Hardware.psm1 (with fallbacks)
        $isLaptop = $false
        $isGaming = $false
        $ramGB = 8
        $cores = 4

        if (Get-Command 'Test-IsLaptop' -ErrorAction SilentlyContinue) {
            $isLaptop = Test-IsLaptop
        }
        if (Get-Command 'Test-IsGamingCapable' -ErrorAction SilentlyContinue) {
            $isGaming = Test-IsGamingCapable
        }
        if (Get-Command 'Get-MemoryInfo' -ErrorAction SilentlyContinue) {
            $memory = Get-MemoryInfo
            if ($memory -and $memory.Total_GB) { $ramGB = $memory.Total_GB }
        }
        if (Get-Command 'Get-CPUInfo' -ErrorAction SilentlyContinue) {
            $cpu = Get-CPUInfo
            if ($cpu -and $cpu.Cores) { $cores = $cpu.Cores }
        }

        # Decision logic
        $suggested = "Office"
        $reason = "Default balanced profile"

        if ($ramGB -lt 6) {
            $suggested = "LowSpec"
            $reason = "Low RAM detected ($ramGB GB)"
        }
        elseif ($isLaptop -and -not $isGaming) {
            $suggested = "Laptop"
            $reason = "Laptop without dedicated GPU detected"
        }
        elseif ($isGaming -and $ramGB -ge 16) {
            $suggested = "Gaming"
            $reason = "Dedicated GPU with $ramGB GB RAM"
        }
        elseif ($cores -ge 8 -and $ramGB -ge 16) {
            $suggested = "Developer"
            $reason = "High core count ($cores) with $ramGB GB RAM"
        }
        elseif ($isGaming -and $ramGB -ge 16) {
            $suggested = "ContentCreator"
            $reason = "Dedicated GPU suitable for content creation"
        }

        return [PSCustomObject]@{
            Profile = $suggested
            Reason = $reason
            Hardware = @{
                IsLaptop = $isLaptop
                HasDedicatedGPU = $isGaming
                RAM_GB = $ramGB
                Cores = $cores
            }
        }
    } catch {
        # Return default if hardware detection fails
        return [PSCustomObject]@{
            Profile = "Office"
            Reason = "Default (hardware detection unavailable)"
            Hardware = @{}
        }
    }
}

function Get-ActiveProfile {
    <#
    .SYNOPSIS
        Get currently active profile
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:ActiveProfileFile) {
        try {
            return Get-Content $script:ActiveProfileFile -Raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Set-ActiveProfile {
    <#
    .SYNOPSIS
        Save the active profile to file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-Path $script:ProfilesDir)) {
        New-Item -ItemType Directory -Path $script:ProfilesDir -Force | Out-Null
    }

    $activeData = @{
        Name = $Name
        AppliedAt = Get-Date -Format "o"
    }

    $activeData | ConvertTo-Json | Set-Content -Path $script:ActiveProfileFile -Encoding UTF8
}

# ============================================================================
# PROFILE APPLICATION - Calls existing module functions
# ============================================================================
function Set-OptimizationProfile {
    <#
    .SYNOPSIS
        Apply a profile by calling existing module functions
    .DESCRIPTION
        This integrates with existing modules:
        - Telemetry.psm1: Disable-Telemetry
        - Services.psm1: Disable-Services
        - Bloatware.psm1: DebloatBlacklist, DebloatAll, Protect-Privacy
        - Registry.psm1: Set-RegistryOptimizations
        - Network.psm1: Set-NetworkOptimizations
        - VBS.psm1: Disable-VBS
        - Power.psm1: Set-PowerPlan
        - OneDrive.psm1: Remove-OneDrive
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [switch]$Force
    )

    $profileData = Get-Profile -Name $Name
    if (-not $profileData) {
        Write-Host "Profile '$Name' not found" -ForegroundColor Red
        return $false
    }

    Write-Host ""
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host "  APPLYING PROFILE: $($profileData.Name)" -ForegroundColor Yellow
    Write-Host "  $($profileData.Description)" -ForegroundColor Gray
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host ""

    # Preview mode via WhatIf
    if ($PSCmdlet.ShouldProcess($profileData.Name, "Apply optimization profile")) {
        # Continue with application
    } else {
        Write-Host "[PREVIEW MODE - No changes will be made]" -ForegroundColor Magenta
        Write-Host ""
        Show-ProfileActions -ProfileData $profileData
        return $true
    }

    # Confirm unless forced
    if (-not $Force) {
        Write-Host "This profile will run the following optimizations:" -ForegroundColor Yellow
        Show-ProfileActions -ProfileData $profileData
        Write-Host ""
        $confirm = Read-Host "Continue? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Host "Cancelled" -ForegroundColor Yellow
            return $false
        }
    }

    $actions = $profileData.Actions
    $results = @{ Success = 0; Skipped = 0; Failed = 0 }

    # Start rollback session if available
    if (Get-Command 'Start-RollbackSession' -ErrorAction SilentlyContinue) {
        Start-RollbackSession -Name "Profile_$Name"
    }

    Write-Host ""
    Write-Host "Applying optimizations..." -ForegroundColor Cyan
    Write-Host ""

    # === TELEMETRY ===
    if ($actions.RunTelemetry) {
        Write-Host "  [1/8] Telemetry..." -ForegroundColor White -NoNewline
        if (Get-Command 'Disable-Telemetry' -ErrorAction SilentlyContinue) {
            try {
                Disable-Telemetry
                Write-Host " Done" -ForegroundColor Green
                $results.Success++
            } catch {
                Write-Host " Failed: $($_.Exception.Message)" -ForegroundColor Red
                $results.Failed++
            }
        } else {
            Write-Host " Module not loaded" -ForegroundColor Yellow
            $results.Skipped++
        }
    } else {
        Write-Host "  [1/8] Telemetry... Skipped (profile setting)" -ForegroundColor DarkGray
        $results.Skipped++
    }

    # === SERVICES ===
    if ($actions.RunServices) {
        Write-Host "  [2/8] Services..." -ForegroundColor White -NoNewline
        if (Get-Command 'Disable-Services' -ErrorAction SilentlyContinue) {
            try {
                Disable-Services
                Write-Host " Done" -ForegroundColor Green
                $results.Success++
            } catch {
                Write-Host " Failed: $($_.Exception.Message)" -ForegroundColor Red
                $results.Failed++
            }
        } else {
            Write-Host " Module not loaded" -ForegroundColor Yellow
            $results.Skipped++
        }
    } else {
        Write-Host "  [2/8] Services... Skipped (profile setting)" -ForegroundColor DarkGray
        $results.Skipped++
    }

    # === BLOATWARE ===
    if ($actions.RunBloatware) {
        Write-Host "  [3/8] Bloatware..." -ForegroundColor White -NoNewline
        $bloatFunc = if ($actions.RunBloatwareAggressive) { 'DebloatAll' } else { 'DebloatBlacklist' }
        if (Get-Command $bloatFunc -ErrorAction SilentlyContinue) {
            try {
                & $bloatFunc
                Write-Host " Done" -ForegroundColor Green
                $results.Success++
            } catch {
                Write-Host " Failed: $($_.Exception.Message)" -ForegroundColor Red
                $results.Failed++
            }
        } else {
            Write-Host " Module not loaded" -ForegroundColor Yellow
            $results.Skipped++
        }
    } else {
        Write-Host "  [3/8] Bloatware... Skipped (profile setting)" -ForegroundColor DarkGray
        $results.Skipped++
    }

    # === REGISTRY ===
    if ($actions.RunRegistry) {
        Write-Host "  [4/8] Registry..." -ForegroundColor White -NoNewline
        if (Get-Command 'Set-RegistryOptimizations' -ErrorAction SilentlyContinue) {
            try {
                Set-RegistryOptimizations
                Write-Host " Done" -ForegroundColor Green
                $results.Success++
            } catch {
                Write-Host " Failed: $($_.Exception.Message)" -ForegroundColor Red
                $results.Failed++
            }
        } else {
            Write-Host " Module not loaded" -ForegroundColor Yellow
            $results.Skipped++
        }
    } else {
        Write-Host "  [4/8] Registry... Skipped (profile setting)" -ForegroundColor DarkGray
        $results.Skipped++
    }

    # === NETWORK ===
    if ($actions.RunNetwork) {
        Write-Host "  [5/8] Network..." -ForegroundColor White -NoNewline
        if (Get-Command 'Set-NetworkOptimizations' -ErrorAction SilentlyContinue) {
            try {
                Set-NetworkOptimizations
                Write-Host " Done" -ForegroundColor Green
                $results.Success++
            } catch {
                Write-Host " Failed: $($_.Exception.Message)" -ForegroundColor Red
                $results.Failed++
            }
        } else {
            Write-Host " Module not loaded" -ForegroundColor Yellow
            $results.Skipped++
        }
    } else {
        Write-Host "  [5/8] Network... Skipped (profile setting)" -ForegroundColor DarkGray
        $results.Skipped++
    }

    # === PRIVACY ===
    if ($actions.RunPrivacy) {
        Write-Host "  [6/8] Privacy..." -ForegroundColor White -NoNewline
        if (Get-Command 'Protect-Privacy' -ErrorAction SilentlyContinue) {
            try {
                Protect-Privacy
                Write-Host " Done" -ForegroundColor Green
                $results.Success++
            } catch {
                Write-Host " Failed: $($_.Exception.Message)" -ForegroundColor Red
                $results.Failed++
            }
        } else {
            Write-Host " Module not loaded" -ForegroundColor Yellow
            $results.Skipped++
        }
    } else {
        Write-Host "  [6/8] Privacy... Skipped (profile setting)" -ForegroundColor DarkGray
        $results.Skipped++
    }

    # === VBS ===
    if ($actions.DisableVBS) {
        Write-Host "  [7/8] VBS/Memory Integrity..." -ForegroundColor White -NoNewline
        if (Get-Command 'Disable-VBS' -ErrorAction SilentlyContinue) {
            try {
                Disable-VBS
                Write-Host " Done" -ForegroundColor Green
                $results.Success++
            } catch {
                Write-Host " Failed: $($_.Exception.Message)" -ForegroundColor Red
                $results.Failed++
            }
        } else {
            Write-Host " Module not loaded" -ForegroundColor Yellow
            $results.Skipped++
        }
    } else {
        Write-Host "  [7/8] VBS... Skipped (profile setting)" -ForegroundColor DarkGray
        $results.Skipped++
    }

    # === POWER PLAN ===
    Write-Host "  [8/8] Power Plan..." -ForegroundColor White -NoNewline
    try {
        $planGuid = switch ($actions.PowerPlan) {
            "High" { "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" }
            "Balanced" { "381b4222-f694-41f0-9685-ff5bb260df2e" }
            "PowerSaver" { "a1841308-3541-4fab-bc81-f71556f20b4a" }
            default { $null }
        }
        if ($planGuid) {
            powercfg /setactive $planGuid 2>$null
            Write-Host " $($actions.PowerPlan)" -ForegroundColor Green
            $results.Success++
        }
    } catch {
        Write-Host " Failed" -ForegroundColor Red
        $results.Failed++
    }

    # === EXTRA REGISTRY TWEAKS ===
    if ($profileData.ExtraRegistry -and $profileData.ExtraRegistry.Count -gt 0) {
        Write-Host ""
        Write-Host "  Applying profile-specific tweaks..." -ForegroundColor Cyan
        foreach ($reg in $profileData.ExtraRegistry) {
            try {
                if (-not (Test-Path $reg.Path)) {
                    New-Item -Path $reg.Path -Force | Out-Null
                }
                Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type $reg.Type -Force
                Write-Host "    Set: $($reg.Name)" -ForegroundColor Green
            } catch {
                Write-Host "    Failed: $($reg.Name)" -ForegroundColor Red
            }
        }
    }

    # === ONEDRIVE ===
    if ($actions.RemoveOneDrive) {
        Write-Host ""
        Write-Host "  OneDrive removal..." -ForegroundColor White -NoNewline
        if (Get-Command 'Remove-OneDrive' -ErrorAction SilentlyContinue) {
            try {
                Remove-OneDrive
                Write-Host " Done" -ForegroundColor Green
            } catch {
                Write-Host " Failed" -ForegroundColor Red
            }
        } else {
            Write-Host " Module not loaded" -ForegroundColor Yellow
        }
    }

    # End rollback session
    if (Get-Command 'Stop-RollbackSession' -ErrorAction SilentlyContinue) {
        Stop-RollbackSession
    }

    # Save active profile
    Set-ActiveProfile -Name $Name

    # Summary
    Write-Host ""
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host "  PROFILE APPLIED: $($profileData.Name)" -ForegroundColor Green
    Write-Host "  Success: $($results.Success) | Skipped: $($results.Skipped) | Failed: $($results.Failed)" -ForegroundColor Gray
    Write-Host ("=" * 65) -ForegroundColor Cyan

    return $true
}

function Show-ProfileActions {
    <#
    .SYNOPSIS
        Display what actions a profile will take
    #>
    param($ProfileData)

    $actions = $ProfileData.Actions

    $items = @(
        @{ Name = "Disable Telemetry"; Enabled = $actions.RunTelemetry; Module = "Telemetry.psm1" }
        @{ Name = "Disable Services"; Enabled = $actions.RunServices; Module = "Services.psm1" }
        @{ Name = "Remove Bloatware"; Enabled = $actions.RunBloatware; Module = "Bloatware.psm1"; Extra = if($actions.RunBloatwareAggressive){"(Aggressive)"}else{"(Standard)"} }
        @{ Name = "Registry Optimizations"; Enabled = $actions.RunRegistry; Module = "Registry.psm1" }
        @{ Name = "Network Optimizations"; Enabled = $actions.RunNetwork; Module = "Network.psm1" }
        @{ Name = "Privacy Tweaks"; Enabled = $actions.RunPrivacy; Module = "Bloatware.psm1" }
        @{ Name = "Disable VBS"; Enabled = $actions.DisableVBS; Module = "VBS.psm1" }
        @{ Name = "Power Plan"; Enabled = $true; Module = "Power.psm1"; Extra = "($($actions.PowerPlan))" }
        @{ Name = "Remove OneDrive"; Enabled = $actions.RemoveOneDrive; Module = "OneDrive.psm1" }
    )

    foreach ($item in $items) {
        $status = if ($item.Enabled) { "[X]" } else { "[ ]" }
        $color = if ($item.Enabled) { "Green" } else { "DarkGray" }
        $extra = if ($item.Extra) { " $($item.Extra)" } else { "" }
        Write-Host "  $status $($item.Name)$extra" -ForegroundColor $color
    }

    if ($ProfileData.ExtraRegistry -and $ProfileData.ExtraRegistry.Count -gt 0) {
        Write-Host "  [X] Profile-specific registry tweaks ($($ProfileData.ExtraRegistry.Count))" -ForegroundColor Green
    }
}

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================
function Show-ProfileDetails {
    <#
    .SYNOPSIS
        Show detailed settings for a profile
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $profileData = Get-Profile -Name $Name
    if (-not $profileData) {
        Write-Host "Profile '$Name' not found" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $($profileData.Icon) $($profileData.Name)" -ForegroundColor $profileData.Color
    Write-Host "  $($profileData.Description)" -ForegroundColor Gray
    Write-Host ("=" * 60) -ForegroundColor Cyan

    Write-Host ""
    Write-Host "  Requirements:" -ForegroundColor Yellow
    Write-Host "    Min RAM: $($profileData.Requirements.MinRAM_GB) GB"
    Write-Host "    Dedicated GPU: $(if($profileData.Requirements.DedicatedGPU){'Required'}else{'Not required'})"
    Write-Host "    Best for: $($profileData.Requirements.RecommendedFor -join ', ')"

    Write-Host ""
    Write-Host "  Actions (calls existing module functions):" -ForegroundColor Yellow
    Show-ProfileActions -ProfileData $profileData

    Write-Host ""
}

function Compare-Profiles {
    <#
    .SYNOPSIS
        Compare two profiles side by side
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Profile1,
        [Parameter(Mandatory)]
        [string]$Profile2
    )

    $p1 = Get-Profile -Name $Profile1
    $p2 = Get-Profile -Name $Profile2

    if (-not $p1 -or -not $p2) {
        Write-Host "One or both profiles not found" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  PROFILE COMPARISON" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""

    $col1 = $p1.Name.PadRight(20)
    $col2 = $p2.Name.PadRight(20)
    Write-Host "  Action".PadRight(30) -NoNewline
    Write-Host $col1 -ForegroundColor $p1.Color -NoNewline
    Write-Host $col2 -ForegroundColor $p2.Color
    Write-Host "  " + ("-" * 68)

    $actionKeys = @('RunTelemetry', 'RunServices', 'RunBloatware', 'RunRegistry', 'RunNetwork', 'RunPrivacy', 'DisableVBS', 'RemoveOneDrive', 'PowerPlan')

    foreach ($key in $actionKeys) {
        $v1 = $p1.Actions[$key]
        $v2 = $p2.Actions[$key]
        $v1Str = if ($v1 -is [bool]) { if($v1){"Yes"}else{"No"} } else { $v1 }
        $v2Str = if ($v2 -is [bool]) { if($v2){"Yes"}else{"No"} } else { $v2 }

        $diffColor = if ($v1 -ne $v2) { 'Yellow' } else { 'Gray' }
        Write-Host "  $($key.PadRight(28))" -NoNewline
        Write-Host $v1Str.ToString().PadRight(20) -ForegroundColor $diffColor -NoNewline
        Write-Host $v2Str.ToString().PadRight(20) -ForegroundColor $diffColor
    }

    Write-Host ""
}

# ============================================================================
# PROFILE MENU
# ============================================================================
function Show-ProfileMenu {
    <#
    .SYNOPSIS
        Interactive profile selection menu
    #>
    [CmdletBinding()]
    param()

    do {
        Clear-Host
        Write-Host ""
        Write-Host ("=" * 65) -ForegroundColor Cyan
        Write-Host "  OPTIMIZATION PROFILES" -ForegroundColor Yellow
        Write-Host ("=" * 65) -ForegroundColor Cyan

        # Show current profile
        $active = Get-ActiveProfile
        if ($active) {
            $appliedDate = if ($active.AppliedAt) {
                try { (Get-Date $active.AppliedAt).ToString("yyyy-MM-dd HH:mm") } catch { "unknown" }
            } else { "unknown" }
            Write-Host "  Current: $($active.Name) (applied $appliedDate)" -ForegroundColor Green
        } else {
            Write-Host "  Current: None" -ForegroundColor Gray
        }

        # Show suggested profile
        $suggested = Get-SuggestedProfile
        Write-Host "  Suggested: $($suggested.Profile) - $($suggested.Reason)" -ForegroundColor Cyan

        Write-Host ""
        Write-Host ("=" * 65) -ForegroundColor Cyan
        Write-Host ""

        # List profiles
        $i = 1
        $profileMap = @{}
        foreach ($key in @('Gaming', 'Developer', 'Office', 'ContentCreator', 'Laptop', 'LowSpec')) {
            if ($script:ProfilePresets.ContainsKey($key)) {
                $p = $script:ProfilePresets[$key]
                $profileMap[$i] = $key
                $marker = ""
                if ($active -and $active.Name -eq $p.Name) { $marker = " [ACTIVE]" }
                if ($suggested.Profile -eq $key) { $marker += " [SUGGESTED]" }

                Write-Host "  [$i] $($p.Icon) $($p.Name)$marker" -ForegroundColor $p.Color
                Write-Host "      $($p.Description)" -ForegroundColor DarkGray
                $i++
            }
        }

        Write-Host ""
        Write-Host "  [7] View Profile Details"
        Write-Host "  [8] Compare Profiles"
        Write-Host "  [9] Hardware Summary"
        Write-Host ""
        Write-Host "  [0] Back to Main Menu"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            { [int]$_ -ge 1 -and [int]$_ -le $profileMap.Count } {
                $selectedProfile = $profileMap[[int]$choice]
                Write-Host ""
                Write-Host "Selected: $selectedProfile" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "  [1] Apply this profile"
                Write-Host "  [2] View details"
                Write-Host "  [3] Preview (WhatIf)"
                Write-Host "  [0] Cancel"
                Write-Host ""
                $subChoice = Read-Host "Action"

                switch ($subChoice) {
                    "1" {
                        Set-OptimizationProfile -Name $selectedProfile
                        Write-Host "`nPress any key..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "2" {
                        Show-ProfileDetails -Name $selectedProfile
                        Write-Host "`nPress any key..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "3" {
                        Set-OptimizationProfile -Name $selectedProfile -WhatIf
                        Write-Host "`nPress any key..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                }
            }
            "7" {
                Write-Host ""
                $profileName = Read-Host "Enter profile name (Gaming/Developer/Office/ContentCreator/Laptop/LowSpec)"
                Show-ProfileDetails -Name $profileName
                Write-Host "`nPress any key..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "8" {
                Write-Host ""
                $p1 = Read-Host "First profile"
                $p2 = Read-Host "Second profile"
                Compare-Profiles -Profile1 $p1 -Profile2 $p2
                Write-Host "`nPress any key..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "9" {
                if (Get-Command 'Show-HardwareSummary' -ErrorAction SilentlyContinue) {
                    Show-HardwareSummary
                } else {
                    Write-Host "Hardware module not loaded" -ForegroundColor Yellow
                }
                Write-Host "`nPress any key..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "0" { return }
        }
    } while ($true)
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================
Export-ModuleMember -Function @(
    # Profile Management
    'Get-ProfileList',
    'Get-Profile',
    'Get-SuggestedProfile',
    'Get-ActiveProfile',
    'Set-ActiveProfile',

    # Profile Application
    'Set-OptimizationProfile',

    # Display
    'Show-ProfileDetails',
    'Show-ProfileActions',
    'Compare-Profiles',
    'Show-ProfileMenu'
)
