$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'AutoStart.ps1')
& (Join-Path $PSScriptRoot 'stop.ps1') | Out-Null
if (Get-RinAutoTask) { Unregister-ScheduledTask -TaskName (Get-RinTaskName) -Confirm:$false -ErrorAction Stop }
$startupLink=Join-Path ([Environment]::GetFolderPath('Startup')) 'Rin Codex Usage.lnk'
if (Test-Path -LiteralPath $startupLink) { Remove-Item -LiteralPath $startupLink -Force }
Write-Output '已关闭宠物联动和 Windows 登录自动启动。'
