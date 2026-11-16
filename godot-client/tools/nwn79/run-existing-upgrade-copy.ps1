param([switch]$PriorVersion,[string]$Receipt='')
$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$testRoot=[IO.Path]::GetFullPath((Join-Path $client '.cache/nwn79'))
$destination=[IO.Path]::GetFullPath((Join-Path $testRoot ('existing-upgrade-copy-'+[guid]::NewGuid().ToString('N'))))
if(-not $destination.StartsWith($testRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Existing-user copy escaped the private workspace cache'}
if($Receipt){
 $Receipt=[IO.Path]::GetFullPath($Receipt)
 if(-not $Receipt.StartsWith($testRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $Receipt)){throw 'Receipt must be a new file under the private NWN-79 cache'}
}
$source=Join-Path $env:APPDATA 'nwn-model-viewer-research'
$sourceName=if($PriorVersion){'client-settings.pre-nwn79.json'}else{'client-settings.json'}
$godot=[IO.Path]::GetFullPath((Join-Path $client '.tools/Godot_v4.7.2-stable_win64_console.exe'))
if(-not(Test-Path -LiteralPath (Join-Path $source $sourceName))){throw 'Requested existing client settings file is unavailable'}
$sourceFile=Join-Path $source $sourceName
$sourceHash=(Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
$localStateFile=Join-Path $source 'Local State'
$localStateHash=if(Test-Path -LiteralPath $localStateFile){(Get-FileHash -LiteralPath $localStateFile -Algorithm SHA256).Hash}else{''}
$passed=$false
try{
 New-Item -ItemType Directory -Path $destination -Force|Out-Null
 Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $destination 'client-settings.json')
 if($localStateHash){Copy-Item -LiteralPath $localStateFile -Destination (Join-Path $destination 'Local State')}
 Push-Location $client
 try{
  $arguments=@('--headless','--path','.','--script','res://tests/nwn79_existing_auto_upgrade_copy.gd','--',('--directory='+$destination))
  if($PriorVersion){$arguments+='--expect-prior'}
  & $godot @arguments
  if($LASTEXITCODE -ne 0){throw 'Copied existing-user one-time import check failed'}
  $passed=$true
 }finally{Pop-Location}
}finally{
 $resolved=[IO.Path]::GetFullPath($destination)
 if($resolved.StartsWith($testRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)){Remove-Item -LiteralPath $resolved -Recurse -Force}
 if((Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -ne $sourceHash){throw 'Live source settings changed during copied import check'}
 if($localStateHash -and (Get-FileHash -LiteralPath $localStateFile -Algorithm SHA256).Hash -ne $localStateHash){throw 'Live Chromium state changed during copied import check'}
 if($passed -and $Receipt){
  $metadata=Get-Content -LiteralPath $sourceFile -Raw|ConvertFrom-Json -AsHashtable
  $recordCount=@($metadata.loginProfiles).Count+[int]$metadata.ContainsKey('protectedCdKey')
  [ordered]@{issue='NWN-79';check='copied-existing-user-one-time-import';priorVersion=[bool]$PriorVersion;passed=$true;sourceVersion=$metadata.version;protectedRecords=$recordCount;backupVerified=$true;secondOpenWithoutChromium=$true;liveSettingsUnchanged=$true;liveChromiumStateUnchanged=$true;capturedAtUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Compress|Set-Content -LiteralPath $Receipt -Encoding utf8
 }
}
