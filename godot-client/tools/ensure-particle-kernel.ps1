param([switch]$CheckOnly)
$ErrorActionPreference='Stop'
$ensureKernelProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$ensureKernelEngine=Join-Path $ensureKernelProject '.tools/Godot_v4.7.2-stable_win64_console.exe'
if((Get-FileHash -LiteralPath $ensureKernelEngine -Algorithm SHA256).Hash.ToLowerInvariant()-ne'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643'){throw 'Native particle kernel requires the pinned Godot executable'}
$ensureKernelManifest=Join-Path $ensureKernelProject '.cache/native-kernel/build-manifest.json'
$ensureKernelBinary=Join-Path $ensureKernelProject '.cache/native-kernel/nwn-particle-kernel.dll'
$ensureKernelInputs=@('native/particle_kernel.cpp','native/particle_kernel.gdextension','tools/build-particle-kernel.ps1','.tools/extension-api/gdextension_interface.h','.tools/extension-api/extension_api.json')+@(Get-ChildItem -LiteralPath (Join-Path $ensureKernelProject 'native') -File -Recurse | Where-Object { $_.Extension -in @('.hpp','.inc') } | ForEach-Object {$_.FullName.Substring($ensureKernelProject.Length+1).Replace('\','/')})
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
if(-not$ensureKernelReady){if($CheckOnly){throw 'Native particle kernel cache is not ready; check-only forbids compilation'};& (Join-Path $PSScriptRoot 'build-particle-kernel.ps1')}
if(-not(Test-Path -LiteralPath $ensureKernelBinary)){throw 'Native particle kernel is unavailable after build'}
