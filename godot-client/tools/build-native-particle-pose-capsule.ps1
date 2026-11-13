[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^native-dense-(pose|light-input)-[a-z0-9-]+$')][string]$Capsule,[Parameter(Mandatory)][ValidateSet('baseline','candidate')][string]$Variant)
$ErrorActionPreference='Stop'
$poseProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$poseStage=[IO.Path]::GetFullPath((Join-Path $poseProject ('.cache/native-dense-area/'+$Capsule+'/'+$Variant)))
if(-not$poseStage.StartsWith((Join-Path $poseProject '.cache/native-dense-area')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Build path escapes private capsule'}
$poseReceipt=Get-Content -LiteralPath (Join-Path (Split-Path -Parent $poseStage) ($Variant+'-sources.json')) -Raw|ConvertFrom-Json
if($poseReceipt.sourceProject-ne$poseStage-or$poseReceipt.variant-ne$Variant-or$poseReceipt.isolatedBuildFinalized){throw 'Private build identity differs'}
foreach($pin in $poseReceipt.sourcePins){if((Get-FileHash -LiteralPath (Join-Path $poseStage $pin.relative)).Hash.ToLowerInvariant()-ne$pin.finalSha256){throw ('Source changed: '+$pin.relative)}}
$poseOutput=Join-Path $poseStage '.cache/native-kernel'
$poseProof=Join-Path $poseOutput 'pose-build.json'
if(Test-Path -LiteralPath $poseProof){throw 'Existing compiler evidence is preserved'}
$poseGuards=@()
foreach($relative in @('.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json')){$poseGuards+=@{relative=$relative;sha256=(Get-FileHash -LiteralPath (Join-Path $poseProject $relative)).Hash.ToLowerInvariant()}}
$poseApi=Join-Path $poseProject '.tools/extension-api'
$poseAbi=Get-Content -LiteralPath (Join-Path $poseApi 'extension_api.json') -Raw|ConvertFrom-Json
if($poseAbi.header.version_full_name-ne'Godot Engine v4.7.2.stable.official'-or$poseAbi.header.precision-ne'single'){throw 'Unsupported private ABI'}
$poseVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$poseVs=@(& $poseVsWhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')}|Select-Object -First 1
if(-not$poseVs){throw 'Existing MSVC unavailable'}
$poseVersion=(Get-Content -LiteralPath (Join-Path $poseVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$poseTools=Join-Path $poseVs ('VC/Tools/MSVC/'+$poseVersion)
$poseCompiler=Join-Path $poseTools 'bin/Hostx64/x64/cl.exe'
$poseSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$poseInclude=Get-ChildItem -LiteralPath (Join-Path $poseSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$poseInclude){throw 'Existing SDK unavailable'}
$posePriorInclude=$env:INCLUDE;$posePriorLib=$env:LIB
$poseBinary=Join-Path $poseOutput 'nwn-particle-kernel.dll'
$poseObject=Join-Path $poseOutput 'pose-kernel.obj'
$poseSource=Join-Path $poseStage 'native/particle_kernel.cpp'
try{
 $env:INCLUDE=((Join-Path $poseTools 'include'),(Join-Path $poseInclude.FullName 'ucrt'),(Join-Path $poseInclude.FullName 'shared'),(Join-Path $poseInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $poseTools 'lib/x64'),(Join-Path $poseSdk ('Lib/'+$poseInclude.Name+'/ucrt/x64')),(Join-Path $poseSdk ('Lib/'+$poseInclude.Name+'/um/x64')))-join';'
 $poseArguments=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD',('/I'+$poseApi),('/Fo'+$poseObject),('/Fe'+$poseBinary),$poseSource,'/link','/INCREMENTAL:NO',('/IMPLIB:'+(Join-Path $poseOutput 'pose-kernel.lib')))
 $poseLog=@(& $poseCompiler @poseArguments 2>&1);$poseExit=$LASTEXITCODE
 [IO.File]::WriteAllText((Join-Path $poseOutput 'pose-compile.log'),($poseLog-join[Environment]::NewLine))
}finally{$env:INCLUDE=$posePriorInclude;$env:LIB=$posePriorLib}
$poseChanged=@($poseGuards|Where-Object{(Get-FileHash -LiteralPath (Join-Path $poseProject $_.relative)).Hash.ToLowerInvariant()-ne$_.sha256}|ForEach-Object relative)
$poseSuccess=$poseExit-eq0-and-not$poseChanged.Count
$poseHash=if($poseExit-eq0){(Get-FileHash -LiteralPath $poseBinary).Hash.ToLowerInvariant()}else{$null}
$poseResult=@{success=[bool]$poseSuccess;capsule=$Capsule;variant=$Variant;exit=$poseExit;output=$poseBinary;binarySha256=$poseHash;sourceSha256=(Get-FileHash -LiteralPath $poseSource).Hash.ToLowerInvariant();compiler=$poseVersion;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD';apiSha256=(Get-FileHash -LiteralPath (Join-Path $poseApi 'extension_api.json')).Hash.ToLowerInvariant();headerSha256=(Get-FileHash -LiteralPath (Join-Path $poseApi 'gdextension_interface.h')).Hash.ToLowerInvariant();guards=$poseGuards;changedGuards=$poseChanged;sharedNativeBuilds=0;isolatedNativeBuilds=1;engineStarts=0;serverConnections=0}
[IO.File]::WriteAllText($poseProof,($poseResult|ConvertTo-Json -Depth 5))
if($poseSuccess){[IO.File]::WriteAllText((Join-Path $poseOutput 'build-manifest.json'),($poseResult|ConvertTo-Json -Depth 5))}
@{success=[bool]$poseSuccess;exit=$poseExit;capsule=$Capsule;variant=$Variant;changedGuards=$poseChanged;binarySha256=$poseHash;report=$poseProof}|ConvertTo-Json -Compress
if(-not$poseSuccess){exit 1}
