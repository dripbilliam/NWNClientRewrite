param(
 [Parameter(Mandatory)][string]$ProjectRoot,
 [Parameter(Mandatory)][string]$SettingsSource,
 [Parameter(Mandatory)][string]$FixtureRoot,
 [Parameter(Mandatory)][string]$OutputRoot,
 [ValidatePattern('^--direct-[a-z0-9-]+=.+$')][string]$Phase1Flag='--direct-server-vault-create-check=true',
 [ValidatePattern('^--direct-[a-z0-9-]+=.+$')][string]$Phase2Flag='--direct-server-vault-reconnect-check=true',
 [ValidateRange(120,480)][int]$TimeoutSeconds=330,
 [ValidateRange(0,8)][int]$Screen=1
)
$ErrorActionPreference='Stop'
$sourceProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=[IO.Path]::GetFullPath((Join-Path $sourceProject '..'))
$project=[IO.Path]::GetFullPath($ProjectRoot)
$source=[IO.Path]::GetFullPath($SettingsSource)
$fixture=[IO.Path]::GetFullPath($FixtureRoot)
$output=[IO.Path]::GetFullPath($OutputRoot)
$separator=[string][IO.Path]::DirectorySeparatorChar
if(-not $output.StartsWith($workspace+$separator,[StringComparison]::OrdinalIgnoreCase) -or
 $output.StartsWith($sourceProject+$separator,[StringComparison]::OrdinalIgnoreCase) -or
 $output.StartsWith($project+$separator,[StringComparison]::OrdinalIgnoreCase) -or
 (Test-Path -LiteralPath $output)){throw 'OutputRoot must be fresh workspace scratch outside the Godot project'}
