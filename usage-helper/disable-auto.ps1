$ErrorActionPreference='Stop'
$startupLink=Join-Path ([Environment]::GetFolderPath('Startup')) 'Rin Codex Usage.lnk'
if (Test-Path -LiteralPath $startupLink) { Remove-Item -LiteralPath $startupLink -Force }
& (Join-Path $PSScriptRoot 'stop.ps1') | Out-Null
Write-Output '已关闭宠物联动和 Windows 登录自动启动。'
