param([Parameter(Mandatory)][ValidatePattern('^local-peer-lifecycle-pixels-[a-z0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
$peerProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$peerWorkspace=Split-Path -Parent $peerProject
$peerServer=Get-Process -Id 40664 -ErrorAction Stop
$peerBefore=@{id=$peerServer.Id;name=$peerServer.ProcessName;start=$peerServer.StartTime.ToUniversalTime().ToString('o')}
$peerExpectedExe=[IO.Path]::GetFullPath((Join-Path $peerWorkspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$peerExpectedProfile=[IO.Path]::GetFullPath((Join-Path $peerWorkspace 'runtime-logs/local-multiplayer-server'))
$peerOwner=Get-CimInstance Win32_Process -Filter 'ProcessId=40664'
if($peerOwner.ExecutablePath-ne$peerExpectedExe-or-not$peerOwner.CommandLine.Contains('"'+$peerExpectedProfile+'"')-or-not$peerOwner.CommandLine.Contains('"Prelude"')){throw 'Expected original Prelude process/profile differs; preserved'}
if((Get-FileHash -LiteralPath $peerExpectedExe -Algorithm SHA256).Hash-ne'98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){throw 'Original server binary differs; preserved'}
$peerSettingsBefore=(Get-FileHash -LiteralPath (Join-Path $peerExpectedProfile 'settings.tml') -Algorithm SHA256).Hash
$peerEndpoint=Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction Stop
if(-not @($peerEndpoint|Where-Object OwningProcess -eq 40664).Count){throw 'Protected original server does not own UDP5121'}
$peerHolderPaths=@('native-test-key.dpapi','native-barter-main.dpapi')|ForEach-Object {Join-Path $peerExpectedProfile $_};$peerHolderHashes=@($peerHolderPaths|ForEach-Object{(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash});
$peerSecure=Get-Content -LiteralPath (Join-Path $peerWorkspace 'runtime-logs/local-multiplayer-server/native-test-key.dpapi') -Raw|ConvertTo-SecureString
$peerPayload=$null
try{$peerMain=[Net.NetworkCredential]::new('',$peerSecure).Password}finally{$peerSecure.Dispose()};$peerSecondSecure=Get-Content -LiteralPath $peerHolderPaths[1] -Raw|ConvertTo-SecureString;try{$peerPayload=@{main=@{cdKey=$peerMain;password=''};peer=@{cdKey=[Net.NetworkCredential]::new('',$peerSecondSecure).Password;password=''}}|ConvertTo-Json -Compress -Depth 4}finally{$peerMain='';$peerSecondSecure.Dispose()}
$peerStart=[Diagnostics.ProcessStartInfo]::new()
$peerStart.FileName='node';$peerStart.WorkingDirectory=$peerWorkspace;$peerStart.UseShellExecute=$false;$peerStart.CreateNoWindow=$true;$peerStart.RedirectStandardInput=$true
$peerStart.ArgumentList.Add((Join-Path $PSScriptRoot 'local_peer_lifecycle_pixels_host.mjs'));$peerStart.ArgumentList.Add($Run)
$peerChild=[Diagnostics.Process]::Start($peerStart)
try{$peerChild.StandardInput.Write($peerPayload);$peerPayload='';$peerChild.StandardInput.Close();$peerChild.WaitForExit()}finally{$peerPayload=''}
$peerAfter=Get-Process -Id 40664 -ErrorAction Stop
$peerPreserved=$peerAfter.ProcessName-eq$peerBefore.name-and$peerAfter.StartTime.ToUniversalTime().ToString('o')-eq$peerBefore.start
$peerSettingsAfter=(Get-FileHash -LiteralPath (Join-Path $peerExpectedProfile 'settings.tml') -Algorithm SHA256).Hash
$peerHoldersAfter=@($peerHolderPaths|ForEach-Object{(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash});$peerHoldersUnchanged=($peerHolderHashes -join ',')-eq($peerHoldersAfter -join ',');
$peerWrapperReceipt=@{protectedHoldersUnchanged=$peerHoldersUnchanged;protectedHolderSha256=$peerHoldersAfter;protectedOriginalServerUnchanged=$peerPreserved;exit=$peerChild.ExitCode;server='127.0.0.1:5121';pid=40664;module='Prelude';settingsUnchanged=$peerSettingsBefore-eq$peerSettingsAfter;settingsSha256=$peerSettingsAfter.ToLowerInvariant();newCredentialFiles=0}
$peerWrapperReceipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $peerProject ('.cache/native-presentation-parity/root/'+$Run+'/wrapper.json')) -Encoding utf8
$peerWrapperReceipt|ConvertTo-Json -Compress
if(-not$peerPreserved-or-not$peerHoldersUnchanged-or$peerSettingsBefore-ne$peerSettingsAfter-or$peerChild.ExitCode-ne0){exit 1}
