param([Parameter(Mandatory=$true)][string]$Capture,[string]$Run='')
$ErrorActionPreference='Stop'
$directory=[IO.Path]::GetFullPath($Capture)
if(-not(Test-Path -LiteralPath $directory -PathType Container)){throw 'Loading capture directory is unavailable'}
if($Run){
 if($Run -cnotmatch '^[a-z0-9-]+$'){throw 'Invalid replay name'}
 $reports=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../reports'))
 if(Test-Path -LiteralPath $reports -PathType Container){
  if(@(Get-ChildItem -LiteralPath $reports -File|Where-Object {$_.Name.StartsWith($Run+'.',[StringComparison]::Ordinal)}).Count){throw 'Existing replay artifacts are preserved; use a fresh run label'}
 }
}
function Need([bool]$condition,[string]$message){if(-not$condition){throw $message}}
function Digest([byte[]]$bytes){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
function IntIn($value,[double]$maximum){
 if($value -is [bool] -or $value -is [string] -or $null -eq $value){return $false}
 try{$number=[double]$value;return [double]::IsFinite($number) -and $number -ge 0 -and $number -le $maximum -and [Math]::Floor($number) -eq $number}catch{return $false}
}
function Scope($value){return (IntIn $value.connection 4294967295) -and (IntIn $value.generation 4294967295) -and (IntIn $value.areaId 4294967295)}
function Vector($value){
 if($value -isnot [array] -or $value.Count -lt 2 -or $value.Count -gt 3){return $false}
 foreach($part in $value){if($part -is [string] -or $part -is [bool] -or $null -eq $part){return $false};try{if(-not[double]::IsFinite([double]$part)){return $false}}catch{return $false}}
 return $true
}
function MovementInput($value){
 if($value.kind -cne 'drive' -or -not(Scope $value) -or -not(IntIn $value.actorId 4294967295) -or -not(IntIn $value.lifetime 4294967295) -or -not(IntIn $value.requestId 4294967295) -or $value.operation -cnotin @('drive','turn','stop')){return $false}
 if($value.operation -ceq 'drive' -and (-not(IntIn $value.flags 63) -or [int]$value.flags -eq 0 -or -not(IntIn $value.heading 3599) -or -not(Vector $value.position) -or $value.transmit -isnot [bool])){return $false}
 if($value.operation -ceq 'turn' -and -not(Vector $value.position)){return $false}
 return $true
}
function MovementEvent([string]$kind,$value){
 if(-not(Scope $value)){return $false}
 if($kind -cin @('movement-input','movement-dispatch')){return MovementInput $value}
 if($kind -ceq 'movement-sample'){
  return $value.kind -ceq 'movement-sample' -and (IntIn $value.native_ticks_us 9007199254740991) -and (IntIn $value.native_frame 9007199254740991) -and (IntIn $value.actorId 4294967295) -and (IntIn $value.lifetime 4294967295) -and $null -ne $value.state -and ($value.state -is [Collections.IDictionary] -or $value.state -is [array])
 }
 if($kind -cne 'network-game-packet' -or $value.direction -cnotin @('received','sent') -or -not(IntIn $value.bytes 786400) -or [int]$value.bytes -lt 3 -or $value.base64 -isnot [string] -or $value.sha256 -cnotmatch '^[0-9a-f]{64}$'){return $false}
 try{$packet=[Convert]::FromBase64String($value.base64)}catch{return $false}
 if($packet.Length -ne [int]$value.bytes -or $packet[0] -ne $(if($value.direction -ceq 'received'){80}else{112}) -or (Digest $packet) -cne $value.sha256){return $false}
 return $value.direction -cne 'sent' -or ($packet[1] -eq 6 -and $packet[2] -in @(1,28,29,33))
}
$manifestPath=Join-Path $directory 'recording.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8|ConvertFrom-Json -AsHashtable
Need ((IntIn $manifest.version 1) -and $manifest.version -eq 1 -and $manifest.complete -ceq $true -and $manifest.catalogs -is [array]) 'Loading recording is incomplete or unsupported'
$timelinePath=Join-Path $directory 'timeline.jsonl'
$timelineInfo=Get-Item -LiteralPath $timelinePath
Need ($timelineInfo.Length -le 256MB) 'Loading timeline checksum/bound differs'
$timeline=[IO.File]::ReadAllBytes($timelinePath)
Need ((Digest $timeline) -ceq [string]$manifest.timelineSha256) 'Loading timeline checksum/bound differs'
$catalogs=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach($item in $manifest.catalogs){
 Need ($item.directory -cmatch '^catalog-[0-9]+$') 'Invalid catalog directory'
 $catalogPath=Join-Path $directory ($item.directory+'/manifest.json')
 $catalogBytes=[IO.File]::ReadAllBytes($catalogPath)
 Need ((Digest $catalogBytes) -ceq [string]$item.sha256) 'Catalog manifest checksum differs'
 $data=[Text.Encoding]::UTF8.GetString($catalogBytes)|ConvertFrom-Json -AsHashtable
 Need ($data.complete -ceq $true -and (IntIn $data.version 2) -and $data.version -eq 2) 'Incomplete native resources'
 [void]$catalogs.Add([string]$item.directory)
}
$frameKinds=@('session-reset','setup','raw-world-begin','raw-world-chunk','raw-world-end','movement','drive-ack','native-clock-protocol','raw-visual-events','raw-combat-events','raw-voice-events','raw-script-sounds','ui-protocol')
$ackKinds=@('catalog-ready','area-ready','raw-world-accepted')
$movementKinds=@('movement-input','movement-dispatch','movement-sample','network-game-packet')
$sequence=0.0;$at=-1.0;$events=0
foreach($line in ([Text.Encoding]::UTF8.GetString($timeline).Trim() -split "`n")){
 Need ([Text.Encoding]::UTF8.GetByteCount($line) -le 1MB+4096) 'Replay frame exceeds bound'
 $row=$line|ConvertFrom-Json -AsHashtable
 Need ((IntIn $row.sequence 9007199254740991) -and [double]$row.sequence -gt $sequence -and $null -ne $row.at -and $row.at -isnot [string] -and $row.at -isnot [bool] -and [double]::IsFinite([double]$row.at) -and [double]$row.at -ge $at) 'Invalid replay ordering'
 $sequence=[double]$row.sequence;$at=[double]$row.at
 if($row.kind -ceq 'frame'){
  Need ($row.value.kind -cin $frameKinds) 'Unsupported native frame'
  if($row.value.kind -ceq 'setup'){Need ($catalogs.Contains([string]$row.value.resourceSources.recordedCatalog)) 'Setup references an unknown captured catalog'}
 }elseif($row.kind -ceq 'acknowledgement'){
  Need ($row.value.kind -cin $ackKinds) 'Unsupported native acknowledgement'
 }elseif($row.kind -cin $movementKinds){
  Need ($manifest.metadata.movementTiming -ceq $true -and (MovementEvent $row.kind $row.value)) 'Invalid movement timing event'
 }else{Need ($row.kind -cin @('view','baseline')) 'Unsupported recording event'}
 $events++
}
Need ($events -eq $manifest.events) 'Recording event count differs'
[ordered]@{complete=$true;events=$events;catalogs=@($manifest.catalogs).Count;networkConnections=0}|ConvertTo-Json -Compress
