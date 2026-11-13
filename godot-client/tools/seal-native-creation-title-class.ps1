[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repairProject=Split-Path -Parent $PSScriptRoot
$repairRoot=Split-Path -Parent $repairProject
$repairArchive=Join-Path $repairRoot 'backups/native-creation-title-class-after-v1.zip'
$repairReceipt=Join-Path $repairProject 'reports/native-creation-title-class-repairs-v1.json'
if((Test-Path -LiteralPath $repairArchive)-or(Test-Path -LiteralPath $repairReceipt)){throw 'Preserve the existing checkpoint'}
$repairCases=@(
 '.cache/creation-claimed-titles/native-creation-title-main-final-v2',
 '.cache/creation-class-order/native-creation-class-order-after-v2'
)
$repairFiles=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$repairChecks=0
foreach($relative in $repairCases){
 $directory=Join-Path $repairProject $relative
 $proof=Get-Content -LiteralPath (Join-Path $directory 'proof.json') -Raw|ConvertFrom-Json
 if(-not$proof.success-or-not$proof.cleanEngine-or$proof.changedInputs.Count){throw 'Only clean accepted snapshots can be sealed'}
 $repairChecks+=$proof.checks
 foreach($file in Get-ChildItem -LiteralPath $directory -File -Recurse){[void]$repairFiles.Add($file.FullName)}
}
foreach($relative in @('systems/native_data/creation_main_layout.gd','systems/native_data/creation_class_state.gd','NATIVE-CREATION-TITLE-CLASS-REPAIRS.md','reports/native-creation-main-title-source-v1.json','tools/seal-native-creation-title-class.ps1')){[void]$repairFiles.Add((Join-Path $repairProject $relative))}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $repairRoot 'backups/native-creation-title-class-before-20261103-205741') -File){[void]$repairFiles.Add($file.FullName)}
$repairEntries=@($repairFiles|Sort-Object|ForEach-Object{
 [ordered]@{path=[IO.Path]::GetRelativePath($repairRoot,$_).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $_).Length}
})
$repairManifest=[ordered]@{kind='integrated-creation-title-class-v1';checks=$repairChecks;cases=$repairCases;files=$repairEntries;scope='Bounded CG_MAIN Title and available-first active class chooser with actual native font/input tests; no server or live-client validation.'}
$repairZip=[IO.Compression.ZipFile]::Open($repairArchive,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($entry in $repairEntries){[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($repairZip,(Join-Path $repairRoot $entry.path),$entry.path,[IO.Compression.CompressionLevel]::Optimal)}
 $writer=[IO.StreamWriter]::new($repairZip.CreateEntry('manifest.json').Open());try{$writer.Write(($repairManifest|ConvertTo-Json -Depth 8))}finally{$writer.Dispose()}
}finally{$repairZip.Dispose()}
$repairZip=[IO.Compression.ZipFile]::OpenRead($repairArchive)
try{
 if($repairZip.Entries.Count-ne$repairEntries.Count+1){throw 'Archive entry count mismatch'}
 foreach($entry in $repairEntries){
  $stream=$repairZip.GetEntry($entry.path).Open();$sha=[Security.Cryptography.SHA256]::Create()
  try{$actual=[Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant()}finally{$stream.Dispose();$sha.Dispose()}
  if($actual-ne$entry.sha256-or(Get-FileHash -LiteralPath (Join-Path $repairRoot $entry.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$entry.sha256){throw ('Archive/current source mismatch: '+$entry.path)}
 }
}finally{$repairZip.Dispose()}
$repairResult=[ordered]@{success=$true;archive=[IO.Path]::GetRelativePath($repairRoot,$repairArchive).Replace('\','/');sha256=(Get-FileHash -LiteralPath $repairArchive -Algorithm SHA256).Hash.ToLowerInvariant();entries=$repairEntries.Count+1;bytes=(Get-Item -LiteralPath $repairArchive).Length;readbackVerified=$true;checks=$repairChecks;cases=$repairCases;scope=$repairManifest.scope}
[IO.File]::WriteAllText($repairReceipt,($repairResult|ConvertTo-Json -Depth 6)+[Environment]::NewLine)
$repairResult|ConvertTo-Json -Depth 6
