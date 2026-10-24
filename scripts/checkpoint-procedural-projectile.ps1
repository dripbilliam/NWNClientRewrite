param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip')
if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/visual_type10.js','src/client_projectile_presentation.js','src/network_projectile_presentation.js',
 'src/network_visual_presentation.js','src/visual_scene_runtime.js','src/main.js',
 'test/visual-type10-native.test.js','test/visual-type10-presentation.test.js',
 'scripts/inspect-native-visual-type10.py','scripts/probe-network-renderer.cjs',
 'scripts/network-procedural-fixture.html','scripts/network-procedural-fixture.mjs',
 'scripts/smoke-network-procedural.cjs','scripts/checkpoint-procedural-projectile.ps1',
 'scripts/audit-procedural-projectile-checkpoint.py','evidence/multiplayer-procedural-projectiles.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'backups/animations/native-visual-type10-observations.json',
 'backups/animations/native-visual-type10-oracle-v2.txt',
 'backups/animations/network-procedural-projectile-captured-v119.json',
 'backups/animations/network-procedural-projectile-replay-v1.json',
 'backups/animations/network-procedural-projectile-peak-v1.png',
 'backups/animations/network-procedural-projectile-ui-v2.txt',
 'backups/animations/network-procedural-projectile-ui-v2-stderr.txt',
 'backups/animations/network-procedural-projectile-focused-v2.txt',
 'backups/animations/network-procedural-projectile-build-v2.txt',
 'backups/animations/installed-procedural-linked-regression-v1.json',
 'backups/animations/rea-visual-type10-start.json',
 'backups/animations/rea-visual-type10-flight-time.json',
 'backups/animations/rea-visual-projectile-spell-config.json',
 'backups/animations/rea-visual-projectile-set-time.json'
)){$paths.Add($relative)}
if($IncludeLive){foreach($relative in @(
 'backups/animations/local-network-attack-feedback-v120.json',
 'backups/animations/local-network-procedural-projectile-v121.json',
 'backups/animations/local-network-procedural-projectile-v122.json',
 'backups/animations/local-network-procedural-projectile-v124.json',
 'backups/animations/network-procedural-projectile-player-observation-v124.json',
 'backups/animations/network-procedural-projectile-captured-v124.json',
 'backups/animations/network-procedural-projectile-acceptance-v1.json',
 'backups/animations/network-procedural-projectile-live-v124.png',
 'backups/animations/network-procedural-projectile-final-v124.png',
 'backups/animations/network-procedural-projectile-focused-v3.txt',
 'backups/animations/network-procedural-projectile-live-v121.png',
 'backups/animations/network-procedural-projectile-final-v121.png',
 'backups/animations/network-procedural-projectile-network-regression-v1.txt'
)){if(Test-Path -LiteralPath (Join-Path $workspace $relative)){$paths.Add($relative)}}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip')
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
