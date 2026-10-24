param([Parameter(Mandatory=$true)][int]$NativeClientId,[int]$DurationSeconds=45,[int]$CaptureVersion=1)
$ErrorActionPreference='Stop'
if($DurationSeconds -lt 1 -or $DurationSeconds -gt 60){throw 'Capture must be bounded to60 seconds'}
if($CaptureVersion -lt 1 -or $CaptureVersion -gt 20){throw 'Invalid capture version'}
$nativeProcess=Get-Process -Id $NativeClientId
$nativeHash=(Get-FileHash -LiteralPath $nativeProcess.Path -Algorithm SHA256).Hash.ToLowerInvariant()
if($nativeProcess.ProcessName -ne 'nwmain' -or $nativeHash -ne '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'){throw 'Pinned original client required'}
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
public static class NativeExamineWatch {
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,int id);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool ReadProcessMemory(IntPtr handle,IntPtr address,byte[] bytes,UIntPtr size,out UIntPtr read);
 static byte[] Read(IntPtr handle,long address,int count){var bytes=new byte[count];UIntPtr read;if(address<=0 || !ReadProcessMemory(handle,new IntPtr(address),bytes,(UIntPtr)count,out read) || read.ToUInt64()!=(ulong)count)return null;return bytes;}
 static long Pointer(IntPtr handle,long address){var bytes=Read(handle,address,8);if(bytes==null)throw new Exception("Native pointer unavailable at0x"+address.ToString("x"));return BitConverter.ToInt64(bytes);}
 public sealed class Packet{public long elapsedMs;public string hex;}
 public sealed class Result{public string manager,client,internalApp,message,lastBytes;public uint lastOffset,lastFragments;public int polls,readableStates;public Dictionary<string,int> envelopeKinds=new Dictionary<string,int>();public List<Packet> packets=new List<Packet>();}
 public static Result Watch(int id,long image,int seconds){
  var handle=OpenProcess(0x410,false,id);if(handle==IntPtr.Zero)throw new Exception("Read-only process access failed");
  var result=new Result();var seen=new HashSet<string>();var timer=Stopwatch.StartNew();
  try{
   // Pinned g_pAppManager -> CClientExoApp -> internal. The original client
   // receive loop6d8eb0 passes internal+208 to game router7a41a0.
   long manager=Pointer(handle,image+0x12df970),client=Pointer(handle,manager),app=Pointer(handle,client+8),message=Pointer(handle,app+0x208);
   result.manager="0x"+manager.ToString("x");result.client="0x"+client.ToString("x");result.internalApp="0x"+app.ToString("x");result.message="0x"+message.ToString("x");
   while(timer.ElapsedMilliseconds<seconds*1000L){
    result.polls++;var state=Read(handle,message,0x68);
    if(state!=null){result.readableStates++;long bytes=BitConverter.ToInt64(state,0x38);uint fragments=BitConverter.ToUInt32(state,0x50),offset=BitConverter.ToUInt32(state,0x58);long length=3L+offset+fragments;result.lastBytes="0x"+bytes.ToString("x");result.lastOffset=offset;result.lastFragments=fragments;
     if(bytes>3 && offset>=4 && length>=12 && length<=65536){var prefix=Read(handle,bytes-3,7);
      // Read no other message bodies. Never capture login/authentication.
      if(prefix!=null && prefix[0]==80){string kind=prefix[1]+"/"+prefix[2];result.envelopeKinds[kind]=result.envelopeKinds.GetValueOrDefault(kind)+1;}
      if(prefix!=null && prefix[0]==80 && prefix[1]==27 && prefix[2]==3 && BitConverter.ToUInt32(prefix,3)==offset+3){
       var packet=Read(handle,bytes-3,(int)length);if(packet!=null){string hex=Convert.ToHexString(packet).ToLowerInvariant();if(seen.Add(hex))result.packets.Add(new Packet{elapsedMs=timer.ElapsedMilliseconds,hex=hex});}
      }
     }
    }
    Thread.Sleep(1);
   }
  }finally{CloseHandle(handle);}return result;
 }
}
'@
Write-Output 'Read-only examination watch armed.'
$nativeResult=[NativeExamineWatch]::Watch($NativeClientId,$nativeProcess.MainModule.BaseAddress.ToInt64(),$DurationSeconds)
$nativeReport=@{readOnly=$true;pid=$NativeClientId;sha256=$nativeHash;scope='Only decoded27/3 examination replies from the pinned client receiver. No writes, debugger, injection, authentication or other gameplay message bodies.';result=$nativeResult}
[IO.File]::WriteAllText((Join-Path (Get-Location) ('backups/animations/native-examine-live-replies-v'+$CaptureVersion+'.json')),($nativeReport|ConvertTo-Json -Depth 8))
Write-Output (@{packets=$nativeResult.packets.Count;polls=$nativeResult.polls;message=$nativeResult.message}|ConvertTo-Json -Compress)
