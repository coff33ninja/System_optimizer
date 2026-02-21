@echo off
:: ============================================================================
:: SYSTEM OPTIMIZER - LAUNCH METHODS
:: ============================================================================
:: This batch file provides multiple ways to launch System Optimizer
:: Supports interactive menu, direct run options, and GitHub download
:: ============================================================================

title System Optimizer - Launcher
color 0A
mode con cols=90 lines=40

echo.
echo ==================================================================================
echo   SYSTEM OPTIMIZER - LAUNCHER
echo ==================================================================================
echo.

:: Clean up temp files first
echo   [*] Cleaning up temp files...
if exist "%TEMP%\SystemOptimizer" rmdir /s /q "%TEMP%\SystemOptimizer" >nul 2>&1
if exist "C:\temp\test_exe" rmdir /s /q "C:\temp\test_exe" >nul 2>&1
del /q "%TEMP%\*SystemOptimizer*" >nul 2>&1
del /q "%TEMP%\*optimize*" >nul 2>&1
del /q "%TEMP%\*.cs" >nul 2>&1
echo   [+] Temp files cleaned

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo   [!] Administrator privileges required for System Optimizer!
    echo   [!] Requesting elevation...
    echo.
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo   [+] Administrator privileges confirmed
echo.

:menu
cls
echo.
echo ==================================================================================
echo   SYSTEM OPTIMIZER - LAUNCH METHODS MENU
echo ==================================================================================
echo.
echo   RECOMMENDED - Modular Version:
echo   [1] Start-SystemOptimizer.ps1 (Download from GitHub)
echo.
echo   Command-Line Options (Modular):
echo   [2] Run All Optimizations (non-interactive)
echo   [3] Run Telemetry Disable Only
echo   [4] Run Services Optimization Only
echo.
echo   Epic Backup Adventure:
echo   [5] Epic Backup Adventure (Smart Launch)
echo.
echo   [0] Exit
echo.
set /p choice="   Select method (0-5): "

if "%choice%"=="1" goto modular_download
if "%choice%"=="2" goto run_all
if "%choice%"=="3" goto run_telemetry
if "%choice%"=="4" goto run_services
if "%choice%"=="5" goto epic_backup
if "%choice%"=="0" goto exit
goto menu

:modular_download
cls
echo.
echo ==================================================================================
echo   MODULAR VERSION - Download from GitHub
echo ==================================================================================
echo.
echo   [*] Downloading Start-SystemOptimizer.ps1 and modules...
echo.
powershell -ExecutionPolicy Bypass -Command "try { $dest = \"$env:TEMP\SystemOptimizer\"; New-Item -ItemType Directory -Path $dest -Force | Out-Null; Write-Host '[*] Downloading entry point...' -ForegroundColor Yellow; irm 'https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/Start-SystemOptimizer.ps1' -OutFile \"$dest\Start-SystemOptimizer.ps1\"; Write-Host '[*] Downloading modules...' -ForegroundColor Yellow; $modules = @('Backup','Bloatware','Core','Drivers','Hardware','ImageTool','Installer','Logging','Maintenance','Network','OneDrive','Power','Privacy','Profiles','Registry','Rollback','Security','Services','Shutdown','Software','Tasks','Telemetry','UITweaks','Utilities','VBS','VHDDeploy','WindowsUpdate'); New-Item -ItemType Directory -Path \"$dest\modules\" -Force | Out-Null; foreach($m in $modules) { irm \"https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/modules/$m.psm1\" -OutFile \"$dest\modules\$m.psm1\" }; Write-Host '[+] Download complete!' -ForegroundColor Green; Set-Location $dest; & \"$dest\Start-SystemOptimizer.ps1\" } catch { Write-Host 'Error: ' $_.Exception.Message -ForegroundColor Red; pause }"
goto continue

:run_all
cls
echo.
echo ==================================================================================
echo   RUN ALL OPTIMIZATIONS (Non-Interactive)
echo ==================================================================================
echo.
if exist "Start-SystemOptimizer.ps1" (
    echo   [*] Running all optimizations...
    powershell -ExecutionPolicy Bypass -NoProfile -Command "& '.\Start-SystemOptimizer.ps1' -RunOption all"
) else (
    echo   [-] Start-SystemOptimizer.ps1 not found!
    pause
)
goto continue

:run_telemetry
cls
echo.
echo ==================================================================================
echo   RUN TELEMETRY DISABLE ONLY
echo ==================================================================================
echo.
if exist "Start-SystemOptimizer.ps1" (
    echo   [*] Disabling telemetry...
    powershell -ExecutionPolicy Bypass -NoProfile -Command "& '.\Start-SystemOptimizer.ps1' -RunOption telemetry"
) else (
    echo   [-] Start-SystemOptimizer.ps1 not found!
    pause
)
goto continue

:run_services
cls
echo.
echo ==================================================================================
echo   RUN SERVICES OPTIMIZATION ONLY
echo ==================================================================================
echo.
if exist "Start-SystemOptimizer.ps1" (
    echo   [*] Optimizing services...
    powershell -ExecutionPolicy Bypass -NoProfile -Command "& '.\Start-SystemOptimizer.ps1' -RunOption services"
) else (
    echo   [-] Start-SystemOptimizer.ps1 not found!
    pause
)
goto continue

:epic_backup
cls
echo.
echo ==================================================================================
echo   EPIC BACKUP ADVENTURE
echo ==================================================================================
echo.
if exist "configs\experiments\fun-backup-system\Epic_Backup_Adventure.ps1" (
    echo   [+] Local Epic Backup Adventure found!
    echo   [*] Launching...
    powershell -ExecutionPolicy Bypass -NoProfile -File ".\configs\experiments\fun-backup-system\Epic_Backup_Adventure.ps1"
) else (
    echo   [-] Local file not found, downloading from GitHub...
    powershell -ExecutionPolicy Bypass -Command "try { irm 'https://raw.githubusercontent.com/coff33ninja/System_Optimizer/main/configs/experiments/fun-backup-system/Epic_Backup_Adventure.ps1' | iex } catch { Write-Host 'Error: ' $_.Exception.Message -ForegroundColor Red; pause }"
)
goto continue

:continue
echo.
echo ==================================================================================
echo   EXECUTION COMPLETED
echo ==================================================================================
echo.
echo   [1] Return to menu
echo   [0] Exit
echo.
set /p continue_choice="   Select option: "
if "%continue_choice%"=="1" goto menu
goto exit

:exit
cls
echo.
echo ==================================================================================
echo   SYSTEM OPTIMIZER - GOODBYE
echo ==================================================================================
echo.
echo   Launch options:
echo   - Interactive menu: .\Start-SystemOptimizer.ps1
echo   - With options: .\Start-SystemOptimizer.ps1 -RunOption all
echo   - Show help: .\Start-SystemOptimizer.ps1 -Help
echo.
echo   Press any key to exit...
pause >nul
exit /b
