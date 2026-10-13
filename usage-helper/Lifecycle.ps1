function New-PetSession {
    [PSCustomObject]@{ MissingSince=$null; Suppressed=$false; RetryAt=[DateTime]::MinValue }
}

function Get-PetAction {
    param($Session, [bool]$Visible, [bool]$HelperRunning, [DateTime]$Now=[DateTime]::UtcNow)
    if (-not $Visible) {
        if ($null -eq $Session.MissingSince) { $Session.MissingSince=$Now }
        if (($Now-$Session.MissingSince).TotalSeconds -ge 2) {
            $Session.Suppressed=$false
            if ($HelperRunning) { return 'Stop' }
        }
        return 'Wait'
    }
    $Session.MissingSince=$null
    if ($HelperRunning -or $Session.Suppressed -or $Now -lt $Session.RetryAt) { return 'Wait' }
    return 'Start'
}

function Get-VisiblePetWindow {
    param([string]$StatePath)
    # A close request also covers versions that retain an empty overlay window.
    # Missing/unreadable state never overrides a real visible native window.
    try {
        $state=Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        if ($state.'electron-avatar-overlay-open' -eq $false) { return $null }
    } catch { }
    return [RinUsage.Desktop]::FindPet()
}
