# build-exe.ps1
# One-time builder: compiles launch.ps1 into a single ROGBLOX.exe using
# the ps2exe PowerShell module. Run this once, then keep ROGBLOX.exe and
# delete everything else if you want.

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$inFile  = Join-Path $here 'launch.ps1'
$outFile = Join-Path $here 'ROGBLOX.exe'

Write-Host ''
Write-Host '  Building ROGBLOX.exe ...' -ForegroundColor Magenta
Write-Host ''

if (-not (Test-Path $inFile)) {
    Write-Host '[!] launch.ps1 missing in this folder.' -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

# Install ps2exe if not present
$mod = Get-Module -ListAvailable -Name 'ps2exe' | Select-Object -First 1
if (-not $mod) {
    Write-Host '[*] Installing ps2exe module (one-time)...' -ForegroundColor Cyan
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
    } catch {
        Write-Host ('[!] Could not install ps2exe automatically: ' + $_) -ForegroundColor Yellow
        Write-Host '    Run this manually as Administrator:'
        Write-Host '        Install-Module -Name ps2exe -Scope AllUsers -Force'
        Read-Host 'Press Enter to close'
        exit 1
    }
}
Import-Module ps2exe -Force

Write-Host '[*] Compiling launch.ps1 -> ROGBLOX.exe ...' -ForegroundColor Cyan
try {
    Invoke-PS2EXE `
        -InputFile  $inFile `
        -OutputFile $outFile `
        -NoConsole `
        -Title 'ROGBLOX' `
        -Description 'ROGBLOX Loader' `
        -Company 'ROGBLOX' `
        -Product 'ROGBLOX Loader' `
        -Version '0.4.0' `
        -RequireAdmin:$false `
        -STA `
        -SupportOS
    if (Test-Path $outFile) {
        Write-Host ''
        Write-Host ('[+] Built: ' + $outFile) -ForegroundColor Green
        Write-Host '    Double-click ROGBLOX.exe to launch the loader.' -ForegroundColor Green
    } else {
        Write-Host '[!] Build finished but no output file produced.' -ForegroundColor Yellow
    }
} catch {
    Write-Host ('[!] Build failed: ' + $_) -ForegroundColor Red
}

Write-Host ''
Read-Host 'Press Enter to close'
