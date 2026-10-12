$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
function Assert-Equal($Actual,$Expected,$Name) { if ($Actual -ne $Expected) { throw "$Name expected [$Expected], got [$Actual]" } }
$snapshot = '{"rateLimits":{"primary":{"usedPercent":99,"windowDurationMins":300}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":8,"windowDurationMins":300,"resetsAt":2000000000},"secondary":{"usedPercent":25,"windowDurationMins":10080}}}}' | ConvertFrom-Json
$rows = @(Get-UsageRows $snapshot)
Assert-Equal $rows.Count 2 'two windows'
Assert-Equal $rows[0].Remaining 92 'prefer account bucket'
Assert-Equal $rows[1].Remaining 75 'weekly remaining'
$originalCulture=[Threading.Thread]::CurrentThread.CurrentCulture
try {
    [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('fr-FR')
    $decimalSnapshot='{"rateLimits":{"primary":{"usedPercent":8.5}}}' | ConvertFrom-Json
    Assert-Equal (@(Get-UsageRows $decimalSnapshot)[0].Remaining) 91.5 'decimal usage across Windows locales'
} finally { [Threading.Thread]::CurrentThread.CurrentCulture=$originalCulture }
$unknown = '{"rateLimits":{"primary":{"usedPercent":null},"secondary":{"usedPercent":100,"windowDurationMins":10080}}}' | ConvertFrom-Json
$rows = @(Get-UsageRows $unknown)
Assert-Equal ($null -eq $rows[0].Remaining) $true 'unknown is not zero'
Assert-Equal $rows[1].Remaining 0 'exhausted is zero'
$one = '{"rateLimits":{"primary":null,"secondary":{"usedPercent":20,"windowDurationMins":10080}}}' | ConvertFrom-Json
$rows = @(Get-UsageRows $one)
Assert-Equal $rows.Count 1 'weekly-only account'
Assert-Equal $rows[0].Slot 'secondary' 'preserve weekly slot'
Assert-Equal (@(Get-UsageRows $null).Count) 0 'missing data'
$bad = '{"rateLimits":{"primary":{"usedPercent":120},"secondary":{"usedPercent":-10}}}' | ConvertFrom-Json
$rows = @(Get-UsageRows $bad)
Assert-Equal $rows[0].Remaining 0 'upper bound'
Assert-Equal $rows[1].Remaining 100 'lower bound'
Assert-Equal (Format-ResetTime $null) '重置时间暂不可用' 'unknown reset'
$now=[DateTimeOffset]::FromUnixTimeSeconds(2000000000)
Assert-Equal (Format-ResetTime 1999999999 $now) '已到重置时间，等待更新' 'expired reset'
$bounds = '{"byDisplayId":{"first":{"x":100,"y":100,"width":400,"height":320,"mascot":{"left":200,"top":10,"width":80,"height":87}}}}' | ConvertFrom-Json
$native=[PSCustomObject]@{Left=125;Top=125;Width=500;Height=400;Dpi=120}
$pet=Get-MascotRect $bounds $native
Assert-Equal $pet.Left 375 'DPI-scaled mascot x'
Assert-Equal $pet.Width 100 'DPI-scaled mascot size'
$native.Width=1000
Assert-Equal ($null -eq (Get-MascotRect $bounds $native)) $true 'reject stale geometry'
$area=[PSCustomObject]@{WorkLeft=-1920;WorkTop=0;WorkRight=0;WorkBottom=1080}
$pet=[PSCustomObject]@{Left=-100;Top=0;Width=80;Height=87}
$pos=Get-CardPosition $pet $area 272 200 12
Assert-Equal $pos.X -384 'flip at right edge on negative monitor'
Assert-Equal $pos.Y 0 'clamp top'
Assert-Equal (Test-PointInRect ([PSCustomObject]@{X=-90;Y=20}) $pet) $true 'hover inside'
Assert-Equal (Test-PointInRect ([PSCustomObject]@{X=-20;Y=20}) $pet) $false 'right edge outside'
$sample=[PSCustomObject]@{Left=100;Top=80}
$current=[PSCustomObject]@{Left=400;Top=200}
$mascot=[PSCustomObject]@{Left=130;Top=100;Width=100;Height=109}
$translated=Get-TranslatedMascot $mascot $current $sample
Assert-Equal $translated.Left 430 'follow live window between accessibility samples'
Assert-Equal $translated.Top 220 'follow vertical movement'
Assert-Equal $translated.Width 100 'preserve mascot size during movement'
$area=[PSCustomObject]@{WorkLeft=0;WorkTop=0;WorkRight=1920;WorkBottom=1080}
$offset=[PSCustomObject]@{X=40;Y=50}
$dragged=Get-DraggedMascot ([PSCustomObject]@{X=500;Y=600}) $offset $mascot $area
Assert-Equal $dragged.Left 460 'follow cursor with original grab point'
Assert-Equal $dragged.Top 550 'follow vertical drag'
$dragged=Get-DraggedMascot ([PSCustomObject]@{X=1930;Y=1100}) $offset $mascot $area
Assert-Equal $dragged.Left 1820 'clamp dragging at right edge'
Assert-Equal $dragged.Top 971 'clamp dragging at bottom edge'
Write-Output 'PASS: quota windows, missing/exhausted data, reset times, DPI, stale bounds, negative monitors, hover boundaries, live window movement and cursor-following drag.'
