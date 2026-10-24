param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='weather-cold-series-v1',[ValidateRange(1,5)][int]$Count=3)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspace=Split-Path $project -Parent
$output=Join-Path $project ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $output){throw 'Cold weather report exists'}
. (Join-Path $PSScriptRoot 'local-test-guard.ps1')
Assert-NativeLocalTestAvailable $project
$shader='7f33fb9053d0c4ad64e2688bede6a31dc7815a52'
$shaderFamily='cdfe2a8d86deff48154b1cd0d6e857301f5e37f0d8930754f63ff9c2c85045a6'
$cacheFolder=[IO.Path]::GetFullPath((Join-Path ([Environment]::GetFolderPath('ApplicationData')) ('Godot/app_userdata/NWN Native Engine Prototype/shader_cache/SceneForwardClusteredShaderRD/'+$shaderFamily)))
$cacheFile=[IO.Path]::GetFullPath((Join-Path $cacheFolder ($shader+'.vulkan.cache')))
if((Split-Path $cacheFile -Parent)-ne$cacheFolder-or(Split-Path $cacheFile -Leaf)-ne($shader+'.vulkan.cache')){throw 'Unexpected owned shader cache target'}
foreach($entry in @((Get-Item -LiteralPath $cacheFolder),(Get-Item -LiteralPath $cacheFile))){if($entry.Attributes-band[IO.FileAttributes]::ReparsePoint){throw 'Linked shader cache target preserved'}}
$backupFolder=Join-Path $project ('.cache/weather-cold-cache/'+$Run)
if(Test-Path -LiteralPath $backupFolder){throw 'Cold weather backup folder exists'}
New-Item -ItemType Directory -Path $backupFolder | Out-Null
$originalBackup=Join-Path $backupFolder 'original.vulkan.cache'
Copy-Item -LiteralPath $cacheFile -Destination $originalBackup
$originalSha=(Get-FileHash -LiteralPath $cacheFile -Algorithm SHA256).Hash.ToLowerInvariant()
if((Get-FileHash -LiteralPath $originalBackup -Algorithm SHA256).Hash.ToLowerInvariant()-ne$originalSha){throw 'Shader backup verification failed'}
$sources=@('systems/particle_surface.gd','systems/particle_world.gd','systems/weather_world.gd','systems/weather_state.gd','systems/weather_placement.gd','systems/visual_model.gd','systems/area_environment.gd','systems/local_connection.gd','tests/weather_probe.gd','tools/local-host.cjs','tools/weather-models.mjs','tools/weather-delivery.mjs','tools/particle-simulation.mjs','../src/model_particles.js')
$hashes=@{}
foreach($name in $sources){$hashes[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
for($i=1;$i-le$Count;$i++){if(Test-Path -LiteralPath (Join-Path $project ('reports/'+$Run+'-'+$i+'.json'))){throw 'Per-run report exists'}}
$rows=[Collections.Generic.List[object]]::new();$failure=$null;$restored=$false
try{
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module GodotWeather1
 for($i=1;$i-le$Count;$i++){
  foreach($name in $sources){if((Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$name]){throw 'Native source changed during cold shader series'}}
  # Only this renderer's exact cache entry is removed, after a verified
  # reversible copy. No directory deletion, editor-cache change or registry edit.
  Remove-Item -LiteralPath $cacheFile
  if(Test-Path -LiteralPath $cacheFile){throw 'Shader entry did not become cold'}
  $name=$Run+'-'+$i+'.json'
  & (Join-Path $project 'join-local.ps1') -WeatherSmoke -AutoPlay -NativeVerbose -Report $name *> (Join-Path $project ('reports/'+$Run+'-'+$i+'.launcher.log'))
  $exit=$LASTEXITCODE
  $report=Get-Content -LiteralPath (Join-Path $project ('reports/'+$name)) -Raw | ConvertFrom-Json
  $engine=Get-Content -LiteralPath (Join-Path $project ('reports/'+$Run+'-'+$i+'.engine.log')) -Raw
  $miss=$engine.Contains('Shader cache miss for SceneForwardClusteredShaderRD/'+$shaderFamily+'/'+$shader)
  $generated=Test-Path -LiteralPath $cacheFile
  $generatedSha=$null
  if($generated){$generatedSha=(Get-FileHash -LiteralPath $cacheFile -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $cacheFile -Destination (Join-Path $backupFolder ('generated-'+$i+'.vulkan.cache'))}
  $row=@{report=$name;launcherExit=$exit;success=$report.success;nativeExit=$report.nativeExit;nativeShutdown=$report.nativeShutdown;coldMissObserved=$miss;cacheRegenerated=$generated;cacheSha256=$generatedSha;checks=@($report.weatherTest.checks).Count;admissions=@($report.nativeLoaded).Count;failure=$report.failure}
  $rows.Add($row);Write-Output ($row | ConvertTo-Json -Depth 5 -Compress)
  if($exit-ne0-or-not$report.success-or$report.nativeExit-ne0-or$report.nativeShutdown.forced-or-not$report.disconnected-or-not$miss-or-not$generated){throw ('Cold weather series stopped at '+$name)}
  foreach($source in $sources){if((Get-FileHash -LiteralPath (Join-Path $project $source) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$source]){throw 'Native source changed during cold shader run'}}
 }
}catch{$failure=$_.Exception.Message}
finally{
 Copy-Item -LiteralPath $originalBackup -Destination $cacheFile -Force
 $restored=(Get-FileHash -LiteralPath $cacheFile -Algorithm SHA256).Hash.ToLowerInvariant()-eq$originalSha
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module Prelude
 $result=@{scope='Exact owned-game rain shader cache evicted reversibly; actual native compile miss and full local weather A-B-A/quit, not driver-cache flushing or proof of previous heap corruption cause';success=($null-eq$failure-and$rows.Count-eq$Count-and$restored);expected=$Count;runs=@($rows.ToArray());failure=$failure;sourceSha256=$hashes;originalCacheSha256=$originalSha;originalCacheRestored=$restored;ordinaryServerRestored=$true}
 $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $output -Encoding utf8
}
if($failure){throw $failure}
