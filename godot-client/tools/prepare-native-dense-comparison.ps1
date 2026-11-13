[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidatePattern('^native-dense-[a-z0-9-]+$')][string]$Run,
 [ValidateSet('baseline','candidate')][string]$Variant='baseline',
 [switch]$Indexed
)
$ErrorActionPreference='Stop'
if($Indexed-and$Variant-ne'candidate'){throw 'Experimental routing is only permitted in a candidate copy'}
$denseProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$denseWorkspace=Split-Path -Parent $denseProject
$denseStage=Join-Path $denseProject ('.cache/native-dense-area/'+$Run)
$denseCopy=Join-Path $denseStage $Variant
if(Test-Path -LiteralPath $denseCopy){throw 'Existing comparison copy is preserved; choose a fresh run'}
. (Join-Path $PSScriptRoot 'native-level-up-no-build.ps1')
Assert-NativeLevelUpNoBuild -Root $denseProject
$denseEngine=Join-Path $denseProject '.tools/Godot_v4.7.2-stable_win64.exe'
function DenseHash([string]$File){(Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()}
if((DenseHash $denseEngine)-ne'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'){throw 'Unexpected existing engine; no fallback/build'}
$denseArchive=Join-Path $denseWorkspace 'backups/native-dense-area-prechanges-2026-11-04-v1.zip'
if((DenseHash $denseArchive)-ne'c2287a214cc443f2a068d285ded55f6d3cc45ec12074cb6e010b8389baa3c5f1'){throw 'Prechange checkpoint differs'}
$denseExtensions=@('.gd','.gdshader','.glsl','.json','.cpp','.hpp','.h','.gdextension','.ps1','.mjs','.cjs','.tscn','.tres')
$denseFiles=@()
foreach($folder in @('systems','tests','native','tools')){
 $denseFiles+=@(Get-ChildItem -LiteralPath (Join-Path $denseProject $folder) -Recurse -File|Where-Object{$_.Extension-in$denseExtensions})
}
$denseFiles+=@(Get-ChildItem -LiteralPath $denseProject -File|Where-Object{$_.Extension-in$denseExtensions-or$_.Extension-eq'.godot'})
$denseRuntime=@('.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json','.godot/extension_list.cfg')
foreach($relative in $denseRuntime){$denseFiles+=Get-Item -LiteralPath (Join-Path $denseProject $relative)}
[IO.Directory]::CreateDirectory($denseCopy)|Out-Null
$densePins=@();$densePinByPath=[Collections.Generic.Dictionary[string,hashtable]]::new([StringComparer]::OrdinalIgnoreCase);$denseBytes=0
foreach($file in $denseFiles|Sort-Object FullName -Unique){
 $relative=[IO.Path]::GetRelativePath($denseProject,$file.FullName).Replace([IO.Path]::DirectorySeparatorChar,[char]'/')
 if($relative.StartsWith('..')){throw 'Comparison input escapes project'}
 $bytes=[IO.File]::ReadAllBytes($file.FullName);$denseBytes+=$bytes.Length
 if($denseBytes-gt96MB-or$densePins.Count-ge5000){throw 'Comparison source copy exceeds bound'}
 $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
 $target=Join-Path $denseCopy $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
 [IO.File]::WriteAllBytes($target,$bytes)
 if((DenseHash $target)-ne$digest){throw 'Comparison copy failed verification'}
 $pin=@{relative=$relative;capturedSha256=$digest;bytes=$bytes.Length;finalSha256=$digest}
 $densePins+=$pin;$densePinByPath.Add($relative,$pin)
}
$denseOverrides=@()
if($Variant-eq'baseline'){
 $archiveStream=[IO.File]::OpenRead($denseArchive);$archive=[IO.Compression.ZipArchive]::new($archiveStream,[IO.Compression.ZipArchiveMode]::Read)
 try{
  $manifestStream=$archive.GetEntry('manifest.json').Open();$reader=[IO.StreamReader]::new($manifestStream)
  try{$manifest=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose()}
  foreach($entry in $manifest.files){
   if(-not$entry.path.StartsWith('godot-client/')){throw 'Checkpoint entry is outside project'}
   $relative=$entry.path.Substring('godot-client/'.Length);$target=[IO.Path]::GetFullPath((Join-Path $denseCopy $relative))
   if(-not$target.StartsWith($denseCopy+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint entry escapes comparison'}
   $input=$archive.GetEntry($entry.path).Open();$memory=[IO.MemoryStream]::new()
   try{$input.CopyTo($memory);$bytes=$memory.ToArray()}finally{$memory.Dispose();$input.Dispose()}
   if([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()-ne$entry.sha256){throw 'Checkpoint entry digest differs'}
   [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null;[IO.File]::WriteAllBytes($target,$bytes)
   if(-not$densePinByPath.ContainsKey($relative)){throw ('Checkpoint entry has no copied source: '+$relative)}
   $densePinByPath[$relative].finalSha256=$entry.sha256;$denseOverrides+=@{relative=$relative;sha256=$entry.sha256;source='verified-before-checkpoint'}
  }
 }finally{$archive.Dispose();$archiveStream.Dispose()}
}
if($Indexed){
 $target=Join-Path $denseCopy 'systems/native_render/live_world.gd';$body=[IO.File]::ReadAllText($target)
 $needle='var drive_spatial_enabled:=false'
 if([regex]::Matches($body,[regex]::Escape($needle)).Count-ne1){throw 'Experimental route marker differs'}
 [IO.File]::WriteAllText($target,$body.Replace($needle,'var drive_spatial_enabled:=true'),[Text.UTF8Encoding]::new($false))
 $digest=DenseHash $target
 $densePinByPath['systems/native_render/live_world.gd'].finalSha256=$digest
 $denseOverrides+=@{relative='systems/native_render/live_world.gd';sha256=$digest;source='copied-only experimental route selection'}
}
foreach($pin in $densePins){if((DenseHash (Join-Path $denseCopy $pin.relative))-ne$pin.finalSha256){throw 'Final comparison input differs'}}
$densePrivateData=Join-Path $denseStage ($Variant+'-user-data');[IO.Directory]::CreateDirectory($densePrivateData)|Out-Null
$denseResult=@{schema=1;run=$Run;variant=$Variant;sourceProject=$denseCopy;sourceBytes=$denseBytes;sourcePins=$densePins;overrides=$denseOverrides;indexedRequested=[bool]$Indexed;engine=@{path=$denseEngine;sha256=(DenseHash $denseEngine)};checkpoint=@{path=$denseArchive;sha256=(DenseHash $denseArchive)};privateUserData=$densePrivateData;nativeBuilds=0;serverConnections=0;scope='Frozen source copy only. Baseline overlays exact prechange checkpoint; an indexed candidate changes only its copied route field. Unused copied candidate files are not historical source. No rendering, server or performance acceptance.'}
$denseReceipt=Join-Path $denseStage ($Variant+'-sources.json');[IO.File]::WriteAllText($denseReceipt,($denseResult|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
@{sourceProject=$denseCopy;variant=$Variant;pins=$densePins.Count;sourceBytes=$denseBytes;privateUserData=$densePrivateData;receipt=$denseReceipt;nativeBuilds=0}|ConvertTo-Json -Compress
