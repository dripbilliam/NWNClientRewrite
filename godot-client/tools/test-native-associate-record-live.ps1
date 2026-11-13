[CmdletBinding()]
param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-associate-record-live-v1',[string]$ProtectedKeyFile='',[string]$DistinctFromAudit='')
$ErrorActionPreference='Stop'
$recordProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$recordWorkspace=[IO.Path]::GetFullPath((Join-Path $recordProject '..'))
$recordInstall=[IO.Path]::GetFullPath((Join-Path $recordWorkspace '../FullDecomp/NwnRootInstall'))
$recordBinary=Join-Path $recordInstall 'bin/win32/nwserver.exe'
if(-not$ProtectedKeyFile-or-not$DistinctFromAudit){throw 'Explicit protected participant and distinct-identity audit are required'}
if((Get-FileHash -LiteralPath $recordBinary).Hash-ne'98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){throw 'Unexpected original server executable'}
if((Get-NetUDPEndpoint -LocalPort 5127 -ErrorAction SilentlyContinue)-or(Get-NetUDPEndpoint -LocalPort 5125 -ErrorAction SilentlyContinue)){throw 'Owned test ports occupied; existing sessions preserved'}
if(-not(Test-Path -LiteralPath $ProtectedKeyFile)){throw 'Protected local-test credential unavailable'}
$recordCredentialPaths=@($ProtectedKeyFile,(Join-Path $recordWorkspace 'runtime-logs/local-multiplayer-server/native-barter-main.dpapi'))|Select-Object -Unique
$recordCredentialBefore=@($recordCredentialPaths|ForEach-Object{@{path=[IO.Path]::GetFullPath($_);sha256=(Get-FileHash -LiteralPath $_).Hash}})
$recordAuditHash=(Get-FileHash -LiteralPath $DistinctFromAudit).Hash
# Prove the existing ensure helpers can only take their no-build branches.
$recordWindow=Get-Content -LiteralPath (Join-Path $recordProject '.cache/native-window/build-manifest.json') -Raw|ConvertFrom-Json
if($recordWindow.source-ne(Get-FileHash -LiteralPath (Join-Path $recordProject 'native/window_modes.c')).Hash.ToLowerInvariant()-or$recordWindow.builder-ne(Get-FileHash -LiteralPath (Join-Path $recordProject 'tools/build-window-modes.ps1')).Hash.ToLowerInvariant()-or$recordWindow.binary-ne(Get-FileHash -LiteralPath (Join-Path $recordProject '.cache/native-window/nwn-window-modes.exe')).Hash.ToLowerInvariant()){throw 'Window build inputs changed; no build authorized'}
foreach($kind in @('kernel','resource-index')){
 $manifest=Get-Content -LiteralPath (Join-Path $recordProject ('.cache/native-'+$kind+'/build-manifest.json')) -Raw|ConvertFrom-Json -AsHashtable
 $binary=if($kind-eq'kernel'){'nwn-particle-kernel.dll'}else{'nwn-resource-index.dll'}
 if($manifest.binarySha256-ne(Get-FileHash -LiteralPath (Join-Path $recordProject ('.cache/native-'+$kind+'/'+$binary))).Hash.ToLowerInvariant()){throw 'Existing native output differs; no build authorized'}
 foreach($entry in $manifest.sources.GetEnumerator()){if($entry.Value-ne(Get-FileHash -LiteralPath (Join-Path $recordProject $entry.Key)).Hash.ToLowerInvariant()){throw 'Native source changed; no rebuild authorized'}}
 foreach($header in Get-ChildItem -LiteralPath (Join-Path $recordProject 'native') -File -Filter '*.hpp'){$relative=$header.FullName.Substring($recordProject.Length+1).Replace('\','/');if(-not$manifest.sources.ContainsKey($relative)){throw 'Unpinned native header would trigger a build'}}
}
$recordOutputs=@('.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json')
$recordBefore=@($recordOutputs|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $recordProject $_)).Hash.ToLowerInvariant()}})
$recordProtectedBefore=@(Get-CimInstance Win32_Process -Filter 'ProcessId=25060 OR ProcessId=7568'|Select-Object ProcessId,Name,CreationDate,ExecutablePath)
if($recordProtectedBefore.Count-ne2){throw 'Protected process baseline differs; no test launched'}
$recordDirectory=Join-Path $recordProject ('.cache/associate-record-live-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$recordHome=Join-Path $recordDirectory 'server';[IO.Directory]::CreateDirectory($recordHome)|Out-Null
$recordProcess=$null;$recordFailure=$null;$recordAccepted=$false;$recordCleaned=$false;$recordResult=$null
$recordRuntimePrior=$env:NWN_GODOT_RUNTIME
try{
 & node (Join-Path $recordProject 'tests/native_associate_record_gui_fixture.mjs') ('--directory='+$recordHome) ('--install='+$recordInstall)|Out-Null
 if($LASTEXITCODE-ne0){throw 'New owned target-GUI fixture preparation failed'}
 $recordFixture=Get-Content -LiteralPath (Join-Path $recordHome 'fixture.json') -Raw|ConvertFrom-Json
 $recordInfo=[Diagnostics.ProcessStartInfo]::new();$recordInfo.FileName=$recordBinary;$recordInfo.WorkingDirectory=Split-Path $recordBinary;$recordInfo.UseShellExecute=$false;$recordInfo.CreateNoWindow=$true;$recordInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
 $recordInfo.Environment['NWN_DO_NOT_NAT_PUNCH']='1'
 foreach($argument in @('-userdirectory',$recordHome,'-port','5127','-publicserver','0','-servername','OwnedAssociateRecordInput','-maxclients','1','-servervault','0','-autosaveinterval','0','-module',$recordFixture.module)){$recordInfo.ArgumentList.Add($argument)}
 $recordProcess=[Diagnostics.Process]::Start($recordInfo)
 $recordDeadline=[DateTime]::UtcNow.AddSeconds(20)
 do{$recordEndpoint=Get-NetUDPEndpoint -LocalPort 5127 -ErrorAction SilentlyContinue;if($recordEndpoint-and$recordEndpoint.OwningProcess-contains$recordProcess.Id){break};if($recordProcess.HasExited){throw 'Owned server exited before admission'};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow-lt$recordDeadline)
 if(-not$recordEndpoint-or$recordEndpoint.OwningProcess-notcontains$recordProcess.Id){throw 'Owned original server did not bind5127'}
 $env:NWN_GODOT_RUNTIME='editor'
 & (Join-Path $recordProject 'join-native.ps1') -ActionCheck -Headless -AssociateRecordCheck -AssociateRecordDirectory $recordHome -AssociateRecordDistinctAudit $DistinctFromAudit -EngineRuntime editor -Debugger -Run $Run -ProtectedKeyFile $ProtectedKeyFile
 $recordExit=$LASTEXITCODE
 $recordResult=Get-Content -LiteralPath (Join-Path $recordProject ('reports/'+$Run+'.json')) -Raw|ConvertFrom-Json
 $recordAccepted=$recordExit-eq0-and$recordResult.success-and$recordResult.actions.success-and$recordResult.associateRecordServerProof.success-and$recordResult.associateRecordLifecycle.success-and$recordResult.sourceUnchanged-and$recordResult.unpinnedProtocolModules.Count-eq0-and$recordResult.publicConnections-eq0
 if(-not$recordAccepted){throw 'Composed original-server target Record assertions failed'}
}catch{$recordFailure=$_.Exception.GetType().FullName}
finally{
 $env:NWN_GODOT_RUNTIME=$recordRuntimePrior
 if($recordProcess-and-not$recordProcess.HasExited){$recordOwned=Get-CimInstance Win32_Process -Filter ('ProcessId = '+$recordProcess.Id);if($recordOwned.ExecutablePath-eq$recordBinary-and$recordOwned.CommandLine.Contains($recordHome)){$recordProcess.Kill();$recordProcess.WaitForExit()}else{throw 'Owned server identity changed; unrelated process preserved'}}
 $recordCleaned=-not(Get-NetUDPEndpoint -LocalPort 5127 -ErrorAction SilentlyContinue|Where-Object OwningProcess -eq $recordProcess.Id)
 $recordAfter=@($recordBefore|ForEach-Object{@{path=$_.path;before=$_.sha256;after=(Get-FileHash -LiteralPath (Join-Path $recordProject $_.path)).Hash.ToLowerInvariant()}})
 $recordOutputsPreserved=@($recordAfter|Where-Object{$_.before-ne$_.after}).Count-eq0
 $recordProtectedAfter=@(Get-CimInstance Win32_Process -Filter 'ProcessId=25060 OR ProcessId=7568'|Select-Object ProcessId,Name,CreationDate,ExecutablePath)
 $recordProcessesPreserved=($recordProtectedBefore|ConvertTo-Json -Depth 5 -Compress)-eq($recordProtectedAfter|ConvertTo-Json -Depth 5 -Compress)
 $recordCredentialsUnchanged=@($recordCredentialBefore|Where-Object{(Get-FileHash -LiteralPath $_.path).Hash-ne$_.sha256}).Count-eq0
 $recordAuditUnchanged=(Get-FileHash -LiteralPath $DistinctFromAudit).Hash-eq$recordAuditHash
 $recordReceipt=[ordered]@{success=($recordAccepted-and-not$recordFailure-and$recordCleaned-and$recordOutputsPreserved-and$recordProcessesPreserved-and$recordCredentialsUnchanged-and$recordAuditUnchanged);run=$Run;directory=$recordDirectory;failureType=$recordFailure;testedAtUtc=[DateTime]::UtcNow.ToString('o');checks=if($recordResult){$recordResult.actions.checks.Count}else{0};serverProcessId=if($recordProcess){$recordProcess.Id}else{$null};serverCleaned=$recordCleaned;fixture=$recordFixture;nativeOutputs=$recordAfter;nativeOutputsPreserved=$recordOutputsPreserved;protectedProcesses=$recordProtectedAfter;protectedProcessesPreserved=$recordProcessesPreserved;credentialFilesUnchanged=$recordCredentialsUnchanged;identityAuditUnchanged=$recordAuditUnchanged;privateKeysLogged=$false;publicConnections=0;gpu=$false;nativeBuilds=0;scope='Owned hidden unchanged original server on unused-or-fail5127, distinct-public-identity guard before login and explicit current-user protected-pipe credential, real native source controls and received NPC Record/GUI3/4 outcomes. Ordinary launches/defaults/MAIN/public endpoints and previous fixtures untouched. No GPU/pixel/remote/DM parity claim.'}
 [IO.File]::WriteAllText((Join-Path $recordDirectory 'runner.json'),($recordReceipt|ConvertTo-Json -Depth 12)+[Environment]::NewLine)
 if($recordReceipt.success){[IO.File]::WriteAllText((Join-Path $recordProject ('reports/'+$Run+'.isolation.json')),($recordReceipt|ConvertTo-Json -Depth 12)+[Environment]::NewLine)}
 [pscustomobject]@{success=$recordReceipt.success;checks=$recordReceipt.checks;failureType=$recordFailure;directory=$recordDirectory;serverCleaned=$recordCleaned;nativeOutputsPreserved=$recordOutputsPreserved;protectedProcessesPreserved=$recordProcessesPreserved}|ConvertTo-Json
}
if(-not$recordReceipt.success){throw 'Owned composed Associate Record test failed; bounded evidence preserved'}
