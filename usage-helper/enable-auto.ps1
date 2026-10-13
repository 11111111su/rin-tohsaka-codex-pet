param([string]$CodexPath)
$ErrorActionPreference='Stop'
if ($CodexPath -and $CodexPath.Contains('"')) { throw 'Invalid Codex path.' }
$installRoot=Join-Path $env:LOCALAPPDATA 'RinCodexUsage'
$startupLink=Join-Path ([Environment]::GetFolderPath('Startup')) 'Rin Codex Usage.lnk'
& (Join-Path $PSScriptRoot 'stop.ps1') | Out-Null
New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
$files=@('Common.ps1','Lifecycle.ps1','Native.cs','RingGauge.cs','UsageHelper.ps1','WatchPet.ps1','start.ps1','stop.ps1','disable-auto.ps1')
foreach ($file in $files) {
    $source=Join-Path $PSScriptRoot $file
    $target=Join-Path $installRoot $file
    if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($target)) { Copy-Item -LiteralPath $source -Destination $target -Force }
}
$executable=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f (Join-Path $installRoot 'WatchPet.ps1')
if ($CodexPath) { $arguments+=' -CodexPath "{0}"' -f $CodexPath }
$shell=New-Object -ComObject WScript.Shell
try {
    $shortcut=$shell.CreateShortcut($startupLink)
    $shortcut.TargetPath=$executable; $shortcut.Arguments=$arguments
    $shortcut.WorkingDirectory=$installRoot; $shortcut.WindowStyle=7
    $shortcut.Description='Start the Codex usage helper when the built-in pet is visible.'
    $shortcut.Save()
} finally { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null }
Start-Process -FilePath $executable -ArgumentList $arguments -WindowStyle Hidden | Out-Null
Write-Output '已启用宠物联动：显示宠物时自动启动额度助手，关闭宠物或退出 Codex 后自动停止。下次登录 Windows 也会生效。'
