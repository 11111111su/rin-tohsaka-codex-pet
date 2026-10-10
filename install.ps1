param(
    [string]$DestinationRoot,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if (-not $DestinationRoot) {
    $DestinationRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
}
$source = Join-Path $PSScriptRoot 'rin-tohsaka'
$manifest = Get-Content -LiteralPath (Join-Path $source 'pet.json') -Raw | ConvertFrom-Json
if ($manifest.id -ne 'rin-tohsaka' -or $manifest.spriteVersionNumber -ne 2 -or $manifest.spritesheetPath -ne 'spritesheet.webp') {
    throw 'Unexpected pet manifest.'
}
$sprite = Join-Path $source 'spritesheet.webp'
if (-not (Test-Path -LiteralPath $sprite -PathType Leaf)) { throw 'Missing spritesheet.webp.' }
$destination = Join-Path (Join-Path $DestinationRoot 'pets') 'rin-tohsaka'
if ((Test-Path -LiteralPath $destination) -and -not $Force) {
    throw 'Pet already exists. Use -Force to overwrite it.'
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $source 'pet.json'),$sprite -Destination $destination -Force
Write-Host "Installed rin-tohsaka to: $destination"
Write-Host 'Restart Codex and select the pet.'
