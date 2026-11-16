param([switch]$ExpectUnlock)
$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$testRoot=[IO.Path]::GetFullPath((Join-Path $client '.cache/nwn79'))
$destination=[IO.Path]::GetFullPath((Join-Path $testRoot ('saved-key-copy-'+[guid]::NewGuid().ToString('N'))))
if(-not $destination.StartsWith($testRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Disposable settings copy escaped private cache'}
$source=Join-Path $env:APPDATA 'nwn-model-viewer-research/client-settings.json'
if(-not(Test-Path -LiteralPath $source)){throw 'Current settings file is unavailable'}
$before=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$settings=Get-Content -LiteralPath $source -Raw|ConvertFrom-Json -AsHashtable
if($settings.version -ne 3){throw 'Current settings copy requires version 3'}
$godot=[IO.Path]::GetFullPath((Join-Path $client '.tools/Godot_v4.7.2-stable_win64_console.exe'))
$passed=$false
try{
 New-Item -ItemType Directory -Path $destination -Force|Out-Null
 Copy-Item -LiteralPath $source -Destination (Join-Path $destination 'client-settings.json')
 Push-Location $client
 try{
  $arguments=@('--headless','--path','.','--script','res://tests/nwn79_saved_key_copy_test.gd','--',('--directory='+$destination))
  if($ExpectUnlock){$arguments+='--expect-unlock'}
  & $godot @arguments
  if($LASTEXITCODE -ne 0){throw 'Disposable saved-key check failed'}
  $passed=$true
 }finally{Pop-Location}
}finally{
 if($destination.StartsWith($testRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $destination)){Remove-Item -LiteralPath $destination -Recurse -Force}
 if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $before){throw 'Live settings changed during disposable saved-key check'}
}
if($passed){Write-Output ('NWN79 saved-key copy identity check passed; Windows identity='+[Security.Principal.WindowsIdentity]::GetCurrent().Name+'; expected unlock='+[bool]$ExpectUnlock+'; live source unchanged=true')}
