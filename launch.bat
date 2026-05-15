@echo off
REM ROGBLOX loader - double-click to open
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%~dp0launch.ps1"
