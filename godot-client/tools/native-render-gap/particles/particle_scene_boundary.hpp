// Include after the particle_resident.hpp GDExtension scene API declarations.
// Optional engine capability. Absent/unsupported helpers use the established
// live ObjectDB/ptrcall path at the same observable boundary.
std::string engine_string(const EngineVar& value);
namespace particle_scene_boundary {
GDExtensionMethodBindPtr eligibility_binding=nullptr,transform_binding=nullptr,status_binding=nullptr;
constexpr int64_t unsupported=1LL<<30,processable=16;
bool enabled=false;
bool available=false;
uint64_t eligibility_calls=0,eligibility_reads=0,eligibility_fallbacks=0,pose_calls=0,pose_reads=0,pose_fallbacks=0,pose_failures=0;
bool bind(){
 {Name os_name("OS");auto os_object=global_singleton(os_name.data);if(os_object){EngineVar os;destroy(os.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](os.data,&os_object);auto args=::method(os,"get_cmdline_user_args");const auto choice=::method(os,"get_environment",{EngineVar::text("NWN_PARTICLE_SCENE_BOUNDARY")});enabled=engine_string(choice)=="native"||::method(args,"has",{EngineVar::text("--particle-scene-boundary=native")}).boolean();if(::method(args,"has",{EngineVar::text("--particle-scene-boundary=legacy")}).boolean())enabled=false;}}
 Name service("ClassDB");auto object=global_singleton(service.data);if(!object)return false;
 EngineVar classdb;destroy(classdb.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](classdb.data,&object);
 if(!::method(classdb,"class_exists",{EngineVar::text("NwnParticleSceneBoundary")}).boolean())return false;
 Name owner("NwnParticleSceneBoundary"),abi("abi_version"),eligibility("eligibility_flags"),transform("global_transform"),status("pose_status");
 auto version=class_method(owner.data,abi.data,2455072627);
 if(!version)return false;int64_t actual=0;ptrcall(version,nullptr,nullptr,&actual);if(actual!=1)return false;
 eligibility_binding=class_method(owner.data,eligibility.data,3744713108);
 transform_binding=class_method(owner.data,transform.data,2963875352);
 status_binding=class_method(owner.data,status.data,2455072627);
 return available=eligibility_binding&&transform_binding&&status_binding;
}
// A fallback request is separate from a false eligibility result. No cached
// node pointer or identity survives a call, including free/rebind boundaries.
bool eligible(int64_t id,bool& result){
 if(!enabled||!available)return false;++eligibility_calls;int64_t flags=0;const GDExtensionConstTypePtr args[]={&id};ptrcall(eligibility_binding,nullptr,args,&flags);
 if(flags&unsupported){++eligibility_fallbacks;return false;}++eligibility_reads;result=(flags&processable)!=0;return true;
}
bool pose(uint64_t id,std::array<float,12>& result){
 if(!enabled||!available)return false;++pose_calls;const auto signed_id=static_cast<int64_t>(id);const GDExtensionConstTypePtr args[]={&signed_id};ptrcall(transform_binding,nullptr,args,result.data());
 bool sentinel=true;for(const auto value:result)if(!std::isnan(value)){sentinel=false;break;}
 if(!sentinel){++pose_reads;return true;}
 int64_t status=0;ptrcall(status_binding,nullptr,nullptr,&status);
 if(status==0){++pose_reads;return true;} // A legitimate all-NaN transform is not a failure.
 if(status==1||status==2){++pose_failures;throw std::runtime_error("Native particle pose owner is absent or no longer Node3D");}
 ++pose_fallbacks;return false;
}
EngineVar inspect(){auto out=EngineVar::dictionary();::set(out,"enabled",EngineVar::boolean(enabled));::set(out,"available",EngineVar::boolean(available));const auto field=[&](const char* name,uint64_t value){::set(out,name,EngineVar::integer(static_cast<int64_t>(value)));};field("eligibility_calls",eligibility_calls);field("eligibility_reads",eligibility_reads);field("eligibility_fallbacks",eligibility_fallbacks);field("pose_calls",pose_calls);field("pose_reads",pose_reads);field("pose_fallbacks",pose_fallbacks);field("pose_failures",pose_failures);return out;}
}
