param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/client_blood_visual.js',
 'src/model_animation_query.js',
 'src/network_blood_visual.js',
 'src/network_combat_presentation.js',
 'src/network_scene.js',
 'src/network_panels.js',
 'src/main.js',
 'test/client-blood-visual-native.test.js',
 'test/network-blood-visual.test.js',
 'scripts/inspect-native-client-blood-visual.py',
 'scripts/inspect-native-blood-helpers.py',
 'scripts/locate-native-blood-settings.py',
 'scripts/network-blood-visual-fixture.html',
 'scripts/network-blood-visual-fixture.mjs',
 'scripts/smoke-network-blood-visual.cjs',
 'scripts/checkpoint-blood-visual.ps1',
 'scripts/audit-blood-visual-checkpoint.py',
 'evidence/multiplayer-blood-visuals.md',
 'CASTING_RESUME_NOTE.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'backups/animations/native-client-blood-visual-observations.json',
 'backups/animations/native-client-blood-visual-success-observations.json',
 'backups/animations/native-client-blood-visual-observations-invalid-v1.json',
 'backups/animations/native-blood-helper-observations.json',
 'backups/animations/native-blood-settings-candidates.json',
 'backups/animations/native-client-blood-visual-oracle-v2.txt',
 'backups/animations/blood-client-hp-mapping-v1.txt',
 'backups/animations/network-blood-visual-ui-v1.txt',
 'backups/animations/network-blood-visual-ui-stderr-v1.txt',
 'backups/animations/network-blood-visual-ui-v2.txt',
 'backups/animations/network-blood-visual-ui-stderr-v2.txt',
 'backups/animations/network-blood-visual-ui-v2.json',
 'backups/animations/network-blood-visual-ui-v2.png',
 'backups/animations/blood-visual-build-v1.txt',
 'backups/animations/blood-visual-build-v2.txt',
 'backups/animations/blood-visual-build-v3.txt',
 'backups/animations/blood-visual-regression-v1.txt',
 'backups/animations/blood-visual-regression-v2.txt',
 'backups/animations/blood-visual-regression-v3.txt',
 'backups/animations/rea-blood-acos-current.json',
 'backups/animations/rea-blood-axis-quaternion-current.json',
 'backups/animations/rea-blood-client-getter-current.json',
 'backups/animations/rea-blood-client-max-hp-current.json',
 'backups/animations/rea-blood-client-object-constructor-current.json',
 'backups/animations/rea-blood-client-procedures-current.json',
 'backups/animations/rea-blood-cross-current.json',
 'backups/animations/rea-blood-gore-init-current.json',
 'backups/animations/rea-blood-gore-init-owner-current.json',
 'backups/animations/rea-blood-gore-settings-current.json',
 'backups/animations/rea-blood-gore-ui-owner-current.json',
 'backups/animations/rea-blood-model-orientation-current.json',
 'backups/animations/rea-blood-model-play-info-current.json',
 'backups/animations/rea-blood-normalize-current.json',
 'backups/animations/rea-blood-play-info-procedures-current.json',
 'backups/animations/rea-blood-quaternion-multiply-current.json',
 'backups/animations/rea-blood-vector-normalize-current.json',
 'backups/animations/rea-blood-vector-scale-current.json',
 'backups/animations/rea-blood-violence-settings-current.json',
 'backups/animations/rea-blood-weapon-lookup-current.json'
)){$paths.Add($relative)}
if($IncludeLive){foreach($relative in @(
 'scripts/verify-network-blood-visual.mjs',
 'backups/animations/local-network-weapon-sound-v153.json',
 'backups/animations/local-network-blood-visual-v154.json',
 'backups/animations/network-blood-visual-encounter-v154.json',
 'backups/animations/network-blood-visual-combat-v154.json',
 'backups/animations/network-blood-visual-particles-v154.json',
 'backups/animations/network-blood-visual-postcombat-v154.json',
 'backups/animations/network-blood-visual-returned-v154.json',
 'backups/animations/network-blood-visual-cleared-v154.json',
 'backups/animations/network-blood-visual-settled-v154.json',
 'backups/animations/network-blood-visual-ready-v154.png',
 'backups/animations/network-blood-visual-radial-v154.png',
 'backups/animations/network-blood-visual-returned-v154.png',
 'backups/animations/network-blood-visual-settled-v154.png',
 'backups/animations/network-blood-visual-current-v155.json',
 'backups/animations/network-blood-visual-ready-v155.png',
 'backups/animations/network-blood-visual-acceptance-v1.json',
 'backups/animations/network-blood-visual-live-verification-v1.txt',
 'backups/animations/network-blood-visual-checkpoint-v1.txt',
 'backups/animations/network-blood-visual-scope-audit-v1.txt'
)){$paths.Add($relative)}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip','multiplayer-character-export-20261019-v2.zip','multiplayer-audio-20261019-v2.zip','multiplayer-ambient-20261019-v2.zip','multiplayer-placed-sound-20261019-v3.zip','multiplayer-effect-sound-20261019-v2.zip','multiplayer-initiative-20261019-v2.zip','multiplayer-action-queue-20261019-v2.zip','multiplayer-projectile-audio-20261019-v2.zip','multiplayer-creature-voice-20261019-v2.zip','multiplayer-weapon-sound-20261019-v2.zip','multiplayer-parry-visual-20261019-v1.zip')
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
