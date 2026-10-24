param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/client_attack_sound.js',
 'src/native_delayed_sound.js',
 'src/native_audio.js',
 'src/game_audio.js',
 'src/network_combat_presentation.js',
 'src/network_scene.js',
 'test/client-attack-sound-native.test.js',
 'test/native-delayed-sound.test.js',
 'test/network-audio-native.test.js',
 'scripts/inspect-native-client-attack-sound.py',
 'scripts/inspect-native-sound-delay.py',
 'scripts/network-weapon-sound-fixture.html',
 'scripts/network-weapon-sound-fixture.mjs',
 'scripts/smoke-network-weapon-sound.cjs',
 'scripts/checkpoint-weapon-sound.ps1',
 'scripts/audit-weapon-sound-checkpoint.py',
 'evidence/multiplayer-weapon-sounds.md',
 'CASTING_RESUME_NOTE.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'backups/animations/rea-combat-sound-owner-current.json',
 'backups/animations/rea-client-creature-constructor-cast-fields.json',
 'backups/animations/scheduler-baseitems-loader-asm.txt',
 'backups/animations/client-attack-sound-native-tests-v1.txt',
 'backups/animations/native-client-attack-sound-observations.json',
 'backups/animations/native-client-attack-sound-oracle-v1.txt',
 'backups/animations/native-sound-delay-observations.json',
 'backups/animations/native-sound-delay-oracle-v1.txt',
 'backups/animations/network-weapon-sound-ui-stderr-v1.txt',
 'backups/animations/network-weapon-sound-ui-v1.json',
 'backups/animations/network-weapon-sound-ui-v1.png',
 'backups/animations/network-weapon-sound-ui-v1.txt',
 'backups/animations/rea-weapon-audio-listener-orientation-current.json',
 'backups/animations/rea-weapon-audio-listener-position-current.json',
 'backups/animations/rea-weapon-audio-listener-procedures-current.json',
 'backups/animations/rea-weapon-audio-source-start-current.json',
 'backups/animations/rea-weapon-audio-source-start-procedures-current.json',
 'backups/animations/rea-weapon-baseitem-loader-current.json',
 'backups/animations/rea-weapon-sound-delay-procedures-current.json',
 'backups/animations/rea-weapon-sound-delay-set-current.json',
 'backups/animations/rea-weapon-sound-delayed-list-current.json',
 'backups/animations/rea-weapon-sound-int-string-current.json',
 'backups/animations/rea-weapon-sound-internal-oneshot-body-current.json',
 'backups/animations/rea-weapon-sound-internal-oneshot-current.json',
 'backups/animations/rea-weapon-sound-item-active-fields-current.json',
 'backups/animations/rea-weapon-sound-oneshot-forward-current.json',
 'backups/animations/rea-weapon-sound-oneshot-owner-current.json',
 'backups/animations/rea-weapon-sound-render-current.json',
 'backups/animations/weapon-sound-build-v1.txt',
 'backups/animations/weapon-sound-focused-v1.txt',
 'backups/animations/weapon-sound-regression-v1.txt'
)){$paths.Add($relative)}
if($IncludeLive){foreach($relative in @(
 'scripts/probe-installed-combat-events.mjs',
 'scripts/verify-network-weapon-sound.mjs',
 'backups/animations/installed-combat-events-v1.json',
 'backups/animations/installed-combat-events-v1.txt',
 'backups/animations/weapon-sound-regression-v2.txt',
 'backups/animations/network-weapon-sound-checkpoint-v1.txt',
 'backups/animations/network-weapon-sound-scope-audit-v1.txt',
 'backups/animations/local-network-creature-voice-v151.json',
 'backups/animations/local-network-weapon-sound-v152.json',
 'backups/animations/network-weapon-sound-ready-v152.png',
 'backups/animations/network-weapon-sound-combat-v152.png',
 'backups/animations/network-weapon-sound-settled-v152.png',
 'backups/animations/network-weapon-sound-attacked-v152.json',
 'backups/animations/network-weapon-sound-combat-v152.json',
 'backups/animations/network-weapon-sound-settled-v152.json',
 'backups/animations/network-weapon-sound-current-v153.json',
 'backups/animations/network-weapon-sound-ready-v153.png',
 'backups/animations/network-weapon-sound-acceptance-v1.json',
 'backups/animations/network-weapon-sound-live-verification-v1.txt'
)){$paths.Add($relative)}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip','multiplayer-effect-sound-20261019-v2.zip','multiplayer-initiative-20261019-v2.zip','multiplayer-action-queue-20261019-v2.zip','multiplayer-projectile-audio-20261019-v2.zip','multiplayer-creature-voice-20261019-v2.zip')
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
