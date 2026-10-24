$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixture=Get-Content -LiteralPath (Join-Path $workspace 'backups/animations/creation-experience-nui-server-fixture-v1.json') -Raw | ConvertFrom-Json
if(Get-NetUDPEndpoint -LocalPort $fixture.port -ErrorAction SilentlyContinue){throw 'Fixture UDP port occupied'}
$directory=[IO.Path]::GetFullPath($fixture.directory)
if(-not $directory.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetFileName($directory)).StartsWith('nwn-nui-server-')){throw 'Unexpected fixture profile'}
$executable=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$arguments=@('-userdirectory',('"'+$directory+'"'),'-port',[string]$fixture.port,'-publicserver','0','-servername','"Owned NUI Compatibility Fixture"','-servervault','0','-maxclients','2','-autosaveinterval','0','-module','NUITest')
$previousNat=[Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','Process')
try{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','1','Process');$process=Start-Process -FilePath $executable -WorkingDirectory (Split-Path $executable) -ArgumentList $arguments -WindowStyle Hidden -PassThru}finally{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH',$previousNat,'Process')}
$report=[ordered]@{pid=$process.Id;directory=$directory;port=$fixture.port;module=$fixture.module};$report|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $workspace 'backups/animations/creation-experience-nui-server-process-v1.json') -Encoding utf8;$report|ConvertTo-Json -Compress
