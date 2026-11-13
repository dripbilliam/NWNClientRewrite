// Included inside particle_scene_boundary after the ABI1 globals. Optional
// interface names are queried ONLY after the engine advertises the capability.
GDExtensionInterfaceGetProcAddress direct_address=nullptr;
nwn_particle_scene_direct_v1::Eligibility direct_eligibility_binding=nullptr;
nwn_particle_scene_direct_v1::Transform direct_transform_binding=nullptr;
bool direct_requested=false,direct_available=false;
uint64_t direct_eligibility_calls=0,direct_source_checks=0,direct_pose_calls=0,direct_pose_reads=0,direct_pose_failures=0,direct_fallbacks=0;
void bind_direct(EngineVar& classdb) {
 if(!enabled||!direct_requested||!direct_address)return;
 if(!::method(classdb,"class_has_method",{EngineVar::text("NwnParticleSceneBoundary"),EngineVar::text("direct_abi_version")}).boolean())return;
 Name owner("NwnParticleSceneBoundary"),version_name("direct_abi_version");
 const auto version_binding=class_method(owner.data,version_name.data,2455072627);
 if(!version_binding)return;
 int64_t version=0;ptrcall(version_binding,nullptr,nullptr,&version);
 if(version!=1)return;
 using namespace nwn_particle_scene_direct_v1;
 const auto abi=reinterpret_cast<Abi>(direct_address(abi_name));
 if(!abi||abi()!=expected_fingerprint)return;
 direct_eligibility_binding=reinterpret_cast<Eligibility>(direct_address(eligibility_name));
 direct_transform_binding=reinterpret_cast<Transform>(direct_address(transform_name));
 direct_available=direct_eligibility_binding&&direct_transform_binding;
}
bool direct_active(){return enabled&&direct_requested&&direct_available;}
// Returns true if both answers are available. Unsupported calls request the
// original GDExtension fallback directly, avoiding a second capability probe.
bool eligible_source(int64_t id,uint64_t source_id,bool& eligible_result,bool& source_exists,bool& bypass_boundary) {
 bypass_boundary=false;
 if(!direct_active())return false;
 ++eligibility_calls;++direct_eligibility_calls;
 const auto flags=direct_eligibility_binding(uint64_t(id),source_id,1);
 if(flags&unsupported){++eligibility_fallbacks;++direct_fallbacks;bypass_boundary=true;return false;}
 ++eligibility_reads;eligible_result=(flags&processable)!=0;
 source_exists=eligible_result&&(flags&nwn_particle_scene_direct_v1::SOURCE_EXISTS)!=0;
 if(eligible_result)++direct_source_checks;
 return true;
}
void direct_info(EngineVar& out) {
 ::set(out,"direct_requested",EngineVar::boolean(direct_requested));
 ::set(out,"direct_available",EngineVar::boolean(direct_available));
 ::set(out,"direct_enabled",EngineVar::boolean(direct_active()));
 const auto field=[&](const char* name,uint64_t value){::set(out,name,EngineVar::integer(static_cast<int64_t>(value)));};
 field("direct_eligibility_calls",direct_eligibility_calls);field("direct_source_checks",direct_source_checks);
 field("direct_pose_calls",direct_pose_calls);field("direct_pose_reads",direct_pose_reads);field("direct_pose_failures",direct_pose_failures);field("direct_fallbacks",direct_fallbacks);
}
