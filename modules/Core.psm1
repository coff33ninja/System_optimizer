#Requires -Version 5.1
<#
.SYNOPSIS
    Core Module - System Optimizer
.DESCRIPTION
    Provides core functionality for System Optimizer including progress tracking,
    download helpers, and main entry points for optimization workflows.

Exported Functions:
    Set-VerboseProgress        - Toggle verbose progress output
    Get-VerboseProgress        - Get verbose progress state
    Start-ProgressOperation    - Initialize a progress operation with ETA tracking
    Update-ProgressItem        - Update progress for current item
    Complete-ProgressOperation - Complete progress operation and show summary
    Show-ProgressBar           - Display console progress bar
    Show-EnhancedProgress      - Show GUI-style progress dialog
    Confirm-ProgressCleanup    - Ensure progress resources are cleaned up
    Close-EnhancedProgress     - Close progress dialog
    Set-ProgressMode           - Set progress display mode (GUI/Console)
    Write-ProgressLog          - Write to progress log
    Start-Download             - Download files with progress tracking
    Start-AllOptimization      - Run all optimizations (main entry)
    Start-FullSetup            - Full setup workflow (software + office + activation)
    Start-MainMenu             - Display legacy main menu

Notes:
    - Progress tracking includes ETA calculation based on item timing
    - Supports both console and GUI progress displays
    - Thread-safe for use in parallel operations

Version: 1.0.0
#>

# ============================================================================
# ENHANCED PROGRESS TRACKING SYSTEM
# ============================================================================
$script:ProgressState = @{
    CurrentOperation = ""
    TotalItems = 0
    CompletedItems = 0
    SuccessCount = 0
    FailedCount = 0
    SkippedCount = 0
    StartTime = $null
    Results = @()
    ItemTimes = @()  # Track time per item for ETA calculation
}

# Progress UI state
$script:ProgressForm = $null
$script:ProgressBar = $null
$script:ProgressLabel = $null
$script:UseGUIProgress = $false

# Verbose mode toggle - set to $true for detailed output (registry paths, file sizes, etc.)
$script:VerboseProgress = $false

function Set-VerboseProgress {
    <#
    .SYNOPSIS
        Enable or disable verbose progress mode
    .PARAMETER Enabled
        $true to enable verbose output, $false to disable
    .EXAMPLE
        Set-VerboseProgress -Enabled $true
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled
    )
    $script:VerboseProgress = $Enabled
    if ($Enabled) {
        Write-Host "  [i] Verbose progress mode: ENABLED" -ForegroundColor Cyan
    } else {
        Write-Host "  [i] Verbose progress mode: DISABLED" -ForegroundColor DarkGray
    }
}

function Get-VerboseProgress {
    <#
    .SYNOPSIS
        Get current verbose progress mode state
    #>
    return $script:VerboseProgress
}

