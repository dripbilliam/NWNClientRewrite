$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture=Join-Path $client '.cache/packed-recording-fixture-v3/source'
function Reject([string]$name,[scriptblock]$call,[string]$expected){
 $reason=''
 try{& $call|Out-Null}catch{$reason=$_.Exception.Message}
 if(-not$reason.Contains($expected)){throw ($name+' did not reject before the retired runtime: '+$reason)}
}
Reject 'join-native list flags' {& (Join-Path $client 'join-native.ps1') -ListFlags -Headless -LocalOnly -ActionCheck} 'The original ListFlags diagnostic is retired'
Reject 'join-native action' {& (Join-Path $client 'join-native.ps1') -ActionCheck} 'Original-host diagnostic flags are retired'
Reject 'join-local weather' {& (Join-Path $client 'join-local.ps1') -WeatherSmoke} 'Original-host local diagnostic flags are retired'
Reject 'join-local combined smoke' {& (Join-Path $client 'join-local.ps1') -Smoke -Headless} 'Original-host local diagnostic flags are retired'
Reject 'loading replay' {& (Join-Path $client 'replay-native-loading.ps1') -Capture $fixture -Paced} 'Native loading replay and timing modes are retired'
Reject 'handoff' {& (Join-Path $client 'test-handoff.ps1') -Report ('nwn79-retired-'+[guid]::NewGuid().ToString('N')+'.json')} 'Original-host handoff scenarios are retired'
[ordered]@{format='nwn79-retired-entrypoints-test-v1';rejected=@('join-native-list-flags','join-native-action','join-local-weather','join-local-combined-smoke','loading-replay','handoff');nodeInvoked=$false;electronInvoked=$false;serverInvoked=$false}|ConvertTo-Json -Compress
