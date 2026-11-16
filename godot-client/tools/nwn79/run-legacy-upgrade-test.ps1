$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$testRoot=[IO.Path]::GetFullPath((Join-Path $client '.cache/nwn79'))
$directory=[IO.Path]::GetFullPath((Join-Path $testRoot ('settings-import-'+[guid]::NewGuid().ToString('N'))))
$autoDirectory=$directory+'-auto'
foreach($path in @($directory,$autoDirectory)){
 if(-not $path.StartsWith($testRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Synthetic settings directory escaped private cache'}
}
$godot=[IO.Path]::GetFullPath((Join-Path $client '.tools/Godot_v4.7.2-stable_win64_console.exe'))
$legacy=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('v10obsolete-ciphertext'))
$id=[guid]::NewGuid().ToString()
$secondId=[guid]::NewGuid().ToString()
$settings=@{
 version=2;modsDirectory='';disabledMods=@('local','12345');activeProfileId=$id
 protectedCdKey=$legacy
 loginProfiles=@(
  @{id=$id;label='Existing';playerName='Druid';protectedCdKey=$legacy},
  @{id=$secondId;label='Alternate';playerName='Wizard';protectedCdKey=$legacy}
 )
 serverPreferences=@{lastServer='Arelith';favorites=@('Prelude','Arelith')}
 graphics=@{resolution='3440x1440';quality=3}
 ui=@{scale=1.25;layout='classic'}
 audio=@{music=0.6;effects=0.8}
}|ConvertTo-Json -Compress -Depth 10
try{
 foreach($path in @($directory,$autoDirectory)){
  New-Item -ItemType Directory -Path $path -Force|Out-Null
  [IO.File]::WriteAllText((Join-Path $path 'client-settings.json'),$settings)
  [IO.File]::WriteAllText((Join-Path $path 'Local State'),'{"obsolete":true}')
 }
 Push-Location $client
 try{
  & $godot --headless --path . --script 'res://tests/nwn79_legacy_upgrade_test.gd' -- ('--directory='+$directory)
  if($LASTEXITCODE -ne 0){throw 'Godot interrupted settings import check failed'}
  & $godot --headless --path . --script 'res://tests/nwn79_login_profile_auto_upgrade_test.gd' -- ('--directory='+$autoDirectory)
  if($LASTEXITCODE -ne 0){throw 'Godot profile import/re-entry check failed'}
 }finally{Pop-Location}
}finally{
 foreach($path in @($directory,$autoDirectory)){
  $resolved=[IO.Path]::GetFullPath($path)
  if($resolved.StartsWith($testRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)){Remove-Item -LiteralPath $resolved -Recurse -Force}
 }
}