function Start-ProgressOperation {
    <#
    .SYNOPSIS
        Initialize a new progress tracking operation
    .PARAMETER Name
        Name of the operation (e.g., "Removing Bloatware")
    .PARAMETER TotalItems
        Total number of items to process
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [int]$TotalItems = 0
    )

    $script:ProgressState = @{
        CurrentOperation = $Name
        TotalItems = $TotalItems
        CompletedItems = 0
        SuccessCount = 0
        FailedCount = 0
        SkippedCount = 0
        StartTime = Get-Date
        Results = @()
        ItemTimes = @()
        LastItemTime = Get-Date
    }

    Write-Host ""
    Write-Host "  $Name" -ForegroundColor Cyan
    if ($TotalItems -gt 0) {
        Write-Host "  Processing $TotalItems items..." -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Update-ProgressItem {
    <#
    .SYNOPSIS
        Update progress for a single item
    .PARAMETER ItemName
        Name of the current item being processed
    .PARAMETER Status
        Status: Success, Failed, Skipped
    .PARAMETER Message
        Optional message to display
    .PARAMETER VerboseDetail
        Optional detailed info shown only in verbose mode (e.g., registry path, file size)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ItemName,
        [ValidateSet('Success', 'Failed', 'Skipped', 'Info')]
        [string]$Status = 'Success',
        [string]$Message = "",
        [string]$VerboseDetail = ""
    )

    # Track time for this item (for ETA calculation)
    $now = Get-Date
    if ($script:ProgressState.LastItemTime) {
        $itemDuration = ($now - $script:ProgressState.LastItemTime).TotalSeconds
        $script:ProgressState.ItemTimes += $itemDuration
    }
    $script:ProgressState.LastItemTime = $now

    $script:ProgressState.CompletedItems++

    switch ($Status) {
        'Success' {
            $script:ProgressState.SuccessCount++
            $icon = "[OK]"
            $color = "Green"
        }
        'Failed' {
            $script:ProgressState.FailedCount++
            $icon = "[X]"
            $color = "Red"
        }
        'Skipped' {
            $script:ProgressState.SkippedCount++
            $icon = "[-]"
            $color = "DarkYellow"
        }
        'Info' {
            $icon = "[i]"
            $color = "Gray"
        }
    }

    # Store result
    $script:ProgressState.Results += @{
        Item = $ItemName
        Status = $Status
        Message = $Message
        VerboseDetail = $VerboseDetail
        Time = $now
    }

    # Display progress
    $total = $script:ProgressState.TotalItems
    $current = $script:ProgressState.CompletedItems

    if ($total -gt 0) {
        $percent = [math]::Round(($current / $total) * 100)
        $progressText = "[$current/$total]"

        # Calculate ETA based on average time per item
        $remaining = $total - $current
        if ($script:ProgressState.ItemTimes.Count -gt 0 -and $remaining -gt 0) {
            $avgTime = ($script:ProgressState.ItemTimes | Measure-Object -Average).Average
            $etaSeconds = [math]::Round($avgTime * $remaining)
            if ($etaSeconds -ge 60) {
                $etaText = " ~{0:N0}m {1:N0}s left" -f [math]::Floor($etaSeconds / 60), ($etaSeconds % 60)
            } else {
                $etaText = " ~{0:N0}s left" -f $etaSeconds
            }
        } else {
            $etaText = ""
        }
    } else {
        $percent = 0
        $progressText = "[$current]"
        $etaText = ""
    }

    # Compact output
    $displayMsg = if ($Message) { ": $Message" } else { "" }
    Write-Host "  $icon $progressText $ItemName$displayMsg$etaText" -ForegroundColor $color

    # Verbose mode: show extra details
    if ($script:VerboseProgress -and $VerboseDetail) {
        Write-Host "       $VerboseDetail" -ForegroundColor DarkGray
    }

    # Update Write-Progress bar if in console
    if ($total -gt 0) {
        $statusText = "$ItemName"
        if ($etaText) { $statusText += $etaText }
        Show-EnhancedProgress -Percent $percent -Activity $script:ProgressState.CurrentOperation -Status $statusText
    }
}

function Complete-ProgressOperation {
    <#
    .SYNOPSIS
        Complete the progress operation and show summary
    .PARAMETER ShowDetails
        Show detailed results for each item
    #>
    [CmdletBinding()]
    param(
        [switch]$ShowDetails
    )

    # Clear progress bar
    Close-EnhancedProgress

    # Show detailed results if requested
    if ($ShowDetails -and $script:ProgressState.Results.Count -gt 0) {
        Write-Host ""
        Write-Host "  Detailed Results:" -ForegroundColor Cyan
        $script:ProgressState.Results | ForEach-Object {
            $color = switch ($_.Status) {
                'Success' { 'Green' }
                'Failed' { 'Red' }
                'Skipped' { 'Yellow' }
                default { 'Gray' }
            }
            Write-Host "    [$($_.Status)] $($_.ItemName)" -ForegroundColor $color
        }
    }

    # Calculate duration
    $duration = (Get-Date) - $script:ProgressState.StartTime
    $durationStr = if ($duration.TotalMinutes -ge 1) {
        "{0:N1} min" -f $duration.TotalMinutes
    } else {
        "{0:N0} sec" -f $duration.TotalSeconds
    }

    # Summary
    Write-Host ""
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  $($script:ProgressState.CurrentOperation) Complete" -ForegroundColor Cyan
    Write-Host "  Duration: $durationStr" -ForegroundColor DarkGray

    $success = $script:ProgressState.SuccessCount
    $failed = $script:ProgressState.FailedCount
    $skipped = $script:ProgressState.SkippedCount

    Write-Host "  Success: $success | Failed: $failed | Skipped: $skipped" -ForegroundColor Gray
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray

    # Return summary object
    return [PSCustomObject]@{
        Operation = $script:ProgressState.CurrentOperation
        Duration = $duration
        Success = $success
        Failed = $failed
        Skipped = $skipped
        Total = $script:ProgressState.CompletedItems
        Results = $script:ProgressState.Results
    }
}

