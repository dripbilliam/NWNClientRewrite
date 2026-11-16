param([string]$PlayerName='',[string]$ProtectedKeyFile='',[string]$Server='')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'join-native.ps1') -PlayerName $PlayerName -ProtectedKeyFile $ProtectedKeyFile -Server $Server
exit $LASTEXITCODE
