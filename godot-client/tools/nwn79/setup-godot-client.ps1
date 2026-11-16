param(
 [string]$Install='',
 [string]$GodotArchive='',
 [string]$UserDataDirectory='',
 [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
$previousAppData=$env:APPDATA
try{
if($UserDataDirectory){
 $UserDataDirectory=[IO.Path]::GetFullPath($UserDataDirectory)
 if($CheckOnly -and -not(Test-Path -LiteralPath $UserDataDirectory -PathType Container)){throw 'Isolated Godot user-data directory is unavailable'}
 if(-not$CheckOnly){New-Item -ItemType Directory -Path $UserDataDirectory -Force | Out-Null}
 $env:APPDATA=$UserDataDirectory
}
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path -Path $client -Parent
$installed=if($Install){[IO.Path]::GetFullPath($Install)}else{[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall'))}
if(-not(Test-Path -LiteralPath $installed -PathType Container)){throw ('NWN installation is unavailable: '+$installed)}
if($CheckOnly -and $GodotArchive){throw 'CheckOnly does not stage a Godot archive'}
if($CheckOnly){
 & (Join-Path $client 'join-godot.ps1') -Install $installed -CheckOnly
 return
}
& (Join-Path $PSScriptRoot 'check-godot-only.ps1') | Out-Null
if($GodotArchive){
 $source=[IO.Path]::GetFullPath($GodotArchive)
 $lock=Get-Content -LiteralPath (Join-Path $client 'runtime-lock.json') -Raw | ConvertFrom-Json
 if(-not(Test-Path -LiteralPath $source -PathType Leaf) -or (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.sha256){throw 'Offline Godot archive does not match the pinned runtime lock'}
 $tools=Join-Path $client '.tools'
 New-Item -ItemType Directory -Path $tools -Force | Out-Null
 $target=Join-Path $tools $lock.asset
 if($source -ne $target){Copy-Item -LiteralPath $source -Destination $target}
}
& (Join-Path $client 'tools/setup.ps1') | Out-Null
& (Join-Path $client 'tools/build-window-modes.ps1') | Out-Null
# The resource-index check enumerates the generated GDExtension header as an
# input. On a clean tree the first build must create that header before the
# incremental check can inspect its input set.
if(-not(Test-Path -LiteralPath (Join-Path $client '.tools/extension-api/gdextension_interface.h')) -or -not(Test-Path -LiteralPath (Join-Path $client '.tools/extension-api/extension_api.json'))){
 & (Join-Path $client 'tools/build-resource-index.ps1')
}
& (Join-Path $client 'tools/ensure-resource-index.ps1')
& (Join-Path $client 'tools/ensure-particle-kernel.ps1')
& (Join-Path $PSScriptRoot 'build-windows-profile.ps1') | Out-Null
if(-not(Test-Path -LiteralPath (Join-Path $workspace 'tooling/native/content-reader/nwn-content-reader.exe'))){
 & (Join-Path $workspace 'scripts/build-content-reader.ps1') | Out-Null
}
if(-not(Test-Path -LiteralPath (Join-Path $workspace 'tooling/native/nwn-network-crypto.exe'))){
 & (Join-Path $workspace 'scripts/build-network-crypto.ps1') | Out-Null
}
& (Join-Path $client 'join-godot.ps1') -Install $installed -CheckOnly
Write-Output 'Godot-only native client setup PASS'
}finally{$env:APPDATA=$previousAppData}