function Show-ProgressBar {
    <#
    .SYNOPSIS
        Display a simple text-based progress bar
    .PARAMETER Percent
        Percentage complete (0-100)
    .PARAMETER Width
        Width of the progress bar in characters
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Percent,
        [int]$Width = 40,
        [string]$Label = ""
    )

    $Percent = [math]::Max(0, [math]::Min(100, $Percent))
    $filled = [math]::Round($Width * $Percent / 100)
    $empty = $Width - $filled

    $bar = "#" * $filled + "-" * $empty
    $labelText = if ($Label) { " $Label" } else { "" }

    Write-Host "`r  [$bar] $Percent%$labelText" -NoNewline
}

function Show-EnhancedProgress {
    <#
    .SYNOPSIS
        Enhanced progress bar that works in PowerShell console, ISE, and EXE
    .PARAMETER Percent
        Percentage complete (0-100)
    .PARAMETER Activity
        Main activity description
    .PARAMETER Status
        Current status text
    .PARAMETER Width
        Width of console progress bar
    .PARAMETER UseGUI
        Force GUI progress bar
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Percent,
        [string]$Activity = "",
        [string]$Status = "",
        [int]$Width = 40,
        [switch]$UseGUI
    )

    $Percent = [math]::Max(0, [math]::Min(100, $Percent))

    # Method 1: Try Write-Progress first (works in PowerShell console)
    if ($Host.Name -eq 'ConsoleHost' -and -not $UseGUI -and -not $script:UseGUIProgress) {
        try {
            $progressStatus = if ($Status) { "$Status ($Percent%)" } else { "$Percent%" }
            Write-Progress -Activity $Activity -Status $progressStatus -PercentComplete $Percent
            return
        } catch {
            # Fall back to other methods if Write-Progress fails
            $null
        }
    }

    # Method 2: GUI Progress Bar for EXE or when requested
    if ($UseGUI -or $script:UseGUIProgress -or $Host.Name -ne 'ConsoleHost') {
        try {
            if (-not $script:ProgressForm) {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                Add-Type -AssemblyName System.Drawing -ErrorAction Stop

                $script:ProgressForm = New-Object System.Windows.Forms.Form
                $script:ProgressForm.Text = "System Optimizer Progress"
                $script:ProgressForm.Size = New-Object System.Drawing.Size(450, 120)
                $script:ProgressForm.StartPosition = "CenterScreen"
                $script:ProgressForm.FormBorderStyle = "FixedDialog"
                $script:ProgressForm.MaximizeBox = $false
                $script:ProgressForm.MinimizeBox = $false
                $script:ProgressForm.TopMost = $true

                $script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
                $script:ProgressBar.Location = New-Object System.Drawing.Point(15, 25)
                $script:ProgressBar.Size = New-Object System.Drawing.Size(400, 25)
                $script:ProgressBar.Style = "Continuous"
                $script:ProgressForm.Controls.Add($script:ProgressBar)

                $script:ProgressLabel = New-Object System.Windows.Forms.Label
                $script:ProgressLabel.Location = New-Object System.Drawing.Point(15, 55)
                $script:ProgressLabel.Size = New-Object System.Drawing.Size(400, 20)
                $script:ProgressLabel.TextAlign = "MiddleLeft"
                $script:ProgressForm.Controls.Add($script:ProgressLabel)

                $script:ProgressForm.Show()
                $script:ProgressForm.Refresh()
                $script:UseGUIProgress = $true
            }

            $script:ProgressBar.Value = $Percent
            $progressText = if ($Status) { "$Activity - $Status" } else { $Activity }
            $script:ProgressLabel.Text = "$progressText ($Percent%)"
            $script:ProgressForm.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
            return
        } catch {
            # Fall back to console if GUI fails
            $script:UseGUIProgress = $false
        }
    }

    # Method 3: Enhanced console progress bar with ANSI colors
    $filled = [math]::Round($Width * $Percent / 100)
    $empty = $Width - $filled

    # Try ANSI colors first (works in Windows Terminal, VS Code, modern consoles)
    try {
        if ($Host.UI.SupportsVirtualTerminal -or $env:WT_SESSION -or $env:TERM_PROGRAM) {
            $green = "`e[42m"      # Green background
            $darkGray = "`e[100m"  # Dark gray background
            $reset = "`e[0m"       # Reset colors
            $clearLine = "`e[2K`e[1G"  # Clear line and move to start

            $statusText = if ($Status) { " $Activity - $Status" } else { " $Activity" }
            Write-Host "$clearLine[$green$(' ' * $filled)$darkGray$(' ' * $empty)$reset] $Percent%$statusText" -NoNewline
            return
        }
    } catch {
        # Continue to fallback method
        $null
    }

    # Method 4: Fallback to Unicode characters
    try {
        $filledChar = "â–ˆ"  # Full block
        $emptyChar = "â–‘"   # Light shade
        $bar = $filledChar * $filled + $emptyChar * $empty
        $statusText = if ($Status) { " $Activity - $Status" } else { " $Activity" }
        Write-Host "`r[$bar] $Percent%$statusText" -NoNewline
    } catch {
        # Final fallback to basic ASCII
        $null
        $bar = "#" * $filled + "-" * $empty
        $statusText = if ($Status) { " $Activity - $Status" } else { " $Activity" }
        Write-Host "`r[$bar] $Percent%$statusText" -NoNewline
    }
}

