param([ValidateSet('Start','Stop','Status')][string]$Action='Status',[switch]$Nui,[switch]$Sync,[string]$NWSyncUrl='',[ValidatePattern('^$|^[a-f0-9]{40}$')][string]$NWSyncHash='')
$ErrorActionPreference='Stop'
$workspace=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$handoffProfile=[IO.Path]::GetFullPath((Join-Path $workspace 'runtime-logs/godot-handoff-server-b'))
$binary=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
if(-not $handoffProfile.StartsWith([IO.Path]::GetFullPath((Join-Path $workspace 'runtime-logs'))+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected handoff profile'}
$owned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object {$_.ExecutablePath -eq $binary -and $_.CommandLine -and $_.CommandLine.Contains('"'+$handoffProfile+'"')})
if($Action -eq 'Stop'){$owned|ForEach-Object{Stop-Process -Id $_.ProcessId};Write-Output 'Stopped only the secondary owned loopback server';return}
if($Action -eq 'Status'){$owned|Select-Object ProcessId,CommandLine|ConvertTo-Json;return}
if($owned.Count -or (Get-NetUDPEndpoint -LocalPort 5122 -ErrorAction SilentlyContinue)){throw 'Secondary handoff server/port already running; preserved'}
if((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash -ne '98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){throw 'Unverified installed server'}
$fixtureName=if($Sync){'nui-handoff-server-fixtures-v4.json'}elseif($Nui){'nui-handoff-server-fixtures-v3.json'}else{'handoff-server-fixtures-v1.json'}
$fixture=Get-Content (Join-Path $workspace ('godot-client/reports/'+$fixtureName)) -Raw|ConvertFrom-Json
$row=$fixture.servers|Where-Object label -eq 'B'
if($row.profile -ne $handoffProfile -or $row.port -ne 5122 -or (Get-FileHash -LiteralPath (Join-Path $handoffProfile ('modules/'+$row.module+'.mod')) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $row.sha256){throw 'Unverified authored handoff module'}
$settings=Join-Path $handoffProfile 'settings.tml'
if(-not (Test-Path -LiteralPath $settings)){
@'
[server.identity]
name = "Godot Owned Handoff B"
public = false

[server.net]
accept-relayed-connections = false

[server.login.player-dm]
enabled = false
'@|Set-Content -LiteralPath $settings -Encoding utf8
}
$arguments=@('-userdirectory',('"'+$handoffProfile+'"'),'-port','5122','-publicserver','0','-servername','"Godot Owned Handoff B"','-maxclients','2','-servervault','0','-autosaveinterval','0','-module',$row.module)
if($NWSyncUrl -or $NWSyncHash){$repository=[uri]$NWSyncUrl;if($repository.Scheme -ne 'http' -or $repository.Host -ne '127.0.0.1' -or $repository.UserInfo -or $repository.Query -or $repository.Fragment -or -not $NWSyncHash){throw 'Owned NWSync fixture must be loopback HTTP with an explicit manifest hash'};$arguments+=@('-nwsyncurl',$repository.AbsoluteUri,'-nwsynchash',$NWSyncHash,'-reloadwhenempty','0')}
$previous=[Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','Process')
try{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','1','Process');$process=Start-Process -FilePath $binary -WorkingDirectory (Split-Path $binary) -ArgumentList $arguments -WindowStyle Hidden -PassThru}finally{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH',$previous,'Process')}
Write-Output "Started owned handoff B PID $($process.Id) on UDP5122; publicserver0"
