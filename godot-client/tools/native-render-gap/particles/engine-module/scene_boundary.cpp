#include "scene_boundary.h"
#include "core/object/class_db.h"
#include "core/os/thread.h"
#include "scene/3d/node_3d.h"
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
}

int64_t NwnParticleSceneBoundary::abi_version(){return 1;}
int64_t NwnParticleSceneBoundary::eligibility_flags(int64_t p_id) {
 if(!Thread::is_main_thread()||sizeof(real_t)!=4)return UNSUPPORTED;
 Object *object=ObjectDB::get_instance(ObjectID(uint64_t(p_id)));
 if(!object)return 0;
 Node3D *node=Object::cast_to<Node3D>(object);
 if(!node)return EXISTS;
 if(!node->is_effective_process_thread_group_main_thread())return EXISTS|NODE3D|UNSUPPORTED;
 int64_t result=EXISTS|NODE3D;
 // Keep short-circuit getter order identical to particle_frame_group::eligible.
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
 // Call the real getter each time. It resolves dirty ancestors and preserves
 // its existing outside-tree diagnostic/identity result. Do not cache this.
 return node->get_global_transform();
}
int64_t NwnParticleSceneBoundary::pose_status(){return last_pose_status;}
void NwnParticleSceneBoundary::_bind_methods() {
 ClassDB::bind_static_method("NwnParticleSceneBoundary",D_METHOD("abi_version"),&NwnParticleSceneBoundary::abi_version);
 ClassDB::bind_static_method("NwnParticleSceneBoundary",D_METHOD("eligibility_flags","id"),&NwnParticleSceneBoundary::eligibility_flags);
 ClassDB::bind_static_method("NwnParticleSceneBoundary",D_METHOD("global_transform","id"),&NwnParticleSceneBoundary::global_transform);
 ClassDB::bind_static_method("NwnParticleSceneBoundary",D_METHOD("pose_status"),&NwnParticleSceneBoundary::pose_status);
}
