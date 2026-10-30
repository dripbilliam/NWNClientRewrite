param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-prelude-world-v1',[string]$KeyFile='',[string]$ProtectedKeyFile='',[int]$PreserveOriginalPid=0,[switch]$Interactive,[switch]$DenseFixture,[switch]$Profile,[switch]$ColdCache,[ValidateRange(1,8)][int]$TransitionCount=1)
$ErrorActionPreference='Stop'
$nativeProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$nativeWorkspace=Split-Path $nativeProject -Parent
. (Join-Path $PSScriptRoot 'local-test-guard.ps1')
Assert-NativeLocalTestAvailable $nativeProject -PreserveOriginalPid $PreserveOriginalPid
& (Join-Path $PSScriptRoot 'ensure-particle-kernel.ps1')
$nativeInstall=[IO.Path]::GetFullPath((Join-Path $nativeWorkspace '../FullDecomp/NwnRootInstall'))
$nativeServer=[IO.Path]::GetFullPath((Join-Path $nativeInstall 'bin/win32/nwserver.exe'))
$nativeHome=Join-Path $nativeWorkspace $(if($DenseFixture){'runtime-logs/dense-performance-server'}else{'runtime-logs/local-multiplayer-server'})
$nativePort=if($DenseFixture){5123}else{5121}
$nativeModule=if($DenseFixture){'DensePerf'}else{'Prelude'}
if($DenseFixture-and-not$Interactive){throw 'Dense fixture uses the interactive inspection route'}
$nativeOwned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object {$_.ExecutablePath-eq$nativeServer-and$_.CommandLine.Contains('"'+$nativeHome+'"')})
if(-not $nativeOwned.Count){
 if($DenseFixture){& (Join-Path $nativeWorkspace 'scripts/dense-performance-server.ps1') -Action Start}
 else{& (Join-Path $nativeWorkspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module Prelude}
}
$nativeDeadline=[DateTime]::UtcNow.AddSeconds(20)
do{$nativeEndpoint=Get-NetUDPEndpoint -LocalPort $nativePort -ErrorAction SilentlyContinue;if($nativeEndpoint){break};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow-lt$nativeDeadline)
if(-not$nativeEndpoint){throw 'Owned local server did not bind'}
$nativeOwned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object {$_.ExecutablePath-eq$nativeServer-and$_.CommandLine.Contains('"'+$nativeHome+'"')})
if(-not @($nativeOwned|Where-Object{$_.ProcessId-in$nativeEndpoint.OwningProcess}).Count){throw 'Local endpoint is not owned; preserved'}
if((Get-FileHash -LiteralPath $nativeServer).Hash-ne'98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){throw 'Unexpected native server'}
$nativeLog=Get-Content -LiteralPath (Join-Path $nativeHome 'logs/nwengineLog.txt') -Raw
if(-not $nativeLog.Contains('Loading Module: '+$nativeModule)){throw 'Owned server module differs'}
if($ProtectedKeyFile){
 if($KeyFile){throw 'Select one private key source'}
 $nativeSecureKey=Get-Content -LiteralPath $ProtectedKeyFile -Raw|ConvertTo-SecureString
 $nativeUnlocked=[Net.NetworkCredential]::new('', $nativeSecureKey).Password
 $nativeKeyContent='YourKey='+$nativeUnlocked
 $nativeUnlocked='';$nativeSecureKey.Dispose()
}else{
 if(-not $KeyFile){$KeyFile=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Neverwinter Nights.0/cdkey.ini'}
 $nativeKeyContent=[IO.File]::ReadAllText($KeyFile)
}
$nativeKeyMatch=[regex]::Match($nativeKeyContent,'(?im)^\s*(?:YourKey|Key1)\s*=\s*([A-Z0-9-]+)\s*$')
if(-not$nativeKeyMatch.Success-or$nativeKeyMatch.Groups[1].Value.Length-ne41){throw 'Existing private local login key unavailable'}
$nativeStart=[Diagnostics.ProcessStartInfo]::new();$nativeStart.FileName='node';$nativeStart.WorkingDirectory=$nativeWorkspace;$nativeStart.UseShellExecute=$false;$nativeStart.CreateNoWindow=$true;$nativeStart.RedirectStandardInput=$true
$nativeStart.ArgumentList.Add((Join-Path $PSScriptRoot 'native-local-world-host.mjs'))
$nativeProcess=[Diagnostics.Process]::Start($nativeStart)
try{
 $nativePrivate=@{install=$nativeInstall;run=$Run;interactive=[bool]$Interactive;denseFixture=[bool]$DenseFixture;profile=[bool]$Profile;coldCache=[bool]$ColdCache;transitionCount=$TransitionCount;credentials=@{cdKey=$nativeKeyMatch.Groups[1].Value;password=''}}|ConvertTo-Json -Compress
 $nativeProcess.StandardInput.Write($nativePrivate);$nativeProcess.StandardInput.Close()
}finally{$nativePrivate='';$nativeKeyContent='';$nativeKeyMatch=$null}
$nativeProcess.WaitForExit()
exit $nativeProcess.ExitCode
