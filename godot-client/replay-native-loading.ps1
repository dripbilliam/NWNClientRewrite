param([Parameter(Mandatory=$true)][string]$Capture,[ValidatePattern('^[a-z0-9-]+$')][string]$Run=('native-loading-replay-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()),[switch]$Headless,[switch]$Paced,[switch]$Interactive,[switch]$VerifyOnly,[ValidateRange(0,2147483647)][int]$Generation=0)
$ErrorActionPreference='Stop'
$replayArguments=@((Join-Path $PSScriptRoot 'tools/replay-native-loading.mjs'),('--capture='+[IO.Path]::GetFullPath($Capture)),('--run='+$Run))
if($Headless){$replayArguments+='--headless'}elseif(-not$VerifyOnly){
 . (Join-Path $PSScriptRoot 'tools/native-window-screen.ps1')
 $replayScreen=Get-NativeSecondaryScreen
 if($replayScreen-ge0){$replayArguments+=('--screen='+$replayScreen)}
}
if($Paced){$replayArguments+='--paced'}
if($Interactive){$replayArguments+='--interactive'}
if($VerifyOnly){$replayArguments+='--verify-only'}
if($Generation){$replayArguments+=('--generation='+$Generation)}
& node @replayArguments
exit $LASTEXITCODE
