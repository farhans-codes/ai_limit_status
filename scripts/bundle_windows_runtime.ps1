[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Destination
)

$ErrorActionPreference = 'Stop'

$destinationPath = (Resolve-Path -LiteralPath $Destination).Path
$vswherePath = Join-Path ${env:ProgramFiles(x86)} `
  'Microsoft Visual Studio\Installer\vswhere.exe'

if (-not (Test-Path -LiteralPath $vswherePath -PathType Leaf)) {
  throw "Could not find Visual Studio Installer at $vswherePath."
}

$visualStudioPath = & $vswherePath `
  -latest `
  -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationPath

if ([string]::IsNullOrWhiteSpace($visualStudioPath)) {
  throw 'Could not find a Visual Studio installation with the x64 C++ toolchain.'
}

$redistRoot = Join-Path $visualStudioPath 'VC\Redist\MSVC'
$crtDirectory = Get-ChildItem `
  -Path (Join-Path $redistRoot '*\x64\Microsoft.VC*.CRT') `
  -Directory `
  -ErrorAction SilentlyContinue |
  Sort-Object FullName -Descending |
  Select-Object -First 1

if ($null -eq $crtDirectory) {
  throw "Could not find the x64 Visual C++ runtime under $redistRoot."
}

$runtimeFiles = @(
  'msvcp140.dll',
  'vcruntime140.dll',
  'vcruntime140_1.dll'
)

foreach ($runtimeFile in $runtimeFiles) {
  $sourcePath = Join-Path $crtDirectory.FullName $runtimeFile
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Required Visual C++ runtime file is missing: $sourcePath"
  }

  Copy-Item `
    -LiteralPath $sourcePath `
    -Destination (Join-Path $destinationPath $runtimeFile) `
    -Force
}

Write-Host "Bundled Visual C++ runtime from $($crtDirectory.FullName):"
Get-Item ($runtimeFiles | ForEach-Object { Join-Path $destinationPath $_ }) |
  Select-Object Name, Length
