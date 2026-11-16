param([Parameter(Mandatory=$true)][string]$Capture,[ValidatePattern('^[a-z0-9-]+$')][string]$Run=('native-loading-replay-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()),[switch]$Headless,[switch]$Paced,[switch]$MovementTiming,[switch]$Interactive,[switch]$VerifyOnly,[ValidateRange(0,2147483647)][int]$Generation=0)
$ErrorActionPreference='Stop'
if($VerifyOnly){
 # The original replay script verifies and returns before selecting a generation or using playback switches.
 & (Join-Path $PSScriptRoot 'tools/nwn79/verify-native-loading-capture.ps1') -Capture $Capture -Run $Run
 return
}
# NWN79_REPLAY_RETIRED: read-only verification is retained; renderer playback is unsupported.
throw 'Native loading replay and timing modes are retired. Use -VerifyOnly for sealed capture validation.'
