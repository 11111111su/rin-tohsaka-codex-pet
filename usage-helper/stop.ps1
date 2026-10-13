param([switch]$Demo, [switch]$HelperOnly)
if (-not $Demo -and -not $HelperOnly) {
    try {
        $watcherSignal=[Threading.EventWaitHandle]::OpenExisting('Local\RinCodexUsage-Watcher-Stop-v1')
        try { $watcherSignal.Set() | Out-Null } finally { $watcherSignal.Dispose() }
        $watcherMutex=New-Object Threading.Mutex($false,'Local\RinCodexUsage-Watcher-v1')
        try {
            $watcherReleased=$false
            try { $watcherReleased=$watcherMutex.WaitOne(12000) } catch [Threading.AbandonedMutexException] { $watcherReleased=$true }
            if ($watcherReleased) { $watcherMutex.ReleaseMutex() } else { throw '自动启动器仍在退出。' }
        } finally { $watcherMutex.Dispose() }
    } catch [Threading.WaitHandleCannotBeOpenedException] { }
}
$eventName = if ($Demo) { 'Local\RinCodexUsage-Demo-Stop-v1' } else { 'Local\RinCodexUsage-Stop-v1' }
try {
    $signal = [Threading.EventWaitHandle]::OpenExisting($eventName)
    try { $signal.Set() | Out-Null } finally { $signal.Dispose() }
    $mutexName=if ($Demo) { 'Local\RinCodexUsage-Demo-v1' } else { 'Local\RinCodexUsage-v1' }
    $mutex=New-Object Threading.Mutex($false,$mutexName)
    try {
        $released=$false
        try { $released=$mutex.WaitOne(5000) } catch [Threading.AbandonedMutexException] { $released=$true }
        if ($released) { $mutex.ReleaseMutex() } else { Write-Warning '助手仍在退出，请稍后重试。' }
    } finally { $mutex.Dispose() }
    Write-Output '已通知额度助手退出。'
} catch [Threading.WaitHandleCannotBeOpenedException] { Write-Output '额度助手未运行。' }
