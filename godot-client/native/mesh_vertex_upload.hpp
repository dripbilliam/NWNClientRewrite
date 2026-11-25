// Worker data only. Scene publication and index/collision validation stay with
// their existing owners. ABI sizes are pinned by the extension build.
namespace mesh_vertex_upload {
using Bounds = std::array<float, 6>;

void write_bounds(Var& out, const char* field, Bounds& bounds) {
 Var value;
 destroy(value.data);
 from[GDEXTENSION_VARIANT_TYPE_AABB](value.data, bounds.data());
 set(out, field, value);
}

Var transform(const raster_conversion::Bytes& vertices, const raster_conversion::Bytes& normals) {
 const size_t bytes = vertices.size();
 if (bytes == 0 || bytes % sizeof(V3) != 0 || normals.size() != bytes)
  return Var::dictionary();
 static const auto expand = [] {
  Name method_name("expand");
  return builtin_method(GDEXTENSION_VARIANT_TYPE_AABB, method_name.data, 2851643018);
 }();
 if (!expand) return Var::dictionary();

 WritableBytes positions(bytes), directions(bytes);
 const auto* vertex_data = vertices.data();
 const auto* normal_data = normals.data();
 Bounds source_bounds{}, pick_bounds{};
 for (size_t offset = 0; offset < bytes; offset += sizeof(V3)) {
  V3 source{}, normal{};
  std::memcpy(source.data(), vertex_data + offset, sizeof(source));
  std::memcpy(normal.data(), normal_data + offset, sizeof(normal));
  const V3 position{source[0], source[2], -source[1]};
  const V3 direction{normal[0], normal[2], -normal[1]};
  std::memcpy(positions.data + offset, position.data(), sizeof(position));
  std::memcpy(directions.data + offset, direction.data(), sizeof(direction));
  if (offset == 0) {
   std::copy(source.begin(), source.end(), source_bounds.begin());
   std::copy(position.begin(), position.end(), pick_bounds.begin());
  } else {
   const GDExtensionConstTypePtr source_args[]{source.data()}, pick_args[]{position.data()};
   Bounds next_source{}, next_pick{};
   expand(source_bounds.data(), source_args, next_source.data(), 1);
   expand(pick_bounds.data(), pick_args, next_pick.data(), 1);
   source_bounds = next_source;
   pick_bounds = next_pick;
  }
 }

 Var out = Var::dictionary();
 auto packed_positions = positions.publish(), packed_normals = directions.publish();
 set(out, "positions", method(packed_positions, "to_vector3_array", {}));
 set(out, "normals", method(packed_normals, "to_vector3_array", {}));
 write_bounds(out, "source_bounds", source_bounds);
 write_bounds(out, "pick_bounds", pick_bounds);
 return out;
}

void call(void*, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr* args,
          GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError* error) {
 if (!particle_upload::count_ok(count, 2, result, error)) return;
 try {
  auto output = Var::dictionary();
  if (get_type(args[0]) == GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY &&
      get_type(args[1]) == GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY) {
   const raster_conversion::Bytes vertices(args[0]), normals(args[1]);
   output = transform(vertices, normals);
  }
  new_copy(result, output.data);
 } catch (const std::exception&) {
  const auto output = Var::dictionary();
  new_copy(result, output.data);
 }
}

template<class Property> void register_method_info(const Name& owner, Property property) {
 Name name("mesh_vertex_upload"), empty(""), vertices("vertices"), normals("normals");
 auto result = property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, empty);
 GDExtensionPropertyInfo args[]{property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY, vertices),
                               property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY, normals)};
 GDExtensionClassMethodArgumentMetadata metadata[2]{};
 GDExtensionClassMethodInfo method{};
 method.name = name.data;
 method.call_func = call;
 method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL | GDEXTENSION_METHOD_FLAG_STATIC;
 method.has_return_value = true;
 method.return_value_info = &result;
 method.argument_count = 2;
 method.arguments_info = args;
 method.arguments_metadata = metadata;
 register_method(library, owner.data, &method);
}
}
