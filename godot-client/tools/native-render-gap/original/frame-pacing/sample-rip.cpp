#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#include <bcrypt.h>
#include <algorithm>
#include <array>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>
#pragma comment(lib,"bcrypt.lib")
#pragma comment(lib,"psapi.lib")

// Diagnostic only: briefly pauses one verified owned client thread. No stack
// walking, target writes, remote calls, priority/power policy, timer-resolution
// changes, symbol downloads, or unrelated process/session operations.
namespace {
struct Handle{HANDLE h=nullptr;explicit Handle(HANDLE value=nullptr):h(value){}~Handle(){if(h&&h!=INVALID_HANDLE_VALUE)CloseHandle(h);}Handle(const Handle&)=delete;Handle&operator=(const Handle&)=delete;};
[[noreturn]] void fail(const char* message){throw std::runtime_error(std::string(message)+" win32="+std::to_string(GetLastError()));}
uint64_t ticks(){LARGE_INTEGER n{};if(!QueryPerformanceCounter(&n))fail("QueryPerformanceCounter");return uint64_t(n.QuadPart);}
uint64_t frequency(){LARGE_INTEGER n{};if(!QueryPerformanceFrequency(&n))fail("QueryPerformanceFrequency");return uint64_t(n.QuadPart);}
uint64_t ft(FILETIME n){return(uint64_t(n.dwHighDateTime)<<32)|n.dwLowDateTime;}
struct Times{uint64_t created=0,kernel=0,user=0;};
Times thread_times(HANDLE h){FILETIME c{},e{},k{},u{};if(!GetThreadTimes(h,&c,&e,&k,&u))fail("GetThreadTimes");return{ft(c),ft(k),ft(u)};}
Times process_times(HANDLE h){FILETIME c{},e{},k{},u{};if(!GetProcessTimes(h,&c,&e,&k,&u))fail("GetProcessTimes");return{ft(c),ft(k),ft(u)};}
std::string utf8(const std::wstring&s){const int n=WideCharToMultiByte(CP_UTF8,0,s.data(),int(s.size()),nullptr,0,nullptr,nullptr);std::string o(size_t(n),'\0');WideCharToMultiByte(CP_UTF8,0,s.data(),int(s.size()),o.data(),n,nullptr,nullptr);return o;}
std::wstring fullpath(const std::wstring&s){std::array<wchar_t,32768>b{};const DWORD n=GetFullPathNameW(s.c_str(),DWORD(b.size()),b.data(),nullptr);if(!n||n>=b.size())fail("GetFullPathName");return b.data();}
std::string quote(const std::string&s){std::ostringstream out;out<<'"';for(unsigned char c:s){if(c=='"'||c=='\\')out<<'\\'<<char(c);else if(c<32)out<<"\\u"<<std::hex<<std::setw(4)<<std::setfill('0')<<unsigned(c)<<std::dec;else out<<char(c);}out<<'"';return out.str();}
std::string sha256(const std::wstring&file){Handle f(CreateFileW(file.c_str(),GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr));if(f.h==INVALID_HANDLE_VALUE)fail("Open hash input");BCRYPT_ALG_HANDLE alg=nullptr;BCRYPT_HASH_HANDLE hash=nullptr;if(BCryptOpenAlgorithmProvider(&alg,BCRYPT_SHA256_ALGORITHM,nullptr,0)<0)fail("BCryptOpenAlgorithmProvider");DWORD size=0,got=0;if(BCryptGetProperty(alg,BCRYPT_OBJECT_LENGTH,reinterpret_cast<PUCHAR>(&size),sizeof(size),&got,0)<0){BCryptCloseAlgorithmProvider(alg,0);fail("Hash object size");}std::vector<unsigned char> object(size);if(BCryptCreateHash(alg,&hash,object.data(),size,nullptr,0,0)<0){BCryptCloseAlgorithmProvider(alg,0);fail("BCryptCreateHash");}std::array<unsigned char,65536> buffer{};DWORD count=0;bool ok=true;for(;;){if(!ReadFile(f.h,buffer.data(),DWORD(buffer.size()),&count,nullptr)){ok=false;break;}if(count==0)break;if(BCryptHashData(hash,buffer.data(),count,0)<0){ok=false;break;}}std::array<unsigned char,32> digest{};if(BCryptFinishHash(hash,digest.data(),DWORD(digest.size()),0)<0)ok=false;BCryptDestroyHash(hash);BCryptCloseAlgorithmProvider(alg,0);if(!ok)fail("Hash input");std::ostringstream out;for(auto b:digest)out<<std::hex<<std::setw(2)<<std::setfill('0')<<unsigned(b);return out.str();}
struct Module{uint64_t base=0,size=0;std::wstring file;std::string sha;};
std::vector<Module> modules(HANDLE process){std::array<HMODULE,2048> names{};DWORD needed=0;if(!EnumProcessModulesEx(process,names.data(),DWORD(sizeof(names)),&needed,LIST_MODULES_64BIT)||needed>sizeof(names))fail("EnumProcessModulesEx");std::vector<Module> result;for(size_t n=0;n<needed/sizeof(HMODULE);n++){MODULEINFO info{};std::array<wchar_t,32768> file{};if(!GetModuleInformation(process,names[n],&info,sizeof(info))||!GetModuleFileNameExW(process,names[n],file.data(),DWORD(file.size())))fail("Module identity");result.push_back({uint64_t(reinterpret_cast<uintptr_t>(info.lpBaseOfDll)),info.SizeOfImage,file.data(),{}});}return result;}

// All fields inside the pause are fixed numeric data. The destructor retries
// a failed explicit resume once; the handle pins the exact thread object.
struct OwnSuspend {
 HANDLE thread;bool armed=false;DWORD resume_previous=DWORD(-1),resume_error=0;
 explicit OwnSuspend(HANDLE h):thread(h){}
 bool release()noexcept{if(!armed)return true;resume_previous=ResumeThread(thread);if(resume_previous==DWORD(-1)){resume_error=GetLastError();return false;}armed=false;return true;}
 ~OwnSuspend(){if(armed)release();}
};
enum Status:uint32_t{OK=0,ALREADY_SUSPENDED=1,SUSPEND_FAILED=2,CONTEXT_FAILED=3,INJECTED_FAILURE=4,RESUME_FAILED=5};
struct Sample{uint64_t due_us=0,began_us=0,pause_us=0,rip=0,rva=0;int32_t module=-1;uint32_t status=0,error=0,previous_suspend=0,resume_previous=0;};
Sample capture_one(HANDLE thread,uint64_t start,uint64_t hz,bool inject=false){
 Sample out{};LARGE_INTEGER before{},after{};QueryPerformanceCounter(&before);out.began_us=(uint64_t(before.QuadPart)-start)*1000000/hz;
 {
  OwnSuspend owned(thread);const DWORD previous=SuspendThread(thread);out.previous_suspend=previous;
  if(previous==DWORD(-1)){out.status=SUSPEND_FAILED;out.error=GetLastError();}
  else{
   owned.armed=true;
   if(previous!=0)out.status=ALREADY_SUSPENDED;
   else if(inject)out.status=INJECTED_FAILURE;
   else{alignas(16) CONTEXT context{};context.ContextFlags=CONTEXT_CONTROL;if(!GetThreadContext(thread,&context)){out.status=CONTEXT_FAILED;out.error=GetLastError();}else out.rip=context.Rip;}
   if(!owned.release()){out.status=RESUME_FAILED;out.error=owned.resume_error;}out.resume_previous=owned.resume_previous;
  }
 } // Mandatory final resume retry before QPC/reporting/allocation/file IO.
 QueryPerformanceCounter(&after);out.pause_us=(uint64_t(after.QuadPart)-uint64_t(before.QuadPart))*1000000/hz;return out;
}
struct Config{DWORD pid=0,tid=0;uint64_t creation=0,thread_creation=0;std::wstring engine,kernel,out;std::string engine_sha,kernel_sha;uint32_t duration_ms=30000;};
struct Result{Config config;uint64_t hz=0,wall_us=0,thread_creation=0,kernel_cpu_100ns=0,user_cpu_100ns=0,missed_due=0;bool high_resolution=false,success=false;std::vector<Module> loaded;std::vector<Sample> samples;};
Result collect(const Config&c){
 if(c.pid==0||c.tid==0||c.creation==0||c.duration_ms>30000||c.duration_ms<100)throw std::runtime_error("Invalid bounded capture inputs");
 Handle process(OpenProcess(PROCESS_QUERY_INFORMATION|PROCESS_VM_READ|SYNCHRONIZE,FALSE,c.pid));if(!process.h)fail("Open owned process");
 if(process_times(process.h).created!=c.creation)throw std::runtime_error("Process creation identity changed");std::array<wchar_t,32768> image{};DWORD image_size=DWORD(image.size());if(!QueryFullProcessImageNameW(process.h,0,image.data(),&image_size))fail("Query image path");if(_wcsicmp(fullpath(image.data()).c_str(),fullpath(c.engine).c_str())!=0||sha256(c.engine)!=c.engine_sha)throw std::runtime_error("Pinned engine path/hash mismatch");
 Handle thread(OpenThread(THREAD_SUSPEND_RESUME|THREAD_GET_CONTEXT|THREAD_QUERY_INFORMATION,FALSE,c.tid));if(!thread.h)fail("Open owned thread");if(GetProcessIdOfThread(thread.h)!=c.pid)throw std::runtime_error("Thread belongs to another process");const auto first=thread_times(thread.h);if(first.created<c.creation||(c.thread_creation&&first.created!=c.thread_creation))throw std::runtime_error("Thread creation identity mismatch");
 Result result;result.config=c;result.hz=frequency();result.thread_creation=first.created;result.loaded=modules(process.h);bool engine_found=false,kernel_found=c.kernel.empty();for(auto&m:result.loaded){if(_wcsicmp(fullpath(m.file).c_str(),fullpath(c.engine).c_str())==0){m.sha=c.engine_sha;engine_found=true;}if(!c.kernel.empty()&&_wcsicmp(fullpath(m.file).c_str(),fullpath(c.kernel).c_str())==0){m.sha=sha256(c.kernel);if(m.sha!=c.kernel_sha)throw std::runtime_error("Pinned kernel hash mismatch");kernel_found=true;}}if(!engine_found||!kernel_found)throw std::runtime_error("Pinned module is not loaded");
 HANDLE timer_raw=CreateWaitableTimerExW(nullptr,nullptr,CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,TIMER_MODIFY_STATE|SYNCHRONIZE);result.high_resolution=timer_raw!=nullptr;if(!timer_raw){const DWORD error=GetLastError();if(error!=ERROR_INVALID_PARAMETER&&error!=ERROR_NOT_SUPPORTED)fail("Create high-resolution waitable timer");timer_raw=CreateWaitableTimerExW(nullptr,nullptr,0,TIMER_MODIFY_STATE|SYNCHRONIZE);}Handle timer(timer_raw);if(!timer.h)fail("Create waitable timer");
 const size_t maximum=size_t(c.duration_ms)*1000/2000+2;result.samples.resize(maximum);size_t used=0;uint32_t jitter=0x6cf31e2d;const uint64_t hz=result.hz;const auto next_step=[&](){jitter=jitter*1664525u+1013904223u;return std::max<uint64_t>(1,uint64_t(2000+jitter%3001)*hz/1000000);};const auto cpu_begin=thread_times(thread.h);const uint64_t start=ticks(),end=start+uint64_t(c.duration_ms)*hz/1000;uint64_t step=next_step(),due=start+step;
 while(due<end&&used<maximum){
  uint64_t now=ticks();if(now<due){LARGE_INTEGER relative{};relative.QuadPart=-LONGLONG(std::max<uint64_t>(1,(due-now)*10000000/hz));if(!SetWaitableTimerEx(timer.h,&relative,0,nullptr,nullptr,nullptr,0))fail("Set private waitable timer");if(WaitForSingleObject(timer.h,1000)!=WAIT_OBJECT_0)fail("Waitable timer deadline");now=ticks();}
  if(now>=end)break;if(now>due+step){do{++result.missed_due;step=next_step();due+=step;}while(due<now);continue;}
  auto sample=capture_one(thread.h,start,hz);sample.due_us=(due-start)*1000000/hz;for(size_t n=0;n<result.loaded.size();n++){const auto&m=result.loaded[n];if(sample.rip>=m.base&&sample.rip-m.base<m.size){sample.module=int32_t(n);sample.rva=sample.rip-m.base;break;}}result.samples[used++]=sample;step=next_step();due+=step;if(sample.status==SUSPEND_FAILED||sample.status==RESUME_FAILED||sample.status==ALREADY_SUSPENDED)break;
 }
 result.wall_us=(ticks()-start)*1000000/hz;CancelWaitableTimer(timer.h);result.samples.resize(used);const auto last=thread_times(thread.h);if(last.created!=first.created||process_times(process.h).created!=c.creation)throw std::runtime_error("Pinned identity mismatch at closure");result.kernel_cpu_100ns=last.kernel-cpu_begin.kernel;result.user_cpu_100ns=last.user-cpu_begin.user;result.success=!result.samples.empty()&&std::all_of(result.samples.begin(),result.samples.end(),[](const Sample&s){return s.status==OK;});return result;
}
void write_result(const Result&r,bool selftest=false){
 if(GetFileAttributesW(r.config.out.c_str())!=INVALID_FILE_ATTRIBUTES)throw std::runtime_error("Preserve prior output");std::ofstream o(r.config.out.c_str(),std::ios::binary);if(!o)throw std::runtime_error("Open fresh report");uint64_t maximum=0,total=0,over=0,errors=0;for(auto&s:r.samples){maximum=std::max(maximum,s.pause_us);total+=s.pause_us;over+=s.pause_us>200;errors+=s.status!=OK;}
 o<<"{\"version\":1,\"success\":"<<(r.success?"true":"false")<<",\"selftest\":"<<(selftest?"true":"false")<<",\"scope\":\"RIP-only statistical owned-thread suspend diagnostic, not FPS or unperturbed performance. Pause_us is suspend/context/resume API wall upper bound; CPU endpoints bracket capture with small endpoint skew. Other threads continue. No network symbols, target writes, stack walking, priority/power/timer-resolution/session changes.\",\"pid\":"<<r.config.pid<<",\"tid\":"<<r.config.tid<<",\"process_creation_100ns\":"<<quote(std::to_string(r.config.creation))<<",\"thread_creation_100ns\":"<<quote(std::to_string(r.thread_creation))<<",\"jitter_seed\":1827872301,\"jitter_min_us\":2000,\"jitter_max_us\":5000,\"requested_duration_ms\":"<<r.config.duration_ms<<",\"wall_us\":"<<r.wall_us<<",\"qpc_frequency\":"<<r.hz<<",\"high_resolution_timer\":"<<(r.high_resolution?"true":"false")<<",\"missed_due\":"<<r.missed_due<<",\"kernel_cpu_100ns\":"<<r.kernel_cpu_100ns<<",\"user_cpu_100ns\":"<<r.user_cpu_100ns<<",\"pause_total_us\":"<<total<<",\"pause_max_us\":"<<maximum<<",\"pause_over_200us\":"<<over<<",\"sample_errors\":"<<errors<<",\"modules\":[";
 for(size_t n=0;n<r.loaded.size();n++){if(n)o<<',';const auto&m=r.loaded[n];o<<"{\"file\":"<<quote(utf8(m.file))<<",\"base\":"<<m.base<<",\"size\":"<<m.size<<",\"sha256\":"<<quote(m.sha)<<'}';}
 o<<"],\"columns\":[\"due_us\",\"began_us\",\"pause_us\",\"rip\",\"module_index\",\"module_rva\",\"status\",\"win32_error\",\"previous_suspend_count\",\"resume_previous_count\"],\"samples\":[";for(size_t n=0;n<r.samples.size();n++){if(n)o<<',';auto&s=r.samples[n];o<<'['<<s.due_us<<','<<s.began_us<<','<<s.pause_us<<','<<s.rip<<','<<s.module<<','<<s.rva<<','<<s.status<<','<<s.error<<','<<s.previous_suspend<<','<<s.resume_previous<<']';}o<<"]}\n";if(!o)throw std::runtime_error("Write report");
}
volatile uint64_t mock_sink=17;
__declspec(noinline) void mock_hotloop(){uint64_t value=mock_sink;for(int n=0;n<20000;n++)value=(value*1664525+1013904223)^(value>>7);mock_sink=value;}
int mock_child(const std::wstring&ready_name){Handle ready(OpenEventW(EVENT_MODIFY_STATE,FALSE,ready_name.c_str()));if(!ready.h||!SetEvent(ready.h))fail("Mock ready event");const auto hz=frequency(),end=ticks()+hz*6;while(ticks()<end)mock_hotloop();return 0;}
int self_test(const std::wstring&file){
 std::array<wchar_t,32768> exe{};if(!GetModuleFileNameW(nullptr,exe.data(),DWORD(exe.size())))fail("Own executable");const std::wstring ready_name=L"Local\\NwnRipMock-"+std::to_wstring(GetCurrentProcessId())+L"-"+std::to_wstring(ticks());Handle ready(CreateEventW(nullptr,TRUE,FALSE,ready_name.c_str()));if(!ready.h||GetLastError()==ERROR_ALREADY_EXISTS)fail("Create private mock event");std::wstring command=L"\""+std::wstring(exe.data())+L"\" --mock-child="+ready_name;STARTUPINFOW startup{};startup.cb=sizeof(startup);PROCESS_INFORMATION child{};if(!CreateProcessW(exe.data(),command.data(),nullptr,nullptr,FALSE,CREATE_NO_WINDOW,nullptr,nullptr,&startup,&child))fail("Create owned mock child");Handle process(child.hProcess),thread(child.hThread);
 try{
  if(WaitForSingleObject(ready.h,3000)!=WAIT_OBJECT_0)throw std::runtime_error("Mock did not reach ready entry point");const auto created=process_times(process.h).created,hz=frequency();if(SuspendThread(thread.h)!=0)throw std::runtime_error("Mock initial suspension unexpected");const auto blocked=capture_one(thread.h,ticks(),hz);const DWORD remains=ResumeThread(thread.h);if(blocked.status!=ALREADY_SUSPENDED||blocked.previous_suspend!=1||blocked.resume_previous!=2||remains!=1)throw std::runtime_error("Pre-existing suspend count was not preserved");const auto injected=capture_one(thread.h,ticks(),hz,true);if(injected.status!=INJECTED_FAILURE||injected.previous_suspend!=0||injected.resume_previous!=1)throw std::runtime_error("Injected-failure RAII resume failed");
  Config c;c.pid=child.dwProcessId;c.tid=child.dwThreadId;c.creation=created;c.thread_creation=thread_times(thread.h).created;c.engine=exe.data();c.engine_sha=sha256(c.engine);c.out=file;c.duration_ms=1600;const auto result=collect(c);write_result(result,true);if(!result.success||result.samples.size()<100||result.user_cpu_100ns==0||std::any_of(result.samples.begin(),result.samples.end(),[](const Sample&s){return s.previous_suspend!=0||s.resume_previous!=1||s.module<0||s.rip==0;}))throw std::runtime_error("Mock sampling/progress/module fixture failed; retained numeric report");
  if(WaitForSingleObject(process.h,7000)!=WAIT_OBJECT_0){TerminateProcess(process.h,31);WaitForSingleObject(process.h,1000);throw std::runtime_error("Owned mock child failed bounded natural exit");}DWORD exit=1;GetExitCodeProcess(process.h,&exit);if(exit!=0)throw std::runtime_error("Mock child nonzero exit");std::cout<<"Mock own-child sampler PASS; normal, pre-existing suspension and forced-after-suspend cleanup; child exited0.\n";return 0;
 }catch(...){ResumeThread(thread.h);TerminateProcess(process.h,32);WaitForSingleObject(process.h,1000);throw;}
}
}
int wmain(int argc,wchar_t**argv){try{Config c;bool test=false;for(int n=1;n<argc;n++){std::wstring a=argv[n];if(a.rfind(L"--mock-child=",0)==0)return mock_child(a.substr(13));if(a==L"--self-test"){test=true;continue;}const auto eq=a.find(L'=');if(eq==std::wstring::npos)throw std::runtime_error("Expected --key=value");const auto key=a.substr(0,eq),v=a.substr(eq+1);if(key==L"--pid")c.pid=DWORD(std::stoul(v));else if(key==L"--tid")c.tid=DWORD(std::stoul(v));else if(key==L"--creation")c.creation=std::stoull(v,nullptr,0);else if(key==L"--thread-creation")c.thread_creation=std::stoull(v,nullptr,0);else if(key==L"--engine")c.engine=fullpath(v);else if(key==L"--sha")c.engine_sha=utf8(v);else if(key==L"--kernel")c.kernel=fullpath(v);else if(key==L"--kernel-sha")c.kernel_sha=utf8(v);else if(key==L"--out")c.out=fullpath(v);else if(key==L"--duration-ms")c.duration_ms=uint32_t(std::stoul(v));else throw std::runtime_error("Unknown option");}if(c.out.empty())throw std::runtime_error("Fresh --out is required");if(test)return self_test(c.out);auto result=collect(c);write_result(result);std::cout<<"Owned sampler closed; samples="<<result.samples.size()<<" success="<<result.success<<"\n";return result.success?0:2;}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
