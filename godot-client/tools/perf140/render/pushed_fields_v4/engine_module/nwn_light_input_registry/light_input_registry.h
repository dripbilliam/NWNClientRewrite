#pragma once
#include "core/object/ref_counted.h"
#include "core/object/script_language.h"
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
  int64_t token=0, publication=-1, pushed_revision=-1;
  bool pushed=false;
  Ref<Script> writer;
  String writer_source;
  Dictionary pushed_properties, pushed_state;
 };
 std::unordered_map<int64_t,Entry> entries;
 std::vector<int64_t> order, pending_removed;
 bool closed=false, polling=false;
 uint64_t membership_generation=0;
 int64_t registration_serial=0;
 int64_t cached_members=0, field_cache_hits=0, reflected_field_reads=0, capability_reads=0, claims=0, publications=0, revocations=0, stale_packets=0, script_revocations=0, binding_revocations=0;
 int64_t polls=0, view_tests=0, input_rows=0, reused=0, dead=0;
 StringName props_name="native_properties", revision_name="native_properties_revision", state_name="native_state";
 StringName enhanced_name="native_enhanced_light", priority_name="native_light_priority";
 Dictionary inspect() const;
 Dictionary poll(const Variant &input);
 void erase(int64_t id);
 bool publication_writer_valid(Entry &entry, Node3D *node);
protected:
 static void _bind_methods();
public:
 Dictionary dispatch(const Variant &operation, const Variant &input);
};
