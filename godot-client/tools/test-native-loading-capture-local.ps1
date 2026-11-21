param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-loading-capture-local-v1')
$ErrorActionPreference='Stop'
$captureProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$captureWorkspace=Split-Path $captureProject -Parent
$captureInstall=[IO.Path]::GetFullPath((Join-Path $captureWorkspace '../FullDecomp/NwnRootInstall'))
$captureServer=Join-Path $captureInstall 'bin/win32/nwserver.exe'
$captureHome=Join-Path $captureWorkspace 'runtime-logs/local-multiplayer-server'
$captureOwned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'"|Where-Object {$_.ExecutablePath-eq$captureServer-and$_.CommandLine.Contains('"'+$captureHome+'"')})
if(-not$captureOwned.Count){& (Join-Path $captureWorkspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module Prelude}
$captureOwned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'"|Where-Object {$_.ExecutablePath-eq$captureServer-and$_.CommandLine.Contains('"'+$captureHome+'"')})
$captureEndpoint=Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue
if(-not@($captureOwned|Where-Object {$_.ProcessId-in$captureEndpoint.OwningProcess}).Count){throw 'Owned local Prelude endpoint is unavailable; other servers preserved'}
if((Get-FileHash -LiteralPath $captureServer).Hash-ne'98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){throw 'Original server digest differs'}
if(-not(Get-Content (Join-Path $captureHome 'logs/nwengineLog.txt') -Raw).Contains('Loading Module: Prelude')){throw 'Owned local server is not Prelude'}
$captureUser=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Neverwinter Nights.0'
$captureKeyText=[IO.File]::ReadAllText((Join-Path $captureUser 'cdkey.ini'))
$captureKey=[regex]::Match($captureKeyText,'(?im)^\s*(?:YourKey|Key1)\s*=\s*([A-Z0-9-]+)\s*$')
if(-not$captureKey.Success-or$captureKey.Groups[1].Value.Length-ne41){throw 'Private local fixture key unavailable'}
$captureSettings=Join-Path $env:TEMP ('nwn-native-loading-settings-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($captureSettings)|Out-Null
$captureStart=[Diagnostics.ProcessStartInfo]::new();$captureStart.FileName='node';$captureStart.WorkingDirectory=$captureWorkspace;$captureStart.UseShellExecute=$false;$captureStart.CreateNoWindow=$true;$captureStart.RedirectStandardInput=$true
foreach($argument in @((Join-Path $PSScriptRoot 'native-session-host.cjs'),'--local-check','--record-loading','--native-headless','--native-profile','--native-debugger',('--run='+$Run))){$captureStart.ArgumentList.Add($argument)}
$captureProcess=[Diagnostics.Process]::Start($captureStart)
try{$capturePayload=@{settingsDirectory=$captureSettings;userDirectory=$captureUser;settings=@{modsDirectory='';disabledMods=@()};cdKey=$captureKey.Groups[1].Value}|ConvertTo-Json -Compress;$captureProcess.StandardInput.Write($capturePayload);$captureProcess.StandardInput.Close()}
finally{$capturePayload='';$captureKeyText='';$captureKey=$null}
$captureProcess.WaitForExit()
exit $captureProcess.ExitCode
