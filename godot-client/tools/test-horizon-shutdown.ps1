param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='horizon-shutdown-batch-v1',[ValidateRange(1,12)][int]$Count=5)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspace=Split-Path $project -Parent
$output=Join-Path $project ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $output){throw 'Shutdown batch report already exists'}
. (Join-Path $PSScriptRoot 'local-test-guard.ps1')
Assert-NativeLocalTestAvailable $project
$sources=@('systems/area_sky.gd','systems/area_environment.gd','systems/local_connection.gd','main.gd','tools/local-host.cjs','tools/sky-delivery.mjs')
$hashes=@{}
foreach($name in $sources){$hashes[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
for($i=1;$i-le$Count;$i++){if(Test-Path -LiteralPath (Join-Path $project ('reports/'+$Run+'-'+$i+'.json'))){throw 'Per-run report already exists'}}
$rows=[Collections.Generic.List[object]]::new()
$failure=$null
try{
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module GodotSky1
 for($i=1;$i-le$Count;$i++){
  foreach($name in $sources){if((Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$name]){throw 'Native source changed during the shutdown series'}}
  $name=$Run+'-'+$i+'.json'
  $started=[DateTime]::UtcNow.ToString('o')
  & (Join-Path $project 'join-local.ps1') -PortalRegionSmoke -NativeVerbose -Report $name *> (Join-Path $project ('reports/'+$Run+'-'+$i+'.launcher.log'))
  $exit=$LASTEXITCODE
  $report=Get-Content -LiteralPath (Join-Path $project ('reports/'+$name)) -Raw | ConvertFrom-Json
  $row=@{report=$name;started=$started;ended=[DateTime]::UtcNow.ToString('o');launcherExit=$exit;success=$report.success;nativeExit=$report.nativeExit;nativeShutdown=$report.nativeShutdown;disconnected=$report.disconnected;admissions=@($report.nativeLoaded).Count;failure=$report.failure}
  $rows.Add($row)
  Write-Output ($row | ConvertTo-Json -Compress -Depth 4)
  if($exit-ne0 -or -not$report.success -or $report.nativeExit-ne0 -or $report.nativeShutdown.forced -or -not$report.disconnected){throw ('Native shutdown series stopped at '+$name)}
  $retired=$report.nativeShutdown.observed
  if($null-eq$retired-or$retired.frames-lt2-or$retired.retiredWorldOwners-ne18-or$retired.worldSurvivors-ne0-or$retired.nui.windows-ne0-or$retired.nui.resources-ne0-or$retired.partySurvivors-ne0-or$retired.buffSurvivors-ne0){throw ('Native retirement evidence missing at '+$name)}
 }
}catch{$failure=$_.Exception.Message}
finally{
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module Prelude
 $result=@{scope='Owned-local repeated whole-world A-B-A and graceful shutdown; no public/FPS acceptance or proof of the previous one-off crash cause';success=($null-eq$failure-and$rows.Count-eq$Count);expected=$Count;runs=@($rows.ToArray());failure=$failure;sourceSha256=$hashes;ordinaryServerRestored=$true}
 $result | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $output -Encoding utf8
}
if($failure){throw $failure}
