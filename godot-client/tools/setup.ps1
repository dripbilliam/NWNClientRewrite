$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$lock=Get-Content -LiteralPath (Join-Path $project 'runtime-lock.json') -Raw | ConvertFrom-Json
$tools=Join-Path $project '.tools'
New-Item -ItemType Directory -Path $tools -Force | Out-Null
$archive=Join-Path $tools $lock.asset
if(-not (Test-Path -LiteralPath $archive)){
 Invoke-WebRequest -Uri $lock.url -OutFile $archive
}
if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()-ne $lock.sha256){throw 'Godot archive checksum mismatch'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try{
 foreach($name in @('Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe')){
  $entry=$zip.GetEntry($name)
  if(-not $entry){throw ('Missing pinned engine executable: '+$name)}
  $destination=Join-Path $tools $name
  if(-not (Test-Path -LiteralPath $destination)){[IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$destination,$false)}
 }
}finally{$zip.Dispose()}
Get-ChildItem -LiteralPath $tools -Filter '*.exe' | ForEach-Object {
 [pscustomobject]@{file=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant();signature=(Get-AuthenticodeSignature -LiteralPath $_.FullName).Status.ToString()}
} | ConvertTo-Json
