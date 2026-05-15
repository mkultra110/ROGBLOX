# ROGBLOX loader — single-button WPF UI.
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
    $list = @()
    foreach ($p in (Find-AutoexecFolders)) {
        try {
            if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
            Set-Content -Path (Join-Path $p 'rogblox.lua') -Value $Loader -Encoding UTF8
            $list += (Split-Path (Split-Path $p -Parent) -Leaf)
        } catch {}
    }
    return $list
}

function Start-Roblox {
    try { Start-Process 'roblox-player:1+launchmode:play' -ErrorAction Stop; return $true }
    catch { try { Start-Process 'roblox://' -ErrorAction Stop; return $true } catch { return $false } }
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
        if ($folders.Count -eq 0) {
            Set-Status "No executor installed yet. Opening Solara download in your browser.`nInstall it, then click Load again." $Warn
            Start-Process $ExecutorSearch
            return
        }

        $installed = Install-Cheat
        try { Set-Clipboard -Value $Loader } catch {}

        if ($installed.Count -eq 0) {
            Set-Status "Couldn't write to executor folder. Try running as admin." $Warn
            return
        }

        Set-Status ("Installed into " + ($installed -join ', ') + ". Launching Roblox...") $Good
        Start-Sleep -Milliseconds 400
        $ok = Start-Roblox
        if ($ok) {
            Set-Status ("Done. Roblox launching. Attach your executor inside the game.`nFrom now on: just open Roblox — the cheat loads itself.") $Good
        } else {
            Set-Status "Cheat installed. Open Roblox yourself (couldn't launch automatically)." $Warn
        }
    } finally {
        $BtnGo.IsEnabled = $true
    }
})

# Initial state — one-shot check just to update the status text
$initial = Find-AutoexecFolders
if ($initial.Count -gt 0) {
    Set-Status "Executor detected. Click Load." $Good
} else {
    Set-Status "Click Load — I'll set everything up." $Sub
}

[void]$window.ShowDialog()
