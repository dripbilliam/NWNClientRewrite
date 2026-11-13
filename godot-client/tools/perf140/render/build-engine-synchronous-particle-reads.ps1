[CmdletBinding()]
param(
 [ValidateSet('engine-synchronous-particle-reads-v2')][string]$Stage='engine-synchronous-particle-reads-v2',
 [ValidateRange(1,16)][int]$Jobs=8,
 [switch]$DryRun
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion.Major-lt7){throw 'Use PowerShell 7 for the retained engine build process/ExitCode wrapper.'}
$readProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$readStage=Join-Path $readProject ('.cache/native-140fps/render-agent/'+$Stage)
$readManifestFile=Join-Path $readStage 'manifest.json'
$readManifest=Get-Content -LiteralPath $readManifestFile -Raw|ConvertFrom-Json
function Assert-ReadProducer {
 if((Get-FileHash -LiteralPath $readManifest.moduleManifest).Hash.ToLowerInvariant()-ne$readManifest.moduleManifestSha256){throw 'Compiled-module proof drift'}
 if((Get-FileHash -LiteralPath $readManifest.sourceFreeze.file).Hash.ToLowerInvariant()-ne$readManifest.sourceFreeze.sha256){throw 'Frozen producer source receipt drift'}
 $proof=Get-Content -LiteralPath $readManifest.moduleManifest -Raw|ConvertFrom-Json
 if([IO.Path]::GetFullPath($proof.module)-ne[IO.Path]::GetFullPath($readManifest.moduleDirectory)){throw 'Proof must pin the actual private compiled module'}
 foreach($pin in $proof.pins){if((Get-FileHash -LiteralPath (Join-Path $proof.module $pin.relative)).Hash.ToLowerInvariant()-ne$pin.sha256){throw ('Private synchronous read source drift: '+$pin.relative)}}
 if((Get-FileHash -LiteralPath (Join-Path $readManifest.source $readManifest.fontPatch.relative)).Hash.ToLowerInvariant()-ne$readManifest.fontPatch.afterSha256){throw 'Inherited immutable atlas source drift'}
 if((Get-FileHash -LiteralPath (Join-Path $readManifest.source $readManifest.nodePatch.relative)).Hash.ToLowerInvariant()-ne$readManifest.nodePatch.afterSha256){throw 'Inherited effective-owner source drift'}
 foreach($guard in $readManifest.guards){if((Get-FileHash -LiteralPath $guard.path).Hash.ToLowerInvariant()-ne$guard.sha256){throw ('Retained/shared guard drift: '+$guard.path)}}
}
Assert-ReadProducer
& (Join-Path $PSScriptRoot 'build-engine-scene-snapshot.ps1') -Stage $Stage -Jobs $Jobs -DryRun:$DryRun
Assert-ReadProducer
