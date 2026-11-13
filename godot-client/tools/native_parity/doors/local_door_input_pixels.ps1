param([Parameter(Mandatory)][ValidatePattern('^local-door-input-pixels-[a-z0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
$doorProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$doorWorkspace=Split-Path -Parent $doorProject
$doorServer=Get-Process -Id 40664 -ErrorAction Stop
$doorBefore=@{id=$doorServer.Id;name=$doorServer.ProcessName;start=$doorServer.StartTime.ToUniversalTime().ToString('o')}
$doorExpectedExe=[IO.Path]::GetFullPath((Join-Path $doorWorkspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$doorExpectedProfile=[IO.Path]::GetFullPath((Join-Path $doorWorkspace 'runtime-logs/local-multiplayer-server'))
$doorOwner=Get-CimInstance Win32_Process -Filter 'ProcessId=40664'
if($doorOwner.ExecutablePath-ne$doorExpectedExe-or-not$doorOwner.CommandLine.Contains('"'+$doorExpectedProfile+'"')-or-not$doorOwner.CommandLine.Contains('"Prelude"')){throw 'Expected original Prelude process/profile differs; preserved'}
if((Get-FileHash -LiteralPath $doorExpectedExe -Algorithm SHA256).Hash-ne'98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){throw 'Original server binary differs; preserved'}
$doorSettingsBefore=(Get-FileHash -LiteralPath (Join-Path $doorExpectedProfile 'settings.tml') -Algorithm SHA256).Hash
$doorEndpoint=Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction Stop
if(-not @($doorEndpoint|Where-Object OwningProcess -eq 40664).Count){throw 'Protected original server does not own UDP5121'}
$doorSecure=Get-Content -LiteralPath (Join-Path $doorWorkspace 'runtime-logs/local-multiplayer-server/native-test-key.dpapi') -Raw|ConvertTo-SecureString
$doorPayload=$null
try{$doorPayload=@{cdKey=[Net.NetworkCredential]::new('',$doorSecure).Password;password=''}|ConvertTo-Json -Compress}finally{$doorSecure.Dispose()}
$doorStart=[Diagnostics.ProcessStartInfo]::new()
$doorStart.FileName='node';$doorStart.WorkingDirectory=$doorWorkspace;$doorStart.UseShellExecute=$false;$doorStart.CreateNoWindow=$true;$doorStart.RedirectStandardInput=$true
$doorStart.ArgumentList.Add((Join-Path $PSScriptRoot 'local_door_input_pixels_host.mjs'));$doorStart.ArgumentList.Add($Run)
$doorChild=[Diagnostics.Process]::Start($doorStart)
try{$doorChild.StandardInput.Write($doorPayload);$doorPayload='';$doorChild.StandardInput.Close();$doorChild.WaitForExit()}finally{$doorPayload=''}
$doorAfter=Get-Process -Id 40664 -ErrorAction Stop
$doorPreserved=$doorAfter.ProcessName-eq$doorBefore.name-and$doorAfter.StartTime.ToUniversalTime().ToString('o')-eq$doorBefore.start
$doorSettingsAfter=(Get-FileHash -LiteralPath (Join-Path $doorExpectedProfile 'settings.tml') -Algorithm SHA256).Hash
$doorWrapperReceipt=@{protectedOriginalServerUnchanged=$doorPreserved;exit=$doorChild.ExitCode;server='127.0.0.1:5121';pid=40664;module='Prelude';settingsUnchanged=$doorSettingsBefore-eq$doorSettingsAfter;settingsSha256=$doorSettingsAfter.ToLowerInvariant();newCredentialFiles=0}
$doorWrapperReceipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $doorProject ('.cache/native-presentation-parity/root/'+$Run+'/wrapper.json')) -Encoding utf8
$doorWrapperReceipt|ConvertTo-Json -Compress
if(-not$doorPreserved-or$doorChild.ExitCode-ne0){exit 1}
