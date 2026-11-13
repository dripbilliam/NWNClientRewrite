param([string]$Descriptor)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$prepared=Join-Path $workspace 'godot-client/.cache/native-presentation-parity/shared-animation-agent/stock-static-props-v1/verified-fixture.json'
$fixture=Get-Content -LiteralPath $prepared -Raw | ConvertFrom-Json -AsHashtable
$serverHome=[IO.Path]::GetFullPath((Join-Path $workspace 'runtime-logs/local-multiplayer-base-reuse2'))
if(-not $serverHome.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Owned home escaped workspace'}
$serverExe=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$serverSha='98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6'
if((Get-FileHash -LiteralPath $serverExe -Algorithm SHA256).Hash.ToLowerInvariant()-ne$serverSha){throw 'Installed dedicated server differs'}
if(Test-Path -LiteralPath $Descriptor){throw 'Prior descriptor preserved'}
if(Get-NetUDPEndpoint -LocalPort 5122 -ErrorAction SilentlyContinue){throw 'Owned test port5122 is occupied'}
$source=Join-Path $workspace 'godot-client/.cache/native-presentation-parity/shared-animation-agent/stock-static-props-v1/module-fixture/module/BaseReuse2.mod'
$moduleSha='b8802b74139b896fef05e47042786ae3fdbb36e92991f3d8742c7ef28661a6f9'
if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()-ne$moduleSha){throw 'Verified authored module differs'}
$modules=Join-Path $serverHome 'modules';New-Item -ItemType Directory -Path $modules -Force | Out-Null
$target=Join-Path $modules 'BaseReuse2.mod'
if(Test-Path -LiteralPath $target){if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()-ne$moduleSha){throw 'Existing owned module differs'}}else{Copy-Item -LiteralPath $source -Destination $target}
$settings=Join-Path $serverHome 'settings.tml'
if(Test-Path -LiteralPath $settings){throw 'Fresh owned server settings required'}
@'
[server.identity]
name = "Replacement Pipeline Local Check"
public = false

[server.net]
accept-relayed-connections = false

[server.login.player-dm]
enabled = false
'@ | Set-Content -LiteralPath $settings -Encoding utf8
$arguments=@('-userdirectory',('"'+$serverHome+'"'),'-port','5122','-publicserver','0','-servername','"Replacement Pipeline Local Check"','-maxclients','2','-servervault','0','-autosaveinterval','0','-module','"BaseReuse2"')
$oldNat=[Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','Process')
try{
 [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','1','Process')
 $child=Start-Process -FilePath $serverExe -WorkingDirectory (Split-Path $serverExe) -ArgumentList $arguments -WindowStyle Hidden -PassThru
}finally{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH',$oldNat,'Process')}
$deadline=[DateTime]::UtcNow.AddSeconds(15)
while([DateTime]::UtcNow-lt$deadline){
 $endpoint=Get-NetUDPEndpoint -LocalPort 5122 -OwningProcess $child.Id -ErrorAction SilentlyContinue
 if($endpoint){break};Start-Sleep -Milliseconds 200
}
if(-not $endpoint){throw 'Owned server did not bind5122'}
$owner=Get-CimInstance Win32_Process -Filter "ProcessId=$($child.Id)"
if($owner.ExecutablePath-ne$serverExe -or -not $owner.CommandLine.Contains('"'+$serverHome+'"')){throw 'Owned server identity differs'}
$result=@{pid=$child.Id;creationTimeUtc=$owner.CreationDate.ToUniversalTime().ToString('o');creationUtcTicks=$owner.CreationDate.ToUniversalTime().Ticks.ToString();executable=$serverExe;sha256=$serverSha;home=$serverHome;port=5122;module='BaseReuse2';moduleFile=$target;moduleSha256=$moduleSha;udpOwned=$true;publicAllowed=$false;natPunchDisabled=$true;fixtureDescriptor=$prepared}
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Descriptor -Encoding utf8
$result | ConvertTo-Json -Depth 8 -Compress
