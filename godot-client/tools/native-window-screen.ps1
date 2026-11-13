# Read-only monitor discovery in the same EnumDisplayMonitors order Godot uses.
# Never activate a window, change display modes, or move/capture the pointer.
function Get-NativeSecondaryScreen {
 if(-not [OperatingSystem]::IsWindows()){return -1}
 if(-not ('NwnNativeStartupMonitor' -as [type])){
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NwnNativeStartupMonitor {
 [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
 [StructLayout(LayoutKind.Sequential)] struct Info { public int Size; public Rect Monitor, Work; public uint Flags; }
 delegate bool Callback(IntPtr monitor, IntPtr dc, ref Rect rect, IntPtr data);
 [DllImport("user32.dll", SetLastError=true)] static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, Callback callback, IntPtr data);
 [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool GetMonitorInfoW(IntPtr monitor, ref Info info);
 public static object[] Describe() {
  int index=0, monitorError=0; var screens=new System.Collections.Generic.List<object>();
  Callback callback=delegate(IntPtr monitor, IntPtr dc, ref Rect rect, IntPtr data) {
   var info=new Info(); info.Size=Marshal.SizeOf<Info>();
   if(!GetMonitorInfoW(monitor,ref info)) { monitorError=Marshal.GetLastWin32Error(); return false; }
   screens.Add(new { index=index++, primary=(info.Flags & 1)!=0,
    workWidth=info.Work.Right-info.Work.Left, workHeight=info.Work.Bottom-info.Work.Top });
   return true;
  };
  if(!EnumDisplayMonitors(IntPtr.Zero,IntPtr.Zero,callback,IntPtr.Zero)) throw new System.ComponentModel.Win32Exception();
  if(monitorError!=0) throw new System.ComponentModel.Win32Exception(monitorError);
  return screens.ToArray();
 }
 public static int FindSecondary() {
  int index=0, selected=-1; long largest=0;
  Callback callback=delegate(IntPtr monitor, IntPtr dc, ref Rect rect, IntPtr data) {
   var info=new Info(); info.Size=Marshal.SizeOf<Info>();
   if(GetMonitorInfoW(monitor,ref info) && (info.Flags & 1)==0) {
    long area=(long)(info.Work.Right-info.Work.Left)*(info.Work.Bottom-info.Work.Top);
    if(selected<0 || area>largest) { selected=index; largest=area; }
   }
   index++; return true;
  };
  if(!EnumDisplayMonitors(IntPtr.Zero,IntPtr.Zero,callback,IntPtr.Zero)) throw new System.ComponentModel.Win32Exception();
  return selected;
 }
}
'@
 }
 return [NwnNativeStartupMonitor]::FindSecondary()
}

# A current topology, not a cached display index. Only reports display metadata.
function Get-NativeScreenTopology {
 if(-not [OperatingSystem]::IsWindows()){throw 'Native display discovery requires Windows'}
 $null=Get-NativeSecondaryScreen
 ConvertTo-Json -InputObject @([NwnNativeStartupMonitor]::Describe()) -Compress -Depth 3
}
