param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Run,[ValidatePattern('^[a-z0-9-]*$')][string]$Observation='',[ValidateRange(100,1000)][int]$IntervalMilliseconds=250,[ValidateRange(30,600)][int]$MaximumSeconds=420)
# Read only this run's verified client process. No game/driver changes, command
# injection, heap walking or process termination. OS commit/working-set counters
# remain available when release Godot's debug allocation counter is disabled.
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$expectedReport=Join-Path $project ('reports/'+$Run+'.native.json')
$output=Join-Path $project ('reports/'+$Run+'.process-memory'+$(if($Observation){'.'+$Observation}else{''})+'.json')
if(Test-Path -LiteralPath $output){throw 'Process-memory evidence already exists'}
$watcherSource=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
$needle=('--report='+$expectedReport).Replace('/','\')
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public sealed class NativeClientMemory : IDisposable {
 [StructLayout(LayoutKind.Sequential)] struct Counters {
  public uint cb, PageFaultCount;
  public UIntPtr PeakWorkingSetSize, WorkingSetSize, QuotaPeakPagedPoolUsage,
   QuotaPagedPoolUsage, QuotaPeakNonPagedPoolUsage, QuotaNonPagedPoolUsage,
   PagefileUsage, PeakPagefileUsage, PrivateUsage;
 }
 public sealed class Sample {
  public ulong PrivateBytes, WorkingSetBytes, PeakWorkingSetBytes;
  public double CpuMs;
 }
 [DllImport("kernel32.dll", SetLastError=true)] static extern SafeProcessHandle OpenProcess(uint access, bool inherit, int pid);
 [DllImport("kernel32.dll", SetLastError=true)] static extern bool K32GetProcessMemoryInfo(SafeProcessHandle process, ref Counters counters, uint size);
 [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetProcessTimes(SafeProcessHandle process, out long created, out long exited, out long kernel, out long user);
 readonly SafeProcessHandle process;
 public NativeClientMemory(int pid) {
  if (IntPtr.Size != 8 || Marshal.SizeOf<Counters>() != 80) throw new Exception("Unsupported Windows memory-counter ABI");
  process=OpenProcess(0x1000, false, pid); // PROCESS_QUERY_LIMITED_INFORMATION only.
  if (process.IsInvalid) { process.Dispose(); throw new Win32Exception(Marshal.GetLastWin32Error()); }
 }
 public Sample Read() {
  var counters=new Counters(); counters.cb=(uint)Marshal.SizeOf<Counters>();
  if (!K32GetProcessMemoryInfo(process, ref counters, counters.cb)) throw new Win32Exception(Marshal.GetLastWin32Error());
  long created, exited, kernel, user;
  if (!GetProcessTimes(process,out created,out exited,out kernel,out user)) throw new Win32Exception(Marshal.GetLastWin32Error());
  return new Sample { PrivateBytes=counters.PrivateUsage.ToUInt64(), WorkingSetBytes=counters.WorkingSetSize.ToUInt64(),
   PeakWorkingSetBytes=counters.PeakWorkingSetSize.ToUInt64(), CpuMs=(kernel+user)/10000.0 };
 }
 public void Dispose() { process.Dispose(); }
}
'@
$watcher=[Diagnostics.Process]::GetCurrentProcess();$cpuStart=$watcher.TotalProcessorTime.TotalMilliseconds
$samples=[Collections.Generic.List[object]]::new();$failure=$null;$client=$null;$identity=$null;$memoryReader=$null
$deadline=[DateTime]::UtcNow.AddSeconds($MaximumSeconds)
try{
 while([DateTime]::UtcNow-lt$deadline-and-not$client){
  if(Test-Path -LiteralPath (Join-Path $project ('reports/'+$Run+'.json'))){throw 'The owned run finished before a client could be observed'}
  foreach($candidate in Get-CimInstance Win32_Process -Filter "Name = 'Godot_v4.7.2-stable_win64.exe' OR Name = 'NwnReleaseTest.exe'"){
   $line=([string]$candidate.CommandLine).Replace('/','\');$offset=$line.IndexOf($needle,[StringComparison]::OrdinalIgnoreCase)
   if($offset-lt0){continue}
   $after=$offset+$needle.Length
   if(($offset-gt0-and$line[$offset-1]-ne'"'-and-not[char]::IsWhiteSpace($line[$offset-1]))-or($after-lt$line.Length-and$line[$after]-ne'"'-and-not[char]::IsWhiteSpace($line[$after]))){continue}
   # CIM can expose a just-created debugger child before ExecutablePath is
   # populated. Use the process image query too, then retry this same run if
   # creation is still incomplete; never accept an unverified empty path.
   try{$observed=[Diagnostics.Process]::GetProcessById($candidate.ProcessId)}catch{continue}
   $image=[string]$candidate.ExecutablePath
   if([string]::IsNullOrWhiteSpace($image)){try{$image=$observed.MainModule.FileName}catch{continue}}
   if([string]::IsNullOrWhiteSpace($image)){continue}
   $executable=[IO.Path]::GetFullPath($image)
   $editor=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
   $releaseRoot=(Join-Path $project '.cache/release-tests')+[IO.Path]::DirectorySeparatorChar
   if($executable-eq$editor){$expectedHash='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'}
   elseif($executable.StartsWith($releaseRoot,[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($executable)-eq'NwnReleaseTest.exe'){$expectedHash='d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'}
   else{throw 'Matched process executable is outside the owned runtime roots'}
   $digest=(Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant()
   if($digest-ne$expectedHash){throw 'Matched runtime hash differs from the pinned executable'}
   $client=$observed
   $identity=@{pid=$client.Id;start_unix_ms=[DateTimeOffset]::new($client.StartTime.ToUniversalTime()).ToUnixTimeMilliseconds();executable=$executable;executable_sha256=$digest}
   break
  }
  if(-not$client){Start-Sleep -Milliseconds $IntervalMilliseconds}
 }
 if(-not$client){throw 'No verified client for this run appeared before the deadline'}
 $memoryReader=[NativeClientMemory]::new($client.Id)
 while(-not$client.HasExited-and[DateTime]::UtcNow-lt$deadline){
  try{
   $query=[Diagnostics.Stopwatch]::StartNew();$reading=$memoryReader.Read()
   $sample=[ordered]@{unix_ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();private_bytes=$reading.PrivateBytes;working_set_bytes=$reading.WorkingSetBytes;peak_working_set_bytes=$reading.PeakWorkingSetBytes;cpu_ms=$reading.CpuMs}
   $query.Stop();$sample.query_ms=$query.Elapsed.TotalMilliseconds;$samples.Add($sample)
  }catch{if($client.HasExited){break}else{throw}}
  Start-Sleep -Milliseconds $IntervalMilliseconds
 }
 if(-not$client.HasExited){throw 'Memory observation deadline reached; the client was left running'}
 if($samples.Count-lt5){throw 'Too few process samples for a valid measurement'}
}catch{$failure=$_.Exception.Message}finally{if($memoryReader){$memoryReader.Dispose()}}
$watcher.Refresh()
$unchanged=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()-eq$watcherSource
$result=[ordered]@{success=($null-eq$failure-and$unchanged);failure=$failure;run=$Run;observation=$Observation;identity=$identity;interval_ms=$IntervalMilliseconds;source_sha256=$watcherSource;source_unchanged=$unchanged;counter_api='K32GetProcessMemoryInfo/PROCESS_MEMORY_COUNTERS_EX and GetProcessTimes; query-limited owned handle';watcher_cpu_ms=($watcher.TotalProcessorTime.TotalMilliseconds-$cpuStart);samples=$samples.ToArray();scope='Windows process private commit and resident working set for the exact verified owned client; not isolated particle allocations or live-heap accounting. Only probe windows with matching PID/time ranges may be compared.'}
[IO.File]::WriteAllText($output,($result|ConvertTo-Json -Depth 6)+[Environment]::NewLine)
if(-not$result.success){throw ('Process memory observation failed: '+$failure)}
Write-Output (@{success=$true;report=$output;samples=$samples.Count}|ConvertTo-Json -Compress)
