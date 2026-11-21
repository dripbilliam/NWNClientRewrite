param([Parameter(Mandatory=$true)][string]$Config,[switch]$Launch,[switch]$Diagnostic,[string]$NativeAcceptance)
$ErrorActionPreference='Stop'
if($Launch){throw 'The legacy Electron transport live launcher is retired. No process was started.'}
$liveConfig=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
Write-Output 'PREPARED ONLY: no process started. Historical native parser/lifetime acceptance and materialized view remain archival.'
