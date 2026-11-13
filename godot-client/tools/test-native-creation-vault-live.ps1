[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^native-creation-[a-z0-9-]+$')][string]$RunPrefix,[Parameter(Mandatory)][string]$LocalBaseline,[ValidatePattern('^[a-z0-9_]+$')][string]$CreationClass='fighter',[ValidateSet('manual','recommended')][string]$CreationPackage='manual',[switch]$CreateOnlyDiagnostic)
$ErrorActionPreference='Stop'
$vaultDiagnosticPrevious=[Environment]::GetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC','Process')
$vaultProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$vaultBaseline=Get-Content -LiteralPath $LocalBaseline -Raw|ConvertFrom-Json
if(-not$vaultBaseline.success-or-not$vaultBaseline.creationProof.success-or-not$vaultBaseline.creationTailExportProof.success-or-not$vaultBaseline.creationPostAdmissionExportComplete-or$vaultBaseline.endpoint-ne'127.0.0.1:5121'){throw 'A completed original5121 source-control baseline is required before the vault leg'}
if(Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue){throw 'Owned5129 is occupied; existing process preserved'}
$vaultDirectory=Join-Path $vaultProject ('.cache/creation-full-vault-tests/'+$RunPrefix)
if(Test-Path -LiteralPath $vaultDirectory){throw 'Existing vault evidence retained'}
$vaultHome=Join-Path $vaultDirectory 'server'
$vaultLock=[IO.File]::Open((Join-Path $vaultProject '.cache/creation-full-alt-key.lease'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$vaultProcess=$null;$vaultFailure=$null;$vaultAccepted=$false;$vaultResult=$null;$vaultCreate=$null;$vaultReconnect=$null
try{
 if($CreateOnlyDiagnostic){$env:NWN_CREATION_APPLY_DIAGNOSTIC='1'}
 & node (Join-Path $vaultProject 'tools/native-creation-vault-fixture.cjs') $vaultHome|Out-Null
 if($LASTEXITCODE-ne0){throw 'Fresh original vault fixture preparation failed'}
 $vaultFixture=Get-Content -LiteralPath (Join-Path $vaultHome 'fixture.json') -Raw|ConvertFrom-Json
 $vaultStart=[Diagnostics.ProcessStartInfo]::new();$vaultStart.FileName=$vaultFixture.serverPath;$vaultStart.WorkingDirectory=Split-Path $vaultFixture.serverPath;$vaultStart.UseShellExecute=$false;$vaultStart.CreateNoWindow=$true;$vaultStart.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$vaultStart.Environment['NWN_DO_NOT_NAT_PUNCH']='1'
 foreach($vaultArgument in @('-userdirectory',$vaultHome,'-port','5129','-publicserver','0','-servername','OwnedNativeCreationVault','-maxclients','1','-servervault','1','-autosaveinterval','0','-module','Prelude')){$vaultStart.ArgumentList.Add($vaultArgument)}
 $vaultProcess=[Diagnostics.Process]::Start($vaultStart)
 $vaultDeadline=[DateTime]::UtcNow.AddSeconds(25)
 do{$vaultEndpoint=Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue;if($vaultEndpoint.OwningProcess-contains$vaultProcess.Id){break};if($vaultProcess.HasExited){throw 'Owned vault server exited during startup'};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow-lt$vaultDeadline)
 if($vaultEndpoint.OwningProcess-notcontains$vaultProcess.Id){throw 'Owned original vault server did not bind5129'}
 $vaultReady=$false
 for($vaultAttempt=0;$vaultAttempt-lt8;$vaultAttempt++){
  & node (Join-Path $vaultProject 'tools/query-native-creation-server.mjs') --port=5129 ('--output='+(Join-Path $vaultDirectory ('ready-'+$vaultAttempt+'.json')))
  if($LASTEXITCODE-eq0){$vaultReady=$true;break}
  if($vaultProcess.HasExited){break};Start-Sleep -Milliseconds 250
 }
 if(-not$vaultReady){throw 'Owned server-vault query did not confirm empty legal Prelude'}
 & (Join-Path $vaultProject 'tools/test-native-creation-full-live.ps1') -Run ($RunPrefix+'-create') -CreationClass $CreationClass -CreationPackage $CreationPackage -CreationDirectory $vaultHome -OwnedServerProcessId $vaultProcess.Id -KeyLease $vaultLock
 $vaultCreatePath=Join-Path $vaultProject ('reports/'+$RunPrefix+'-create.json')
 $vaultCreate=Get-Content -LiteralPath $vaultCreatePath -Raw|ConvertFrom-Json
 if(-not$vaultCreate.success){throw 'Source-control creation into original server vault failed'}
 if($CreateOnlyDiagnostic){
  $vaultAccepted=$vaultCreate.success
 }else{
 & (Join-Path $vaultProject 'tools/test-native-creation-full-live.ps1') -Run ($RunPrefix+'-reconnect') -CreationClass $CreationClass -CreationPackage $CreationPackage -CreationDirectory $vaultHome -OwnedServerProcessId $vaultProcess.Id -CreationReconnectFrom $vaultCreatePath -KeyLease $vaultLock
 $vaultReconnect=Get-Content -LiteralPath (Join-Path $vaultProject ('reports/'+$RunPrefix+'-reconnect.json')) -Raw|ConvertFrom-Json
 $vaultAccepted=$vaultReconnect.success-and$vaultReconnect.creationReconnectSelection.success-and$null-eq$vaultReconnect.nativeCreation-and$vaultReconnect.creationTailExportProof.success
 if(-not$vaultAccepted){throw 'Original server-vault selection/re-admission/export did not pass'}
 }
}catch{$vaultFailure=$_.Exception.Message}
finally{
 [Environment]::SetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC',$vaultDiagnosticPrevious,'Process')
 $vaultCleaned=$vaultProcess-eq$null
 if($vaultProcess){
  if(-not$vaultProcess.HasExited){
   $vaultIdentity=Get-CimInstance Win32_Process -Filter ('ProcessId='+$vaultProcess.Id)
   if($vaultIdentity.ExecutablePath-eq$vaultFixture.serverPath-and$vaultIdentity.CommandLine.Contains($vaultHome)){$vaultProcess.Kill();$vaultProcess.WaitForExit(10000)|Out-Null}else{$vaultFailure='Owned server identity changed; unrelated process preserved'}
  }
  $vaultCleaned=-not(Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue|Where-Object OwningProcess -eq $vaultProcess.Id)
 }
 $vaultLock.Dispose()
 if(Test-Path -LiteralPath $vaultDirectory){$vaultResult=[ordered]@{success=($vaultAccepted-and$vaultCleaned-and-not$vaultFailure);runPrefix=$RunPrefix;diagnostic=[bool]$CreateOnlyDiagnostic;createOnly=[bool]$CreateOnlyDiagnostic;failure=$vaultFailure;serverCleaned=$vaultCleaned;serverProcessId=if($vaultProcess){$vaultProcess.Id}else{$null};endpoint='127.0.0.1:5129';exclusiveAltAcrossBothLegs=$true;created=if($vaultCreate){$vaultCreate.exportedCharacter.sha256}else{$null};reconnected=if($vaultReconnect){$vaultReconnect.exportedCharacter.sha256}else{$null};existingServerProcessId=7568;publicConnections=0;nativeBuilds=0;gpu=$false;scope=if($CreateOnlyDiagnostic){'Single original5129 creation diagnostic: exact first setup/full world capture and durable apply boundaries, observed CPU and60s no-ACK owned stack, unchanged360s cap. No implicit reconnect or complete vault-pair claim.'}else{'Fresh unchanged original server/profile on unused-or-fail5129: source-control first-level creation, original server-vault save, disconnect, fresh native chooser received server-row selection, re-admission and exported stats/equipment. Existing5121/editor preserved by each guarded child leg.'}};[IO.File]::WriteAllText((Join-Path $vaultDirectory 'runner.json'),($vaultResult|ConvertTo-Json -Depth 8)+[Environment]::NewLine)}
 [pscustomobject]@{success=($vaultAccepted-and$vaultCleaned-and-not$vaultFailure);failure=$vaultFailure;serverCleaned=$vaultCleaned;directory=$vaultDirectory}|ConvertTo-Json
}
if(-not$vaultResult.success){throw 'Owned original server-vault acceptance failed; evidence preserved'}
