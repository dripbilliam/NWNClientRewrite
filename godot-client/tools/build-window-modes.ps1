$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source=Join-Path $project 'native/window_modes.c'
$output=Join-Path $project '.cache/native-window'
$target=Join-Path $output 'nwn-window-modes.exe'
$manifest=Join-Path $output 'build-manifest.json'
$identity=@{source=(Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant();builder=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()}
if((Test-Path -LiteralPath $manifest)-and(Test-Path -LiteralPath $target)){
 $saved=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
 if($saved.source-eq$identity.source-and$saved.builder-eq$identity.builder-and$saved.binary-eq(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant()){Write-Output 'Native window-mode query already built';return}
}
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$visual=@(& $vswhere -all -prerelease -products '*' -property installationPath)|Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')}|Select-Object -First 1
if(-not$visual){throw 'MSVC unavailable'}
$version=(Get-Content -LiteralPath (Join-Path $visual 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$tools=Join-Path $visual ('VC/Tools/MSVC/'+$version)
$sdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$include=Get-ChildItem -LiteralPath (Join-Path $sdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$include){throw 'Windows SDK unavailable'}
$oldInclude=$env:INCLUDE;$oldLib=$env:LIB
try{
 $env:INCLUDE=((Join-Path $tools 'include'),(Join-Path $include.FullName 'ucrt'),(Join-Path $include.FullName 'shared'),(Join-Path $include.FullName 'um'))-join';'
 $env:LIB=((Join-Path $tools 'lib/x64'),(Join-Path $sdk ('Lib/'+$include.Name+'/ucrt/x64')),(Join-Path $sdk ('Lib/'+$include.Name+'/um/x64')))-join';'
 New-Item -ItemType Directory -Path $output -Force|Out-Null
 Push-Location $output
 try{& (Join-Path $tools 'bin/Hostx64/x64/cl.exe') /nologo /O2 /W4 /WX /TC /MD $source /Fe:nwn-window-modes.exe /link user32.lib /INCREMENTAL:NO;if($LASTEXITCODE-ne0){throw 'Native window-mode query build failed'}}finally{Pop-Location}
 $identity.binary=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant();$identity.compiler=$version
 $identity|ConvertTo-Json|Set-Content -LiteralPath $manifest -Encoding utf8
}finally{$env:INCLUDE=$oldInclude;$env:LIB=$oldLib}
Write-Output 'Native window-mode query built'
