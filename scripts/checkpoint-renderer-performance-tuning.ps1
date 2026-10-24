param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=@(
 'src/main.js',
 'src/renderer_shadow_budget.js',
 'src/renderer_point_shadow_cache.js',
 'src/renderer_shadow_traversal.js',
 'src/renderer_light_loops.js',
 'src/renderer_performance_view.js',
 'test/renderer-shadow-budget.test.js',
 'test/renderer-point-shadow-cache.test.js',
 'test/renderer-shadow-traversal.test.js',
 'scripts/renderer-shadow-cache-fixture.html',
 'scripts/renderer-shadow-cache-fixture.mjs',
 'scripts/smoke-renderer-shadow-cache.cjs',
 'scripts/renderer-light-loops-fixture.html',
 'scripts/renderer-light-loops-fixture.mjs',
 'scripts/smoke-renderer-light-loops.cjs',
 'scripts/audit-renderer-fullscreen-checkpoint.mjs',
 'scripts/checkpoint-renderer-performance-tuning.ps1',
 'evidence/renderer-native-performance.md',
 'CASTING_RESUME_NOTE.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'backups/animations/renderer-material-scan-benchmark-v1.json',
 'backups/animations/renderer-native-performance-focused-v2.txt',
 'backups/animations/renderer-shadow-cache-focused-v3.txt',
 'backups/animations/renderer-native-performance-build-v2.txt',
 'backups/animations/renderer-light-loops-gpu-v1.json',
 'backups/animations/renderer-light-loops-gpu-v2.json',
 'backups/animations/renderer-shadow-cache-gpu-v1.json',
 'backups/animations/renderer-shadow-cache-gpu-v1.png',
 'backups/animations/network-performance-panel-proof-v160.json',
 'backups/animations/rea-performance-session-current.json',
 'backups/animations/rea-performance-nearest-lights-current.json',
 'backups/animations/rea-performance-draw-bucket-current.json',
 'backups/animations/rea-performance-object-lights-current.json',
 'backups/animations/rea-performance-shadow-procedures-current.json',
 'backups/animations/rea-performance-shadow-lights-current.json',
 'backups/animations/rea-performance-shadow-config-current.json',
 'backups/animations/rea-performance-shadow-render-current.json'
)
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip','multiplayer-effect-sound-20261019-v2.zip','multiplayer-initiative-20261019-v2.zip','multiplayer-action-queue-20261019-v2.zip','multiplayer-projectile-audio-20261019-v2.zip','multiplayer-creature-voice-20261019-v2.zip','multiplayer-weapon-sound-20261019-v2.zip','multiplayer-parry-visual-20261019-v1.zip','multiplayer-blood-visual-20261019-v2.zip','multiplayer-fullscreen-renderer-20261019-v1.zip','multiplayer-fullscreen-renderer-20261019-v2.zip','multiplayer-performance-panel-20261019-v1.zip')
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
