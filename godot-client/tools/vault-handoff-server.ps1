param([ValidateSet('Start','Stop','Status')][string]$Action='Status',[Parameter(Mandatory=$true)][ValidatePattern('^vault-handoff-fixtures-v[0-9]+\.json$')][string]$Fixture)
$ErrorActionPreference='Stop'
$workspace=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixturePath=Join-Path $workspace ('godot-client/reports/'+$Fixture)
$definition=Get-Content -LiteralPath $fixturePath -Raw|ConvertFrom-Json
$testRoot=[IO.Path]::GetFullPath($definition.root)
if((Split-Path $testRoot -Parent).TrimEnd('\') -ne ([IO.Path]::GetTempPath()).TrimEnd('\') -or (Split-Path $testRoot -Leaf) -notmatch '^nwn-godot-vault-handoff-[A-Za-z0-9]+$' -or $definition.vault -ne (Join-Path $testRoot 'vault') -or $definition.servers.Count -ne 2){throw 'Unrecognized external owned fixture'}
$binary=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
if((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash -ne '98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){throw 'Unverified installed server'}
$base=Get-Content -LiteralPath (Join-Path $workspace 'godot-client/reports/handoff-server-fixtures-v1.json') -Raw|ConvertFrom-Json
$definitions=@()
foreach($index in 0..1){
 $s=$definition.servers[$index];$expected=$base.servers[$index];$vaultProfile=[IO.Path]::GetFullPath($s.profile)
 if($vaultProfile -ne (Join-Path $testRoot $expected.label) -or $s.port -ne $expected.port -or $s.module -ne $expected.module -or $s.sha256 -ne $expected.sha256 -or (Get-FileHash -LiteralPath (Join-Path $vaultProfile ('modules/'+$s.module+'.mod')) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected.sha256){throw 'Unverified authored server profile/module'}
 $link=Get-Item -LiteralPath (Join-Path $vaultProfile 'servervault')
 if($link.LinkType -ne 'Junction' -or [IO.Path]::GetFullPath($link.Target) -ne $definition.vault){throw 'Fixture server vault is not the expected shared external folder'}
 $owned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'"|Where-Object {$_.ExecutablePath -eq $binary -and $_.CommandLine -and $_.CommandLine.Contains('"'+$vaultProfile+'"') -and $_.CommandLine.Contains($s.module)})
 $definitions+=@{server=$s;owned=$owned}
}
if($Action -eq 'Stop'){foreach($d in $definitions){$d.owned|ForEach-Object{Stop-Process -Id $_.ProcessId}};Write-Output 'Stopped only both exact external vault-handoff fixture profiles';return}
if($Action -eq 'Status'){foreach($d in $definitions){$d.owned|Select-Object ProcessId,CommandLine|ConvertTo-Json -Compress};return}
foreach($d in $definitions){if($d.owned.Count -or (Get-NetUDPEndpoint -LocalPort $d.server.port -ErrorAction SilentlyContinue)){throw 'Fixture port occupied; existing server preserved'}}
foreach($d in $definitions){
 $s=$d.server;$arguments=@('-userdirectory',('"'+$s.profile+'"'),'-port',[string]$s.port,'-publicserver','0','-servername','"Owned Native Vault Handoff"','-maxclients','2','-servervault','1','-autosaveinterval','0','-module',$s.module)
 $previous=[Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','Process')
 try{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','1','Process');$process=Start-Process -FilePath $binary -WorkingDirectory (Split-Path $binary) -ArgumentList $arguments -WindowStyle Hidden -PassThru}finally{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH',$previous,'Process')}
 Write-Output "Started owned external server $($s.label) PID $($process.Id) UDP$($s.port), servervault1/publicserver0"
}
