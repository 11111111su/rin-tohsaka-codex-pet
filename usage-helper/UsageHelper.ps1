param(
    [switch]$Once,
    [switch]$Diagnose,
    [switch]$Demo,
    [ValidateSet('normal','full','unknown','weekly')][string]$DemoCase='normal',
    [string]$PreviewPath,
    [string]$DiagnosticPath,
    [string]$CodexPath,
    [switch]$FollowPet,
    [int]$OwnerProcessId,
    [ValidateRange(30,600)][int]$RefreshSeconds=60
)
$ErrorActionPreference = 'Stop'
if ($PreviewPath -and -not $Demo) { throw '-PreviewPath requires -Demo.' }
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Lifecycle.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs') -ReferencedAssemblies System.dll,System.Core.dll,WindowsBase,UIAutomationClient,UIAutomationTypes
[RinUsage.Desktop]::EnableDpiAwareness()
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$statePath = Join-Path $codexHome '.codex-global-state.json'

if ($Diagnose) {
    $native = [RinUsage.Desktop]::FindPet()
    $bounds = $null; $requested = $false
    if (Test-Path -LiteralPath $statePath) {
        try { $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw '无法读取 Codex 宠物位置文件。' }
        $bounds = $state.'electron-avatar-overlay-bounds'; $requested = $state.'electron-avatar-overlay-open'
    }
    [PSCustomObject]@{
        CodexExecutable=Get-CodexExecutable $CodexPath; PetRequested=$requested
        PetWindow=$native; Mascot=Get-MascotRect $bounds $native
        AccessibleMascot=if ($native) { [RinUsage.Desktop]::AccessibleMascot($native.Handle) } else { $null }
    } | ConvertTo-Json -Depth 5
    return
}

