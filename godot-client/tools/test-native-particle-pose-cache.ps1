[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^native-particle-pose-cache-[a-z0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
$poseProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$poseStage=Join-Path $poseProject ('.cache/native-particle-pose-cache/'+$Run)
if(Test-Path -LiteralPath $poseStage){throw 'Existing pose-cache evidence is preserved'}
$posePins=@()
foreach($relative in @('native/experimental/particle_pose_cache.hpp','tests/native_particle_pose_cache_test.cpp')){
 $bytes=[IO.File]::ReadAllBytes((Join-Path $poseProject $relative));$target=Join-Path $poseStage $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
 [IO.File]::WriteAllBytes($target,$bytes)
 $posePins+=@{relative=$relative;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
}
$poseGuards=@()
foreach($relative in @('.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json')){
 $poseGuards+=@{relative=$relative;sha256=(Get-FileHash -LiteralPath (Join-Path $poseProject $relative)).Hash.ToLowerInvariant()}
}
$poseVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$poseVs=@(& $poseVsWhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')}|Select-Object -First 1
if(-not$poseVs){throw 'Existing MSVC not found; no installation'}
$poseVersion=(Get-Content -LiteralPath (Join-Path $poseVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$poseTools=Join-Path $poseVs ('VC/Tools/MSVC/'+$poseVersion)
$poseCompiler=Join-Path $poseTools 'bin/Hostx64/x64/cl.exe'
$poseSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$poseInclude=Get-ChildItem -LiteralPath (Join-Path $poseSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$poseInclude){throw 'Existing Windows SDK unavailable'}
$posePriorInclude=$env:INCLUDE;$posePriorLib=$env:LIB
$poseExecutable=Join-Path $poseStage 'pose-cache-test.exe'
$poseObject=Join-Path $poseStage 'pose-cache-test.obj'
$poseCompileLog=Join-Path $poseStage 'compile.log'
try{
 $env:INCLUDE=((Join-Path $poseTools 'include'),(Join-Path $poseInclude.FullName 'ucrt'),(Join-Path $poseInclude.FullName 'shared'),(Join-Path $poseInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $poseTools 'lib/x64'),(Join-Path $poseSdk ('Lib/'+$poseInclude.Name+'/ucrt/x64')),(Join-Path $poseSdk ('Lib/'+$poseInclude.Name+'/um/x64')))-join';'
 $poseArguments=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD',('/Fo'+$poseObject),('/Fe'+$poseExecutable),(Join-Path $poseStage 'tests/native_particle_pose_cache_test.cpp'),'/link','/INCREMENTAL:NO')
 $poseOutput=@(& $poseCompiler @poseArguments 2>&1);$poseCompileExit=$LASTEXITCODE
 [IO.File]::WriteAllText($poseCompileLog,($poseOutput-join[Environment]::NewLine))
 if($poseCompileExit-ne0){throw ('Isolated pose test compilation failed; see '+$poseCompileLog)}
 $poseTestOutput=@(& $poseExecutable 2>&1);$poseExit=$LASTEXITCODE
 [IO.File]::WriteAllText((Join-Path $poseStage 'stdout.log'),($poseTestOutput-join[Environment]::NewLine))
 $poseResult=($poseTestOutput-join'')|ConvertFrom-Json
}finally{$env:INCLUDE=$posePriorInclude;$env:LIB=$posePriorLib}
$poseChanged=@()
foreach($pin in $posePins){if((Get-FileHash -LiteralPath (Join-Path $poseProject $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256-or(Get-FileHash -LiteralPath (Join-Path $poseStage $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256){$poseChanged+=$pin.relative}}
foreach($pin in $poseGuards){if((Get-FileHash -LiteralPath (Join-Path $poseProject $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256){$poseChanged+=$pin.relative}}
$poseSuccess=$poseCompileExit-eq0-and$poseExit-eq0-and$poseResult.success-and-not$poseChanged.Count
$poseReceipt=@{success=[bool]$poseSuccess;run=$Run;result=$poseResult;compileExit=$poseCompileExit;exit=$poseExit;sourcePins=$posePins;guards=$poseGuards;changed=$poseChanged;compiler=$poseVersion;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD';sharedNativeBuilds=0;isolatedTestBuilds=1;engines=0;servers=0;gpu=$false;scope='Pure candidate conversion-cache primitive with bit-equivalent authored/random inputs. No Godot pose/lifetime integration or FPS acceptance.'}
$poseReport=Join-Path $poseProject ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $poseReport){throw 'Existing report is preserved'}
[IO.File]::WriteAllText($poseReport,($poseReceipt|ConvertTo-Json -Depth 6))
@{success=[bool]$poseSuccess;run=$Run;checks=$poseResult.checks;failures=$poseResult.failures;changed=$poseChanged;report=$poseReport;sharedNativeBuilds=0;isolatedTestBuilds=1}|ConvertTo-Json -Compress
if(-not$poseSuccess){exit 1}