$outputParent=(Resolve-Path -LiteralPath (Split-Path $output -Parent)).Path
if(-not $outputParent.StartsWith($workspace+$separator,[StringComparison]::OrdinalIgnoreCase) -or
 ((Get-Item -LiteralPath $outputParent).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'OutputRoot parent is outside workspace or redirected'}
$settingsFile=Join-Path $source 'client-settings.json'
if(-not(Test-Path -LiteralPath $settingsFile -PathType Leaf) -or
 (Get-Content -LiteralPath $settingsFile -Raw|ConvertFrom-Json).version -ne 3){throw 'An isolated imported v3 settings source is required'}
$manifest=Join-Path $project 'godot-delivery-manifest.json'
if(-not(Test-Path -LiteralPath (Join-Path $project 'native_direct_session_world.gd') -PathType Leaf) -or
 -not(Test-Path -LiteralPath (Join-Path $project 'tests/native_creation_source_live_probe.gd') -PathType Leaf)){throw 'Godot project must include the opt-in physical creator probe'}
if($project -ne $sourceProject -and -not(Test-Path -LiteralPath $manifest -PathType Leaf)){throw 'Staged project is missing its delivery manifest'}
$godot=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
if(-not(Test-Path -LiteralPath $godot -PathType Leaf) -or
 (Get-FileHash -LiteralPath $godot -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'){throw 'Pinned graphical Godot is absent or changed'}
$server=Join-Path $PSScriptRoot 'vault-create-server.ps1'
$fixtureManifest=Join-Path $fixture 'fixture.json'
if(-not(Test-Path -LiteralPath $fixtureManifest -PathType Leaf) -or
 (Get-Content -LiteralPath $fixtureManifest -Raw|ConvertFrom-Json).servervault -ne 1){throw 'Owned empty ServerVault ON fixture is required'}
$install=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall'))
$settings=Join-Path $output 'settings'
$profile=Join-Path $output 'profile'
$userData=Join-Path $output 'user-data'
$phase1Report=Join-Path $output 'create.json'
$phase2Report=Join-Path $output 'reconnect.json'
$summaryPath=Join-Path $output 'summary.json'
$serverStarted=$false
$ownedServerPid=0
$activeClient=$null
$result=[ordered]@{
 format='nwn79-server-vault-create-reconnect-v1';pass=$false
 project=$project;projectKind=if($project -eq $sourceProject){'source'}else{'sealed-test-package'}
 packageManifestSha256=if(Test-Path -LiteralPath $manifest -PathType Leaf){(Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash.ToLowerInvariant()}else{''}
 servervault=1;initialBicCount=$null;createdBicCount=$null;reconnectedBicCount=$null
 createdBicSha256=@();reconnectedBicSha256=@();createdBicPathSha256='';reconnectedBicPathSha256=''
 finalBicCount=$null;finalBicSha256=@()
 serverPid=0;oneServerAcrossSessions=$false
 create=$null;reconnect=$null;serverStopped=$false;failure=''
}
function Read-OwnedStatus {
 $lines=@(& $server -Action Status -OutputRoot $fixture)
 return ($lines|Select-Object -Last 1|ConvertFrom-Json)
}
function Require-OneServer($status,[int]$ownedServerProcessId) {
 $ids=@($status.ownedPids)
 if($ids.Count -ne 1 -or [int]$ids[0] -ne $ownedServerProcessId){throw 'Exact owned server PID changed between sessions'}
}
function Read-SingleBicPathDigest {
 $vault=Join-Path $fixture 'profile/servervault'
 $files=@(Get-ChildItem -LiteralPath $vault -Recurse -File -Filter '*.bic')
 if($files.Count -ne 1){throw 'Expected exactly one server-vault BIC path'}
 $relative=[IO.Path]::GetRelativePath($vault,$files[0].FullName).Replace('\','/').ToLowerInvariant()
 if($relative.StartsWith('../') -or $relative.Contains('/../')){throw 'Server-vault BIC path escaped fixture'}
 return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($relative))).ToLowerInvariant()
}
function Run-Client([string]$report,[string]$fixtureFlag,[string]$phase) {
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$godot;$start.WorkingDirectory=$project;$start.UseShellExecute=$false
 $start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $start.Environment['APPDATA']=$userData;$start.Environment['LOCALAPPDATA']=$userData
 foreach($argument in @('--screen',[string]$Screen,'--path',$project,'--script','res://native_direct_session_world.gd','--',
   '--direct-session',('--direct-install='+$install),('--direct-profile='+$profile),('--direct-settings='+$settings),
   ('--report='+$report),'--direct-headless-check=true','--direct-host=127.0.0.1','--direct-port=5121',$fixtureFlag)){$start.ArgumentList.Add($argument)}
 if($phase -eq 'reconnect'){
  $start.ArgumentList.Add('--creation-reconnect-report='+$phase1Report)
  $start.ArgumentList.Add('--creation-reconnect-sha='+(Get-FileHash -LiteralPath $phase1Report -Algorithm SHA256).Hash.ToLowerInvariant())
 }
 $script:activeClient=[Diagnostics.Process]::Start($start)
 if($null -eq $script:activeClient){throw ('Godot did not start for '+$phase)}
 $stdout=$script:activeClient.StandardOutput.ReadToEndAsync()
 $stderr=$script:activeClient.StandardError.ReadToEndAsync()
 if(-not $script:activeClient.WaitForExit($TimeoutSeconds*1000)){
  $script:activeClient.Kill($true);[void]$script:activeClient.WaitForExit(10000)
  throw ('Godot '+$phase+' timed out')
 }
 if(-not $stdout.Wait(10000) -or -not $stderr.Wait(10000)){throw ('Godot '+$phase+' output did not close')}
 $exitCode=$script:activeClient.ExitCode
 $script:activeClient.Dispose();$script:activeClient=$null
 if(-not(Test-Path -LiteralPath $report -PathType Leaf)){throw ('Godot '+$phase+' made no receipt; exit '+$exitCode)}
 $parsed=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
 return [pscustomobject]@{exitCode=$exitCode;report=$parsed;sha256=(Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash.ToLowerInvariant()}
}
New-Item -ItemType Directory -Path $settings,$profile,$userData -Force|Out-Null
foreach($name in @('client-settings.json','Local State')){
 $inputFile=Join-Path $source $name
 if(Test-Path -LiteralPath $inputFile -PathType Leaf){Copy-Item -LiteralPath $inputFile -Destination (Join-Path $settings $name)}
}
try {
 $before=Read-OwnedStatus
 if(@($before.ownedPids).Count -ne 0 -or [int]$before.bicCount -ne 0){throw 'Creation fixture requires no running server and an empty vault'}
 $result.initialBicCount=[int]$before.bicCount
 $serverStarted=$true
 $started=& $server -Action Start -OutputRoot $fixture
 $ready=$false
 for($i=0;$i -lt 100;$i++){
  if(@(Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue).Count -gt 0){$ready=$true;break}
  Start-Sleep -Milliseconds 100
 }
 if(-not $ready){throw 'Owned ServerVault ON server did not bind UDP 5121'}
 $running=Read-OwnedStatus
 if(@($running.ownedPids).Count -ne 1){throw 'Expected exactly one owned server process'}
 $ownedServerPid=[int]$running.ownedPids[0];$result.serverPid=$ownedServerPid
 $created=Run-Client $phase1Report $Phase1Flag 'create'
 $createReceipt=$created.report.direct_server_vault_create_check
 $createPass=$created.exitCode -eq 0 -and $created.report.clean_exit -eq $true -and
  -not $created.report.failure -and
  $created.report.creationProof.success -eq $true -and
  $createReceipt.creatorOpened -eq $true -and $createReceipt.creatorSubmitted -eq $true -and
  $createReceipt.source19Sent -eq $true -and $createReceipt.worldAdmitted -eq $true -and
  $createReceipt.disconnectClean -eq $true -and -not [string]::IsNullOrWhiteSpace([string]$createReceipt.characterFingerprint)
 $result.create=[ordered]@{pass=[bool]$createPass;exitCode=$created.exitCode;cleanExit=[bool]$created.report.clean_exit;
  finalWorldReady=[bool]$created.report.world.ready;creatorOpened=[bool]$createReceipt.creatorOpened;
  creatorSubmitted=[bool]$createReceipt.creatorSubmitted;source19Sent=[bool]$createReceipt.source19Sent;
  worldAdmitted=[bool]$createReceipt.worldAdmitted;disconnectClean=[bool]$createReceipt.disconnectClean;
  characterFingerprint=[string]$createReceipt.characterFingerprint;reportSha256=$created.sha256}
 if(-not $createPass){throw 'Create/world/disconnect receipt failed'}
 $afterCreate=$null
 for($i=0;$i -lt 50;$i++){
  $afterCreate=Read-OwnedStatus
  Require-OneServer $afterCreate $ownedServerPid
  if([int]$afterCreate.bicCount -eq 1){break}
  Start-Sleep -Milliseconds 100
 }
 $result.createdBicCount=[int]$afterCreate.bicCount
 $result.createdBicSha256=@($afterCreate.bicSha256)
 if([int]$afterCreate.bicCount -ne 1 -or @($afterCreate.bicSha256).Count -ne 1){throw 'Server did not persist exactly one new BIC after clean disconnect'}
 $result.createdBicPathSha256=Read-SingleBicPathDigest
 $reconnected=Run-Client $phase2Report $Phase2Flag 'reconnect'
 $reconnectReceipt=$reconnected.report.direct_server_vault_reconnect_check
 $list=$reconnected.report.direct_character_list
 $noSecondCreatorDraft=-not ($reconnected.report.PSObject.Properties.Name -contains 'direct_creation') -and
  $reconnected.report.creationProof.reconnectSelection.uploadPerformed -eq $false
 $reconnectPass=$reconnected.exitCode -eq 0 -and $reconnected.report.clean_exit -eq $true -and
  -not $reconnected.report.failure -and
  $reconnected.report.creationProof.success -eq $true -and
  [int]$list.acceptedPackets -ge 1 -and [int]$list.receivedServerRows -ge 1 -and
  $reconnectReceipt.rosterAccepted -eq $true -and $reconnectReceipt.serverRowMatched -eq $true -and $reconnectReceipt.previewRequested -eq $true -and
  $reconnectReceipt.previewReady -eq $true -and $reconnectReceipt.playSent -eq $true -and
  $reconnectReceipt.worldAdmitted -eq $true -and $reconnectReceipt.disconnectClean -eq $true -and
  $noSecondCreatorDraft -and [string]$reconnectReceipt.characterFingerprint -ceq [string]$createReceipt.characterFingerprint
 $result.reconnect=[ordered]@{pass=[bool]$reconnectPass;exitCode=$reconnected.exitCode;cleanExit=[bool]$reconnected.report.clean_exit;
  finalWorldReady=[bool]$reconnected.report.world.ready;acceptedPackets=[int]$list.acceptedPackets;
  receivedServerRows=[int]$list.receivedServerRows;serverRowMatched=[bool]$reconnectReceipt.serverRowMatched;
  previewRequested=[bool]$reconnectReceipt.previewRequested;previewReady=[bool]$reconnectReceipt.previewReady;
  playSent=[bool]$reconnectReceipt.playSent;worldAdmitted=[bool]$reconnectReceipt.worldAdmitted;
  disconnectClean=[bool]$reconnectReceipt.disconnectClean;noSecondCreatorDraft=[bool]$noSecondCreatorDraft;
  characterFingerprint=[string]$reconnectReceipt.characterFingerprint;reportSha256=$reconnected.sha256}
 if(-not $reconnectPass){throw 'Reconnect/preview/Play/world receipt failed'}
 $afterReconnect=Read-OwnedStatus
 Require-OneServer $afterReconnect $ownedServerPid
 $result.reconnectedBicCount=[int]$afterReconnect.bicCount
 $result.reconnectedBicSha256=@($afterReconnect.bicSha256)
 if([int]$afterReconnect.bicCount -ne 1 -or @($afterReconnect.bicSha256).Count -ne 1){throw 'Server vault character count changed after reconnect'}
 $result.reconnectedBicPathSha256=Read-SingleBicPathDigest
 if($result.reconnectedBicPathSha256 -cne $result.createdBicPathSha256){throw 'Server vault BIC path changed after reconnect'}
 $result.oneServerAcrossSessions=$true
 $result.pass=$true
}catch{
 $result.failure=$_.Exception.Message
 throw
}finally{
 try {
  if($activeClient){if(-not $activeClient.HasExited){$activeClient.Kill($true);[void]$activeClient.WaitForExit(10000)};$activeClient.Dispose()}
  try {
   $beforeStop=Read-OwnedStatus
   $result.finalBicCount=[int]$beforeStop.bicCount
   $result.finalBicSha256=@($beforeStop.bicSha256)
  }finally{
   if($serverStarted){& $server -Action Stop -OutputRoot $fixture|Out-Null}
  }
  $afterStop=Read-OwnedStatus
  $result.serverStopped=@($afterStop.ownedPids).Count -eq 0 -and @(Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue).Count -eq 0
  if(-not $result.serverStopped){throw 'Owned server did not stop cleanly'}
 }catch{
  $result.pass=$false
  if($result.failure){$result.failure+='; cleanup: '+$_.Exception.Message}else{$result.failure='Cleanup: '+$_.Exception.Message}
 }
 foreach($name in @('client-settings.json','Local State')){
  $copy=Join-Path $settings $name
  if(Test-Path -LiteralPath $copy -PathType Leaf){Remove-Item -LiteralPath $copy -Force}
 }
 $result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $summaryPath -Encoding utf8
 $result|ConvertTo-Json -Compress -Depth 8
}
if(-not $result.pass){throw 'Server-vault creation/reconnect acceptance failed'}