if ($Once) {
    $rpc = New-Object RinUsage.RpcClient
    try {
        $rpc.Start((Get-CodexExecutable $CodexPath))
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ([DateTime]::UtcNow -lt $deadline -and $rpc.Running) {
            $line = $rpc.Take()
            if (-not $line) { Start-Sleep -Milliseconds 50; continue }
            try { $message = $line | ConvertFrom-Json } catch { continue }
            if ($message.id -eq 1) {
                if ($message.error) { throw 'Codex 初始化失败。请检查登录状态。' }
                $rpc.Send('{"method":"initialized","params":{}}')
                $rpc.Send('{"id":2,"method":"account/rateLimits/read"}')
            }
            if ($message.id -eq 2) {
                if ($message.error) { throw '额度读取失败。请在 Codex 中登录 ChatGPT 后重试。' }
                $rows = @(Get-UsageRows $message.result)
                if ($rows.Count -eq 0) { throw '当前账号未返回套餐额度窗口。' }
                $rows | ConvertTo-Json -Depth 3
                return
            }
        }
        throw 'Codex 额度读取超时（30 秒）。'
    } finally { $rpc.Dispose() }
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'RingGauge.cs') -ReferencedAssemblies System.dll,WindowsBase,PresentationCore,PresentationFramework,System.Xaml
$mutexName = if ($Demo) { 'Local\RinCodexUsage-Demo-v1' } else { 'Local\RinCodexUsage-v1' }
$mutex = New-Object Threading.Mutex($false, $mutexName)
$ownsMutex = $false
try { $ownsMutex = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
if (-not $ownsMutex) { $mutex.Dispose(); Write-Output '额度助手已经在运行。'; return }
$eventName = if ($Demo) { 'Local\RinCodexUsage-Demo-Stop-v1' } else { 'Local\RinCodexUsage-Stop-v1' }
$stopEvent = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $eventName)
$stopEvent.Reset() | Out-Null

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="远坂凛 · Codex 余量" Width="292" SizeToContent="Height"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" ShowInTaskbar="False" ShowActivated="False" Topmost="True">
  <Border Background="#FF231C24" BorderBrush="#FF443440" BorderThickness="1" CornerRadius="20" Padding="18,19,18,16">
    <StackPanel>
      <Grid Margin="0,0,0,18">
        <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <TextBlock Text="RIN / CODEX" FontSize="11" Foreground="#FFB5A6B0" VerticalAlignment="Center"/>
        <Path Grid.Column="1" Width="16" Height="16" Stretch="Uniform" Stroke="#FFBA405C" StrokeThickness="1.2" Data="M 1,6 L 5,1 L 11,1 L 15,6 L 8,15 Z M 1,6 L 15,6 M 5,1 L 6,6 L 8,15 M 11,1 L 10,6 L 8,15"/>
      </Grid>
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition x:Name="PrimaryColumn"/><ColumnDefinition x:Name="GapColumn" Width="18"/><ColumnDefinition x:Name="SecondaryColumn"/></Grid.ColumnDefinitions>
        <StackPanel x:Name="PrimaryRow" Grid.Column="0">
          <Grid Width="112" Height="112" HorizontalAlignment="Center">
            <ContentControl x:Name="PrimaryGaugeHost"/>
            <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
              <StackPanel Orientation="Horizontal" HorizontalAlignment="Center"><TextBlock x:Name="PrimaryValue" Text="—" FontSize="26" FontWeight="Medium" Foreground="#FFF3E9EE"/><TextBlock x:Name="PrimaryPercent" Text="%" FontSize="11" Foreground="#FFB5A6B0" VerticalAlignment="Bottom" Margin="2,0,0,5" Visibility="Collapsed"/></StackPanel>
              <TextBlock x:Name="PrimaryState" Text="读取中" FontSize="11" Foreground="#FFB5A6B0" HorizontalAlignment="Center"/>
            </StackPanel>
          </Grid>
          <TextBlock x:Name="PrimaryLabel" Text="5 小时" FontSize="12" Foreground="#FFF3E9EE" HorizontalAlignment="Center" Margin="0,10,0,0"/>
          <TextBlock x:Name="PrimaryReset" Text="等待更新" FontSize="11" Foreground="#FFB5A6B0" TextAlignment="Center" TextWrapping="Wrap" Margin="0,7,0,0"/>
          <TextBlock x:Name="PrimaryDate" FontSize="11" Foreground="#FF95838F" HorizontalAlignment="Center" Margin="0,4,0,0"/>
        </StackPanel>
        <StackPanel x:Name="SecondaryRow" Grid.Column="2">
          <Grid Width="112" Height="112" HorizontalAlignment="Center">
            <ContentControl x:Name="SecondaryGaugeHost"/>
            <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
              <StackPanel Orientation="Horizontal" HorizontalAlignment="Center"><TextBlock x:Name="SecondaryValue" Text="—" FontSize="26" FontWeight="Medium" Foreground="#FFF3E9EE"/><TextBlock x:Name="SecondaryPercent" Text="%" FontSize="11" Foreground="#FFB5A6B0" VerticalAlignment="Bottom" Margin="2,0,0,5" Visibility="Collapsed"/></StackPanel>
              <TextBlock x:Name="SecondaryState" Text="读取中" FontSize="11" Foreground="#FFB5A6B0" HorizontalAlignment="Center"/>
            </StackPanel>
          </Grid>
          <TextBlock x:Name="SecondaryLabel" Text="每周" FontSize="12" Foreground="#FFF3E9EE" HorizontalAlignment="Center" Margin="0,10,0,0"/>
          <TextBlock x:Name="SecondaryReset" Text="等待更新" FontSize="11" Foreground="#FFB5A6B0" TextAlignment="Center" TextWrapping="Wrap" Margin="0,7,0,0"/>
          <TextBlock x:Name="SecondaryDate" FontSize="11" Foreground="#FF95838F" HorizontalAlignment="Center" Margin="0,4,0,0"/>
        </StackPanel>
      </Grid>
      <Grid Margin="0,20,0,0">
        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/></Grid.ColumnDefinitions>
        <TextBlock Text="距离重置" FontSize="11" Foreground="#FFB5A6B0"/>
        <TextBlock x:Name="Freshness" Grid.Column="1" Text="正在连接 Codex…" FontSize="11" Foreground="#FFB5A6B0" HorizontalAlignment="Right" TextWrapping="Wrap" TextAlignment="Right" MaxWidth="185"/>
      </Grid>
    </StackPanel>
  </Border>