function Confirm-ProgressCleanup {
    <#
    .SYNOPSIS
        Ensure all progress displays are properly closed and cleaned up
    .DESCRIPTION
        This function ensures that both the enhanced progress system and any
        lingering Write-Progress displays are properly closed. Should be called
        at the end of any operation that might have used progress displays.
    #>
    [CmdletBinding()]
    param()

    try {
        # Close enhanced progress system
        if (Get-Command 'Close-EnhancedProgress' -ErrorAction SilentlyContinue) {
            Close-EnhancedProgress
        }

        # Clear any lingering Write-Progress displays
        try {
            Write-Progress -Activity "Cleanup" -Completed
        } catch {
            # Ignore if Write-Progress not supported
            $null
        }

        # Force cleanup of any GUI elements that might be stuck
        if ($script:ProgressForm) {
            try {
                $script:ProgressForm.Close()
                $script:ProgressForm.Dispose()
                $script:ProgressForm = $null
                $script:ProgressBar = $null
                $script:ProgressLabel = $null
                $script:UseGUIProgress = $false
            } catch {
                # Ignore disposal errors
                $null
            }
        }

        # Force garbage collection to clean up any remaining GUI objects
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

    } catch {
        # Silently ignore any cleanup errors
        $null
    }
}

function Close-EnhancedProgress {
    <#
    .SYNOPSIS
        Close and cleanup progress displays
    #>
    [CmdletBinding()]
    param()

    # Close GUI progress if open
    if ($script:ProgressForm) {
        try {
            $script:ProgressForm.Close()
            $script:ProgressForm.Dispose()
        } catch {
            # Ignore disposal errors
            $null
        }
        $script:ProgressForm = $null
        $script:ProgressBar = $null
        $script:ProgressLabel = $null
        $script:UseGUIProgress = $false
    }

    # Clear Write-Progress
    try {
        Write-Progress -Activity "Complete" -Completed
    } catch {
        # Ignore if Write-Progress not supported
        $null
    }

    # New line after console progress (only if not using GUI)
    if (-not $script:UseGUIProgress) {
        Write-Host ""
    }
}

