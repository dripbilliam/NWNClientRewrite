param([switch]$KeepArchive)
$ErrorActionPreference='Stop'
# Matching official runtime only. This prepares an experiment; it does not
# change the client launcher, engine settings, renderer or running processes.
$runtimeProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runtimeTools=Join-Path $runtimeProject '.tools'
$runtimeManifest=Join-Path $runtimeTools 'release-runtime-4.7.2.verified.json'
$runtimeSource='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
$runtimeExpected='f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
$runtimeNames=@('windows_release_x86_64.exe','windows_release_x86_64_console.exe')
if(Test-Path -LiteralPath $runtimeManifest){
 $saved=Get-Content -LiteralPath $runtimeManifest -Raw|ConvertFrom-Json
 if($saved.source-ne$runtimeSource-or$saved.archiveSha256-ne$runtimeExpected-or$saved.files.Count-ne2){throw 'Release runtime receipt does not match the pinned official archive'}
 foreach($entry in $saved.files){
  if($entry.name-notin$runtimeNames){throw 'Unexpected runtime file in receipt'}
  $runtimeFile=Join-Path $runtimeTools $entry.name
  if(-not(Test-Path -LiteralPath $runtimeFile)-or(Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash.ToLowerInvariant()-ne$entry.sha256){throw 'Release runtime changed after verification'}
 }
 Write-Output (@{verified=$true;cached=$true;manifest=$runtimeManifest;files=$saved.files}|ConvertTo-Json -Compress -Depth 4);return
}
foreach($name in $runtimeNames){if(Test-Path -LiteralPath (Join-Path $runtimeTools $name)){throw 'An unverified release runtime already exists; refusing to overwrite it'}}
$runtimeArchive=Join-Path $runtimeTools 'Godot_v4.7.2-stable_export_templates.tpz.download'
if(Test-Path -LiteralPath $runtimeArchive){throw 'An earlier runtime download exists; inspect it before retrying'}
$runtimeCreated=$false
$runtimeStages=[Collections.Generic.List[string]]::new()
try{
 $runtimeHandler=[Net.Http.HttpClientHandler]::new();$runtimeHandler.AllowAutoRedirect=$true
 $runtimeClient=[Net.Http.HttpClient]::new($runtimeHandler);$runtimeClient.Timeout=[TimeSpan]::FromMinutes(15)
 $runtimeClient.DefaultRequestHeaders.UserAgent.ParseAdd('NWN-Godot-local-performance-check')
 try{
  $runtimeResponse=$runtimeClient.GetAsync($runtimeSource,[Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
  $runtimeResponse.EnsureSuccessStatusCode()|Out-Null
  $runtimeLength=$runtimeResponse.Content.Headers.ContentLength
  if($runtimeLength-and($runtimeLength-lt100MB-or$runtimeLength-gt2GB)){throw 'Unexpected pinned export archive size'}
  $runtimeInput=$runtimeResponse.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
  $runtimeOutput=[IO.File]::Open($runtimeArchive,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$runtimeCreated=$true
  try{
   $runtimeBuffer=[byte[]]::new(1MB);$runtimeCopied=0L;$runtimeNext=128MB
   while(($runtimeRead=$runtimeInput.Read($runtimeBuffer,0,$runtimeBuffer.Length))-gt0){
    $runtimeOutput.Write($runtimeBuffer,0,$runtimeRead);$runtimeCopied+=$runtimeRead
    if($runtimeCopied-ge$runtimeNext){Write-Output (@{downloadMiB=[math]::Round($runtimeCopied/1MB);totalMiB=if($runtimeLength){[math]::Round($runtimeLength/1MB)}else{$null}}|ConvertTo-Json -Compress);$runtimeNext+=128MB}
   }
   if($runtimeLength-and$runtimeCopied-ne$runtimeLength){throw 'Truncated release runtime archive'}
  }finally{$runtimeOutput.Dispose();$runtimeInput.Dispose();$runtimeResponse.Dispose()}
 }finally{$runtimeClient.Dispose();$runtimeHandler.Dispose()}
 $runtimeDigest=(Get-FileHash -LiteralPath $runtimeArchive -Algorithm SHA256).Hash.ToLowerInvariant()
 if($runtimeDigest-ne$runtimeExpected){throw 'Official export archive SHA256 verification failed'}
 Add-Type -AssemblyName System.IO.Compression
 $runtimeZip=[IO.Compression.ZipArchive]::new([IO.File]::OpenRead($runtimeArchive),[IO.Compression.ZipArchiveMode]::Read,$false)
 $runtimeFiles=[Collections.Generic.List[object]]::new()
 try{
  foreach($name in $runtimeNames){
   $entry=$runtimeZip.GetEntry('templates/'+$name)
   if(-not$entry-or$entry.Length-lt64KB-or$entry.Length-gt512MB){throw 'Expected official Windows release member is missing or has an invalid size'}
   $destination=[IO.Path]::GetFullPath((Join-Path $runtimeTools $name));$stage=$destination+'.partial'
   if(-not$destination.StartsWith($runtimeTools+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Release runtime destination escaped the tools folder'}
   $writer=[IO.File]::Open($stage,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$runtimeStages.Add($stage)
   $reader=$entry.Open();try{$reader.CopyTo($writer)}finally{$reader.Dispose();$writer.Dispose()}
   if((Get-Item -LiteralPath $stage).Length-ne$entry.Length){throw 'Release runtime extraction length mismatch'}
   $memberDigest=(Get-FileHash -LiteralPath $stage -Algorithm SHA256).Hash.ToLowerInvariant()
   Move-Item -LiteralPath $stage -Destination $destination
   $runtimeFiles.Add(@{name=$name;bytes=$entry.Length;sha256=$memberDigest;archiveMember=$entry.FullName})
  }
 }finally{$runtimeZip.Dispose()}
 $runtimeResult=@{verified=$true;source=$runtimeSource;archiveSha256=$runtimeDigest;version='4.7.2.stable';files=@($runtimeFiles.ToArray());launcherChanged=$false}
 [IO.File]::WriteAllText($runtimeManifest,($runtimeResult|ConvertTo-Json -Depth 5)+[Environment]::NewLine)
 Write-Output (@{verified=$true;cached=$false;manifest=$runtimeManifest;files=$runtimeFiles.ToArray();launcherChanged=$false}|ConvertTo-Json -Compress -Depth 5)
}finally{
 foreach($stage in $runtimeStages){if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage}}
 if($runtimeCreated-and-not$KeepArchive-and(Test-Path -LiteralPath $runtimeArchive)){Remove-Item -LiteralPath $runtimeArchive}
}
