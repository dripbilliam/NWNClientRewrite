param([switch]$Apply)
$ErrorActionPreference='Stop'
$cleanupRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$expectedRoot=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Temp')).TrimEnd('\')
if(-not $cleanupRoot.Equals($expectedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected Temp root; cleanup refused'}
if((Get-Item -LiteralPath $cleanupRoot -Force).Attributes-band[IO.FileAttributes]::ReparsePoint){throw 'Linked Temp root; cleanup refused'}
$cleanupPrefix='^(?:nwn|nvn)-(?:godot|offline)-[A-Za-z0-9][A-Za-z0-9._-]*$'
$cleanupStarted=[DateTime]::UtcNow
$cleanupProcesses=@(Get-CimInstance Win32_Process)
$legacyHosts=@($cleanupProcesses|Where-Object{$_.Name-match'^(?:node|electron|Godot.*)\.exe$'-and$_.CommandLine-and$_.CommandLine-match'(?:local-host\.cjs|reference-live-host\.cjs|replay-scene\.cjs)'})
if($legacyHosts.Count){throw 'A legacy scene-export/replay host is running; preserve its temporary files'}
$cleanupRecords=[Collections.Generic.List[object]]::new()
$cleanupTotal=[long]0; $cleanupRemoved=[long]0; $cleanupCount=0; $cleanupDeleted=0
$cleanupCandidates=@(Get-ChildItem -LiteralPath $cleanupRoot -Force|Where-Object{$_.Name-match$cleanupPrefix})
foreach($candidate in $cleanupCandidates){
 $cleanupPath=[IO.Path]::GetFullPath($candidate.FullName)
 # Every recursive target must be a matching direct child of this exact Temp.
 if(-not [IO.Path]::GetDirectoryName($cleanupPath).Equals($cleanupRoot,[StringComparison]::OrdinalIgnoreCase)-or[IO.Path]::GetFileName($cleanupPath)-notmatch$cleanupPrefix){throw 'Target escaped the requested Temp scope'}
 $record=[ordered]@{name=$candidate.Name;bytes=[long]0;files=0;status='inspected'}
 $cleanupCount++
 try{
  if($candidate.LastWriteTimeUtc-gt$cleanupStarted.AddMinutes(-5)){$record.status='preserved-recent';continue}
  $normalized=$cleanupPath.Replace('\','/')
  if(@($cleanupProcesses|Where-Object{([string]$_.CommandLine).Replace('\','/').IndexOf($normalized,[StringComparison]::OrdinalIgnoreCase)-ge0-or([string]$_.ExecutablePath).Replace('\','/').IndexOf($normalized,[StringComparison]::OrdinalIgnoreCase)-ge0}).Count){$record.status='preserved-active';continue}
  $pending=[Collections.Generic.Stack[string]]::new();$pending.Push($cleanupPath)
  while($pending.Count){
   $entry=Get-Item -LiteralPath $pending.Pop() -Force
   if($entry.Attributes-band[IO.FileAttributes]::ReparsePoint){throw 'Contains a filesystem link; preserved'}
   if($entry.PSIsContainer){foreach($child in Get-ChildItem -LiteralPath $entry.FullName -Force){$pending.Push($child.FullName)}}
   else{$record.bytes+=[long]$entry.Length;$record.files++}
  }
  $cleanupTotal+=$record.bytes
  if($Apply){
   $resolved=[IO.Path]::GetFullPath((Get-Item -LiteralPath $cleanupPath -Force).FullName)
   if($resolved-ne$cleanupPath-or-not[IO.Path]::GetDirectoryName($resolved).Equals($cleanupRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Target changed before deletion'}
   if((Get-Item -LiteralPath $resolved -Force).Attributes-band[IO.FileAttributes]::ReparsePoint){throw 'Target became a filesystem link'}
   Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
   if(Test-Path -LiteralPath $resolved){throw 'Target still exists after cleanup'}
   $record.status='deleted';$cleanupDeleted++;$cleanupRemoved+=$record.bytes
  }else{$record.status='would-delete'}
 }catch{$record.status='preserved-error';$record.error=$_.Exception.Message}
 finally{$cleanupRecords.Add([PSCustomObject]$record)}
 if($cleanupCount%1000-eq0){Write-Output("Processed {0}/{1}; removed {2:N2} GiB"-f$cleanupCount,$cleanupCandidates.Count,($cleanupRemoved/1GB))}
}
$cleanupRemaining=@(Get-ChildItem -LiteralPath $cleanupRoot -Force|Where-Object{$_.Name-match$cleanupPrefix})
$cleanupReport=[ordered]@{tempRoot=$cleanupRoot;apply=[bool]$Apply;startedUtc=$cleanupStarted;finishedUtc=[DateTime]::UtcNow;candidates=$cleanupCandidates.Count;deleted=$cleanupDeleted;deletedBytes=$cleanupRemoved;deletedGiB=[Math]::Round($cleanupRemoved/1GB,3);scannedBytes=$cleanupTotal;remaining=$cleanupRemaining.Count;remainingNames=@($cleanupRemaining.Name);records=$cleanupRecords}
$cleanupReportFile=Join-Path (Split-Path $PSScriptRoot -Parent) ('godot-client/reports/temp-cleanup-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+'.json')
[IO.File]::WriteAllText($cleanupReportFile,($cleanupReport|ConvertTo-Json -Depth 6))
[PSCustomObject]@{deleted=$cleanupDeleted;deletedGiB=$cleanupReport.deletedGiB;remaining=$cleanupRemaining.Count;report=$cleanupReportFile}|ConvertTo-Json -Compress
