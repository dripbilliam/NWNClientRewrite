// Strictly read-only DRS query: only the global/base profile and three approved
// executable basenames plus their exact paths. No profile enumeration, mutation,
// save, creation, UI, focus changes or render-device creation exists here.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>
#include <iomanip>
#include <algorithm>
#include "nvapi.h"
#include "NvApiDriverSettings.h"
using Query = void *(__cdecl *)(unsigned int);
template<class T> T load(Query query,unsigned int id){auto p=reinterpret_cast<T>(query(id));if(!p)throw std::runtime_error("Missing read-only NVAPI interface");return p;}
std::string utf8(const NvU16 *p){int n=0;while(p[n]&&n<NVAPI_UNICODE_STRING_MAX)n++;const auto*w=reinterpret_cast<const wchar_t*>(p);int size=WideCharToMultiByte(CP_UTF8,0,w,n,nullptr,0,nullptr,nullptr);std::string result(size,'\0');if(size)WideCharToMultiByte(CP_UTF8,0,w,n,result.data(),size,nullptr,nullptr);return result;}
std::string quote(const std::string&s){std::ostringstream o;o<<'"';for(unsigned char c:s){if(c=='"'||c=='\\')o<<'\\'<<c;else if(c<32)o<<"\\u"<<std::hex<<std::setw(4)<<std::setfill('0')<<int(c)<<std::dec;else o<<c;}o<<'"';return o.str();}
std::string hexid(NvU32 n){std::ostringstream o;o<<"0x"<<std::hex<<std::setw(8)<<std::setfill('0')<<n;return o.str();}
int main(){
 try{
  wchar_t system[MAX_PATH]{};if(!GetSystemDirectoryW(system,MAX_PATH))throw std::runtime_error("System directory unavailable");std::wstring library=std::wstring(system)+L"\\nvapi64.dll";HMODULE module=LoadLibraryExW(library.c_str(),nullptr,LOAD_LIBRARY_SEARCH_SYSTEM32);if(!module)throw std::runtime_error("System NVAPI unavailable");auto query=reinterpret_cast<Query>(GetProcAddress(module,"nvapi_QueryInterface"));if(!query)throw std::runtime_error("NVAPI query interface unavailable");
  const auto initialize=load<decltype(&NvAPI_Initialize)>(query,0x0150e828);
  const auto unload=load<decltype(&NvAPI_Unload)>(query,0xd22bdd7e);
  const auto create=load<decltype(&NvAPI_DRS_CreateSession)>(query,0x0694d52e);
  const auto destroy=load<decltype(&NvAPI_DRS_DestroySession)>(query,0xdad9cff8);
  const auto settings=load<decltype(&NvAPI_DRS_LoadSettings)>(query,0x375dbd6b);
  const auto base=load<decltype(&NvAPI_DRS_GetBaseProfile)>(query,0xda8466a0);
  const auto global=load<decltype(&NvAPI_DRS_GetCurrentGlobalProfile)>(query,0x617bff9f);
  const auto info=load<decltype(&NvAPI_DRS_GetProfileInfo)>(query,0x61cd6fd6);
  const auto find=load<decltype(&NvAPI_DRS_FindApplicationByName)>(query,0xeee566b2);
  const auto get=load<decltype(&NvAPI_DRS_GetSetting)>(query,0x73bf8338);
  const auto values=load<decltype(&NvAPI_DRS_EnumAvailableSettingValues)>(query,0x2ec39f90);
  const auto message=load<decltype(&NvAPI_GetErrorMessage)>(query,0x6c2d048c);
  const auto version=load<decltype(&NvAPI_GetInterfaceVersionString)>(query,0x01053fa5);
  const auto driver=load<decltype(&NvAPI_SYS_GetDriverAndBranchVersion)>(query,0x2926aaad);
  if(initialize()!=NVAPI_OK)throw std::runtime_error("NVAPI initialization failed");NvDRSSessionHandle session=nullptr;if(create(&session)!=NVAPI_OK)throw std::runtime_error("DRS session creation failed");if(settings(session)!=NVAPI_OK)throw std::runtime_error("DRS read-only LoadSettings failed");
  NvAPI_ShortString api{},branch{};NvU32 driver_version=0;version(api);driver(&driver_version,branch);
  const std::vector<std::pair<NvU32,const char*>> keys={{APPIDLE_DYNAMIC_FRL_FPS_ID,"idle_application_max_fps"},{APPIDLE_DYNAMIC_FRL_THRESHOLD_TIME_ID,"idle_threshold_seconds"},{FRL_FPS_ID,"frame_rate_limit"},{VSYNCMODE_ID,"vertical_sync"},{OGL_DEFAULT_SWAP_INTERVAL_ID,"opengl_swap_interval"},{OGL_DEFAULT_SWAP_INTERVAL_FRACTIONAL_ID,"opengl_swap_fractional"},{OGL_DEFAULT_SWAP_INTERVAL_SIGN_ID,"opengl_swap_sign"},{PREFERRED_PSTATE_ID,"power_management"},{EXTERNAL_QUIET_MODE_ID,"external_quiet_mode"}};
  auto status=[&](NvAPI_Status s){NvAPI_ShortString text{};message(s,text);return std::string("\"status\":")+std::to_string(int(s))+",\"status_name\":"+quote(text);};
  auto profile=[&](NvDRSProfileHandle handle){NVDRS_PROFILE p{};p.version=NVDRS_PROFILE_VER;auto ps=info(session,handle,&p);std::ostringstream o;o<<"{"<<status(ps);if(ps==NVAPI_OK)o<<",\"name\":"<<quote(utf8(p.profileName))<<",\"predefined\":"<<p.isPredefined<<",\"apps_count\":"<<p.numOfApps<<",\"settings_count\":"<<p.numOfSettings;o<<",\"settings\":[";bool first=true;for(auto [id,name]:keys){if(!first)o<<',';first=false;NVDRS_SETTING setting{};setting.version=NVDRS_SETTING_VER;auto s=get(session,handle,id,&setting);o<<"{\"key\":"<<quote(name)<<",\"id\":"<<quote(hexid(id))<<','<<status(s);if(s==NVAPI_OK){o<<",\"setting_name\":"<<quote(utf8(setting.settingName))<<",\"type\":"<<int(setting.settingType)<<",\"location\":"<<int(setting.settingLocation)<<",\"current_predefined\":"<<setting.isCurrentPredefined<<",\"predefined_valid\":"<<setting.isPredefinedValid;if(setting.settingType==NVDRS_DWORD_TYPE)o<<",\"current\":"<<setting.u32CurrentValue<<",\"predefined\":"<<setting.u32PredefinedValue;}o<<'}';}o<<"]}";return o.str();};
  std::cout<<"{\"success\":true,\"read_only\":true,\"api\":"<<quote(api)<<",\"driver_version\":"<<driver_version<<",\"branch\":"<<quote(branch)<<",\"setting_metadata\":[";
  bool first=true;for(auto [id,name]:keys){if(!first)std::cout<<',';first=false;NVDRS_SETTING_VALUES available{};available.version=NVDRS_SETTING_VALUES_VER;NvU32 count=NVAPI_SETTING_MAX_VALUES;auto s=values(id,&count,&available);std::cout<<"{\"key\":"<<quote(name)<<",\"id\":"<<quote(hexid(id))<<','<<status(s);if(s==NVAPI_OK){std::cout<<",\"type\":"<<int(available.settingType)<<",\"count\":"<<count;if(available.settingType==NVDRS_DWORD_TYPE)std::cout<<",\"driver_default\":"<<available.u32DefaultValue;}std::cout<<'}';}
  NvDRSProfileHandle b=nullptr,g=nullptr;auto bs=base(session,&b),gs=global(session,&g);std::cout<<"],\"base_profile\":{"<<status(bs);if(bs==NVAPI_OK)std::cout<<",\"profile\":"<<profile(b);std::cout<<"},\"current_global_profile\":{"<<status(gs);if(gs==NVAPI_OK)std::cout<<",\"profile\":"<<profile(g);std::cout<<"},\"applications\":[";
  const std::vector<std::wstring> targets={L"nwmain.exe",L"C:\\Users\\Niflheim\\Desktop\\Tools\\Local Tools\\FullDecomp\\NwnRootInstall\\bin\\win32\\nwmain.exe",L"godot.windows.template_release.x86_64.exe",L"C:\\Users\\Niflheim\\Desktop\\Tools\\Local Tools\\EntireDecomp\\godot-client\\.cache\\native-render-gap\\engine\\build-1794133858985\\godot.windows.template_release.x86_64.exe",L"C:\\Users\\Niflheim\\Desktop\\Tools\\Local Tools\\EntireDecomp\\godot-client\\.cache\\native-140fps\\render-agent\\engine-font-atlas-ownership-v1\\build-1793998835313\\binaries\\godot.windows.template_release.x86_64.exe",L"Godot_v4.7.2-stable_win64.exe",L"C:\\Users\\Niflheim\\Desktop\\Tools\\Local Tools\\EntireDecomp\\godot-client\\.tools\\Godot_v4.7.2-stable_win64.exe"};
  first=true;for(const auto&target:targets){NvAPI_UnicodeString name{};std::copy(target.begin(),target.end(),name);NVDRS_APPLICATION app{};app.version=NVDRS_APPLICATION_VER;NvDRSProfileHandle handle=nullptr;auto s=find(session,name,&handle,&app);if(s==NVAPI_INCOMPATIBLE_STRUCT_VERSION){app={};app.version=NVDRS_APPLICATION_VER_V1;s=find(session,name,&handle,&app);}if(!first)std::cout<<',';first=false;std::cout<<"{\"query\":"<<quote(utf8(name))<<','<<status(s);if(s==NVAPI_OK)std::cout<<",\"matched_application\":"<<quote(utf8(app.appName))<<",\"predefined_application\":"<<app.isPredefined<<",\"profile\":"<<profile(handle);std::cout<<'}';}
  auto ds=destroy(session),us=unload();std::cout<<"],\"destroy_status\":"<<int(ds)<<",\"unload_status\":"<<int(us)<<",\"scope\":\"Global/base and approved target application lookup only. No settings/profile mutations, saves, creates, full-profile enumeration, render-device creation or window focus calls.\"}\n";FreeLibrary(module);return 0;
 }catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}
}
