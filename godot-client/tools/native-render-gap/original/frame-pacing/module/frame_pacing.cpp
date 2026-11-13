#include "frame_pacing.h"
#include "core/object/class_db.h"
#include "core/os/os.h"
#include "core/os/thread.h"
#include <array>
#include <atomic>
#include <algorithm>
#ifdef WINDOWS_ENABLED
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#endif

namespace {
using namespace NwnFramePacingMetrics;
constexpr uint64_t FRAME_CAPACITY=4096,CPU_CAPACITY=128,CPU_WIDTH=11;
template<uint64_t Capacity,uint64_t Width> struct Ring {
 struct Slot {std::atomic_flag writer=ATOMIC_FLAG_INIT;std::atomic<uint64_t> sequence{0};std::array<std::atomic<uint64_t>,Width> values{};};
 std::array<Slot,Capacity> slots{};std::atomic<uint64_t> count{0};
 void publish(const uint64_t *values){
  const uint64_t ticket=count.fetch_add(1)+1;if(ticket==0||ticket>UINT64_MAX/2)return;auto& slot=slots[ticket%Capacity];
  // Main/RT CPU windows share a ring. Never block a frame if an exceptionally
  // delayed writer still owns a wrapped slot; the cold reader reports its drop.
  if(slot.writer.test_and_set(std::memory_order_acquire))return;
  slot.sequence.store((ticket<<1)|1);for(uint64_t i=0;i<Width;i++)slot.values[i].store(i==0?ticket:values[i]);slot.sequence.store(ticket<<1);slot.writer.clear(std::memory_order_release);
 }
 Array read(uint64_t limit,uint64_t& dropped)const{
  Array out;const uint64_t latest=std::min(count.load(),UINT64_MAX/2),first=latest>limit?latest-limit+1:1;
  for(uint64_t ticket=first;ticket<=latest;ticket++){
   const auto& slot=slots[ticket%Capacity];bool valid=false;uint64_t copy[Width];
   for(int attempt=0;attempt<3;attempt++){const uint64_t before=slot.sequence.load();if(before!=(ticket<<1))continue;for(uint64_t i=0;i<Width;i++)copy[i]=slot.values[i].load();if(before==slot.sequence.load()){valid=true;break;}}
   if(!valid){dropped++;continue;}Array row;row.resize(Width);for(uint64_t i=0;i<Width;i++)row[i]=int64_t(copy[i]);out.push_back(row);
  }return out;
 }
};
Ring<FRAME_CAPACITY,FIELD_COUNT> main_frames,render_frames;
Ring<CPU_CAPACITY,CPU_WIDTH> cpu_windows;
std::atomic<uint64_t> main_thread{0},render_thread{0};
std::atomic<uint64_t> main_creation{0},render_creation{0};
struct CpuEndpoint {uint64_t frames=0,baseline_frames=0,wall=0,kernel=0,user=0,thread=0;bool valid=false,attempted=false;};
thread_local std::array<CpuEndpoint,2> endpoints{};
uint64_t own_thread(){
#ifdef WINDOWS_ENABLED
 static thread_local uint64_t id=GetCurrentThreadId();return id;
#else
 return Thread::get_caller_id();
#endif
}
void cpu_endpoint(Lane lane,bool initial){
 auto& endpoint=endpoints[lane];if(!initial)endpoint.frames++;if(endpoint.attempted&&endpoint.frames-endpoint.baseline_frames<120)return;
#ifdef WINDOWS_ENABLED
 FILETIME created{},exited{},kernel{},user{};const BOOL ok=GetThreadTimes(GetCurrentThread(),&created,&exited,&kernel,&user);const DWORD error=ok?0:GetLastError();const uint64_t wall=OS::get_singleton()->get_ticks_usec();
 const uint64_t k=(uint64_t(kernel.dwHighDateTime)<<32)|kernel.dwLowDateTime,u=(uint64_t(user.dwHighDateTime)<<32)|user.dwLowDateTime;
 if(ok){const uint64_t creation=(uint64_t(created.dwHighDateTime)<<32)|created.dwLowDateTime;(lane==MAIN?main_creation:render_creation).store(creation);}
 if(endpoint.valid){uint64_t row[CPU_WIDTH]={0,uint64_t(lane),endpoint.thread,endpoint.wall,wall,endpoint.frames-endpoint.baseline_frames,k>=endpoint.kernel?k-endpoint.kernel:0,u>=endpoint.user?u-endpoint.user:0,uint64_t(ok!=FALSE),uint64_t(error),endpoint.frames};cpu_windows.publish(row);}
 endpoint.attempted=true;endpoint.valid=ok!=FALSE;endpoint.wall=wall;endpoint.kernel=k;endpoint.user=u;endpoint.thread=own_thread();endpoint.baseline_frames=endpoint.frames;
#else
 (void)lane;(void)initial;
#endif
}
Array columns(){const char* names[]={"sequence","os_thread_id","start_us","physics_begin_us","physics_end_us","process_begin_us","scenetree_process_end_us","sync_begin_us","sync_end_us","draw_region_return_us","audio_begin_us","audio_end_us","delay_begin_us","end_us","physics_steps","render_dispatches","begin_frame_end_us","setup_end_us","viewport_begin_us","viewport_end_us","end_frame_begin_us","end_frame_end_us"};static_assert(sizeof(names)/sizeof(names[0])==FIELD_COUNT);Array out;for(auto name:names)out.push_back(name);return out;}
Dictionary process_policy(){Dictionary out;
#ifdef WINDOWS_ENABLED
 HANDLE process=GetCurrentProcess();out["available"]=true;out["priority_class"]=int64_t(GetPriorityClass(process));DWORD_PTR affinity=0,system=0;const BOOL affinity_ok=GetProcessAffinityMask(process,&affinity,&system);out["affinity_available"]=affinity_ok!=FALSE;out["affinity_mask"]=int64_t(affinity);out["system_affinity_mask"]=int64_t(system);
#ifdef PROCESS_POWER_THROTTLING_CURRENT_VERSION
 PROCESS_POWER_THROTTLING_STATE power{};power.Version=PROCESS_POWER_THROTTLING_CURRENT_VERSION;const BOOL power_ok=GetProcessInformation(process,ProcessPowerThrottling,&power,sizeof(power));const DWORD power_error=power_ok?0:GetLastError();out["power_available"]=power_ok!=FALSE;out["power_control_mask"]=int64_t(power.ControlMask);out["power_state_mask"]=int64_t(power.StateMask);if(!power_ok)out["power_error"]=int64_t(power_error);
#endif
#else
 out["available"]=false;
#endif
 return out;
}
Dictionary thread_policy(uint64_t id,uint64_t expected_creation){Dictionary out;out["thread_id"]=int64_t(id);out["expected_creation_100ns"]=int64_t(expected_creation);
#ifdef WINDOWS_ENABLED
 if(id==0||expected_creation==0){out["available"]=false;out["identity_unverified"]=true;return out;}
 HANDLE thread=OpenThread(THREAD_QUERY_LIMITED_INFORMATION,FALSE,DWORD(id));if(!thread){const DWORD error=GetLastError();out["available"]=false;out["error"]=int64_t(error);return out;}
 if(GetProcessIdOfThread(thread)!=GetCurrentProcessId()){out["available"]=false;out["identity_changed"]=true;CloseHandle(thread);return out;}
 FILETIME creation{},exit{},kernel{},user{};const BOOL identity_ok=GetThreadTimes(thread,&creation,&exit,&kernel,&user);const DWORD identity_error=identity_ok?0:GetLastError();const uint64_t observed_creation=(uint64_t(creation.dwHighDateTime)<<32)|creation.dwLowDateTime;
 if(!identity_ok||observed_creation!=expected_creation){out["available"]=false;out["identity_changed"]=true;out["identity_error"]=int64_t(identity_error);out["observed_creation_100ns"]=int64_t(observed_creation);CloseHandle(thread);return out;}
 out["available"]=true;out["priority"]=GetThreadPriority(thread);GROUP_AFFINITY affinity{};const BOOL affinity_ok=GetThreadGroupAffinity(thread,&affinity);out["group_affinity_available"]=affinity_ok!=FALSE;out["group"]=int64_t(affinity.Group);out["affinity_mask"]=int64_t(affinity.Mask);
#ifdef THREAD_POWER_THROTTLING_CURRENT_VERSION
 THREAD_POWER_THROTTLING_STATE power{};power.Version=THREAD_POWER_THROTTLING_CURRENT_VERSION;BOOL power_ok=GetThreadInformation(thread,ThreadPowerThrottling,&power,sizeof(power));DWORD power_error=power_ok?0:GetLastError();
 // GetThreadInformation requires QUERY_INFORMATION, unlike the other cold
 // identity/priority reads. Reopen only after access denied, validate the same
 // own-process creation identity again, and never request any SET access.
 if(!power_ok&&power_error==ERROR_ACCESS_DENIED){
  out["power_initial_error"]=int64_t(power_error);HANDLE query=OpenThread(THREAD_QUERY_INFORMATION,FALSE,DWORD(id));
  if(query){
   FILETIME query_creation{},query_exit{},query_kernel{},query_user{};const BOOL query_identity=GetProcessIdOfThread(query)==GetCurrentProcessId()&&GetThreadTimes(query,&query_creation,&query_exit,&query_kernel,&query_user);const uint64_t query_created=(uint64_t(query_creation.dwHighDateTime)<<32)|query_creation.dwLowDateTime;
   if(query_identity&&query_created==expected_creation){power={};power.Version=THREAD_POWER_THROTTLING_CURRENT_VERSION;power_ok=GetThreadInformation(query,ThreadPowerThrottling,&power,sizeof(power));power_error=power_ok?0:GetLastError();out["power_query_information_fallback"]=true;}
   else{out["power_query_identity_changed"]=true;}
   CloseHandle(query);
  }else{out["power_query_open_error"]=int64_t(GetLastError());}
 }
 out["power_available"]=power_ok!=FALSE;out["power_control_mask"]=int64_t(power.ControlMask);out["power_state_mask"]=int64_t(power.StateMask);if(!power_ok)out["power_error"]=int64_t(power_error);
#endif
 CloseHandle(thread);
#else
 out["available"]=false;
#endif
 return out;
}
}
namespace NwnFramePacingMetrics {
bool enabled(){static const bool value=OS::get_singleton()->get_cmdline_user_args().find("--frame-pacing-metrics=on")!=nullptr;return value;}
Frame::Frame(Lane p_lane,uint64_t start):lane(p_lane){
 recording=enabled();if(!recording)return;std::fill(std::begin(values),std::end(values),uint64_t(0));values[THREAD_ID]=own_thread();values[START]=start?start:OS::get_singleton()->get_ticks_usec();(lane==MAIN?main_thread:render_thread).store(values[THREAD_ID]);cpu_endpoint(lane,true);
}
Frame::~Frame(){if(!recording)return;values[END]=OS::get_singleton()->get_ticks_usec();(lane==MAIN?main_frames:render_frames).publish(values);cpu_endpoint(lane,false);}
void Frame::at(Field field,uint64_t tick){if(recording)values[field]=tick;}
void Frame::first_at(Field field,uint64_t tick){if(recording&&values[field]==0)values[field]=tick;}
void Frame::mark(Field field){if(recording)values[field]=OS::get_singleton()->get_ticks_usec();}
void Frame::add(Field field,uint64_t value){if(recording)values[field]+=value;}
}
Dictionary NwnFramePacing::snapshot(int max_frames){
 Dictionary out;out["enabled"]=NwnFramePacingMetrics::enabled();const uint64_t limit=uint64_t(CLAMP(max_frames,1,int(FRAME_CAPACITY)));uint64_t main_dropped=0,render_dropped=0,cpu_dropped=0;
 out["columns"]=columns();out["main"]=main_frames.read(limit,main_dropped);out["render"]=render_frames.read(limit,render_dropped);out["cpu_windows"]=cpu_windows.read(CPU_CAPACITY,cpu_dropped);out["main_completed"]=int64_t(main_frames.count.load());out["render_completed"]=int64_t(render_frames.count.load());out["main_dropped"]=int64_t(main_dropped);out["render_dropped"]=int64_t(render_dropped);out["cpu_dropped"]=int64_t(cpu_dropped);
 Array cpu_columns;for(const char* name:{"sequence","lane_main0_render1","os_thread_id","wall_start_us","wall_end_us","completed_frames","kernel_cpu_100ns","user_cpu_100ns","cpu_available","win32_error","lane_completed"})cpu_columns.push_back(name);out["cpu_columns"]=cpu_columns;
 const uint64_t main_id=main_thread.load(),render_id=render_thread.load(),main_created=main_creation.load(),render_created=render_creation.load();const bool same=main_id!=0&&main_id==render_id&&main_created==render_created;out["same_thread"]=same;out["process_policy"]=process_policy();const Dictionary main_policy=thread_policy(main_id,main_created);out["main_thread_policy"]=main_policy;out["render_thread_policy"]=same?main_policy:thread_policy(render_id,render_created);
 out["scope"]="Cold fixed-ring snapshot. Absolute process OS microsecond wall ticks; nested and cross-thread spans must not be added. CPU windows use own-thread GetThreadTimes endpoints every120 completed frames after warmup, in100ns units. Same-thread main/render CPU windows overlap and must never be added. No focus, settings or process/thread policy changes.";return out;
}
void NwnFramePacing::_bind_methods(){ClassDB::bind_static_method("NwnFramePacing",D_METHOD("snapshot","max_frames"),&NwnFramePacing::snapshot,DEFVAL(1024));}
