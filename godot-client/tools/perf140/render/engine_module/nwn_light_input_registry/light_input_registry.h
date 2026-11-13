#pragma once
#include "core/object/ref_counted.h"
#include "core/math/vector3.h"
#include "core/variant/dictionary.h"
#include <unordered_map>
#include <vector>

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
 Dictionary inspect() const;
 Dictionary poll(const Variant &input);
 void erase(int64_t id);
protected:
 static void _bind_methods();
public:
 Dictionary dispatch(const Variant &operation, const Variant &input);
};
