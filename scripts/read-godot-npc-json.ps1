param([Parameter(Mandatory=$true)][int]$ClientId,[Parameter(Mandatory=$true)][string]$NamePrefix,[Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Run,[switch]$Utf32,[ValidatePattern('^native-session-[0-9]+$')][string]$ProtocolHostSession='')
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../godot-client'))
$expected=[IO.Path]::GetFullPath((Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'))
$process=Get-Process -Id $ClientId
if($ProtocolHostSession){
 $hostProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$ClientId"
 $hostScript=Join-Path $project 'tools/native-session-host.cjs'
 if($process.ProcessName-ne'node'-or-not$hostProcess.CommandLine.Contains($hostScript)-or-not$hostProcess.CommandLine.Contains("--run=$ProtocolHostSession")){throw 'Expected the explicitly identified owned replacement protocol host'}
}elseif(-not [string]::Equals($process.Path,$expected,[StringComparison]::OrdinalIgnoreCase)){throw 'Expected the owned replacement Godot executable'}
if($NamePrefix.Length-lt5-or$NamePrefix.Length-gt64-or$NamePrefix-match'[^a-zA-Z0-9 ''_-]'){throw 'Expected a narrow NPC-name prefix'}
$output=Join-Path $project "reports/$Run.json"
if(Test-Path -LiteralPath $output){throw 'Diagnostic receipt already exists'}
# READ + QUERY rights only. Never write/protect/suspend/debug/inject. The private
# scratch windows stay in this process; only whitelisted matching NPC fields are
# serialized. Stale JSON bytes may survive in a heap: no liveness claim follows.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
public static class GodotNpcJsonRead {
 [StructLayout(LayoutKind.Sequential)] struct MBI {public IntPtr BaseAddress,AllocationBase;public uint AllocationProtect;public UIntPtr RegionSize;public uint State,Protect,Type;}
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,int id);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll")] static extern UIntPtr VirtualQueryEx(IntPtr handle,IntPtr address,out MBI info,UIntPtr size);
 [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr handle,IntPtr address,byte[] buffer,UIntPtr size,out UIntPtr read);
 public sealed class Window {public string text,address;public int matchAt;}
 public sealed class Result {public ulong bytesRead;public long elapsedMs;public List<Window> windows=new List<Window>();}
 public static Result Scan(int id,string prefix,bool utf32) {
  var handle=OpenProcess(0x410,false,id);if(handle==IntPtr.Zero)throw new Exception("Read-only process access failed: "+Marshal.GetLastWin32Error());
  var result=new Result();var timer=Stopwatch.StartNew();var encoding=utf32?Encoding.UTF32:Encoding.UTF8;var needle=encoding.GetBytes(prefix);var seen=new HashSet<ulong>();var buffer=new byte[1048576];
  try {ulong address=0;while(timer.ElapsedMilliseconds<10000&&result.bytesRead<4UL*1024*1024*1024&&result.windows.Count<24){
   MBI info;if(VirtualQueryEx(handle,new IntPtr((long)address),out info,(UIntPtr)Marshal.SizeOf<MBI>())==UIntPtr.Zero)break;
   ulong start=(ulong)info.BaseAddress.ToInt64(),size=info.RegionSize.ToUInt64(),next=start+size;if(next<=address)break;
   if(info.State==0x1000&&info.Type==0x20000&&(info.Protect&0x100)==0&&(info.Protect&0xff)==4){
    for(ulong offset=0;offset<size&&timer.ElapsedMilliseconds<10000&&result.bytesRead<4UL*1024*1024*1024&&result.windows.Count<24;offset+=983040){
     int requested=(int)Math.Min(Math.Min((ulong)buffer.Length,size-offset),4UL*1024*1024*1024-result.bytesRead);UIntPtr read;ReadProcessMemory(handle,new IntPtr((long)(start+offset)),buffer,(UIntPtr)requested,out read);int length=(int)read.ToUInt64();result.bytesRead+=(ulong)length;
     int cursor=0;while(cursor<length&&result.windows.Count<24){int at=buffer.AsSpan(cursor,length-cursor).IndexOf(needle);if(at<0)break;at+=cursor;cursor=at+needle.Length;ulong pointer=start+offset+(ulong)at;if(!seen.Add(pointer))continue;
      int before=Math.Max(0,at-65536),after=Math.Min(length,at+131072);if(utf32){before+=(at-before)%4;after-=(after-before)%4;}var text=encoding.GetString(buffer,before,after-before);var matchAt=encoding.GetCharCount(buffer,before,at-before);
      result.windows.Add(new Window{text=text,matchAt=matchAt,address="0x"+pointer.ToString("x")});
     }
    }
   }address=next;
  }}finally{CloseHandle(handle);Array.Clear(buffer,0,buffer.Length);}result.elapsedMs=timer.ElapsedMilliseconds;return result;
 }
 public static List<string> EnclosingJson(Window window){
  var result=new List<string>();var text=window.text;int tried=0;
  for(int begin=window.matchAt;begin>=0&&tried<128;--begin){if(text[begin]!='{')continue;++tried;int depth=0,end=-1;bool quoted=false,escape=false;
   for(int n=begin;n<text.Length;++n){char c=text[n];if(quoted){if(escape)escape=false;else if(c=='\\')escape=true;else if(c=='"')quoted=false;continue;}if(c=='"'){quoted=true;continue;}if(c=='{')++depth;else if(c=='}'&&--depth==0){end=n;break;}}
   if(end>=window.matchAt)result.Add(text.Substring(begin,end-begin+1));
  }return result;
 }
}
'@
$scan=[GodotNpcJsonRead]::Scan($ClientId,$NamePrefix,$Utf32.IsPresent)
$candidates=[Collections.Generic.List[object]]::new()
$seen=[Collections.Generic.HashSet[string]]::new()
foreach($window in $scan.windows){
 # Find only enclosing complete JSON dictionaries. GDScript String storage is
 # not reconstructed or treated as a stable engine object layout.
 foreach($jsonCandidate in [GodotNpcJsonRead]::EnclosingJson($window)){
  try{$object=$jsonCandidate|ConvertFrom-Json -Depth 100 -ErrorAction Stop}catch{continue}
  if($object.objectType-ne5-or$null-eq$object.id){continue}
  $projected=[ordered]@{id=$object.id;areaId=$object.areaId;objectType=$object.objectType;appearance=$object.appearance;replicated=$object.replicated;replicationRemoved=$object.replicationRemoved}
  $json=$projected|ConvertTo-Json -Depth 70 -Compress
  if($json.Contains($NamePrefix)-and$seen.Add($json)){$candidates.Add(@{address=$window.address;object=$projected})}
  break
 }
 $window.text=''
}
$receipt=@{pid=$ClientId;engineSha256=(Get-FileHash -LiteralPath $expected -Algorithm SHA256).Hash.ToLowerInvariant();processExeSha256=(Get-FileHash -LiteralPath $process.Path -Algorithm SHA256).Hash.ToLowerInvariant();protocolHostSession=$ProtocolHostSession;readOnly=$true;at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();namePrefix=$NamePrefix;encoding=if($Utf32){'utf32le'}else{'utf8'};bytesRead=$scan.bytesRead;elapsedMs=$scan.elapsedMs;matchingWindows=$scan.windows.Count;candidates=@($candidates.ToArray());scope='Bounded private RW memory search of owned replacement client for complete JSON NPC dictionaries; whitelisted actor fields only, no unrestricted memory dump or process changes. Heap remnants are historical candidates, not proof of current registry or selected playback state.'}
$receipt|ConvertTo-Json -Depth 80|Set-Content -LiteralPath $output -Encoding utf8
[pscustomobject]@{report=$output;readOnly=$true;bytesRead=$scan.bytesRead;elapsedMs=$scan.elapsedMs;windows=$scan.windows.Count;candidates=$candidates.Count}|ConvertTo-Json -Compress
