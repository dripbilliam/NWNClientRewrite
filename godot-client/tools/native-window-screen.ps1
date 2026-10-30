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
 public static int FindSecondary() {
  int index=0, selected=-1;
  Callback callback=delegate(IntPtr monitor, IntPtr dc, ref Rect rect, IntPtr data) {
   var info=new Info(); info.Size=Marshal.SizeOf<Info>();
   if(GetMonitorInfoW(monitor,ref info) && (info.Flags & 1)==0 && selected<0) selected=index;
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
