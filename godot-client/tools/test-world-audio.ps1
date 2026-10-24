param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='world-audio-series-v1',[ValidateRange(1,3)][int]$Count=2)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspace=Split-Path $project -Parent
$output=Join-Path $project ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $output){throw 'World audio series report exists'}
. (Join-Path $PSScriptRoot 'local-test-guard.ps1')
Assert-NativeLocalTestAvailable $project
$sources=@('systems/world_audio.gd','systems/world_sound_state.gd','systems/audio_stream_transfer.gd','systems/client_dummies.gd','systems/area_visual_runtime.gd','systems/visual_world.gd','systems/visual_runtime.gd','systems/visual_resources.gd','systems/local_connection.gd','systems/visual_probe.gd','systems/particle_world.gd','tools/world-audio.mjs','tools/world-audio-evidence.cjs','tools/native-audio.mjs','tools/visual-delivery.mjs','tools/local-host.cjs','tools/local-protocol.cjs','tools/isolate-audio.mjs','tools/silent-audio.mjs','tools/build-local-bridge.mjs','join-local.ps1')
$hashes=@{}
foreach($name in $sources){$hashes[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
$bridge=(Get-Content -LiteralPath (Join-Path $project '.cache/local-bridge/latest.json') -Raw | ConvertFrom-Json).build
if(-not $bridge.StartsWith((Join-Path $project '.cache/local-bridge/'),[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected bridge root'}
$bridgeHashes=@{}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $bridge 'assets') -File){$bridgeHashes[$file.Name]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
for($i=1;$i-le$Count;$i++){if(Test-Path -LiteralPath (Join-Path $project ('reports/'+$Run+'-'+$i+'.json'))){throw 'Per-run audio report exists'}}
$rows=[Collections.Generic.List[object]]::new();$failure=$null;$restored=$false
try{
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module GodotSounds2
 for($i=1;$i-le$Count;$i++){
  foreach($name in $sources){if((Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$name]){throw 'Audio source changed before run'}}
  $name=$Run+'-'+$i+'.json'
  & (Join-Path $project 'join-local.ps1') -WorldAudioSmoke -AutoPlay -NativeVerbose -Report $name *> (Join-Path $project ('reports/'+$Run+'-'+$i+'.launcher.log'))
  $exit=$LASTEXITCODE
  $report=Get-Content -LiteralPath (Join-Path $project ('reports/'+$name)) -Raw | ConvertFrom-Json
  $checks=@($report.visualTest.checks)
  $row=@{report=$name;launcherExit=$exit;success=$report.success;checks=$checks.Count;nativeExit=$report.nativeExit;forced=$report.nativeShutdown.forced;retiredWorldOwners=$report.nativeShutdown.observed.retiredWorldOwners;trackedSurvivors=$report.nativeShutdown.observed.worldSurvivors;failure=$report.failure}
  $rows.Add($row);Write-Output ($row | ConvertTo-Json -Compress)
  if($exit-ne0-or-not$report.success-or$report.nativeExit-ne0-or$report.nativeShutdown.forced-or-not$report.disconnected-or$checks.Count-ne39-or@($checks|Where-Object {-not $_.passed}).Count-ne0){throw ('World audio series failed at '+$name)}
  foreach($source in $sources){if((Get-FileHash -LiteralPath (Join-Path $project $source) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$source]){throw 'Audio source changed during run'}}
  foreach($file in $bridgeHashes.Keys){if((Get-FileHash -LiteralPath (Join-Path $bridge ('assets/'+$file)) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$bridgeHashes[$file]){throw 'Immutable bridge changed during audio run'}}
 }
}catch{$failure=$_.Exception.Message}
finally{
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module Prelude
 $ownedHome=[IO.Path]::GetFullPath((Join-Path $workspace 'runtime-logs/local-multiplayer-server'))
 $restored=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object {$_.CommandLine.Contains('"'+$ownedHome+'"')-and$_.CommandLine.Contains('-module "Prelude"')}).Count-eq1
 $result=@{scope='Actual owned-server effect/script packets, original waveform transport/native playback and explicit private dummy probes; no public connections or performance acceptance';success=($null-eq$failure-and$rows.Count-eq$Count-and$restored);expected=$Count;runs=@($rows.ToArray());failure=$failure;sourceSha256=$hashes;bridge=$bridge;bridgeAssetsSha256=$bridgeHashes;ordinaryServerRestored=$restored}
 $result|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $output -Encoding utf8
}
if($failure){throw $failure}
if(-not $restored){throw 'Ordinary owned server was not restored'}