function Set-ProgressMode {
    <#
    .SYNOPSIS
        Set the preferred progress display mode
    .PARAMETER Mode
        Progress mode: Auto, Console, GUI
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Auto', 'Console', 'GUI')]
        [string]$Mode = 'Auto'
    )

    switch ($Mode) {
        'GUI' {
            $script:UseGUIProgress = $true
            Write-Host "  [i] Progress mode: GUI" -ForegroundColor Cyan
        }
        'Console' {
            $script:UseGUIProgress = $false
            Close-EnhancedProgress  # Close any open GUI
            Write-Host "  [i] Progress mode: Console" -ForegroundColor Cyan
        }
        'Auto' {
            $script:UseGUIProgress = $false
            Write-Host "  [i] Progress mode: Auto-detect" -ForegroundColor Cyan
        }
    }
}

function Write-ProgressLog {
    <#
    .SYNOPSIS
        Write a progress message with timestamp and status icon
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Section')]
        [string]$Type = 'Info'
    )

    $time = Get-Date -Format "HH:mm:ss"

    switch ($Type) {
        'Success' {
            Write-Host "  [$time] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[OK] " -ForegroundColor Green -NoNewline
            Write-Host $Message
        }
        'Warning' {
            Write-Host "  [$time] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[!] " -ForegroundColor Yellow -NoNewline
            Write-Host $Message
        }
        'Error' {
            Write-Host "  [$time] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[X] " -ForegroundColor Red -NoNewline
            Write-Host $Message
        }
        'Section' {
            Write-Host ""
            Write-Host "  [$time] === $Message ===" -ForegroundColor Cyan
        }
        default {
            Write-Host "  [$time] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[-] $Message"
        }
    }
}

# ============================================================================
# DOWNLOAD HELPER WITH PROGRESS
# ============================================================================
function Start-Download {
    <#
    .SYNOPSIS
        Download a file with progress bar display
    .PARAMETER Url
        URL to download from
    .PARAMETER OutFile
        Path to save the downloaded file
    .PARAMETER Description
        Optional description to show during download
    .EXAMPLE
        Start-Download -Url "https://example.com/file.exe" -OutFile "C:\temp\file.exe" -Description "MyApp"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$OutFile,
        [string]$Description = ""
    )

    $fileName = Split-Path $OutFile -Leaf
    $displayName = if ($Description) { $Description } else { $fileName }

    try {
        # Ensure directory exists
        $outDir = Split-Path $OutFile -Parent
        if ($outDir -and -not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }

        Write-Host "  Downloading: $displayName" -ForegroundColor Cyan

        # Try BITS transfer first (shows progress natively)
        $useBits = Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue

        if ($useBits) {
            try {
                Start-BitsTransfer -Source $Url -Destination $OutFile -DisplayName $displayName -Description "Downloading $fileName"
                Write-Host "  [OK] Downloaded: $displayName" -ForegroundColor Green
                return $true
            } catch {
                # Fall back to WebRequest if BITS fails
                $null
            }
        }

        # Fallback: Invoke-WebRequest with manual progress
        $webClient = New-Object System.Net.WebClient

        # Get file size first
        try {
            $request = [System.Net.WebRequest]::Create($Url)
            $request.Method = "HEAD"
            $response = $request.GetResponse()
            $totalBytes = $response.ContentLength
            $response.Close()
        } catch {
            $totalBytes = -1
        }

        if ($totalBytes -gt 0) {
            $totalMB = [math]::Round($totalBytes / 1MB, 2)
            Write-Host "  Size: $totalMB MB" -ForegroundColor DarkGray
        }

        # Download with progress callback
        $startTime = Get-Date
        $lastUpdate = Get-Date

        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
            $percent = $EventArgs.ProgressPercentage
            $received = $EventArgs.BytesReceived
            $total = $EventArgs.TotalBytesToReceive

            # Update every 500ms to avoid console spam
            $now = Get-Date
            if (($now - $script:lastUpdate).TotalMilliseconds -ge 500 -or $percent -eq 100) {
                $script:lastUpdate = $now
                $receivedMB = [math]::Round($received / 1MB, 1)
                $totalMB = [math]::Round($total / 1MB, 1)

                # Calculate speed
                $elapsed = ($now - $script:startTime).TotalSeconds
                if ($elapsed -gt 0) {
                    $speed = [math]::Round(($received / 1MB) / $elapsed, 2)
                    $speedText = "${speed} MB/s"
                } else {
                    $speedText = ""
                }

                # Progress bar
                $width = 30
                $filled = [math]::Round($width * $percent / 100)
                $empty = $width - $filled
                $bar = "#" * $filled + "-" * $empty

                Write-Host "`r  [$bar] $percent% - $receivedMB/$totalMB MB - $speedText    " -NoNewline
            }
        } | Out-Null

        Register-ObjectEvent -InputObject $webClient -EventName DownloadFileCompleted -Action {
            Write-Host ""  # New line after progress
        } | Out-Null

        # Start async download and wait
        $webClient.DownloadFileAsync([Uri]$Url, $OutFile)

        while ($webClient.IsBusy) {
            Start-Sleep -Milliseconds 100
        }

        # Cleanup events
        Get-EventSubscriber | Where-Object { $_.SourceObject -eq $webClient } | Unregister-Event

        if (Test-Path $OutFile) {
            Write-Host "  [OK] Downloaded: $displayName" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  [X] Download failed: $displayName" -ForegroundColor Red
            return $false
        }

    } catch {
        Write-Host "  [X] Download error: $($_.Exception.Message)" -ForegroundColor Red

        # Last resort fallback - simple Invoke-WebRequest
        try {
            Write-Host "  Retrying with basic download..." -ForegroundColor DarkYellow
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
            if (Test-Path $OutFile) {
                Write-Host "  [OK] Downloaded: $displayName" -ForegroundColor Green
                return $true
            }
        } catch {
            Write-Host "  [X] All download methods failed" -ForegroundColor Red
        }

        return $false
    }
}

