param([string]$Label='native-feat-popup-selection-v1')
$ErrorActionPreference='Stop'
if($Label -cnotmatch '^[a-z0-9-]{3,80}$'){throw 'Invalid checkpoint label'}
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$project=Join-Path $workspace 'godot-client'
$sha=[Security.Cryptography.SHA256]::Create()
function Digest([byte[]]$bytes){([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}
$accepted='8526b686546ba5675019623545956a40450c4a980c38a0a3b5de235b06c0a6f9'
if((Digest ([IO.File]::ReadAllBytes((Join-Path $project 'systems/native_feat_popup.gd')))) -ne $accepted){throw 'Accepted popup source differs'}
$output=Join-Path $project ('backups/'+$Label+'.zip')
if(Test-Path -LiteralPath $output){throw 'Existing checkpoint preserved'}
Add-Type -AssemblyName System.IO.Compression
$files=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
function Include([string]$relative){
 $source=[IO.Path]::GetFullPath((Join-Path $workspace $relative))
 if(-not $source.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint source escapes workspace'}
 if(-not [IO.File]::Exists($source)){throw "Missing checkpoint input: $relative"}
 $files[$relative.Replace('\','/')]=$source
}
foreach($relative in @(
 'godot-client/NATIVE-FEAT-POPUP-SELECTION.md',
 'godot-client/NATIVE-CREATION-FEATS.md',
 'godot-client/reports/native-feat-popup-selection-source-v1.json',
 'godot-client/reports/native-feat-popup-selection-source-v2.json',
 'godot-client/reports/native-feat-popup-selection-original-v1.json',
 'godot-client/reports/native-creation-feats-research-v1.json',
 'scripts/inspect-native-feat-popup-selection.py',
 'scripts/observe-native-feat-popup-selection.py',
 'scripts/inspect-native-intratile-coordinator.py',
 'tools/seal-native-feat-popup-selection.ps1'
)){Include $relative}
foreach($name in @('native-feat-popup-selection-before-v1','native-feat-popup-selection-after-v1','native-feat-popup-selection-legacy-v1')){
 $folder=Join-Path $project ('.cache/feat-popup-selection/'+$name)
 $proof=Get-Content -LiteralPath (Join-Path $folder 'proof.json') -Raw|ConvertFrom-Json
 if($name -ne 'native-feat-popup-selection-before-v1' -and (-not $proof.success -or -not $proof.cleanEngine -or $proof.changedInputs.Count -ne 0)){throw 'Accepted receipt is not clean'}
 foreach($pinnedRow in $proof.inputs){
  $snapshot=Join-Path $folder ('inputs/'+$pinnedRow.path)
  if((Digest ([IO.File]::ReadAllBytes($snapshot))) -ne $pinnedRow.sha256){throw "Pinned input mismatch: $snapshot"}
 }
 foreach($file in Get-ChildItem -LiteralPath $folder -File -Recurse){Include ($file.FullName.Substring($workspace.Length+1))}
}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $project 'backups/native-feat-popup-selection-before-v1') -File){Include ($file.FullName.Substring($workspace.Length+1))}
$stream=[IO.File]::Open($output,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
$manifest=[Collections.Generic.List[object]]::new()
try{
 foreach($entryPath in ($files.Keys|Sort-Object)){
  $bytes=[IO.File]::ReadAllBytes($files[$entryPath]);$manifest.Add(@{path=$entryPath;sha256=(Digest $bytes);bytes=$bytes.Length})
  $entry=$zip.CreateEntry($entryPath,[IO.Compression.CompressionLevel]::Optimal);$writer=$entry.Open();try{$writer.Write($bytes,0,$bytes.Length)}finally{$writer.Dispose()}
 }
 $meta=@{scope='Original palette source witness, retained before42/10 visual rejection and accepted actual42+legacy31 physical input/theme state. No full creator/server/original-pixel claim.';acceptedPopupSha256=$accepted;files=$manifest.ToArray()}
 $metadata=[Text.Encoding]::UTF8.GetBytes(($meta|ConvertTo-Json -Depth 10));$entry=$zip.CreateEntry('manifest.json',[IO.Compression.CompressionLevel]::Optimal);$writer=$entry.Open();try{$writer.Write($metadata,0,$metadata.Length)}finally{$writer.Dispose()}
}finally{$zip.Dispose()}
$read=[IO.Compression.ZipFile]::OpenRead($output)
try{
 foreach($row in $manifest){$entry=$read.GetEntry($row.path);if($null -eq $entry){throw 'Missing ZIP entry'};$reader=$entry.Open();$buffer=[IO.MemoryStream]::new();try{$reader.CopyTo($buffer);$bytes=$buffer.ToArray()}finally{$reader.Dispose();$buffer.Dispose()};if($bytes.Length -ne $row.bytes -or (Digest $bytes) -ne $row.sha256){throw 'ZIP readback mismatch'}}
 if($read.Entries.Count -ne $manifest.Count+1){throw 'ZIP entry count mismatch'}
}finally{$read.Dispose()}
$zipHash=(Digest ([IO.File]::ReadAllBytes($output)));$sha.Dispose()
@{success=$true;path=$output;sha256=$zipHash;entries=$manifest.Count+1;acceptedChecks=73;originalPaletteTransitions=7}|ConvertTo-Json -Compress
