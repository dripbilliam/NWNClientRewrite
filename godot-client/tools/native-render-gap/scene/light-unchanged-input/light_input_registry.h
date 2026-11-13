#pragma once
#include "core/object/ref_counted.h"
#include "modules/gdscript/gdscript.h"
#include "core/math/vector3.h"
#include "core/variant/dictionary.h"
#include <unordered_map>
#include <vector>

class Node3D;

// Private OPTIONAL counterpart of the existing extension's input registry.
// It retains only that registry's rows, not a second entity/world store.
class NwnBuiltinLightInputRegistry : public RefCounted {
 GDCLASS(NwnBuiltinLightInputRegistry, RefCounted);
 struct Entry {
  int64_t id=0, source=0, revision=-1, owner=0, priority=0;
  bool published=false, position_known=false, in_view=true;
  Vector3 position;
  double range=-1;
  Dictionary row;
  bool has_row=false;
 };
 std::unordered_map<int64_t,Entry> entries;
 std::vector<int64_t> order, pending_removed;
 bool closed=false, polling=false;
 uint64_t membership_generation=0;
 int64_t polls=0, view_tests=0, input_rows=0, reused=0, dead=0;
 StringName props_name="native_properties", revision_name="native_properties_revision", state_name="native_state";
 StringName enhanced_name="native_enhanced_light", priority_name="native_light_priority";
 bool plain_requested=false, plain_segment_requested=false;
 Ref<GDScript> plain_writer;
 String plain_source;
 int64_t plain_claims=0, plain_rows=0, plain_field_reads=0, plain_schema_checks=0, plain_source_rejections=0, plain_schema_rejections=0;
 int64_t plain_segment_proofs=0, plain_segment_reuses=0, plain_segment_invalidations=0;
 int64_t plain_member_index_reads=0,plain_member_index_proofs=0,plain_member_scratch_barriers=0;
 int64_t lifetime_staged_rows=0,lifetime_post_checks=0,lifetime_detached_releases=0;
 int64_t unchanged_fast_rows_total=0;
 bool plain_schema_valid(int *member_indices=nullptr);
 Dictionary enroll_plain_reader(const Variant &input);
 GDScriptInstance *plain_reader(Node3D *node,int *member_indices=nullptr);
 GDScriptInstance *plain_reader_segment(Node3D *node,bool &proven,int *member_indices=nullptr);
 Dictionary inspect() const;
 Dictionary poll(const Variant &input);
 void erase(int64_t id);
protected:
 static void _bind_methods();
public:
 NwnBuiltinLightInputRegistry();
 Dictionary dispatch(const Variant &operation, const Variant &input);
};
