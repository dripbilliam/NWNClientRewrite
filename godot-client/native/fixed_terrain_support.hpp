// Batched support for the fixed terrain column index. Reuse Godot's exact
// transform operators and the same native polygon kernel as the Part route.
namespace fixed_terrain_support {
using scene_model::Matrix;

int outside(const V3& point, const V3& low, const V3& high) {
 int mask = 0;
 for (size_t axis = 0; axis < 3; ++axis) {
  mask |= (point[axis] < low[axis] ? 2 : (point[axis] > high[axis] ? 1 : 0)) << ((2 - axis) * 2);
 }
 return mask;
}

bool authored_box_hit(const V3& start, const V3& end, const V3& low, const V3& high) {
 const int first = outside(start, low, high);
 if (first == 0) return true;
 if (first & outside(end, low, high)) return false;
 // The original finite BoxIntersect tries X, Y, then Z, with f32 arithmetic.
 for (size_t axis = 0; axis < 3; ++axis) {
  const int bits = (first >> ((2 - axis) * 2)) & 3;
  if (!bits) continue;
  const float plane = bits & 2 ? low[axis] : high[axis];
  const float fraction = (plane - start[axis]) / (end[axis] - start[axis]);
  const size_t u = (axis + 1) % 3, v = (axis + 2) % 3;
  const float x = (1.0f - fraction) * start[u] + end[u] * fraction;
  const float y = (1.0f - fraction) * start[v] + end[v] * fraction;
  if (x >= low[u] && x <= high[u] && y >= low[v] && y <= high[v]) return true;
 }
 return false;
}

bool finite(const V3& point) {
 return std::all_of(point.begin(), point.end(), [](float n) { return std::isfinite(n); });
}

bool overlaps(const V3& a, const V3& b, const V3& low, const V3& high) {
 for (size_t axis = 0; axis < 3; ++axis) {
  if (std::max(a[axis], b[axis]) < low[axis] || std::min(a[axis], b[axis]) > high[axis]) return false;
 }
 return true;
}

GDExtensionObjectPtr live_node(uint64_t id) {
 auto node = instance_from_id(id);
 if (!node || !cast_object(node, node_tag)) return nullptr;
 GDExtensionBool queued = false;
 ptrcall(scene_index::queued_method, node, nullptr, &queued);
 return queued ? nullptr : node;
}

struct Part {
 uint64_t node = 0;
 uint64_t geometry = 0;
 Var geometry_owner; // Retain the compiled faces without copying them per tile.
 Matrix pose{}, inverse{};
 std::array<float, 9> normals{};
 V3 world_low{}, world_high{}, local_low{}, local_high{}, authored_low{}, authored_high{};
 bool aabb = false, excluded = false, bounded = false;
};

struct Owner {
 std::vector<Part> parts;

 void configure(const Var& input) {
  auto rows = get(input, "parts");
  const auto count = size(rows);
  if (count < 1 || count > 64) throw std::runtime_error("Fixed terrain support Part count out of range");
  std::vector<Part> next;
  next.reserve(static_cast<size_t>(count));
  for (int64_t index = 0; index < count; ++index) {
   auto row = at(rows, index);
   Part part;
   part.node = static_cast<uint64_t>(get(row, "node").integer());
   auto object = live_node(part.node);
   if (!object) throw std::runtime_error("Fixed terrain support Part unavailable");
   part.excluded = get(row, "excluded").boolean();
   if (!part.excluded) {
    part.aabb = get(row, "aabb").boolean();
    part.bounded = get(row, "bounded").boolean();
    part.geometry = static_cast<uint64_t>(get(row, "geometry").integer());
    part.geometry_owner = get(row, "geometry_owner");
    const auto found = scene_geometry::geometry_owners.find(part.geometry);
    if (found == scene_geometry::geometry_owners.end() || !found->second->configured) {
     throw std::runtime_error("Fixed terrain support faces unavailable");
    }
    part.local_low = values<3>(get(row, "local_low"));
    part.local_high = values<3>(get(row, "local_high"));
    if (!part.aabb) {
     part.authored_low = values<3>(get(row, "authored_low"));
     part.authored_high = values<3>(get(row, "authored_high"));
    }
    if (part.bounded) {
     part.world_low = values<3>(get(row, "world_low"));
     part.world_high = values<3>(get(row, "world_high"));
    }
    ptrcall(node_transform, object, nullptr, part.pose.data());
    transform_inverse(part.pose.data(), nullptr, part.inverse.data(), 0);
    if (part.aabb) {
     std::array<float, 9> basis{};
     transform_basis(part.inverse.data(), basis.data());
     basis_transpose(basis.data(), nullptr, part.normals.data(), 0);
    }
   }
   next.push_back(std::move(part));
  }
  parts.swap(next);
 }

