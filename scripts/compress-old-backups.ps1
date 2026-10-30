param([switch]$Apply,[switch]$Sample,[ValidateRange(1,3650)][int]$MinimumAgeDays=1)
$ErrorActionPreference='Stop'
$backupWorkspace=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$backupRoots=@('backups','godot-client/backups')|ForEach-Object{[IO.Path]::GetFullPath((Join-Path $backupWorkspace $_))}
$backupCutoff=[DateTime]::UtcNow.AddDays(-$MinimumAgeDays)
$backupRun='backup-compression-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$backupReportPath=Join-Path $backupWorkspace ('godot-client/reports/'+$backupRun+'.json')
$backupLogPath=Join-Path $backupWorkspace ('godot-client/reports/'+$backupRun+'.compact.log')
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
public static class BackupFileAllocation {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 static extern uint GetCompressedFileSizeW(string path,out uint high);
 public static long Bytes(string path) {
  uint high;uint low=GetCompressedFileSizeW(path,out high);
  if(low==0xffffffff && Marshal.GetLastWin32Error()!=0) throw new IOException("Cannot measure allocated file size");
  return checked((long)(((ulong)high<<32)|low));
 }
 public static string Hash(string path) {
  using(var stream=File.OpenRead(path)) using(var sha=System.Security.Cryptography.SHA256.Create()) {
   return Convert.ToHexString(sha.ComputeHash(stream)).ToLowerInvariant();
  }
 }
}
'@
$backupProcesses=@(Get-CimInstance Win32_Process)
$backupEntries=[Collections.Generic.List[object]]::new()
$backupErrors=[Collections.Generic.List[object]]::new()
$backupRecent=0;$backupLinks=0;$backupActive=0
foreach($backupRoot in $backupRoots){
 if(-not$backupRoot.StartsWith($backupWorkspace+'\',[StringComparison]::OrdinalIgnoreCase)-or(Get-Item -LiteralPath $backupRoot -Force).Attributes-band[IO.FileAttributes]::ReparsePoint){throw 'Unexpected backup root'}
 $backupRootInUse=$false
 foreach($backupProcess in $backupProcesses){
  $executable=([string]$backupProcess.ExecutablePath).Replace('/','\')
  $command=([string]$backupProcess.CommandLine).Replace('/','\')
  if($executable.StartsWith($backupRoot+'\',[StringComparison]::OrdinalIgnoreCase)-or$command.IndexOf($backupRoot+'\',[StringComparison]::OrdinalIgnoreCase)-ge0){$backupRootInUse=$true;break}
 }
 $readErrors=@()
 foreach($backupFile in Get-ChildItem -LiteralPath $backupRoot -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable +readErrors){
  $backupPath=[IO.Path]::GetFullPath($backupFile.FullName)
  if(-not$backupPath.StartsWith($backupRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'File escaped backup root'}
  if($Sample-and$backupPath-ne(Join-Path $backupWorkspace 'backups/animations/local-network-peer-v1.json')){continue}
  if($backupFile.Attributes-band[IO.FileAttributes]::ReparsePoint){$backupLinks++;continue}
  if($backupFile.LastWriteTimeUtc-ge$backupCutoff){$backupRecent++;continue}
  # Profiles or tools actually running from a backup tree remain untouched.
  if($backupRootInUse){$backupActive++;continue}
  $backupEntries.Add([PSCustomObject]@{path=$backupPath.Substring($backupWorkspace.Length+1).Replace('\','/');length=[long]$backupFile.Length;beforeAllocated=[long]0;afterAllocated=[long]0;sha256='';verified=$false;error=$null})
 }
 foreach($readError in $readErrors){$backupErrors.Add([PSCustomObject]@{stage='inventory';message=$readError.Exception.Message})}
}
$backupReport=[ordered]@{algorithm='Windows transparent LZX';apply=[bool]$Apply;sample=[bool]$Sample;cutoffUtc=$backupCutoff;recentPreserved=$backupRecent;linksPreserved=$backupLinks;activePreserved=$backupActive;files=$backupEntries;errors=$backupErrors;success=$false}
Write-Output("Inventory: {0} eligible backup files; recent checkpoints preserved: {1}"-f$backupEntries.Count,$backupRecent)
$backupIndex=0
foreach($backupEntry in $backupEntries){
 $backupPath=Join-Path $backupWorkspace $backupEntry.path
 try{$backupEntry.beforeAllocated=[BackupFileAllocation]::Bytes($backupPath);$backupEntry.sha256=[BackupFileAllocation]::Hash($backupPath)}
 catch{$backupEntry.error=$_.Exception.Message;$backupErrors.Add([PSCustomObject]@{stage='hash-before';path=$backupEntry.path;message=$_.Exception.Message})}
 $backupIndex++;if($backupIndex%10000-eq0){Write-Output("Hashed {0}/{1} files before compression"-f$backupIndex,$backupEntries.Count)}
}
[IO.File]::WriteAllText($backupReportPath,($backupReport|ConvertTo-Json -Depth 5))
if($Apply){
 $backupBatch=[Collections.Generic.List[string]]::new();$backupBatchChars=0;$backupProcessed=0
 $compressBatch={
  if(-not$backupBatch.Count){return}
  & "$env:SystemRoot/System32/compact.exe" /C /A /I /F /EXE:LZX /Q @backupBatch >> $backupLogPath 2>&1
  if($LASTEXITCODE-ne0){$backupErrors.Add([PSCustomObject]@{stage='compact';message='One or more files could not be compressed; inspect the compact log';exitCode=$LASTEXITCODE})}
 }
 foreach($backupEntry in $backupEntries){
  if($backupEntry.error){continue}
  $backupPath=Join-Path $backupWorkspace $backupEntry.path
  if($backupBatch.Count-ge100-or$backupBatchChars+$backupPath.Length-gt14000){. $compressBatch;$backupProcessed+=$backupBatch.Count;$backupBatch.Clear();$backupBatchChars=0;if($backupProcessed%1000-eq0){Write-Output("Compressed {0}/{1} files"-f$backupProcessed,$backupEntries.Count)}}
  $backupBatch.Add($backupPath);$backupBatchChars+=$backupPath.Length+3
 }
 . $compressBatch
}
$backupIndex=0
foreach($backupEntry in $backupEntries){
 if($backupEntry.error){continue}
 $backupPath=Join-Path $backupWorkspace $backupEntry.path
 try{
  $backupEntry.afterAllocated=[BackupFileAllocation]::Bytes($backupPath)
  $backupEntry.verified=([BackupFileAllocation]::Hash($backupPath)-eq$backupEntry.sha256)-and(Get-Item -LiteralPath $backupPath).Length-eq$backupEntry.length
  if(-not$backupEntry.verified){throw 'File content changed; inspect before using this backup'}
 }catch{$backupEntry.error=$_.Exception.Message;$backupErrors.Add([PSCustomObject]@{stage='hash-after';path=$backupEntry.path;message=$_.Exception.Message})}
 $backupIndex++;if($backupIndex%10000-eq0){Write-Output("Verified {0}/{1} files after compression"-f$backupIndex,$backupEntries.Count)}
}
$backupReport.logicalBytes=($backupEntries|Measure-Object length -Sum).Sum
$backupReport.beforeAllocated=($backupEntries|Measure-Object beforeAllocated -Sum).Sum
$backupReport.afterAllocated=($backupEntries|Measure-Object afterAllocated -Sum).Sum
$backupReport.savedGiB=[Math]::Round(($backupReport.beforeAllocated-$backupReport.afterAllocated)/1GB,3)
$backupReport.verified=@($backupEntries|Where-Object verified).Count
$backupReport.success=$backupReport.verified-eq$backupEntries.Count-and$backupErrors.Count-eq0
[IO.File]::WriteAllText($backupReportPath,($backupReport|ConvertTo-Json -Depth 5))
[PSCustomObject]@{success=$backupReport.success;files=$backupEntries.Count;verified=$backupReport.verified;errors=$backupErrors.Count;beforeGiB=[Math]::Round($backupReport.beforeAllocated/1GB,3);afterGiB=[Math]::Round($backupReport.afterAllocated/1GB,3);savedGiB=$backupReport.savedGiB;report=$backupReportPath}|ConvertTo-Json -Compress
