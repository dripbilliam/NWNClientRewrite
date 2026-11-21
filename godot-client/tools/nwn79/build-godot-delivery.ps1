param(
 [Parameter(Mandatory=$true)][string]$Destination,
 [string]$Install='',
 [switch]$Zip,
 [switch]$IncludeVaultCreationProbe
)
$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path -Path $client -Parent
$destination=[IO.Path]::GetFullPath($Destination)
if($destination -eq $workspace -or $destination -eq $client -or -not$destination.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Delivery staging must be a new directory inside this workspace'}
if(Test-Path -LiteralPath $destination){throw 'Delivery staging destination already exists'}
& (Join-Path $PSScriptRoot 'check-godot-only.ps1') | Out-Null
if($Install){& (Join-Path $client 'join-godot.ps1') -Install $Install -CheckOnly | Out-Null}
else{& (Join-Path $client 'join-godot.ps1') -CheckOnly | Out-Null}
$files=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
function Add-Source([string]$absolute){
 if(-not(Test-Path -LiteralPath $absolute -PathType Leaf)){throw ('Delivery source is missing: '+$absolute)}
 $resolved=[IO.Path]::GetFullPath($absolute)
 if(-not$resolved.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw ('Delivery source escaped workspace: '+$resolved)}
 [void]$files.Add($resolved)
}
foreach($name in @('project.godot','runtime-lock.json','join-godot.ps1')){Add-Source (Join-Path $client $name)}
foreach($file in Get-ChildItem -LiteralPath $client -File){if($file.Name -match '\.gd(?:\.uid)?$' -and $file.Name -notin @('main.gd','main.gd.uid')){Add-Source $file.FullName}}
foreach($folder in @('systems','data','tools')){
 foreach($file in Get-ChildItem -LiteralPath (Join-Path $client $folder) -Recurse -File){
  $insideFolder=$file.FullName.Substring((Join-Path $client $folder).Length+1)
  if($insideFolder.Replace([char]92,[char]47) -match '(^|/)tests/'){continue}
  if($folder -eq 'data' -and $file.Extension -eq '.json') {Add-Source $file.FullName}
  elseif($folder -eq 'systems' -and ($file.Name -match '\.(?:gd|json)(?:\.uid)?$')) {Add-Source $file.FullName}
  elseif($folder -eq 'tools' -and ($file.Name -match '\.gd(?:\.uid)?$')) {Add-Source $file.FullName}
 }
}
if($IncludeVaultCreationProbe){Add-Source (Join-Path $client 'tests/native_creation_source_live_probe.gd')}
foreach($name in @('native/particle_kernel.gdextension','native/resource_index.gdextension','native/window_modes.c','tools/setup.ps1','tools/native-runtime-selection.ps1','tools/build-window-modes.ps1','tools/nwn79/check-godot-only.ps1','tools/nwn79/build-windows-profile.ps1','tools/nwn79/verify-godot-delivery.ps1','tools/nwn79/build-godot-delivery.ps1','.godot/extension_list.cfg','.tools/Godot_v4.7.2-stable_win64.exe','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll','.cache/nwn79/windows-profile.exe','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json')){Add-Source (Join-Path $client $name)}
foreach($name in @('tooling/native/content-reader/nwn-content-reader.exe','tooling/native/content-reader/zstd-LICENSE.txt','tooling/native/nwn-network-crypto.exe','tooling/native/libhydrogen-LICENSE.txt','scripts/build-content-reader.ps1','scripts/build-network-crypto.ps1')){Add-Source (Join-Path $workspace $name)}
foreach($name in @('clock_source.gdextension','nwn-clock-source.dll')){
 $optional=Join-Path $client ('.cache/native-clock-source-v1/'+$name)
 if(Test-Path -LiteralPath $optional){Add-Source $optional}
}
$sourceHashes=@{}
foreach($source in $files){$sourceHashes[$source]=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$manifestFiles=@()
foreach($source in ($files | Sort-Object)){
 $relative=$source.Substring($workspace.Length+1).Replace('\','/')
 $target=Join-Path $destination $relative
 New-Item -ItemType Directory -Path (Split-Path -Path $target -Parent) -Force | Out-Null
 Copy-Item -LiteralPath $source -Destination $target
 $item=Get-Item -LiteralPath $target
 $copiedHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
 if($copiedHash -ne $sourceHashes[$source]){throw ('Delivery source changed during staging: '+$relative)}
 $manifestFiles+=@{path=$relative;size=$item.Length;sha256=$copiedHash}
}
foreach($source in $files){
 if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceHashes[$source]){throw ('Delivery source changed during staging: '+$source)}
}
$manifest=@{format='nwn79-godot-delivery-v1';files=$manifestFiles}
if($IncludeVaultCreationProbe){$manifest.testFixture='server-vault-create-reconnect-v1'}
$manifestPath=Join-Path $destination 'godot-client/godot-delivery-manifest.json'
$manifest|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $manifestPath -Encoding utf8
& (Join-Path $PSScriptRoot 'verify-godot-delivery.ps1') -PackageRoot $destination -Strict
if($Zip){
 $archive=$destination+'.zip'
 if(Test-Path -LiteralPath $archive){throw 'Delivery archive already exists'}
 [IO.Compression.ZipFile]::CreateFromDirectory($destination,$archive,[IO.Compression.CompressionLevel]::Optimal,$false)
 Write-Output ('Godot-only delivery archive: '+$archive)
}
Write-Output ('Godot-only delivery staged: '+$destination)
