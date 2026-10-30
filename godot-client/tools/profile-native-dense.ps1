param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Run,[ValidateRange(5,20)][int]$SecondsPerMode=8,[switch]$Close)
$ErrorActionPreference='Stop'
$nativeProfileProject=Split-Path $PSScriptRoot -Parent
$nativeProfileProgress=Join-Path $nativeProfileProject ('reports/'+$Run+'.progress.json')
$nativeProfileControl=Join-Path $nativeProfileProject ('reports/'+$Run+'.control.json')
$nativeProfileOutput=Join-Path $nativeProfileProject ('reports/'+$Run+'.ablations.json')
if(Test-Path -LiteralPath $nativeProfileOutput){throw 'Profile comparison output exists'}
$nativeProfileRows=@();$nativeProfileSerial=1
try{
 foreach($nativeProfileMode in @('baseline','no-animation','baseline','no-actor-picking','half-resolution','unshaded','no-3d','baseline')){
  $nativeProfileCommand=@{serial=$nativeProfileSerial;mode=$nativeProfileMode}|ConvertTo-Json -Compress
  [IO.File]::WriteAllText($nativeProfileControl,$nativeProfileCommand,[Text.UTF8Encoding]::new($false))
  Start-Sleep -Seconds $SecondsPerMode
  $nativeProfileSample=$null
  for($nativeRead=0;$nativeRead-lt5;$nativeRead++){
   try{$nativeProfileSample=Get-Content -LiteralPath $nativeProfileProgress -Raw|ConvertFrom-Json;break}catch{Start-Sleep -Milliseconds 100}
  }
  if(-not$nativeProfileSample-or$nativeProfileSample.frame_profile.control_serial-ne$nativeProfileSerial-or$nativeProfileSample.frame_profile.frames-lt120){throw 'Profile control did not produce a fresh measured window'}
  $nativeProfileRows+=$nativeProfileSample
  Write-Output ($nativeProfileSample|Select-Object fps,@{n='mode';e={$_.frame_profile.mode}},@{n='wallMs';e={$_.frame_profile.metrics.wall_ms.mean}},@{n='gpuMs';e={$_.frame_profile.metrics.render_gpu_ms.mean}},@{n='animationMs';e={$_.frame_profile.metrics.actor_animation.mean}}|ConvertTo-Json -Compress)
  $nativeProfileSerial++
 }
}finally{
 [IO.File]::WriteAllText($nativeProfileControl,(@{serial=$nativeProfileSerial+1;mode=$(if($Close){'close'}else{'baseline'})}|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
 @{scope='Sequential native dense diagnostic ablations. Workloads intentionally differ; no visual-preserving speedup, native-client comparison or clean GPU acceptance.';rows=$nativeProfileRows}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $nativeProfileOutput -Encoding utf8
}
