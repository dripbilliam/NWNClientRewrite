param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/client_projectile_presentation.js',
 'src/network_projectile_presentation.js',
 'test/client-projectile-presentation.test.js',
 'scripts/probe-network-renderer.cjs',
 'scripts/network-projectile-audio-fixture.html',
 'scripts/network-projectile-audio-fixture.mjs',
 'scripts/smoke-network-projectile-audio.cjs',
 'scripts/inspect-native-client-projectile-ai.py',
 'scripts/checkpoint-projectile-audio.ps1',
 'scripts/audit-projectile-audio-checkpoint.py',
 'evidence/multiplayer-projectile-audio.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'CASTING_RESUME_NOTE.md',
 'backups/animations/rea-client-projectile-update-body.json',
 'backups/animations/rea-linked-projectile-destructor-body.json',
 'backups/animations/rea-client-projectile-constructor-body.json',
 'backups/animations/native-client-projectile-ai-observations.json',
 'backups/animations/client-projectile-ai-native-v1.txt',
 'backups/animations/network-projectile-audio-focused-v1.txt',
 'backups/animations/network-projectile-audio-focused-v2.txt',
 'backups/animations/network-projectile-audio-regression-v1.txt',
 'backups/animations/network-projectile-audio-build-v1.txt',
 'backups/animations/network-projectile-audio-ui-v1.txt',
 'backups/animations/network-projectile-audio-ui-v1.json',
 'backups/animations/network-projectile-audio-ui-v1.png'
)){$paths.Add($relative)}
if($IncludeLive){foreach($relative in @(
 'scripts/verify-network-projectile-audio.mjs',
 'backups/animations/local-network-action-queue-v147.json',
 'backups/animations/local-network-projectile-audio-v148.json',
 'backups/animations/network-projectile-audio-cast-v148.json',
 'backups/animations/network-projectile-audio-ground-v148.png',
 'backups/animations/network-projectile-audio-aftercast-v148.png',
 'backups/animations/network-projectile-audio-current-v149.json',
 'backups/animations/network-projectile-audio-ready-v149.png',
 'backups/animations/network-projectile-audio-acceptance-v1.json',
 'backups/animations/network-projectile-audio-live-verification-v1.txt',
 'backups/animations/network-projectile-audio-checkpoint-v1.txt',
 'backups/animations/network-projectile-audio-scope-audit-v1.txt'
)){$paths.Add($relative)}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip','multiplayer-effect-sound-20261019-v2.zip','multiplayer-initiative-20261019-v2.zip','multiplayer-action-queue-20261019-v2.zip')
$chain=@($parents|ForEach-Object {[ordered]@{archive=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $workspace ('backups/'+$_)) -Algorithm SHA256).Hash}})
Add-Type -AssemblyName System.IO.Compression
$manifest=[Collections.Generic.List[object]]::new();$stream=[IO.File]::Open($destination,[IO.FileMode]::CreateNew);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($relative in $paths){$absolute=[IO.Path]::GetFullPath((Join-Path $workspace $relative));if(-not $absolute.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint source escaped workspace'};$snapshot=[IO.File]::ReadAllBytes($absolute);$entry=$zip.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal);$entryStream=$entry.Open();try{$entryStream.Write($snapshot,0,$snapshot.Length)}finally{$entryStream.Dispose()};$manifest.Add([ordered]@{path=$relative;bytes=$snapshot.Length;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($snapshot))})}
 foreach($metadata in @(@{name='checkpoint-manifest.json';value=@($manifest.ToArray())},@{name='checkpoint-chain.json';value=[ordered]@{kind='incremental';parents=$chain;restore='Extract parents in order, then overlay this checkpoint.'}})){$entry=$zip.CreateEntry($metadata.name);$writer=[IO.StreamWriter]::new($entry.Open());try{$writer.Write(($metadata.value|ConvertTo-Json -Depth 6))}finally{$writer.Dispose()}}
}finally{$zip.Dispose();$stream.Dispose()}
$verify=[IO.Compression.ZipFile]::OpenRead($destination)
try{if($verify.Entries.Count -ne $paths.Count+2){throw 'Checkpoint count mismatch'};foreach($record in $manifest){$entry=$verify.GetEntry($record.path);if(-not $entry -or $entry.Length -ne $record.bytes){throw ('Length mismatch: '+$record.path)};$entryStream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{$hash=[Convert]::ToHexString($sha.ComputeHash($entryStream))}finally{$entryStream.Dispose();$sha.Dispose()};if($hash -ne $record.sha256){throw ('Hash mismatch: '+$record.path)}}}finally{$verify.Dispose()}
[ordered]@{path=$destination;files=$paths.Count;bytes=(Get-Item -LiteralPath $destination).Length}|ConvertTo-Json -Compress
