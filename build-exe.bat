@echo off
REM ROGBLOX one-time exe builder
REM Double-click to compile launch.ps1 into a single ROGBLOX.exe
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0build-exe.ps1"