</Window>
'@
$reader = New-Object Xml.XmlNodeReader $xaml
$script:card = [Windows.Markup.XamlReader]::Load($reader)
$script:controls = @{}
foreach ($name in @('PrimaryRow','PrimaryColumn','PrimaryLabel','PrimaryValue','PrimaryPercent','PrimaryState','PrimaryGaugeHost','PrimaryReset','PrimaryDate','SecondaryRow','SecondaryColumn','SecondaryLabel','SecondaryValue','SecondaryPercent','SecondaryState','SecondaryGaugeHost','SecondaryReset','SecondaryDate','GapColumn','Freshness')) {
    $script:controls[$name] = $script:card.FindName($name)
}
$script:gauges=@{}
foreach ($prefix in @('Primary','Secondary')) {
    $gauge=New-Object RinUsage.RingGauge
    $gauge.Width=112; $gauge.Height=112
    if ($prefix -eq 'Secondary') {
        $gauge.ValueBrush=[Windows.Media.BrushConverter]::new().ConvertFromString('#FF9E759A')
        $gauge.GemColor=[Windows.Media.ColorConverter]::ConvertFromString('#FFB58EB6')
    }
    $script:controls[$prefix+'GaugeHost'].Content=$gauge
    $script:gauges[$prefix]=$gauge
}
$script:handle = 0L; $script:rpc = $null; $script:initialized = $false
$script:requestId = 2; $script:pending = $null; $script:pendingSince = [DateTime]::MinValue
$script:lastRequest = [DateTime]::MinValue; $script:lastUpdate = [DateTime]::MinValue
$script:retryAt = [DateTime]::MinValue; $script:snapshot = $null; $script:status = '正在连接 Codex…'
$script:stateWrite = [DateTime]::MinValue; $script:bounds = $null; $script:petClosed = $false
$script:lastStateCheck = [DateTime]::MinValue; $script:hoverSince = $null; $script:lastHover = [DateTime]::MinValue
$script:lastRender = [DateTime]::MinValue; $script:lastPosition = ''; $script:closing = $false
$script:lastErrorType = ''; $script:diagnosticPet = $null
$script:accessiblePet = $null; $script:lastAccessibleCheck = [DateTime]::MinValue
$script:missingPetSince=$null
$ownerProcess=if ($OwnerProcessId) { [Diagnostics.Process]::GetProcessById($OwnerProcessId) } else { $null }
$script:accessibleAnchor = $null
$script:dragActive=$false; $script:dragOffset=$null

function Request-Usage {
    if ($null -ne $script:pending -or -not $script:initialized) { return }
    $script:requestId++
    $script:rpc.Send(('{"id":' + $script:requestId + ',"method":"account/rateLimits/read"}'))
    $script:pending = $script:requestId; $script:pendingSince = [DateTime]::UtcNow
    $script:lastRequest = [DateTime]::UtcNow
}

function Reset-Connection {
    if ($script:rpc) { $script:rpc.Dispose(); $script:rpc = $null }
    $script:initialized = $false; $script:pending = $null
    $script:retryAt = [DateTime]::UtcNow.AddSeconds(30)
    $script:status = '暂时无法刷新 · 30 秒后重试'
}

function Update-Usage {
    $now = [DateTime]::UtcNow
    if ($null -eq $script:rpc) {
        if ($now -lt $script:retryAt) { return }
        try {
            $script:rpc = New-Object RinUsage.RpcClient
            $script:rpc.Start((Get-CodexExecutable $CodexPath))
            $script:pendingSince = $now
            $script:status = '正在连接 Codex…'
        } catch { Reset-Connection; return }
    }
    if (-not $script:rpc.Running) { Reset-Connection; return }
    for ($i=0; $i -lt 100; $i++) {
        $line = $script:rpc.Take(); if (-not $line) { break }
        try { $message = $line | ConvertFrom-Json } catch { continue }
        if ($message.id -eq 1) {
            if ($message.error) { Reset-Connection; return }
            $script:rpc.Send('{"method":"initialized","params":{}}')
            $script:initialized = $true; Request-Usage
        } elseif ($null -ne $script:pending -and $message.id -eq $script:pending) {
            $script:pending = $null
            if ($message.error) { Reset-Connection; return }
            $script:snapshot = $message.result; $script:lastUpdate = $now; $script:status = ''
        } elseif ($message.method -eq 'account/rateLimits/updated') {
            $script:snapshot = $message.params; $script:lastUpdate = $now; $script:status = ''
        }
    }
    if ((-not $script:initialized -or $null -ne $script:pending) -and ($now-$script:pendingSince).TotalSeconds -gt 25) { Reset-Connection; return }
    if (($now-$script:lastRequest).TotalSeconds -ge $RefreshSeconds) { Request-Usage }
}

