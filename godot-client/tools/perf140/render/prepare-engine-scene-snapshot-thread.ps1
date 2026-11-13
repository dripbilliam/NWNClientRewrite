[CmdletBinding()]
param([ValidatePattern('^[a-z0-9-]+$')][string]$Stage='engine-scene-snapshot-thread-v1')
$ErrorActionPreference='Stop'
$snapshotProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$snapshotBase=Join-Path $snapshotProject '.cache/native-140fps/render-agent'
$snapshotStage=Join-Path $snapshotBase $Stage
if(Test-Path -LiteralPath $snapshotStage){throw 'Existing evidence is preserved'}
$snapshotParent=Join-Path $snapshotBase 'engine-scene-snapshot-v1'
$snapshotParentManifest=Get-Content -LiteralPath (Join-Path $snapshotParent 'manifest.json') -Raw|ConvertFrom-Json
$snapshotParentDescriptor=Join-Path $snapshotParent 'engine-descriptor.json'
$snapshotDescriptor=Get-Content -LiteralPath $snapshotParentDescriptor -Raw|ConvertFrom-Json
$snapshotModuleFile=Join-Path $snapshotProject '.cache/native-140fps/particles-agent/scene-snapshot-thread-preflight-v1/engine-module-sources.json'
$snapshotModuleHash=(Get-FileHash -LiteralPath $snapshotModuleFile).Hash.ToLowerInvariant()
if($snapshotModuleHash-ne'baaec9dd9e0513d0b651bacde1a20d203430e3b725a8d9550290033a9612126f'){throw 'Frozen preflight proposal changed'}
$snapshotModule=Get-Content -LiteralPath $snapshotModuleFile -Raw|ConvertFrom-Json
foreach($pin in $snapshotModule.pins){if((Get-FileHash -LiteralPath (Join-Path $snapshotModule.module $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256){throw ('Module changed: '+$pin.relative)}}
$snapshotPatch=$snapshotModule.nodePatch
if((Get-FileHash -LiteralPath $snapshotPatch.afterFile).Hash.ToLowerInvariant()-ne$snapshotPatch.afterSha256-or(Get-FileHash -LiteralPath $snapshotPatch.patchFile).Hash.ToLowerInvariant()-ne$snapshotPatch.patchSha256){throw 'Guarded Node accessor proposal changed'}
$snapshotSource=[IO.Path]::GetFullPath((Join-Path $snapshotStage 'source'))
$snapshotParentSource=[IO.Path]::GetFullPath($snapshotParentManifest.source)
if(-not$snapshotSource.StartsWith($snapshotStage+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not$snapshotParentSource.StartsWith($snapshotParent+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Copy source/destination escaped explicit private stages'}
if((Get-FileHash -LiteralPath (Join-Path $snapshotParentSource $snapshotPatch.relative)).Hash.ToLowerInvariant()-ne$snapshotPatch.beforeSha256){throw 'Parent Node.h is not the exact expected source'}
foreach($pin in $snapshotParentManifest.modulePins){if((Get-FileHash -LiteralPath (Join-Path $snapshotParentManifest.moduleDirectory $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256){throw 'Parent module changed'} }
$snapshotGuards=@($snapshotParentManifest.guards)+@(@{path=$snapshotDescriptor.engines.candidate.path;sha256=$snapshotDescriptor.engines.candidate.sha256;kind='snapshot-v3-baseline'})
foreach($guard in $snapshotGuards){if((Get-FileHash -LiteralPath $guard.path).Hash.ToLowerInvariant()-ne$guard.sha256){throw 'Retained guard changed'}}
New-Item -ItemType Directory -Path $snapshotSource|Out-Null
Get-ChildItem -LiteralPath $snapshotParentSource -Force|ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $snapshotSource -Recurse -Force}
$snapshotDestination=Join-Path $snapshotSource 'modules/nwn_particle_snapshot'
foreach($pin in $snapshotParentManifest.modulePins){if((Get-FileHash -LiteralPath (Join-Path $snapshotDestination $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256){throw 'Copied parent module differs'}}
foreach($pin in $snapshotModule.pins){Copy-Item -LiteralPath (Join-Path $snapshotModule.module $pin.relative) -Destination (Join-Path $snapshotDestination $pin.relative)}
$snapshotNode=Join-Path $snapshotSource $snapshotPatch.relative
if((Get-FileHash -LiteralPath $snapshotNode).Hash.ToLowerInvariant()-ne$snapshotPatch.beforeSha256){throw 'Copied Node.h differs before guarded replacement'}
Copy-Item -LiteralPath $snapshotNode -Destination (Join-Path $snapshotStage 'node.h.before')
Copy-Item -LiteralPath $snapshotPatch.afterFile -Destination $snapshotNode
Copy-Item -LiteralPath $snapshotPatch.patchFile -Destination (Join-Path $snapshotStage 'node-main-thread-group.patch')
foreach($guard in $snapshotGuards){if((Get-FileHash -LiteralPath $guard.path).Hash.ToLowerInvariant()-ne$guard.sha256){throw 'Retained guard changed during copy'}}
$snapshotReceipt=@{version=1;directory=$snapshotStage;source=$snapshotSource;initialSourceState='patched';originalRepository='https://github.com/godotengine/godot';originalCommit=$snapshotDescriptor.sourceCommit;archiveSha256=$snapshotDescriptor.sourceArchiveSha256;originalTargetSha256=$snapshotParentManifest.originalTargetSha256;changedTargetSha256=$snapshotParentManifest.changedTargetSha256;parentDescriptor=$snapshotParentDescriptor;parentDescriptorSha256=(Get-FileHash -LiteralPath $snapshotParentDescriptor).Hash.ToLowerInvariant();moduleManifest=$snapshotModuleFile;moduleManifestSha256=$snapshotModuleHash;moduleDirectory=$snapshotDestination;modulePins=$snapshotModule.pins;guards=$snapshotGuards;nodePatch=$snapshotPatch;resolvedParentFeatures=$snapshotDescriptor.resolvedFeatures;copyPolicy='Real recursive copies; no hard links or changes to earlier engine source/archives';sharedSourceChanged=$false;sharedEngineChanged=$false;buildStarted=$false;variantDescription='Corrected RD + particle snapshot V3 baseline versus O(1) cached thread-owner preflight and validate-only skip; no light or occlusion changes'}
[IO.File]::WriteAllText((Join-Path $snapshotStage 'manifest.json'),($snapshotReceipt|ConvertTo-Json -Depth 8))
$snapshotReceipt|ConvertTo-Json -Depth 8
