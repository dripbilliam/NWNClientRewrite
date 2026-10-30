param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-loading-baseline-project-v1')
$ErrorActionPreference='Stop'
$baselineProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$baselineArchive=Join-Path $baselineProject 'backups/native-loading-six-stage-baseline-v1.zip'
if((Get-FileHash -LiteralPath $baselineArchive).Hash.ToLowerInvariant()-ne'4f07d63443e3b305cf62ebf9ff1ddd70e54c8ab85fad3104c31d76e22f613cac'){throw 'Baseline checkpoint identity differs'}
$baselineFolder=Join-Path ([IO.Path]::GetTempPath()) ('nwn-native-loading-baseline-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($baselineFolder)|Out-Null
Add-Type -AssemblyName System.IO.Compression
$baselineZip=[IO.Compression.ZipFile]::OpenRead($baselineArchive)
try{
 foreach($entry in $baselineZip.Entries){
  if($entry.FullName.StartsWith('__workspace__/')){continue}
  $target=[IO.Path]::GetFullPath((Join-Path $baselineFolder $entry.FullName))
  if(-not$target.StartsWith($baselineFolder+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint path escaped owned baseline folder'}
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
  $source=$entry.Open();$writer=[IO.File]::Open($target,[IO.FileMode]::CreateNew)
  try{$source.CopyTo($writer)}finally{$writer.Dispose();$source.Dispose()}
 }
}finally{$baselineZip.Dispose()}
[IO.Directory]::CreateDirectory((Join-Path $baselineFolder '.godot'))|Out-Null
[IO.Directory]::CreateDirectory((Join-Path $baselineFolder '.cache/native-kernel'))|Out-Null
[IO.File]::WriteAllText((Join-Path $baselineFolder '.godot/extension_list.cfg'),"res://native/particle_kernel.gdextension`n")
$baselineKernel=Join-Path $baselineProject '.cache/native-kernel/nwn-particle-kernel.dll'
Copy-Item -LiteralPath $baselineKernel -Destination (Join-Path $baselineFolder '.cache/native-kernel/nwn-particle-kernel.dll')
$baselineResult=[ordered]@{sourceProject=$baselineFolder;checkpoint=$baselineArchive;checkpointSha256=(Get-FileHash -LiteralPath $baselineArchive).Hash.ToLowerInvariant();kernelSha256=(Get-FileHash -LiteralPath $baselineKernel).Hash.ToLowerInvariant();scope='Authored source checkpoint and our compiled extension only; no original assets, credentials, prepared assets or game-server connections'}
$baselineResult|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $baselineProject ('reports/'+$Run+'.json')) -Encoding utf8
$baselineResult|ConvertTo-Json -Compress
