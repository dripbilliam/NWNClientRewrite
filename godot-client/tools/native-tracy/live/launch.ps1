param([Parameter(Mandatory=$true)][string]$Config,[switch]$Launch,[string]$NativeAcceptance)
$ErrorActionPreference='Stop'
if($Launch){throw 'The legacy Electron Tracy launch path is retired. No process was started.'}
$tracyConfig=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
Write-Output 'SOURCE PLAN ONLY: no process started. Historical materialization and native/capture/lifetime acceptance remain archival.'
