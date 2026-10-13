param([string]$PreviewPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'TrayIconArtwork.cs') -ReferencedAssemblies System.dll,System.Drawing
$frames=@(foreach ($size in @(16,20,24,32,40,48,64,256)) {
    $bitmap=[RinUsage.TrayIconArtwork]::Render($size)
    $stream=New-Object IO.MemoryStream
    try {
        $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
        [PSCustomObject]@{Size=$size;Bytes=$stream.ToArray()}
        if ($PreviewPath -and $size -eq 256) { $bitmap.Save($PreviewPath,[Drawing.Imaging.ImageFormat]::Png) }
    } finally { $bitmap.Dispose(); $stream.Dispose() }
})
$file=[IO.File]::Create((Join-Path $PSScriptRoot 'rin-usage.ico'))
$writer=New-Object IO.BinaryWriter($file)
try {
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$frames.Count)
    $offset=6+16*$frames.Count
    foreach ($frame in $frames) {
        $dimension=if ($frame.Size -eq 256) { 0 } else { $frame.Size }
        $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
        $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$frame.Bytes.Length); $writer.Write([uint32]$offset)
        $offset+=$frame.Bytes.Length
    }
    foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
} finally { $writer.Dispose() }