 Var nearest(const Var& input) const {
  const auto start = values<3>(get(input, "start"));
  const auto end = values<3>(get(input, "end"));
  const auto selected = static_cast<uint64_t>(get(input, "mask").integer());
  const auto a = scene_model::engine(start);
  auto limit = scene_model::engine(end);
  V3 normal{};
  bool hit = false, same_column = true;
  int64_t tested = 0, rejected = 0, visits = 0, triangle_calls = 0;
  for (size_t i = 0; i < parts.size(); ++i) {
   if (same_column && !(selected & (uint64_t(1) << i))) continue;
   ++visits;
   const auto& part = parts[i];
   auto node = live_node(part.node);
   if (!node) return Var(); // Let the scene owner report the same unavailability.
   if (part.excluded) continue;
   if (same_column && part.bounded && !overlaps(a, limit, part.world_low, part.world_high)) {
    ++rejected;
    continue;
   }
   Matrix pose{};
   ptrcall(node_transform, node, nullptr, pose.data());
   if (pose != part.pose) return Var();
   ++tested;
   const auto local_start = scene_model::native(scene_model::transformed(part.inverse, a));
   auto local_end = scene_model::native(scene_model::transformed(part.inverse, limit));
   if (!finite(local_start) || !finite(local_end)) return Var();
   if (!part.aabb && !authored_box_hit(local_start, local_end, part.authored_low, part.authored_high)) continue;
   if (!overlaps(local_start, local_end, part.local_low, part.local_high)) continue;
   const auto geometry = scene_geometry::geometry_owners.find(part.geometry);
   if (geometry == scene_geometry::geometry_owners.end() || !geometry->second->configured) return Var();
   ++triangle_calls;
   V3 local_normal{};
   if (!scene_geometry::Owner::nearest_faces(geometry->second->faces, local_start, local_end, local_normal)) continue;
   limit = scene_model::transformed(part.pose, scene_model::engine(local_end));
   if (!finite(limit)) return Var();
   hit = true;
   normal = {};
   if (part.aabb) {
    const auto n = scene_model::engine(local_normal);
    V3 world_normal{}, unit{};
    basis_point(part.normals.data(), n.data(), world_normal.data());
    vector_normalize(world_normal.data(), nullptr, unit.data(), 0);
    normal = scene_model::native(unit);
   }
   // A rounded hit can leave the indexed column. Continue the original
   // physical list from this hit when the shortened segment crosses it.
   same_column = same_column && std::floor(a[0]) == std::floor(limit[0]) && std::floor(a[2]) == std::floor(limit[2]);
  }
  auto result = Var::dictionary();
  set(result, "hit", Var::boolean(hit));
  if (hit) {
   set(result, "position", array(scene_model::native(limit)));
   set(result, "normal", array(normal));
  }
  set(result, "tested", Var::integer(tested));
  set(result, "rejected", Var::integer(rejected));
  set(result, "visits", Var::integer(visits));
  set(result, "triangle_calls", Var::integer(triangle_calls));
  set(result, "column_changed", Var::boolean(!same_column));
  return result;
 }
};

GDExtensionObjectPtr create(void*, GDExtensionBool notify) {
 Name base("RefCounted"), name("NwnFixedTerrainSupport");
 auto object = construct_object(base.data);
 set_instance(object, name.data, new Owner());
 if (notify) {
  Var value;
  destroy(value.data);
  from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data, &object);
  method(value, "notification", {Var::integer(0)});
 }
 return object;
}

void release(void*, GDExtensionClassInstancePtr instance) {
 delete static_cast<Owner*>(instance);
}

void dispatch(void*, GDExtensionClassInstancePtr instance, const GDExtensionConstVariantPtr* args,
              GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError* error) {
 error->error = GDEXTENSION_CALL_OK;
 if (count != 2) {
  error->error = count < 2 ? GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS : GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
  error->expected = 2;
  new_nil(result);
  return;
 }
 try {
  auto& owner = *static_cast<Owner*>(instance);
  const Var operation(args[0]), input(args[1]);
  switch (operation.integer()) {
   case 0: owner.configure(input); new_nil(result); return;
   case 1: new_copy(result, owner.nearest(input).data); return;
   default: throw std::runtime_error("Unknown fixed terrain support operation");
  }
 } catch (const std::exception& e) {
  auto out = Var::dictionary();
  set(out, "error", Var::text(e.what()));
  new_copy(result, out.data);
 }
}

template<typename Property>
void register_owner(const Property& property) {
 Name name("NwnFixedTerrainSupport"), base("RefCounted"), method("dispatch"), empty(""), op("operation"), input("input");
 GDExtensionClassCreationInfo6 info{};
 info.is_exposed = true;
 info.is_runtime = true;
 info.create_instance_func = create;
 info.free_instance_func = release;
 register_class(library, name.data, base.data, &info);
 auto ret = property(GDEXTENSION_VARIANT_TYPE_NIL, empty);
 ret.usage |= 131072;
 GDExtensionPropertyInfo args[] = {property(GDEXTENSION_VARIANT_TYPE_INT, op), property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, input)};
 GDExtensionClassMethodArgumentMetadata metadata[2]{};
 GDExtensionClassMethodInfo m{};
 m.name = method.data;
 m.call_func = dispatch;
 m.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
 m.has_return_value = true;
 m.return_value_info = &ret;
 m.argument_count = 2;
 m.arguments_info = args;
 m.arguments_metadata = metadata;
 register_method(library, name.data, &m);
}

void unregister_owner() {
 Name name("NwnFixedTerrainSupport");
 unregister_class(library, name.data);
}
}
