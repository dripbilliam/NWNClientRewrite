[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^native-direct-handoff-[a-z0-9-]+$')][string]$Run,[ValidateSet('roundtrip','cancel','failure')][string]$Scenario='roundtrip',[switch]$PrepareOnly,[switch]$Debugger)
$ErrorActionPreference='Stop'
$directProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$directWorkspace=Split-Path $directProject
$directDirectory=Join-Path $directProject ('.cache/native-direct-handoff/'+$Run)
$directBuilder=Join-Path $PSScriptRoot 'native-direct-handoff-fixture.mjs'
$directJoin=Join-Path $directProject 'join-native.ps1'
if($PrepareOnly){
 & node $directBuilder $directDirectory
 if($LASTEXITCODE-ne0){throw 'Direct-handoff preparation rejected; prior evidence preserved'}
 return
}
# Refuse before any server/key activity until Root installs the explicit mode.
$directJoinParameters=(Get-Command $directJoin).Parameters
foreach($directParameter in @('DirectHandoffCheck','DirectHandoffDirectory','DirectHandoffScenario')){if(-not$directJoinParameters.ContainsKey($directParameter)){throw 'Reviewed current direct-route opt-in hooks are not installed'}}
if(-not(Test-Path -LiteralPath (Join-Path $directDirectory 'fixture.json'))){throw 'PrepareOnly must create the reviewed fresh fixture first'}
$directDescriptorText=& node $directBuilder --verify $directDirectory
if($LASTEXITCODE-ne0){throw 'Owned direct-handoff fixture verification failed'}
$directFixture=$directDescriptorText|ConvertFrom-Json
foreach($directPort in @(5129,5130)){if(Get-NetUDPEndpoint -LocalPort $directPort -ErrorAction SilentlyContinue){throw 'Owned handoff endpoint occupied; existing process preserved'}}
foreach($directSuffix in @('.json','.native.json','.native.png','.settings.cfg','.layout.cfg','.lobby.cfg')){if(Test-Path -LiteralPath (Join-Path $directProject ('reports/'+$Run+$directSuffix))){throw 'Fresh report and preferences required; prior evidence retained'}}
foreach($directEvidence in @('runner.json','stop-destination.json','destination-stopped.json')){if(Test-Path -LiteralPath (Join-Path $directDirectory $directEvidence)){throw 'Prior direct-handoff evidence retained'}}
$directProtected=@(Get-CimInstance Win32_Process|Where-Object{$_.Name-in@('nwserver.exe','Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe','node.exe','electron.exe')}|Select-Object ProcessId,Name,ExecutablePath,CreationDate)
if(-not($directProtected|Where-Object{$_.ProcessId-eq7568-and$_.Name-eq'nwserver.exe'})-or-not($directProtected|Where-Object ProcessId -eq 25060)){throw 'Protected original server/editor identities changed'}
$directAlt=Join-Path $directWorkspace 'runtime-logs/local-multiplayer-server/native-barter-alt.dpapi'
$directMain=Join-Path $directWorkspace 'runtime-logs/local-multiplayer-server/native-barter-main.dpapi'
$directProfiles=@($directAlt,$directMain)|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash}}
$directOutputNames=@('.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json')
$directOutputs=@($directOutputNames|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $directProject $_)).Hash}})
$directInputs=@($directBuilder,$PSCommandPath,(Join-Path $PSScriptRoot 'native-direct-handoff-mode.cjs'),(Join-Path $PSScriptRoot 'native-direct-handoff-capture.cjs'),(Join-Path $PSScriptRoot 'native-direct-handoff-host-check.cjs'),(Join-Path $PSScriptRoot 'native-direct-handoff-recovery.cjs'),(Join-Path $PSScriptRoot 'native-direct-handoff-query.mjs'),(Join-Path $directProject 'tests/native_direct_handoff_world.gd'),(Join-Path $directProject 'tests/native_direct_handoff_probe.gd'),(Join-Path $directDirectory 'fixture.json'))
foreach($directServer in $directFixture.servers){$directInputs+=@($directServer.modulePath,$directServer.clientModule)}
$directBefore=@($directInputs|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash}})
. (Join-Path $PSScriptRoot 'native-level-up-no-build.ps1')
Assert-NativeLevelUpNoBuild -Root $directProject
$directLease=[IO.File]::Open((Join-Path $directProject '.cache/creation-full-alt-key.lease'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$directProcesses=@{A=$null;B=$null};$directClient=$null;$directAccepted=$false;$directFailure=$null;$directStopped=$false
function Stop-DirectOwned($directRow){
 $directProcess=$directProcesses[$directRow.label]
 if($null-eq$directProcess-or$directProcess.HasExited){return}
 $directCurrent=Get-CimInstance Win32_Process -Filter ('ProcessId='+$directProcess.Id)
 if($directCurrent.ExecutablePath-ne$directFixture.serverPath-or-not$directCurrent.CommandLine.Contains($directRow.profile)-or-not$directCurrent.CommandLine.Contains($directRow.module)){throw 'Owned server identity changed; unrelated process preserved'}
 $directProcess.Kill();$directProcess.WaitForExit(10000)|Out-Null
}
try{
 foreach($directRow in $directFixture.servers){
  $directStart=[Diagnostics.ProcessStartInfo]::new();$directStart.FileName=$directFixture.serverPath;$directStart.WorkingDirectory=Split-Path $directFixture.serverPath;$directStart.UseShellExecute=$false;$directStart.CreateNoWindow=$true;$directStart.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$directStart.Environment['NWN_DO_NOT_NAT_PUNCH']='1'
  foreach($directArgument in @('-userdirectory',$directRow.profile,'-port',[string]$directRow.port,'-publicserver','0','-servername',('OwnedNativeDirect'+$directRow.label),'-maxclients','1','-servervault','0','-autosaveinterval','0','-module',$directRow.module)){$directStart.ArgumentList.Add($directArgument)}
  $directProcess=[Diagnostics.Process]::Start($directStart);$directProcesses[$directRow.label]=$directProcess;$directDeadline=[DateTime]::UtcNow.AddSeconds(25)
  do{$directEndpoint=Get-NetUDPEndpoint -LocalPort $directRow.port -ErrorAction SilentlyContinue;if($directEndpoint.OwningProcess-contains$directProcess.Id){break};if($directProcess.HasExited){throw 'Owned direct server exited before readiness'};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow-lt$directDeadline)
  if($directEndpoint.OwningProcess-notcontains$directProcess.Id){throw 'Owned direct server did not bind its reviewed endpoint'}
  & node (Join-Path $PSScriptRoot 'native-direct-handoff-query.mjs') $directDirectory $directRow.label (Join-Path $directDirectory ('ready-'+$directRow.label+'.json'))
  if($LASTEXITCODE-ne0){throw 'Original direct-server module/legal/local-vault query failed'}
 }
 $directClientStart=[Diagnostics.ProcessStartInfo]::new();$directClientStart.FileName=(Get-Command pwsh).Source;$directClientStart.WorkingDirectory=$directWorkspace;$directClientStart.UseShellExecute=$false;$directClientStart.CreateNoWindow=$true;$directClientStart.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
 foreach($directArgument in @('-NoProfile','-File',$directJoin,'-DirectHandoffCheck','-DirectHandoffDirectory',$directDirectory,'-DirectHandoffScenario',$Scenario,'-Headless','-EngineRuntime','editor','-LocalOnly','-Run',$Run,'-ProtectedKeyFile',$directAlt)){$directClientStart.ArgumentList.Add($directArgument)}
 if($Debugger){$directClientStart.ArgumentList.Add('-Debugger')}
 $directClient=[Diagnostics.Process]::Start($directClientStart);$directRunDeadline=[DateTime]::UtcNow.AddSeconds(720)
 while(-not$directClient.HasExited-and[DateTime]::UtcNow-lt$directRunDeadline){
  $directRequestPath=Join-Path $directDirectory 'stop-destination.json'
  if($Scenario-eq'failure'-and-not$directStopped-and(Test-Path -LiteralPath $directRequestPath)){
   if((Get-Item -LiteralPath $directRequestPath).Length-gt4096){throw 'Destination stop request exceeds bound'}
   $directRequest=Get-Content -LiteralPath $directRequestPath -Raw|ConvertFrom-Json
   if($directRequest.kind-ne'native-direct-handoff-stop'-or$directRequest.version-ne1-or$directRequest.host-ne'127.0.0.1'-or$directRequest.port-ne5130-or$directRequest.fixtureNonce-ne$directFixture.nonce-or$directRequest.from-lt1-or$directRequest.to-le$directRequest.from){throw 'Unrecognized destination stop request'}
   $directB=$directFixture.servers|Where-Object label -eq 'B';Stop-DirectOwned $directB
   $directReleaseDeadline=[DateTime]::UtcNow.AddSeconds(8)
   do{$directRemaining=@(Get-NetUDPEndpoint -LocalPort 5130 -ErrorAction SilentlyContinue);if(-not$directRemaining.Count){break};if($directRemaining.OwningProcess-contains$directProcesses.B.Id){Start-Sleep -Milliseconds 100}else{throw 'Destination endpoint changed owner; preserved'}}while([DateTime]::UtcNow-lt$directReleaseDeadline)
   if($directRemaining.Count){throw 'Owned destination endpoint did not release'}
   $directAck=@{version=1;kind='native-direct-handoff-stopped';host='127.0.0.1';port=5130;fixtureNonce=$directFixture.nonce;requestSha256=(Get-FileHash -LiteralPath $directRequestPath).Hash.ToLowerInvariant();stopped=$true}
   $directAckStream=[IO.File]::Open((Join-Path $directDirectory 'destination-stopped.json'),[IO.FileMode]::CreateNew)
   try{$directBytes=[Text.Encoding]::UTF8.GetBytes(($directAck|ConvertTo-Json -Compress));$directAckStream.Write($directBytes)}finally{$directAckStream.Dispose()}
   $directStopped=$true
  }
  Start-Sleep -Milliseconds 100
 }
 if(-not$directClient.HasExited){throw 'Bounded direct-route client timed out; no retry'}
 $directResult=Get-Content -LiteralPath (Join-Path $directProject ('reports/'+$Run+'.json')) -Raw|ConvertFrom-Json
 $directAccepted=$directClient.ExitCode-eq0-and$directResult.success-and$directResult.directHandoffProof.success-and$directResult.sourceUnchanged-and$directResult.headless-eq$true-and$directResult.nativeExit-eq0-and$directResult.publicConnections-eq0-and$directResult.unpinnedProtocolModules.Count-eq0
 if(-not$directAccepted){throw 'Current direct-route authority proof rejected; no implicit retry'}
}catch{$directFailure=$_.Exception.Message}
finally{
 if($directClient-and-not$directClient.HasExited){$directCurrentClient=Get-CimInstance Win32_Process -Filter ('ProcessId='+$directClient.Id);if($directCurrentClient.ExecutablePath-eq$directClientStart.FileName-and$directCurrentClient.CommandLine.Contains($directJoin)-and$directCurrentClient.CommandLine.Contains($Run)-and$directCurrentClient.CommandLine.Contains($directDirectory)-and[Math]::Abs(($directCurrentClient.CreationDate.ToUniversalTime()-$directClient.StartTime.ToUniversalTime()).TotalMilliseconds)-lt1000){$directClient.Kill($true);$directClient.WaitForExit(10000)|Out-Null}else{$directFailure='Owned wrapper child identity changed; preserved'}}
 foreach($directRow in $directFixture.servers){try{Stop-DirectOwned $directRow}catch{$directFailure=$_.Exception.Message}}
 $directLease.Dispose()
 $directServerCleanup=@($directFixture.servers|ForEach-Object{$directOwnedProcess=$directProcesses[$_.label];@{label=$_.label;processId=if($directOwnedProcess){$directOwnedProcess.Id}else{$null};closed=$null-eq$directOwnedProcess-or$directOwnedProcess.HasExited;ownedSocketReleased=-not(Get-NetUDPEndpoint -LocalPort $_.port -ErrorAction SilentlyContinue|Where-Object OwningProcess -eq $directOwnedProcess.Id)}})
 $directInputGuards=@($directBefore|ForEach-Object{@{path=$_.path;unchanged=(Get-FileHash -LiteralPath $_.path).Hash-eq$_.sha256}})
 $directOutputGuards=@($directOutputs|ForEach-Object{@{path=$_.path;unchanged=(Get-FileHash -LiteralPath (Join-Path $directProject $_.path)).Hash-eq$_.sha256}})
 $directProfileGuards=@($directProfiles|ForEach-Object{@{path=$_.path;unchanged=(Get-FileHash -LiteralPath $_.path).Hash-eq$_.sha256}})
 $directProcessGuards=@($directProtected|ForEach-Object{$directCurrent=Get-CimInstance Win32_Process -Filter ('ProcessId='+$_.ProcessId);@{processId=$_.ProcessId;unchanged=$directCurrent-and$directCurrent.Name-eq$_.Name-and$directCurrent.ExecutablePath-eq$_.ExecutablePath-and$directCurrent.CreationDate-eq$_.CreationDate}})
 $directPassed=$directAccepted-and-not$directFailure-and-not($directServerCleanup.closed-contains$false)-and-not($directServerCleanup.ownedSocketReleased-contains$false)-and-not($directInputGuards.unchanged-contains$false)-and-not($directOutputGuards.unchanged-contains$false)-and-not($directProfileGuards.unchanged-contains$false)-and-not($directProcessGuards.unchanged-contains$false)
 $directReceipt=[ordered]@{success=$directPassed;run=$Run;scenario=$Scenario;route='native-session-host';failure=$directFailure;serverCleanup=$directServerCleanup;inputs=$directInputGuards;nativeOutputs=$directOutputGuards;encryptedProfiles=$directProfileGuards;protectedProcesses=$directProcessGuards;publicConnections=0;nativeBuilds=0;privateKeysLogged=$false;headless=$true;legacyLocalHostAcceptance=$false;pixelAcceptance=$false;performanceAcceptance=$false;destinationStopped=$directStopped}
 [IO.File]::WriteAllText((Join-Path $directDirectory 'runner.json'),($directReceipt|ConvertTo-Json -Depth 9)+[Environment]::NewLine)
 [pscustomobject]@{success=$directPassed;failure=$directFailure;run=$Run;scenario=$Scenario}|ConvertTo-Json
}
if(-not$directPassed){throw 'Owned current direct handoff rejected; evidence preserved'}
