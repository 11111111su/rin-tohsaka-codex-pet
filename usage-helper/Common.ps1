function Get-CodexExecutable {
    param([string]$ExplicitPath)
    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) { throw 'Codex executable not found.' }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    $command = Get-Command codex.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    $running = Get-Process -Name codex -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if ($running) { return $running.Path }
    $binRoot = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (Test-Path -LiteralPath $binRoot) {
        $binary = Get-ChildItem -LiteralPath $binRoot -Filter codex.exe -Recurse -File |
            Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if ($binary) { return $binary.FullName }
    }
    $package = Get-AppxPackage 'OpenAI.Codex' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($package) {
        $binary = Join-Path $package.InstallLocation 'app\resources\codex.exe'
        if (Test-Path -LiteralPath $binary) { return $binary }
    }
    throw '未找到 Codex CLI。请启动 Codex，或通过 -CodexPath 指定 codex.exe。'
}

function Get-UsageRows {
    param($Snapshot)
    $bucket = $Snapshot.rateLimitsByLimitId.codex
    if ($null -eq $bucket) { $bucket = $Snapshot.rateLimits }
    if ($null -eq $bucket) { return @() }
    $rows = @()
    foreach ($slot in @('primary','secondary')) {
        $window = $bucket.$slot
        if ($null -eq $window) { continue }
        $minutes = $window.windowDurationMins
        $label = if ($minutes -eq 300) { '5 小时' } elseif ($minutes -eq 10080) { '每周' } elseif ($null -eq $minutes) { if ($slot -eq 'primary') { '短期额度' } else { '长期额度' } } else { '{0:g} 小时' -f ([double]$minutes / 60) }
        $remaining = $null
        if ($null -ne $window.usedPercent) {
            $used = 0.0
            $parsed = if ($window.usedPercent -is [ValueType]) { $used=[Convert]::ToDouble($window.usedPercent,[Globalization.CultureInfo]::InvariantCulture); $true } else { [double]::TryParse([string]$window.usedPercent, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$used) }
            if ($parsed -and -not [double]::IsNaN($used) -and -not [double]::IsInfinity($used)) {
                $remaining = [Math]::Max(0.0, [Math]::Min(100.0, 100.0 - $used))
            }
        }
        $rows += [PSCustomObject]@{ Label=$label; Remaining=$remaining; ResetsAt=$window.resetsAt; Slot=$slot }
    }
    return $rows
}

function Format-ResetTime {
    param($UnixSeconds, [DateTimeOffset]$Now = [DateTimeOffset]::Now)
    if ($null -eq $UnixSeconds) { return '重置时间暂不可用' }
    try { $reset = [DateTimeOffset]::FromUnixTimeSeconds([long]$UnixSeconds).ToLocalTime() } catch { return '重置时间暂不可用' }
    $seconds = ($reset - $Now).TotalSeconds
    if ($seconds -le 0) { return '已到重置时间，等待更新' }
    $minutes = [Math]::Ceiling($seconds / 60)
    $countdown = if ($minutes -ge 1440) { '{0} 天 {1} 小时' -f [Math]::Floor($minutes/1440), [Math]::Floor(($minutes%1440)/60) } elseif ($minutes -ge 60) { '{0} 小时 {1} 分' -f [Math]::Floor($minutes/60), ($minutes%60) } else { '{0} 分' -f $minutes }
    return '{0}后重置 · {1}' -f $countdown, $reset.ToString('MM-dd HH:mm')
}

function Get-MascotRect {
    param($Bounds, $Window)
    if ($null -eq $Bounds -or $null -eq $Window) { return $null }
    $candidates = @($Bounds)
    if ($Bounds.byDisplayId) { $candidates += @($Bounds.byDisplayId.PSObject.Properties | ForEach-Object { $_.Value }) }
    if ($Bounds.byResolution) { $candidates += @($Bounds.byResolution.PSObject.Properties | ForEach-Object { $_.Value }) }
    $scale = $Window.Dpi / 96.0
    $best = $null; $score = [double]::PositiveInfinity
    foreach ($entry in $candidates) {
        $mascot = $entry.mascot
        if ($null -eq $mascot -or $null -eq $entry.width -or $null -eq $entry.height) { continue }
        foreach ($factor in @($scale, 1.0) | Select-Object -Unique) {
            $delta = [Math]::Abs($Window.Width - $entry.width * $factor) + [Math]::Abs($Window.Height - $entry.height * $factor)
            # Same-sized historical windows are resolved against current position.
            $position = if ($null -ne $entry.x -and $null -ne $entry.y) { [Math]::Abs($Window.Left - $entry.x*$factor) + [Math]::Abs($Window.Top - $entry.y*$factor) } else { 100000 }
            $candidateScore = $delta * 100000 + $position
            if ($delta -le 8*$scale -and $mascot.width -gt 0 -and $mascot.height -gt 0 -and $candidateScore -lt $score) {
                $best = [PSCustomObject]@{ Left=$Window.Left + $mascot.left*$factor; Top=$Window.Top + $mascot.top*$factor; Width=$mascot.width*$factor; Height=$mascot.height*$factor }
                $score = $candidateScore
            }
        }
    }
    return $best
}

function Get-CardPosition {
    param($Pet, $WorkArea, [int]$Width, [int]$Height, [int]$Gap=12)
    $x = $Pet.Left + $Pet.Width + $Gap
    if ($x + $Width -gt $WorkArea.WorkRight) { $x = $Pet.Left - $Width - $Gap }
    $y = $Pet.Top + ($Pet.Height - $Height)/2
    $x = [Math]::Max($WorkArea.WorkLeft, [Math]::Min($x, $WorkArea.WorkRight-$Width))
    $y = [Math]::Max($WorkArea.WorkTop, [Math]::Min($y, $WorkArea.WorkBottom-$Height))
    return [PSCustomObject]@{X=[int]$x;Y=[int]$y}
}

function Test-PointInRect {
    param($Point, $Rect, [int]$Padding=0)
    return $null -ne $Rect -and $Point.X -ge ($Rect.Left-$Padding) -and $Point.X -lt ($Rect.Left+$Rect.Width+$Padding) -and $Point.Y -ge ($Rect.Top-$Padding) -and $Point.Y -lt ($Rect.Top+$Rect.Height+$Padding)
}

function Get-TranslatedMascot {
    param($Mascot, $CurrentWindow, $SampledWindow)
    return [PSCustomObject]@{
        Left=$Mascot.Left+$CurrentWindow.Left-$SampledWindow.Left
        Top=$Mascot.Top+$CurrentWindow.Top-$SampledWindow.Top
        Width=$Mascot.Width;Height=$Mascot.Height
    }
}

function Get-DraggedMascot {
    param($Point, $Offset, $Mascot, $WorkArea)
    return [PSCustomObject]@{
        Left=[Math]::Max($WorkArea.WorkLeft,[Math]::Min($Point.X-$Offset.X,$WorkArea.WorkRight-$Mascot.Width))
        Top=[Math]::Max($WorkArea.WorkTop,[Math]::Min($Point.Y-$Offset.Y,$WorkArea.WorkBottom-$Mascot.Height))
        Width=$Mascot.Width;Height=$Mascot.Height
    }
}
