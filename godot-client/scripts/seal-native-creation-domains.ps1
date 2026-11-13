[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$domainProject=Split-Path -Parent $PSScriptRoot
$domainOutput=Join-Path $domainProject 'backups/native-creation-domains-v1.zip'
$domainReceipt=Join-Path $domainProject 'reports/native-creation-domains-checkpoint-v1.json'
if((Test-Path -LiteralPath $domainOutput)-or(Test-Path -LiteralPath $domainReceipt)){throw 'Preserve this immutable checkpoint'}
$domainEntries=[Collections.Generic.List[object]]::new()
$domainNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
function Add-DomainEntry([string]$Source,[string]$Entry){
 if(-not(Test-Path -LiteralPath $Source -PathType Leaf)){throw ('Missing input: '+$Source)}
 if(-not$domainNames.Add($Entry)){throw ('Duplicate entry: '+$Entry)}
 $domainEntries.Add([ordered]@{source=[IO.Path]::GetFullPath($Source);entry=$Entry;sha256=(Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.ToLowerInvariant()})
}
$domainCases=@('native-creation-domains-state-v2','native-creation-domains-resources-v1','native-creation-domains-view-v5','native-creation-domains-binding-v2','native-creation-school-binding-post-domains-v1')
$domainAccepted=[Collections.Generic.List[object]]::new()
foreach($case in $domainCases){
 $receiptPath=Join-Path $domainProject ('reports/'+$case+'-receipt.json')
 $caseReceipt=Get-Content -LiteralPath $receiptPath -Raw|ConvertFrom-Json
 if(-not$caseReceipt.success-or-not$caseReceipt.engineClean-or$caseReceipt.exitCode-ne0-or$caseReceipt.changedInputs.Count-ne0){throw ('Rejected test receipt: '+$case)}
 $caseRoot=[IO.Path]::GetFullPath([string]$caseReceipt.directory)
 if(-not$caseRoot.StartsWith([IO.Path]::GetFullPath((Join-Path $domainProject '.cache'))+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Test snapshot outside project cache'}
 foreach($input in $caseReceipt.inputs){
  $copy=Join-Path $caseRoot ('project/'+$input.path)
  if((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw ('Accepted copy changed: '+$case+'/'+$input.path)}
  Add-DomainEntry $copy ('accepted/'+$case+'/project/'+$input.path)
 }
 foreach($file in @('receipt.json','result.json','engine.log','stdout.log','stderr.log')){Add-DomainEntry (Join-Path $caseRoot $file) ('accepted/'+$case+'/'+$file)}
 foreach($file in @('project.godot','oracle.json')){
  $copy=Join-Path $caseRoot ('project/'+$file)
  if(Test-Path -LiteralPath $copy -PathType Leaf){Add-DomainEntry $copy ('accepted/'+$case+'/project/'+$file)}
 }
 $domainAccepted.Add([ordered]@{name=$case;checks=$caseReceipt.result.checks;inputs=$caseReceipt.inputs.Count;scope=$caseReceipt.scope})
}
$domainEvidence=@('NATIVE-CREATION-DOMAINS.md','NATIVE-CREATION-SCHOOL.md','NATIVE-CREATION-FEAT-ADAPTER.md','NATIVE-UI-RESOURCE-INVENTORY.md','scripts/seal-native-creation-domains.ps1','reports/native-creation-domains-static-v1.json','reports/native-creation-domains-original-v1.json','reports/native-creation-domains-original-failed-v1.json','reports/native-creation-domains-original-failed-v2.json','tests/run-native-creation-domains-state-tests.ps1','tests/run-native-creation-domains-resources-tests.ps1','tests/run-native-creation-domains-view-tests.ps1','tests/run-native-creation-domains-binding-tests.ps1','tests/run-native-creation-school-binding-tests.ps1')
foreach($file in $domainEvidence){Add-DomainEntry (Join-Path $domainProject $file) ('evidence/'+$file)}
foreach($file in @('inspect-native-creation-domains.py','inspect-native-intratile-coordinator.py')){Add-DomainEntry (Join-Path (Split-Path -Parent $domainProject) ('scripts/'+$file)) ('evidence/workspace-scripts/'+$file)}
Add-DomainEntry (Join-Path $domainProject '.cache/domains-checkpoints/20261103-011644-before-painter/native_gui_painter.gd') 'dirty-before/native_gui_painter.gd'
Add-DomainEntry (Join-Path $domainProject '.cache/domains-checkpoints/20261103-011644-before-painter/native_domains_chooser.gd') 'chronology/rejected-row-reuse/native_domains_chooser.gd'
foreach($file in @('native_creation.gd','native_creation_frontend.gd')){Add-DomainEntry (Join-Path $domainProject ('.cache/domains-checkpoints/20261103-012016-before-integration/'+$file)) ('dirty-before/'+$file)}
foreach($rejected in @('domains-view-tests/20261103-011325-f3379a4e','domains-view-tests/20261103-011426-740bec28','domains-binding-tests/20261103-012656-53523546')){
 foreach($file in @('receipt.json','result.json','engine.log','stdout.log','stderr.log')){
  $source=Join-Path $domainProject ('.cache/'+$rejected+'/'+$file)
  if(Test-Path -LiteralPath $source -PathType Leaf){Add-DomainEntry $source ('rejected/'+$rejected+'/'+$file)}
 }
}
$domainScope='Exact accepted copied closures/evidence and three dirty-before files. Headless controlled-art input/draft checks, not original pixels, all rule variants, complete source creation/level-up, server upload or modal fullcoverage. Later shared-agent edits are outside this sealed acceptance.'
$domainManifest=[ordered]@{schema=1;createdAtUtc=[DateTime]::UtcNow.ToString('o');cases=$domainAccepted;scope=$domainScope;entries=@($domainEntries|ForEach-Object{[ordered]@{path=$_.entry;sha256=$_.sha256}})}
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($domainOutput))|Out-Null
$domainZip=[IO.Compression.ZipFile]::Open($domainOutput,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($input in $domainEntries){
  if((Get-FileHash -LiteralPath $input.source -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw ('Input changed: '+$input.entry)}
  [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($domainZip,$input.source,$input.entry,[IO.Compression.CompressionLevel]::SmallestSize)|Out-Null
 }
 $entry=$domainZip.CreateEntry('manifest.json',[IO.Compression.CompressionLevel]::SmallestSize)
 $writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false))
 try{$writer.Write(($domainManifest|ConvertTo-Json -Depth 12)+[Environment]::NewLine)}finally{$writer.Dispose()}
}finally{$domainZip.Dispose()}
$domainVerify=[IO.Compression.ZipFile]::OpenRead($domainOutput)
try{
 if($domainVerify.Entries.Count-ne$domainEntries.Count+1){throw 'Archive entry count mismatch'}
 foreach($input in $domainEntries){
  $entry=$domainVerify.GetEntry($input.entry);if($null-eq$entry){throw ('Missing archive entry: '+$input.entry)}
  $stream=$entry.Open()
  try{$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()}finally{$stream.Dispose()}
  if($hash-ne$input.sha256){throw ('Archive content mismatch: '+$input.entry)}
 }
}finally{$domainVerify.Dispose()}
$domainPacket=[ordered]@{success=$true;createdAtUtc=[DateTime]::UtcNow.ToString('o');archive=$domainOutput;sha256=(Get-FileHash -LiteralPath $domainOutput -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $domainOutput).Length;entries=$domainEntries.Count+1;verifiedContentEntries=$domainEntries.Count;cases=$domainAccepted;scope=$domainScope}
[IO.File]::WriteAllText($domainReceipt,($domainPacket|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
[pscustomobject]$domainPacket|Select-Object success,archive,sha256,bytes,entries,verifiedContentEntries|ConvertTo-Json -Compress
