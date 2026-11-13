param([ValidateSet('validate','observe')][string]$Mode='validate',[ValidatePattern('^[a-z0-9-]*$')][string]$Run='',[ValidatePattern('^[a-z0-9-]*$')][string]$Observation='',[ValidateRange(250,2000)][int]$IntervalMilliseconds=500,[ValidateRange(5,600)][int]$MaximumSeconds=180)
# Read-only, exact owned native process. Default mode compiles the query helper
# without reading a process. Observation never starts/stops/suspends a client.
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceHash=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
if(-not('OwnedNativeThreadReader' -as [type])){
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public sealed class OwnedNativeThreadReader : IDisposable {
 public sealed class ProcessSample { public long Created, Exited; public double CpuMs; }
 public sealed class ThreadSample { public int Id, Owner; public long Created; public double KernelMs, UserMs; public string Name; public int Error; public bool Available; }
 [DllImport("kernel32.dll",SetLastError=true)] static extern SafeProcessHandle OpenProcess(uint access,bool inherit,int id);
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenThread(uint access,bool inherit,int id);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetProcessTimes(SafeProcessHandle handle,out long created,out long exited,out long kernel,out long user);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetThreadTimes(IntPtr handle,out long created,out long exited,out long kernel,out long user);
 [DllImport("kernel32.dll",SetLastError=true)] static extern uint GetProcessIdOfThread(IntPtr handle);
 [DllImport("kernel32.dll")] static extern int GetThreadDescription(IntPtr handle,out IntPtr description);
 [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr memory);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 readonly SafeProcessHandle process; readonly int owner;
 public OwnedNativeThreadReader(int id) { owner=id; process=OpenProcess(0x1000,false,id); if(process.IsInvalid){process.Dispose();throw new Win32Exception(Marshal.GetLastWin32Error());} }
 public ProcessSample ReadProcess() { long c,e,k,u;if(!GetProcessTimes(process,out c,out e,out k,out u))throw new Win32Exception(Marshal.GetLastWin32Error());return new ProcessSample{Created=c,Exited=e,CpuMs=(k+u)/10000.0}; }
 public ThreadSample ReadThread(int id) {
  var result=new ThreadSample{Id=id};var handle=OpenThread(0x0800,false,id);
  if(handle==IntPtr.Zero){result.Error=Marshal.GetLastWin32Error();return result;}
  IntPtr description=IntPtr.Zero;
  try {
   result.Owner=(int)GetProcessIdOfThread(handle);if(result.Owner!=owner)return result;
   long c,e,k,u;if(!GetThreadTimes(handle,out c,out e,out k,out u)){result.Error=Marshal.GetLastWin32Error();return result;}
   result.Created=c;result.KernelMs=k/10000.0;result.UserMs=u/10000.0;result.Available=true;
   if(GetThreadDescription(handle,out description)==0&&description!=IntPtr.Zero)result.Name=Marshal.PtrToStringUni(description);
   return result;
  } finally {if(description!=IntPtr.Zero)LocalFree(description);CloseHandle(handle);}
 }
 public void Dispose(){process.Dispose();}
}
'@
}
if($Mode-eq'validate'){
 @{success=$true;mode='validate';processReads=0;sourceSha256=$sourceHash;scope='Helper compilation only; no native client observation, trace or workload launch'}|ConvertTo-Json -Compress
 return
}
if(-not$Run){throw 'Observe mode requires an explicit owned run label'}
$output=Join-Path $project ('reports/'+$Run+'.thread-cpu'+$(if($Observation){'.'+$Observation}else{''})+'.json')
if(Test-Path -LiteralPath $output){throw 'Prior thread evidence is preserved'}
$needle=('--report='+(Join-Path $project ('reports/'+$Run+'.native.json'))).Replace('/','\')
$allowed=@{}
$allowed[(Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe')]='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
$allowed[(Join-Path $project '.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/build-1793998835313/binaries/godot.windows.template_release.x86_64.exe')]='62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc'
$watcher=[Diagnostics.Process]::GetCurrentProcess();$watcherStart=$watcher.TotalProcessorTime.TotalMilliseconds
$clock=[Diagnostics.Stopwatch]::StartNew();$samples=[Collections.Generic.List[object]]::new();$client=$null;$reader=$null;$identity=$null;$failure=$null;$ended='deadline';$discovery=@()
try{
 while(-not$client-and$clock.Elapsed.TotalSeconds-lt30){
  foreach($candidate in Get-CimInstance Win32_Process -Filter "Name = 'Godot_v4.7.2-stable_win64.exe' OR Name = 'godot.windows.template_release.x86_64.exe'"){
   $line=([string]$candidate.CommandLine).Replace('/','\');$offset=$line.IndexOf($needle,[StringComparison]::OrdinalIgnoreCase)
   if($offset-lt0){continue};$after=$offset+$needle.Length
   if(($offset-gt0-and$line[$offset-1]-ne'"'-and-not[char]::IsWhiteSpace($line[$offset-1]))-or($after-lt$line.Length-and$line[$after]-ne'"'-and-not[char]::IsWhiteSpace($line[$after]))){continue}
   $image=[string]$candidate.ExecutablePath;if([string]::IsNullOrWhiteSpace($image)){continue};$image=[IO.Path]::GetFullPath($image)
   if(-not$allowed.ContainsKey($image)){throw 'Matched client is outside the exact supported runtime paths'}
   if((Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash.ToLowerInvariant()-ne$allowed[$image]){throw 'Matched client executable hash differs'}
   $observed=[Diagnostics.Process]::GetProcessById([int]$candidate.ProcessId);$created=$observed.StartTime.ToUniversalTime().ToFileTimeUtc()
   $probe=[OwnedNativeThreadReader]::new($observed.Id);$first=$probe.ReadProcess()
   if($first.Created-ne$created-or$first.Exited-ne0){$probe.Dispose();continue}
   $client=$observed;$reader=$probe
   $identity=@{processId=$client.Id;createdFileTimeUtc=$created;executable=$image;executableSha256=$allowed[$image];logicalProcessors=[Environment]::ProcessorCount;processorAffinityHex=$client.ProcessorAffinity.ToInt64().ToString('x')};break
  }
  if(-not$client){Start-Sleep -Milliseconds $IntervalMilliseconds}
 }
 if(-not$client){throw 'No live verified native process for this run'}
 $start=$clock.Elapsed.TotalMilliseconds
 while($clock.Elapsed.TotalMilliseconds-$start-lt$MaximumSeconds*1000){
  $query=[Diagnostics.Stopwatch]::StartNew();$processReading=$reader.ReadProcess()
  if($processReading.Created-ne$identity.createdFileTimeUtc){throw 'Owned process lifetime changed'}
  if($processReading.Exited-ne0){$ended='process-exited';break}
  $client.Refresh();$threads=[Collections.Generic.List[object]]::new();$unavailable=0
  foreach($thread in $client.Threads){
   try{
    $value=$reader.ReadThread($thread.Id);if(-not$value.Available){$unavailable+=1;continue}
    $state=$null;$wait=$null;try{$state=$thread.ThreadState.ToString();if($state-eq'Wait'){$wait=$thread.WaitReason.ToString()}}catch{}
    $threads.Add(@{id=$value.Id;createdFileTimeUtc=$value.Created;name=$value.Name;kernelMs=$value.KernelMs;userMs=$value.UserMs;state=$state;waitReason=$wait})
   }finally{$thread.Dispose()}
  }
  $query.Stop();$samples.Add(@{unixMs=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();elapsedMs=$clock.Elapsed.TotalMilliseconds-$start;processCpuMs=$processReading.CpuMs;threads=$threads.ToArray();unavailableThreads=$unavailable;queryMs=$query.Elapsed.TotalMilliseconds})
  Start-Sleep -Milliseconds $IntervalMilliseconds
 }
 if($samples.Count-lt3){throw 'Too few owned thread samples'}
}catch{$failure=$_.Exception.Message}finally{if($reader){$reader.Dispose()}}
$watcher.Refresh();$unchanged=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()-eq$sourceHash
$result=@{version=1;success=($null-eq$failure-and$unchanged);failure=$failure;run=$Run;identity=$identity;ended=$ended;sourceSha256=$sourceHash;sourceUnchanged=$unchanged;intervalMs=$IntervalMilliseconds;watcherCpuMs=($watcher.TotalProcessorTime.TotalMilliseconds-$watcherStart);samples=$samples.ToArray();scope='Read-only exact-run process/thread CPU counters and instantaneous scheduling state. Short-lived threads may be missed. Wait labels are snapshots, not wait durations/stacks. No ETW/global trace, affinity/priority change, process suspension or termination. Godot internal thread IDs differ from Windows thread IDs.'}
$stream=[IO.File]::Open($output,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try{$bytes=[Text.Encoding]::UTF8.GetBytes(($result|ConvertTo-Json -Depth 8)+[Environment]::NewLine);$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
if(-not$result.success){throw ('Owned thread observation failed: '+$failure)}
@{success=$true;report=$output;samples=$samples.Count;ended=$ended}|ConvertTo-Json -Compress
