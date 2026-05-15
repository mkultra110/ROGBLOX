# ROGBLOX loader (Windows) — WPF gorgeous edition
# Beautiful dark glassmorphism UI with gradient accents, glow, and animations.
# Handles the "no executor installed" case with clear guidance.

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$Repo    = 'mkultra110/rogblox'
$Branch  = 'main'
$RawBase = "https://raw.githubusercontent.com/$Repo/$Branch"
$Loader  = 'loadstring(game:HttpGet("' + $RawBase + '/src/main.lua"))()'

function Get-ExecutorPaths {
    $l = $env:LOCALAPPDATA; $r = $env:APPDATA; $u = $env:USERPROFILE
    @(
        @{ Name='Synapse X';       Path="$l\Synapse X\autoexec" }
        @{ Name='Wave';            Path="$l\Wave\autoexec" }
        @{ Name='Wave (Roaming)';  Path="$r\Wave\AutoExecute" }
        @{ Name='Krnl';            Path="$l\Krnl\autoexec" }
        @{ Name='Krnl (Roaming)';  Path="$r\Krnl\autoexec" }
        @{ Name='Fluxus';          Path="$l\Fluxus\autoexec" }
        @{ Name='Fluxus (Roaming)';Path="$r\Fluxus\autoexec" }
        @{ Name='Script-Ware';     Path="$l\Script-Ware\Roblox\autoexec" }
        @{ Name='Solara';          Path="$l\Solara\autoexec" }
        @{ Name='AWP.gg';          Path="$l\AWP\autoexec" }
        @{ Name='Xeno';            Path="$l\Xeno\autoexec" }
        @{ Name='Hydrogen';        Path="$u\Hydrogen\autoexec" }
        @{ Name='Delta';           Path="$l\Delta\autoexec" }
        @{ Name='CelerNB';         Path="$l\CelerNB\autoexec" }
    )
}

function Find-DetectedExecutors {
    $found = @()
    foreach ($e in Get-ExecutorPaths) {
        $parent = Split-Path $e.Path -Parent
        if (Test-Path $parent) { $found += $e }
    }
    return $found
}

function Install-Cheat {
    $list = @()
    foreach ($e in Find-DetectedExecutors) {
        try {
            if (-not (Test-Path $e.Path)) { New-Item -ItemType Directory -Force -Path $e.Path | Out-Null }
            Set-Content -Path (Join-Path $e.Path 'rogblox.lua') -Value $Loader -Encoding UTF8
            $list += $e.Name
        } catch {}
    }
    return $list
}

function Start-Roblox {
    try { Start-Process "roblox-player:1+launchmode:play" -ErrorAction Stop; return $true }
    catch {
        try { Start-Process "roblox://"; return $true } catch { return $false }
    }
}