function Start-AllOptimization {
    Write-Log "RUNNING ALL OPTIMIZATIONS" "SECTION"
    Write-Host ""
    Write-Host "This will apply ALL optimizations. Some changes require a reboot." -ForegroundColor Yellow
    Write-Host ""

    # Initialize rollback tracking
    if (Get-Command 'Initialize-RollbackSystem' -ErrorAction SilentlyContinue) {
        $sessionId = Initialize-RollbackSystem -OperationName "AllOptimizations"
        Write-Host "[Rollback] Session started: $sessionId" -ForegroundColor DarkGray

        # Optional restore point
        New-OptionalRestorePoint -Description "Before System Optimizer - All Optimizations"
    }

    Write-Host ""
    Write-Host "Press any key to continue or Ctrl+C to cancel..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

    Disable-Telemetry
    Disable-Services
    Remove-BloatwareApps
    Disable-ScheduledTasks
    Set-RegistryOptimizations
    Disable-VBS
    Set-NetworkOptimizations

    # Save rollback session
    if (Get-Command 'Save-RollbackSession' -ErrorAction SilentlyContinue) {
        Save-RollbackSession
        Write-Host "[Rollback] Undo script saved - use menu option [36] to rollback" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Log "ALL OPTIMIZATIONS COMPLETED" "SECTION"
    Write-Host ""
    Write-Host "A reboot is recommended to apply all changes." -ForegroundColor Yellow
    Write-Host ""

    $reboot = Read-Host "Reboot now? (Y/N)"
    if ($reboot -eq "Y" -or $reboot -eq "y") {
        Write-Log "Rebooting system..."
        Restart-Computer -Force
    }
}

function Start-FullSetup {
    Write-Log "RUNNING FULL SETUP WORKFLOW" "SECTION"
    Write-Host ""
    Write-Host "This will run the full setup workflow:" -ForegroundColor Yellow
    Write-Host "  1. PatchMyPC (install/update software)" -ForegroundColor Gray
    Write-Host "  2. Office Tool Plus (install Office)" -ForegroundColor Gray
    Write-Host "  3. Re-run Services optimization" -ForegroundColor Gray
    Write-Host "  4. Microsoft Activation Script (MAS)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press any key to continue or Ctrl+C to cancel..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

    # Step 1: PatchMyPC
    Write-Host ""
    Write-Host "=== STEP 1: PatchMyPC ===" -ForegroundColor Cyan
    Write-Host "Install/update common software first." -ForegroundColor Gray
    Start-PatchMyPC

    Write-Host ""
    Write-Host "Press any key when PatchMyPC is done..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

    # Step 2: Office Tool Plus
    Write-Host ""
    Write-Host "=== STEP 2: Office Tool Plus ===" -ForegroundColor Cyan
    Write-Host "Install Microsoft Office." -ForegroundColor Gray
    Start-OfficeTool

    Write-Host ""
    Write-Host "Press any key when Office installation is done..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

    # Step 3: Re-run Services optimization
    Write-Host ""
    Write-Host "=== STEP 3: Services Optimization ===" -ForegroundColor Cyan
    Write-Host "Re-running services optimization after software installs..." -ForegroundColor Gray
    Disable-Services

    # Step 4: MAS
    Write-Host ""
    Write-Host "=== STEP 4: Microsoft Activation Script ===" -ForegroundColor Cyan
    Write-Host "Activate Windows and Office." -ForegroundColor Gray
    Start-MAS

    Write-Host ""
    Write-Log "FULL SETUP WORKFLOW COMPLETED" "SECTION"
    Write-Host ""
}

function Start-MainMenu {
    do {
        Show-Menu
        $choice = Read-Host "Select an option"

        switch ($choice) {
            "1" { Start-AllOptimization }
            "2" { Disable-Telemetry }
            "3" { Disable-Services }
            "4" { Remove-BloatwareApps }
            "5" { Disable-ScheduledTasks }
            "6" { Set-RegistryOptimizations }
            "7" { Disable-VBS }
            "8" { Set-NetworkOptimizations }
            "9" { Remove-OneDrive }
            "10" { Start-SystemMaintenance }
            "11" { Start-PatchMyPC }
            "12" { Start-OfficeTool }
            "13" { Start-MAS }
            "14" { Get-WifiPasswords }
            "15" { Verify-OptimizationStatus }
            "16" { Start-FullSetup }
            "17" { Set-PowerPlan }
            "18" { Start-OOShutUp10 }
            "19" { Reset-GroupPolicy }
            "20" { Reset-WMI }
            "21" { Start-DiskCleanup }
            "22" { Set-WindowsUpdateControl }
            "23" { Start-SnappyDriverInstaller }
            "24" { Reset-Network }
            "25" { Repair-WindowsUpdate }
            "26" { Set-DefenderControl }
            "27" { Start-AdvancedDebloat }
            "28" { Sync-WinUtilServices }
            "29" { Start-DismPlusTweaks }
            "30" { Start-WindowsImageTool }
            "31" { Show-LogViewer }
            "32" { Start-UserProfileBackup }
            "33" { Show-ShutdownMenu }
            "0" {
                Write-Host "Exiting... Log saved to: $LogFile" -ForegroundColor Cyan
                return
            }
            default { Write-Host "Invalid option. Please try again." -ForegroundColor Red }
        }

        if ($choice -ne "0") {
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
    } while ($true)
}

# Export functions
Export-ModuleMember -Function @(
    'Start-AllOptimization',
    'Start-FullSetup',
    'Start-MainMenu',
    # Progress helpers
    'Start-ProgressOperation',
    'Update-ProgressItem',
    'Complete-ProgressOperation',
    'Show-ProgressBar',
    'Show-EnhancedProgress',
    'Close-EnhancedProgress',
    'Confirm-ProgressCleanup',
    'Set-ProgressMode',
    'Write-ProgressLog',
    'Set-VerboseProgress',
    'Get-VerboseProgress',
    # Download helper
    'Start-Download'
)


