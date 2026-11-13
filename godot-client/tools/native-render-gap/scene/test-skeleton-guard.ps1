[CmdletBinding()]
param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='skeleton-guard-logic-a',[ValidatePattern('^[a-z0-9-]+$')][string]$Prepared='skeleton-guard-a')
$ErrorActionPreference='Stop'
$guardProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$guardPrepared=Join-Path $guardProject ('.cache/native-render-gap/scene/'+$Prepared)
$guardStage=Join-Path $guardProject ('.cache/native-render-gap/scene/'+$Run)
if(Test-Path -LiteralPath $guardStage){throw 'Existing evidence is frozen'}
[IO.Directory]::CreateDirectory($guardStage)|Out-Null
$guardPins=@()
foreach($guardPair in @(@((Join-Path $PSScriptRoot 'skeleton_guard_logic_test.cpp'),'test.cpp'),@((Join-Path $guardPrepared 'extracted-setters.inc'),'extracted-setters.inc'))){
 $guardRaw=[IO.File]::ReadAllBytes($guardPair[0]);[IO.File]::WriteAllBytes((Join-Path $guardStage $guardPair[1]),$guardRaw)
 $guardPins+=@{input=$guardPair[0];relative=$guardPair[1];sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($guardRaw)).ToLowerInvariant()}
}
$guardVswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$guardVs=@(& $guardVswhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')}|Select-Object -First 1
if(-not$guardVs){throw 'Existing MSVC unavailable'}
$guardVersion=(Get-Content -LiteralPath (Join-Path $guardVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$guardTools=Join-Path $guardVs ('VC/Tools/MSVC/'+$guardVersion)
$guardCompiler=Join-Path $guardTools 'bin/Hostx64/x64/cl.exe'
$guardSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$guardIncludes=Get-ChildItem -LiteralPath (Join-Path $guardSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$guardIncludes){throw 'Existing Windows SDK unavailable'}
$guardPriorInclude=$env:INCLUDE;$guardPriorLib=$env:LIB
$guardExe=Join-Path $guardStage 'test.exe'
$guardArgs=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD',('/Fo'+(Join-Path $guardStage 'test.obj')),('/Fe'+$guardExe),(Join-Path $guardStage 'test.cpp'),'/link','/INCREMENTAL:NO')
try{
 $env:INCLUDE=((Join-Path $guardTools 'include'),(Join-Path $guardIncludes.FullName 'ucrt'),(Join-Path $guardIncludes.FullName 'shared'),(Join-Path $guardIncludes.FullName 'um'))-join';'
 $env:LIB=((Join-Path $guardTools 'lib/x64'),(Join-Path $guardSdk ('Lib/'+$guardIncludes.Name+'/ucrt/x64')),(Join-Path $guardSdk ('Lib/'+$guardIncludes.Name+'/um/x64')))-join';'
 $guardCompileOutput=@(& $guardCompiler @guardArgs 2>&1);$guardCompileExit=$LASTEXITCODE
 [IO.File]::WriteAllText((Join-Path $guardStage 'compile.log'),($guardCompileOutput-join[Environment]::NewLine))
 if($guardCompileExit-eq0){$guardRunOutput=@(& $guardExe 2>&1);$guardExit=$LASTEXITCODE;[IO.File]::WriteAllText((Join-Path $guardStage 'stdout.log'),($guardRunOutput-join[Environment]::NewLine));$guardResult=($guardRunOutput-join'')|ConvertFrom-Json}
}finally{$env:INCLUDE=$guardPriorInclude;$env:LIB=$guardPriorLib}
$guardChanged=@()
foreach($guardPin in $guardPins){if((Get-FileHash -LiteralPath $guardPin.input).Hash.ToLowerInvariant()-ne$guardPin.sha256-or(Get-FileHash -LiteralPath (Join-Path $guardStage $guardPin.relative)).Hash.ToLowerInvariant()-ne$guardPin.sha256){$guardChanged+=$guardPin.relative}}
$guardSuccess=$guardCompileExit-eq0-and$guardExit-eq0-and$guardResult.success-and$guardChanged.Count-eq0
$guardReceipt=@{success=[bool]$guardSuccess;createdAtUtc=[DateTime]::UtcNow.ToString('o');compileExit=$guardCompileExit;runExit=$guardExit;result=$guardResult;pins=$guardPins;changed=$guardChanged;compiler=$guardCompiler;compilerVersion=$guardVersion;command=@($guardCompiler)+$guardArgs;engineBuilds=0;enginesStarted=0;gpu=$false;scope='Isolated exact extracted setter bodies and storage/queue stubs only; no engine or FPS acceptance'}
$guardReceipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $guardStage 'receipt.json') -Encoding utf8
$guardReceipt|ConvertTo-Json -Depth 3
if(-not$guardSuccess){exit 1}