# ---------- XAML ----------

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ROGBLOX Loader"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" WindowStartupLocation="CenterScreen"
        Width="520" Height="460"
        FontFamily="Segoe UI">
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
        <SolidColorBrush x:Key="Panel" Color="#1E1E2A"/>
        <SolidColorBrush x:Key="Panel2" Color="#252535"/>
        <SolidColorBrush x:Key="Stroke" Color="#3A3A52"/>
        <SolidColorBrush x:Key="Text" Color="#ECECF5"/>
        <SolidColorBrush x:Key="Sub" Color="#9A9AB0"/>
        <SolidColorBrush x:Key="Dim" Color="#6A6A85"/>
        <SolidColorBrush x:Key="Good" Color="#6EE0A0"/>
        <SolidColorBrush x:Key="Warn" Color="#FFD06A"/>
        <SolidColorBrush x:Key="Bad"  Color="#FF6E78"/>

        <Style TargetType="Button" x:Key="BigAccent">
            <Setter Property="Background" Value="{StaticResource AccentBrush}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}"
                                CornerRadius="10">
                            <Border.Effect>
                                <DropShadowEffect Color="#7B57FF" BlurRadius="22" ShadowDepth="0" Opacity="0.55"/>
                            </Border.Effect>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="{StaticResource AccentHoverBrush}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="RenderTransform">
                                    <Setter.Value><ScaleTransform ScaleX="0.98" ScaleY="0.98"/></Setter.Value>
                                </Setter>
                                <Setter TargetName="b" Property="RenderTransformOrigin" Value="0.5,0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button" x:Key="LinkBtn">
            <Setter Property="Background" Value="{StaticResource Panel2}"/>
            <Setter Property="Foreground" Value="{StaticResource Text}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="5" Padding="10,4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#3A3A55"/>
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
                                <Setter Property="Foreground" Value="{StaticResource Text}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border CornerRadius="14" Background="{StaticResource BgBrush}" BorderBrush="{StaticResource Stroke}" BorderThickness="1">
        <Border.Effect>
            <DropShadowEffect Color="Black" BlurRadius="30" ShadowDepth="0" Opacity="0.6"/>
        </Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="36"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- title bar -->
            <Grid Grid.Row="0" x:Name="DragBar" Background="Transparent">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="ROGBLOX Loader" Foreground="{StaticResource Sub}"
                           FontSize="11" VerticalAlignment="Center" Margin="14,0,0,0"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="0,4,8,0">
                    <Button x:Name="BtnMin"   Style="{StaticResource WinBtn}" Content="&#xE921;"/>
                    <Button x:Name="BtnClose" Style="{StaticResource WinBtn}" Content="&#xE8BB;"/>
                </StackPanel>
            </Grid>

            <!-- body -->
            <StackPanel Grid.Row="1" Margin="28,8,28,18">
                <!-- logo -->
                <TextBlock Text="ROGBLOX" FontSize="38" FontWeight="Bold"
                           Foreground="{StaticResource LogoBrush}" HorizontalAlignment="Left">
                    <TextBlock.Effect>
                        <DropShadowEffect Color="#7B57FF" BlurRadius="24" ShadowDepth="0" Opacity="0.55"/>
                    </TextBlock.Effect>
                </TextBlock>
                <TextBlock Text="Roblox cheat hub — one click install"
                           Foreground="{StaticResource Sub}" FontSize="12" Margin="0,-2,0,18"/>

                <!-- big button -->
                <Button x:Name="BtnGo" Style="{StaticResource BigAccent}" Height="54" Content="Load and Launch Roblox"/>

                <!-- status panel -->
                <Border Margin="0,18,0,0" Background="{StaticResource Panel}" CornerRadius="8" BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                    <StackPanel Margin="14,12,14,12">
                        <TextBlock x:Name="StatusTitle" Text="Ready." Foreground="{StaticResource Text}" FontSize="13" FontWeight="SemiBold"/>
                        <TextBlock x:Name="StatusBody"  Text="Click the button above to install and launch." Foreground="{StaticResource Sub}" FontSize="11" Margin="0,4,0,0" TextWrapping="Wrap"/>

                        <!-- no-executor help panel (hidden by default) -->
                        <Border x:Name="HelpPanel" Margin="0,12,0,0" Background="{StaticResource Panel2}" CornerRadius="6" Padding="12,10" Visibility="Collapsed">
                            <StackPanel>
                                <TextBlock Foreground="{StaticResource Warn}" FontWeight="Bold" FontSize="12" Text="You need a Roblox executor"/>
                                <TextBlock Foreground="{StaticResource Sub}" FontSize="11" TextWrapping="Wrap" Margin="0,4,0,8"
                                           Text="Roblox doesn't run external scripts by itself. Install one of these free executors, then re-run this loader."/>
                                <StackPanel Orientation="Horizontal">
                                    <Button x:Name="LinkSolara" Style="{StaticResource LinkBtn}" Content="Solara"   Margin="0,0,6,0"/>
                                    <Button x:Name="LinkWave"   Style="{StaticResource LinkBtn}" Content="Wave"     Margin="0,0,6,0"/>
                                    <Button x:Name="LinkXeno"   Style="{StaticResource LinkBtn}" Content="Xeno"     Margin="0,0,6,0"/>
                                    <Button x:Name="LinkDelta"  Style="{StaticResource LinkBtn}" Content="Delta"    Margin="0,0,6,0"/>
                                    <Button x:Name="LinkBloxstrap" Style="{StaticResource LinkBtn}" Content="Bloxstrap"/>
                                </StackPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </Border>
            </StackPanel>

            <TextBlock Grid.Row="1" Text="v0.3.0" Foreground="{StaticResource Dim}" FontSize="10"
                       HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,16,8"/>
        </Grid>
    </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# control bindings
