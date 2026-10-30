param([int]$PreserveOriginalPid=0)
$ErrorActionPreference='Stop'
# Direct native original-resource path. Protocol connects only to the owned
# Prelude server. It deliberately leaves the transitional launcher intact.
$nativePlayWorkspace=Split-Path $PSScriptRoot -Parent
$nativePlayKey=Join-Path $nativePlayWorkspace 'runtime-logs/local-multiplayer-server/native-test-key.dpapi'
$nativePlayArgs=@{Run=('native-local-play-'+[DateTime]::UtcNow.ToString('yyyyMMdd-hhmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6));Interactive=$true;PreserveOriginalPid=$PreserveOriginalPid}
if(Test-Path -LiteralPath $nativePlayKey){$nativePlayArgs.ProtectedKeyFile=$nativePlayKey}
& (Join-Path $PSScriptRoot 'tools/test-native-local-world.ps1') @nativePlayArgs
exit $LASTEXITCODE
