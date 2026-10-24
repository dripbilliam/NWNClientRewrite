param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$destination=Join-Path $workspace ('backups/'+$Name+'.zip');if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists'}
$paths=@(
 'src/resource_archive.js',
 'src/network_resources.js',
 'src/server_discovery.js',
 'src/nwsync_manifest.js',
 'src/network_frontend.js',
 'electron/main.cjs',
 'electron/network_ipc.cjs',
 'electron/network_game_session.mjs',
 'electron/installed_network_resources.mjs',
 'electron/installed_network_session.mjs',
 'electron/nwsync_content.mjs',
 'electron/nwsync_reader.mjs',
 'electron/server_resource_context.mjs',
 'scripts/native/nwn_content_reader.c',
 'scripts/native/zstd-LICENSE.txt',
 'scripts/build-content-reader.ps1',
 'scripts/inspect-native-resource-priority.py',
 'scripts/smoke-server-content.cjs',
 'scripts/checkpoint-server-content.ps1',
 'scripts/locate-native-character-ui.py',
 'scripts/probe-installed-record-ui.mjs',
 'scripts/probe-server-content-connection.mjs',
 'scripts/probe-server-advertisement.mjs',
 'scripts/download-advertised-server-content.mjs',
 'scripts/inspect-advertised-manifest.mjs',
 'scripts/read-fresh-content-progress.mjs',
 'scripts/verify-arelith-cold-connect.mjs',
 'scripts/smoke-fresh-arelith-context.mjs',
 'test/server-discovery.test.js',
 'test/nwsync-content.test.js',
 'test/resource-precedence.test.js',
 'test/network-game-session.test.js',
 'test/network-resources-native.test.js',
 'evidence/multiplayer-server-content.md',
 'evidence/arelith-cold-connect.md',
 'REPLACEMENT_CLIENT_ROADMAP.md',
 'CASTING_RESUME_NOTE.md',
 'tooling/native/content-reader/build-manifest.json',
 'backups/animations/content-reader-build-v3.txt',
 'backups/animations/native-resource-priority-observations.json',
 'backups/animations/server-content-focused-v6.txt',
 'backups/animations/server-content-lifecycle-v1.txt',
 'backups/animations/server-content-electron-v2.json',
 'backups/animations/server-content-electron-v2.txt',
 'backups/animations/server-content-electron-v2-stderr.txt',
 'backups/animations/server-content-build-v2.txt',
 'backups/animations/installed-record-ui-hooks-v1.json',
 'backups/animations/native-character-ui-reference-candidates.json',
 'backups/animations/arelith-cold-connect-v1.json',
 'backups/animations/arelith-initial-login-v2.json',
 'backups/animations/arelith-authenticated-advertisement-v1.json',
 'backups/animations/arelith-public-discovery-v1.json',
 'backups/animations/arelith-manifest-format-v1.json',
 'backups/animations/arelith-fresh-download-v1.json',
 'backups/animations/arelith-fresh-download-v2.json',
 'backups/animations/arelith-fresh-rules-progress-v1.json',
 'backups/animations/arelith-fresh-rules-progress-v3.json',
 'backups/animations/arelith-cold-connect-acceptance-v2.txt',
 'backups/animations/arelith-fresh-context-v1.json',
 'backups/animations/arelith-fresh-context-v1.txt',
 'backups/animations/arelith-content-focused-v2.txt',
 'backups/animations/arelith-content-build-v1.txt'
)
$paths+=@(Get-ChildItem -LiteralPath (Join-Path $workspace 'backups/animations') -File | Where-Object {$_.Name -like 'rea-server-resource-*.json' -or $_.Name -like 'rea-character-ui-*.json' -or $_.Name -like 'rea-inventory-ui-*.json' -or $_.Name -like 'rea-arelith-*.json'} | ForEach-Object {'backups/animations/'+$_.Name})
$paths=@($paths | Select-Object -Unique)
Add-Type -AssemblyName System.IO.Compression
$parentName='multiplayer-arelith-cold-connect-20261019-v1.zip';$parentPath=Join-Path $workspace ('backups/'+$parentName);$parentZip=[IO.Compression.ZipFile]::OpenRead($parentPath)
try{$reader=[IO.StreamReader]::new($parentZip.GetEntry('checkpoint-chain.json').Open());try{$prior=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose()}}finally{$parentZip.Dispose()}
$chain=@($prior.parents)+@([ordered]@{archive=$parentName;sha256=(Get-FileHash -LiteralPath $parentPath -Algorithm SHA256).Hash})
$manifest=[Collections.Generic.List[object]]::new();$stream=[IO.File]::Open($destination,[IO.FileMode]::CreateNew);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($relative in $paths){$absolute=[IO.Path]::GetFullPath((Join-Path $workspace $relative));if(-not $absolute.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint source escaped workspace'};$snapshot=[IO.File]::ReadAllBytes($absolute);$entry=$zip.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal);$entryStream=$entry.Open();try{$entryStream.Write($snapshot,0,$snapshot.Length)}finally{$entryStream.Dispose()};$manifest.Add([ordered]@{path=$relative;bytes=$snapshot.Length;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($snapshot))})}
 foreach($metadata in @(@{name='checkpoint-manifest.json';value=@($manifest.ToArray())},@{name='checkpoint-chain.json';value=[ordered]@{kind='incremental';parents=$chain;restore='Extract parents in order, then overlay this checkpoint. Build the public content-reader helper from its pinned inputs.'}})){$entry=$zip.CreateEntry($metadata.name);$writer=[IO.StreamWriter]::new($entry.Open());try{$writer.Write(($metadata.value|ConvertTo-Json -Depth 8))}finally{$writer.Dispose()}}
}finally{$zip.Dispose();$stream.Dispose()}
$verify=[IO.Compression.ZipFile]::OpenRead($destination)
try{if($verify.Entries.Count -ne $paths.Count+2){throw 'Checkpoint count mismatch'};foreach($record in $manifest){$entry=$verify.GetEntry($record.path);if(-not $entry -or $entry.Length -ne $record.bytes){throw ('Length mismatch: '+$record.path)};$entryStream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{$hash=[Convert]::ToHexString($sha.ComputeHash($entryStream))}finally{$entryStream.Dispose();$sha.Dispose()};if($hash -ne $record.sha256){throw ('Hash mismatch: '+$record.path)}}}finally{$verify.Dispose()}
[ordered]@{path=$destination;files=$paths.Count;bytes=(Get-Item -LiteralPath $destination).Length;sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()}|ConvertTo-Json -Compress
