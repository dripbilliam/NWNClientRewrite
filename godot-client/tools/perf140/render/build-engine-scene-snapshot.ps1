[CmdletBinding()]
param([ValidatePattern('^[a-z0-9-]+$')][string]$Stage='engine-scene-snapshot-v1',[ValidateRange(1,16)][int]$Jobs=8,[switch]$DryRun)
$ErrorActionPreference='Stop'
$snapshotProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$snapshotDirectory=Join-Path $snapshotProject ('.cache/native-140fps/render-agent/'+$Stage)
$snapshotManifestFile=Join-Path $snapshotDirectory 'manifest.json'
$snapshotManifest=Get-Content -LiteralPath $snapshotManifestFile -Raw|ConvertFrom-Json
function Assert-SnapshotInputs {
 foreach($pin in $snapshotManifest.modulePins){if((Get-FileHash -LiteralPath (Join-Path $snapshotManifest.moduleDirectory $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256){throw ('Private module source drift: '+$pin.relative)}}
 foreach($module in $snapshotManifest.inheritedModules){foreach($pin in $module.pins){if((Get-FileHash -LiteralPath (Join-Path $module.directory $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256){throw ('Inherited private module drift: '+$pin.relative)}}}
 if ($snapshotManifest.nodePatch -and (Get-FileHash -LiteralPath (Join-Path $snapshotManifest.source $snapshotManifest.nodePatch.relative)).Hash.ToLowerInvariant() -ne $snapshotManifest.nodePatch.afterSha256) {throw 'Guarded Node accessor source drift'}
 foreach($guard in $snapshotManifest.guards){if((Get-FileHash -LiteralPath $guard.path).Hash.ToLowerInvariant()-ne$guard.sha256){throw ('Shared/retained guard drift: '+$guard.path)}}
}
Assert-SnapshotInputs
$snapshotStarted=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$snapshotBuildText=(& (Join-Path $PSScriptRoot 'build-engine-rd-fork.ps1') -Stage $Stage -SourceState patched -Jobs $Jobs -DryRun:$DryRun|Out-String)
$snapshotBuildResult=$snapshotBuildText|ConvertFrom-Json
$snapshotBuildText
if(-not$DryRun-and($null-eq$snapshotBuildResult.exitCode-or$snapshotBuildResult.exitCode-ne0)){throw 'Private engine build did not return a clean receipt'}
Assert-SnapshotInputs
if(-not$DryRun){
 $snapshotProof=@{success=$true;stage=$snapshotDirectory;started=$snapshotStarted;finished=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();manifestSha256=(Get-FileHash -LiteralPath $snapshotManifestFile).Hash.ToLowerInvariant();moduleSourceUnchanged=$true;retainedPairedEnginesUnchanged=$true;sharedOutputsUnchanged=$true}
 [IO.File]::WriteAllText((Join-Path $snapshotDirectory ('module-build-guards-'+$snapshotStarted+'.json')),($snapshotProof|ConvertTo-Json -Depth 4))
}
