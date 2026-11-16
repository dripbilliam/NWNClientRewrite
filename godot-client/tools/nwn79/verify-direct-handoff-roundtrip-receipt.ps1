param([Parameter(Mandatory=$true)][string]$Report)
$ErrorActionPreference='Stop'
function Require([bool]$ok,[string]$reason){if(-not$ok){throw ('Roundtrip receipt assertion failed: '+$reason)}}
Require (Test-Path -LiteralPath $Report -PathType Leaf) 'structured report exists'
$receipt=Get-Content -LiteralPath $Report -Raw|ConvertFrom-Json
$roundtrip=$receipt.direct_portal_roundtrip_check
$hops=@($roundtrip.hops)
Require (-not$receipt.failure -and $receipt.clean_exit -eq $true -and $receipt.protocol_finish_ack -eq $true -and $receipt.world.ready -eq $true) 'client, world and protocol close cleanly'
Require ($hops.Count -eq 2 -and [int]$hops[0].fromPort -eq 5121 -and [int]$hops[0].toPort -eq 5122 -and [int]$hops[1].fromPort -eq 5122 -and [int]$hops[1].toPort -eq 5121) 'authored A to B to A route'
Require ([int]$hops[0].sourceConnection -lt [int]$hops[0].destinationConnection -and [int]$hops[0].destinationConnection -eq [int]$hops[1].sourceConnection -and [int]$hops[1].sourceConnection -lt [int]$hops[1].destinationConnection) 'three distinct ordered connections'
Require ([long]$hops[0].sourceArea -ne [long]$hops[0].destinationArea -and [long]$hops[1].destinationArea -eq [long]$hops[0].sourceArea -and [long]$hops[1].sourceArea -eq [long]$hops[0].destinationArea) 'origin area restored after destination'
foreach($hop in $hops){Require ($hop.oldRetired -eq $true -and $hop.destinationAuthStarted -eq $true -and $hop.worldAdmitted -eq $true -and $hop.controlReady -eq $true -and $hop.resourceScopeCurrent -eq $true -and $hop.staleWorkRejected -eq $true -and $hop.characterKind -in @('bic','reference')) 'retired old session, admitted current world and preserved character scope'}
Require ([int]$roundtrip.finalPort -eq 5121 -and [int]$roundtrip.finalConnection -eq [int]$hops[1].destinationConnection -and [long]$receipt.world.area_id -eq [long]$hops[0].sourceArea) 'final world belongs to returned origin connection'
[ordered]@{status='pass';report=[IO.Path]::GetFullPath($Report);reportSha256=(Get-FileHash -LiteralPath $Report -Algorithm SHA256).Hash.ToLowerInvariant();hops=2;connections=3;cleanExit=$true}|ConvertTo-Json -Compress
