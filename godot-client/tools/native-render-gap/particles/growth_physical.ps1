param([Parameter(Mandatory=$true)][string]$Inventory,[Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label)
$ErrorActionPreference='Stop'
(Get-Process -Id $PID).PriorityClass='BelowNormal'
$growthProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$growthOutput=Join-Path $growthProject ('.cache/prune-audit-20261108/'+$Label)
if(Test-Path -LiteralPath $growthOutput){throw 'Retain prior physical-size audit'}
$growthInput=Get-Content -LiteralPath $Inventory -Raw|ConvertFrom-Json
$growthInputSha=(Get-FileHash -LiteralPath $Inventory).Hash.ToLowerInvariant()
$growthRoots=@((Join-Path $growthProject '.cache/native-render-gap'),(Join-Path $growthProject '.cache/native-presentation-parity/production-replay'))
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RenderGapGrowthDiskSize {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 private static extern uint GetCompressedFileSizeW(string file,out uint high);
 public static ulong Read(string file) {
  string native=file.StartsWith(@"\\?\")?file:@"\\?\"+file;
  uint high;uint low=GetCompressedFileSizeW(native,out high);
  int error=Marshal.GetLastWin32Error();
  if(low==UInt32.MaxValue&&error!=0)throw new System.ComponentModel.Win32Exception(error);
  return ((ulong)high<<32)|low;
 }
}
'@
function Assert-GrowthPath([string]$file){
 $full=[IO.Path]::GetFullPath($file);$allowed=$false
 foreach($root in $growthRoots){if($full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$allowed=$true}}
 if(-not $allowed){throw 'File escapes the two audited roots'}
 return $full
}
$growthRows=@();$growthStarted=[DateTime]::UtcNow.ToString('o')
foreach($growthFile in $growthInput.largestFiles){
 if($growthFile.extension-notin@('.json','.jsonl')){continue}
 $growthFull=Assert-GrowthPath $growthFile.file
 $growthInfo=Get-Item -LiteralPath $growthFull
 $growthCompressed=($growthInfo.Attributes-band[IO.FileAttributes]::Compressed)-ne0
 $growthRows+=[PSCustomObject]@{file=$growthFull;bytes=$growthInfo.Length;allocatedBytes=[RenderGapGrowthDiskSize]::Read($growthFull);modifiedUtc=$growthInfo.LastWriteTimeUtc.ToString('o');compressed=$growthCompressed;linksAtInventory=$growthFile.links;unchangedLogicalLength=$growthInfo.Length-eq$growthFile.bytes}
}
$growthSamples=@();$growthHashBytes=0L;$growthHashLimit=160MB
foreach($growthGroup in $growthInput.sameNameSizeDuplicateHints){
 if($growthGroup.name-notlike'*.json'-or$growthSamples.Count-ge5){continue}
 if($growthHashBytes+2*$growthGroup.bytesEach-gt$growthHashLimit){continue}
 $growthProofs=@()
 foreach($growthFile in @($growthGroup.files|Select-Object -First 2)){
  $growthFull=Assert-GrowthPath $growthFile.file
  $growthProofs+=[PSCustomObject]@{file=$growthFull;bytes=(Get-Item -LiteralPath $growthFull).Length;sha256=(Get-FileHash -LiteralPath $growthFull).Hash.ToLowerInvariant()}
  $growthHashBytes+=$growthFile.bytes
 }
 $growthSamples+=[PSCustomObject]@{name=$growthGroup.name;inventoryCopies=$growthGroup.count;equalSampleHashes=($growthProofs[0].sha256-eq$growthProofs[1].sha256);sampledFiles=$growthProofs;scope='Two exact sampled copies only; do not infer hashes for all other files'}
}
New-Item -ItemType Directory -Path $growthOutput|Out-Null
$growthResult=[PSCustomObject]@{version=1;startedUtc=$growthStarted;finishedUtc=[DateTime]::UtcNow.ToString('o');inventory=[IO.Path]::GetFullPath($Inventory);inventorySha256=$growthInputSha;files=$growthRows.Count;logicalBytes=($growthRows|Measure-Object bytes -Sum).Sum;allocatedBytes=($growthRows|Measure-Object allocatedBytes -Sum).Sum;alreadyCompressedFiles=@($growthRows|Where-Object compressed).Count;hashBytesRead=$growthHashBytes;rows=$growthRows;duplicateSamples=$growthSamples;mutations=0;scope='Read-only GetCompressedFileSizeW and attributes plus bounded duplicate samples. No NTFS compression/deletion/hardlink operation. Physical totals can still double-count hardlinks and exclude NTFS metadata.'}
$growthResult|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $growthOutput 'physical.json') -Encoding utf8
$growthResult|Select-Object files,logicalBytes,allocatedBytes,alreadyCompressedFiles,hashBytesRead,duplicateSamples|ConvertTo-Json -Depth 5
