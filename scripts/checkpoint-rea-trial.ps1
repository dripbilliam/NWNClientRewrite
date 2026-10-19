$ErrorActionPreference='Stop'
$taskWorkspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskDirectory=Join-Path $taskWorkspace 'backups/rea-trial'
$taskDestination=[IO.Path]::GetFullPath((Join-Path $taskWorkspace 'backups/rea-trial-20261016-v1.zip'))
if(-not $taskDestination.StartsWith($taskWorkspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Archive target is outside workspace'}
if(Test-Path -LiteralPath $taskDestination){throw 'Trial archive already exists'}
$taskFiles=@(Get-ChildItem -LiteralPath $taskDirectory -File | Where-Object {$_.Extension -in @('.json','.txt','.npmrc') -and $_.Name -ne 'archive-verification.json'})
$taskFiles+=@('scripts/rea-trial-run.mjs','scripts/rea-trial-fixture.mjs','scripts/verify-rea-trial.mjs','scripts/checkpoint-rea-trial.ps1','evidence/rea-isolated-trial.md','backups/rea-trial/runner/package.json','backups/rea-trial/runner/package-lock.json') | ForEach-Object {Get-Item -LiteralPath (Join-Path $taskWorkspace $_)}
Add-Type -AssemblyName System.IO.Compression
$taskStream=[IO.File]::Open($taskDestination,[IO.FileMode]::CreateNew)
$taskZip=[IO.Compression.ZipArchive]::new($taskStream,[IO.Compression.ZipArchiveMode]::Create)
$taskManifest=[Collections.Generic.List[object]]::new()
try{
 foreach($taskFile in $taskFiles){
  $taskRelative=$taskFile.FullName.Substring($taskWorkspace.Length+1).Replace('\','/')
  $taskManifest.Add([ordered]@{path=$taskRelative;bytes=$taskFile.Length;sha256=(Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256).Hash})
  $taskEntry=$taskZip.CreateEntry($taskRelative,[IO.Compression.CompressionLevel]::Optimal)
  $taskInput=[IO.File]::OpenRead($taskFile.FullName);$taskOutput=$taskEntry.Open()
  try{$taskInput.CopyTo($taskOutput)}finally{$taskInput.Dispose();$taskOutput.Dispose()}
 }
 $taskWriter=[IO.StreamWriter]::new($taskZip.CreateEntry('manifest.json').Open())
 try{$taskWriter.Write(($taskManifest|ConvertTo-Json -Depth 4))}finally{$taskWriter.Dispose()}
}finally{$taskZip.Dispose();$taskStream.Dispose()}
$taskVerify=[IO.Compression.ZipFile]::OpenRead($taskDestination)
try{
 if($taskVerify.Entries.Count -ne $taskFiles.Count+1){throw 'Archive entry count mismatch'}
 foreach($taskRecord in $taskManifest){
  $taskEntry=$taskVerify.GetEntry($taskRecord.path);if(-not $taskEntry -or $taskEntry.Length -ne $taskRecord.bytes){throw 'Archive length mismatch'}
  $taskInput=$taskEntry.Open();$taskHash=[Security.Cryptography.SHA256]::Create()
  try{if([Convert]::ToHexString($taskHash.ComputeHash($taskInput)) -ne $taskRecord.sha256){throw ('Archive hash mismatch: '+$taskRecord.path)}}finally{$taskInput.Dispose();$taskHash.Dispose()}
 }
}finally{$taskVerify.Dispose()}
$taskReport=[ordered]@{validation='PASS';path=$taskDestination;files=$taskFiles.Count;bytes=(Get-Item -LiteralPath $taskDestination).Length;everyEntryLengthAndSha256Verified=$true}
$taskReport|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $taskDirectory 'archive-verification.json')
$taskReport|ConvertTo-Json -Compress
