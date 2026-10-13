param([switch]$Demo, [string]$CodexPath)
$ErrorActionPreference = 'Stop'
if (-not $Demo) {
    try {
        $watcherSignal=[Threading.EventWaitHandle]::OpenExisting('Local\RinCodexUsage-Watcher-Stop-v1')
        $watcherSignal.Dispose()
        Write-Output '宠物联动已运行，显示宠物后额度助手会自动启动。'
        return
    } catch [Threading.WaitHandleCannotBeOpenedException] { }
    $startupLink=Join-Path ([Environment]::GetFolderPath('Startup')) 'Rin Codex Usage.lnk'
    if (Test-Path -LiteralPath $startupLink) {
        $shell=New-Object -ComObject WScript.Shell
        try {
            $shortcut=$shell.CreateShortcut($startupLink)
            Start-Process -FilePath $shortcut.TargetPath -ArgumentList $shortcut.Arguments -WindowStyle Hidden | Out-Null
        } finally { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null }
        Write-Output '已恢复宠物联动。'
        return
    }
}
$scriptFile = Join-Path $PSScriptRoot 'UsageHelper.ps1'
$arguments = '-NoProfile -Sta -ExecutionPolicy Bypass -File "{0}"' -f $scriptFile
if ($Demo) { $arguments += ' -Demo' }
if ($CodexPath) {
    if ($CodexPath.Contains('"')) { throw 'Invalid Codex path.' }
    $arguments += ' -CodexPath "{0}"' -f $CodexPath
}
Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $arguments -WindowStyle Hidden | Out-Null
Write-Output '已启动额度助手。打开 Codex 内置宠物后，悬停 0.35 秒查看。右键托盘图标可刷新或退出。'
