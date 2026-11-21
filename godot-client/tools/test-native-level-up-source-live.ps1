[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^native-level-up-source-[a-z0-9-]+$')][string]$Run,[ValidateSet('wizard-multiclass','sorcerer-caster','cleric-new-class')][string]$Case='wizard-multiclass')
$ErrorActionPreference='Stop'
$sourceProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceWorkspace=Split-Path $sourceProject
$sourceJoin=Join-Path $sourceProject 'join-native.ps1'
# Preflight must reject a staged harness before any profile, key or process use.
if(-not(Get-Command $sourceJoin).Parameters.ContainsKey('LevelUpSourceCheck')-or-not(Test-Path -LiteralPath (Join-Path $sourceProject 'tests/native_live_level_up_source_probe.gd'))){throw 'Reviewed source authority dispatch hooks are not installed'}
if(Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue){throw '5129 is occupied; existing process preserved'}
$sourceDirectory=Join-Path $sourceProject ('.cache/level-up-source-authority/'+$Run)
if((Test-Path -LiteralPath $sourceDirectory)-or(Test-Path -LiteralPath (Join-Path $sourceProject ('reports/'+$Run+'.json')))){throw 'Existing source authority evidence retained'}
$sourceHome=Join-Path $sourceDirectory 'server'
$sourceAlt=Join-Path $sourceWorkspace 'runtime-logs/local-multiplayer-server/native-barter-alt.dpapi'
$sourceMain=Join-Path $sourceWorkspace 'runtime-logs/local-multiplayer-server/native-barter-main.dpapi'
$sourceProtected=@(Get-CimInstance Win32_Process|Where-Object{$_.Name-in@('nwserver.exe','Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe','node.exe','electron.exe')}|Select-Object ProcessId,Name,ExecutablePath,CreationDate)
if(-not($sourceProtected|Where-Object{$_.ProcessId-eq7568-and$_.Name-eq'nwserver.exe'})-or-not($sourceProtected|Where-Object ProcessId -eq 25060)){throw 'Protected original server/editor identity changed'}
$sourceProfiles=@($sourceAlt,$sourceMain)|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash}}
$sourceOutputs=@('.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json')
$sourceBefore=@($sourceOutputs|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $sourceProject $_)).Hash}})
. (Join-Path $PSScriptRoot 'native-level-up-no-build.ps1')
Assert-NativeLevelUpNoBuild -Root $sourceProject
$sourceLease=[IO.File]::Open((Join-Path $sourceProject '.cache/creation-full-alt-key.lease'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$sourceServer=$null;$sourceFailure=$null;$sourceAccepted=$false;$sourceResult=$null
try{
 & node (Join-Path $sourceProject 'tools/native-level-up-source-server.cjs') $sourceHome
 if($LASTEXITCODE-ne0){throw 'Owned source level-up profile preparation failed'}
 $sourceFixture=Get-Content -LiteralPath (Join-Path $sourceHome 'fixture.json') -Raw|ConvertFrom-Json
 $sourceStart=[Diagnostics.ProcessStartInfo]::new();$sourceStart.FileName=$sourceFixture.serverPath;$sourceStart.WorkingDirectory=Split-Path $sourceFixture.serverPath;$sourceStart.UseShellExecute=$false;$sourceStart.CreateNoWindow=$true;$sourceStart.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$sourceStart.Environment['NWN_DO_NOT_NAT_PUNCH']='1'
 foreach($argument in @('-userdirectory',$sourceHome,'-port','5129','-publicserver','0','-servername','OwnedNativeSourceLevelUp','-maxclients','1','-servervault','0','-autosaveinterval','0','-module','Prelude')){$sourceStart.ArgumentList.Add($argument)}
 $sourceStarted=[DateTime]::UtcNow;$sourceServer=[Diagnostics.Process]::Start($sourceStart);$sourceDeadline=[DateTime]::UtcNow.AddSeconds(25)
 do{$sourceEndpoint=Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue;if($sourceEndpoint.OwningProcess-contains$sourceServer.Id){break};if($sourceServer.HasExited){throw 'Owned source server exited before readiness'};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow-lt$sourceDeadline)
 if($sourceEndpoint.OwningProcess-notcontains$sourceServer.Id){throw 'Owned source server did not bind5129'}
 $sourceReady=$false
 for($attempt=0;$attempt-lt8;$attempt++){
  & node (Join-Path $sourceProject 'tools/query-native-level-up-source-server.mjs') ('--output='+(Join-Path $sourceDirectory ('ready-'+$attempt+'.json')))
  if($LASTEXITCODE-eq0){$sourceReady=$true;break};Start-Sleep -Milliseconds 250
 }
 if(-not$sourceReady-or(Get-Item -LiteralPath (Join-Path $sourceHome 'logs/nwengineLog.txt')).LastWriteTimeUtc-lt$sourceStarted){throw 'Fresh owned legal/local-vault Prelude was not confirmed'}
 & $sourceJoin -LevelUpSourceCheck -LevelUpSourceCase $Case -LevelUpSourceDirectory $sourceHome -Headless -Debugger -EngineRuntime editor -LocalOnly -Run $Run -ProtectedKeyFile $sourceAlt
 $sourceResult=Get-Content -LiteralPath (Join-Path $sourceProject ('reports/'+$Run+'.json')) -Raw|ConvertFrom-Json
 $sourceAccepted=$sourceResult.success-and$sourceResult.levelUpSourceProof.success-and$sourceResult.levelUpSourceProof.sourceOnly-and$sourceResult.sourceUnchanged-and$sourceResult.unpinnedProtocolModules.Count-eq0-and$sourceResult.publicConnections-eq0-and$sourceResult.nativeExit-eq0
 if(-not$sourceAccepted){throw 'Original source level-up authority did not pass; no retry'}
}catch{$sourceFailure=$_.Exception.Message}
finally{
 $sourceCleaned=$null-eq$sourceServer
 if($sourceServer){
  if(-not$sourceServer.HasExited){$current=Get-CimInstance Win32_Process -Filter ('ProcessId='+$sourceServer.Id);if($current.ExecutablePath-eq$sourceFixture.serverPath-and$current.CommandLine.Contains($sourceHome)){$sourceServer.Kill();$sourceServer.WaitForExit(10000)|Out-Null}else{$sourceFailure='Owned source-server identity changed; unrelated process preserved'}}
  $sourceCleaned=-not(Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue|Where-Object OwningProcess -eq $sourceServer.Id)
 }
 $sourceLease.Dispose()
 $sourceOutputGuards=@($sourceBefore|ForEach-Object{@{path=$_.path;unchanged=(Get-FileHash -LiteralPath (Join-Path $sourceProject $_.path)).Hash-eq$_.sha256}})
 $sourceProfileGuards=@($sourceProfiles|ForEach-Object{@{path=$_.path;unchanged=(Get-FileHash -LiteralPath $_.path).Hash-eq$_.sha256}})
 $sourceProcessGuards=@($sourceProtected|ForEach-Object{$now=Get-CimInstance Win32_Process -Filter ('ProcessId='+$_.ProcessId);@{processId=$_.ProcessId;unchanged=$now-and$now.Name-eq$_.Name-and$now.ExecutablePath-eq$_.ExecutablePath-and$now.CreationDate-eq$_.CreationDate}})
 $sourcePassed=$sourceAccepted-and$sourceCleaned-and-not$sourceFailure-and-not($sourceOutputGuards.unchanged-contains$false)-and-not($sourceProfileGuards.unchanged-contains$false)-and-not($sourceProcessGuards.unchanged-contains$false)
 $sourceReceipt=[ordered]@{success=$sourcePassed;run=$Run;case=$Case;failure=$sourceFailure;serverCleaned=$sourceCleaned;serverProcessId=if($sourceServer){$sourceServer.Id}else{$null};endpoint='127.0.0.1:5129';nativeOutputs=$sourceOutputGuards;encryptedProfiles=$sourceProfileGuards;protectedProcesses=$sourceProcessGuards;privateKeysLogged=$false;publicConnections=0;nativeBuilds=0;scope='One source-mode1 original Prelude level-up authority workload. Existing server/editor/other processes preserved; XP-only detached installed BIC, actual native source controls and independent original-server results/export. No legacy-editor or complete visual/FPS claim.'}
 if(Test-Path -LiteralPath $sourceDirectory){[IO.File]::WriteAllText((Join-Path $sourceDirectory 'runner.json'),($sourceReceipt|ConvertTo-Json -Depth 9)+[Environment]::NewLine)}
 [pscustomobject]@{success=$sourcePassed;failure=$sourceFailure;serverCleaned=$sourceCleaned;run=$Run}|ConvertTo-Json
}
if(-not$sourcePassed){throw 'Bounded source level-up authority rejected; evidence preserved'}
