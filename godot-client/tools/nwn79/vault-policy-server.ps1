param(
 [ValidateSet('Status','Start','Stop')][string]$Action='Status',
 [ValidateSet('ServerOnly','LocalAllowed')][string]$Mode='ServerOnly',
 [ValidatePattern('^vault-handoff-fixtures-v[0-9]+\.json$')][string]$Fixture='vault-handoff-fixtures-v6.json'
)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$definition=Get-Content -LiteralPath (Join-Path $workspace ('godot-client/reports/'+$Fixture)) -Raw|ConvertFrom-Json
$root=[IO.Path]::GetFullPath([string]$definition.root)
$temp=[IO.Path]::GetTempPath().TrimEnd('\')
if((Split-Path $root -Parent).TrimEnd('\') -ne $temp -or (Split-Path $root -Leaf) -notmatch '^nwn-godot-vault-handoff-[A-Za-z0-9]+$'){
 throw 'Unrecognized isolated vault-policy fixture root'
}
$base=Get-Content -LiteralPath (Join-Path $workspace 'godot-client/reports/handoff-server-fixtures-v1.json') -Raw|ConvertFrom-Json
if($definition.servers.Count -ne 2 -or $definition.servers[0].label -ne 'A' -or $definition.servers[0].module -ne $base.servers[0].module -or $definition.servers[0].sha256 -ne $base.servers[0].sha256){throw 'Unverified server-vault fixture metadata'}
$binary=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
if((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant() -ne '98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6'){throw 'Unverified installed native server'}
if($Mode -eq 'ServerOnly'){
 $entry=$definition.servers[0];$vaultMode=1
 $profile=[IO.Path]::GetFullPath([string]$entry.profile)
 if($profile -ne (Join-Path $root 'A') -or $entry.port -ne 5121 -or $definition.vault -ne (Join-Path $root 'vault')){throw 'Unverified server-vault profile'}
 $link=Get-Item -LiteralPath (Join-Path $profile 'servervault')
 if($link.LinkType -ne 'Junction' -or [IO.Path]::GetFullPath($link.Target) -ne $definition.vault){throw 'Server-vault link is not the isolated shared vault'}
 $module=Join-Path $profile ('modules/'+$entry.module+'.mod')
}else{
 $entry=$definition.control;$vaultMode=0
 $profile=[IO.Path]::GetFullPath([string]$entry.profile)
 if($profile -ne (Join-Path $root 'LocalPrelude') -or $entry.port -ne 5121 -or $entry.module -ne 'Prelude' -or $entry.sha256 -ne '3daae6b779197cd71a202d87a06bd9c5b2362d3957067490562ea32740d5adb8'){throw 'Unverified local-vault control profile'}
 $vault=Get-Item -LiteralPath (Join-Path $profile 'servervault')
 if($vault.LinkType -or -not $vault.PSIsContainer){throw 'Local-vault control must own a plain isolated vault directory'}
 $module=Join-Path $profile 'nwm/Prelude.nwm'
}
if((Get-FileHash -LiteralPath $module -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256){throw 'Fixture module hash changed'}
$owned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'"|Where-Object {$_.ExecutablePath -eq $binary -and $_.CommandLine -and $_.CommandLine.Contains('"'+$profile+'"') -and $_.CommandLine.Contains('-servervault '+$vaultMode) -and $_.CommandLine.Contains($entry.module)})
if($Action -eq 'Status'){
 [pscustomobject]@{mode=$Mode;profile=$profile;port=$entry.port;servervault=$vaultMode;ownedPids=@($owned|ForEach-Object ProcessId)}|ConvertTo-Json -Compress
 return
}
if($Action -eq 'Stop'){
 foreach($process in $owned){Stop-Process -Id $process.ProcessId}
 Write-Output ('Stopped '+$owned.Count+' exact owned '+$Mode+' server process(es)')
 return
}
if($owned.Count -ne 0 -or @(Get-NetUDPEndpoint -LocalPort $entry.port -ErrorAction SilentlyContinue).Count -ne 0){throw 'Fixture server or UDP port is already occupied; existing process preserved'}
$arguments=@('-userdirectory',('"'+$profile+'"'),'-port',[string]$entry.port,'-publicserver','0','-servername','"Owned Vault Policy"','-maxclients','2','-servervault',[string]$vaultMode,'-autosaveinterval','0','-module',('"'+$entry.module+'"'))
$previous=[Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','Process')
try{
 [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','1','Process')
 $process=Start-Process -FilePath $binary -WorkingDirectory (Split-Path $binary) -ArgumentList $arguments -WindowStyle Hidden -PassThru
}finally{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH',$previous,'Process')}
Write-Output ('Started exact owned '+$Mode+' server PID '+$process.Id+' UDP '+$entry.port+' servervault='+$vaultMode)