function Render-Usage {
    $rows = @(Get-UsageRows $script:snapshot)
    foreach ($prefix in @('Primary','Secondary')) {
        $slot = $prefix.ToLowerInvariant()
        $row = $rows | Where-Object Slot -eq $slot | Select-Object -First 1
        $visible=$null -eq $script:snapshot -or $null -ne $row
        $script:controls[$prefix+'Row'].Visibility = if ($visible) { 'Visible' } else { 'Collapsed' }
        $script:controls[$prefix+'Column'].Width = if ($visible) { New-Object Windows.GridLength(1,[Windows.GridUnitType]::Star) } else { New-Object Windows.GridLength(0) }
        if ($row) {
            $script:controls[$prefix+'Label'].Text = $row.Label
            $known=$null -ne $row.Remaining
            $script:controls[$prefix+'Value'].Text = if ($known) { '{0:0.#}' -f $row.Remaining } else { '—' }
            $script:controls[$prefix+'Percent'].Visibility = if ($known) { 'Visible' } else { 'Collapsed' }
            $script:controls[$prefix+'State'].Visibility = if ($known) { 'Collapsed' } else { 'Visible' }
            $script:controls[$prefix+'State'].Text='暂不可用'
            $script:gauges[$prefix].Remaining = if ($known) { $row.Remaining } else { [double]::NaN }
            $reset=Get-ResetParts $row.ResetsAt
            $script:controls[$prefix+'Reset'].Text = $reset.Countdown
            $script:controls[$prefix+'Date'].Text = $reset.Timestamp
        }
    }
    $script:controls.GapColumn.Width=if ($script:controls.PrimaryRow.Visibility -eq 'Visible' -and $script:controls.SecondaryRow.Visibility -eq 'Visible') { New-Object Windows.GridLength(18) } else { New-Object Windows.GridLength(0) }
    $age = ([DateTime]::UtcNow-$script:lastUpdate).TotalSeconds
    $text = if ($Demo) { '示例数据' } elseif ($script:status) { $script:status } elseif ($rows.Count -eq 0) { '当前账号未返回套餐额度' } elseif ($age -gt [Math]::Max(90,$RefreshSeconds*2)) { '数据已过期 · 等待刷新' } else { '更新于 {0}' -f $script:lastUpdate.ToLocalTime().ToString('HH:mm:ss') }
    $script:controls.Freshness.Text = $text
    $script:card.UpdateLayout()
}

function Read-PetState {
    if (([DateTime]::UtcNow-$script:lastStateCheck).TotalMilliseconds -lt 500) { return }
    $script:lastStateCheck = [DateTime]::UtcNow
    try {
        $file = Get-Item -LiteralPath $statePath -ErrorAction Stop
        if ($file.LastWriteTimeUtc -ne $script:stateWrite) {
            $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $script:bounds = $state.'electron-avatar-overlay-bounds'
            $script:petClosed = $state.'electron-avatar-overlay-open' -eq $false
            $script:stateWrite = $file.LastWriteTimeUtc
        }
    } catch { $script:petClosed = $false; $script:bounds = $null }
}

