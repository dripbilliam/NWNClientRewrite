// PRIVATE diagnostic derivative only. No worker, selection or default changes.
// Included inside the kernel's private namespace, after chrono/array declarations.
namespace particle_preparation_audit {
using AuditClock=std::chrono::steady_clock;
enum Phase:size_t {ELIGIBILITY,SOURCE_EXISTS,READINESS,CLOCK,CHANNELS,PATCH,
 POSE,SOURCE_POSE,SOURCE_PUBLISH,CONTEXT,ADMISSION,SIMULATION,EXISTING,BIRTHS,PHASE_COUNT};
inline constexpr const char* phase_names[PHASE_COUNT]={"eligibility","source_exists","readiness","clock",
 "channels","patch_detonate","emitter_pose","source_pose","source_publish","context",
 "admission","simulation_total","existing_prefix","birth_tail"};
enum Count:size_t {SOURCES,CHANNEL_SAMPLES,CONSTANT_HITS,POSE_READS,SOURCE_POSE_READS,
 POSE_SOURCE_SAME,POSE_ID_REPEATS,SOURCE_ID_REPEATS,POSE_SEGMENT_REPEATS,SOURCE_SEGMENT_REPEATS,ID_CAP_REJECTS,ACTIVE_BEFORE,
 CULLED,NOT_ANIMATING,FADED,CHUNK,WIND,BOUNCE,LIVE_CLOCK,READY_CALLBACK,PATCHED,
 SAFE_PREFIX,NO_BIRTH_PREFIX,GROUPABLE_NO_BIRTH,SINGLE,FOUNTAIN,EXPLOSION,BIRTHS_CALLED,
 CLOCK_READS,BOUNDARIES,COUNT_COUNT};
inline constexpr const char* count_names[COUNT_COUNT]={"sources","sampled_channels","constant_hits",
 "emitter_pose_reads","source_pose_reads","same_pose_source","repeated_emitter_pose_id",
 "repeated_source_pose_id","same_segment_emitter_pose_repeats","same_segment_source_pose_repeats","id_cap_rejections","active_particles_before","culled",
 "animation_disabled","faded","chunk","wind","bounce","live_clock_boundary",
 "readiness_boundary","patch_boundary","callback_free_existing_sources",
 "conservative_no_birth_sources","groupable_no_birth_sources","single_sources",
 "fountain_sources","explosion_sources","birth_operations","clock_reads","conservative_boundaries"};
struct Data {
 std::array<uint64_t,PHASE_COUNT> nanoseconds{};
 std::array<uint64_t,COUNT_COUNT> counts{};
 uint64_t safe_existing_ns=0,no_birth_existing_ns=0,groupable_existing_ns=0;
 uint64_t segment=0,max_segment=0;
};
struct Frame {
 bool enabled=false,safe=false,no_birth=false,groupable=false;
 Data data;
 static constexpr size_t id_capacity=32768;
 uint64_t epoch=1;
 std::unordered_map<uint64_t,uint64_t> poses,sources;
 void pose(uint64_t id,bool source){
  if(!enabled)return;
  ++data.counts[source?SOURCE_POSE_READS:POSE_READS];auto& seen=source?sources:poses;
  auto found=seen.find(id);if(found!=seen.end()){++data.counts[source?SOURCE_ID_REPEATS:POSE_ID_REPEATS];if(found->second==epoch)++data.counts[source?SOURCE_SEGMENT_REPEATS:POSE_SEGMENT_REPEATS];found->second=epoch;return;}
  if(seen.size()==id_capacity){++data.counts[ID_CAP_REJECTS];return;}seen.emplace(id,epoch);
 }
 void boundary(){if(enabled){data.segment=0;++data.counts[BOUNDARIES];if(epoch==UINT64_MAX){poses.clear();sources.clear();epoch=1;}else ++epoch;}}
};
thread_local Frame* current=nullptr;
struct FrameScope {
 Frame* previous;
 explicit FrameScope(Frame& next):previous(current){current=&next;}
 ~FrameScope(){current=previous;}
};
inline Frame* active(){return current&&current->enabled?current:nullptr;}
inline void count(Count key,uint64_t amount=1){if(auto* frame=active())frame->data.counts[key]+=amount;}
struct CallbackScope {
 Frame* previous;
 CallbackScope():previous(current){if(auto* frame=active())frame->boundary();current=nullptr;}
 ~CallbackScope(){current=previous;}
};
struct Span {
 Frame* frame;Phase phase;AuditClock::time_point began{};bool finished=false,safe=false,no_birth=false,groupable=false;
 explicit Span(Phase next):frame(active()),phase(next){if(frame){if(phase==EXISTING){safe=frame->safe;no_birth=frame->no_birth;groupable=frame->groupable;}began=AuditClock::now();++frame->data.counts[CLOCK_READS];}}
 Span(const Span&)=delete;Span& operator=(const Span&)=delete;
 void finish(){
  if(!frame||finished)return;finished=true;const auto ended=AuditClock::now();++frame->data.counts[CLOCK_READS];
  const auto ns=static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(ended-began).count());
  frame->data.nanoseconds[phase]+=ns;
  if(phase==EXISTING){if(safe)frame->data.safe_existing_ns+=ns;if(no_birth)frame->data.no_birth_existing_ns+=ns;if(groupable)frame->data.groupable_existing_ns+=ns;}
 }
 ~Span(){finish();}
};
// Output is deliberately cold and bounded. Timings are instrumented diagnostics,
// not an improvement or an uninstrumented normal-throughput acceptance result.
EngineVar publish(const Data& value){
 auto out=EngineVar::dictionary(),phases=EngineVar::dictionary(),counts=EngineVar::dictionary();
 for(size_t index=0;index<PHASE_COUNT;++index)::set(phases,phase_names[index],EngineVar::number(static_cast<double>(value.nanoseconds[index])*1e-6));
 for(size_t index=0;index<COUNT_COUNT;++index)::set(counts,count_names[index],EngineVar::integer(static_cast<int64_t>(value.counts[index])));
 ::set(out,"phases_ms",phases);::set(out,"counts",counts);
 ::set(out,"callback_free_existing_ms",EngineVar::number(static_cast<double>(value.safe_existing_ns)*1e-6));
 ::set(out,"conservative_no_birth_existing_ms",EngineVar::number(static_cast<double>(value.no_birth_existing_ns)*1e-6));
 ::set(out,"groupable_no_birth_existing_ms",EngineVar::number(static_cast<double>(value.groupable_existing_ns)*1e-6));
 ::set(out,"max_conservative_segment",EngineVar::integer(static_cast<int64_t>(value.max_segment)));
 ::set(out,"scope",EngineVar::text("Private profile=false sparse instrumentation; simulation_total includes existing_prefix and birth_tail. Existing costs include original mutations/services; categories are conservative hypotheses, not worker engagement. Sources/particles counted before simulation. No pipeline or RNG changes."));return out;
}
} // namespace particle_preparation_audit
