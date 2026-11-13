// Private diagnostic only. Disabled startup mode returns before any TLS state
// access or Windows processor query. No affinity, priority or power setters.
namespace particle_core_survey {
constexpr uint64_t stride=120;
constexpr size_t capacity=256;
bool enabled=false;
struct Bin {WORD group=0;BYTE number=0;uint64_t count=0;};
struct Sample {uint64_t frame=0;WORD group=0;BYTE number=0;};
struct State {uint64_t calls=0,samples=0,dropped=0;DWORD thread_id=0;size_t bins=0;std::array<Bin,capacity> histogram{};std::array<Sample,capacity> ring{};};
thread_local State state;
void bind(){Name os_name("OS");auto object=global_singleton(os_name.data);if(!object)return;EngineVar os;destroy(os.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](os.data,&object);auto args=::method(os,"get_cmdline_user_args");enabled=::method(args,"has",{EngineVar::text("--particle-core-survey")}).boolean();if(::method(args,"has",{EngineVar::text("--particle-core-survey=off")}).boolean())enabled=false;}
void frame(){
 if(!enabled)return;
 auto& value=state;++value.calls;if((value.calls-1)%stride)return;
 PROCESSOR_NUMBER processor{};GetCurrentProcessorNumberEx(&processor);
 if(!value.thread_id)value.thread_id=GetCurrentThreadId();
 size_t index=0;for(;index<value.bins;++index)if(value.histogram[index].group==processor.Group&&value.histogram[index].number==processor.Number)break;
 if(index<value.bins)++value.histogram[index].count;
 else if(value.bins<capacity)value.histogram[value.bins++]={processor.Group,processor.Number,1};
 else ++value.dropped;
 value.ring[static_cast<size_t>(value.samples%capacity)]={value.calls,processor.Group,processor.Number};++value.samples;
}
uint64_t file_time(FILETIME value){return (static_cast<uint64_t>(value.dwHighDateTime)<<32)|value.dwLowDateTime;}
EngineVar topology(){
 auto out=EngineVar::dictionary(),rows=::array_empty();ULONG needed=0;GetSystemCpuSetInformation(nullptr,0,&needed,GetCurrentProcess(),0);
 if(!needed||needed>1024U*1024U){::set(out,"error",EngineVar::integer(GetLastError()));::set(out,"rows",rows);return out;}
 std::vector<uint8_t> bytes(needed);ULONG returned=0;
 if(!GetSystemCpuSetInformation(reinterpret_cast<PSYSTEM_CPU_SET_INFORMATION>(bytes.data()),needed,&returned,GetCurrentProcess(),0)){::set(out,"error",EngineVar::integer(GetLastError()));::set(out,"rows",rows);return out;}
 if(returned>bytes.size())throw std::runtime_error("CPU topology exceeds its returned buffer");
 size_t at=0;while(at<returned){
  if(returned-at<8)throw std::runtime_error("CPU topology header is truncated");DWORD size=0;CPU_SET_INFORMATION_TYPE type{};std::memcpy(&size,bytes.data()+at,4);std::memcpy(&type,bytes.data()+at+4,4);
  if(size<8||size>returned-at)throw std::runtime_error("CPU topology record size is invalid");
  if(type==CpuSetInformation){if(size<sizeof(SYSTEM_CPU_SET_INFORMATION))throw std::runtime_error("CPU set record is undersized");SYSTEM_CPU_SET_INFORMATION record{};std::memcpy(&record,bytes.data()+at,sizeof(record));const auto& cpu=record.CpuSet;auto row=EngineVar::dictionary();
   ::set(row,"id",EngineVar::integer(cpu.Id));::set(row,"group",EngineVar::integer(cpu.Group));::set(row,"logical_processor_index",EngineVar::integer(cpu.LogicalProcessorIndex));::set(row,"core_index",EngineVar::integer(cpu.CoreIndex));::set(row,"efficiency_class",EngineVar::integer(cpu.EfficiencyClass));::set(row,"last_level_cache_index",EngineVar::integer(cpu.LastLevelCacheIndex));::set(row,"numa_node_index",EngineVar::integer(cpu.NumaNodeIndex));::set(row,"flags",EngineVar::integer(cpu.AllFlags));::method(rows,"append",{row});
  }at+=size;
 }
 ::set(out,"error",EngineVar::integer(0));::set(out,"rows",rows);::set(out,"scope",EngineVar::text("Cold OS CPU-set snapshot; join group/logical_processor_index to sampled group/number. Higher efficiency_class means faster, less power-efficient in the Windows API; no CPU-index mapping is assumed."));return out;
}
struct Worker {uint64_t calls=0,samples=0,histogram_sum=0,first=0,last=0;DWORD thread_id=0;size_t ring_size=0;};
DWORD WINAPI worker_entry(void* pointer){
 auto& out=*static_cast<Worker*>(pointer);for(uint32_t n=0;n<30721;++n)frame();out.calls=state.calls;out.samples=state.samples;out.thread_id=state.thread_id;out.ring_size=static_cast<size_t>(std::min<uint64_t>(state.samples,capacity));for(size_t n=0;n<state.bins;++n)out.histogram_sum+=state.histogram[n].count;
 if(out.ring_size){out.first=state.ring[static_cast<size_t>((state.samples-out.ring_size)%capacity)].frame;out.last=state.ring[static_cast<size_t>((state.samples-1)%capacity)].frame;}return 0;
}
EngineVar selftest(){
 const auto before_calls=state.calls,before_samples=state.samples;Worker workers[2]{};HANDLE handles[2]{};
 for(size_t n=0;n<2;++n){handles[n]=CreateThread(nullptr,0,worker_entry,&workers[n],0,nullptr);if(!handles[n]){for(size_t j=0;j<n;++j){WaitForSingleObject(handles[j],INFINITE);CloseHandle(handles[j]);}throw std::runtime_error("CPU survey worker creation failed");}}
 for(auto handle:handles){WaitForSingleObject(handle,INFINITE);CloseHandle(handle);}
 auto out=EngineVar::dictionary(),rows=::array_empty();bool success=before_calls==state.calls&&before_samples==state.samples;
 for(const auto& worker:workers){const bool correct=enabled?(worker.calls==30721&&worker.samples==257&&worker.histogram_sum==257&&worker.ring_size==256&&worker.first==121&&worker.last==30721&&worker.thread_id!=0):(worker.calls==0&&worker.samples==0&&worker.histogram_sum==0&&worker.ring_size==0&&worker.thread_id==0);success=success&&correct;auto row=EngineVar::dictionary();::set(row,"success",EngineVar::boolean(correct));::set(row,"calls",EngineVar::integer(static_cast<int64_t>(worker.calls)));::set(row,"samples",EngineVar::integer(static_cast<int64_t>(worker.samples)));::set(row,"histogram_sum",EngineVar::integer(static_cast<int64_t>(worker.histogram_sum)));::set(row,"thread_id",EngineVar::integer(worker.thread_id));::set(row,"ring_size",EngineVar::integer(static_cast<int64_t>(worker.ring_size)));::set(row,"first_frame",EngineVar::integer(static_cast<int64_t>(worker.first)));::set(row,"last_frame",EngineVar::integer(static_cast<int64_t>(worker.last)));::method(rows,"append",{row});}
 if(enabled)success=success&&workers[0].thread_id!=workers[1].thread_id;
 ::set(out,"success",EngineVar::boolean(success));::set(out,"main_tls_unchanged",EngineVar::boolean(before_calls==state.calls&&before_samples==state.samples));::set(out,"workers",rows);return out;
}
EngineVar inspect(const EngineVar& input){
 if(::has(input,"reset")&&::get(input,"reset").boolean())state=State{};
 auto out=EngineVar::dictionary();const auto& value=state;auto bins=::array_empty(),records=::array_empty();
 for(size_t n=0;n<value.bins;++n){const auto& bin=value.histogram[n];auto row=EngineVar::dictionary();::set(row,"group",EngineVar::integer(bin.group));::set(row,"number",EngineVar::integer(bin.number));::set(row,"count",EngineVar::integer(static_cast<int64_t>(bin.count)));::method(bins,"append",{row});}
 const auto retained=static_cast<size_t>(std::min<uint64_t>(value.samples,capacity));for(size_t n=0;n<retained;++n){const auto& sample=value.ring[static_cast<size_t>((value.samples-retained+n)%capacity)];auto row=EngineVar::dictionary();::set(row,"frame",EngineVar::integer(static_cast<int64_t>(sample.frame)));::set(row,"group",EngineVar::integer(sample.group));::set(row,"number",EngineVar::integer(sample.number));::method(records,"append",{row});}
 FILETIME created{},exited{},kernel{},user{};const bool process_ok=GetProcessTimes(GetCurrentProcess(),&created,&exited,&kernel,&user)!=0;const auto process_created=process_ok?file_time(created):0;const bool thread_ok=GetThreadTimes(GetCurrentThread(),&created,&exited,&kernel,&user)!=0;
 ::set(out,"enabled",EngineVar::boolean(enabled));::set(out,"stride",EngineVar::integer(stride));::set(out,"capacity",EngineVar::integer(capacity));::set(out,"frame_calls",EngineVar::integer(static_cast<int64_t>(value.calls)));::set(out,"samples",EngineVar::integer(static_cast<int64_t>(value.samples)));::set(out,"dropped_distinct_cores",EngineVar::integer(static_cast<int64_t>(value.dropped)));::set(out,"frame_thread_id",EngineVar::integer(value.thread_id));::set(out,"report_thread_id",EngineVar::integer(GetCurrentThreadId()));::set(out,"process_id",EngineVar::integer(GetCurrentProcessId()));::set(out,"process_creation_100ns",EngineVar::integer(static_cast<int64_t>(process_created)));::set(out,"report_thread_creation_100ns",EngineVar::integer(static_cast<int64_t>(thread_ok?file_time(created):0)));::set(out,"histogram",bins);::set(out,"records",records);::set(out,"clocks_per_frame",EngineVar::integer(0));::set(out,"scope",EngineVar::text("TLS calling-thread Presentation frame-entry samples, not continuous residency. Join frame_thread_id/process creation to independent Windows main-thread proof. Migrations between samples are unobserved; no affinity/priority/power changes."));
 if(!::has(input,"topology")||::get(input,"topology").boolean())::set(out,"topology",topology());
 if(::has(input,"selftest")&&::get(input,"selftest").boolean())::set(out,"selftest",selftest());return out;
}
}
