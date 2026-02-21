<#
.SYNOPSIS
    First-Run Warning and Consent System

.DESCRIPTION
    Displays a comprehensive warning on first execution explaining what System Optimizer
    does, potential risks, and requires explicit user consent before proceeding.
    
    Stores consent in registry to avoid showing on subsequent runs.

.NOTES
    Version: 1.0.0
    Author: System Optimizer Team
    
.EXPORTED FUNCTIONS
    - Show-FirstRunWarning: Display warning and get user consent
    - Test-FirstRunComplete: Check if first run warning has been accepted
    - Set-FirstRunComplete: Mark first run as complete
    - Reset-FirstRunWarning: Reset first run flag (for testing or re-showing)
#>

# Registry path for storing first-run flag
$script:RegistryPath = "HKCU:\Software\SystemOptimizer"
$script:FirstRunValue = "FirstRunComplete"

function Test-FirstRunComplete {
    <#
    .SYNOPSIS
        Check if the first-run warning has been accepted
    
    .DESCRIPTION
        Checks registry to see if user has already accepted the first-run warning
    
    .OUTPUTS
        Boolean - True if first run is complete, False if warning needs to be shown
    #>
    
    try {
        if (Test-Path $script:RegistryPath) {
            $value = Get-ItemProperty -Path $script:RegistryPath -Name $script:FirstRunValue -ErrorAction SilentlyContinue
            return ($null -ne $value -and $value.$script:FirstRunValue -eq 1)
        }
        return $false
    } catch {
        return $false
    }
}

function Set-FirstRunComplete {
    <#
    .SYNOPSIS
        Mark first run as complete
    
    .DESCRIPTION
        Stores a flag in registry indicating user has accepted the warning
    #>
    
    try {
        if (-not (Test-Path $script:RegistryPath)) {
            New-Item -Path $script:RegistryPath -Force | Out-Null
        }
        Set-ItemProperty -Path $script:RegistryPath -Name $script:FirstRunValue -Value 1 -Type DWord
        return $true
    } catch {
        Write-Warning "Failed to save first-run flag: $($_.Exception.Message)"
        return $false
    }
}

function Reset-FirstRunWarning {
    <#
    .SYNOPSIS
        Reset the first-run warning flag
    
    .DESCRIPTION
        Removes the registry flag so the warning will be shown again on next run.
        Useful for testing or if user wants to review the warning again.
    #>
    
    try {
        if (Test-Path $script:RegistryPath) {
            Remove-ItemProperty -Path $script:RegistryPath -Name $script:FirstRunValue -ErrorAction SilentlyContinue
        }
        Write-Host "First-run warning has been reset. It will show on next execution." -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "Failed to reset first-run flag: $($_.Exception.Message)"
        return $false
    }
}

