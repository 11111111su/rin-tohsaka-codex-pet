function Get-RinTaskName {
    'RinCodexUsage-'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Get-RinAutoTask {
    Get-ScheduledTask -TaskName (Get-RinTaskName) -ErrorAction SilentlyContinue
}

function Get-RinInstallRoot {
    # Documents is shared with the unpackaged Windows scheduler; packaged LocalAppData can be virtualized.
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Codex\RinCodexUsage'
}

function Register-RinAutoTask {
    param([string]$InstallRoot, [string]$CodexPath)
    $executable=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    # Resolve the current user's data directory in the scheduled process itself.
    # Encoding the command avoids persisting fragile user-profile path quoting.
    $command="& (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Codex\RinCodexUsage\WatchPet.ps1')"
    if ($CodexPath) {
        if ($CodexPath.Contains('"')) { throw 'Invalid Codex path.' }
        $command+=" -CodexPath '"+$CodexPath.Replace("'","''")+"'"
    }
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $arguments='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand '+$encoded
    $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    # All script resources use PSScriptRoot; leave the scheduler's working directory unset.
    $action=New-ScheduledTaskAction -Execute $executable -Argument $arguments
    $logon=New-ScheduledTaskTrigger -AtLogOn -User $user
    # Recover even after a normal unexpected launcher exit; IgnoreNew prevents duplicates.
    $recovery=New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddSeconds(30)) -RepetitionInterval ([TimeSpan]::FromMinutes(1))
    $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval ([TimeSpan]::FromMinutes(1))
    Register-ScheduledTask -TaskName (Get-RinTaskName) -Action $action -Trigger @($logon,$recovery) -Principal $principal -Settings $settings -Description 'Run the pet usage launcher independently of Codex; recover when it stops.' -Force -ErrorAction Stop | Out-Null
}

function Start-RinAutoTask {
    Enable-ScheduledTask -TaskName (Get-RinTaskName) -ErrorAction Stop | Out-Null
    Start-ScheduledTask -TaskName (Get-RinTaskName) -ErrorAction Stop
}
