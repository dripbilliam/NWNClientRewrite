#include "rig_skin_publisher.h"
#include "core/object/class_db.h"
#include "core/os/thread.h"
#include "core/os/os.h"
#include "scene/3d/node_3d.h"
#include "scene/3d/skeleton_3d.h"

namespace {
bool batch_bone_components() {
 static const bool enabled=OS::get_singleton()&&OS::get_singleton()->get_cmdline_user_args().find("--rig-bone-components=reference")==nullptr;
 return enabled;
}
// Unsupported/custom shapes fall back before the first write. These checks
// do not substitute a pose, omit a setter, or change an animation clock.
bool array_field(const Dictionary &p_record,const char *p_name,Array &r_value) {
 const Variant *value=p_record.getptr(p_name);
 if(!value||value->get_type()!=Variant::ARRAY)return false;
 r_value=*value;return true;
}
Node3D *plain_node(const Variant &p_value) {
 if(p_value.get_type()!=Variant::OBJECT)return nullptr;
 Node3D *node=Object::cast_to<Node3D>(static_cast<Object *>(p_value));
 if(!node||node->get_script_instance()||!node->is_effective_process_thread_group_main_thread())return nullptr;
 return node;
}
Skeleton3D *plain_skeleton(const Dictionary &p_skin) {
 const Variant *value=p_skin.getptr("skeleton");
 if(!value||value->get_type()!=Variant::OBJECT)return nullptr;
 Skeleton3D *skeleton=Object::cast_to<Skeleton3D>(static_cast<Object *>(*value));
 if(!skeleton||skeleton->get_script_instance()||!skeleton->is_effective_process_thread_group_main_thread())return nullptr;
 return skeleton;
}
bool integer_field(const Dictionary &p_record,const char *p_name,int64_t &r_value) {
 const Variant *value=p_record.getptr(p_name);
 if(!value||value->get_type()!=Variant::INT)return false;
 r_value=*value;return true;
}
bool skin_supported(const Dictionary &p_skin,int64_t p_node_count,Skeleton3D **r_skeleton=nullptr) {
 int64_t part=0;if(!integer_field(p_skin,"part",part)||part<0||part>=p_node_count)return false;
 Skeleton3D *skeleton=plain_skeleton(p_skin);if(!skeleton)return false;
 Array bones;if(!array_field(p_skin,"bones",bones)||bones.size()>skeleton->get_bone_count())return false;
 for(int64_t slot=0;slot<bones.size();++slot){if(bones[slot].get_type()!=Variant::INT)return false;const int64_t index=bones[slot];if(index>=p_node_count)return false;}
 if(r_skeleton)*r_skeleton=skeleton;
 return true;
}
}

