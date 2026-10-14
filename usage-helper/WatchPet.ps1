param([string]$CodexPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Lifecycle.ps1')
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs') -ReferencedAssemblies System.dll,System.Core.dll,WindowsBase,UIAutomationClient,UIAutomationTypes
[RinUsage.Desktop]::EnableDpiAwareness()
$mutex=New-Object Threading.Mutex($false,'Local\RinCodexUsage-Watcher-v1')
$owned=$false
try { $owned=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned=$true }
if (-not $owned) { $mutex.Dispose(); return }
$stop=New-Object Threading.EventWaitHandle($false,[Threading.EventResetMode]::ManualReset,'Local\RinCodexUsage-Watcher-Stop-v1')
$stop.Reset() | Out-Null
$codexRoot=if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$statePath=Join-Path $codexRoot '.codex-global-state.json'
$session=New-PetSession
$child=$null
function Stop-OwnedHelper {
    if (-not $script:child) { return }
    if (-not $script:child.HasExited) {
        & (Join-Path $PSScriptRoot 'stop.ps1') -HelperOnly | Out-Null
        if (-not $script:child.WaitForExit(5000)) { $script:child.Kill(); $script:child.WaitForExit() }
    }
    $script:child.Dispose(); $script:child=$null
}
try {
    while (-not $stop.WaitOne(500)) {
        $now=[DateTime]::UtcNow
        if ($child -and $child.HasExited) {
            # A deliberate tray exit lasts until the pet is closed and opened again.
            if ($child.ExitCode -eq 0) { $session.Suppressed=$true }
            else { $session.RetryAt=$now.AddSeconds(10) }
            $child.Dispose(); $child=$null
        }
        $pet=Get-VisiblePetWindow $statePath
        $action=Get-PetAction $session ($null -ne $pet) ($null -ne $child) $now
        if ($action -eq 'Stop') { Stop-OwnedHelper }
        if ($action -eq 'Start') {
            try {
                $arguments='-NoProfile -Sta -ExecutionPolicy Bypass -File "{0}" -FollowPet -OwnerProcessId {1}' -f (Join-Path $PSScriptRoot 'UsageHelper.ps1'),$PID
                if ($CodexPath) {
                    if ($CodexPath.Contains('"')) { throw 'Invalid Codex path.' }
                    $arguments+=' -CodexPath "{0}"' -f $CodexPath
                }
                $child=[RinUsage.HiddenProcess]::Start((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'),$arguments)
            } catch { $session.RetryAt=$now.AddSeconds(10) }
        }
    }
} finally {
    Stop-OwnedHelper
    $stop.Dispose(); $mutex.ReleaseMutex(); $mutex.Dispose()
}
