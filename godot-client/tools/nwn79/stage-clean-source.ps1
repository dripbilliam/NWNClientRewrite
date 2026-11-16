param([Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path -Path $client -Parent
$destination=[IO.Path]::GetFullPath($Destination)
if(-not$destination.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $destination.StartsWith($client+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
 throw 'Clean source staging must be a new directory in the workspace, outside godot-client'
}
if(Test-Path -LiteralPath $destination){throw 'Clean source staging destination already exists'}

function Copy-Source([string]$source,[string]$relative){
 if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw ('Clean source input is missing: '+$source)}
 $target=Join-Path $destination $relative
 New-Item -ItemType Directory -Path (Split-Path -Path $target -Parent) -Force | Out-Null
 Copy-Item -LiteralPath $source -Destination $target
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach($name in @('project.godot','runtime-lock.json','main.tscn','join-godot.ps1')){Copy-Source (Join-Path $client $name) ('godot-client/'+$name)}
foreach($file in Get-ChildItem -LiteralPath $client -File){
 if($file.Name -match '\.gd(?:\.uid)?$'){Copy-Source $file.FullName ('godot-client/'+$file.Name)}
}
foreach($folder in @('systems','data','native','tools')){
 foreach($file in Get-ChildItem -LiteralPath (Join-Path $client $folder) -Recurse -File){
  $allowed=switch($folder){
   'systems' {$file.Name -match '\.(?:gd|json|tscn|tres|gdshader)(?:\.uid)?$'}
   'data' {$file.Extension -eq '.json'}
   'native' {$file.Extension -in @('.c','.cpp','.h','.hpp','.inc','.gdextension')}
   'tools' {$file.Extension -in @('.ps1','.gd','.uid','.json','.c','.h','.hpp','.inc')}
  }
  if($allowed){Copy-Source $file.FullName ('godot-client/'+$file.FullName.Substring($client.Length+1).Replace('\','/'))}
 }
}
foreach($name in @('build-content-reader.ps1','build-network-crypto.ps1','native/nwn_content_reader.c','native/nwn_network_crypto.c','native/zstd-LICENSE.txt')){
 Copy-Source (Join-Path $workspace ('scripts/'+$name)) ('scripts/'+$name)
}
foreach($relative in @('references/libhydrogen','references/nwnxee-unified/NWNXLib/External/sqlite3','references/neverwinter.nim/neverwinter/private/zstd/lib')){
 $source=Join-Path $workspace $relative
 if(-not(Test-Path -LiteralPath $source -PathType Container)){throw ('Clean source reference is missing: '+$source)}
 $target=Join-Path $destination $relative
 New-Item -ItemType Directory -Path (Split-Path -Path $target -Parent) -Force | Out-Null
 Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
}
$project=Join-Path $destination 'godot-client'
foreach($name in @('.tools','.godot','.cache')){if(Test-Path -LiteralPath (Join-Path $project $name)){throw ('Clean source unexpectedly includes '+$name)}}
if(@(Get-ChildItem -LiteralPath $destination -Recurse -File | Where-Object {$_.Extension -in @('.exe','.dll','.cjs','.mjs','.js')}).Count){throw 'Clean source unexpectedly includes a runtime binary or Node script'}
$count=@(Get-ChildItem -LiteralPath $destination -Recurse -File).Count
Write-Output ('Godot-only clean source staged: '+$destination+' ('+$count+' source files; no tools/cache/compiled helpers/Node)')
