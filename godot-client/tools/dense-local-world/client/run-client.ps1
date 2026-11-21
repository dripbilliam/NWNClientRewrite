param(
 [Parameter(Mandatory)][string]$World,
 [Parameter(Mandatory)][string]$Repository,
 [string]$RepositoryLogs='',
 [Parameter(Mandatory)][string]$SettingsSource,
 [Parameter(Mandatory)][string]$OutputRoot,
 [ValidateSet('cold','warm','pair')][string]$Phase='pair',
 [ValidateSet('validate','frame','profile')][string]$Mode='validate',
 [ValidateRange(2,30)][int]$IdleSeconds=6,
 [ValidateRange(1,12)][int]$RouteLaps=1,
 [ValidateRange(45,600)][int]$TimeoutSeconds=180,
 [ValidateSet('reference','cpu-compiled','gpu-skin','gpu-skin-pick')][string]$Variant='reference',
 [switch]$PointerProbe,
 [switch]$JoinDiagnostics,
 [switch]$ForegroundModelCompletion,
 [switch]$PrefetchLookahead,
 [switch]$DriveObstaclePrefix,
 [switch]$DriveObstacleSparse,
 [switch]$CpuSkinPicking,
 [ValidateSet('safe','separate')][string]$RenderThread='safe',
 [string]$Install=''
)
$ErrorActionPreference='Stop'
if($RouteLaps -gt 1 -and $Mode -ne 'validate'){throw 'Repeated route laps require headless validate mode'}
if($CpuSkinPicking -and $Variant -in @('gpu-skin','gpu-skin-pick')){throw 'CPU skin picking requires CPU deformation'}
if($ForegroundModelCompletion -and -not $JoinDiagnostics){throw 'Foreground model completion comparison requires JoinDiagnostics'}
if($DriveObstacleSparse -and -not $DriveObstaclePrefix){throw 'Sparse obstacle reuse requires DriveObstaclePrefix'}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$workspace=[IO.Path]::GetFullPath((Join-Path $project '..'))
$scratch=(Resolve-Path -LiteralPath (Join-Path $workspace '.cache')).Path
$worldFile=(Resolve-Path -LiteralPath $World).Path
$repositoryRoot=(Resolve-Path -LiteralPath $Repository).Path
$logRoot=if($RepositoryLogs){(Resolve-Path -LiteralPath $RepositoryLogs).Path}else{$repositoryRoot}
$output=[IO.Path]::GetFullPath($OutputRoot)
$prefix=$scratch+[IO.Path]::DirectorySeparatorChar
if(-not $output.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){
 throw 'OutputRoot must be a child of the workspace .cache directory'
}
$outputParent=(Resolve-Path -LiteralPath (Split-Path $output -Parent)).Path
if((Get-Item -LiteralPath $outputParent).Attributes -band [IO.FileAttributes]::ReparsePoint){
 throw 'OutputRoot parent may not be a redirected directory'
}
$worldSpec=Get-Content -LiteralPath $worldFile -Raw | ConvertFrom-Json
if($worldSpec.format -ne 'nwn-dense-local-world-v1' -or [int]$worldSpec.port -lt 1024 -or [int]$worldSpec.port -gt 65535){
 throw 'The benchmark world descriptor is invalid'
}
$repoFile=Join-Path $repositoryRoot 'descriptor.json'
$repo=Get-Content -LiteralPath $repoFile -Raw | ConvertFrom-Json
$ready=Get-Content -LiteralPath (Join-Path $logRoot 'ready.json') -Raw | ConvertFrom-Json
$requestLog=Join-Path $logRoot 'requests.jsonl'
if($repo.format -ne 'dense-local-nwsync-v1' -or [string]$repo.url -notmatch '^http://127\.0\.0\.1:[0-9]+/' -or [string]$repo.manifestHash -notmatch '^[a-f0-9]{40}$' -or [int]$repo.uniqueBlobCount -le 0){
 throw 'The NWSync repository descriptor is invalid or does not point to loopback'
}
if([int]$ready.port -ne ([Uri]$repo.url).Port -or -not (Get-Process -Id $ready.pid -ErrorAction SilentlyContinue)){
 throw 'Start the owned NWSync repository before launching the benchmark client'
}
if($Install){$installPath=(Resolve-Path -LiteralPath $Install).Path}else{
 $installPath=(Resolve-Path -LiteralPath (Join-Path $workspace '../FullDecomp/NwnRootInstall')).Path
}
$godot=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
if((Get-FileHash -LiteralPath $godot -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'){
 throw 'The pinned workspace Godot executable changed'
}
$seed=(Resolve-Path -LiteralPath $SettingsSource).Path
if(-not $seed.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or ((Get-Item -LiteralPath $seed).Attributes -band [IO.FileAttributes]::ReparsePoint)){
 throw 'SettingsSource must be an isolated settings seed under the workspace .cache directory'
}
$inputSettings=@('godot-client-settings.json','client-settings.json') | ForEach-Object {Join-Path $seed $_} | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf} | Select-Object -First 1
if(-not $inputSettings){throw 'An isolated v3 settings seed with an enrolled disposable local test profile is required'}
$rendering=Join-Path $output 'rendering.cfg'
$profile=''
$settings=Join-Path $output 'settings'
$userData=Join-Path $output 'user-data'
$identityPath=Join-Path $output 'inputs.json'
$worldHash=(Get-FileHash -LiteralPath $worldFile -Algorithm SHA256).Hash.ToLowerInvariant()
$nwsyncHash=(Get-FileHash -LiteralPath $repoFile -Algorithm SHA256).Hash.ToLowerInvariant()
$screen=-1
if($Mode -ne 'validate'){
 . (Join-Path $project 'tools/native-window-screen.ps1')
 $screen=Get-NativeSecondaryScreen
 if($screen -lt 0){throw 'A secondary monitor is required for graphical capture'}
}

