param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=@(
 'src/main.js',
 'src/renderer_light_slots.js',
 'src/renderer_shadow_budget.js',
 'src/renderer_shadow_traversal.js',
 'test/renderer-light-slots.test.js',
 'test/renderer-shadow-traversal.test.js',
 'scripts/probe-network-renderer.cjs',
 'scripts/renderer-shadow-traversal-fixture.html',
 'scripts/renderer-shadow-traversal-fixture.mjs',
 'scripts/smoke-renderer-shadow-traversal.cjs',
 'scripts/checkpoint-renderer-fullscreen.ps1',
 'scripts/audit-renderer-fullscreen-checkpoint.py',
 'evidence/renderer-fullscreen-performance.md',
 'CASTING_RESUME_NOTE.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'backups/animations/renderer-fullscreen-focused-v1.txt',
 'backups/animations/renderer-fullscreen-focused-v3.txt',
 'backups/animations/renderer-fullscreen-build-v4.txt',
 'backups/animations/renderer-shadow-traversal-gpu-v1.json',
 'backups/animations/renderer-shadow-traversal-gpu-v1.png',
 'backups/animations/renderer-shadow-traversal-gpu-v2-stderr.txt',
 'backups/animations/renderer-shadow-traversal-gpu-v3.json',
 'backups/animations/renderer-shadow-traversal-gpu-v3.png',
 'backups/animations/network-fullscreen-windowed-v156.cpuprofile',
 'backups/animations/network-fullscreen-full-v156.cpuprofile',
 'backups/animations/network-fullscreen-full-v157.cpuprofile',
 'backups/animations/network-fullscreen-windowed-baseline-v156.json',
 'backups/animations/network-fullscreen-full-baseline-v156.json',
 'backups/animations/network-fullscreen-full-profiled-v156.json',
 'backups/animations/network-fullscreen-restored-v156.json',
 'backups/animations/network-fullscreen-windowed-optimized-v157.json',
 'backups/animations/network-fullscreen-optimized-v157.json',
 'backups/animations/network-fullscreen-rotation-before-v157.json',
 'backups/animations/network-fullscreen-rotation-final-v157.json',
 'index.html',
 'src/style.css',
 'src/network_scene.js',
 'src/renderer_light_loops.js',
 'test/network-scene-loading.test.js',
 'scripts/renderer-light-loops-fixture.html',
 'scripts/renderer-light-loops-fixture.mjs',
 'scripts/smoke-renderer-light-loops.cjs',
 'scripts/audit-renderer-fullscreen-checkpoint.mjs',
 'backups/animations/renderer-fullscreen-focused-v5.txt',
 'backups/animations/renderer-fullscreen-build-v6.txt',
 'backups/animations/network-scene-loading-focused-v1.txt',
 'backups/animations/network-scene-loading-focused-v2.txt',
 'backups/animations/renderer-debug-panel-focused-v1.txt',
 'backups/animations/renderer-debug-panel-build-v2.txt',
 'backups/animations/network-fullscreen-stall-events-v157.json',
 'backups/animations/network-fullscreen-before-rotation-v158.json',
 'backups/animations/network-fullscreen-after-rotation-v158.json',
 'backups/animations/network-fullscreen-current-v158.json',
 'backups/animations/network-fullscreen-current-v158.png',
 'backups/animations/local-network-blood-visual-v155.json',
 'backups/animations/local-network-fullscreen-v156.json',
 'backups/animations/local-network-fullscreen-v157.json',
 'backups/animations/network-fullscreen-windowed-v156.png',
 'backups/animations/network-fullscreen-full-v156.png',
 'backups/animations/network-fullscreen-optimized-v157.png',
 'backups/animations/renderer-fullscreen-scope-audit-v1.txt'
)
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip','multiplayer-effect-sound-20261019-v2.zip','multiplayer-initiative-20261019-v2.zip','multiplayer-action-queue-20261019-v2.zip','multiplayer-projectile-audio-20261019-v2.zip','multiplayer-creature-voice-20261019-v2.zip','multiplayer-weapon-sound-20261019-v2.zip','multiplayer-parry-visual-20261019-v1.zip','multiplayer-blood-visual-20261019-v2.zip','multiplayer-fullscreen-renderer-20261019-v1.zip')
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
