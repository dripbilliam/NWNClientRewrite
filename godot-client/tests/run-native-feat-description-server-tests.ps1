param([string]$ProtectedKeyFile='')
$ErrorActionPreference='Stop'
$guiProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$guiWorkspace=[IO.Path]::GetFullPath((Join-Path $guiProject '..'))
$guiInstall=[IO.Path]::GetFullPath((Join-Path $guiWorkspace '../FullDecomp/NwnRootInstall'))
$guiBinary=Join-Path $guiInstall 'bin/win32/nwserver.exe'
if(-not$ProtectedKeyFile){$ProtectedKeyFile=Join-Path $guiWorkspace 'runtime-logs/local-multiplayer-server/native-barter-main.dpapi'}
if((Get-FileHash -LiteralPath $guiBinary -Algorithm SHA256).Hash-ne'98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){throw 'Unexpected existing original server executable'}
if(Get-NetUDPEndpoint -LocalPort 5127 -ErrorAction SilentlyContinue){throw 'Reserved local5127 port is occupied; existing processes preserved'}
if(-not(Test-Path -LiteralPath $ProtectedKeyFile)){throw 'Explicit protected local-test participant key unavailable'}
$guiRun=Join-Path $guiProject ('.cache/feat-description-server-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$guiHome=Join-Path $guiRun 'server'
[IO.Directory]::CreateDirectory($guiHome)|Out-Null
$guiInputs=@('tests/native_feat_description_server_fixture.mjs','tests/native_feat_description_server_probe.mjs','tests/run-native-feat-description-server-tests.ps1','tools/private-login.cjs','../electron/network_game_session.mjs','../electron/installed_network_session.mjs','../src/network_hud_input.js','../src/network_game_messages.js','../src/network_speech.js','../src/network_runtime_messages.js')
$guiHashes=@($guiInputs|ForEach-Object{@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $guiProject $_) -Algorithm SHA256).Hash.ToLowerInvariant()}})
$guiNode=(Get-Command node).Source
function Start-GuiOwned([string]$Executable,[string[]]$Arguments,[string]$WorkingDirectory,[bool]$DisableNat=$false){
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$Executable;$info.WorkingDirectory=$WorkingDirectory;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 if($DisableNat){$info.Environment['NWN_DO_NOT_NAT_PUNCH']='1'}
 foreach($argument in $Arguments){$info.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($info)
 return [pscustomobject]@{process=$process;stdout=$process.StandardOutput.ReadToEndAsync();stderr=$process.StandardError.ReadToEndAsync()}
}
$guiServer=$null;$guiClient=$null;$guiPipe=$null;$guiSecure=$null;$guiBytes=$null;$guiPayload='';$guiPlain='';$guiFailure=$null;$guiPhase='prepare';$guiCleaned=$false;$guiResult=$null
try{
 & $guiNode (Join-Path $PSScriptRoot 'native_feat_description_server_fixture.mjs') ('--directory='+$guiHome) ('--install='+$guiInstall)|Out-Null
 if($LASTEXITCODE-ne0){throw 'Authored feat module preparation failed'}
 $guiFixture=Get-Content -LiteralPath (Join-Path $guiHome 'fixture.json') -Raw|ConvertFrom-Json
 $guiPhase='server-start'
 $guiServer=Start-GuiOwned $guiBinary @('-userdirectory',$guiHome,'-port','5127','-publicserver','0','-servername','OwnedFeatGui4Test','-maxclients','1','-servervault','0','-autosaveinterval','0','-module',$guiFixture.module) (Split-Path $guiBinary) $true
 $guiReadyDeadline=[DateTime]::UtcNow.AddSeconds(20)
 do{
  $guiEndpoint=Get-NetUDPEndpoint -LocalPort 5127 -ErrorAction SilentlyContinue
  if($guiEndpoint-and$guiEndpoint.OwningProcess-contains$guiServer.process.Id){break}
  if($guiServer.process.HasExited){throw 'Owned original server exited before admission'}
  Start-Sleep -Milliseconds 200
 }while([DateTime]::UtcNow-lt$guiReadyDeadline)
 if(-not$guiEndpoint-or$guiEndpoint.OwningProcess-notcontains$guiServer.process.Id){throw 'Owned server did not bind requested test port'}
 $guiPhase='private-participant'
 $guiPipeName='nwn-private-login-'+[Guid]::NewGuid().ToString('N')
 $guiPipe=[IO.Pipes.NamedPipeServerStream]::new($guiPipeName,[IO.Pipes.PipeDirection]::Out,1,[IO.Pipes.PipeTransmissionMode]::Byte,([IO.Pipes.PipeOptions]::Asynchronous-bor[IO.Pipes.PipeOptions]::CurrentUserOnly))
 $guiSecure=Get-Content -LiteralPath $ProtectedKeyFile -Raw|ConvertTo-SecureString
 $guiPlain=[Net.NetworkCredential]::new('',$guiSecure).Password
 $guiPayload=@{cdKey=$guiPlain}|ConvertTo-Json -Compress;$guiPlain='';$guiSecure.Dispose();$guiSecure=$null
 $guiOutput=Join-Path $guiRun 'probe.json'
 $guiClient=Start-GuiOwned $guiNode @((Join-Path $PSScriptRoot 'native_feat_description_server_probe.mjs'),('--directory='+$guiHome),('--install='+$guiInstall),('--private-login-pipe='+$guiPipeName),('--report='+$guiOutput)) $guiWorkspace
 $guiCancellation=[Threading.CancellationTokenSource]::new(15000)
 try{$guiPipe.WaitForConnectionAsync($guiCancellation.Token).GetAwaiter().GetResult()}finally{$guiCancellation.Dispose()}
 $guiBytes=[Text.Encoding]::UTF8.GetBytes($guiPayload);$guiPayload='';$guiPipe.Write($guiBytes,0,$guiBytes.Length);$guiPipe.Dispose();$guiPipe=$null;[Array]::Clear($guiBytes,0,$guiBytes.Length);$guiBytes=$null
 $guiPhase='protocol'
 $guiDeadline=[DateTime]::UtcNow.AddSeconds(65)
 while(-not$guiClient.process.WaitForExit(1000)){if([DateTime]::UtcNow-ge$guiDeadline){$guiClient.process.Kill($true);$guiClient.process.WaitForExit();throw 'Stopped only owned timed-out GUI4 protocol test'}}
 $guiClient.process.Refresh()
 if(-not(Test-Path -LiteralPath $guiOutput)){throw 'Owned GUI4 protocol test produced no result'}
 $guiResult=Get-Content -LiteralPath $guiOutput -Raw|ConvertFrom-Json
 if($guiClient.process.ExitCode-ne0-or-not$guiResult.success){throw 'Owned original-server GUI4 assertion failed'}
 foreach($input in $guiHashes){if((Get-FileHash -LiteralPath (Join-Path $guiProject $input.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw 'Protocol source changed during owned GUI4 test'}}
 $guiPhase='complete'
}catch{$guiFailure=$_.Exception.GetType().FullName}
finally{
 $guiPlain='';$guiPayload='';if($guiBytes){[Array]::Clear($guiBytes,0,$guiBytes.Length)};if($guiSecure){$guiSecure.Dispose()};if($guiPipe){$guiPipe.Dispose()}
 if($guiClient){if(-not$guiClient.process.HasExited){$guiClient.process.Kill($true);$guiClient.process.WaitForExit()};[IO.File]::WriteAllText((Join-Path $guiRun 'client.stdout.log'),$guiClient.stdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $guiRun 'client.stderr.log'),$guiClient.stderr.GetAwaiter().GetResult())}
 if($guiServer){
  if(-not$guiServer.process.HasExited){
   $guiOwned=Get-CimInstance Win32_Process -Filter ('ProcessId = '+$guiServer.process.Id)
   if($guiOwned.ExecutablePath-eq$guiBinary-and$guiOwned.CommandLine.Contains($guiHome)){$guiServer.process.Kill();$guiServer.process.WaitForExit()}else{throw 'Owned server identity changed; unrelated process preserved'}
  }
  [IO.File]::WriteAllText((Join-Path $guiRun 'server.stdout.log'),$guiServer.stdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $guiRun 'server.stderr.log'),$guiServer.stderr.GetAwaiter().GetResult())
  $guiCleaned=-not(Get-NetUDPEndpoint -LocalPort 5127 -ErrorAction SilentlyContinue|Where-Object OwningProcess -eq $guiServer.process.Id)
 }
 $guiReceipt=[ordered]@{success=(-not$guiFailure-and$guiCleaned-and$null-ne$guiResult-and$guiResult.success);testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$guiRun;phase=$guiPhase;failureType=$guiFailure;checks=if($guiResult){$guiResult.checks}else{0};sourceInputs=$guiHashes;serverSha256=(Get-FileHash -LiteralPath $guiBinary -Algorithm SHA256).Hash.ToLowerInvariant();serverProcessId=if($guiServer){$guiServer.process.Id}else{$null};serverCleaned=$guiCleaned;sessionClosed=if($guiResult){$guiResult.sessionClosed}else{$false};privateKeysLogged=$false;publicConnections=0;gpu=$false;nativeBuilds=0;scope='Owned hidden unchanged original server, unique private profile, endpoint127.0.0.1:5127, protected participant input through current-user named pipe. No user process restart, public join, renderer readiness, original pixel or server-specific disguise calculation claim.'}
 [IO.File]::WriteAllText((Join-Path $guiRun 'runner.json'),($guiReceipt|ConvertTo-Json -Depth 6)+[Environment]::NewLine)
 if($guiReceipt.success){[IO.File]::WriteAllText((Join-Path $guiProject 'reports/native-feat-description-server-v1-receipt.json'),($guiReceipt|ConvertTo-Json -Depth 6)+[Environment]::NewLine)}
 [pscustomobject]@{success=$guiReceipt.success;checks=$guiReceipt.checks;phase=$guiPhase;failureType=$guiFailure;directory=$guiRun;serverCleaned=$guiCleaned;sessionClosed=$guiReceipt.sessionClosed}|ConvertTo-Json
}
if(-not$guiReceipt.success){throw 'Owned local GUI4 check failed; finite fixture evidence retained'}