function Read-HttpReceipt([long]$offset) {
 if(-not (Test-Path -LiteralPath $requestLog -PathType Leaf)){return @()}
 $stream=[IO.File]::Open($requestLog,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 try {
  if($stream.Length -lt $offset -or $stream.Length-$offset -gt 33554432){throw 'NWSync request log rotated or exceeded the run bound'}
  $stream.Position=$offset
  $reader=[IO.StreamReader]::new($stream)
  try {
   while($null -ne ($line=$reader.ReadLine())){
    if(-not $line){continue}
    $line | ConvertFrom-Json
   }
  }finally{$reader.Dispose()}
 }finally{$stream.Dispose()}
}

function Invoke-ClientRun([string]$temperature,[string]$preparedCache) {
 $report=Join-Path $output "$temperature-client.json"
 $receiptPath=Join-Path $output "$temperature-benchmark.json"
 if((Test-Path -LiteralPath $report) -or (Test-Path -LiteralPath $receiptPath)){throw 'A run cannot overwrite previous evidence'}
 $offset=if(Test-Path -LiteralPath $requestLog){(Get-Item -LiteralPath $requestLog).Length}else{0L}
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$godot
 $start.WorkingDirectory=$project
 $start.UseShellExecute=$false
 $start.CreateNoWindow=$Mode -eq 'validate'
 $start.RedirectStandardOutput=$true
 $start.RedirectStandardError=$true
 $start.Environment['APPDATA']=$userData
 $start.Environment['LOCALAPPDATA']=$userData
 $start.Environment['NWN_PARTICLE_PRESENTATION']='shared'
 $start.Environment['NWN_PARTICLE_LIGHTING']='pooled'
 # Keep both renderer selections explicit and the same for every pair.
 $launch=if($Mode -eq 'validate'){@('--headless','--max-fps','60')}else{@('--screen',[string]$screen,'--render-thread',$RenderThread,'--rendering-method','forward_plus','--rendering-driver','vulkan')}
 $launch+=@('--path',$project,'--log-file',(Join-Path $output "$temperature-engine.log"),'--script','res://tools/dense-local-world/client/benchmark.gd','--',
  '--direct-session','--settings-check=true','--direct-local-only=true',('--direct-install='+$installPath),('--direct-profile='+$profile),('--direct-settings='+$settings),
  ('--report='+$report),('--render-preferences='+$rendering),('--prepared-cache='+$preparedCache),
  ('--benchmark-world='+$worldFile),('--benchmark-nwsync='+$repoFile),('--benchmark-receipt='+$receiptPath),('--benchmark-phase='+$temperature),('--benchmark-mode='+$Mode),
  ('--benchmark-idle-ms='+($IdleSeconds*1000)),('--benchmark-timeout='+$TimeoutSeconds),('--profile='+([string]($Mode -eq 'profile')).ToLowerInvariant()),
  ('--benchmark-route-laps='+$RouteLaps),
  '--native-lighting=enhanced','--native-light-history','--native-max-lights=32','--native-surface-output=true','--native-shadow-lights=1','--native-postprocess-mask=28','--native-postprocess-midpoint=0.4','--native-postprocess-intensity=0.15','--native-postprocess-vibrance=0.7')
 if($Variant -in @('gpu-skin','gpu-skin-pick')){$launch+='--skin-deform=gpu'}
 if($Variant -eq 'gpu-skin-pick'){$launch+='--gpu-skin-pick=on-demand'}
 if($Variant -eq 'cpu-compiled'){$launch+='--cpu-skin-deform=compiled'}
 if($PointerProbe){$launch+='--benchmark-pointer-probe=true'}
 if($JoinDiagnostics){$launch+='--benchmark-join-diagnostics=true'}
 if($JoinDiagnostics -and $Mode -eq 'validate'){$launch+='--drive-obstacle-prewarm-diagnostics'}
 if($ForegroundModelCompletion){$launch+='--benchmark-foreground-model-completion=true'}
 if($PrefetchLookahead){$launch+='--benchmark-prefetch-lookahead=true'}
 if($DriveObstaclePrefix){$launch+='--drive-obstacle-prewarm-prefix'}
 if($DriveObstacleSparse){$launch+='--drive-obstacle-prewarm-sparse'}
 if($CpuSkinPicking){$launch+='--cpu-skin-pick=on-demand'}
 foreach($argument in $launch){$start.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($start)
 if($null -eq $process){throw 'Godot did not start'}
 Write-Host "Started $temperature $Mode client PID $($process.Id)"
 try {
  $stdout=$process.StandardOutput.ReadToEndAsync()
  $stderr=$process.StandardError.ReadToEndAsync()
  if(-not $process.WaitForExit(($TimeoutSeconds+25)*1000)){
   $process.Kill($true)
   [void]$process.WaitForExit(5000)
   throw 'The owned Godot client exceeded the process timeout'
  }
  $code=$process.ExitCode
  $stdoutText=$stdout.GetAwaiter().GetResult()
  $stderrText=$stderr.GetAwaiter().GetResult()
  $scriptErrors=@(($stdoutText+"`n"+$stderrText) -split '\r?\n' | Where-Object {$_ -match 'SCRIPT ERROR:'} | Select-Object -First 12)
 }finally{$process.Dispose()}
 if(-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)){throw "The $temperature client wrote no benchmark receipt; exit $code"}
 $probe=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -AsHashtable
 if(-not $probe.success){throw "The $temperature client failed: $($probe.failure)"}
 if($probe.routeLaps -ne $RouteLaps -or $probe.laps.Count -ne $RouteLaps){
  throw "The $temperature client did not record all $RouteLaps completed route laps"
 }
 if([bool]$probe.pointerProbe -ne [bool]$PointerProbe -or
   [bool]$probe.render.skinDeformGpu -ne ($Variant -in @('gpu-skin','gpu-skin-pick')) -or
   [bool]$probe.render.cpuSkinPick -ne [bool]$CpuSkinPicking -or
   [bool]$probe.render.gpuSkinPick -ne ($Variant -eq 'gpu-skin-pick')){
  throw "The $temperature client did not use the selected skinning or pointer options"
 }
 if($PointerProbe -and $Variant -eq 'gpu-skin-pick'){
  $poseUse=0
  foreach($window in $probe.windows.Values){$poseUse+=$window.pointerProbe.gpu.refits+$window.pointerProbe.gpu.reuses}
  if($poseUse -eq 0){throw "The $temperature pointer workload did not exercise a posed GPU skin shape"}
 }
 if($PointerProbe -and $CpuSkinPicking){
  $poseUse=0
  foreach($window in $probe.windows.Values){$poseUse+=$window.pointerProbe.cpu.cpuRefits+$window.pointerProbe.cpu.cpuReuses}
  if($poseUse -eq 0){throw "The $temperature pointer workload did not exercise a posed CPU skin shape"}
 }
 if($JoinDiagnostics -and ($probe.joinPublication.reason -ne 'world-settled' -or $probe.joinPublication.byObjectType.Count -eq 0)){
  throw "The $temperature client did not record scene publication diagnostics through settlement"
 }
 foreach($lap in $probe.laps){
  if($lap.distance -le 1 -or $lap.returnDistance -le 1 -or -not $lap.settledWorld.objectVisualsComplete -or -not $lap.settledWorld.environmentAccepted -or
      $lap.requestedMs -ge $lap.arrivedMs -or $lap.arrivedMs -ge $lap.returnedMs -or $lap.returnedMs -ge $lap.settledMs){
   throw "The $temperature client recorded an incomplete route lap"
  }
 }
 if($scriptErrors.Count){throw "The $temperature client logged a script error: $($scriptErrors[0])"}
 $base=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
 if($code -ne 0 -or -not $base.clean_exit){
  $reason=if($base.failure){$base.failure}else{"world complete=$($base.object_visuals_complete), workers=$($base.workers_remaining), finish acknowledged=$($base.protocol_finish_ack)"}
  throw "The $temperature client did not exit cleanly (exit $code, $reason)"
 }
 $deformation=$base.cpu_skin_deformation
 if($Variant -eq 'cpu-compiled' -and (-not $deformation.available -or $deformation.calls -le 0 -or $deformation.rejections -ne 0)){
  throw "The $temperature client did not exercise compiled CPU skin deformation without rejections"
 }
 $rows=@(Read-HttpReceipt $offset)
 $requests=@($rows | Where-Object {$_.completed -and [int]$_.status -eq 200})
 $manifestRequests=@($requests | Where-Object {[string]$_.route -match ('/manifests/'+$repo.manifestHash+'$')})
 $blobs=@($requests | Where-Object {[string]$_.route -match '/data/sha1/'})
 $uniqueBlobs=@($blobs | ForEach-Object {([string]$_.route).Split('/')[-1]} | Sort-Object -Unique)
 $expectedBlobs=@($repo.entries.hash | Sort-Object -Unique)
 if($temperature -eq 'cold' -and ($manifestRequests.Count -lt 1 -or $uniqueBlobs.Count -ne [int]$repo.uniqueBlobCount -or (Compare-Object $expectedBlobs $uniqueBlobs -CaseSensitive))){
  throw "Cold client expected the manifest and $($repo.uniqueBlobCount) unique downloaded assets; observed $($manifestRequests.Count) manifest requests and $($uniqueBlobs.Count) blobs"
 }
 if($temperature -eq 'warm' -and $blobs.Count -ne 0){throw 'Warm client downloaded content blobs instead of using its private cache'}
 return [ordered]@{phase=$temperature;receipt=$receiptPath;exitCode=$code;cleanExit=$true;manifestRequests=$manifestRequests.Count;blobRequests=$blobs.Count;uniqueBlobRequests=$uniqueBlobs.Count;requestBytes=[long](($requests | Measure-Object -Property bytes -Sum).Sum);milestones=$probe.milestones;routeLaps=$RouteLaps;laps=$probe.laps;world=$probe.world;cpuSkinDeformation=$deformation;postRouteWorld=$probe.postRouteWorld;render=$probe.render;windows=$probe.windows}
}

if($Phase -eq 'warm'){
 $identity=Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
 if($identity.worldHash -ne $worldHash -or $identity.nwsyncHash -ne $nwsyncHash -or
    $identity.mode -ne $Mode -or $identity.variant -ne $Variant -or $identity.renderThread -ne $RenderThread -or
    $identity.idleSeconds -ne $IdleSeconds -or ($identity.routeLaps ?? 1) -ne $RouteLaps -or
    [bool]$identity.pointerProbe -ne [bool]$PointerProbe -or [bool]$identity.cpuSkinPicking -ne [bool]$CpuSkinPicking -or
    [bool]$identity.joinDiagnostics -ne [bool]$JoinDiagnostics -or
    [bool]$identity.foregroundModelCompletion -ne [bool]$ForegroundModelCompletion -or
    [bool]$identity.prefetchLookahead -ne [bool]$PrefetchLookahead -or
    [bool]$identity.driveObstaclePrefix -ne [bool]$DriveObstaclePrefix -or [bool]$identity.driveObstacleSparse -ne [bool]$DriveObstacleSparse -or
    -not(Test-Path -LiteralPath (Join-Path $output 'cold-summary.json'))){
  throw 'A warm run requires an identical successful cold fixture, mode, renderer and route configuration'
 }
 $preparedCache=[string]$identity.preparedCache
 $profile=(Resolve-Path -LiteralPath ([string]$identity.networkProfile)).Path
 if((Split-Path $profile -Parent) -ne $scratch -or (Split-Path $profile -Leaf) -notmatch '^dn-profile-[a-f0-9]{8}$' -or ((Get-Item -LiteralPath $profile).Attributes -band [IO.FileAttributes]::ReparsePoint)){
  throw 'The warm run profile does not belong to this harness'
 }
}else{
 if(Test-Path -LiteralPath $output){throw 'A cold run requires a new OutputRoot and an empty client NWSync cache'}
 # NWSync writes hash plus random staging filenames. Keep the private
 # profile shallow enough for the existing Windows replacement helper.
 $profile=Join-Path $scratch ('dn-profile-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
 New-Item -ItemType Directory -Path $output,$profile,$settings,$userData | Out-Null
 $seedData=Get-Content -LiteralPath $inputSettings -Raw | ConvertFrom-Json -AsHashtable
 if($seedData.version -ne 3){throw 'A v3 native settings seed is required'}
 # Only alter the isolated test copy. No Workshop or installed local override
 # may furnish the custom fixture assets in either admission.
 $seedData.modsDirectory=''
 $seedData.disabledMods=@()
 $seedData | ConvertTo-Json -Depth 12 -Compress | Set-Content -LiteralPath (Join-Path $settings 'client-settings.json') -Encoding utf8
 @'
[rendering]
particles_enabled=true
particle_collision_enabled=false
compact_scenery=false
fov_degrees=45.0
shadow_lights=1
'@ | Set-Content -LiteralPath $rendering -Encoding utf8
 # Prepared assets belong outside source workspaces. Keep this private cache
 # distinct from the installed client cache and the NWSync ownership under
 # profile/replacement-client/server-content. Both legs use this exact cache.
 $preparedCache=Join-Path ([IO.Path]::GetTempPath()) ('nwn-dense-prepared-'+[Guid]::NewGuid().ToString('N'))
 $identity=[ordered]@{
  worldHash=$worldHash; nwsyncHash=$nwsyncHash; manifestHash=$repo.manifestHash
  mode=$Mode; variant=$Variant; renderThread=$RenderThread; idleSeconds=$IdleSeconds; routeLaps=$RouteLaps
  pointerProbe=[bool]$PointerProbe; cpuSkinPicking=[bool]$CpuSkinPicking; joinDiagnostics=[bool]$JoinDiagnostics
  foregroundModelCompletion=[bool]$ForegroundModelCompletion; prefetchLookahead=[bool]$PrefetchLookahead
  driveObstaclePrefix=[bool]$DriveObstaclePrefix; driveObstacleSparse=[bool]$DriveObstacleSparse
  preparedCache=$preparedCache; preparedCachePolicy='private-cold-then-reused'; networkProfile=$profile
 }
 $identity | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $identityPath -Encoding utf8
}

$runs=@()
if($Phase -ne 'warm'){
 $cold=Invoke-ClientRun 'cold' $preparedCache
 $cold | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $output 'cold-summary.json') -Encoding utf8
 $runs+=,$cold
}
if($Phase -ne 'cold'){
 $warm=Invoke-ClientRun 'warm' $preparedCache
 if($Phase -eq 'warm'){$runs+=,(Get-Content -LiteralPath (Join-Path $output 'cold-summary.json') -Raw | ConvertFrom-Json -AsHashtable)}
 $runs+=,$warm
}
$pairClean=$runs.Count -eq 2 -and @($runs | Where-Object {-not $_.cleanExit -or $_.exitCode -ne 0}).Count -eq 0
$summary=[ordered]@{
 format='dense-local-client-pair-v1'; success=$true; phase=$Phase; mode=$Mode; variant=$Variant
 manifestHash=$repo.manifestHash; routeLaps=$RouteLaps; pointerProbe=[bool]$PointerProbe
 cpuSkinPicking=[bool]$CpuSkinPicking; joinDiagnostics=[bool]$JoinDiagnostics
 foregroundModelCompletion=[bool]$ForegroundModelCompletion; prefetchLookahead=[bool]$PrefetchLookahead
 driveObstaclePrefix=[bool]$DriveObstaclePrefix; driveObstacleSparse=[bool]$DriveObstacleSparse
 pairedCleanExit=$pairClean; runs=$runs
}
$summaryPath=Join-Path $output "summary-$Phase.json"
$summary | ConvertTo-Json -Depth 17 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output $summaryPath
