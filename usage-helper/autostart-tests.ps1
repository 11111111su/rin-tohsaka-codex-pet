$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'AutoStart.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs') -ReferencedAssemblies System.dll,System.Core.dll,WindowsBase,UIAutomationClient,UIAutomationTypes
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
    $encoded=($task.Actions[0].Arguments -split ' ')[-1]
    $launchers=@(Get-CimInstance Win32_Process -Filter "Name='RinUsageLauncher.exe'" | Where-Object {
        $_.ExecutablePath -eq $task.Actions[0].Execute -and $_.CommandLine.Contains($encoded)
    })
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
        $_.ParentProcessId -in $launchers.ProcessId -and $_.CommandLine -and $_.CommandLine.Contains($encoded)
    })
}
function Assert-NoConsole($WatcherId,$HelperId) {
    $consoles=@(Get-CimInstance Win32_Process -Filter "Name='conhost.exe'" | Where-Object {
        $_.ParentProcessId -in @($WatcherId,$HelperId)
    })
    $ids=@($WatcherId,$HelperId)+@($consoles.ProcessId)
    if ([RinUsage.Desktop]::VisibleConsoleWindows([int[]]$ids).Length) { throw 'Launcher or helper exposed a console window.' }
    Write-Output 'PASS: launcher and helper have no visible console window'
}
function Get-OwnedHelper($WatcherId) {
    @(Get-CimInstance Win32_Process -Filter ('ParentProcessId='+$WatcherId) | Where-Object {
        $_.CommandLine -like '*UsageHelper.ps1*'
    })
}
$task=Get-RinAutoTask
if (-not $task) { throw 'Enable automatic startup before running this integration test.' }
if ([IO.Path]::GetFileName($task.Actions[0].Execute) -ne 'RinUsageLauncher.exe') { throw 'Task must use the console-free GUI launcher.' }
if ($task.Principal.RunLevel -ne 'Limited') { throw 'Task must use limited privileges.' }
if ($task.Settings.ExecutionTimeLimit -ne 'PT0S') { throw 'Long-running launcher must not have a scheduler time limit.' }
if ($task.Settings.MultipleInstances -ne 'IgnoreNew') { throw 'Duplicate launcher prevention is required.' }
if (-not ($task.Triggers | Where-Object { $_.Repetition.Interval -eq 'PT1M' })) { throw 'Missing recovery trigger.' }
Start-RinAutoTask
Assert-Eventually { @(Get-OwnedWatcher).Count -eq 1 } 'one independent scheduled watcher'
$watcher=@(Get-OwnedWatcher)[0]
Assert-Eventually { @(Get-OwnedHelper $watcher.ProcessId).Count -eq 1 } 'visible pet starts helper'
$oldHelper=@(Get-OwnedHelper $watcher.ProcessId)[0].ProcessId
Assert-NoConsole $watcher.ProcessId $oldHelper
# Only the verified launcher process for this exact registered task is terminated.
Stop-Process -Id $watcher.ProcessId -Force -ErrorAction Stop
Assert-Eventually { -not (Get-Process -Id $oldHelper -ErrorAction SilentlyContinue) } 'helper exits with lost launcher'
Assert-Eventually {
    $found=@(Get-OwnedWatcher)
    $found.Count -eq 1 -and $found[0].ProcessId -ne $watcher.ProcessId
} 'scheduler recovers terminated launcher' 90
$replacement=@(Get-OwnedWatcher)[0]
Assert-Eventually { @(Get-OwnedHelper $replacement.ProcessId).Count -eq 1 } 'recovered launcher restores helper'
Assert-NoConsole $replacement.ProcessId (@(Get-OwnedHelper $replacement.ProcessId)[0].ProcessId)
& (Join-Path $PSScriptRoot 'stop.ps1') | Out-Null
if ((Get-RinAutoTask).State -ne 'Disabled') { throw 'Manual stop must pause recovery.' }
Assert-Eventually { @(Get-OwnedWatcher).Count -eq 0 } 'manual stop removes launcher'
Start-RinAutoTask
Assert-Eventually { @(Get-OwnedWatcher).Count -eq 1 } 'explicit start resumes synchronization'
Write-Output 'PASS: independent startup, recovery, cleanup, and intentional pause.'
