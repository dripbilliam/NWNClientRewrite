#include "scene_snapshot.h"
// Staging copies the pinned shared ABI header next to this file.
#include "scene_snapshot_abi.hpp"
#include "core/object/class_db.h"
#include "core/os/thread.h"
#include "core/templates/local_vector.h"
#include "scene/3d/node_3d.h"

namespace {
using namespace nwn_scene_snapshot_abi;
PackedByteArray failure(uint8_t status) {
 PackedByteArray result;result.resize(header_bytes);header(result.ptrw(),0,status);return result;
}
}

int64_t NwnParticleSceneSnapshot::abi_version(){return nwn_scene_snapshot_abi::version;}
PackedByteArray NwnParticleSceneSnapshot::snapshot_nodes(const PackedInt64Array &ids,const PackedByteArray &roles) {
 using namespace nwn_scene_snapshot_abi;
 if(!Thread::is_main_thread())return failure(not_main_thread);
 if(sizeof(real_t)!=4)return failure(unsupported_precision);
 if(ids.size()!=roles.size()||ids.size()<0||uint64_t(ids.size())>maximum_rows)return failure(bad_request);
 LocalVector<Node3D *> nodes;nodes.resize(uint32_t(ids.size()));LocalVector<bool> present;present.resize(uint32_t(ids.size()));
 // Resolve/check ownership before taking any transforms. Unsupported thread
 // groups produce an explicit status; there is no substituted visibility/TRS.
 for(int64_t i=0;i<ids.size();++i) {
  if(roles[i]&~uint8_t(eligibility|validate|transform))return failure(bad_request);
  if(!roles[i]){nodes[i]=nullptr;present[i]=false;continue;}
  Object *object=ObjectDB::get_instance(ObjectID(uint64_t(ids[i])));present[i]=object!=nullptr;nodes[i]=Object::cast_to<Node3D>(object);
  // Validation-only rows read ObjectDB/type only. Actual scene getters require
  // a main-thread effective owner, checked in O(1) by the engine-owned cache.
  if(nodes[i]&&(roles[i]&(eligibility|transform))&&!nodes[i]->is_effective_process_thread_group_main_thread())return failure(unsupported_thread_group);
 }
 PackedByteArray result;result.resize(header_bytes+ids.size()*row_bytes);uint8_t *bytes=result.ptrw();uint32_t transforms=0,eligible=0;
 for(int64_t i=0;i<ids.size();++i) {
  uint8_t *row=bytes+header_bytes+i*row_bytes;std::memset(row,0,row_bytes);write64(row,uint64_t(ids[i]));write32(row+12,roles[i]);
  Node3D *node=nodes[i];uint32_t flags=present[i]?uint32_t(exists):uint32_t(0);
  if(node) {
   flags|=node3d;
   if((roles[i]&(eligibility|transform))&&node->is_inside_tree()) {
    flags|=inside;
    if((roles[i]&eligibility)&&node->is_visible_in_tree()) {
     flags|=visible;if(node->can_process()){flags|=processable;++eligible;}
    }
    if(roles[i]&transform) {
     const Transform3D pose=node->get_global_transform();
     for(size_t matrix_row=0;matrix_row<3;++matrix_row)for(size_t column=0;column<3;++column)write_float(row+16+(matrix_row*3+column)*4,float(pose.basis[matrix_row][column]));
     for(size_t axis=0;axis<3;++axis)write_float(row+16+(9+axis)*4,float(pose.origin[axis]));
     flags|=has_transform;++transforms;
    }
   }
  }
  write32(row+8,flags);
 }
 header(bytes,uint32_t(ids.size()),ok,transforms,eligible);return result;
}
void NwnParticleSceneSnapshot::_bind_methods() {
 ClassDB::bind_static_method("NwnParticleSceneSnapshot",D_METHOD("snapshot_nodes","ids","roles"),&NwnParticleSceneSnapshot::snapshot_nodes);
 ClassDB::bind_static_method("NwnParticleSceneSnapshot",D_METHOD("abi_version"),&NwnParticleSceneSnapshot::abi_version);
}
