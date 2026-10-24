param([Parameter(Mandatory=$true)][int]$NativeClientId,[switch]$PacketCandidates)
$ErrorActionPreference = 'Stop'
$nativeClient = Get-Process -Id $NativeClientId
if ($nativeClient.ProcessName -ne 'nwmain') { throw 'Expected original nwmain process' }
$nativeHash = (Get-FileHash -LiteralPath $nativeClient.Path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($nativeHash -ne '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a') { throw 'Original client build differs from the pinned reference' }

# Read-only process rights. No write/protect/debug/thread/injection APIs.
# Scan private writable memory for only the two requested gameplay strings;
# serialize bounded NUL-terminated suffixes of matches, never memory dumps.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
public static class NativeExamineRead {
 [StructLayout(LayoutKind.Sequential)] struct MBI {
  public IntPtr BaseAddress,AllocationBase; public uint AllocationProtect;
  public UIntPtr RegionSize; public uint State,Protect,Type;
 }
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,int id);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll",SetLastError=true)] static extern UIntPtr VirtualQueryEx(IntPtr handle,IntPtr address,out MBI info,UIntPtr size);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool ReadProcessMemory(IntPtr handle,IntPtr address,byte[] buffer,UIntPtr size,out UIntPtr read);
 public sealed class Hit {public string needle,address,suffixHex,packetAddress,packetCandidateHex;}
 public sealed class Result {public ulong bytesRead;public int regions;public long elapsedMs;public List<Hit> hits=new List<Hit>();}
 public static Result Scan(int id,bool packetCandidates) {
  var handle=OpenProcess(0x410,false,id);if(handle==IntPtr.Zero)throw new Exception("Read-only process access failed: "+Marshal.GetLastWin32Error());
  var timer=Stopwatch.StartNew();var result=new Result();var names=new[]{"Attuned to Fire","Racial Type: Human"};
  var needles=Array.ConvertAll(names,Encoding.ASCII.GetBytes);var counts=new int[2];var seen=new HashSet<ulong>();var buffer=new byte[1048576];
  try {
   ulong address=0;
   while(timer.ElapsedMilliseconds<20000 && result.bytesRead<4UL*1024*1024*1024) {
    MBI info;if(VirtualQueryEx(handle,new IntPtr((long)address),out info,(UIntPtr)Marshal.SizeOf<MBI>())==UIntPtr.Zero)break;
    ulong start=(ulong)info.BaseAddress.ToInt64(),size=info.RegionSize.ToUInt64(),next=start+size;if(next<=address)break;
    if(info.State==0x1000 && info.Type==0x20000 && (info.Protect&0x100)==0 && (info.Protect&0xff)==4) {
     result.regions++;
     for(ulong offset=0;offset<size && timer.ElapsedMilliseconds<20000;offset+=1048064) {
      int requested=(int)Math.Min((ulong)buffer.Length,size-offset);UIntPtr read;
      ReadProcessMemory(handle,new IntPtr((long)(start+offset)),buffer,(UIntPtr)requested,out read);int length=(int)read.ToUInt64();result.bytesRead+=(ulong)length;
      for(int n=0;n<needles.Length;n++) {
       if(counts[n]>=24)continue;int cursor=0;
       while(cursor<length) {
        int at=buffer.AsSpan(cursor,length-cursor).IndexOf(needles[n]);if(at<0)break;at+=cursor;cursor=at+needles[n].Length;
        ulong pointer=start+offset+(ulong)at;if(!seen.Add(pointer))continue;
        int end=at;while(end<length && end<at+768 && buffer[end]!=0)end++;
        var hit=new Hit{needle=names[n],address="0x"+pointer.ToString("x"),suffixHex=Convert.ToHexString(buffer.AsSpan(at,end-at)).ToLowerInvariant()};
        // Only a nearby examination envelope enclosing the matched gameplay
        // string can be retained; no unrelated surrounding heap is serialized.
        if(packetCandidates)for(int p=at-1;p>=Math.Max(0,at-512);p--) {
         if(buffer[p]!=80 || buffer[p+1]!=27 || buffer[p+2]!=3)continue;
         uint boundary=BitConverter.ToUInt32(buffer,p+3);
         if(boundary<11 || boundary>8192 || p+boundary<=at || p+boundary+8>length)continue;
         hit.packetAddress="0x"+(start+offset+(ulong)p).ToString("x");hit.packetCandidateHex=Convert.ToHexString(buffer.AsSpan(p,(int)boundary+8)).ToLowerInvariant();break;
        }
        result.hits.Add(hit);if(++counts[n]>=24)break;
       }
      }
     }
    }
    address=next;
   }
  } finally {CloseHandle(handle);}
  result.elapsedMs=timer.ElapsedMilliseconds;return result;
 }
}
'@
$nativeResult = [NativeExamineRead]::Scan($NativeClientId,$PacketCandidates.IsPresent)
$nativeReport = @{pid=$NativeClientId;sha256=$nativeHash;baseAddress=('0x'+$nativeClient.MainModule.BaseAddress.ToInt64().ToString('x'));readOnly=$true;scope='Private RW memory; only bounded suffixes matching Attuned to Fire or Racial Type: Human; no process modifications or unrestricted memory dump';result=$nativeResult}
$nativeArtifact = if($PacketCandidates){'native-examine-live-strings-v2.json'}else{'native-examine-live-strings-v1.json'}
$nativeOutput = Join-Path (Get-Location) ('backups/animations/'+$nativeArtifact)
[IO.File]::WriteAllText($nativeOutput,($nativeReport | ConvertTo-Json -Depth 8))
Write-Output ($nativeResult | Select-Object bytesRead,regions,elapsedMs,@{Name='matches';Expression={$_.hits.Count}} | ConvertTo-Json -Compress)
