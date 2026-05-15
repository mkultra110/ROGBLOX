@echo off
REM ROGBLOX double-click launcher
REM Runs launch.ps1 with the right execution policy, no fuss.

setlocal
cd /d "%~dp0"

where powershell >nul 2>&1
if errorlevel 1 (
    echo PowerShell not found. Install PowerShell to use this launcher.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch.ps1" %*

echo.
pause
endlocal
