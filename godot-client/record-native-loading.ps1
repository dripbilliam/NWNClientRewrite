param([ValidatePattern('^[a-z0-9-]+$')][string]$Run=('native-loading-record-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()),[switch]$LocalCheck,[switch]$Headless)
$ErrorActionPreference='Stop'
$recordingPrevious=[Environment]::GetEnvironmentVariable('NWN_RECORD_LOADING','Process')
try{
 [Environment]::SetEnvironmentVariable('NWN_RECORD_LOADING','1','Process')
 & (Join-Path $PSScriptRoot 'join-native.ps1') -Run $Run -Profile -LocalCheck:$LocalCheck -Headless:$Headless
}finally{[Environment]::SetEnvironmentVariable('NWN_RECORD_LOADING',$recordingPrevious,'Process')}
