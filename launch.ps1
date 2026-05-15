# ROGBLOX loader (Windows GUI)
# One window, one button: "Load and Launch Roblox".
# Click it -> installs the cheat into every detected executor's
# AutoExecute folder, then launches Roblox.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Repo = 'mkultra110/rogblox'
$Branch = 'main'
$RawBase = "https://raw.githubusercontent.com/$Repo/$Branch"
$Loader = 'loadstring(game:HttpGet("' + $RawBase + '/src/main.lua"))()'

function Get-ExecutorPaths {
    $l = $env:LOCALAPPDATA
    $r = $env:APPDATA
    $u = $env:USERPROFILE
    @(
        @{ Name='Synapse X';        Path="$l\Synapse X\autoexec" }
        @{ Name='Synapse';          Path="$l\Synapse\autoexec" }
        @{ Name='Wave';             Path="$l\Wave\autoexec" }
        @{ Name='Wave (Roaming)';   Path="$r\Wave\AutoExecute" }
        @{ Name='Krnl';             Path="$l\Krnl\autoexec" }
        @{ Name='Krnl (Roaming)';   Path="$r\Krnl\autoexec" }
        @{ Name='Fluxus';           Path="$l\Fluxus\autoexec" }
        @{ Name='Fluxus (Roaming)'; Path="$r\Fluxus\autoexec" }
        @{ Name='Script-Ware';      Path="$l\Script-Ware\Roblox\autoexec" }
        @{ Name='Solara';           Path="$l\Solara\autoexec" }
        @{ Name='Solara (Roaming)'; Path="$r\Solara\autoexec" }
        @{ Name='AWP.gg';           Path="$l\AWP\autoexec" }
        @{ Name='Xeno';             Path="$l\Xeno\autoexec" }
        @{ Name='Hydrogen';         Path="$u\Hydrogen\autoexec" }
        @{ Name='Delta';            Path="$l\Delta\autoexec" }
        @{ Name='CelerNB';          Path="$l\CelerNB\autoexec" }
    )
}

function Install-Cheat {
    $installed = @()
    foreach ($exe in Get-ExecutorPaths) {
        $parent = Split-Path $exe.Path -Parent
        if (Test-Path $parent) {
            try {
                if (-not (Test-Path $exe.Path)) {
                    New-Item -ItemType Directory -Force -Path $exe.Path | Out-Null
                }
                $target = Join-Path $exe.Path 'rogblox.lua'
                Set-Content -Path $target -Value $Loader -Encoding UTF8
                $installed += $exe.Name
            } catch {}
        }
    }
    return $installed
}

function Start-Roblox {
    try {
        Start-Process "roblox-player:1+launchmode:play" -ErrorAction Stop
        return $true
    } catch {
        try {
            Start-Process "roblox://" -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }
}

# ---------- UI ----------

$form = New-Object System.Windows.Forms.Form
$form.Text = "ROGBLOX Loader"
$form.Size = New-Object System.Drawing.Size(420, 280)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 24)
$form.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "ROGBLOX"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(180, 150, 255)
$title.Location = New-Object System.Drawing.Point(20, 16)
$title.Size = New-Object System.Drawing.Size(380, 32)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Roblox cheat hub - one click install"
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 160)
$subtitle.Location = New-Object System.Drawing.Point(20, 52)
$subtitle.Size = New-Object System.Drawing.Size(380, 18)
$form.Controls.Add($subtitle)

$button = New-Object System.Windows.Forms.Button
$button.Text = "Load and Launch Roblox"
$button.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$button.Location = New-Object System.Drawing.Point(20, 90)
$button.Size = New-Object System.Drawing.Size(360, 50)
$button.BackColor = [System.Drawing.Color]::FromArgb(120, 90, 220)
$button.ForeColor = [System.Drawing.Color]::White
$button.FlatStyle = "Flat"
$button.FlatAppearance.BorderSize = 0
$button.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($button)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Ready."
$status.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 160)
$status.Location = New-Object System.Drawing.Point(20, 156)
$status.Size = New-Object System.Drawing.Size(360, 60)
$status.TextAlign = "TopLeft"
$form.Controls.Add($status)

$button.Add_Click({
    $button.Enabled = $false
    $status.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 160)
    $status.Text = "Installing cheat into executor autoexec folders..."
    $form.Refresh()

    $installed = Install-Cheat
    try { Set-Clipboard -Value $Loader } catch {}

    if ($installed.Count -gt 0) {
        $status.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 140)
        $status.Text = "Installed to: " + ($installed -join ', ') + ".`nLoader copied to clipboard. Launching Roblox..."
    } else {
        $status.ForeColor = [System.Drawing.Color]::FromArgb(230, 180, 80)
        $status.Text = "No executor folders detected.`nLoader copied to clipboard - paste it manually. Launching Roblox..."
    }
    $form.Refresh()

    Start-Sleep -Milliseconds 600
    $ok = Start-Roblox
    if (-not $ok) {
        $status.ForeColor = [System.Drawing.Color]::FromArgb(230, 90, 90)
        $status.Text = "Could not launch Roblox. Open it manually."
    }
    $button.Enabled = $true
})

[void]$form.ShowDialog()
