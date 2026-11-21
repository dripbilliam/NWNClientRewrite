[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Run,[ValidatePattern('^[a-z0-9_]+$')][string]$CreationClass='fighter',[ValidateSet('manual','recommended')][string]$CreationPackage='manual',[string]$CreationDirectory='',[int]$OwnedServerProcessId=0,[string]$CreationReconnectFrom='',[IO.FileStream]$KeyLease)
$ErrorActionPreference='Stop'
$creationProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$creationWorkspace=[IO.Path]::GetFullPath((Join-Path $creationProject '..'))
$creationAlt=Join-Path $creationWorkspace 'runtime-logs/local-multiplayer-server/native-barter-alt.dpapi'
$creationMain=Join-Path $creationWorkspace 'runtime-logs/local-multiplayer-server/native-barter-main.dpapi'
$creationReport=Join-Path $creationProject ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $creationReport){throw 'Existing evidence retained; choose a new run'}
$creationLockPath=Join-Path $creationProject '.cache/creation-full-alt-key.lease'
$creationOwnsLock=$null-eq$KeyLease
if($KeyLease-and(-not$CreationDirectory-or[IO.Path]::GetFullPath($KeyLease.Name)-ne[IO.Path]::GetFullPath($creationLockPath)-or-not$KeyLease.CanWrite-or$KeyLease.SafeFileHandle.IsInvalid)){throw 'Existing creation key lease is unavailable or differs'}
$creationLock=if($creationOwnsLock){[IO.File]::Open($creationLockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}else{$KeyLease}
$creationPort=if($CreationDirectory){5129}else{5121};$creationEndpointProcess=if($CreationDirectory){$OwnedServerProcessId}else{7568}
$creationFailure=$null;$creationResult=$null;$creationAccepted=$false
$creationOutputs=@('.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json')
$creationBefore=@();$creationProfiles=@();$creationProtected=@()
try{
 if($CreationDirectory){
  if($OwnedServerProcessId-le0){throw 'Explicit owned server identity required'}
  $creationServerIdentity=Get-CimInstance Win32_Process -Filter ('ProcessId='+$OwnedServerProcessId)
  $creationFixture=Get-Content -LiteralPath (Join-Path $CreationDirectory 'fixture.json') -Raw|ConvertFrom-Json
  if($creationFixture.kind-ne'owned-native-first-level-vault'-or$creationFixture.directory-ne[IO.Path]::GetFullPath($CreationDirectory)-or$creationFixture.port-ne5129-or$creationServerIdentity.ExecutablePath-ne$creationFixture.serverPath-or-not$creationServerIdentity.CommandLine.Contains($CreationDirectory)){throw 'Owned vault server identity differs'}
 }elseif($CreationReconnectFrom-or$OwnedServerProcessId){throw 'Reconnect and owned PID require the isolated vault directory'}
 $creationEndpoint=Get-NetUDPEndpoint -LocalPort $creationPort -ErrorAction Stop
 if($creationEndpoint.OwningProcess-notcontains$creationEndpointProcess){throw 'Expected original server endpoint changed; no test launched'}
 $creationProtected=@(Get-CimInstance Win32_Process -Filter 'ProcessId=25060 OR ProcessId=7568'|Select-Object ProcessId,Name,CreationDate,ExecutablePath)
 if($creationProtected.Count-ne2-or-not($creationProtected|Where-Object{$_.ProcessId-eq7568-and$_.Name-eq'nwserver.exe'})){throw 'Protected server/editor identity changed'}
 $creationProfiles=@(@($creationAlt,$creationMain)|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash}})
 # These exact checks prove join-native's ensure calls take their no-build paths.
 $creationWindow=Get-Content -LiteralPath (Join-Path $creationProject '.cache/native-window/build-manifest.json') -Raw|ConvertFrom-Json
 if($creationWindow.source-ne(Get-FileHash -LiteralPath (Join-Path $creationProject 'native/window_modes.c')).Hash.ToLowerInvariant()-or$creationWindow.builder-ne(Get-FileHash -LiteralPath (Join-Path $creationProject 'tools/build-window-modes.ps1')).Hash.ToLowerInvariant()-or$creationWindow.binary-ne(Get-FileHash -LiteralPath (Join-Path $creationProject '.cache/native-window/nwn-window-modes.exe')).Hash.ToLowerInvariant()){throw 'Window build inputs changed; no build authorized'}
 foreach($creationKind in @('kernel','resource-index')){
  $creationManifest=Get-Content -LiteralPath (Join-Path $creationProject ('.cache/native-'+$creationKind+'/build-manifest.json')) -Raw|ConvertFrom-Json -AsHashtable
  $creationBinary=if($creationKind-eq'kernel'){'nwn-particle-kernel.dll'}else{'nwn-resource-index.dll'}
  if($creationManifest.binarySha256-ne(Get-FileHash -LiteralPath (Join-Path $creationProject ('.cache/native-'+$creationKind+'/'+$creationBinary))).Hash.ToLowerInvariant()){throw 'Existing output differs; no build authorized'}
  foreach($creationEntry in $creationManifest.sources.GetEnumerator()){if($creationEntry.Value-ne(Get-FileHash -LiteralPath (Join-Path $creationProject $creationEntry.Key)).Hash.ToLowerInvariant()){throw 'Native inputs changed; no build authorized'}}
  foreach($creationHeader in Get-ChildItem -LiteralPath (Join-Path $creationProject 'native') -File -Filter '*.hpp'){$creationRelative=$creationHeader.FullName.Substring($creationProject.Length+1).Replace('\','/');if(-not$creationManifest.sources.ContainsKey($creationRelative)){throw 'Unpinned header; no build authorized'}}
 }
 $creationBefore=@($creationOutputs|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $creationProject $_)).Hash.ToLowerInvariant()}})
 & node (Join-Path $creationProject 'tools/query-native-creation-server.mjs') ('--port='+$creationPort) ('--output='+$creationReport+'.before-query.json')
 if($LASTEXITCODE-ne0){throw 'Original server is occupied or admission rules differ; no login sent'}
 $creationJoinArgs=@{CreationCheck=$true;CreationClass=$CreationClass;CreationPackage=$CreationPackage;Headless=$true;Debugger=$true;EngineRuntime='editor';LocalOnly=$true;Run=$Run;ProtectedKeyFile=$creationAlt}
 if($CreationDirectory){$creationJoinArgs.CreationDirectory=$CreationDirectory;$creationJoinArgs.CreationPort=5129}
 if($CreationReconnectFrom){$creationJoinArgs.CreationReconnectFrom=$CreationReconnectFrom}
 & (Join-Path $creationProject 'join-native.ps1') @creationJoinArgs
 $creationResult=Get-Content -LiteralPath $creationReport -Raw|ConvertFrom-Json
 $creationAccepted=$creationResult.success-and$creationResult.creationProof.success-and$creationResult.sourceUnchanged-and$creationResult.unpinnedProtocolModules.Count-eq0-and$creationResult.publicConnections-eq0-and($creationResult.nativeCreation.nativeGenerated-or($CreationReconnectFrom-and$creationResult.creationReconnectSelection.success))-and$null-ne$creationResult.exportedCharacter
 if(-not$creationAccepted){throw 'Original-server full creation acceptance failed; inspect retained evidence'}
}catch{$creationFailure=$_.Exception.Message}
finally{
 $creationAfter=@($creationBefore|ForEach-Object{@{path=$_.path;before=$_.sha256;after=(Get-FileHash -LiteralPath (Join-Path $creationProject $_.path)).Hash.ToLowerInvariant()}})
 $creationOutputsPreserved=@($creationAfter|Where-Object{$_.before-ne$_.after}).Count-eq0
 $creationProtectedAfter=@(Get-CimInstance Win32_Process -Filter 'ProcessId=25060 OR ProcessId=7568'|Select-Object ProcessId,Name,CreationDate,ExecutablePath)
 $creationProcessesPreserved=($creationProtected|ConvertTo-Json -Depth 5 -Compress)-eq($creationProtectedAfter|ConvertTo-Json -Depth 5 -Compress)
 $creationProfilesPreserved=@($creationProfiles|Where-Object{(Get-FileHash -LiteralPath $_.path).Hash-ne$_.sha256}).Count-eq0
 $creationServerPreserved=(Get-NetUDPEndpoint -LocalPort $creationPort -ErrorAction SilentlyContinue).OwningProcess-contains$creationEndpointProcess
 $creationVacant=$false
 if($creationServerPreserved-and$creationResult){& node (Join-Path $creationProject 'tools/query-native-creation-server.mjs') ('--port='+$creationPort) ('--output='+$creationReport+'.after-query.json');$creationVacant=$LASTEXITCODE-eq0}
 $creationReceipt=[ordered]@{success=($creationAccepted-and-not$creationFailure-and$creationOutputsPreserved-and$creationProcessesPreserved-and$creationProfilesPreserved-and$creationServerPreserved-and$creationVacant);run=$Run;failure=$creationFailure;checks=if($creationResult){$creationResult.creationProof.checks}else{0};testedAtUtc=[DateTime]::UtcNow.ToString('o');endpoint=('127.0.0.1:'+$creationPort);testedServerProcessId=$creationEndpointProcess;testedServerPreserved=$creationServerPreserved;protectedExistingServerProcessId=7568;originalServerVacantAfter=$creationVacant;nativeOutputs=$creationAfter;nativeOutputsPreserved=$creationOutputsPreserved;protectedProcessesPreserved=$creationProcessesPreserved;encryptedProfilesUnchanged=$creationProfilesPreserved;privateKeysLogged=$false;publicConnections=0;nativeBuilds=0;gpu=$false;scope=if($CreationDirectory){'One original server-vault creation/selection leg with received admission/export; paired disconnect/reconnect acceptance belongs to the dedicated outer fixture receipt.'}else{'Actual native first-level source controls, upload, received original Prelude admission and exported BIC, with exclusive protected ALT pipe and existing server/editor preserved. No server-vault reconnect claim from this local-vault case.'}}
 [IO.File]::WriteAllText((Join-Path $creationProject ('reports/'+$Run+'.isolation.json')),($creationReceipt|ConvertTo-Json -Depth 10)+[Environment]::NewLine)
 if($creationOwnsLock){$creationLock.Dispose()}
 [pscustomobject]@{success=$creationReceipt.success;checks=$creationReceipt.checks;failure=$creationFailure;serverPreserved=$creationServerPreserved;nativeOutputsPreserved=$creationOutputsPreserved;protectedProcessesPreserved=$creationProcessesPreserved;encryptedProfilesUnchanged=$creationProfilesPreserved}|ConvertTo-Json
}
if(-not$creationReceipt.success){throw 'Bounded first-level original-server acceptance did not pass; evidence preserved'}
