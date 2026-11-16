param([Parameter(Mandatory=$true)][string]$Report)
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $Report -PathType Leaf)){throw 'Local smoke report is missing'}
$receipt=Get-Content -LiteralPath $Report -Raw|ConvertFrom-Json -AsHashtable
$smoke=$receipt.direct_local_smoke_check
if(-not($smoke -is [System.Collections.IDictionary])){throw 'Local smoke completed without its movement/animation receipt'}
if($receipt.clean_exit -ne $true -or $receipt.protocol_finish_ack -ne $true){throw 'Local smoke did not exit cleanly'}
if($smoke.requestKind -notin @('walk','drive') -or $smoke.requestAccepted -ne $true -or $smoke.requestTransmitted -ne $true){throw 'Local smoke movement command was not sent through the admitted session'}
if([double]$smoke.serverDisplacement -le 0.25 -or $smoke.serverMovementObserved -ne $true -or [int]$smoke.serverUpdates -lt 1 -or [long]$smoke.originArea -ne [long]$smoke.destinationArea -or [int]$smoke.originGeneration -ne [int]$smoke.destinationGeneration){throw 'Local smoke lacks a same-area server-authoritative movement update'}
if($smoke.speechEcho -ne $true -or $smoke.cameraFollowValid -ne $true -or [int]$smoke.presentationFrames -lt 2){throw 'Local smoke chat, camera or rig pose-clock activity is missing'}
$animation=$smoke.animationWitness
if($smoke.presentationAnimationAdvanced -ne $true -or -not($animation -is [System.Collections.IDictionary]) -or [int]$animation.changed_local_parts -lt 1){throw 'Local smoke lacks a changed controlled model pose'}
$skinChanged=[double]$animation.maximum_local_skin_vertex_delta -gt 0.0001
$controlled=[long]$receipt.direct_headless_check.controlled
$walkClip=@($animation.active_clips|Where-Object {([string]$_.model).StartsWith($controlled.ToString()+':',[StringComparison]::Ordinal) -and [string]$_.clip -in @('walk','run')}).Count -gt 0
$rigidMoved=$animation.rigidOnly -eq $true -and $animation.activeWalkClip -eq $true -and $walkClip -and [int]$animation.advanced_model_clocks -gt 0 -and [int]$animation.skin_meshes_sampled -eq 0
if(-not($skinChanged -or $rigidMoved)){throw 'Local smoke actor advanced only an idle/ready pose, without skin motion or a controlled walk/run clip'}
[ordered]@{format='nwn79-local-smoke-witness-v1';accepted=$true;serverDisplacement=[double]$smoke.serverDisplacement;serverUpdates=[int]$smoke.serverUpdates;skinChanged=$skinChanged;rigidWalkRun=$rigidMoved}
