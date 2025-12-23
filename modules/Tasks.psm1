# ============================================================================
# Tasks Module - System Optimizer
# ============================================================================

function Disable-ScheduledTasks {
    Write-Log "DISABLING SCHEDULED TASKS" "SECTION"

    $TasksToDisable = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
        "\Microsoft\Windows\Autochk\Proxy"
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
        "\Microsoft\Windows\Feedback\Siuf\DmClient"
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
        "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
        "\Microsoft\Windows\DiskFootprint\Diagnostics"
        "\Microsoft\Windows\Maintenance\WinSAT"
        "\Microsoft\Windows\Maps\MapsToastTask"
        "\Microsoft\Windows\Maps\MapsUpdateTask"
        "\Microsoft\Windows\Shell\FamilySafetyMonitor"
        "\Microsoft\Windows\Shell\FamilySafetyRefreshTask"
        "\Microsoft\XblGameSave\XblGameSaveTask"
        "\Microsoft\XblGameSave\XblGameSaveTaskLogon"
    )

    # Use progress tracking if available
    $hasProgress = Get-Command 'Start-ProgressOperation' -ErrorAction SilentlyContinue
    if ($hasProgress) {
        Start-ProgressOperation -Name "Disabling Scheduled Tasks" -TotalItems $TasksToDisable.Count
    }

    foreach ($task in $TasksToDisable) {
        # Get short name for display
        $shortName = $task.Split('\')[-1]
        try {
            $existingTask = Get-ScheduledTask -TaskName $shortName -ErrorAction SilentlyContinue
            if ($existingTask) {
                Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
                if ($hasProgress) {
                    Update-ProgressItem -ItemName $shortName -Status 'Success'
                } else {
                    Write-Log "Disabled task: $task" "SUCCESS"
                }
            } else {
                if ($hasProgress) {
                    Update-ProgressItem -ItemName $shortName -Status 'Skipped' -Message "Not found"
                } else {
                    Write-Log "Task not found: $task" "WARNING"
                }
            }
        } catch {
            if ($hasProgress) {
                Update-ProgressItem -ItemName $shortName -Status 'Failed' -Message $_.Exception.Message
            } else {
                Write-Log "Could not disable: $task" "WARNING"
            }
        }
    }

    if ($hasProgress) {
        Complete-ProgressOperation
    } else {
        Write-Log "Scheduled tasks optimization completed" "SUCCESS"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Disable-ScheduledTasks'
)
