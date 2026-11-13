[CmdletBinding()]
param([ValidatePattern('^[a-z0-9-]+$')][string]$Stage='engine-font-atlas-v1',[ValidateRange(1,16)][int]$Jobs=8)
$ErrorActionPreference='Stop'
$atlasProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$atlasStage=Join-Path $atlasProject ('.cache/native-140fps/render-agent/'+$Stage)
$atlasManifest=Get-Content -LiteralPath (Join-Path $atlasStage 'manifest.json') -Raw|ConvertFrom-Json
function Assert-FontSource {
 if((Get-FileHash -LiteralPath (Join-Path $atlasManifest.source $atlasManifest.fontPatch.relative)).Hash.ToLowerInvariant()-ne$atlasManifest.fontPatch.afterSha256){throw 'Private font upload source drift'}
 foreach($guard in $atlasManifest.guards){if((Get-FileHash -LiteralPath $guard.path).Hash.ToLowerInvariant()-ne$guard.sha256){throw ('Shared/retained source drift: '+$guard.path)}}
}
Assert-FontSource
& (Join-Path $PSScriptRoot 'build-engine-scene-snapshot.ps1') -Stage $Stage -Jobs $Jobs
Assert-FontSource
