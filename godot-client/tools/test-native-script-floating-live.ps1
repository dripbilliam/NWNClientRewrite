[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^native-script-floating-[a-z0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
$floatingProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$floatingWorkspace=Split-Path $floatingProject
$floatingJoin=Join-Path $floatingProject 'join-native.ps1'
if(-not(Get-Command $floatingJoin).Parameters.ContainsKey('ScriptFloatingCheck')-or-not(Test-Path -LiteralPath (Join-Path $floatingProject 'tests/native_script_floating_world.gd'))){throw 'Reviewed ScriptFloating dispatch hooks are not installed'}
if(Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue){throw '5129 is occupied; existing process preserved'}
$floatingDirectory=Join-Path $floatingProject ('.cache/script-floating-authority/'+$Run)
if((Test-Path -LiteralPath $floatingDirectory)-or(Test-Path -LiteralPath (Join-Path $floatingProject ('reports/'+$Run+'.json')))){throw 'Existing ScriptFloating evidence retained'}
$floatingHome=Join-Path $floatingDirectory 'server'
$floatingAlt=Join-Path $floatingWorkspace 'runtime-logs/local-multiplayer-server/native-barter-alt.dpapi'
$floatingMain=Join-Path $floatingWorkspace 'runtime-logs/local-multiplayer-server/native-barter-main.dpapi'
$floatingProtected=@(Get-CimInstance Win32_Process|Where-Object{$_.Name-in@('nwserver.exe','Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe','node.exe','electron.exe')}|Select-Object ProcessId,Name,ExecutablePath,CreationDate)
if(-not($floatingProtected|Where-Object{$_.ProcessId-eq7568-and$_.Name-eq'nwserver.exe'})-or-not($floatingProtected|Where-Object ProcessId -eq 25060)){throw 'Protected original server/editor identity changed'}
$floatingProfiles=@($floatingAlt,$floatingMain)|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash}}
$floatingOutputs=@('.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json')
$floatingBefore=@($floatingOutputs|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $floatingProject $_)).Hash}})
. (Join-Path $PSScriptRoot 'native-level-up-no-build.ps1')
Assert-NativeLevelUpNoBuild -Root $floatingProject
$floatingLease=[IO.File]::Open((Join-Path $floatingProject '.cache/creation-full-alt-key.lease'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$floatingServer=$null;$floatingFailure=$null;$floatingAccepted=$false;$floatingResult=$null
try{
 & node (Join-Path $floatingProject 'tools/native-script-floating-server.mjs') $floatingHome
 if($LASTEXITCODE-ne0){throw 'Owned ScriptFloating profile preparation failed'}
 $floatingFixture=Get-Content -LiteralPath (Join-Path $floatingHome 'fixture.json') -Raw|ConvertFrom-Json
 $floatingStart=[Diagnostics.ProcessStartInfo]::new();$floatingStart.FileName=$floatingFixture.serverPath;$floatingStart.WorkingDirectory=Split-Path $floatingFixture.serverPath;$floatingStart.UseShellExecute=$false;$floatingStart.CreateNoWindow=$true;$floatingStart.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$floatingStart.Environment['NWN_DO_NOT_NAT_PUNCH']='1'
 foreach($argument in @('-userdirectory',$floatingHome,'-port','5129','-publicserver','0','-servername','OwnedNativeScriptFloating','-maxclients','1','-servervault','0','-autosaveinterval','0','-module','ScriptFloat1')){$floatingStart.ArgumentList.Add($argument)}
 $floatingStarted=[DateTime]::UtcNow;$floatingServer=[Diagnostics.Process]::Start($floatingStart);$floatingDeadline=[DateTime]::UtcNow.AddSeconds(25)
 do{$floatingEndpoint=Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue;if($floatingEndpoint.OwningProcess-contains$floatingServer.Id){break};if($floatingServer.HasExited){throw 'Owned ScriptFloating server exited before readiness'};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow-lt$floatingDeadline)
 if($floatingEndpoint.OwningProcess-notcontains$floatingServer.Id){throw 'Owned ScriptFloating server did not bind5129'}
 $floatingReady=$false
 for($attempt=0;$attempt-lt8;$attempt++){& node (Join-Path $floatingProject 'tools/query-native-script-floating-server.mjs') ('--output='+(Join-Path $floatingDirectory ('ready-'+$attempt+'.json')));if($LASTEXITCODE-eq0){$floatingReady=$true;break};Start-Sleep -Milliseconds 250}
 if(-not$floatingReady-or(Get-Item -LiteralPath (Join-Path $floatingHome 'logs/nwengineLog.txt')).LastWriteTimeUtc-lt$floatingStarted){throw 'Fresh owned legal/local-vault ScriptFloat1 was not confirmed'}
 & $floatingJoin -ScriptFloatingCheck -ScriptFloatingDirectory $floatingHome -Headless -EngineRuntime editor -LocalOnly -Run $Run -ProtectedKeyFile $floatingAlt
 $floatingResult=Get-Content -LiteralPath (Join-Path $floatingProject ('reports/'+$Run+'.json')) -Raw|ConvertFrom-Json
 $floatingAccepted=$floatingResult.success-and$floatingResult.scriptFloatingProof.success-and$floatingResult.sourceUnchanged-and$floatingResult.unpinnedProtocolModules.Count-eq0-and$floatingResult.publicConnections-eq0-and$floatingResult.nativeExit-eq0
 if(-not$floatingAccepted){throw 'Original ScriptFloating received/native proof rejected; no retry'}
}catch{$floatingFailure=$_.Exception.Message}
finally{
 $floatingCleaned=$null-eq$floatingServer
 if($floatingServer){if(-not$floatingServer.HasExited){$current=Get-CimInstance Win32_Process -Filter ('ProcessId='+$floatingServer.Id);if($current.ExecutablePath-eq$floatingFixture.serverPath-and$current.CommandLine.Contains($floatingHome)){$floatingServer.Kill();$floatingServer.WaitForExit(10000)|Out-Null}else{$floatingFailure='Owned ScriptFloating server identity changed; unrelated process preserved'}};$floatingCleaned=-not(Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue|Where-Object OwningProcess -eq $floatingServer.Id)}
 $floatingLease.Dispose()
 $floatingOutputGuards=@($floatingBefore|ForEach-Object{@{path=$_.path;unchanged=(Get-FileHash -LiteralPath (Join-Path $floatingProject $_.path)).Hash-eq$_.sha256}})
 $floatingProfileGuards=@($floatingProfiles|ForEach-Object{@{path=$_.path;unchanged=(Get-FileHash -LiteralPath $_.path).Hash-eq$_.sha256}})
 $floatingProcessGuards=@($floatingProtected|ForEach-Object{$now=Get-CimInstance Win32_Process -Filter ('ProcessId='+$_.ProcessId);@{processId=$_.ProcessId;unchanged=$now-and$now.Name-eq$_.Name-and$now.ExecutablePath-eq$_.ExecutablePath-and$now.CreationDate-eq$_.CreationDate}})
 $floatingPassed=$floatingAccepted-and$floatingCleaned-and-not$floatingFailure-and-not($floatingOutputGuards.unchanged-contains$false)-and-not($floatingProfileGuards.unchanged-contains$false)-and-not($floatingProcessGuards.unchanged-contains$false)
 $floatingReceipt=[ordered]@{success=$floatingPassed;run=$Run;failure=$floatingFailure;serverCleaned=$floatingCleaned;serverProcessId=if($floatingServer){$floatingServer.Id}else{$null};endpoint='127.0.0.1:5129';nativeOutputs=$floatingOutputGuards;encryptedProfiles=$floatingProfileGuards;protectedProcesses=$floatingProcessGuards;privateKeysLogged=$false;publicConnections=0;nativeBuilds=0;scope='One original-server ScriptFloating93/94 stimulus and received native UI proof. Existing server/editor/other processes preserved; installed Wizard unchanged. No GPU/pixels, public world, recreation or implicit retry.'}
 if(Test-Path -LiteralPath $floatingDirectory){[IO.File]::WriteAllText((Join-Path $floatingDirectory 'runner.json'),($floatingReceipt|ConvertTo-Json -Depth 9)+[Environment]::NewLine)}
 [pscustomobject]@{success=$floatingPassed;failure=$floatingFailure;serverCleaned=$floatingCleaned;run=$Run}|ConvertTo-Json
}
if(-not$floatingPassed){throw 'Bounded ScriptFloating authority rejected; evidence preserved'}
