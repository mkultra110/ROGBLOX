@echo off
REM ROGBLOX build script - compiles the pure C++ loader and copies
REM the resulting .exe to the repo root as ROGBLOX.exe.
REM
REM Requirements (one-time on this PC):
REM   - Visual Studio 2022 with the "Desktop development with C++" workload
REM   - CMake 3.20 or newer (bundled with VS, or from cmake.org)
REM
REM Double-click this file. The first run takes ~30 seconds; subsequent
REM rebuilds are much faster.

setlocal
cd /d "%~dp0"

echo.
echo   Building ROGBLOX.exe (C++)
echo   --------------------------
echo.

where cmake >nul 2>&1
if errorlevel 1 (
    echo [!] CMake not found in PATH.
    echo     Install CMake 3.20+ from https://cmake.org/download/
    echo     or open this folder from a Visual Studio Developer Prompt.
    pause
    exit /b 1
)

REM Step 1: regenerate the Lua bundle (the cheat itself, embedded into
REM the .exe at build time). Python is preferred; bundle.py is portable.
where python >nul 2>&1
if not errorlevel 1 (
    echo [*] Regenerating dist\rogblox.lua...
    python bundle.py || (
        echo [!] bundle.py failed.
        pause
        exit /b 1
    )
) else (
    echo [i] Python not found - skipping bundle regen.
    echo [i] Using existing dist\rogblox.lua.
    if not exist dist\rogblox.lua (
        echo [!] dist\rogblox.lua missing and Python unavailable.
        echo     Install Python 3.x from python.org and re-run.
        pause
        exit /b 1
    )
)

REM Step 2: configure + build with CMake
echo [*] Configuring CMake project...
cmake -S cpp -B cpp\build -A x64 || (
    echo [!] CMake configure failed.
    pause
    exit /b 1
)
echo [*] Compiling...
cmake --build cpp\build --config Release --target rogblox-loader || (
    echo [!] Build failed.
    pause
    exit /b 1
)

REM Step 3: copy the built loader to the repo root as ROGBLOX.exe
set BUILT=cpp\build\loader\Release\rogblox-loader.exe
if not exist "%BUILT%" (
    echo [!] Build finished but %BUILT% is missing.
    pause
    exit /b 1
)
copy /y "%BUILT%" ROGBLOX.exe >nul

echo.
echo [+] Built ROGBLOX.exe
echo     Double-click ROGBLOX.exe to launch the loader.
echo     Send it to friends - it's fully self-contained.
echo.
pause
endlocal
