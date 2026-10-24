param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/network_character.js','src/network_game_messages.js','src/network_frontend.js','src/style.css','index.html',
 'electron/network_game_session.mjs','electron/network_character_vault.mjs','electron/network_ipc.cjs','electron/preload.cjs','electron/main.cjs','electron/installed_network_session.mjs',
 'scripts/probe-network-renderer.cjs','scripts/inspect-native-character-export-wire.py','scripts/network-character-fixture.html','scripts/network-character-fixture.mjs','scripts/smoke-network-character.cjs','scripts/verify-network-character-export.mjs',
 'scripts/checkpoint-character-export.ps1','scripts/audit-character-export-checkpoint.py',
 'test/network-character-export.test.js','test/network-character-vault.test.js','test/network-ipc.test.js',
 'evidence/multiplayer-character-persistence.md','evidence/multiplayer-character-export-investigation.md','evidence/multiplayer-chat.md',
 'backups/animations/native-character-export-wire-observations.json','backups/animations/rea-character-export-filename.json','backups/animations/rea-character-export-write-opaque.json',
 'backups/animations/rea-character-rejoin-load-creature.json','backups/animations/rea-character-rejoin-ready-spell-body.json',
 'backups/animations/network-character-export-focused-v2.txt','backups/animations/network-character-export-regression-v1.txt','backups/animations/network-character-export-build-v2.txt',
 'backups/animations/network-character-export-ui-v1.json','backups/animations/network-character-export-ui-v1.png','backups/animations/network-character-export-ui-v3.txt'
)){$paths.Add($relative)}
if($IncludeLive){foreach($relative in @('REPLACEMENT_CLIENT_ROADMAP.md','backups/animations/local-network-model-preparation-v130.json','backups/animations/local-network-character-export-v131.json','backups/animations/local-network-character-export-v132.json','backups/animations/network-character-export-frozen-v131.json','backups/animations/network-character-export-spell-proof-v131.json','backups/animations/network-character-export-acceptance-v1.json','backups/animations/network-character-export-ready-v131.png','backups/animations/network-character-export-ready-v132.png','backups/animations/network-character-export-ready-v133.png','backups/animations/network-character-export-equip-proof-v131.json','backups/animations/network-character-export-reconnect-proof-v132.json','backups/animations/network-character-export-current-v133.json')){if(Test-Path -LiteralPath (Join-Path $workspace $relative)){$paths.Add($relative)}}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip','multiplayer-model-preparation-live-20261019-v4.zip')
$chain=@($parents|ForEach-Object {[ordered]@{archive=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $workspace ('backups/'+$_)) -Algorithm SHA256).Hash}})
Add-Type -AssemblyName System.IO.Compression
$manifest=[Collections.Generic.List[object]]::new();$stream=[IO.File]::Open($destination,[IO.FileMode]::CreateNew);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($relative in $paths){$absolute=[IO.Path]::GetFullPath((Join-Path $workspace $relative));if(-not $absolute.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint source escaped workspace'};$snapshot=[IO.File]::ReadAllBytes($absolute);$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($snapshot));$entry=$zip.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal);$entryStream=$entry.Open();try{$entryStream.Write($snapshot,0,$snapshot.Length)}finally{$entryStream.Dispose()};$manifest.Add([ordered]@{path=$relative;bytes=$snapshot.Length;sha256=$hash})}
 foreach($metadata in @(@{name='checkpoint-manifest.json';value=@($manifest.ToArray())},@{name='checkpoint-chain.json';value=[ordered]@{kind='incremental';parents=$chain;restore='Extract parents in order, then overlay this checkpoint.'}})){$entry=$zip.CreateEntry($metadata.name);$writer=[IO.StreamWriter]::new($entry.Open());try{$writer.Write(($metadata.value|ConvertTo-Json -Depth 6))}finally{$writer.Dispose()}}
}finally{$zip.Dispose();$stream.Dispose()}
$verify=[IO.Compression.ZipFile]::OpenRead($destination)
try{if($verify.Entries.Count -ne $paths.Count+2){throw 'Checkpoint count mismatch'};foreach($record in $manifest){$entry=$verify.GetEntry($record.path);if(-not $entry -or $entry.Length -ne $record.bytes){throw ('Length mismatch: '+$record.path)};$entryStream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{$hash=[Convert]::ToHexString($sha.ComputeHash($entryStream))}finally{$entryStream.Dispose();$sha.Dispose()};if($hash -ne $record.sha256){throw ('Hash mismatch: '+$record.path)}}}finally{$verify.Dispose()}
[ordered]@{path=$destination;files=$paths.Count;bytes=(Get-Item -LiteralPath $destination).Length}|ConvertTo-Json -Compress
