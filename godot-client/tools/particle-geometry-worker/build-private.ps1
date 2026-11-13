param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label)
$ErrorActionPreference='Stop'
(Get-Process -Id $PID).PriorityClass='BelowNormal'
$kernelProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$kernelStage=Join-Path $kernelProject ('.cache/particle-geometry-worker/'+$Label)
if(Test-Path -LiteralPath $kernelStage){throw 'Private candidate already exists'}
New-Item -ItemType Directory -Path $kernelStage|Out-Null
Copy-Item -LiteralPath (Join-Path $kernelProject 'native') -Destination (Join-Path $kernelStage 'native') -Recurse
$kernelPins=@(Get-ChildItem -LiteralPath (Join-Path $kernelStage 'native') -File -Recurse|Where-Object{$_.Extension -in @('.cpp','.hpp','.gdextension')}|ForEach-Object{@{relative=$_.FullName.Substring($kernelStage.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
@{source=$kernelStage;pins=$kernelPins;createdUtc=[DateTime]::UtcNow.ToString('o');purpose='Opt-in particle geometry worker; accepted DLL untouched'}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $kernelStage 'source-pins.json') -Encoding utf8
$kernelOutput=Join-Path $kernelStage 'build';New-Item -ItemType Directory -Path $kernelOutput|Out-Null
$kernelApi=Join-Path $kernelProject '.tools/extension-api'
$kernelVs='C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717'
$kernelCompiler=Join-Path $kernelVs 'bin/Hostx64/x64/cl.exe'
if(-not(Test-Path -LiteralPath $kernelCompiler)){throw 'Pinned MSVC unavailable'}
$kernelSdk='C:\Program Files (x86)\Windows Kits\10'
$kernelInclude=Get-ChildItem -LiteralPath (Join-Path $kernelSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$kernelInclude){throw 'Windows SDK unavailable'}
$kernelPriorInclude=$env:INCLUDE;$kernelPriorLib=$env:LIB
try{
 $env:INCLUDE=((Join-Path $kernelVs 'include'),(Join-Path $kernelInclude.FullName 'ucrt'),(Join-Path $kernelInclude.FullName 'shared'),(Join-Path $kernelInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $kernelVs 'lib/x64'),(Join-Path $kernelSdk ('Lib/'+$kernelInclude.Name+'/ucrt/x64')),(Join-Path $kernelSdk ('Lib/'+$kernelInclude.Name+'/um/x64')))-join';'
 & $kernelCompiler /nologo /O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD ('/I'+$kernelApi) ('/Fo'+(Join-Path $kernelOutput 'particle-kernel.obj')) ('/Fe'+(Join-Path $kernelOutput 'nwn-particle-kernel.dll')) (Join-Path $kernelStage 'native/particle_kernel.cpp') /link /INCREMENTAL:NO ('/IMPLIB:'+(Join-Path $kernelOutput 'particle-kernel.lib')) 2>&1|Tee-Object -FilePath (Join-Path $kernelOutput 'compiler.log')
 if($LASTEXITCODE-ne0){throw ('Private compile failed '+$LASTEXITCODE)}
}finally{$env:INCLUDE=$kernelPriorInclude;$env:LIB=$kernelPriorLib}
foreach($kernelPin in $kernelPins){if((Get-FileHash -LiteralPath (Join-Path $kernelStage $kernelPin.relative)).Hash.ToLowerInvariant()-ne$kernelPin.sha256){throw ('Private compiler input drift '+$kernelPin.relative)}}
$kernelBinary=Join-Path $kernelOutput 'nwn-particle-kernel.dll'
@{success=$true;sourcePins=$kernelPins;binary=$kernelBinary;binarySha256=(Get-FileHash -LiteralPath $kernelBinary).Hash.ToLowerInvariant();compiler=$kernelCompiler;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD';sharedBinaryWrites=0}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $kernelOutput 'build-receipt.json') -Encoding utf8
Write-Output ('Private DLL SHA256 '+(Get-FileHash -LiteralPath $kernelBinary).Hash.ToLowerInvariant())
