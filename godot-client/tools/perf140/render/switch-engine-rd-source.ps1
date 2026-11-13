[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Stage,
 [Parameter(Mandatory)][ValidateSet('pristine','patched')][string]$SourceState
)
$ErrorActionPreference='Stop'
$renderProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$renderDirectory=Join-Path $renderProject ('.cache/native-140fps/render-agent/'+$Stage)
$renderManifest=Get-Content -LiteralPath (Join-Path $renderDirectory 'manifest.json') -Raw|ConvertFrom-Json
$renderTarget=Join-Path $renderManifest.source 'servers/rendering/rendering_server_default.cpp'
$renderBefore=(Get-FileHash -LiteralPath $renderTarget).Hash.ToLowerInvariant()
if($renderBefore-notin@($renderManifest.originalTargetSha256,$renderManifest.changedTargetSha256)){throw 'Private source has unrelated edits; preserved'}
$renderSaved=Join-Path $renderDirectory ('rendering_server_default.'+$SourceState+'.cpp')
$renderExpected=if($SourceState-eq'pristine'){$renderManifest.originalTargetSha256}else{$renderManifest.changedTargetSha256}
if((Get-FileHash -LiteralPath $renderSaved).Hash.ToLowerInvariant()-ne$renderExpected){throw 'Saved source witness drifted'}
$renderSwitch=Join-Path $renderDirectory ('source-switch-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+'.json')
Copy-Item -LiteralPath $renderSaved -Destination $renderTarget
$renderReceipt=@{sourceState=$SourceState;target=$renderTarget;before=$renderBefore;after=(Get-FileHash -LiteralPath $renderTarget).Hash.ToLowerInvariant();expected=$renderExpected;compilerFlagsChanged=$false;otherSourcesChanged=$false;sharedSourceChanged=$false}
[IO.File]::WriteAllText($renderSwitch,($renderReceipt|ConvertTo-Json))
$renderReceipt|ConvertTo-Json
