param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/network_initiative_feedback.js',
 'src/network_game_messages.js',
 'src/network_frontend.js',
 'src/network_feedback_view.js',
 'src/main.js',
 'test/network-initiative-feedback.test.js',
 'scripts/inspect-native-initiative-wire.py',
 'scripts/inspect-native-initiative-client.py',
 'scripts/inspect-native-camera-disassembly.py',
 'scripts/network-hud-fixture.mjs',
 'scripts/smoke-network-hud.cjs',
 'scripts/checkpoint-initiative.ps1',
 'scripts/audit-initiative-checkpoint.py',
 'evidence/multiplayer-initiative.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'CASTING_RESUME_NOTE.md',
 'backups/animations/native-initiative-branch-v1.json',
 'backups/animations/native-initiative-server-dispatch-v1.txt',
 'backups/animations/native-initiative-server-branch-v1.txt',
 'backups/animations/native-network-initiative-wire.json',
 'backups/animations/native-client-initiative-observations.json',
 'backups/animations/native-initiative-wire-oracle-v1.txt',
 'backups/animations/native-initiative-client-oracle-v1.txt',
 'backups/animations/rea-cc14-message-names.json',
 'backups/animations/rea-initiative-caller-names.json',
 'backups/animations/rea-initiative-resolve-owner.json',
 'backups/animations/rea-initiative-resolve-callers.json',
 'backups/animations/network-initiative-focused-v1.txt',
 'backups/animations/network-initiative-regression-v2.txt',
 'backups/animations/network-initiative-build-v1.txt',
 'backups/animations/network-initiative-ui-v1.txt',
 'backups/animations/network-initiative-replay-v1.json',
 'backups/animations/network-initiative-entry-v1.png',
 'backups/animations/network-initiative-hud-prepared-v1.png',
 'backups/animations/network-initiative-hud-spontaneous-v1.png'
)){$paths.Add($relative)}
if($IncludeLive){foreach($relative in @(
 'scripts/verify-network-initiative.mjs',
 'scripts/verify-network-reactive-spell.mjs',
 'backups/animations/local-network-effect-sound-v142.json',
 'backups/animations/local-network-initiative-v143.json',
 'backups/animations/local-network-initiative-v144.json',
 'backups/animations/network-initiative-before-attack-v143.json',
 'backups/animations/network-initiative-combat-v143.json',
 'backups/animations/network-initiative-hostile-v143.json',
 'backups/animations/network-initiative-current-v143.json',
 'backups/animations/network-initiative-current-v145.json',
 'backups/animations/network-initiative-ready-v143.png',
 'backups/animations/network-initiative-combat-v143.png',
 'backups/animations/network-initiative-hostile-v143.png',
 'backups/animations/network-initiative-ready-v145.png',
 'backups/animations/network-initiative-reactive-v144.json',
 'backups/animations/network-initiative-reactive-final-v144.json',
 'backups/animations/network-initiative-acceptance-v1.json',
 'backups/animations/network-initiative-reactive-acceptance-v1.json',
 'backups/animations/rea-initiative-missing-sound-demand.json'
)){$paths.Add($relative)}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip','multiplayer-effect-sound-20261019-v2.zip')
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
