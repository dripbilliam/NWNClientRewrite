param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,[switch]$IncludeLive)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip')
if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=[Collections.Generic.List[string]]::new()
foreach($relative in @(
 'src/renderer_model_preparation.js',
 'src/renderer_light_selection.js',
 'src/renderer_light_slots.js',
 'src/renderer_shadow_budget.js',
 'test/renderer-light-selection.test.js',
 'scripts/inspect-native-light-selection.py',
 'scripts/renderer-light-slots-fixture.mjs',
 'scripts/smoke-renderer-light-selection.cjs',
 'evidence/renderer-light-selection.md',
 'evidence/multiplayer-character-export-investigation.md',
 'scripts/locate-native-character-export.py',
 'backups/animations/native-character-export-sender-candidates.json',
 'backups/animations/native-light-selection-observations.json',
 'backups/animations/renderer-light-selection-tests-v2.txt',
 'backups/animations/renderer-light-selection-regression-v1.txt',
 'backups/animations/renderer-light-selection-build-v1.txt',
 'backups/animations/renderer-light-selection-gpu-v1-stderr.txt',
 'backups/animations/renderer-light-selection-gpu-v2.json',
 'backups/animations/renderer-light-selection-gpu-v2.png',
 'src/model_particles.js',
 'src/model_native_pose.js',
 'src/model_animation.js',
 'src/binary_mdl.js',
 'src/mdl_animation.js',
 'test/model-native-pose-fields.test.js',
 'test/model-selfillum.test.js',
 'scripts/inspect-native-mesh-selfillum.py',
 'scripts/smoke-model-selfillum.mjs',
 'evidence/model-selfillum-controller.md',
 'backups/animations/native-mesh-selfillum-observations.json',
 'backups/animations/model-selfillum-focused-v1.txt',
 'backups/animations/model-selfillum-rendering-v2.txt',
 'backups/animations/model-selfillum-installed-v1.json',
 'backups/animations/model-selfillum-build-v1.txt',
 'backups/animations/rea-mesh-controller-part-constructor.json',
 'backups/animations/rea-mesh-controller-parse-field.json',
 'backups/animations/rea-mesh-controller-control.json',
 'backups/animations/rea-mesh-controller-control-body.json',
 'backups/animations/rea-mesh-controller-draw.json',
 'backups/animations/rea-mesh-controller-render-flat.json',
 'src/network_scene.js',
 'src/main.js',
 'test/renderer-model-preparation.test.js',
 'scripts/probe-network-renderer.cjs',
 'scripts/renderer-model-preparation-fixture.html',
 'scripts/renderer-model-preparation-fixture.mjs',
 'scripts/smoke-renderer-model-preparation.cjs',
 'scripts/checkpoint-renderer-model.ps1',
 'scripts/audit-renderer-model-checkpoint.py',
 'evidence/renderer-model-preparation.md',
 'backups/animations/renderer-model-preparation-focused-v3.txt',
 'backups/animations/renderer-model-preparation-integration-v2.txt',
 'backups/animations/renderer-model-preparation-build-v2.txt',
 'backups/animations/renderer-model-preparation-gpu-v2.json',
 'backups/animations/renderer-model-preparation-gpu-v2.png',
 'backups/animations/renderer-model-preparation-gpu-v1-stderr.txt',
 'scripts/analyze-network-light-capacity.mjs',
 'backups/animations/renderer-model-preparation-build-v3.txt',
 'backups/animations/renderer-model-preparation-tests-v3.txt',
 'backups/animations/renderer-model-preparation-focused-v5.txt',
 'backups/animations/renderer-model-preparation-build-v5.txt',
 'backups/animations/renderer-model-preparation-particle-tests-v4.txt',
 'backups/animations/renderer-model-preparation-gpu-v4.json',
 'backups/animations/renderer-model-preparation-gpu-v4.png'
)){$paths.Add($relative)}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $workspace 'backups/animations') -Filter 'rea-light-selection-*.json' | Sort-Object Name){$paths.Add('backups/animations/'+$file.Name)}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $workspace 'backups/animations') -Filter 'rea-character-export-*.json' | Sort-Object Name){$paths.Add('backups/animations/'+$file.Name)}
if($IncludeLive){foreach($relative in @('backups/animations/network-model-preparation-combat-ready-v129.png','backups/animations/network-model-preparation-ready-v130.png','backups/animations/network-model-preparation-render-proof-v130.json','backups/animations/network-model-preparation-live-acceptance-v130.json','backups/animations/network-model-preparation-scope-audit-v3.txt')){if(Test-Path -LiteralPath (Join-Path $workspace $relative)){$paths.Add($relative)}}}
if($IncludeLive){foreach($relative in @('backups/animations/local-network-light-capacity-v128.json','backups/animations/local-network-model-preparation-v129.json','backups/animations/network-model-preparation-acceptance-v1.json','backups/animations/network-light-capacity-observation-v128.json','backups/animations/network-model-preparation-observation-v129.json','backups/animations/network-model-preparation-ready-v129.png','backups/animations/network-model-preparation-ambush-proof-v129.json','backups/animations/network-model-preparation-render-observation-v129.json','backups/animations/network-model-preparation-quest-proof-v129.json','backups/animations/network-model-preparation-player-combat-proof-v129.json','REPLACEMENT_CLIENT_ROADMAP.md')){if(Test-Path -LiteralPath (Join-Path $workspace $relative)){$paths.Add($relative)}}}
$parents=@('multiplayer-attack-feedback-20261019-v1.zip','multiplayer-attack-feedback-live-20261019-v1.zip','multiplayer-procedural-projectile-live-20261019-v2.zip','multiplayer-light-capacity-live-20261019-v4.zip')
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
