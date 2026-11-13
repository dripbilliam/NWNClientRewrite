[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$tracyStage=Join-Path $PSScriptRoot '.cache/native-tracy/live/manual-cache-a'
& (Join-Path $tracyStage 'source/launch.ps1') -Config (Join-Path $tracyStage 'config.json') -NativeAcceptance (Join-Path $tracyStage 'native-acceptance.json') -Launch