function Update-Hover {
    Read-PetState
    $native = if (-not $script:petClosed) { [RinUsage.Desktop]::FindPet() } else { $null }
    if ($FollowPet) {
        if ($native) { $script:missingPetSince=$null }
        else {
            if ($null -eq $script:missingPetSince) { $script:missingPetSince=[DateTime]::UtcNow }
            if (([DateTime]::UtcNow-$script:missingPetSince).TotalSeconds -ge 2) { $script:card.Close(); return }
        }
    }
    $pet = Get-MascotRect $script:bounds $native
    if ($native -and -not $pet) {
        if (([DateTime]::UtcNow-$script:lastAccessibleCheck).TotalMilliseconds -ge 400) {
            $script:accessiblePet=[RinUsage.Desktop]::AccessibleMascot($native.Handle)
            $script:accessibleAnchor=$native
            $script:lastAccessibleCheck=[DateTime]::UtcNow
        }
        if ($script:accessiblePet -and $script:accessiblePet.Handle -eq $native.Handle) {
            $pet=Get-TranslatedMascot $script:accessiblePet $native $script:accessibleAnchor
        }
    }
    # A compact pet-only native window can be used even before saved detailed bounds exist.
    if ($native -and -not $pet -and $native.Width -le 200*$native.Dpi/96 -and $native.Height -le 250*$native.Dpi/96) { $pet = $native }
    $script:diagnosticPet = $pet
    if (-not $pet) { $script:card.Hide(); $script:hoverSince=$null; $script:dragActive=$false; return }
    $point = New-Object RinUsage.Desktop+Point
    [RinUsage.Desktop]::GetCursorPos([ref]$point) | Out-Null
    $buttonDown=[RinUsage.Desktop]::LeftButtonDown
    $overPet=Test-PointInRect $point $pet -Padding 3
    if ($buttonDown -and -not $script:dragActive -and $overPet -and [RinUsage.Desktop]::IsTopmostAtPet($native.Handle,$point.X,$point.Y,$script:handle)) {
        $script:dragActive=$true
        $script:dragOffset=[PSCustomObject]@{X=$point.X-$pet.Left;Y=$point.Y-$pet.Top}
    }
    if ($script:dragActive -and $buttonDown) {
        $pet=Get-DraggedMascot $point $script:dragOffset $pet $native
        $script:diagnosticPet=$pet
    } elseif ($script:dragActive) {
        $script:dragActive=$false; $script:lastAccessibleCheck=[DateTime]::MinValue
    }
    $hover = $script:dragActive -or ($overPet -and [RinUsage.Desktop]::IsTopmostAtPet($native.Handle,$point.X,$point.Y,$script:handle))
    $now = [DateTime]::UtcNow
    if ($hover) {
        if ($null -eq $script:hoverSince) { $script:hoverSince=$now }
        $script:lastHover=$now
    } else { $script:hoverSince=$null }
    $show = ($hover -and ($now-$script:hoverSince).TotalMilliseconds -ge 350) -or ($script:card.IsVisible -and ($now-$script:lastHover).TotalMilliseconds -lt 350)
    if (-not $show) { $script:card.Hide(); return }
    if (-not $script:card.IsVisible) {
        $script:card.Show(); $script:card.UpdateLayout(); $script:lastPosition=''
        if ([Windows.SystemParameters]::ClientAreaAnimation) {
            $fade=New-Object Windows.Media.Animation.DoubleAnimation
            $fade.From=0; $fade.To=1; $fade.Duration=[Windows.Duration]::new([TimeSpan]::FromMilliseconds(140))
            $fade.FillBehavior=[Windows.Media.Animation.FillBehavior]::Stop
            $script:card.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)
        }
    }
    $source = [Windows.PresentationSource]::FromVisual($script:card)
    $factor = $source.CompositionTarget.TransformToDevice.M11
    $width = [int][Math]::Ceiling($script:card.ActualWidth*$factor)
    $height = [int][Math]::Ceiling($script:card.ActualHeight*$factor)
    $position = Get-CardPosition $pet $native $width $height ([int](12*$factor))
    $signature = '{0},{1},{2},{3}' -f $position.X,$position.Y,$width,$height
    if ($signature -ne $script:lastPosition) { [RinUsage.Desktop]::Place($script:handle,$position.X,$position.Y,$width,$height); $script:lastPosition=$signature }
}

