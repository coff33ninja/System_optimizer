# ============================================================================
# Power Module - System Optimizer
# ============================================================================

function Set-PowerPlan {
    Set-ConsoleSize
    Clear-Host
    Write-Log "POWER PLAN SETTINGS" "SECTION"

    Write-Host ""
    Write-Host "Power Plan Options:" -ForegroundColor Cyan
    Write-Host "  [1] High Performance"
    Write-Host "  [2] Ultimate Performance (creates if not exists)"
    Write-Host "  [3] Balanced (default)"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" {
            Write-Log "Setting High Performance power plan..."
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
            Set-NeverSleepOnAC
            Write-Log "High Performance power plan activated" "SUCCESS"
        }
        "2" {
            Write-Log "Creating/Setting Ultimate Performance power plan..."
            # Create Ultimate Performance plan (may already exist)
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            # Find and activate it
            $ultimate = powercfg /list | Select-String "Ultimate Performance"
            if ($ultimate) {
                $guid = ($ultimate -split '\s+')[3]
                powercfg /setactive $guid
                Write-Log "Ultimate Performance power plan activated" "SUCCESS"
            } else {
                # Fallback to High Performance
                powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
                Write-Log "Ultimate not available, set High Performance" "WARNING"
            }
            Set-NeverSleepOnAC
        }
        "3" {
            Write-Log "Setting Balanced power plan..."
            powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
            Set-NeverSleepOnAC
            Write-Log "Balanced power plan activated" "SUCCESS"
        }
        "0" { Write-Log "Cancelled" "INFO" }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}

function Set-NeverSleepOnAC {
    Write-Log "Configuring power settings..."

    # === AC POWER (Plugged In) - Never sleep/hibernate/turn off screen ===
    powercfg /change standby-timeout-ac 0
    Write-Log "Sleep on AC: Never" "SUCCESS"

    powercfg /change hibernate-timeout-ac 0
    Write-Log "Hibernate on AC: Never" "SUCCESS"

    powercfg /change monitor-timeout-ac 0
    Write-Log "Turn off screen on AC: Never" "SUCCESS"

    # Disable hybrid sleep on AC
    powercfg /setacvalueindex scheme_current sub_sleep hybridsleep 0
    Write-Log "Hybrid sleep on AC: Disabled" "SUCCESS"

    # === BATTERY POWER - Reasonable timeouts ===
    powercfg /change monitor-timeout-dc 30
    Write-Log "Turn off screen on Battery: 30 minutes" "SUCCESS"

    powercfg /change standby-timeout-dc 60
    Write-Log "Sleep on Battery: 1 hour" "SUCCESS"

    powercfg /change hibernate-timeout-dc 120
    Write-Log "Hibernate on Battery: 2 hours" "SUCCESS"

    # Apply changes
    powercfg /setactive scheme_current

    Write-Log "Power settings configured - AC: never sleep | Battery: screen 30min, sleep 1hr" "SUCCESS"
}

# Export functions
Export-ModuleMember -Function @(
    'Set-PowerPlan',
    'Set-NeverSleepOnAC'
)
