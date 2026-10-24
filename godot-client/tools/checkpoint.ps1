param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9][a-z0-9-]{2,79}$')][string]$Name, [string[]]$RelatedSource=@())
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$ignored=@('.godot','.tools','.cache','reports','backups','__pycache__')
$files=[Collections.Generic.List[string]]::new()
function Add-ProjectSource([string]$directory){
 foreach($entry in Get-ChildItem -LiteralPath $directory){
  if($entry.Attributes-band [IO.FileAttributes]::ReparsePoint){throw 'Linked source is unsupported'}
  if($entry.PSIsContainer){if($entry.Name-notin $ignored){Add-ProjectSource $entry.FullName}}
  elseif($entry.Extension-in @('.gd','.tscn','.godot','.json','.mjs','.cjs','.ps1','.py','.md') -or $entry.Name-eq '.gitignore'){$files.Add($entry.FullName)}
 }
}
Add-ProjectSource $project
$workspace=[IO.Path]::GetFullPath((Join-Path $project '..'))
$related=[Collections.Generic.List[object]]::new()
foreach($source in $RelatedSource){
 $absolute=[IO.Path]::GetFullPath((Join-Path $workspace $source))
 $allowed=@('src','electron','test','scripts') | Where-Object {$absolute.StartsWith((Join-Path $workspace $_)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)}
 if(-not $allowed -or [IO.Path]::GetExtension($absolute)-notin @('.js','.mjs','.cjs','.ts','.gd','.md','.json','.ps1','.py')){throw 'Related checkpoint input must be authored src/electron/test/scripts source inside the workspace'}
 $entry=Get-Item -LiteralPath $absolute
 if($entry.PSIsContainer){throw 'Related source must be a file'}
 for($ancestor=$entry;$ancestor-and$ancestor.FullName-ne$workspace;$ancestor=$ancestor.Parent??$ancestor.Directory){if($ancestor.Attributes-band[IO.FileAttributes]::ReparsePoint){throw 'Linked related source is unsupported'}}
 $relative=$absolute.Substring($workspace.Length+1).Replace('\','/')
 if(@($related | Where-Object {$_.source-eq$relative}).Count){throw 'Duplicate related checkpoint source'}
 $related.Add(@{absolute=$absolute;source=$relative})
}
$folder=Join-Path $project 'backups'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$destination=Join-Path $folder ($Name+'.zip')
$stream=[IO.File]::Open($destination,[IO.FileMode]::CreateNew)
$archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
$hash=[Security.Cryptography.SHA256]::Create()
$records=[Collections.Generic.List[object]]::new()
try{
 foreach($file in @($files | Sort-Object)){
  $relative=$file.Substring($project.Length+1).Replace('\','/')
  $bytes=[IO.File]::ReadAllBytes($file)
  $digest=[Convert]::ToHexString($hash.ComputeHash($bytes)).ToLowerInvariant()
  $entry=$archive.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal)
  $writer=$entry.Open();try{$writer.Write($bytes)}finally{$writer.Dispose()}
  $records.Add(@{file=$relative;sha256=$digest;bytes=$bytes.Length})
 }
 foreach($source in $related){
  $bytes=[IO.File]::ReadAllBytes($source.absolute)
  $digest=[Convert]::ToHexString($hash.ComputeHash($bytes)).ToLowerInvariant()
  $relative='__workspace__/'+$source.source
  $entry=$archive.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal)
  $writer=$entry.Open();try{$writer.Write($bytes)}finally{$writer.Dispose()}
  $records.Add(@{file=$relative;source=$source.source;sourceScope='workspace';sha256=$digest;bytes=$bytes.Length})
 }
}finally{$archive.Dispose()}
$reader=[IO.Compression.ZipArchive]::new([IO.File]::OpenRead($destination),[IO.Compression.ZipArchiveMode]::Read,$false)
try{
 foreach($record in $records){$entry=$reader.GetEntry($record.file);$data=$entry.Open();try{$actual=[Convert]::ToHexString($hash.ComputeHash($data)).ToLowerInvariant()}finally{$data.Dispose()};if($actual-ne $record.sha256){throw 'Checkpoint read-back mismatch'}}
}finally{$reader.Dispose();$hash.Dispose()}
$result=@{file=$destination;files=$records.Count;sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant();verified=$true;manifest=@($records.ToArray())}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath ($destination+'.verified.json') -Encoding utf8
$result | Select-Object file,files,sha256,verified | ConvertTo-Json -Compress