$script:card.Add_SourceInitialized({
    $script:handle = (New-Object Windows.Interop.WindowInteropHelper $script:card).Handle.ToInt64()
    [RinUsage.Desktop]::MakePassive($script:handle)
})
$tray = New-Object Windows.Forms.NotifyIcon
$trayIcon=New-Object Drawing.Icon((Join-Path $PSScriptRoot 'rin-usage.ico'),[Windows.Forms.SystemInformation]::SmallIconSize)
$tray.Icon = $trayIcon
$helperVersion=([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION'))).Trim()
$tray.Text = '远坂凛 · Codex 额度助手 v'+$helperVersion
$menu = New-Object Windows.Forms.ContextMenuStrip
$refreshItem = $menu.Items.Add('立即刷新')
$refreshItem.Add_Click({ $script:lastRequest=[DateTime]::MinValue })
$exitItem = $menu.Items.Add('退出额度助手')
$exitItem.Add_Click({ $script:card.Close() })
$tray.ContextMenuStrip = $menu; $tray.Visible = $true
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(100)
$timer.Add_Tick({
    try {
        if ($stopEvent.WaitOne(0)) { $script:card.Close(); return }
        if ($ownerProcess -and $ownerProcess.HasExited) { $script:card.Close(); return }
        if (-not $Demo -and $FollowPet) { Update-Hover; if ($script:closing) { return } }
        if (-not $Demo) { Update-Usage }
        if (([DateTime]::UtcNow-$script:lastRender).TotalSeconds -ge 1) {
            Render-Usage; $script:lastRender=[DateTime]::UtcNow
            if ($DiagnosticPath) {
                [PSCustomObject]@{Initialized=$script:initialized;Visible=$script:card.IsVisible;Pet=$script:diagnosticPet;Placement=$script:lastPosition;Card=[RinUsage.Desktop]::WindowRect($script:handle);Status=$script:status;LastUpdate=$script:lastUpdate.ToString('o');ErrorType=$script:lastErrorType} |
                    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $DiagnosticPath -Encoding UTF8
            }
        }
        if (-not $Demo -and -not $FollowPet) { Update-Hover }
        if ($PreviewPath) {
            $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$script:card.ActualWidth,[int]$script:card.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
            $bitmap.Render($script:card)
            $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
            $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
            $stream=[IO.File]::Create($PreviewPath)
            try { $encoder.Save($stream) } finally { $stream.Dispose() }
            $script:card.Close()
        }
    } catch {
        $script:lastErrorType=$_.Exception.GetType().Name
        $script:status='助手暂时无法更新 · 可从托盘退出'; $script:card.Hide()
        if ($PreviewPath) { Write-Output ('Preview failed: '+$script:lastErrorType); $script:card.Close() }
    }
})
$script:card.Add_Closed({ $script:closing=$true; $timer.Stop(); [Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() })
try {
    $script:card.Show(); $script:card.UpdateLayout()
    if ($Demo) {
        $script:snapshot = [PSCustomObject]@{rateLimits=[PSCustomObject]@{
            primary=[PSCustomObject]@{usedPercent=28;windowDurationMins=300;resetsAt=[DateTimeOffset]::Now.AddMinutes(138).ToUnixTimeSeconds()}
            secondary=[PSCustomObject]@{usedPercent=52;windowDurationMins=10080;resetsAt=[DateTimeOffset]::Now.AddHours(102).ToUnixTimeSeconds()}
        }}
        if ($DemoCase -eq 'full') { $script:snapshot.rateLimits.primary.usedPercent=0; $script:snapshot.rateLimits.secondary.usedPercent=100 }
        if ($DemoCase -eq 'unknown') { $script:snapshot.rateLimits.primary.usedPercent=$null; $script:snapshot.rateLimits.secondary.usedPercent=$null }
        if ($DemoCase -eq 'weekly') { $script:snapshot.rateLimits.primary=$null }
        $script:card.Left=450; $script:card.Top=220
    } else { $script:card.Hide() }
    Render-Usage; $timer.Start()
    [Windows.Threading.Dispatcher]::Run()
} finally {
    $timer.Stop(); $tray.Visible=$false; $tray.Dispose(); $trayIcon.Dispose(); $menu.Dispose()
    if ($script:rpc) { $script:rpc.Dispose() }
    if ($ownerProcess) { $ownerProcess.Dispose() }
    $stopEvent.Dispose(); if ($ownsMutex) { $mutex.ReleaseMutex() }; $mutex.Dispose()
}
