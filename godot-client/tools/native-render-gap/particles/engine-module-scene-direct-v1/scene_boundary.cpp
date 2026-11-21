#include "scene_boundary.h"
#include "particle_scene_direct_abi.hpp"
#include "core/extension/gdextension.h"
#include "core/object/class_db.h"
#include "core/os/thread.h"
#include "scene/3d/node_3d.h"
#include <cstring>
#include <limits>

namespace {
thread_local int64_t last_pose_status=NwnParticleSceneBoundary::OK;
Transform3D failure(int64_t p_status) {
 last_pose_status=p_status;
 const real_t value=std::numeric_limits<real_t>::quiet_NaN();
 Transform3D result;
 for(int row=0;row<3;++row)for(int column=0;column<3;++column)result.basis[row][column]=value;
 result.origin=Vector3(value,value,value);
 return result;
}
uint64_t direct_abi() {
 return nwn_particle_scene_direct_v1::fingerprint(sizeof(void*),sizeof(real_t),sizeof(Transform3D));
}
uint64_t direct_eligibility(uint64_t p_id,uint64_t p_source_id,uint32_t p_check_source) {
 // Preserve the existing eligibility getter order and short circuits. It
 // resolves one current ObjectDB identity and retains no scene pointer.
 const auto flags=uint64_t(NwnParticleSceneBoundary::eligibility_flags(int64_t(p_id)));
 if((flags&NwnParticleSceneBoundary::UNSUPPORTED)||!(flags&NwnParticleSceneBoundary::PROCESSABLE)||!p_check_source)return flags;
 // No callbacks occur between eligibility and the original source precheck.
 // Source existence is not a Node3D/type check at this earlier boundary.
 return flags|(ObjectDB::get_instance(ObjectID(p_source_id))?nwn_particle_scene_direct_v1::SOURCE_EXISTS:0);
}
int32_t direct_transform(uint64_t p_id,float* p_destination,uint32_t p_capacity) {
 using namespace nwn_particle_scene_direct_v1;
 if(!Thread::is_main_thread())return UNSUPPORTED_THREAD;
 if(sizeof(real_t)!=4)return UNSUPPORTED_PRECISION;
 if(!p_destination||p_capacity<12)return BAD_DESTINATION;
 Object *object=ObjectDB::get_instance(ObjectID(p_id));
 if(!object)return ABSENT;
 Node3D *node=Object::cast_to<Node3D>(object);
 if(!node)return WRONG_TYPE;
 if(!node->is_effective_process_thread_group_main_thread())return UNSUPPORTED_THREAD;
 // One getter only. The extension completes conversion/error handling before
 // asking this function for its later source pose; no fused pose snapshot.
 const Transform3D current=node->get_global_transform();
 static_assert(sizeof(Transform3D)==12*sizeof(real_t),"Expected Godot Transform3D POD layout");
 std::memcpy(p_destination,&current,12*sizeof(float));
 return nwn_particle_scene_direct_v1::OK;
}
}

int64_t NwnParticleSceneBoundary::abi_version(){return 1;}
int64_t NwnParticleSceneBoundary::direct_abi_version(){return sizeof(void*)==8&&sizeof(real_t)==4?1:0;}
int64_t NwnParticleSceneBoundary::eligibility_flags(int64_t p_id) {
 if(!Thread::is_main_thread()||sizeof(real_t)!=4)return UNSUPPORTED;
 Object *object=ObjectDB::get_instance(ObjectID(uint64_t(p_id)));
 if(!object)return 0;
 Node3D *node=Object::cast_to<Node3D>(object);
 if(!node)return EXISTS;
 if(!node->is_effective_process_thread_group_main_thread())return EXISTS|NODE3D|UNSUPPORTED;
 int64_t result=EXISTS|NODE3D;
 if(!node->is_inside_tree())return result;
 result|=INSIDE;
 if(!node->is_visible_in_tree())return result;
 result|=VISIBLE;
 if(node->can_process())result|=PROCESSABLE;
 return result;
}
Transform3D NwnParticleSceneBoundary::global_transform(int64_t p_id) {
 if(!Thread::is_main_thread())return failure(UNSUPPORTED_THREAD);
 if(sizeof(real_t)!=4)return failure(UNSUPPORTED_PRECISION);
 Object *object=ObjectDB::get_instance(ObjectID(uint64_t(p_id)));
 if(!object)return failure(ABSENT);
 Node3D *node=Object::cast_to<Node3D>(object);
 if(!node)return failure(WRONG_TYPE);
 if(!node->is_effective_process_thread_group_main_thread())return failure(UNSUPPORTED_THREAD);
 last_pose_status=OK;
 return node->get_global_transform();
}
int64_t NwnParticleSceneBoundary::pose_status(){return last_pose_status;}
void NwnParticleSceneBoundary::_bind_methods() {
 ClassDB::bind_static_method("NwnParticleSceneBoundary",D_METHOD("abi_version"),&NwnParticleSceneBoundary::abi_version);
 ClassDB::bind_static_method("NwnParticleSceneBoundary",D_METHOD("eligibility_flags","id"),&NwnParticleSceneBoundary::eligibility_flags);
 ClassDB::bind_static_method("NwnParticleSceneBoundary",D_METHOD("global_transform","id"),&NwnParticleSceneBoundary::global_transform);
 ClassDB::bind_static_method("NwnParticleSceneBoundary",D_METHOD("pose_status"),&NwnParticleSceneBoundary::pose_status);
 ClassDB::bind_static_method("NwnParticleSceneBoundary",D_METHOD("direct_abi_version"),&NwnParticleSceneBoundary::direct_abi_version);
 using namespace nwn_particle_scene_direct_v1;
 GDExtension::register_interface_function(abi_name,reinterpret_cast<GDExtensionInterfaceFunctionPtr>(&direct_abi));
 GDExtension::register_interface_function(eligibility_name,reinterpret_cast<GDExtensionInterfaceFunctionPtr>(&direct_eligibility));
 GDExtension::register_interface_function(transform_name,reinterpret_cast<GDExtensionInterfaceFunctionPtr>(&direct_transform));
}
