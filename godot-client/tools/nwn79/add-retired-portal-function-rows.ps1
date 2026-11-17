param([string]$LedgerPath = (Join-Path $PSScriptRoot 'js-runtime-function-ledger-v1.json'))
$ErrorActionPreference='Stop'
$ledger=Get-Content -LiteralPath $LedgerPath -Raw|ConvertFrom-Json -AsHashtable
$path='electron/network_portal_transfer.mjs'
$module=@($ledger.moduleRecords|Where-Object oldPath -eq $path)[0]
if(-not $module){throw 'Portal module is absent from old normal-runtime closure'}
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$source=@(git -C $workspace show "HEAD:$path")
if($LASTEXITCODE -ne 0){throw 'Portal source is unavailable in HEAD'}
$added=0
foreach($name in @('constructor','receive','begin','peerClosed','clear','fail','dispose')){
 $hits=@()
 for($i=0;$i -lt $source.Count;$i++){
  if($source[$i] -match ('^\s+(?:async\s+)?'+[regex]::Escape($name)+'\s*\(.*\)\s*\{')){$hits+=($i+1)}
 }
 if($hits.Count -ne 1){throw "Expected one portal declaration for $name; got $($hits.Count)"}
 $location="$path`:$($hits[0])"
 if(@($module.functions|Where-Object { $_.oldLocation -eq $location -and $_.oldSymbol -eq $name }).Count){continue}
 $module.functions += [ordered]@{oldSymbol=$name;oldQualifiedSymbol="NetworkPortalTransfer.$name";oldLocation=$location;kind='class method';status='pending';godotReplacement='';actualGodotCaller='';evidence=@();gap='Original portal method is mechanically inventoried; exact Godot caller and per-branch parity require review'}
 $added++
}
$ledger.sourceInventory.mechanicalCandidateCount=@($ledger.moduleRecords|ForEach-Object {$_.functions}).Count
$ledger.sourceInventory.complete=$false
[IO.File]::WriteAllText($LedgerPath,(($ledger|ConvertTo-Json -Depth 40)+"`n"),[Text.UTF8Encoding]::new($false))
Write-Output "portalRowsAdded=$added totalRows=$($ledger.sourceInventory.mechanicalCandidateCount)"
