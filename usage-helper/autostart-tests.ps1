$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'AutoStart.ps1')
function Assert-Eventually($Check,[string]$Name,[int]$Seconds=15) {
    $deadline=[DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (& $Check) { Write-Output ('PASS: '+$Name); return }
        Start-Sleep -Milliseconds 300
    }
    throw ('Timed out: '+$Name)
}
function Get-OwnedWatcher {
    $task=Get-RinAutoTask
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
        $_.CommandLine -and $_.CommandLine.TrimEnd().EndsWith($task.Actions[0].Arguments,[StringComparison]::OrdinalIgnoreCase)
    })
}
function Get-OwnedHelper($WatcherId) {
    @(Get-CimInstance Win32_Process -Filter ('ParentProcessId='+$WatcherId) | Where-Object {
        $_.CommandLine -like '*UsageHelper.ps1*'
    })
}
$task=Get-RinAutoTask
if (-not $task) { throw 'Enable automatic startup before running this integration test.' }
if ($task.Principal.RunLevel -ne 'Limited') { throw 'Task must use limited privileges.' }
if ($task.Settings.ExecutionTimeLimit -ne 'PT0S') { throw 'Long-running launcher must not have a scheduler time limit.' }
if ($task.Settings.MultipleInstances -ne 'IgnoreNew') { throw 'Duplicate launcher prevention is required.' }
if (-not ($task.Triggers | Where-Object { $_.Repetition.Interval -eq 'PT1M' })) { throw 'Missing recovery trigger.' }
Start-RinAutoTask
Assert-Eventually { @(Get-OwnedWatcher).Count -eq 1 } 'one independent scheduled watcher'
$watcher=@(Get-OwnedWatcher)[0]
Assert-Eventually { @(Get-OwnedHelper $watcher.ProcessId).Count -eq 1 } 'visible pet starts helper'
$oldHelper=@(Get-OwnedHelper $watcher.ProcessId)[0].ProcessId
# Only the verified launcher process for this exact registered task is terminated.
Stop-Process -Id $watcher.ProcessId -Force -ErrorAction Stop
Assert-Eventually { -not (Get-Process -Id $oldHelper -ErrorAction SilentlyContinue) } 'helper exits with lost launcher'
Assert-Eventually {
    $found=@(Get-OwnedWatcher)
    $found.Count -eq 1 -and $found[0].ProcessId -ne $watcher.ProcessId
} 'scheduler recovers terminated launcher' 90
$replacement=@(Get-OwnedWatcher)[0]
Assert-Eventually { @(Get-OwnedHelper $replacement.ProcessId).Count -eq 1 } 'recovered launcher restores helper'
& (Join-Path $PSScriptRoot 'stop.ps1') | Out-Null
if ((Get-RinAutoTask).State -ne 'Disabled') { throw 'Manual stop must pause recovery.' }
Assert-Eventually { @(Get-OwnedWatcher).Count -eq 0 } 'manual stop removes launcher'
Start-RinAutoTask
Assert-Eventually { @(Get-OwnedWatcher).Count -eq 1 } 'explicit start resumes synchronization'
Write-Output 'PASS: independent startup, recovery, cleanup, and intentional pause.'
