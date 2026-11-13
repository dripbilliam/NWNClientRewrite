[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$schoolProject=Split-Path -Parent $PSScriptRoot
$schoolOutput=Join-Path $schoolProject 'backups/native-creation-school-v1.zip'
$schoolReceipt=Join-Path $schoolProject 'reports/native-creation-school-checkpoint-v1.json'
if((Test-Path -LiteralPath $schoolOutput)-or(Test-Path -LiteralPath $schoolReceipt)){throw 'This immutable checkpoint already exists'}
$schoolEntries=[Collections.Generic.List[object]]::new()
$schoolNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
function Add-SchoolEntry([string]$Source,[string]$Entry){
 if(-not(Test-Path -LiteralPath $Source -PathType Leaf)){throw ('Missing input: '+$Source)}
 if(-not$schoolNames.Add($Entry)){throw ('Duplicate entry: '+$Entry)}
 $schoolEntries.Add([ordered]@{source=[IO.Path]::GetFullPath($Source);entry=$Entry;sha256=(Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.ToLowerInvariant()})
}
$schoolCases=@(
 'native-creation-school-state-v3',
 'native-creation-school-view-v2',
 'native-creation-school-binding-v2',
 'native-creation-feat-binding-post-school-v1',
 'native-creation-feat-adapter-post-school-v1'
)
$schoolAccepted=[Collections.Generic.List[object]]::new()
foreach($case in $schoolCases){
 $receiptPath=Join-Path $schoolProject ('reports/'+$case+'-receipt.json')
 $caseReceipt=Get-Content -LiteralPath $receiptPath -Raw|ConvertFrom-Json
 if(-not$caseReceipt.success-or-not$caseReceipt.engineClean-or$caseReceipt.exitCode-ne0-or$caseReceipt.changedInputs.Count-ne0){throw ('Rejected test receipt: '+$case)}
 $caseRoot=[IO.Path]::GetFullPath([string]$caseReceipt.directory)
 if(-not$caseRoot.StartsWith([IO.Path]::GetFullPath((Join-Path $schoolProject '.cache'))+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Accepted test copy is outside project cache'}
 foreach($input in $caseReceipt.inputs){
  $copied=Join-Path $caseRoot ('project/'+$input.path)
  if((Get-FileHash -LiteralPath $copied -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw ('Accepted snapshot changed: '+$case+'/'+$input.path)}
  Add-SchoolEntry $copied ('accepted/'+$case+'/project/'+$input.path)
 }
 foreach($file in @('receipt.json','result.json','engine.log','stdout.log','stderr.log')){Add-SchoolEntry (Join-Path $caseRoot $file) ('accepted/'+$case+'/'+$file)}
 foreach($file in @('project.godot','oracle.json','school-oracle.json')){
  $source=Join-Path $caseRoot ('project/'+$file)
  if(Test-Path -LiteralPath $source -PathType Leaf){Add-SchoolEntry $source ('accepted/'+$case+'/project/'+$file)}
 }
 $schoolAccepted.Add([ordered]@{name=$case;checks=$caseReceipt.result.checks;inputs=$caseReceipt.inputs.Count;scope=$caseReceipt.scope})
}
$schoolFiles=@(
 'NATIVE-CREATION-SCHOOL.md','NATIVE-CREATION-FEAT-ADAPTER.md','NATIVE-CREATION-FEATS.md',
 'reports/native-creation-school-static-v1.json',
 'reports/native-creation-post-feats-original-v1.json',
 'reports/native-creation-post-feats-original-failed-v1.json',
 'reports/native-creation-school-original-v1.json',
 'scripts/seal-native-creation-school.ps1',
 'tests/run-native-creation-school-state-tests.ps1',
 'tests/run-native-creation-school-view-tests.ps1',
 'tests/run-native-creation-school-binding-tests.ps1',
 'tests/run-native-creation-feat-binding-tests.ps1',
 'tests/run-native-creation-feat-adapter-tests.ps1'
)
foreach($file in $schoolFiles){Add-SchoolEntry (Join-Path $schoolProject $file) ('evidence/'+$file)}
foreach($file in @('inspect-native-creation-post-feats.py','inspect-native-creation-school.py')){Add-SchoolEntry (Join-Path (Split-Path -Parent $schoolProject) ('scripts/'+$file)) ('evidence/workspace-scripts/'+$file)}
$schoolBefore=Join-Path $schoolProject '.cache/school-checkpoints/20261103-001537-before'
foreach($file in @('native_creation.gd','native_creation_frontend.gd','creation_rules.gd')){Add-SchoolEntry (Join-Path $schoolBefore $file) ('dirty-before/'+$file)}
# Preserve the late backup exactly as captured, while identifying its chronology.
# It already contained the newly authored slot helper. The prior accepted copy
# supplies the real pre-helper version; do not relabel the late file as before.
Add-SchoolEntry (Join-Path $schoolBefore 'creation_feat_snapshot.gd') 'chronology/captured-after-slot-helper/creation_feat_snapshot.gd'
Add-SchoolEntry (Join-Path $schoolProject '.cache/feat-binding-tests/20261102-234154-565a7578/project/systems/native_data/creation_feat_snapshot.gd') 'dirty-before/creation_feat_snapshot.gd'
$schoolManifest=[ordered]@{
 schema=1;createdAtUtc=[DateTime]::UtcNow.ToString('o');cases=$schoolAccepted
 scope='Exact accepted copied source closures, original static/CPU evidence and dirty-before chronology. No original pixels, public/live server validation, full creator, level-up or authoritative character upload acceptance. Later concurrent-agent edits are outside this sealed acceptance.'
 beforeChronology='Three dirty files were captured before the School hooks. The captured Snapshot file already contained the new slot helper and is retained under chronology/. The exact earlier accepted Feats-v6 Snapshot supplies dirty-before/creation_feat_snapshot.gd.'
 entries=@($schoolEntries|ForEach-Object{[ordered]@{path=$_.entry;sha256=$_.sha256}})
}
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($schoolOutput))|Out-Null
$schoolZip=[IO.Compression.ZipFile]::Open($schoolOutput,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($input in $schoolEntries){
  if((Get-FileHash -LiteralPath $input.source -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw ('Input changed before archiving: '+$input.entry)}
  [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($schoolZip,$input.source,$input.entry,[IO.Compression.CompressionLevel]::SmallestSize)|Out-Null
 }
 $entry=$schoolZip.CreateEntry('manifest.json',[IO.Compression.CompressionLevel]::SmallestSize)
 $writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false))
 try{$writer.Write(($schoolManifest|ConvertTo-Json -Depth 12)+[Environment]::NewLine)}finally{$writer.Dispose()}
}finally{$schoolZip.Dispose()}
$schoolVerify=[IO.Compression.ZipFile]::OpenRead($schoolOutput)
try{
 if($schoolVerify.Entries.Count-ne$schoolEntries.Count+1){throw 'Archive entry count mismatch'}
 foreach($input in $schoolEntries){
  $entry=$schoolVerify.GetEntry($input.entry);if($null-eq$entry){throw ('Missing archive entry: '+$input.entry)}
  $stream=$entry.Open()
  try{$digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()}finally{$stream.Dispose()}
  if($digest-ne$input.sha256){throw ('Archive digest mismatch: '+$input.entry)}
 }
}finally{$schoolVerify.Dispose()}
$schoolPacket=[ordered]@{
 success=$true;createdAtUtc=[DateTime]::UtcNow.ToString('o');archive=$schoolOutput
 sha256=(Get-FileHash -LiteralPath $schoolOutput -Algorithm SHA256).Hash.ToLowerInvariant()
 bytes=(Get-Item -LiteralPath $schoolOutput).Length;entries=$schoolEntries.Count+1
 verifiedContentEntries=$schoolEntries.Count;cases=$schoolAccepted
 beforeChronology=$schoolManifest.beforeChronology;scope=$schoolManifest.scope
}
[IO.File]::WriteAllText($schoolReceipt,($schoolPacket|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
[pscustomobject]$schoolPacket|Select-Object success,archive,sha256,bytes,entries,verifiedContentEntries|ConvertTo-Json -Compress
