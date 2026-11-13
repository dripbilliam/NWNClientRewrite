param([switch]$CheckOnly)
$ErrorActionPreference='Stop'
$ensureKernelProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$ensureKernelEngine=Join-Path $ensureKernelProject '.tools/Godot_v4.7.2-stable_win64_console.exe'
if((Get-FileHash -LiteralPath $ensureKernelEngine -Algorithm SHA256).Hash.ToLowerInvariant()-ne'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643'){throw 'Native resource index requires the pinned Godot executable'}
$ensureKernelManifest=Join-Path $ensureKernelProject '.cache/native-resource-index/build-manifest.json'
$ensureKernelBinary=Join-Path $ensureKernelProject '.cache/native-resource-index/nwn-resource-index.dll'
. (Join-Path $PSScriptRoot 'resource-index-build-inputs.ps1')
$ensureKernelInputs=@(Get-ResourceIndexBuildInputs -Project $ensureKernelProject)
$ensureKernelReady=$false
if((Test-Path -LiteralPath $ensureKernelManifest)-and(Test-Path -LiteralPath $ensureKernelBinary)){
 try{
  $ensureKernelBuild=Get-Content -LiteralPath $ensureKernelManifest -Raw | ConvertFrom-Json -AsHashtable
  $ensureKernelReady=(Get-FileHash -LiteralPath $ensureKernelBinary -Algorithm SHA256).Hash.ToLowerInvariant()-eq$ensureKernelBuild.binarySha256
  foreach($ensureKernelInput in $ensureKernelInputs){
   $ensureKernelPath=Join-Path $ensureKernelProject $ensureKernelInput
   if(-not(Test-Path -LiteralPath $ensureKernelPath)-or(Get-FileHash -LiteralPath $ensureKernelPath -Algorithm SHA256).Hash.ToLowerInvariant()-ne$ensureKernelBuild.sources[$ensureKernelInput]){$ensureKernelReady=$false}
  }
 }catch{$ensureKernelReady=$false}
}
if(-not$ensureKernelReady){if($CheckOnly){throw 'Native resource index cache is not ready; check-only forbids compilation'};& (Join-Path $PSScriptRoot 'build-resource-index.ps1')}
if(-not(Test-Path -LiteralPath $ensureKernelBinary)){throw 'Native resource index is unavailable after build'}
$resourceExtension='res://native/resource_index.gdextension'
$resourceList=Join-Path $ensureKernelProject '.godot/extension_list.cfg'
if($CheckOnly){if(-not(Test-Path -LiteralPath $resourceList)-or$resourceExtension-notin[IO.File]::ReadAllLines($resourceList)){throw 'Resource extension registration is missing'};return}
New-Item -ItemType Directory -Path (Split-Path $resourceList -Parent) -Force | Out-Null
$resourceLines=if(Test-Path -LiteralPath $resourceList){[IO.File]::ReadAllLines($resourceList)}else{@()}
if($resourceExtension-notin$resourceLines){[IO.File]::WriteAllLines($resourceList,@($resourceLines)+@($resourceExtension))}
