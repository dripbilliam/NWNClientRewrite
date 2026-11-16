param([string]$Fixture='')
$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$source=if($Fixture){[IO.Path]::GetFullPath($Fixture)}else{Join-Path $client '.cache/packed-recording-fixture-v3/source'}
$verifier=Join-Path $PSScriptRoot 'verify-native-loading-capture.ps1'
$entry=Join-Path $client 'replay-native-loading.ps1'
$scratch=Join-Path $client ('.cache/nwn79-capture-verifier-test-'+[guid]::NewGuid().ToString('N'))
function Hash([byte[]]$bytes){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
function CopyFixture([string]$name){
 $destination=Join-Path $scratch $name
 New-Item -ItemType Directory -Path $destination -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path $source 'recording.json'),(Join-Path $source 'timeline.jsonl') -Destination $destination
 foreach($catalog in Get-ChildItem -LiteralPath $source -Directory -Filter 'catalog-*'){Copy-Item -LiteralPath $catalog.FullName -Destination $destination -Recurse}
 return $destination
}
function UpdateTimeline([string]$directory,$row){
 $line=$row|ConvertTo-Json -Depth 30 -Compress
 $bytes=[Text.Encoding]::UTF8.GetBytes($line+"`n")
 [IO.File]::WriteAllBytes((Join-Path $directory 'timeline.jsonl'),$bytes)
 $manifest=Get-Content -LiteralPath (Join-Path $directory 'recording.json') -Raw|ConvertFrom-Json -AsHashtable
 $manifest.timelineSha256=Hash $bytes
 [IO.File]::WriteAllText((Join-Path $directory 'recording.json'),($manifest|ConvertTo-Json -Depth 20 -Compress))
}
function Reject([string]$name,[scriptblock]$mutate,[string]$expected){
 $directory=CopyFixture $name
 & $mutate $directory
 $reason=''
 try{& $verifier -Capture $directory|Out-Null}catch{$reason=$_.Exception.Message}
 if(-not$reason.Contains($expected)){throw ("$name expected '$expected' rejection, observed '$reason'")}
}
try{
 New-Item -ItemType Directory -Path $scratch -Force|Out-Null
 $positive=(& $entry -Capture $source -Run ('nwn79-verifier-'+[guid]::NewGuid().ToString('N')) -VerifyOnly)|ConvertFrom-Json
 if($positive.complete -ne $true -or $positive.events -ne 1 -or $positive.catalogs -ne 1 -or $positive.networkConnections -ne 0){throw 'Godot-only entrypoint did not verify the sealed positive fixture'}
 $combined=(& $entry -Capture $source -Run ('nwn79-verifier-combined-'+[guid]::NewGuid().ToString('N')) -VerifyOnly -Generation 4 -Headless -Paced -MovementTiming -Interactive)|ConvertFrom-Json
 if(($combined|ConvertTo-Json -Compress) -cne ($positive|ConvertTo-Json -Compress)){throw 'Combined VerifyOnly switches changed the original read-only result'}
 $combinedInvalid=CopyFixture 'combined-timeline-hash'
 [IO.File]::AppendAllText((Join-Path $combinedInvalid 'timeline.jsonl'),' ')
 $combinedReason=''
 try{& $entry -Capture $combinedInvalid -Run ('nwn79-verifier-negative-'+[guid]::NewGuid().ToString('N')) -VerifyOnly -Generation 4 -Headless -Paced -MovementTiming -Interactive|Out-Null}catch{$combinedReason=$_.Exception.Message}
 if(-not$combinedReason.Contains('Loading timeline checksum/bound differs')){throw 'Combined VerifyOnly accepted a corrupt timeline or entered playback'}
 Reject 'timeline-hash' {param($d)$p=Join-Path $d 'timeline.jsonl';[IO.File]::AppendAllText($p,' ')} 'Loading timeline checksum/bound differs'
 Reject 'catalog-hash' {param($d)$p=Join-Path $d 'catalog-1/manifest.json';[IO.File]::AppendAllText($p,' ')} 'Catalog manifest checksum differs'
 Reject 'sequence' {param($d)$row=Get-Content (Join-Path $d 'timeline.jsonl') -Raw|ConvertFrom-Json -AsHashtable;$row.sequence=0;UpdateTimeline $d $row} 'Invalid replay ordering'
 Reject 'unsupported-frame' {param($d)$row=Get-Content (Join-Path $d 'timeline.jsonl') -Raw|ConvertFrom-Json -AsHashtable;$row.value.kind='unknown';UpdateTimeline $d $row} 'Unsupported native frame'
 Reject 'unknown-catalog' {param($d)$row=Get-Content (Join-Path $d 'timeline.jsonl') -Raw|ConvertFrom-Json -AsHashtable;$row.value.resourceSources.recordedCatalog='catalog-7';UpdateTimeline $d $row} 'Setup references an unknown captured catalog'
 Reject 'event-count' {param($d)$m=Get-Content (Join-Path $d 'recording.json') -Raw|ConvertFrom-Json -AsHashtable;$m.events=2;[IO.File]::WriteAllText((Join-Path $d 'recording.json'),($m|ConvertTo-Json -Depth 20 -Compress))} 'Recording event count differs'
 Reject 'movement-without-metadata' {param($d)$row=Get-Content (Join-Path $d 'timeline.jsonl') -Raw|ConvertFrom-Json -AsHashtable;$row.kind='movement-input';$row.value=@{kind='drive';connection=1;generation=1;areaId=1;actorId=1;lifetime=1;requestId=1;operation='drive';flags=1;heading=0;position=@(0,0,0);transmit=$true};UpdateTimeline $d $row} 'Invalid movement timing event'
 Reject 'movement-invalid-packet' {param($d)$row=Get-Content (Join-Path $d 'timeline.jsonl') -Raw|ConvertFrom-Json -AsHashtable;$row.kind='network-game-packet';$row.value=@{connection=1;generation=1;areaId=1;direction='sent';bytes=3;base64=[Convert]::ToBase64String([byte[]]@(112,6,1));sha256=('0'*64)};UpdateTimeline $d $row;$m=Get-Content (Join-Path $d 'recording.json') -Raw|ConvertFrom-Json -AsHashtable;$m.metadata=@{movementTiming=$true};[IO.File]::WriteAllText((Join-Path $d 'recording.json'),($m|ConvertTo-Json -Depth 20 -Compress))} 'Invalid movement timing event'
 $valid=CopyFixture 'movement-valid-packet';$packet=[byte[]]@(112,6,1);$row=Get-Content (Join-Path $valid 'timeline.jsonl') -Raw|ConvertFrom-Json -AsHashtable;$row.kind='network-game-packet';$row.value=@{connection=1;generation=1;areaId=1;direction='sent';bytes=3;base64=[Convert]::ToBase64String($packet);sha256=(Hash $packet)};UpdateTimeline $valid $row;$m=Get-Content (Join-Path $valid 'recording.json') -Raw|ConvertFrom-Json -AsHashtable;$m.metadata=@{movementTiming=$true};[IO.File]::WriteAllText((Join-Path $valid 'recording.json'),($m|ConvertTo-Json -Depth 20 -Compress))
 $movement=(& $verifier -Capture $valid)|ConvertFrom-Json
 if($movement.complete -ne $true -or $movement.events -ne 1){throw 'Valid sealed movement packet fixture was rejected'}
 [ordered]@{format='nwn79-native-loading-capture-verifier-test-v1';positive=$true;combinedVerifyOnly=$true;negativeCases=9;validMovementPacket=$true;nodeInvoked=$false;electronInvoked=$false}|ConvertTo-Json -Compress
}finally{
 $scratch=[IO.Path]::GetFullPath($scratch)
 $cache=[IO.Path]::GetFullPath((Join-Path $client '.cache'))
 if($scratch.StartsWith($cache+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $scratch)){Remove-Item -LiteralPath $scratch -Recurse -Force}
}
