$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$destination=Join-Path $workspace 'backups/multiplayer-attack-feedback-live-20261019-v1.zip'
if(Test-Path -LiteralPath $destination){throw 'Live checkpoint already exists'}
$paths=@(
 'scripts/probe-network-renderer.cjs','scripts/audit-attack-feedback-checkpoint.py',
 'scripts/checkpoint-attack-feedback-live.ps1','scripts/audit-attack-feedback-live-checkpoint.py',
 'test/network-attack-feedback.test.js','evidence/multiplayer-attack-feedback.md',
 'evidence/multiplayer-damage-feedback.md','REPLACEMENT_CLIENT_ROADMAP.md',
 'backups/animations/local-network-attack-feedback-v117.json',
 'backups/animations/local-network-attack-feedback-v118.json',
 'backups/animations/local-network-attack-feedback-v119.json',
 'backups/animations/network-attack-feedback-captured-v119.json',
 'backups/animations/network-attack-feedback-positive-damage-v119.json',
 'backups/animations/network-attack-feedback-melee-v119.json',
 'backups/animations/network-attack-feedback-acceptance-v1.json',
 'backups/animations/network-attack-feedback-focused-v2.txt',
 'backups/animations/network-attack-feedback-scope-audit-v1.txt',
 'backups/animations/network-attack-feedback-checkpoint-verified-v1.json',
 'backups/animations/network-attack-feedback-floating-v119.png',
 'backups/animations/network-attack-feedback-melee-v119.png',
 'backups/animations/network-attack-feedback-positive-damage-v119.png',
 'backups/animations/network-attack-feedback-area-v117.png',
 'backups/animations/network-attack-feedback-final-v117.png',
 'backups/animations/network-attack-feedback-final-v118.png',
 'backups/animations/network-attack-feedback-final-v119.png'
)
$manifest=[Collections.Generic.List[object]]::new()
Add-Type -AssemblyName System.IO.Compression
$stream=[IO.File]::Open($destination,[IO.FileMode]::CreateNew)
$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($relative in $paths){
  $absolute=[IO.Path]::GetFullPath((Join-Path $workspace $relative))
  if(-not $absolute.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Live checkpoint source escaped workspace'}
  $snapshot=[IO.File]::ReadAllBytes($absolute);$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($snapshot))
  $entry=$zip.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal);$output=$entry.Open()
  try{$output.Write($snapshot,0,$snapshot.Length)}finally{$output.Dispose()}
  $manifest.Add([ordered]@{path=$relative;bytes=$snapshot.Length;sha256=$hash})
 }
 $entry=$zip.CreateEntry('checkpoint-manifest.json');$writer=[IO.StreamWriter]::new($entry.Open());try{$writer.Write(($manifest|ConvertTo-Json -Depth 4))}finally{$writer.Dispose()}
 $base=Join-Path $workspace 'backups/multiplayer-attack-feedback-20261019-v1.zip'
 $chain=[ordered]@{kind='incremental';baseArchive='multiplayer-attack-feedback-20261019-v1.zip';baseSha256=(Get-FileHash -LiteralPath $base -Algorithm SHA256).Hash;restore='Extract the base archive, then overlay these updated source/evidence files. Native game assets remain external read-only inputs.'}
 $entry=$zip.CreateEntry('checkpoint-chain.json');$writer=[IO.StreamWriter]::new($entry.Open());try{$writer.Write(($chain|ConvertTo-Json -Depth 4))}finally{$writer.Dispose()}
}finally{$zip.Dispose();$stream.Dispose()}
$verify=[IO.Compression.ZipFile]::OpenRead($destination)
try{
 if($verify.Entries.Count -ne $paths.Count+2){throw 'Live checkpoint entry mismatch'}
 foreach($record in $manifest){$entry=$verify.GetEntry($record.path);if(-not $entry -or $entry.Length -ne $record.bytes){throw ('Live checkpoint length mismatch: '+$record.path)};$input=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{$actual=[Convert]::ToHexString($sha.ComputeHash($input))}finally{$input.Dispose();$sha.Dispose()};if($actual -ne $record.sha256){throw ('Live checkpoint hash mismatch: '+$record.path)}}
}finally{$verify.Dispose()}
[ordered]@{path=$destination;files=$paths.Count;bytes=(Get-Item -LiteralPath $destination).Length}|ConvertTo-Json -Compress
