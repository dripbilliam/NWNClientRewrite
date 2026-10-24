param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=@(
 'src/main.js',
 'src/renderer_light_slots.js',
 'src/renderer_light_selection.js',
 'src/renderer_hierarchy.js',
 'src/model_particles.js',
 'src/camera_keyhole_shader.js',
 'src/renderer_model_preparation.js',
 'test/renderer-light-slots.test.js',
 'test/renderer-hierarchy.test.js',
 'test/model-particles.test.js',
 'test/camera-keyhole-native.test.js',
 'test/renderer-model-preparation.test.js',
 'scripts/renderer-frame-matrices-fixture.html',
 'scripts/renderer-frame-matrices-fixture.mjs',
 'scripts/smoke-renderer-frame-matrices.cjs',
 'scripts/checkpoint-renderer-frame-scheduling.ps1',
 'scripts/audit-renderer-fullscreen-checkpoint.mjs',
 'evidence/renderer-frame-scheduling.md',
 'CASTING_RESUME_NOTE.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'backups/animations/renderer-frame-matrices-focused-v1.txt',
 'backups/animations/renderer-frame-matrices-gpu-v1.json',
 'backups/animations/renderer-parallel-preparation-focused-v1.txt',
 'backups/animations/renderer-hierarchy-parallel-build-v1.txt',
 'backups/animations/network-frame-matrices-before-v163.json',
 'backups/animations/network-frame-matrices-proof-v164.json',
 'backups/animations/network-frame-matrices-v164.cpuprofile',
 'backups/animations/network-frame-matrices-v164.png',
 'backups/animations/renderer-model-preparation-gpu-v5.json',
 'backups/animations/renderer-model-preparation-gpu-v5.png',
 'backups/animations/rea-performance-max-light-initial-data-current.json',
 'backups/animations/rea-performance-max-light-config-record-current.json',
 'backups/animations/rea-performance-control-light-procedures-current.json',
 'backups/animations/rea-performance-control-lights-fade-current.json'
)
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip','multiplayer-effect-sound-20261019-v2.zip','multiplayer-initiative-20261019-v2.zip','multiplayer-action-queue-20261019-v2.zip','multiplayer-projectile-audio-20261019-v2.zip','multiplayer-creature-voice-20261019-v2.zip','multiplayer-weapon-sound-20261019-v2.zip','multiplayer-parry-visual-20261019-v1.zip','multiplayer-blood-visual-20261019-v2.zip','multiplayer-fullscreen-renderer-20261019-v1.zip','multiplayer-fullscreen-renderer-20261019-v2.zip','multiplayer-performance-panel-20261019-v1.zip','multiplayer-performance-tuning-20261019-v1.zip','multiplayer-performance-recovery-20261019-v1.zip')
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
