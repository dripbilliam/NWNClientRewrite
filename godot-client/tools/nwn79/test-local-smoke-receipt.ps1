param([string]$Scratch='')
$ErrorActionPreference='Stop'
$verifier=Join-Path $PSScriptRoot 'verify-local-smoke-receipt.ps1'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$cache=Join-Path $workspace '.cache'
$root=if($Scratch){[IO.Path]::GetFullPath($Scratch)}else{Join-Path $cache ('nwn79-local-smoke-validator-'+[guid]::NewGuid().ToString('N'))}
if(-not$root.StartsWith($cache+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Local smoke validator scratch escaped workspace cache'}
if(Test-Path -LiteralPath $root){throw 'Local smoke validator scratch must be fresh'}
New-Item -ItemType Directory -Path $root -Force|Out-Null
function Write-Case([string]$name,[hashtable]$value){$path=Join-Path $root ($name+'.json');[IO.File]::WriteAllText($path,($value|ConvertTo-Json -Depth 12));return $path}
function Reject([string]$name,[hashtable]$value){$path=Write-Case $name $value;try{& $verifier -Report $path|Out-Null;throw ('Invalid local smoke witness was accepted: '+$name)}catch{if($_.Exception.Message -like 'Invalid local smoke witness was accepted:*'){throw}}}
try{
 $base=@{clean_exit=$true;protocol_finish_ack=$true;direct_headless_check=@{controlled=4294967295};direct_local_smoke_check=@{requestKind='walk';requestAccepted=$true;requestTransmitted=$true;serverDisplacement=1.5;serverMovementObserved=$true;serverUpdates=2;originArea=2147483649;destinationArea=2147483649;originGeneration=1;destinationGeneration=1;speechEcho=$true;cameraFollowValid=$true;presentationFrames=16;presentationAnimationAdvanced=$true;animationWitness=@{changed_local_parts=34;advanced_model_clocks=1;maximum_local_skin_vertex_delta=0.0;skin_meshes_sampled=0;rigidOnly=$true;activeWalkClip=$true;active_clips=@(@{model='4294967295:0';clip='walk';time=0.25})}}}
 $positive=Write-Case 'rigid-walk-positive' $base
 $accepted=& $verifier -Report $positive
 if($accepted.accepted -ne $true -or $accepted.rigidWalkRun -ne $true){throw 'Valid rigid walk witness was rejected'}
 $idle=$base|ConvertTo-Json -Depth 12|ConvertFrom-Json -AsHashtable;$idle.direct_local_smoke_check.animationWitness.activeWalkClip=$false;$idle.direct_local_smoke_check.animationWitness.active_clips[0].clip='1hreadyr';Reject 'idle-ready-negative' $idle
 $poseOnly=$base|ConvertTo-Json -Depth 12|ConvertFrom-Json -AsHashtable;$poseOnly.direct_local_smoke_check.Remove('animationWitness');Reject 'pose-frames-only-negative' $poseOnly
 $noServer=$base|ConvertTo-Json -Depth 12|ConvertFrom-Json -AsHashtable;$noServer.direct_local_smoke_check.serverUpdates=0;Reject 'local-prediction-negative' $noServer
 $noDisplacement=$base|ConvertTo-Json -Depth 12|ConvertFrom-Json -AsHashtable;$noDisplacement.direct_local_smoke_check.serverDisplacement=0.25;Reject 'movement-threshold-negative' $noDisplacement
 $wrongActor=$base|ConvertTo-Json -Depth 12|ConvertFrom-Json -AsHashtable;$wrongActor.direct_local_smoke_check.animationWitness.active_clips[0].model='123:0';Reject 'wrong-actor-clip-negative' $wrongActor
 $skin=$base|ConvertTo-Json -Depth 12|ConvertFrom-Json -AsHashtable;$skin.direct_local_smoke_check.animationWitness.rigidOnly=$false;$skin.direct_local_smoke_check.animationWitness.activeWalkClip=$false;$skin.direct_local_smoke_check.animationWitness.active_clips=@();$skin.direct_local_smoke_check.animationWitness.maximum_local_skin_vertex_delta=0.001
 $skinResult=& $verifier -Report (Write-Case 'skin-positive' $skin)
 if($skinResult.accepted -ne $true -or $skinResult.skinChanged -ne $true){throw 'Valid skin deformation witness was rejected'}
 [ordered]@{format='nwn79-local-smoke-validator-test-v1';accepted=@('rigid-walk-positive','skin-positive');rejected=@('idle-ready-negative','pose-frames-only-negative','local-prediction-negative','movement-threshold-negative','wrong-actor-clip-negative');nodeInvoked=$false;serverInvoked=$false}|ConvertTo-Json -Depth 4
}finally{if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}}
