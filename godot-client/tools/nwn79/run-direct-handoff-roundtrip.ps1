param(
 [string]$ProjectRoot='',
 [string]$Install='',
 [string]$SettingsSource='',
 [string]$OutputRoot='',
 [ValidateRange(60,180)][int]$TimeoutSeconds=150,
 [switch]$Run
)
$ErrorActionPreference='Stop'
$sourceClient=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path $sourceClient -Parent
$project=if($ProjectRoot){[IO.Path]::GetFullPath($ProjectRoot)}else{$sourceClient}
$installed=if($Install){[IO.Path]::GetFullPath($Install)}else{[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall'))}
$fixturePath=Join-Path $sourceClient 'reports/handoff-server-fixtures-v1.json'
$originScript=Join-Path $workspace 'scripts/local-multiplayer-server.ps1'
$destinationScript=Join-Path $sourceClient 'tools/handoff-server.ps1'
$directPath=Join-Path $project 'native_direct_session_world.gd'
$engine=Join-Path $project '.tools/Godot_v4.7.2-stable_win64_console.exe'
$fixture=Get-Content -LiteralPath $fixturePath -Raw|ConvertFrom-Json
if($fixture.version -ne 1 -or @($fixture.servers).Count -ne 2 -or $fixture.command -ne '-native-portal'){throw 'Owned two-server handoff fixture differs'}
$origin=@($fixture.servers|Where-Object {$_.label -eq 'A' -and $_.port -eq 5121 -and $_.destination -eq 5122})
$destination=@($fixture.servers|Where-Object {$_.label -eq 'B' -and $_.port -eq 5122 -and $_.destination -eq 5121})
if($origin.Count -ne 1 -or $destination.Count -ne 1){throw 'Owned handoff endpoints differ'}
foreach($server in $fixture.servers){
 $module=Join-Path ([string]$server.profile) ('modules/'+$server.module+'.mod')
 if(-not(Test-Path -LiteralPath $module -PathType Leaf) -or (Get-FileHash -LiteralPath $module -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$server.sha256){throw ('Authored handoff module differs: '+$server.label)}
}
if(-not(Test-Path -LiteralPath $directPath -PathType Leaf) -or -not(Test-Path -LiteralPath $engine -PathType Leaf) -or -not(Test-Path -LiteralPath $installed -PathType Container)){throw 'Godot direct-world, pinned engine or NWN installation is unavailable'}
if((Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant() -cne 'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643'){throw 'Private roundtrip requires pinned Godot console'}
$hook=[IO.File]::ReadAllText($directPath).Contains('direct-headless-portal-roundtrip-check')
& (Join-Path $project 'tools/nwn79/check-godot-only.ps1')|Out-Null
if(-not$Run){
 [ordered]@{format='nwn79-direct-handoff-roundtrip-plan-v1';status='pending';hookPresent=$hook;servers=@([ordered]@{port=5121;module=$origin[0].module},[ordered]@{port=5122;module=$destination[0].module});route=@(5121,5122,5121);settings='isolated copied version-3 settings';report='direct_portal_roundtrip_check.hops';assertions=@('two ordered old-session retirements','two newly admitted controllable worlds','three distinct session connections','origin area restored','current resource scope and stale-work rejection','clean acknowledged shutdown');clientOrServerStarted=$false;fpsMeasurements=0}|ConvertTo-Json -Depth 5
 return
}
if(-not$hook){throw 'Protocol-owned direct-world return hook is pending; roundtrip runner will not start either server'}
if(-not$SettingsSource -or -not$OutputRoot){throw 'Live roundtrip requires SettingsSource and a fresh OutputRoot'}
$settingsSource=[IO.Path]::GetFullPath($SettingsSource)
$output=[IO.Path]::GetFullPath($OutputRoot)
if(-not$output.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($project+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)){throw 'Roundtrip receipts require a fresh workspace directory outside the running project'}
$settingsFile=Join-Path $settingsSource 'client-settings.json'
if(-not(Test-Path -LiteralPath $settingsFile -PathType Leaf) -or (Get-Content -LiteralPath $settingsFile -Raw|ConvertFrom-Json).version -ne 3){throw 'Roundtrip needs an already imported copied version-3 settings source'}
if((Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue) -or (Get-NetUDPEndpoint -LocalPort 5122 -ErrorAction SilentlyContinue)){throw 'Private handoff server port is already in use; preserved'}
function Require([bool]$ok,[string]$reason){if(-not$ok){throw ('Roundtrip receipt assertion failed: '+$reason)}}
New-Item -ItemType Directory -Path $output -Force|Out-Null
$private=Join-Path $output 'private'
$settings=Join-Path $private 'settings';$profile=Join-Path $private 'profile';$userData=Join-Path $private 'user-data'
$report=Join-Path $output 'roundtrip.json'
$stdout=Join-Path $output 'roundtrip.stdout.log';$stderr=Join-Path $output 'roundtrip.stderr.log'
$originStarted=$false;$destinationStarted=$false;$process=$null;$failure='';$result=[ordered]@{status='fail';reason='not started'}
try{
 New-Item -ItemType Directory -Path $settings,$profile,$userData -Force|Out-Null
 foreach($name in @('client-settings.json','Local State')){$file=Join-Path $settingsSource $name;if(Test-Path -LiteralPath $file -PathType Leaf){Copy-Item -LiteralPath $file -Destination (Join-Path $settings $name)}}
 & $originScript -Action Start -Port 5121 -Module $origin[0].module|Out-Null;$originStarted=$true
 & $destinationScript -Action Start|Out-Null;$destinationStarted=$true
 $deadline=[DateTime]::UtcNow.AddSeconds(30)
 while(-not(Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue) -or -not(Get-NetUDPEndpoint -LocalPort 5122 -ErrorAction SilentlyContinue)){
  if([DateTime]::UtcNow -ge $deadline){throw 'Owned handoff servers did not bind both UDP ports'}
  Start-Sleep -Milliseconds 250
 }
 $serverBinary=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
 foreach($server in $fixture.servers){
  $endpoint=Get-NetUDPEndpoint -LocalPort $server.port -ErrorAction Stop
  $owners=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'"|Where-Object {$_.ExecutablePath -eq $serverBinary -and $_.CommandLine -and $_.CommandLine.Contains('"'+$server.profile+'"') -and $_.ProcessId -in $endpoint.OwningProcess})
  Require ($owners.Count -eq 1) ('UDP '+$server.port+' is owned by the exact authored server profile')
 }
 $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$engine;$start.WorkingDirectory=$project;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.Environment['APPDATA']=$userData
 $arguments=@('--headless','--path',$project,'--script','res://native_direct_session_world.gd','--','--direct-session',('--direct-install='+$installed),('--direct-profile='+$profile),('--direct-settings='+$settings),('--report='+$report),'--direct-host=127.0.0.1','--direct-port=5121','--direct-headless-check=true','--direct-pregen-bic=fighter.bic','--direct-headless-portal-roundtrip-check=true')
 foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($start)
 if($null -eq $process){throw 'Godot roundtrip client did not start'}
 $outTask=$process.StandardOutput.ReadToEndAsync();$errTask=$process.StandardError.ReadToEndAsync()
 if(-not$process.WaitForExit($TimeoutSeconds*1000)){$process.Kill($true);[void]$process.WaitForExit(10000);throw 'Godot roundtrip client timed out'}
 if(-not$outTask.Wait(10000) -or -not$errTask.Wait(10000)){throw 'Godot roundtrip output did not close'}
 [IO.File]::WriteAllText($stdout,$outTask.Result);[IO.File]::WriteAllText($stderr,$errTask.Result)
 Require ($process.ExitCode -eq 0) 'Godot process exited successfully'
 $result=(& (Join-Path $PSScriptRoot 'verify-direct-handoff-roundtrip-receipt.ps1') -Report $report)|ConvertFrom-Json
}catch{
 $failure=$_.Exception.Message
 $result=[ordered]@{status='fail';reason=$failure;report=$report}
}finally{
 if($process -ne $null){if(-not$process.HasExited){$process.Kill($true);[void]$process.WaitForExit(10000)};$process.Dispose()}
 $cleanupErrors=@()
 if($destinationStarted){try{& $destinationScript -Action Stop|Out-Null}catch{$cleanupErrors+=('destination: '+$_.Exception.Message)}}
 if($originStarted){try{& $originScript -Action Stop -Port 5121|Out-Null}catch{$cleanupErrors+=('origin: '+$_.Exception.Message)}}
 $private=[IO.Path]::GetFullPath($private)
 if(-not$private.StartsWith($output+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe handoff credential cleanup path'}
 if(Test-Path -LiteralPath $private){Remove-Item -LiteralPath $private -Recurse -Force}
 if($cleanupErrors.Count){$failure='Owned server cleanup failed: '+($cleanupErrors -join '; ');$result=[ordered]@{status='fail';reason=$failure;report=$report}}
 [ordered]@{format='nwn79-direct-handoff-roundtrip-v1';route=@(5121,5122,5121);result=$result;failure=$failure;liveSettingsWrites=0;fpsMeasurements=0;nwn79Complete=$false}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $output 'summary.json') -Encoding utf8
}
if($failure){throw $failure}
Write-Output ('Godot-only private handoff roundtrip PASS: '+(Join-Path $output 'summary.json'))
