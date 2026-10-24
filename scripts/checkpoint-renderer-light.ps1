param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip')
if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/renderer_light_slots.js',
 'src/main.js',
 'test/renderer-light-slots.test.js',
 'test/renderer-shadow-budget.test.js',
 'scripts/renderer-light-slots-fixture.html',
 'scripts/renderer-light-slots-fixture.mjs',
 'scripts/smoke-renderer-light-slots.cjs',
 'scripts/probe-network-renderer.cjs',
 'scripts/checkpoint-renderer-light.ps1',
 'scripts/audit-renderer-light-checkpoint.py',
 'evidence/renderer-light-capacity.md',
 'backups/animations/renderer-light-capacity-tests-v2.txt',
 'backups/animations/renderer-light-capacity-build-v1.txt',
 'backups/animations/renderer-light-capacity-build-v2.txt',
 'backups/animations/network-light-capacity-regression-v2.txt',
 'backups/animations/renderer-light-capacity-gpu-v2.json',
 'backups/animations/renderer-light-capacity-baseline-v124.json',
 'backups/animations/renderer-light-capacity-build-v4.txt',
 'backups/animations/network-light-capacity-entry-tests-v3.txt',
 'scripts/analyze-network-light-capacity.mjs',
 'backups/animations/renderer-light-capacity-build-v5.txt',
 'backups/animations/network-light-capacity-final-focused-v1.txt'
)){$paths.Add($relative)}
if($IncludeLive){foreach($relative in @('backups/animations/local-network-light-capacity-v125.json','backups/animations/local-network-light-capacity-v126.json','backups/animations/local-network-light-capacity-v127.json','backups/animations/network-light-capacity-observation-v126.json','backups/animations/network-light-capacity-observation-v127.json','backups/animations/network-light-capacity-player-proof-v126.json','backups/animations/network-light-capacity-acceptance-v1.json','backups/animations/network-light-capacity-live-v125.png','backups/animations/network-light-capacity-final-v125.png','backups/animations/network-light-capacity-live-v126.png','backups/animations/network-light-capacity-final-v126.png','backups/animations/network-light-capacity-final-v127.png','backups/animations/network-light-capacity-regression-v1.txt','REPLACEMENT_CLIENT_ROADMAP.md')){if(Test-Path -LiteralPath (Join-Path $workspace $relative)){$paths.Add($relative)}}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip')
$chain=@($parents|ForEach-Object {[ordered]@{archive=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $workspace ('backups/'+$_)) -Algorithm SHA256).Hash}})
Add-Type -AssemblyName System.IO.Compression
$manifest=[Collections.Generic.List[object]]::new();$stream=[IO.File]::Open($destination,[IO.FileMode]::CreateNew);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($relative in $paths){$absolute=[IO.Path]::GetFullPath((Join-Path $workspace $relative));if(-not $absolute.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint source escaped workspace'};$snapshot=[IO.File]::ReadAllBytes($absolute);$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($snapshot));$entry=$zip.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal);$entryStream=$entry.Open();try{$entryStream.Write($snapshot,0,$snapshot.Length)}finally{$entryStream.Dispose()};$manifest.Add([ordered]@{path=$relative;bytes=$snapshot.Length;sha256=$hash})}
 foreach($metadata in @(@{name='checkpoint-manifest.json';value=@($manifest.ToArray())},@{name='checkpoint-chain.json';value=[ordered]@{kind='incremental';parents=$chain;restore='Extract parents in order, then overlay this checkpoint.'}})){$entry=$zip.CreateEntry($metadata.name);$writer=[IO.StreamWriter]::new($entry.Open());try{$writer.Write(($metadata.value|ConvertTo-Json -Depth 6))}finally{$writer.Dispose()}}
}finally{$zip.Dispose();$stream.Dispose()}
$verify=[IO.Compression.ZipFile]::OpenRead($destination)
try{if($verify.Entries.Count -ne $paths.Count+2){throw 'Checkpoint count mismatch'};foreach($record in $manifest){$entry=$verify.GetEntry($record.path);if(-not $entry -or $entry.Length -ne $record.bytes){throw ('Length mismatch: '+$record.path)};$entryStream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{$hash=[Convert]::ToHexString($sha.ComputeHash($entryStream))}finally{$entryStream.Dispose();$sha.Dispose()};if($hash -ne $record.sha256){throw ('Hash mismatch: '+$record.path)}}}finally{$verify.Dispose()}
[ordered]@{path=$destination;files=$paths.Count;bytes=(Get-Item -LiteralPath $destination).Length}|ConvertTo-Json -Compress
