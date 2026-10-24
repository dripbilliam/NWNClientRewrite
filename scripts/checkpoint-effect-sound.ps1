param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/native_effect_sound.js',
 'src/game_audio.js',
 'src/native_audio.js',
 'src/visual_scene_runtime.js',
 'src/network_scene.js',
 'src/network_visual_presentation.js',
 'src/network_area_visual_presentation.js',
 'src/main.js',
 'test/effect-sound-presentation.test.js',
 'test/visual-scene-runtime.test.js',
 'test/area-visual-native.test.js',
 'test/visual-phase-control-native.test.js',
 'test/visual-phase-update-native.test.js',
 'scripts/network-effect-sound-fixture.html',
 'scripts/network-effect-sound-fixture.mjs',
 'scripts/smoke-network-effect-sound.cjs',
 'scripts/checkpoint-effect-sound.ps1',
 'scripts/audit-effect-sound-checkpoint.py',
 'evidence/multiplayer-effect-sounds.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'CASTING_RESUME_NOTE.md',
 'backups/animations/network-effect-sound-focused-v1.txt',
 'backups/animations/network-effect-sound-regression-v1.txt',
 'backups/animations/network-effect-sound-build-v1.txt',
 'backups/animations/network-effect-sound-ui-v1.json',
 'backups/animations/network-effect-sound-ui-v1.png',
 'backups/animations/network-effect-sound-ui-v1.txt',
 'backups/animations/network-effect-sound-ui-v2.txt',
 'backups/animations/rea-duration-source-ref-ctor.json',
 'backups/animations/rea-duration-source-internal-ctor.json',
 'backups/animations/rea-duration-source-wrapper-play.json',
 'backups/animations/rea-duration-source-move-wrapper.json',
 'backups/animations/rea-duration-source-start-voice.json',
 'backups/animations/rea-duration-visual-start.json',
 'backups/animations/rea-duration-visual-update-owner.json',
 'backups/animations/rea-network-area-visual-start.json',
 'backups/animations/native-visual-phase-control-observations.json',
 'backups/animations/native-visual-phase-update-observations.json',
 'backups/animations/native-area-visual-observations.json'
)){$paths.Add($relative)}
if($IncludeLive){foreach($relative in @(
 'scripts/verify-network-effect-sound.mjs',
 'backups/animations/local-network-placed-sound-v140.json',
 'backups/animations/local-network-effect-sound-v141.json',
 'backups/animations/network-effect-sound-start-v141.json',
 'backups/animations/network-effect-sound-moved-v141.json',
 'backups/animations/network-effect-sound-current-v141.json',
 'backups/animations/network-effect-sound-current-v142.json',
 'backups/animations/network-effect-sound-ready-v141.png',
 'backups/animations/network-effect-sound-cast-v141.png',
 'backups/animations/network-effect-sound-ready-v142.png',
 'backups/animations/network-effect-sound-wire-v141.json',
 'backups/animations/network-effect-sound-acceptance-v1.json'
)){$paths.Add($relative)}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip')
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
