$ErrorActionPreference='Stop'
$nvProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$nvRoot=Join-Path $nvProject '.cache/native-render-gap/original/nvapi-drs-a'
$nvSource=Join-Path $PSScriptRoot 'read-nvidia-drs.cpp'
$nvVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$nvVs=@(& $nvVsWhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/cl.exe')}|Select-Object -First 1
if(-not $nvVs){throw 'Pinned MSVC unavailable'}
$nvTools=Join-Path $nvVs 'VC/Tools/MSVC/14.50.35717'
$nvCompiler=Join-Path $nvTools 'bin/Hostx64/x64/cl.exe'
$nvSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$nvInclude=Get-ChildItem -LiteralPath (Join-Path $nvSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
$nvBeforeInclude=$env:INCLUDE;$nvBeforeLib=$env:LIB
$nvOutput=Join-Path $nvRoot 'read-nvidia-drs-msvc.exe'
$nvArguments=@('/nologo','/O2','/EHsc','/std:c++17','/MD',('/I'+(Join-Path $nvRoot 'sdk-b')),('/Fo'+(Join-Path $nvRoot 'read-nvidia-drs-msvc.obj')),('/Fe'+$nvOutput),$nvSource,'/link','/INCREMENTAL:NO')
try {
 $env:INCLUDE=((Join-Path $nvTools 'include'),(Join-Path $nvInclude.FullName 'ucrt'),(Join-Path $nvInclude.FullName 'shared'),(Join-Path $nvInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $nvTools 'lib/x64'),(Join-Path $nvSdk ('Lib/'+$nvInclude.Name+'/ucrt/x64')),(Join-Path $nvSdk ('Lib/'+$nvInclude.Name+'/um/x64')))-join';'
 & $nvCompiler @nvArguments *> (Join-Path $nvRoot 'compiler-msvc.log')
 $nvExit=$LASTEXITCODE
 if($nvExit -ne 0){Get-Content -LiteralPath (Join-Path $nvRoot 'compiler-msvc.log') -Tail 30;throw ('DRS helper compiler exit '+$nvExit)}
 $nvPins=Get-ChildItem -LiteralPath (Join-Path $nvRoot 'sdk-b') -File|ForEach-Object{@{name=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant();source=('https://raw.githubusercontent.com/NVIDIA/nvapi/main/'+$_.Name)}}
 @{version=1;compiler=$nvCompiler;compilerSha256=(Get-FileHash -LiteralPath $nvCompiler).Hash.ToLowerInvariant();source=$nvSource;sourceSha256=(Get-FileHash -LiteralPath $nvSource).Hash.ToLowerInvariant();headers=$nvPins;arguments=$nvArguments;exit=$nvExit;output=$nvOutput;outputSha256=(Get-FileHash -LiteralPath $nvOutput).Hash.ToLowerInvariant();scope='Private read-only DRS helper build. No driver/API calls or GPU tests yet.'}|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $nvRoot 'build-receipt.json') -Encoding utf8
 Write-Output ('Built private DRS helper '+$nvOutput)
} finally {$env:INCLUDE=$nvBeforeInclude;$env:LIB=$nvBeforeLib}