$DragBar    = $window.FindName('DragBar')
$BtnMin     = $window.FindName('BtnMin')
$BtnClose   = $window.FindName('BtnClose')
$BtnGo      = $window.FindName('BtnGo')
$StatusTitle= $window.FindName('StatusTitle')
$StatusBody = $window.FindName('StatusBody')
$HelpPanel  = $window.FindName('HelpPanel')

$DragBar.Add_MouseLeftButtonDown({ $window.DragMove() })
$BtnMin.Add_Click(  { $window.WindowState = 'Minimized' })
$BtnClose.Add_Click({ $window.Close() })

# executor links - point to a Google search so the user finds the current
# working build/community rather than hard-coding a URL that goes stale.
function Open-Search([string]$q) {
    Start-Process ("https://www.google.com/search?q=" + [uri]::EscapeDataString($q))
}
$window.FindName('LinkSolara'   ).Add_Click({ Open-Search 'Solara roblox executor download' })
$window.FindName('LinkWave'     ).Add_Click({ Open-Search 'Wave roblox executor download' })
$window.FindName('LinkXeno'     ).Add_Click({ Open-Search 'Xeno roblox executor download' })
$window.FindName('LinkDelta'    ).Add_Click({ Open-Search 'Delta roblox executor download' })
$window.FindName('LinkBloxstrap').Add_Click({ Open-Search 'Bloxstrap roblox launcher download' })

function Set-Status([string]$title, [string]$body, [string]$color = '#ECECF5') {
    $StatusTitle.Text = $title
    $StatusBody.Text  = $body
    $StatusTitle.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($color)
}

$BtnGo.Add_Click({
    $BtnGo.IsEnabled = $false
    Set-Status 'Installing...' 'Searching for executor folders and installing the cheat.'
    $HelpPanel.Visibility = 'Collapsed'
    $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)

    $installed = Install-Cheat
    try { Set-Clipboard -Value $Loader } catch {}

    if ($installed.Count -gt 0) {
        Set-Status ("Installed to " + $installed.Count + " executor(s)") `
                   ("✓ " + ($installed -join '   ✓ ') + "`n`nLauncher will start Roblox. Attach your executor in-game.") `
                   '#6EE0A0'
        Start-Sleep -Milliseconds 600
        $ok = Start-Roblox
        if (-not $ok) {
            Set-Status 'Could not launch Roblox' 'Open Roblox manually — the cheat is already installed.' '#FFD06A'
        }
    } else {
        Set-Status 'No executor installed' `
                   'Loader copied to clipboard. To run ROGBLOX you need a Roblox executor — click one below to download.' `
                   '#FFD06A'
        $HelpPanel.Visibility = 'Visible'
    }
    $BtnGo.IsEnabled = $true
})

# initial status reflects current state
$detected = Find-DetectedExecutors
if ($detected.Count -eq 0) {
    Set-Status 'No executor detected' `
               'Install one of the executors below first, then come back and click the button.' `
               '#FFD06A'
    $HelpPanel.Visibility = 'Visible'
} else {
    Set-Status ("Ready — " + $detected.Count + " executor(s) found") `
               ("Detected: " + ($detected.Name -join ', ')) `
               '#6EE0A0'
}

[void]$window.ShowDialog()