function Show-FirstRunWarning {
    <#
    .SYNOPSIS
        Display first-run warning and get user consent
    
    .DESCRIPTION
        Shows a comprehensive warning explaining what System Optimizer does,
        potential risks, and requires explicit user consent before proceeding.
    
    .OUTPUTS
        Boolean - True if user accepts, False if user declines
    #>
    
    Clear-Host
    
    # Header
    Write-Host ("=" * 80) -ForegroundColor Red
    Write-Host "  SYSTEM OPTIMIZER - FIRST RUN WARNING" -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Red
    Write-Host ""
    
    # What is this tool
    Write-Host "WHAT IS SYSTEM OPTIMIZER?" -ForegroundColor Cyan
    Write-Host "System Optimizer is a comprehensive Windows 10/11 optimization toolkit that" -ForegroundColor White
    Write-Host "makes SIGNIFICANT CHANGES to your system to improve performance and privacy." -ForegroundColor White
    Write-Host ""
    
    # What it modifies
    Write-Host "WHAT DOES IT MODIFY?" -ForegroundColor Cyan
    Write-Host "  • Windows Services" -ForegroundColor Gray -NoNewline
    Write-Host " - Disables 90+ unnecessary services" -ForegroundColor White
    Write-Host "  • Telemetry & Privacy" -ForegroundColor Gray -NoNewline
    Write-Host " - Blocks data collection and tracking" -ForegroundColor White
    Write-Host "  • Registry Settings" -ForegroundColor Gray -NoNewline
    Write-Host " - Applies 20+ performance tweaks" -ForegroundColor White
    Write-Host "  • Scheduled Tasks" -ForegroundColor Gray -NoNewline
    Write-Host " - Disables diagnostic and telemetry tasks" -ForegroundColor White
    Write-Host "  • Pre-installed Apps" -ForegroundColor Gray -NoNewline
    Write-Host " - Removes bloatware and unwanted software" -ForegroundColor White
    Write-Host "  • Network Settings" -ForegroundColor Gray -NoNewline
    Write-Host " - Optimizes TCP/IP and network stack" -ForegroundColor White
    Write-Host "  • Security Features" -ForegroundColor Gray -NoNewline
    Write-Host " - Can disable VBS, Defender, and other protections" -ForegroundColor White
    Write-Host ""
    
    # Risks
    Write-Host "POTENTIAL RISKS:" -ForegroundColor Red
    Write-Host "  ⚠ System instability if incompatible optimizations are applied" -ForegroundColor Yellow
    Write-Host "  ⚠ Some Windows features may stop working (Store, Xbox, Cortana, etc.)" -ForegroundColor Yellow
    Write-Host "  ⚠ Windows Update issues if update services are disabled" -ForegroundColor Yellow
    Write-Host "  ⚠ Reduced security if Defender or VBS are disabled" -ForegroundColor Yellow
    Write-Host "  ⚠ Compatibility issues with certain applications" -ForegroundColor Yellow
    Write-Host "  ⚠ Changes may affect system warranty or support" -ForegroundColor Yellow
    Write-Host ""
    
    # Requirements
    Write-Host "REQUIREMENTS:" -ForegroundColor Cyan
    Write-Host "  • Administrator privileges (required for system modifications)" -ForegroundColor White
    Write-Host "  • Windows 10 or Windows 11" -ForegroundColor White
    Write-Host "  • Understanding of what each optimization does" -ForegroundColor White
    Write-Host ""
    
    # Recommendations
    Write-Host "STRONGLY RECOMMENDED BEFORE PROCEEDING:" -ForegroundColor Green
    Write-Host "  ✓ Create a System Restore Point" -ForegroundColor White
    Write-Host "  ✓ Backup important data to external drive" -ForegroundColor White
    Write-Host "  ✓ Read the documentation at GitHub" -ForegroundColor White
    Write-Host "  ✓ Start with individual optimizations, not 'Run All'" -ForegroundColor White
    Write-Host "  ✓ Test each change before applying more" -ForegroundColor White
    Write-Host ""
    
    # Reversibility
    Write-Host "REVERSIBILITY:" -ForegroundColor Cyan
    Write-Host "  • Built-in Rollback System available (Menu Option 32)" -ForegroundColor White
    Write-Host "  • System Restore can undo most changes" -ForegroundColor White
    Write-Host "  • Some changes may require manual reversal" -ForegroundColor White
    Write-Host "  • Bloatware removal is difficult to reverse" -ForegroundColor White
    Write-Host ""
    
    # Support
    Write-Host "SUPPORT & DOCUMENTATION:" -ForegroundColor Cyan
    Write-Host "  • GitHub: https://github.com/coff33ninja/System_Optimizer" -ForegroundColor White
    Write-Host "  • Issues: Report problems via GitHub Issues" -ForegroundColor White
    Write-Host "  • Documentation: See docs/ folder and wiki" -ForegroundColor White
    Write-Host ""
    
    # Disclaimer
    Write-Host ("=" * 80) -ForegroundColor Red
    Write-Host "DISCLAIMER:" -ForegroundColor Yellow
    Write-Host "This tool is provided AS-IS without warranty. Use at your own risk." -ForegroundColor White
    Write-Host "The authors are not responsible for any damage or data loss." -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor Red
    Write-Host ""
    
    # Consent prompt
    Write-Host "Do you understand and accept these risks?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Type 'I ACCEPT' (case-sensitive) to continue, or anything else to exit: " -ForegroundColor Cyan -NoNewline
    
    $response = Read-Host
    Write-Host ""
    
    if ($response -ceq "I ACCEPT") {
        Write-Host "✓ Consent accepted. Proceeding with System Optimizer..." -ForegroundColor Green
        Write-Host ""
        
        # Save consent flag
        $saved = Set-FirstRunComplete
        if (-not $saved) {
            Write-Warning "Could not save consent flag. Warning may appear again on next run."
        }
        
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        return $true
    } else {
        Write-Host "✗ Consent not accepted. Exiting System Optimizer." -ForegroundColor Red
        Write-Host ""
        Write-Host "If you change your mind, run the script again." -ForegroundColor Gray
        Write-Host "For more information, visit: https://github.com/coff33ninja/System_Optimizer" -ForegroundColor Cyan
        Write-Host ""
        
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Show-FirstRunWarning, Test-FirstRunComplete, Set-FirstRunComplete, Reset-FirstRunWarning
