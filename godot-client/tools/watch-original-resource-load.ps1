param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-original-resource-baseline-v2',[ValidateRange(1,60)][int]$Seconds=20,[ValidatePattern('^[a-z0-9-]*$')][string]$OutputRun='')
$ErrorActionPreference='Stop'
$watchProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$watchReport=Join-Path $watchProject ('reports/'+$(if($OutputRun){$OutputRun}else{$Run})+'.residency.json')
if(Test-Path -LiteralPath $watchReport){throw 'Original residency report already exists'}
$watchLaunch=Get-Content (Join-Path $watchProject ('reports/'+$Run+'.json')) -Raw|ConvertFrom-Json
$watchProcess=Get-Process -Id $watchLaunch.pid
if($watchProcess.ProcessName-ne'nwmain'-or(Get-FileHash -LiteralPath $watchProcess.Path -Algorithm SHA256).Hash.ToLowerInvariant()-ne$watchLaunch.sha256){throw 'Pinned owned original client is required'}
$watchCommand=Get-CimInstance Win32_Process -Filter ('ProcessId='+$watchProcess.Id)
if(-not$watchCommand.CommandLine.Contains($watchLaunch.profile)-or-not$watchCommand.CommandLine.Contains('127.0.0.1:5121')){throw 'Only the owned isolated localhost original is observed'}
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
public static class OriginalResourceReadOnly {
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,int id);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool ReadProcessMemory(IntPtr handle,IntPtr address,byte[] bytes,UIntPtr size,out UIntPtr read);
 static byte[] Read(IntPtr handle,long address,int count){var bytes=new byte[count];UIntPtr read;if(address<=0||!ReadProcessMemory(handle,new IntPtr(address),bytes,(UIntPtr)count,out read)||read.ToUInt64()!=(ulong)count)return null;return bytes;}
 public sealed class Sample {public long elapsedMs;public string utc;public int models;public int inputActive=-1;public int loadPanels;public bool loadingVisible;public List<string> added=new List<string>();}
 public sealed class Observation {public List<Sample> samples=new List<Sample>();public int unreadable;public int intervalMs=20;public long firstLoadingMs=-1;public long firstReadyMs=-1;public long inputReadyMs=-1;}
 static long Pointer(IntPtr handle,long address){var bytes=Read(handle,address,8);return bytes==null?0:BitConverter.ToInt64(bytes);}
 public static Observation Observe(int id,long image,int seconds){
  var handle=OpenProcess(0x410,false,id);if(handle==IntPtr.Zero)throw new Exception("Read-only process access failed");
  var result=new Observation();var seen=new HashSet<string>();var timer=Stopwatch.StartNew();int previousCount=-1;
  try{while(timer.ElapsedMilliseconds<seconds*1000L){
   // Ghidra FindModel / AuroraQueryModelMemoryInUse: global model pointer
   // array at RVA 13018b8, count at 13018c0, source name at Model+10.
   // Read only bounded model-name storage; no messages/login/key memory.
   var pointer=Read(handle,image+0x13018b8,8);var length=Read(handle,image+0x13018c0,4);
   if(pointer!=null&&length!=null){int count=BitConverter.ToInt32(length);long array=BitConverter.ToInt64(pointer);if(count>=0&&count<=16384){
    var sample=new Sample{elapsedMs=timer.ElapsedMilliseconds,utc=DateTime.UtcNow.ToString("o"),models=count};var values=count!=previousCount?Read(handle,array,count*8):null;previousCount=count;
    if(values!=null)for(int i=0;i<count;++i){long model=BitConverter.ToInt64(values,i*8);var name=Read(handle,model+0x10,64);if(name==null)continue;int zero=Array.IndexOf(name,(byte)0);if(zero<1)continue;string text=Encoding.ASCII.GetString(name,0,zero);if(Regex.IsMatch(text,"^[a-zA-Z0-9_]{1,63}$")&&seen.Add(text))sample.added.Add(text);}
    long gui=Pointer(handle,image+0x12df8b0);var guiData=gui>0?Read(handle,gui+0x88,12):null;
    if(guiData!=null){long panels=BitConverter.ToInt64(guiData,0);int n=BitConverter.ToInt32(guiData,8);if(n>=0&&n<=64){var list=Read(handle,panels,n*8);if(list!=null)for(int i=0;i<n;++i){long panel=BitConverter.ToInt64(list,i*8);if(Pointer(handle,panel)==image+0xe4c0a8){sample.loadPanels++;var flags=Read(handle,panel+0xb0,4);if(flags!=null&&(BitConverter.ToUInt32(flags)&2)==0)sample.loadingVisible=true;}}}}
    long input=Pointer(handle,image+0x12df8c8);long internals=input>0?Pointer(handle,input+8):0;var active=internals>0?Read(handle,internals+0x44,4):null;if(active!=null)sample.inputActive=BitConverter.ToInt32(active);
    result.samples.Add(sample);
    if(sample.loadingVisible&&result.firstLoadingMs<0)result.firstLoadingMs=sample.elapsedMs;
    if(result.firstLoadingMs>=0&&!sample.loadingVisible){if(result.firstReadyMs<0)result.firstReadyMs=sample.elapsedMs;if(sample.inputActive==1&&result.inputReadyMs<0)result.inputReadyMs=sample.elapsedMs;}
    if(result.firstReadyMs>=0&&result.inputReadyMs>=0&&sample.elapsedMs>Math.Max(result.firstReadyMs,result.inputReadyMs)+500)break;
   }else result.unreadable++;}else result.unreadable++;
   Thread.Sleep(result.intervalMs);
  }}finally{CloseHandle(handle);}return result;
 }
}
'@
$watchObserved=[OriginalResourceReadOnly]::Observe($watchProcess.Id,$watchProcess.MainModule.BaseAddress.ToInt64(),$Seconds)
[ordered]@{run=$Run;pid=$watchProcess.Id;endpoint=$watchLaunch.endpoint;sha256=$watchLaunch.sha256;observations=$watchObserved;writesToProcess=0;scope='Bounded read-only source-model residency, exact load-panel vtable/hidden flag and CExoInput active-word observations at 20 ms intervals. GUI and world models are both included. Not frame time or original-versus-replacement loading parity.'}|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $watchReport -Encoding utf8
[pscustomobject]@{report=$watchReport;samples=$watchObserved.samples.Count;unreadable=$watchObserved.unreadable;modelsFirst=$watchObserved.samples[0].models;modelsLast=$watchObserved.samples[-1].models}|ConvertTo-Json -Compress
