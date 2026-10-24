param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9][a-z0-9-]{2,79}$')][string]$Name)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$destination=[IO.Path]::GetFullPath((Join-Path $workspace ('backups/'+$Name+'.zip')))
if(-not $destination.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint is outside workspace'}
if(Test-Path -LiteralPath $destination){throw 'Checkpoint exists; select a new name'}
$sourceFiles=[Collections.Generic.List[string]]::new()
$extensions=@('.js','.mjs','.cjs','.css','.html','.md','.ps1','.py','.glsl')
foreach($directory in @('src','electron','test','scripts','evidence','dist','.github')){
 foreach($file in Get-ChildItem -LiteralPath (Join-Path $workspace $directory) -Recurse -File){
  if(($file.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0){throw 'Linked source file is not supported'}
  if($file.Extension -in $extensions){$sourceFiles.Add($file.FullName)}
 }
}
foreach($relative in @('package.json','package-lock.json','index.html','vite.config.js','scripts/performance-queue/manifest.json','scripts/performance-queue/source-contract.json')){$sourceFiles.Add((Join-Path $workspace $relative))}
$records=[Collections.Generic.List[object]]::new()
$hash=[Security.Cryptography.SHA256]::Create()
$stream=[IO.File]::Open($destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
try{
 foreach($file in @($sourceFiles | Sort-Object -Unique)){
  $relative=$file.Substring($workspace.Length+1).Replace('\','/')
  $bytes=[IO.File]::ReadAllBytes($file)
  $sha256=[Convert]::ToHexString($hash.ComputeHash($bytes)).ToLowerInvariant()
  $entry=$archive.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal)
  $entryStream=$entry.Open();try{$entryStream.Write($bytes,0,$bytes.Length)}finally{$entryStream.Dispose()}
  $records.Add([ordered]@{file=$relative;bytes=$bytes.Length;sha256=$sha256})
 }
 $manifest=[ordered]@{version=1;name=$Name;created=[DateTime]::UtcNow.ToString('o');scope='Source, tests, evidence and authored application bundle only. Native binaries, private captures, server assets, profiles and credentials excluded.';files=@($records.ToArray())}
 $data=[Text.Encoding]::UTF8.GetBytes(($manifest | ConvertTo-Json -Depth 8))
 $entry=$archive.CreateEntry('checkpoint-manifest.json');$entryStream=$entry.Open();try{$entryStream.Write($data,0,$data.Length)}finally{$entryStream.Dispose()}
}finally{$archive.Dispose()}
$readStream=[IO.File]::OpenRead($destination)
$reader=[IO.Compression.ZipArchive]::new($readStream,[IO.Compression.ZipArchiveMode]::Read,$false)
try{
 if($reader.Entries.Count-ne $records.Count+1){throw 'Checkpoint entry count mismatch'}
 foreach($record in $records){
  $entry=$reader.GetEntry($record.file);if(-not $entry -or $entry.Length-ne $record.bytes){throw 'Checkpoint entry missing or truncated'}
  $entryStream=$entry.Open();try{$actual=[Convert]::ToHexString($hash.ComputeHash($entryStream)).ToLowerInvariant()}finally{$entryStream.Dispose()}
  if($actual-ne $record.sha256){throw 'Checkpoint entry checksum mismatch'}
 }
}finally{$reader.Dispose();$hash.Dispose()}
$result=[ordered]@{success=$true;name=$Name;file=$destination;files=$records.Count;bytes=(Get-Item -LiteralPath $destination).Length;sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()}
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ($destination+'.verified.json') -Encoding utf8
$result | ConvertTo-Json -Compress
