param(
 [ValidateSet('Prepare','Status','Start','Stop')][string]$Action='Status',
 [Parameter(Mandatory)][string]$OutputRoot,
 [string]$AllowedSeedSha256=''
)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$client=Join-Path $workspace 'godot-client'
$output=[IO.Path]::GetFullPath($OutputRoot)
if(-not $output.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($client+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Fixture must be workspace scratch outside godot-client'}
$parent=(Resolve-Path -LiteralPath (Split-Path $output -Parent)).Path
if(-not $parent.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Fixture parent is outside the workspace or is a reparse point'}
$profile=Join-Path $output 'profile'
$vault=Join-Path $profile 'servervault'
$module=Join-Path $profile 'nwm/Prelude.nwm'
$manifest=Join-Path $output 'fixture.json'
$binary=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$binaryHash='98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6'
$moduleHash='3daae6b779197cd71a202d87a06bd9c5b2362d3957067490562ea32740d5adb8'
if($Action -eq 'Prepare'){
 if(Test-Path -LiteralPath $output){throw 'Fixture output must be fresh'}
 $source=Get-Content -LiteralPath (Join-Path $client 'reports/vault-handoff-fixtures-v6.json') -Raw|ConvertFrom-Json
 $sourceModule=Join-Path ([IO.Path]::GetFullPath([string]$source.control.profile)) 'nwm/Prelude.nwm'
 if($source.control.module -ne 'Prelude' -or $source.control.sha256 -ne $moduleHash -or (Get-FileHash -LiteralPath $sourceModule -Algorithm SHA256).Hash.ToLowerInvariant() -ne $moduleHash){throw 'Owned Prelude fixture module is unavailable or changed'}
 if((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant() -ne $binaryHash){throw 'Installed native server changed'}
 New-Item -ItemType Directory -Path (Split-Path $module -Parent),$vault -Force|Out-Null
 Copy-Item -LiteralPath $sourceModule -Destination $module
 if((Get-FileHash -LiteralPath $module -Algorithm SHA256).Hash.ToLowerInvariant() -ne $moduleHash){throw 'Copied Prelude fixture module changed'}
 [ordered]@{format='nwn79-empty-server-vault-v1';root=$output;profile=$profile;vault=$vault;module=$module;moduleSha256=$moduleHash;serverBinary=$binary;serverSha256=$binaryHash;port=5121;servervault=1;initialBicCount=0}|ConvertTo-Json -Depth 3|Set-Content -LiteralPath $manifest -Encoding utf8
 Write-Output ('Prepared empty owned server vault: '+$manifest)
 return
}
if(-not(Test-Path -LiteralPath $manifest -PathType Leaf)){throw 'Owned server-vault fixture is not prepared'}
$definition=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
if($definition.format -ne 'nwn79-empty-server-vault-v1' -or $definition.root -ne $output -or $definition.profile -ne $profile -or $definition.vault -ne $vault -or $definition.module -ne $module -or $definition.port -ne 5121 -or $definition.servervault -ne 1){throw 'Owned server-vault fixture metadata changed'}
if(-not(Test-Path -LiteralPath $vault -PathType Container) -or (Get-Item -LiteralPath $vault).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Owned server vault is unavailable or redirected'}
if((Get-FileHash -LiteralPath $module -Algorithm SHA256).Hash.ToLowerInvariant() -ne $moduleHash -or (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant() -ne $binaryHash){throw 'Owned server or module changed'}
$owned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'"|Where-Object {$_.ExecutablePath -eq $binary -and $_.CommandLine -and $_.CommandLine.Contains('"'+$profile+'"') -and $_.CommandLine.Contains('-servervault 1') -and $_.CommandLine.Contains('-module "Prelude"') -and $_.CommandLine.Contains('-port 5121')})
$bics=@(Get-ChildItem -LiteralPath $vault -Recurse -File -Filter '*.bic' -ErrorAction Stop)
if($Action -eq 'Status'){
 [ordered]@{format='nwn79-empty-server-vault-status-v1';port=5121;servervault=1;ownedPids=@($owned|ForEach-Object ProcessId);bicCount=$bics.Count;bicSha256=@($bics|ForEach-Object {(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()})}|ConvertTo-Json -Compress
 return
}
if($Action -eq 'Stop'){
 foreach($process in $owned){Stop-Process -Id $process.ProcessId}
 Write-Output ('Stopped '+$owned.Count+' exact owned ServerVault ON process(es)')
 return
}
if($owned.Count -ne 0 -or @(Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue).Count -ne 0){throw 'Owned server or UDP 5121 is already occupied'}
if($AllowedSeedSha256){
 if($AllowedSeedSha256 -notmatch '^[0-9a-f]{64}$' -or $bics.Count -ne 1 -or
  (Get-FileHash -LiteralPath $bics[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $AllowedSeedSha256){throw 'Seeded protocol check requires exactly one verified BIC'}
}elseif($bics.Count -ne 0){throw 'Creation acceptance requires an initially empty server vault'}
$arguments=@('-userdirectory',('"'+$profile+'"'),'-port','5121','-publicserver','0','-servername','"Owned Vault Creation"','-maxclients','2','-servervault','1','-autosaveinterval','0','-module','"Prelude"')
$previous=[Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','Process')
try{
 [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','1','Process')
 $process=Start-Process -FilePath $binary -WorkingDirectory (Split-Path $binary) -ArgumentList $arguments -WindowStyle Hidden -PassThru
}finally{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH',$previous,'Process')}
Write-Output ('Started exact owned empty ServerVault ON Prelude PID '+$process.Id+' UDP 5121')
