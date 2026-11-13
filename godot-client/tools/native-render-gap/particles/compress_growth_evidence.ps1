param([Parameter(Mandatory=$true)][string]$Manifest,[Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Run)
$ErrorActionPreference='Stop'
(Get-Process -Id $PID).PriorityClass='BelowNormal'
$growthProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$growthWorkspace=[IO.Path]::GetFullPath((Join-Path $growthProject '..'))
$growthManifestPath=[IO.Path]::GetFullPath($Manifest)
$growthExpectedManifest='2df68171d1823375fdff6e73fac06cfcd21092f5c9ea6cfa6069f5498d260939'
$growthExpectedSource='4553daad7d614e5d9f6e353be56df6356aa717d9c220c491e5c9af6e103a3e12'
if((Get-FileHash -LiteralPath $growthManifestPath).Hash.ToLowerInvariant()-ne$growthExpectedManifest){throw 'Exact approved505-path manifest required'}
$growthRows=@(Get-Content -LiteralPath $growthManifestPath -Raw|ConvertFrom-Json)
if($growthRows.Count-ne505-or($growthRows|Measure-Object bytes -Sum).Sum-ne6234430939){throw 'Approved count/length differs'}
$growthAllowed=@('.cache/native-render-gap/replays','.cache/native-render-gap/scene/normal-integration-a','.cache/native-render-gap/scene/normal-integration-b','.cache/native-presentation-parity/production-replay')|ForEach-Object{[IO.Path]::GetFullPath((Join-Path $growthProject $_))+'\'}
$growthSeen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$growthParentChecks=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
function Assert-GrowthFile($row){
 $absolute=[IO.Path]::GetFullPath($row.file);$allowed=$false
 foreach($prefix in $growthAllowed){if($absolute.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){$allowed=$true}}
 if(-not$allowed-or$row.action-ne'ntfs-compress-only'-or$row.delete-ne$false-or[IO.Path]::GetExtension($absolute)-ne'.json'-or$row.expectedSha256-notmatch'^[a-f0-9]{64}$'){throw 'Nonapproved compression path/action'}
 $info=[IO.FileInfo]::new($absolute)
 if(-not$info.Exists-or$info.Length-ne$row.bytes-or($info.Attributes-band([IO.FileAttributes]::Directory-bor[IO.FileAttributes]::ReparsePoint))){throw 'File length/lifetime/type differs'}
 if([Math]::Abs(($info.LastWriteTimeUtc-([datetime]$row.modifiedUtc).ToUniversalTime()).TotalMilliseconds)-gt1){throw 'File was modified after the audited manifest'}
 $parent=$info.Directory
 while($parent-and$parent.FullName.StartsWith($growthProject+'\',[StringComparison]::OrdinalIgnoreCase)){
  if($growthParentChecks.Add($parent.FullName)-and($parent.Attributes-band[IO.FileAttributes]::ReparsePoint)){throw 'Reparse parent is not allowed'}
  $parent=$parent.Parent
 }
 return $absolute
}
function Get-GrowthSource {
 Push-Location -LiteralPath $growthWorkspace
 try{$identity=(& node -e "console.log(require('./godot-client/tools/native-feature-manifest.cjs').sourceIdentity(require('path').resolve('godot-client')).sha256)").Trim();if($LASTEXITCODE-ne0){throw 'Source identity query failed'};return $identity}finally{Pop-Location}
}
if((Get-GrowthSource)-ne$growthExpectedSource){throw 'Installed C source changed before compression'}
$growthOutput=Join-Path $growthProject ('.cache/prune-audit-20261108/'+$Run)
if(Test-Path -LiteralPath $growthOutput){throw 'Retain prior action journal; never blindly rerun'}
$growthDrive=[IO.DriveInfo]::new('C:\')
if($growthDrive.DriveFormat-ne'NTFS'){throw 'Transparent compression requires NTFS'}
foreach($row in $growthRows){$absolute=Assert-GrowthFile $row;if(-not$growthSeen.Add($absolute)){throw 'Duplicate approved path'}}
New-Item -ItemType Directory -Path $growthOutput|Out-Null
Copy-Item -LiteralPath $growthManifestPath -Destination (Join-Path $growthOutput 'input-manifest.json')
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $growthOutput 'executor.ps1')
$growthFreeBefore=$growthDrive.AvailableFreeSpace;$growthStarted=[DateTime]::UtcNow.ToString('o')
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using Microsoft.Win32.SafeHandles;
public sealed class GrowthCompressionResult {
 public string file,sha256,afterSha256,status,error;
 public long bytes;
 public ulong storedBytesBefore,storedBytesAfter,reclaimedBytes;
 public bool alreadyCompressed,contentUnchanged;
}
public static class GrowthNtfsEvidence {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetCompressedFileSizeW(string file,out uint high);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool DeviceIoControl(SafeFileHandle file,uint code,ref ushort format,uint inputBytes,IntPtr output,uint outputBytes,out uint returned,IntPtr overlapped);
 static string Long(string file){return file.StartsWith(@"\\?\")?file:@"\\?\"+file;}
 static ulong Stored(string file){uint high;uint low=GetCompressedFileSizeW(Long(file),out high);if(low==UInt32.MaxValue&&Marshal.GetLastWin32Error()!=0)throw new Win32Exception(Marshal.GetLastWin32Error());return ((ulong)high<<32)|low;}
 static string Hash(Stream file){file.Position=0;using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(file)).Replace("-","").ToLowerInvariant();}
 public static GrowthCompressionResult Inspect(string file,string expected,long length){
  var result=new GrowthCompressionResult{file=file,status="preflight"};
  try{using(var stream=new FileStream(Long(file),FileMode.Open,FileAccess.Read,FileShare.Read,1024*1024,FileOptions.SequentialScan)){
   result.bytes=stream.Length;result.sha256=Hash(stream);result.storedBytesBefore=Stored(file);result.alreadyCompressed=(File.GetAttributes(Long(file))&FileAttributes.Compressed)!=0;
   if(result.bytes!=length||result.sha256!=expected){result.status="skip-mismatch";result.error="Expected bytes/hash differ";}else result.contentUnchanged=true;
  }}catch(Exception error){result.status="skip-writer-or-access";result.error=error.Message;}
  return result;
 }
 public static GrowthCompressionResult Compress(string file,string expected,long length){
  var result=new GrowthCompressionResult{file=file,status="compressed"};FileStream stream;
  try{stream=new FileStream(Long(file),FileMode.Open,FileAccess.ReadWrite,FileShare.Read,1024*1024,FileOptions.SequentialScan);}catch(Exception error){result.status="skip-writer-or-access";result.error=error.Message;return result;}
  using(stream){
   result.bytes=stream.Length;result.sha256=Hash(stream);
   if(result.bytes!=length||result.sha256!=expected){result.status="skip-mismatch";result.error="Expected bytes/hash differ under writer-excluding handle";return result;}
   result.storedBytesBefore=Stored(file);result.alreadyCompressed=(File.GetAttributes(Long(file))&FileAttributes.Compressed)!=0;
   if(!result.alreadyCompressed){ushort format=2;uint returned;if(!DeviceIoControl(stream.SafeFileHandle,0x9c040,ref format,2,IntPtr.Zero,0,out returned,IntPtr.Zero))throw new Win32Exception(Marshal.GetLastWin32Error());stream.Flush();}
   result.afterSha256=Hash(stream);result.contentUnchanged=result.bytes==stream.Length&&result.sha256==result.afterSha256;
   if(!result.contentUnchanged)throw new IOException("Content changed after FSCTL compression; stop immediately");
   result.storedBytesAfter=Stored(file);result.reclaimedBytes=result.storedBytesBefore>result.storedBytesAfter?result.storedBytesBefore-result.storedBytesAfter:0;
  }
  return result;
 }
}
'@
$growthPreflightJournal=Join-Path $growthOutput 'preflight.jsonl';$growthActionJournal=Join-Path $growthOutput 'actions.jsonl'
$growthAdmitted=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$growthCompleted=0;$growthSkipped=0;$growthStoredBefore=0L;$growthStoredAfter=0L;$growthSaved=0L
$growthActiveFile=$null
function Append-GrowthJournal([string]$file,$value){[IO.File]::AppendAllText($file,($value|ConvertTo-Json -Depth 6 -Compress)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))}
try{
 foreach($row in $growthRows){
  try{$absolute=Assert-GrowthFile $row;$result=[GrowthNtfsEvidence]::Inspect($absolute,$row.expectedSha256,[long]$row.bytes)}catch{$result=@{file=$row.file;status='skip-changed-metadata';error=$_.Exception.Message}}
  Append-GrowthJournal $growthPreflightJournal $result
  if($result.status-eq'preflight' -and$result.contentUnchanged){[void]$growthAdmitted.Add($row.file)}
 }
 if((Get-GrowthSource)-ne$growthExpectedSource){throw 'Installed C source changed during full preflight'}
 @{stage='preflight';admitted=$growthAdmitted.Count;total=$growthRows.Count;mutationCount=0}|ConvertTo-Json -Compress
 for($offset=0;$offset-lt$growthRows.Count;$offset+=50){
  $chunk=[Math]::Floor($offset/50);$chunkStarted=[DateTime]::UtcNow.ToString('o');$chunkDone=0;$chunkSkipped=0;$chunkSaved=0L
  foreach($row in @($growthRows|Select-Object -Skip $offset -First 50)){
   $growthActiveFile=$row.file
   if(-not$growthAdmitted.Contains($row.file)){$result=@{file=$row.file;status='skip-preflight';mutation=$false}}
   else{
    try{$absolute=Assert-GrowthFile $row}catch{$result=@{file=$row.file;status='skip-changed-metadata';error=$_.Exception.Message};Append-GrowthJournal $growthActionJournal $result;$growthSkipped++;$chunkSkipped++;continue}
    $result=[GrowthNtfsEvidence]::Compress($absolute,$row.expectedSha256,[long]$row.bytes)
   }
   Append-GrowthJournal $growthActionJournal $result
   if($result.status-eq'compressed'){$growthCompleted++;$chunkDone++;$growthStoredBefore+=[long]$result.storedBytesBefore;$growthStoredAfter+=[long]$result.storedBytesAfter;$growthSaved+=[long]$result.reclaimedBytes;$chunkSaved+=[long]$result.reclaimedBytes}else{$growthSkipped++;$chunkSkipped++}
  }
  if((Get-GrowthSource)-ne$growthExpectedSource){throw 'Installed C source changed during compression'}
  $chunkReceipt=@{chunk=$chunk;startedUtc=$chunkStarted;finishedUtc=[DateTime]::UtcNow.ToString('o');compressed=$chunkDone;skipped=$chunkSkipped;storedBytesSaved=$chunkSaved;sourceIdentity=$growthExpectedSource}
  $chunkReceipt|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $growthOutput ('chunk-'+$chunk.ToString('000')+'.json')) -Encoding utf8
  @{stage='chunk';chunk=$chunk;completed=$growthCompleted;skipped=$growthSkipped;total=$growthRows.Count;storedBytesSaved=$growthSaved}|ConvertTo-Json -Compress
 }
 $growthSourceAfter=Get-GrowthSource
 if($growthSourceAfter-ne$growthExpectedSource-or(Get-FileHash -LiteralPath $growthManifestPath).Hash.ToLowerInvariant()-ne$growthExpectedManifest){throw 'Source/approved manifest identity changed'}
 $summary=@{version=1;success=$growthCompleted+$growthSkipped-eq505;allFilesCompressed=$growthCompleted-eq505;startedUtc=$growthStarted;finishedUtc=[DateTime]::UtcNow.ToString('o');files=$growthRows.Count;compressed=$growthCompleted;skipped=$growthSkipped;logicalBytes=6234430939;storedBytesBefore=$growthStoredBefore;storedBytesAfter=$growthStoredAfter;storedBytesSaved=$growthSaved;volumeFreeBytesBefore=$growthFreeBefore;volumeFreeBytesAfter=[IO.DriveInfo]::new('C:\').AvailableFreeSpace;sourceBefore=$growthExpectedSource;sourceAfter=$growthSourceAfter;manifestSha256=$growthExpectedManifest;deletedFiles=0;semanticByteWrites=0;scope='Approved exact505copied dossiers only; writer-excluding handles; exact expected bytes/hash verified before and after each FSCTL compression; all source/evidence paths retained'}
 $summary|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $growthOutput 'summary.json') -Encoding utf8
 $summary|ConvertTo-Json -Compress
}catch{
 @{success=$false;completed=$growthCompleted;skipped=$growthSkipped;storedBytesSaved=$growthSaved;activeFile=$growthActiveFile;error=$_.Exception.Message;scope='Partial per-file journals retained. Do not rerun blindly.'}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $growthOutput 'failure.json') -Encoding utf8
 throw
}
