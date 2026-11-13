[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Label,[Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
$renderProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$renderCapsule=Join-Path $renderProject ('.cache/native-140fps/render-agent/'+$Label)
$renderManifest=Get-Content -LiteralPath (Join-Path $renderCapsule 'manifest.json') -Raw|ConvertFrom-Json
$renderCandidate=$renderManifest.project
$renderStage=Join-Path $renderProject ('.cache/native-140fps/render-agent/checks/'+$Run)
if(Test-Path -LiteralPath $renderStage){throw 'Existing pure policy evidence preserved'}
$renderPolicy=Join-Path $renderCandidate 'native/experimental/managed_pose_lease_policy.hpp'
$renderHeader=Join-Path $renderCandidate 'native/experimental/frame_pose_cache.hpp'
if((Get-FileHash -LiteralPath $renderPolicy).Hash.ToLowerInvariant()-ne'1238557f11761384196ef86e19414a597d97143f0e4d560ca501604941763cfa'){throw 'Original frozen managed policy drifted'}
foreach($renderRelative in @('native/experimental/managed_pose_lease_policy.hpp','native/experimental/frame_pose_cache.hpp')){$renderPin=$renderManifest.pins|Where-Object relative -eq $renderRelative;if((Get-FileHash -LiteralPath (Join-Path $renderCandidate $renderRelative)).Hash.ToLowerInvariant()-ne$renderPin.sha256){throw 'Combined policy header drifted'}}
New-Item -ItemType Directory -Path $renderStage|Out-Null
$renderSource=Join-Path $renderProject 'tests/native_perf140_particle_managed_lease_policy_test.cpp'
$renderVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$renderVs=@(& $renderVsWhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')}|Select-Object -First 1
$renderVersion=(Get-Content -LiteralPath (Join-Path $renderVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$renderTools=Join-Path $renderVs ('VC/Tools/MSVC/'+$renderVersion)
$renderCompiler=Join-Path $renderTools 'bin/Hostx64/x64/cl.exe'
$renderSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$renderInclude=Get-ChildItem -LiteralPath (Join-Path $renderSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
$renderOldInclude=$env:INCLUDE;$renderOldLib=$env:LIB
try{
 $env:INCLUDE=((Join-Path $renderTools 'include'),(Join-Path $renderInclude.FullName 'ucrt'),(Join-Path $renderInclude.FullName 'shared'),(Join-Path $renderInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $renderTools 'lib/x64'),(Join-Path $renderSdk ('Lib/'+$renderInclude.Name+'/ucrt/x64')),(Join-Path $renderSdk ('Lib/'+$renderInclude.Name+'/um/x64')))-join';'
 $renderBinary=Join-Path $renderStage 'managed-policy-test.exe'
 $renderArguments=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD',('/I'+(Join-Path $renderCandidate 'native/experimental')),('/Fo'+(Join-Path $renderStage 'managed-policy-test.obj')),('/Fe'+$renderBinary),$renderSource,'/link','/INCREMENTAL:NO')
 $renderLog=@(& $renderCompiler @renderArguments 2>&1);$renderCompileExit=$LASTEXITCODE
 [IO.File]::WriteAllText((Join-Path $renderStage 'compile.log'),($renderLog-join[Environment]::NewLine))
 if($renderCompileExit-ne0){throw 'Private combined policy compile failed'}
 $renderResult=@(& $renderBinary);$renderTestExit=$LASTEXITCODE
 [IO.File]::WriteAllText((Join-Path $renderStage 'result.json'),($renderResult-join[Environment]::NewLine))
 if($renderTestExit-ne0){throw 'Private combined policy checks failed'}
 $renderProof=@{success=$true;test=($renderResult-join[Environment]::NewLine)|ConvertFrom-Json;sourceSha256=(Get-FileHash -LiteralPath $renderSource).Hash.ToLowerInvariant();policySha256=(Get-FileHash -LiteralPath $renderPolicy).Hash.ToLowerInvariant();frameHeaderSha256=(Get-FileHash -LiteralPath $renderHeader).Hash.ToLowerInvariant();binarySha256=(Get-FileHash -LiteralPath $renderBinary).Hash.ToLowerInvariant();engineStarts=0;sharedBuilds=0;gpu=$false;serverConnections=0}
 [IO.File]::WriteAllText((Join-Path $renderStage 'checks.json'),($renderProof|ConvertTo-Json -Depth 5));$renderProof|ConvertTo-Json -Compress -Depth 5
}finally{$env:INCLUDE=$renderOldInclude;$env:LIB=$renderOldLib}
