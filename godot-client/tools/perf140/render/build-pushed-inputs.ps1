[CmdletBinding()]
param([Parameter(Mandatory)][string]$Candidate)
$ErrorActionPreference='Stop'
$renderProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$renderPrivate=[IO.Path]::GetFullPath((Join-Path $renderProject ('.cache/native-140fps/render-agent/'+$Candidate)))
if($Candidate-notmatch'^[a-z0-9-]+$'-or-not$renderPrivate.StartsWith((Join-Path $renderProject '.cache/native-140fps/render-agent')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Invalid private build scope'}
$renderManifest=Get-Content -LiteralPath (Join-Path $renderPrivate 'manifest.json') -Raw|ConvertFrom-Json
$renderSourceProject=Join-Path $renderPrivate 'project'
if($renderManifest.project-ne$renderSourceProject){throw 'Candidate identity differs'}
foreach($renderPin in $renderManifest.pins){if((Get-FileHash -LiteralPath (Join-Path $renderSourceProject $renderPin.relative)).Hash.ToLowerInvariant()-ne$renderPin.sha256){throw ('Private input changed: '+$renderPin.relative)}}
$renderOutput=Join-Path $renderSourceProject '.cache/native-kernel'
New-Item -ItemType Directory -Path $renderOutput -Force|Out-Null
$renderProof=Join-Path $renderPrivate 'build.json'
if(Test-Path -LiteralPath $renderProof){throw 'Existing compiler evidence must be preserved'}
$renderGuards=@()
foreach($renderRelative in @('.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json')){$renderGuards+=@{relative=$renderRelative;sha256=(Get-FileHash -LiteralPath (Join-Path $renderProject $renderRelative)).Hash.ToLowerInvariant()}}
$renderApi=Join-Path $renderProject '.tools/extension-api'
$renderAbi=Get-Content -LiteralPath (Join-Path $renderApi 'extension_api.json') -Raw|ConvertFrom-Json
if($renderAbi.header.version_full_name-ne'Godot Engine v4.7.2.stable.official'-or$renderAbi.header.precision-ne'single'){throw 'Unsupported private ABI'}
$renderVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$renderVs=@(& $renderVsWhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')}|Select-Object -First 1
if(-not$renderVs){throw 'Existing MSVC unavailable'}
$renderVersion=(Get-Content -LiteralPath (Join-Path $renderVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$renderTools=Join-Path $renderVs ('VC/Tools/MSVC/'+$renderVersion)
$renderCompiler=Join-Path $renderTools 'bin/Hostx64/x64/cl.exe'
$renderSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$renderInclude=Get-ChildItem -LiteralPath (Join-Path $renderSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$renderInclude){throw 'Existing Windows SDK unavailable'}
$renderPriorInclude=$env:INCLUDE;$renderPriorLib=$env:LIB
$renderBinary=Join-Path $renderOutput 'nwn-particle-kernel.dll'
try{
 $env:INCLUDE=((Join-Path $renderTools 'include'),(Join-Path $renderInclude.FullName 'ucrt'),(Join-Path $renderInclude.FullName 'shared'),(Join-Path $renderInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $renderTools 'lib/x64'),(Join-Path $renderSdk ('Lib/'+$renderInclude.Name+'/ucrt/x64')),(Join-Path $renderSdk ('Lib/'+$renderInclude.Name+'/um/x64')))-join';'
 $renderArguments=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD',('/I'+$renderApi),('/Fo'+(Join-Path $renderOutput 'pushed-inputs.obj')),('/Fe'+$renderBinary),(Join-Path $renderSourceProject 'native/particle_kernel.cpp'),'/link','/INCREMENTAL:NO',('/IMPLIB:'+(Join-Path $renderOutput 'pushed-inputs.lib')))
 $renderLog=@(& $renderCompiler @renderArguments 2>&1);$renderExit=$LASTEXITCODE
 [IO.File]::WriteAllText((Join-Path $renderPrivate 'compile.log'),($renderLog-join[Environment]::NewLine))
}finally{$env:INCLUDE=$renderPriorInclude;$env:LIB=$renderPriorLib}
$renderChanged=@($renderGuards|Where-Object{(Get-FileHash -LiteralPath (Join-Path $renderProject $_.relative)).Hash.ToLowerInvariant()-ne$_.sha256}|ForEach-Object relative)
$renderSuccess=$renderExit-eq0-and-not$renderChanged.Count
$renderHash=if($renderExit-eq0){(Get-FileHash -LiteralPath $renderBinary).Hash.ToLowerInvariant()}else{$null}
$renderResult=@{success=[bool]$renderSuccess;candidate=$Candidate;exitCode=$renderExit;output=$renderBinary;binarySha256=$renderHash;compiler=$renderVersion;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD';guards=$renderGuards;changedGuards=$renderChanged;sharedNativeBuilds=0;isolatedNativeBuilds=1;engineStarts=0;serverConnections=0;gpu=$false}
[IO.File]::WriteAllText($renderProof,($renderResult|ConvertTo-Json -Depth 6))
if($renderSuccess){[IO.File]::WriteAllText((Join-Path $renderOutput 'build-manifest.json'),($renderResult|ConvertTo-Json -Depth 6))}
$renderResult|ConvertTo-Json -Compress -Depth 6
if(-not$renderSuccess){exit 1}
