param([string]$CodexPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'AutoStart.ps1')
if ($CodexPath -and $CodexPath.Contains('"')) { throw 'Invalid Codex path.' }
$installRoot=Get-RinInstallRoot
$startupLink=Join-Path ([Environment]::GetFolderPath('Startup')) 'Rin Codex Usage.lnk'
& (Join-Path $PSScriptRoot 'stop.ps1') | Out-Null
New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
$files=@('Common.ps1','Lifecycle.ps1','AutoStart.ps1','Native.cs','RingGauge.cs','rin-usage.ico','VERSION','UsageHelper.ps1','WatchPet.ps1','start.ps1','stop.ps1','disable-auto.ps1')
foreach ($file in $files) {
    $source=Join-Path $PSScriptRoot $file
    $target=Join-Path $installRoot $file
    if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($target)) { Copy-Item -LiteralPath $source -Destination $target -Force }
}
Register-RinAutoTask $installRoot $CodexPath
if (Test-Path -LiteralPath $startupLink) { Remove-Item -LiteralPath $startupLink -Force }
Start-RinAutoTask
$ready=$false; $deadline=[DateTime]::UtcNow.AddSeconds(15)
while ([DateTime]::UtcNow -lt $deadline) {
    try {
        $signal=[Threading.EventWaitHandle]::OpenExisting('Local\RinCodexUsage-Watcher-Stop-v1')
        $signal.Dispose(); $ready=$true; break
    } catch [Threading.WaitHandleCannotBeOpenedException] { Start-Sleep -Milliseconds 300 }
}
if (-not $ready) { throw '启动器未能运行，请检查 Windows 任务计划程序中的 RinCodexUsage 任务。' }
Write-Output '已启用宠物联动及 Windows 独立启动任务，启动器退出后会自动恢复。'
