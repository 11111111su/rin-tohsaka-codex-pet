$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'HiddenLauncher.cs') -ReferencedAssemblies System.dll,System.Core.dll -OutputAssembly (Join-Path $PSScriptRoot 'RinUsageLauncher.exe') -OutputType WindowsApplication
