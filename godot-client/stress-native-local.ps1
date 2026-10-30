param([int]$PreserveOriginalPid=0)
$ErrorActionPreference='Stop'
# Same authored moving people/braziers module used by the JS dense tests.
# Assets and presentation are loaded natively by Godot; protocol is loopback.
$nativeStressRoot=Split-Path $PSScriptRoot -Parent
$nativeStressKey=Join-Path $nativeStressRoot 'runtime-logs/local-multiplayer-server/native-test-key.dpapi'
$nativeStressArgs=@{Run=('native-dense-play-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6));Interactive=$true;DenseFixture=$true;PreserveOriginalPid=$PreserveOriginalPid}
if(Test-Path -LiteralPath $nativeStressKey){$nativeStressArgs.ProtectedKeyFile=$nativeStressKey}
& (Join-Path $PSScriptRoot 'tools/test-native-local-world.ps1') @nativeStressArgs
exit $LASTEXITCODE
