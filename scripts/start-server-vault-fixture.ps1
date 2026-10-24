$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixture=Get-Content -LiteralPath (Join-Path $workspace 'backups/animations/server-vault-fixture-v1.json') -Raw | ConvertFrom-Json
if(Get-NetUDPEndpoint -LocalPort $fixture.port -ErrorAction SilentlyContinue){throw 'Fixture UDP port is already occupied'}
$executable=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$arguments=@('-userdirectory',('"'+$fixture.directory+'"'),'-port',[string]$fixture.port,'-publicserver','0','-servername','"Server Vault Compatibility Fixture"','-servervault','1','-maxclients','2','-autosaveinterval','0','-module','Prelude')
$previousNat=[Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','Process')
try{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','1','Process');$process=Start-Process -FilePath $executable -WorkingDirectory (Split-Path $executable) -ArgumentList $arguments -WindowStyle Hidden -PassThru}finally{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH',$previousNat,'Process')}
$report=[ordered]@{pid=$process.Id;directory=$fixture.directory;port=$fixture.port;module=$fixture.module;serverVault=$true}
$report|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $workspace 'backups/animations/server-vault-fixture-process-v1.json') -Encoding utf8
$report|ConvertTo-Json -Compress
