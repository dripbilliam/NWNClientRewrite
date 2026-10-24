param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/network_action_queue.js',
 'src/network_action_queue_view.js',
 'src/network_player_state.js',
 'src/network_player_state_store.js',
 'src/network_player_requests.js',
 'src/network_frontend.js',
 'src/network_quickbar_view.js',
 'src/main.js',
 'src/style.css',
 'electron/network_game_session.mjs',
 'electron/network_ipc.cjs',
 'electron/preload.cjs',
 'test/network-action-queue.test.js',
 'test/network-game-session.test.js',
 'test/network-ipc.test.js',
 'scripts/inspect-native-action-cancel.py',
 'scripts/inspect-native-network-interactions.py',
 'scripts/network-hud-fixture.mjs',
 'scripts/smoke-network-hud.cjs',
 'scripts/probe-network-renderer.cjs',
 'scripts/checkpoint-action-queue.ps1',
 'scripts/audit-action-queue-checkpoint.py',
 'evidence/multiplayer-action-queue.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'CASTING_RESUME_NOTE.md',
 'backups/animations/native-network-action-cancel.json',
 'backups/animations/native-network-action-cancel-oracle-v1.txt',
 'backups/animations/rea-queue-client-add.json',
 'backups/animations/rea-queue-client-retarget.json',
 'backups/animations/rea-queue-client-remove.json',
 'backups/animations/rea-queue-client-click-cancel.json',
 'backups/animations/rea-queue-cancel-client-sender.json',
 'backups/animations/rea-queue-cancel-client-callers.json',
 'backups/animations/rea-cancel-creature-owner.json',
 'backups/animations/rea-cancel-input-server-tail.json',
 'backups/animations/rea-network-client-player-state-view.json',
 'backups/animations/native-cancel-input-call-v1.txt',
 'backups/animations/native-cancel-input-branch-v1.txt',
 'backups/animations/network-action-queue-focused-v1.txt',
 'backups/animations/network-action-queue-focused-v2.txt',
 'backups/animations/network-action-queue-focused-v3.txt',
 'backups/animations/network-action-queue-regression-v1.txt',
 'backups/animations/network-action-queue-build-v1.txt',
 'backups/animations/network-action-queue-build-v2.txt',
 'backups/animations/network-action-queue-ui-v1.txt',
 'backups/animations/network-action-queue-ui-v2.txt',
 'backups/animations/network-action-queue-ui-v3.txt',
 'backups/animations/network-action-queue-replay-v1.json',
 'backups/animations/network-action-queue-widgets-v1.png',
 'backups/animations/network-action-queue-entry-v1.png',
 'backups/animations/network-action-queue-hud-prepared-v1.png',
 'backups/animations/network-action-queue-hud-spontaneous-v1.png'
)){$paths.Add($relative)}
if($IncludeLive){foreach($relative in @(
 'scripts/verify-network-action-queue.mjs',
 'backups/animations/local-network-initiative-v145.json',
 'backups/animations/local-network-action-queue-v146.json',
 'backups/animations/network-action-queue-first-cancel-v146.json',
 'backups/animations/network-action-queue-current-v146.json',
 'backups/animations/network-action-queue-casting-v146.json',
 'backups/animations/network-action-queue-cancel-v146.png',
 'backups/animations/network-action-queue-precast-v146.png',
 'backups/animations/network-action-queue-current-v147.json',
 'backups/animations/network-action-queue-ready-v147.png',
 'backups/animations/network-action-queue-acceptance-v1.json',
 'backups/animations/rea-attack-approach-ai-owner.json',
 'backups/animations/rea-attack-approach-server-owner.json',
 'backups/animations/rea-attack-approach-player-click.json',
 'backups/animations/rea-attack-approach-world-click.json',
 'backups/animations/rea-attack-approach-creature-click.json',
 'backups/animations/rea-attack-approach-sender-callers.json'
)){$paths.Add($relative)}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip','multiplayer-effect-sound-20261019-v2.zip','multiplayer-initiative-20261019-v2.zip')
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
