// Included inside particle_presentation, after its Clock alias. Main-thread
// native presentation wall samples, not GPU or calling-thread CPU utilization.
namespace setup_clock_route {
GDExtensionPtrBuiltInMethod callable_null=nullptr,callable_custom=nullptr;
void bind(){Name null_name("is_null"),custom_name("is_custom");callable_null=builtin_method(GDEXTENSION_VARIANT_TYPE_CALLABLE,null_name.data,3918633141);callable_custom=builtin_method(GDEXTENSION_VARIANT_TYPE_CALLABLE,custom_name.data,3918633141);}
// 0=non-Callable (the old valid_callable always returns false),1=structurally
// null/noncustom Callable,2=all other Callable values, including invalid ones.
uint8_t classify(const EngineVar& value){
 if(value.type()!=GDEXTENSION_VARIANT_TYPE_CALLABLE)return 0;
 if(!callable_null||!callable_custom)return 2;
 alignas(8) uint8_t raw[16];to[GDEXTENSION_VARIANT_TYPE_CALLABLE](raw,const_cast<uint8_t*>(value.data));
 GDExtensionBool custom=false,is_null=false;callable_custom(raw,nullptr,&custom,0);if(!custom)callable_null(raw,nullptr,&is_null,0);ptr_destructor(GDEXTENSION_VARIANT_TYPE_CALLABLE)(raw);
 return !custom&&is_null?1:2;
}
}
struct FrameSampler {
 static constexpr size_t capacity=256;
 struct Invocation {bool profile_seen=false,profile=false;uint32_t phase_mask=0;std::array<Clock::time_point,4> points{};resident::ExternalCallCounts external;uint64_t clocks=0,readiness=0,fallbacks=0,lighting_rows=0;};
 struct Sample {uint64_t call=0;int64_t generation=0,registered=0,prepared=0,culled=0,active=0;double wall_ms=0;std::array<double,5> phases{};resident::ExternalCallCounts external;uint64_t clocks=0,readiness=0,fallbacks=0,lighting_rows=0;bool success=false,setup=false,boundary=false,phase_complete=false;};
 bool coarse_phases=false;uint64_t phase_clock_reads=0,phase_success_samples=0;std::array<double,5> phase_success_sum{};
 bool enabled=false;uint64_t stride=120,min_members=0,calls=0,eligible=0,clock_pairs=0,detailed=0,unclassified=0,samples=0,successes=0,errors=0;
 double sum_success_ms=0,max_success_ms=0;std::array<Sample,capacity> ring{};
 void configure(const EngineVar& input){
  if(input.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Sparse frame sampler requires a dictionary");
  const bool next_enabled=::get(input,"enabled").boolean();
  const int64_t next_stride=::has(input,"stride")?::get(input,"stride").integer():static_cast<int64_t>(stride);
  const int64_t next_min=::has(input,"min_members")?::get(input,"min_members").integer():static_cast<int64_t>(min_members);
  const bool next_coarse=::has(input,"coarse_phases")?::get(input,"coarse_phases").boolean():coarse_phases;
  const bool reset=::has(input,"reset")&&::get(input,"reset").boolean();
  if(next_stride<1||next_stride>4096||next_min<0||next_min>1000000)throw std::runtime_error("Sparse sampler stride/member threshold is out of range");
  if(reset){phase_clock_reads=phase_success_samples=0;phase_success_sum={};calls=eligible=clock_pairs=detailed=unclassified=samples=successes=errors=0;sum_success_ms=max_success_ms=0;}
  coarse_phases=next_coarse;enabled=next_enabled;stride=static_cast<uint64_t>(next_stride);min_members=static_cast<uint64_t>(next_min);
 }
 bool select(size_t members){++calls;if(members<min_members)return false;return eligible++%stride==0;}
 void record(const Invocation& invocation,Sample sample){
  ++clock_pairs;if(!invocation.profile_seen){++unclassified;return;}if(invocation.profile){++detailed;return;}
  ring[samples%capacity]=sample;++samples;if(sample.success&&sample.phase_complete){++phase_success_samples;for(size_t index=0;index<5;++index)phase_success_sum[index]+=sample.phases[index];}if(sample.success){++successes;sum_success_ms+=sample.wall_ms;max_success_ms=std::max(max_success_ms,sample.wall_ms);}else ++errors;
 }
 EngineVar inspect()const{
  auto out=EngineVar::dictionary();const auto number=[&](const char* name,uint64_t value){::set(out,name,EngineVar::integer(static_cast<int64_t>(value)));};
  ::set(out,"enabled",EngineVar::boolean(enabled));number("stride",stride);number("min_members",min_members);number("calls",calls);number("eligible_calls",eligible);number("scheduled_clock_pairs",clock_pairs);number("excluded_detailed_samples",detailed);number("unclassified_samples",unclassified);number("samples",samples);number("successes",successes);number("errors",errors);number("capacity",capacity);
  ::set(out,"success_mean_ms",EngineVar::number(successes?sum_success_ms/static_cast<double>(successes):0));::set(out,"success_max_ms",EngineVar::number(max_success_ms));
  ::set(out,"coarse_phases",EngineVar::boolean(coarse_phases));number("phase_clock_reads",phase_clock_reads);number("phase_success_samples",phase_success_samples);
  const std::array<const char*,5> phase_names{"input_parse_ms","entry_advance_ms","sort_geometry_pack_ms","counter_publish_ms","summary_ms"};
  auto means=EngineVar::dictionary();for(size_t index=0;index<5;++index)::set(means,phase_names[index],EngineVar::number(phase_success_samples?phase_success_sum[index]/static_cast<double>(phase_success_samples):0));::set(out,"phase_success_means",means);
  ::set(out,"clock_domain",EngineVar::text("presentation calling-thread steady_clock wall"));::set(out,"scope",EngineVar::text("Owner::frame including input parsing/simulation/geometry/summary; excludes dispatch result copy and renderer submit; only profile-OFF samples retained"));
  auto rows=::array_empty();std::vector<double> times;const auto count=std::min<uint64_t>(samples,capacity),first=samples-count;times.reserve(static_cast<size_t>(count));
  for(uint64_t index=first;index<samples;++index){const auto& sample=ring[index%capacity];auto row=EngineVar::dictionary();::set(row,"call",EngineVar::integer(static_cast<int64_t>(sample.call)));::set(row,"generation",EngineVar::integer(sample.generation));::set(row,"registered",EngineVar::integer(sample.registered));::set(row,"prepared",EngineVar::integer(sample.prepared));::set(row,"culled",EngineVar::integer(sample.culled));::set(row,"active",EngineVar::integer(sample.active));::set(row,"wall_ms",EngineVar::number(sample.wall_ms));::set(row,"success",EngineVar::boolean(sample.success));::set(row,"phase_complete",EngineVar::boolean(sample.phase_complete));if(sample.phase_complete)for(size_t phase_index=0;phase_index<5;++phase_index)::set(row,phase_names[phase_index],EngineVar::number(sample.phases[phase_index]));::set(row,"external_random_calls",EngineVar::integer(static_cast<int64_t>(sample.external.random)));::set(row,"external_cosine_calls",EngineVar::integer(static_cast<int64_t>(sample.external.cosine)));::set(row,"external_other_calls",EngineVar::integer(static_cast<int64_t>(sample.external.other)));::set(row,"clock_provider_calls",EngineVar::integer(static_cast<int64_t>(sample.clocks)));::set(row,"readiness_provider_calls",EngineVar::integer(static_cast<int64_t>(sample.readiness)));::set(row,"fallback_provider_calls",EngineVar::integer(static_cast<int64_t>(sample.fallbacks)));::set(row,"lighting_rows",EngineVar::integer(static_cast<int64_t>(sample.lighting_rows)));::set(row,"setup_boundary",EngineVar::boolean(sample.setup));::set(row,"scene_boundary",EngineVar::boolean(sample.boundary));::method(rows,"append",{row});if(sample.success)times.push_back(sample.wall_ms);}
  std::sort(times.begin(),times.end());::set(out,"ring_p95_ms",EngineVar::number(times.empty()?0:times[static_cast<size_t>((times.size()-1)*0.95)]));::set(out,"records",rows);return out;
 }
};
