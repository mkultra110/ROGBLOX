# ROGBLOX launcher for Windows
# - Detects installed Roblox executors
# - Drops the autoexecute loader into each one's AutoExecute folder
# - Copies the loader one-liner to the clipboard
# - Optionally launches Roblox

[CmdletBinding()]
param(
    [string]$Branch = 'main',
    [string]$PlaceId,
    [switch]$LaunchRoblox,
    [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'
$Repo = 'mkultra110/rogblox'
$RawBase = "https://raw.githubusercontent.com/$Repo/$Branch"
$Loader = 'loadstring(game:HttpGet("' + $RawBase + '/src/main.lua"))()'

function Write-Banner {
    Write-Host ""
    Write-Host "  ____   ___   ____ ____  _     _____  __" -ForegroundColor Magenta
    Write-Host " |  _ \ / _ \ / ___| __ )| |   / _ \ \/ /" -ForegroundColor Magenta
    Write-Host " | |_) | | | | |  _|  _ \| |  | | | \  / " -ForegroundColor Magenta
    Write-Host " |  _ <| |_| | |_| | |_) | |__| |_| /  \ " -ForegroundColor Magenta
    Write-Host " |_| \_\\___/ \____|____/|_____\___/_/\_\" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "   Roblox cheat hub  -  $Branch" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-ExecutorPaths {
    $local = $env:LOCALAPPDATA
    $roaming = $env:APPDATA
    $userprofile = $env:USERPROFILE

    @(
        @{ Name = 'Synapse X';        Path = "$local\Synapse X\autoexec" }
        @{ Name = 'Synapse V3';       Path = "$local\Synapse\autoexec" }
        @{ Name = 'Wave';             Path = "$local\Wave\autoexec" }
        @{ Name = 'Wave (Roaming)';   Path = "$roaming\Wave\AutoExecute" }
        @{ Name = 'Krnl';             Path = "$local\Krnl\autoexec" }
        @{ Name = 'Krnl (Roaming)';   Path = "$roaming\Krnl\autoexec" }
        @{ Name = 'Fluxus';           Path = "$local\Fluxus\autoexec" }
        @{ Name = 'Fluxus (Roaming)'; Path = "$roaming\Fluxus\autoexec" }
        @{ Name = 'Script-Ware';      Path = "$local\Script-Ware\Roblox\autoexec" }
        @{ Name = 'Solara';           Path = "$local\Solara\autoexec" }
        @{ Name = 'Solara (Roaming)'; Path = "$roaming\Solara\autoexec" }
        @{ Name = 'AWP.gg';           Path = "$local\AWP\autoexec" }
        @{ Name = 'Xeno';             Path = "$local\Xeno\autoexec" }
        @{ Name = 'Hydrogen';         Path = "$userprofile\Hydrogen\autoexec" }
        @{ Name = 'Delta';            Path = "$local\Delta\autoexec" }
        @{ Name = 'CelerNB';          Path = "$local\CelerNB\autoexec" }
    )
}

function Install-Autoexec {
    Write-Host "[*] Searching for installed executors..." -ForegroundColor Cyan
    $found = 0
    foreach ($exe in Get-ExecutorPaths) {
        $parent = Split-Path $exe.Path -Parent
        if (Test-Path $parent) {
            try {
                if (-not (Test-Path $exe.Path)) {
                    New-Item -ItemType Directory -Force -Path $exe.Path | Out-Null
                }
                $target = Join-Path $exe.Path 'rogblox.lua'
                Set-Content -Path $target -Value $Loader -Encoding UTF8
                Write-Host "    [+] $($exe.Name) -> $target" -ForegroundColor Green
                $found++
            } catch {
                Write-Host "    [!] $($exe.Name) failed: $_" -ForegroundColor DarkYellow
            }
        }
    }
    if ($found -eq 0) {
        Write-Host "[!] No executor folders detected." -ForegroundColor Yellow
        Write-Host "    Paste the loader manually (it's on your clipboard)." -ForegroundColor Yellow
    } else {
        Write-Host "[*] Installed autoexec to $found executor(s)." -ForegroundColor Green
    }
}

function Copy-Loader {
    try {
        Set-Clipboard -Value $Loader
        Write-Host "[*] Loader copied to clipboard:" -ForegroundColor Cyan
        Write-Host "    $Loader" -ForegroundColor DarkGray
    } catch {
        Write-Host "[!] Could not copy to clipboard: $_" -ForegroundColor Yellow
        Write-Host "    $Loader"
    }
}

function Test-Loader {
    Write-Host "[*] Verifying loader URL is reachable..." -ForegroundColor Cyan
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/src/main.lua" -TimeoutSec 10 -Method Head
        if ($resp.StatusCode -eq 200) {
            Write-Host "    [+] OK ($($resp.StatusCode))" -ForegroundColor Green
        } else {
            Write-Host "    [!] HTTP $($resp.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    [!] Cannot reach $RawBase/src/main.lua" -ForegroundColor Yellow
        Write-Host "        ($_)" -ForegroundColor DarkGray
        Write-Host "    The repo may not be public yet, or this branch may not exist on origin." -ForegroundColor DarkGray
    }
}

function Start-Roblox {
    param([string]$PlaceId)
    Write-Host "[*] Launching Roblox..." -ForegroundColor Cyan
    if ($PlaceId) {
        $url = "roblox://placeId=$PlaceId"
        Start-Process $url
    } else {
        Start-Process "roblox-player:1+launchmode:play"
    }
}

Write-Banner

if (-not $NoInstall) { Install-Autoexec }
Copy-Loader
Test-Loader

if ($LaunchRoblox -or $PlaceId) {
    Start-Roblox -PlaceId $PlaceId
}

Write-Host ""
Write-Host "Ready. Inject your executor on a running Roblox client - the script" -ForegroundColor White
Write-Host "will autoexec on next attach, or you can paste from the clipboard." -ForegroundColor White
Write-Host ""
Write-Host "Usage:" -ForegroundColor DarkGray
Write-Host "    .\launch.ps1                          (install autoexec + copy loader)" -ForegroundColor DarkGray
Write-Host "    .\launch.ps1 -LaunchRoblox            (also start Roblox)" -ForegroundColor DarkGray
Write-Host "    .\launch.ps1 -PlaceId 1818            (start a specific game)" -ForegroundColor DarkGray
Write-Host "    .\launch.ps1 -Branch dev              (use a different repo branch)" -ForegroundColor DarkGray
Write-Host "    .\launch.ps1 -NoInstall               (clipboard only)" -ForegroundColor DarkGray
Write-Host ""
