param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='point-visual-series-v1',[ValidateRange(1,3)][int]$Count=2)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspace=Split-Path $project -Parent
$output=Join-Path $project ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $output){throw 'Point visual series report exists'}
. (Join-Path $PSScriptRoot 'local-test-guard.ps1')
Assert-NativeLocalTestAvailable $project
$sources=@('systems/client_dummies.gd','systems/client_fade.gd','systems/area_visual_state.gd','systems/area_visual_runtime.gd','systems/visual_world.gd','systems/visual_runtime.gd','systems/visual_resources.gd','systems/visual_model.gd','systems/local_connection.gd','systems/visual_probe.gd','systems/particle_world.gd','systems/particle_surface.gd','tools/area-visual-definition.mjs','tools/client-dummies.mjs','tools/visual-delivery.mjs','tools/visual-definition.mjs','tools/visual-definition-bundle.cjs','tools/staging-visual-definition.mjs','tools/staging-visual-model.mjs','tools/isolate-visual-delivery.mjs','tools/export-visual-model.mjs','tools/local-host.cjs','tools/local-protocol.cjs','join-local.ps1')
$hashes=@{}
foreach($name in $sources){$hashes[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
$bridge=(Get-Content -LiteralPath (Join-Path $project '.cache/local-bridge/latest.json') -Raw | ConvertFrom-Json).build
if(-not $bridge.StartsWith((Join-Path $project '.cache/local-bridge/'),[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected isolated bridge root'}
$bridgeHashes=@{}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $bridge 'assets') -File){$bridgeHashes[$file.Name]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
for($i=1;$i-le$Count;$i++){if(Test-Path -LiteralPath (Join-Path $project ('reports/'+$Run+'-'+$i+'.json'))){throw 'Per-run report exists'}}
$rows=[Collections.Generic.List[object]]::new();$failure=$null;$restored=$false
try{
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module GodotPoints
 for($i=1;$i-le$Count;$i++){
  foreach($name in $sources){if((Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$name]){throw 'Point visual sources changed before run'}}
  $name=$Run+'-'+$i+'.json'
  & (Join-Path $project 'join-local.ps1') -PointVisualSmoke -AutoPlay -NativeVerbose -Report $name *> (Join-Path $project ('reports/'+$Run+'-'+$i+'.launcher.log'))
  $exit=$LASTEXITCODE
  $report=Get-Content -LiteralPath (Join-Path $project ('reports/'+$name)) -Raw | ConvertFrom-Json
  $checks=@($report.visualTest.checks)
  $row=@{report=$name;launcherExit=$exit;success=$report.success;checks=$checks.Count;nativeExit=$report.nativeExit;forced=$report.nativeShutdown.forced;retiredWorldOwners=$report.nativeShutdown.observed.retiredWorldOwners;trackedSurvivors=$report.nativeShutdown.observed.worldSurvivors;failure=$report.failure}
  $rows.Add($row);Write-Output ($row | ConvertTo-Json -Compress)
  if($exit-ne0-or-not$report.success-or$report.nativeExit-ne0-or$report.nativeShutdown.forced-or-not$report.disconnected-or$checks.Count-ne30-or@($checks|Where-Object {-not $_.passed}).Count-ne0-or$report.nativeShutdown.observed.worldSurvivors-ne0){throw ('Point visual series failed at '+$name)}
  foreach($source in $sources){if((Get-FileHash -LiteralPath (Join-Path $project $source) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$source]){throw 'Point visual source changed during run'}}
  foreach($file in $bridgeHashes.Keys){if((Get-FileHash -LiteralPath (Join-Path $bridge ('assets/'+$file)) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$bridgeHashes[$file]){throw 'Immutable isolated bridge changed during run'}}
 }
}catch{$failure=$_.Exception.Message}
finally{
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module Prelude
 $ownedHome=[IO.Path]::GetFullPath((Join-Path $workspace 'runtime-logs/local-multiplayer-server'))
 $restored=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object {$_.CommandLine.Contains('"'+$ownedHome+'"')-and$_.CommandLine.Contains('-module "Prelude"')}).Count-eq1
 $result=@{scope='Real owned-server area-effect packets plus explicitly authored invalid-target object/dummy adapter probes; no public connections or FPS acceptance';success=($null-eq$failure-and$rows.Count-eq$Count-and$restored);expected=$Count;runs=@($rows.ToArray());failure=$failure;sourceSha256=$hashes;bridge=$bridge;bridgeAssetsSha256=$bridgeHashes;ordinaryServerRestored=$restored}
 $result|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $output -Encoding utf8
}
if($failure){throw $failure}
if(-not $restored){throw 'Ordinary owned local server was not restored'}
