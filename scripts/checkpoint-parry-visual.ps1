param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/client_parry_visual.js',
 'src/network_parry_visual.js',
 'src/network_combat_presentation.js',
 'src/network_scene.js',
 'test/client-parry-visual-native.test.js',
 'test/network-parry-visual.test.js',
 'scripts/inspect-native-client-parry-visual.py',
 'scripts/inspect-native-parry-model-query.py',
 'scripts/network-parry-visual-fixture.html',
 'scripts/network-parry-visual-fixture.mjs',
 'scripts/smoke-network-parry-visual.cjs',
 'scripts/checkpoint-parry-visual.ps1',
 'scripts/audit-parry-visual-checkpoint.py',
 'evidence/multiplayer-parry-visuals.md',
 'CASTING_RESUME_NOTE.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'backups/animations/native-client-parry-visual-observations.json',
 'backups/animations/native-parry-model-query-observations.json',
 'backups/animations/network-parry-visual-ui-v1.txt',
 'backups/animations/network-parry-visual-ui-stderr-v1.txt',
 'backups/animations/network-parry-visual-ui-v2.txt',
 'backups/animations/network-parry-visual-ui-stderr-v2.txt',
 'backups/animations/network-parry-visual-ui-v3.json',
 'backups/animations/network-parry-visual-ui-v3.png',
 'backups/animations/network-parry-visual-ui-v3.txt',
 'backups/animations/network-parry-visual-ui-stderr-v3.txt',
 'backups/animations/parry-visual-build-v1.txt',
 'backups/animations/parry-visual-regression-v1.txt',
 'backups/animations/rea-combat-impact-effect-body-current.json',
 'backups/animations/rea-combat-impact-effect-rest-current.json',
 'backups/animations/rea-combat-impact-effect-callees-current.json',
 'backups/animations/rea-combat-render-handle-current.json',
 'backups/animations/rea-combat-context-body-constructor-current.json',
 'backups/animations/rea-combat-context-parts-getter-thunk-current.json',
 'backups/animations/rea-combat-context-parts-load-model-current.json',
 'backups/animations/rea-combat-context-parts-set-model-current.json',
 'backups/animations/rea-combat-context-simple-model-query-current.json',
 'backups/animations/rea-combat-context-head-get-model-current.json',
 'backups/animations/rea-combat-context-special-model-current.json',
 'backups/animations/client-creature-update-cast-fields-asm-v1.txt',
 'backups/animations/rea-placed-sound-source-position.json'
)){$paths.Add($relative)}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip','multiplayer-effect-sound-20261019-v2.zip','multiplayer-initiative-20261019-v2.zip','multiplayer-action-queue-20261019-v2.zip','multiplayer-projectile-audio-20261019-v2.zip','multiplayer-creature-voice-20261019-v2.zip','multiplayer-weapon-sound-20261019-v2.zip')
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
