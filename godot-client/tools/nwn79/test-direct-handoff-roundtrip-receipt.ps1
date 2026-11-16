$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$scratch=Join-Path $client ('.cache/nwn79-handoff-receipt-test-'+[guid]::NewGuid().ToString('N'))
$verifier=Join-Path $PSScriptRoot 'verify-direct-handoff-roundtrip-receipt.ps1'
function Fixture {
 return @{clean_exit=$true;protocol_finish_ack=$true;world=@{ready=$true;area_id=101};direct_portal_roundtrip_check=@{finalPort=5121;finalConnection=3;hops=@(
  @{fromPort=5121;toPort=5122;sourceConnection=1;destinationConnection=2;sourceArea=101;destinationArea=202;oldRetired=$true;destinationAuthStarted=$true;worldAdmitted=$true;controlReady=$true;resourceScopeCurrent=$true;staleWorkRejected=$true;characterKind='bic'},
  @{fromPort=5122;toPort=5121;sourceConnection=2;destinationConnection=3;sourceArea=202;destinationArea=101;oldRetired=$true;destinationAuthStarted=$true;worldAdmitted=$true;controlReady=$true;resourceScopeCurrent=$true;staleWorkRejected=$true;characterKind='bic'})}}
}
function WriteFixture($receipt){$receipt|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $scratch 'receipt.json') -Encoding utf8}
function Reject([string]$name,[scriptblock]$mutate,[string]$reason){
 $receipt=Fixture
 & $mutate $receipt
 WriteFixture $receipt
 $actual=''
 try{& $verifier -Report (Join-Path $scratch 'receipt.json')|Out-Null}catch{$actual=$_.Exception.Message}
 if(-not$actual.Contains($reason)){throw ("$name expected '$reason' but got '$actual'")}
}
try{
 New-Item -ItemType Directory -Path $scratch -Force|Out-Null
 WriteFixture (Fixture)
 $good=(& $verifier -Report (Join-Path $scratch 'receipt.json'))|ConvertFrom-Json
 if($good.status -ne 'pass' -or $good.hops -ne 2 -or $good.connections -ne 3){throw 'Valid two-hop receipt was rejected'}
 Reject 'route' {param($r)$r.direct_portal_roundtrip_check.hops[1].toPort=5122} 'authored A to B to A route'
 Reject 'connection' {param($r)$r.direct_portal_roundtrip_check.hops[1].destinationConnection=2} 'three distinct ordered connections'
 Reject 'return-area' {param($r)$r.direct_portal_roundtrip_check.hops[1].destinationArea=203} 'origin area restored'
 Reject 'old-retirement' {param($r)$r.direct_portal_roundtrip_check.hops[1].oldRetired=$false} 'retired old session'
 Reject 'stale-scope' {param($r)$r.direct_portal_roundtrip_check.hops[0].staleWorkRejected=$false} 'retired old session'
 Reject 'final-control' {param($r)$r.direct_portal_roundtrip_check.finalPort=5122} 'final world belongs'
 [ordered]@{format='nwn79-direct-handoff-roundtrip-receipt-test-v1';positive=$true;negativeCases=6;nodeInvoked=$false;clientOrServerStarted=$false}|ConvertTo-Json -Compress
}finally{
 $scratch=[IO.Path]::GetFullPath($scratch)
 $cache=[IO.Path]::GetFullPath((Join-Path $client '.cache'))
 if($scratch.StartsWith($cache+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $scratch)){Remove-Item -LiteralPath $scratch -Recurse -Force}
}
