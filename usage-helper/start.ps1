param([switch]$Demo, [string]$CodexPath)
$ErrorActionPreference = 'Stop'
$scriptFile = Join-Path $PSScriptRoot 'UsageHelper.ps1'
$arguments = '-NoProfile -Sta -ExecutionPolicy Bypass -File "{0}"' -f $scriptFile
if ($Demo) { $arguments += ' -Demo' }
if ($CodexPath) {
    if ($CodexPath.Contains('"')) { throw 'Invalid Codex path.' }
    $arguments += ' -CodexPath "{0}"' -f $CodexPath
}
Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $arguments -WindowStyle Hidden | Out-Null
Write-Output '已启动额度助手。打开 Codex 内置宠物后，悬停 0.35 秒查看。右键托盘图标可刷新或退出。'