int64_t NwnRigSkinPublisher::abi_version(){return 2;}
int64_t NwnRigSkinPublisher::continue_legacy(int64_t p_start,const Array &p_skins) {
 continuation_start=p_start;continuation_skins=p_skins;++continuations;return PARTIAL_FAILURE;
}
bool NwnRigSkinPublisher::configure(const Dictionary &p_entry) {
 if(configured||running||!Thread::is_main_thread()||sizeof(real_t)!=4)return false;
 // Do not put this owner back into p_entry: that would create a RefCounted /
 // Dictionary cycle. ModelRigs owns publishers in a separate id-keyed table.
 Array nodes,parents,skins;
 if(!array_field(p_entry,"nodes",nodes)||!array_field(p_entry,"parents",parents)||!array_field(p_entry,"skins",skins))return false;
 entry=p_entry;rigid.resize(nodes.size());configured=true;return true;
}
int64_t NwnRigSkinPublisher::publish() {
 ++calls;
 if(running)return REENTRANT;
 if(continuation_start>=0){continuation_start=-1;continuation_skins=Array();}
 if(!configured||!Thread::is_main_thread()||sizeof(real_t)!=4){++fallbacks;return FALLBACK;}
 // A force_update callback may remove the last script-side reference. Match
 // the ordinary local entry's lifetime through this complete synchronous call.
 Ref<NwnRigSkinPublisher> keep_alive(this);
 running=true;
 struct RunningGuard{bool &running;~RunningGuard(){running=false;}}guard{running};
 Array nodes,parents,skins;
 if(!array_field(entry,"nodes",nodes)||!array_field(entry,"parents",parents)||!array_field(entry,"skins",skins)||nodes.size()!=parents.size()){++fallbacks;return FALLBACK;}
 const int64_t count=nodes.size();
 // Preflight all current inputs before the first Skeleton write. Node reads
 // and Transform3D arithmetic below call no script or user callback.
 for(int64_t index=0;index<count;++index){
  if(!plain_node(nodes[index])||parents[index].get_type()!=Variant::INT){++fallbacks;return FALLBACK;}
  const int64_t parent=parents[index];if(parent< -1||parent>=index){++fallbacks;return FALLBACK;}
 }
 for(int64_t index=0;index<skins.size();++index){if(skins[index].get_type()!=Variant::DICTIONARY||!skin_supported(skins[index],count)){++fallbacks;return FALLBACK;}}
 rigid.resize(count);
 Transform3D *matrices=rigid.ptrw();
 for(int64_t index=0;index<count;++index){
  // Every current Array element was just proved a live plain main-thread
  // Node3D. The complete node/skin preflight and this matrix loop contain
  // no callback, Array mutation or authored-object release. Reuse that
  // invocation-local type proof; never retain this pointer across a force.
  Node3D *node=static_cast<Node3D *>(static_cast<Object *>(nodes[index]));
  // Deliberately use quaternion and position, with no scale. This is exactly
  // ModelRigs' established rigid skin convention and operation order.
  const Quaternion rotation=node->get_quaternion();
  const Vector3 position=node->get_position();
  const Transform3D local(Basis(rotation),position);
  const int64_t parent=parents[index];
  matrices[index]=parent== -1?local:matrices[parent]*local;
  ++node_reads;
 }
 // Match the live Array iteration. A force-update signal may replace/mutate a
 // later skin Dictionary or its bones; read it again at its actual boundary.
 for(int64_t skin_index=0;skin_index<skins.size();++skin_index){
  if(skins[skin_index].get_type()!=Variant::DICTIONARY)return continue_legacy(skin_index,skins);
  const Dictionary skin=skins[skin_index];
  Skeleton3D *skeleton=nullptr;
  if(!skin_supported(skin,count,&skeleton))return continue_legacy(skin_index,skins);
  const int64_t part=skin["part"];
  const Transform3D inverse=matrices[part].affine_inverse();
  Array bones;array_field(skin,"bones",bones);
  const int64_t slots=bones.size();
  for(int64_t slot=0;slot<slots;++slot){
   const int64_t index=bones[slot];
   const Transform3D transform=index<0?Transform3D():inverse*matrices[index];
   if(batch_bone_components()){
    skeleton->nwn_set_bone_pose_components(int(slot),transform.origin,transform.basis.get_rotation_quaternion(),Vector3(1,1,1));
   }else{
    skeleton->set_bone_pose_position(int(slot),transform.origin);
    skeleton->set_bone_pose_rotation(int(slot),transform.basis.get_rotation_quaternion());
    skeleton->set_bone_pose_scale(int(slot),Vector3(1,1,1));
   }
   ++bone_writes;
  }
  // Do not replace this with deferred publication or skip unchanged writes.
  // Force-update signals remain between skins, in the same order as before.
  skeleton->force_update_all_bone_transforms();++force_calls;
 }
 ++completed;return COMPLETE;
}
Dictionary NwnRigSkinPublisher::take_continuation() {
 Dictionary out;if(running||continuation_start<0)return out;
 // Only the uncommon after-force fallback allocates this detached matrix
 // Array. Later reentrant updates may reuse native scratch, never this copy.
 Array matrices;matrices.resize(rigid.size());
 for(int64_t index=0;index<rigid.size();++index)matrices[index]=rigid[index];
 out["rigid"]=matrices;out["skins"]=continuation_skins;out["start"]=continuation_start;
 continuation_start=-1;continuation_skins=Array();return out;
}
Dictionary NwnRigSkinPublisher::inspect() const {
 Dictionary out;out["bone_components_batched"]=batch_bone_components();out["bone_setter_calls"]=bone_writes*(batch_bone_components()?1:3);out["configured"]=configured;out["running"]=running;out["calls"]=calls;out["completed"]=completed;out["fallbacks"]=fallbacks;out["partial_failures"]=partial_failures;out["continuations"]=continuations;out["node_reads"]=node_reads;out["bone_writes"]=bone_writes;out["force_calls"]=force_calls;out["continuation_pending"]=continuation_start>=0;return out;
}
void NwnRigSkinPublisher::_bind_methods() {
 ClassDB::bind_static_method("NwnRigSkinPublisher",D_METHOD("abi_version"),&NwnRigSkinPublisher::abi_version);
 ClassDB::bind_method(D_METHOD("configure","entry"),&NwnRigSkinPublisher::configure);
 ClassDB::bind_method(D_METHOD("publish"),&NwnRigSkinPublisher::publish);
 ClassDB::bind_method(D_METHOD("take_continuation"),&NwnRigSkinPublisher::take_continuation);
 ClassDB::bind_method(D_METHOD("inspect"),&NwnRigSkinPublisher::inspect);
}
