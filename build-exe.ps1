# build-exe.ps1
# Builds a single self-contained ROGBLOX.exe:
#   1. Bundle every Lua module into dist/rogblox.lua (bundle.ps1)
#   2. Inject the bundle into launch-bundled.ps1 (also bundle.ps1)
#   3. Compile launch-bundled.ps1 -> ROGBLOX.exe via PS2EXE
# Run once. Send the resulting .exe to anyone - no other files needed.

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$bundleScript = Join-Path $here 'bundle.ps1'
$bundledPs1   = Join-Path $here 'launch-bundled.ps1'
$outExe       = Join-Path $here 'ROGBLOX.exe'

Write-Host ''
Write-Host '  Building ROGBLOX.exe' -ForegroundColor Magenta
Write-Host '  -------------------' -ForegroundColor DarkMagenta
Write-Host ''

# Step 1: bundle
if (-not (Test-Path $bundleScript)) {
    Write-Host '[!] bundle.ps1 missing - repo is incomplete.' -ForegroundColor Red
    Read-Host 'Press Enter to close'; exit 1
}
& $bundleScript
if (-not (Test-Path $bundledPs1)) {
    Write-Host '[!] Bundling did not produce launch-bundled.ps1.' -ForegroundColor Red
    Read-Host 'Press Enter to close'; exit 1
}

# Step 2: ensure ps2exe is installed
$mod = Get-Module -ListAvailable -Name 'ps2exe' | Select-Object -First 1
if (-not $mod) {
    Write-Host '[*] Installing ps2exe (one-time)...' -ForegroundColor Cyan
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
    } catch {
        Write-Host ('[!] Could not install ps2exe: ' + $_) -ForegroundColor Yellow
        Write-Host '    Try running PowerShell as Admin and: Install-Module ps2exe -Scope AllUsers -Force'
        Read-Host 'Press Enter to close'; exit 1
    }
}
Import-Module ps2exe -Force

# Step 3: compile
Write-Host '[*] Compiling launch-bundled.ps1 -> ROGBLOX.exe ...' -ForegroundColor Cyan
try {
    Invoke-PS2EXE `
        -InputFile  $bundledPs1 `
        -OutputFile $outExe `
        -NoConsole `
        -Title       'ROGBLOX' `
        -Description 'ROGBLOX Loader' `
        -Company     'ROGBLOX' `
        -Product     'ROGBLOX Loader' `
        -Version     '0.4.0' `
        -STA `
        -SupportOS
} catch {
    Write-Host ('[!] Build failed: ' + $_) -ForegroundColor Red
    Read-Host 'Press Enter to close'; exit 1
}

if (Test-Path $outExe) {
    $size = [Math]::Round((Get-Item $outExe).Length / 1KB, 1)
    Write-Host ''
    Write-Host ("[+] Built ROGBLOX.exe  ($size KB)") -ForegroundColor Green
    Write-Host '    Self-contained - send it to friends. They just run it.' -ForegroundColor Green
    # tidy up the transient bundled .ps1 (the .exe is the artifact)
    Remove-Item $bundledPs1 -ErrorAction SilentlyContinue
} else {
    Write-Host '[!] PS2EXE finished but no output file produced.' -ForegroundColor Yellow
}

Write-Host ''
Read-Host 'Press Enter to close'
