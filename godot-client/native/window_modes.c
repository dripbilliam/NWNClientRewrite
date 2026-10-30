// Read-only monitor/mode enumeration. No paths, credentials, network, window
// activation or display changes. Monitor order matches EnumDisplayMonitors.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
static int screen_count=0,errors=0;
static void mode(const DEVMODEW *value){
 printf("{\"width\":%lu,\"height\":%lu,\"refresh\":%lu,\"depth\":%lu}",(unsigned long)value->dmPelsWidth,(unsigned long)value->dmPelsHeight,(unsigned long)value->dmDisplayFrequency,(unsigned long)value->dmBitsPerPel);
}
static BOOL CALLBACK monitor(HMONITOR handle,HDC dc,LPRECT rectangle,LPARAM context){
 MONITORINFOEXW info;DEVMODEW current,item;DWORD index;int count=0;
 (void)dc;(void)rectangle;(void)context;ZeroMemory(&info,sizeof(info));info.cbSize=sizeof(info);
 if(!GetMonitorInfoW(handle,(MONITORINFO *)&info)){errors++;return TRUE;}
 if(screen_count)putchar(',');
 printf("{\"index\":%d,\"primary\":%s,\"position\":[%ld,%ld],\"size\":[%ld,%ld],\"current\":",screen_count++,(info.dwFlags&MONITORINFOF_PRIMARY)?"true":"false",info.rcMonitor.left,info.rcMonitor.top,info.rcMonitor.right-info.rcMonitor.left,info.rcMonitor.bottom-info.rcMonitor.top);
 ZeroMemory(&current,sizeof(current));current.dmSize=sizeof(current);
 if(EnumDisplaySettingsExW(info.szDevice,ENUM_CURRENT_SETTINGS,&current,0))mode(&current);else{fputs("null",stdout);errors++;}
 fputs(",\"modes\":[",stdout);
 for(index=0;index<8192;index++){
  ZeroMemory(&item,sizeof(item));item.dmSize=sizeof(item);
  if(!EnumDisplaySettingsExW(info.szDevice,index,&item,0))break;
  if(!item.dmPelsWidth||!item.dmPelsHeight)continue;
  if(count++)putchar(',');mode(&item);
 }
 if(index==8192)errors++;
 fputs("]}",stdout);return TRUE;
}
int main(int argc,char **argv){
 (void)argv;if(argc!=1)return 2;
 fputs("{\"screens\":[",stdout);
 if(!EnumDisplayMonitors(NULL,NULL,monitor,0))errors++;
 printf("],\"errors\":%d,\"readOnly\":true}\n",errors);
 return errors?1:0;
}
