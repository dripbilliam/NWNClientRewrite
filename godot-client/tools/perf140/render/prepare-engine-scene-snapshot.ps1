[CmdletBinding()]
param([ValidatePattern('^[a-z0-9-]+$')][string]$Stage='engine-scene-snapshot-v1')
$ErrorActionPreference='Stop'
$snapshotProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$snapshotBase=Join-Path $snapshotProject '.cache/native-140fps/render-agent'
$snapshotStage=Join-Path $snapshotBase $Stage
if(Test-Path -LiteralPath $snapshotStage){throw 'Existing private engine evidence is preserved'}
$snapshotParent=Join-Path $snapshotBase 'engine-rd-ab-v1'
$snapshotParentManifest=Get-Content -LiteralPath (Join-Path $snapshotParent 'manifest.json') -Raw|ConvertFrom-Json
$snapshotDescriptorFile=Join-Path $snapshotParent 'engine-ab-descriptor.json'
$snapshotDescriptor=Get-Content -LiteralPath $snapshotDescriptorFile -Raw|ConvertFrom-Json
$snapshotModuleFile=Join-Path $snapshotProject '.cache/native-140fps/particles-agent/scene-snapshot-v3/engine-module-sources.json'
$snapshotModuleHash=(Get-FileHash -LiteralPath $snapshotModuleFile).Hash.ToLowerInvariant()
if($snapshotModuleHash-ne'bd99f0286fd2d4489c3f533d38554cba80960b3e6844220e8540400baee1ffc1'){throw 'Frozen particle module proposal changed'}
$snapshotModule=Get-Content -LiteralPath $snapshotModuleFile -Raw|ConvertFrom-Json
foreach($pin in $snapshotModule.pins){if((Get-FileHash -LiteralPath (Join-Path $snapshotModule.module $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256){throw ('Module source drift: '+$pin.relative)}}
$snapshotSource=[IO.Path]::GetFullPath((Join-Path $snapshotStage 'source'))
if(-not$snapshotSource.StartsWith($snapshotStage+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Private source escaped intended stage'}
$snapshotParentSource=[IO.Path]::GetFullPath($snapshotParentManifest.source)
if(-not$snapshotParentSource.StartsWith($snapshotParent+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Parent source escaped retained engine stage'}
$snapshotTarget='servers/rendering/rendering_server_default.cpp'
if((Get-FileHash -LiteralPath (Join-Path $snapshotParentSource $snapshotTarget)).Hash.ToLowerInvariant()-ne$snapshotDescriptor.patchedTargetSha256){throw 'Corrected RD parent source changed'}
$snapshotGuards=@()
foreach($kind in @('pristine','patched')){
 $item=$snapshotDescriptor.engines.$kind
 if((Get-FileHash -LiteralPath $item.path).Hash.ToLowerInvariant()-ne$item.sha256){throw ('Retained engine changed: '+$kind)}
 $snapshotGuards+=@{path=$item.path;sha256=$item.sha256;kind=$kind}
}
foreach($relative in @('.tools/Godot_v4.7.2-stable_win64.exe','.tools/windows_release_x86_64.exe','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json')){
 $file=Join-Path $snapshotProject $relative
 $snapshotGuards+=@{path=$file;sha256=(Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant();kind='shared'}
}
New-Item -ItemType Directory -Path $snapshotSource|Out-Null
# Copy-Item makes actual new files, not hard links. Never mutate the retained
# paired engine tree or its object outputs while building this additive module.
Get-ChildItem -LiteralPath $snapshotParentSource -Force|ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $snapshotSource -Recurse -Force}
$snapshotDestination=Join-Path $snapshotSource 'modules/nwn_particle_snapshot'
if(Test-Path -LiteralPath $snapshotDestination){throw 'Parent unexpectedly already contains the new module'}
New-Item -ItemType Directory -Path $snapshotDestination|Out-Null
foreach($pin in $snapshotModule.pins){Copy-Item -LiteralPath (Join-Path $snapshotModule.module $pin.relative) -Destination (Join-Path $snapshotDestination $pin.relative)}
if((Get-FileHash -LiteralPath (Join-Path $snapshotSource $snapshotTarget)).Hash.ToLowerInvariant()-ne$snapshotDescriptor.patchedTargetSha256){throw 'Copied RD source does not match corrected parent'}
foreach($guard in $snapshotGuards){if((Get-FileHash -LiteralPath $guard.path).Hash.ToLowerInvariant()-ne$guard.sha256){throw ('Guard changed during copy: '+$guard.path)}}
$snapshotReceipt=@{version=1;directory=$snapshotStage;source=$snapshotSource;initialSourceState='patched';originalRepository='https://github.com/godotengine/godot';originalCommit=$snapshotDescriptor.sourceCommit;archiveSha256=$snapshotDescriptor.sourceArchiveSha256;originalTargetSha256=$snapshotDescriptor.pristineTargetSha256;changedTargetSha256=$snapshotDescriptor.patchedTargetSha256;parentManifest=(Join-Path $snapshotParent 'manifest.json');parentDescriptor=$snapshotDescriptorFile;parentDescriptorSha256=(Get-FileHash -LiteralPath $snapshotDescriptorFile).Hash.ToLowerInvariant();moduleManifest=$snapshotModuleFile;moduleManifestSha256=$snapshotModuleHash;moduleDirectory=$snapshotDestination;modulePins=$snapshotModule.pins;guards=$snapshotGuards;copyPolicy='Real recursive copies of the corrected engine source/object tree; no hard links and no mutation of parent source or archived binaries';sharedSourceChanged=$false;sharedEngineChanged=$false;buildStarted=$false;onlyAddedSource='modules/nwn_particle_snapshot (7 pinned files) on top of retained corrected RD engine';resolvedParentFeatures=$snapshotDescriptor.resolvedFeatures}
[IO.File]::WriteAllText((Join-Path $snapshotStage 'manifest.json'),($snapshotReceipt|ConvertTo-Json -Depth 8))
$snapshotReceipt|ConvertTo-Json -Depth 8
