// CPU skin arithmetic for the original inverse-bind pose path. Surface upload,
// pick refits and callbacks remain in the owning rig on the calling thread.
namespace cpu_skin_deformation {
constexpr auto vertices_type = GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY;
constexpr auto weights_type = GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY;
constexpr auto indices_type = GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY;
GDExtensionInterfacePackedVector3ArrayOperatorIndexConst read_vertices = nullptr;
GDExtensionInterfacePackedVector3ArrayOperatorIndex write_vertices = nullptr;
GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst read_weights = nullptr;
GDExtensionInterfacePackedInt32ArrayOperatorIndexConst read_indices = nullptr;
GDExtensionPtrBuiltInMethod vertex_size = nullptr;
GDExtensionPtrBuiltInMethod weight_size = nullptr;
GDExtensionPtrBuiltInMethod index_size = nullptr;
GDExtensionPtrBuiltInMethod vertex_resize = nullptr;

void bind(GDExtensionInterfaceGetProcAddress address) {
    read_vertices = reinterpret_cast<decltype(read_vertices)>(address("packed_vector3_array_operator_index_const"));
    write_vertices = reinterpret_cast<decltype(write_vertices)>(address("packed_vector3_array_operator_index"));
    read_weights = reinterpret_cast<decltype(read_weights)>(address("packed_float64_array_operator_index_const"));
    read_indices = reinterpret_cast<decltype(read_indices)>(address("packed_int32_array_operator_index_const"));
}

template<GDExtensionVariantType Type>
struct Packed {
    alignas(8) uint8_t raw[16];

    Packed() {
        ptr_constructor(Type, 0)(raw, nullptr);
    }
    explicit Packed(const Var& value) {
        if (value.type() != Type) {
            throw std::runtime_error("CPU skin numeric stream has the wrong packed type");
        }
        to[Type](raw, const_cast<uint8_t*>(value.data));
    }
    ~Packed() {
        ptr_destructor(Type)(raw);
    }
    Packed(const Packed&) = delete;
    Packed& operator=(const Packed&) = delete;

    int64_t count(GDExtensionPtrBuiltInMethod length) const {
        int64_t size = 0;
        length(const_cast<uint8_t*>(raw), nullptr, &size, 0);
        return size;
    }
    Var publish() {
        Var value;
        destroy(value.data);
        from[Type](value.data, raw);
        return value;
    }
};

using Point = std::array<float, 3>;
using Matrix = std::array<double, 12>;
static_assert(sizeof(Point) == 12, "This build uses the pinned float32 Vector3 ABI");

bool finite(const Point& value) {
    return std::isfinite(value[0]) && std::isfinite(value[1]) && std::isfinite(value[2]);
}

Var deform(const Var& input) {
    Packed<vertices_type> positions(get(input, "positions"));
    Packed<weights_type> weights(get(input, "weights"));
    Packed<indices_type> bones(get(input, "bones"));
    Packed<indices_type> aliases(get(input, "aliases"));
    auto matrices = get(input, "matrices");
    const int64_t count = positions.count(vertex_size);
    if (count < 0 || count > 2147483647LL / 4 || count % 3 ||
            weights.count(weight_size) != count * 4 || bones.count(index_size) != count * 4) {
        throw std::runtime_error("CPU skin numeric stream lengths do not match triangle corners");
    }
    const auto alias_count = aliases.count(index_size);
    if (alias_count != 0 && alias_count != count) {
        throw std::runtime_error("CPU skin alias stream length does not match triangle corners");
    }
    if (matrices.type() != GDEXTENSION_VARIANT_TYPE_ARRAY) {
        throw std::runtime_error("CPU skin requires an ordered bind matrix palette");
    }
    const auto matrix_count = size(matrices);
    if (matrix_count < 0 || matrix_count > 64) {
        throw std::runtime_error("CPU skin bind matrix count exceeds its slot limit");
    }
    std::array<std::optional<Matrix>, 64> palette{};
    Packed<vertices_type> output;
    const GDExtensionConstTypePtr resize_args[] = {&count};
    int64_t resize_result = -1;
    vertex_resize(output.raw, resize_args, &resize_result, 1);
    if (resize_result != 0) {
        throw std::runtime_error("CPU skin output allocation failed");
    }
    if (count == 0) {
        return output.publish();
    }
    const void* position_data = read_vertices(positions.raw, 0);
    auto* output_data = static_cast<uint8_t*>(write_vertices(output.raw, 0));
    const double* weight_data = read_weights(weights.raw, 0);
    const int32_t* bone_data = read_indices(bones.raw, 0);
    const int32_t* alias_data = alias_count > 0 ? read_indices(aliases.raw, 0) : nullptr;
    if (!position_data || !output_data || !weight_data || !bone_data || (alias_count > 0 && !alias_data)) {
        throw std::runtime_error("CPU skin packed numeric storage is unavailable");
    }
    const auto* original = static_cast<const uint8_t*>(position_data);
    for (int64_t corner = 0; corner < count; ++corner) {
        const auto offset = static_cast<size_t>(corner) * sizeof(Point);
        if (alias_data) {
            const int64_t rank = alias_data[corner];
            if (rank < 0 || rank > corner || alias_data[rank] != rank) {
                throw std::runtime_error("CPU skin alias must reference a previously evaluated source corner");
            }
            if (rank != corner) {
                std::memcpy(output_data + offset, output_data + static_cast<size_t>(rank) * sizeof(Point), sizeof(Point));
                continue;
            }
        }
        Point point{};
        std::memcpy(point.data(), original + offset, sizeof(Point));
        if (!finite(point)) {
            throw std::runtime_error("CPU skin source position is non-finite");
        }
        double x = 0, y = 0, z = 0;
        bool influenced = false;
        const double vx = point[0];
        const double vy = -static_cast<double>(point[2]);
        const double vz = point[1];
        for (int component = 0; component < 4; ++component) {
            const auto at_influence = corner * 4 + component;
            const double weight = weight_data[at_influence];
            if (!std::isfinite(weight)) {
                throw std::runtime_error("CPU skin influence weight is non-finite");
            }
            if (weight <= 0) {
                continue;
            }
            const auto slot = bone_data[at_influence];
            if (slot < 0 || slot >= matrix_count) {
                throw std::runtime_error("Native weighted skin slot is unavailable");
            }
            auto& matrix = palette[static_cast<size_t>(slot)];
            if (!matrix.has_value()) {
                auto source = at(matrices, slot);
                if (source.type() != GDEXTENSION_VARIANT_TYPE_ARRAY || size(source) < 12) {
                    throw std::runtime_error("Native weighted skin slot is unavailable");
                }
                Matrix values{};
                for (int64_t index = 0; index < 12; ++index) {
                    auto component_value = at(source, index);
                    if (component_value.type() != GDEXTENSION_VARIANT_TYPE_FLOAT &&
                            component_value.type() != GDEXTENSION_VARIANT_TYPE_INT) {
                        throw std::runtime_error("CPU skin bind matrix contains a non-numeric value");
                    }
                    values[index] = component_value.number();
                    if (!std::isfinite(values[index])) {
                        throw std::runtime_error("CPU skin bind matrix is non-finite");
                    }
                }
                matrix = values;
            }
            const auto& m = *matrix;
            // Match the established GDScript left-to-right double math. Only
            // the final Vector3 conversion rounds components to float32.
            x += (m[0] * vx + m[1] * vy + m[2] * vz + m[3]) * weight;
            y += (m[4] * vx + m[5] * vy + m[6] * vz + m[7]) * weight;
            z += (m[8] * vx + m[9] * vy + m[10] * vz + m[11]) * weight;
            influenced = true;
        }
        if (influenced) {
            point = {static_cast<float>(x), static_cast<float>(z), static_cast<float>(-y)};
            if (!finite(point)) {
                throw std::runtime_error("CPU skin deformation produced a non-finite position");
            }
        }
        std::memcpy(output_data + offset, point.data(), sizeof(Point));
    }
    return output.publish();
}

void call_deform(void*, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr* args,
        GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError* error) {
    if (!particle_upload::count_ok(count, 1, result, error)) {
        return;
    }
    auto response = Var::dictionary();
    try {
        set(response, "positions", deform(Var(args[0])));
    } catch (const std::exception& reason) {
        set(response, "error", Var::text(reason.what()));
    }
    new_copy(result, response.data);
}

Point normalize_skin_vector(Point value) {
    const float squared = value[0] * value[0] + value[1] * value[1] + value[2] * value[2];
    if (!std::isfinite(squared)) {
        throw std::runtime_error("CPU skin normal needs engine floating-point handling");
    }
    if (squared == 0.0f) {
        return {};
    }
    const float length = std::sqrt(squared);
    for (auto& component : value) {
        component /= length;
    }
    return value;
}

Point flat_normal(const std::array<Point, 3>& points) {
    const auto& [a, b, c] = points;
    const Point u{c[0] - b[0], c[1] - b[1], c[2] - b[2]};
    const Point v{a[0] - b[0], a[1] - b[1], a[2] - b[2]};
    return normalize_skin_vector(cross(u, v));
}

Var flat_normals(const Var& input) {
    Packed<vertices_type> positions(input);
    Packed<vertices_type> output;
    const int64_t count = positions.count(vertex_size);
    if (count <= 0 || count % 3 != 0) {
        return output.publish();
    }
    const GDExtensionConstTypePtr resize_args[] = {&count};
    int64_t resize_result = -1;
    vertex_resize(output.raw, resize_args, &resize_result, 1);
    const auto* corners = static_cast<const uint8_t*>(read_vertices(positions.raw, 0));
    auto* normals = resize_result == 0 ? static_cast<uint8_t*>(write_vertices(output.raw, 0)) : nullptr;
    if (!corners || !normals) {
        throw std::runtime_error("CPU skin normal storage is unavailable");
    }
    for (int64_t triangle = 0; triangle < count; triangle += 3) {
        const size_t offset = static_cast<size_t>(triangle) * sizeof(Point);
        std::array<Point, 3> points{};
        std::memcpy(points.data(), corners + offset, sizeof(points));
        const auto normal = flat_normal(points);
        for (size_t corner = 0; corner < points.size(); ++corner) {
            std::memcpy(normals + offset + corner * sizeof(Point), normal.data(), sizeof(Point));
        }
    }
    return output.publish();
}

// Pinned Godot 4.7 vertex-buffer format. Positions are tightly packed,
// followed by one octahedral normal and generated tangent per corner.
// Each CPU triangle has three identical normals and needs one encoding.
std::array<uint16_t, 2> skin_oct(Point value, bool tangent) {
    const float divisor = std::abs(value[0]) + std::abs(value[1]) + std::abs(value[2]);
    if (divisor == 0.0f) {
        throw std::runtime_error("CPU skin surface needs engine handling for degenerate geometry");
    }
    for (auto& component : value) {
        component /= divisor;
    }
    const auto [x, y, z] = value;
    const float u = z >= 0.0f ? x : (1.0f - std::abs(y)) * (x >= 0.0f ? 1.0f : -1.0f);
    const float v = z >= 0.0f ? y : (1.0f - std::abs(x)) * (y >= 0.0f ? 1.0f : -1.0f);
    const float first = u * 0.5f + 0.5f;
    float second = v * 0.5f + 0.5f;
    if (tangent) {
        second = std::max(second, 1.0f / 32767.0f) * 0.5f + 0.5f;
    }
    std::array<uint16_t, 2> bytes{static_cast<uint16_t>(std::clamp(first * 65535.0f, 0.0f, 65535.0f)),
        static_cast<uint16_t>(std::clamp(second * 65535.0f, 0.0f, 65535.0f))};
    if (tangent && bytes[0] == 0 && bytes[1] == 65535) {
        bytes[0] = 65535;
    }
    return bytes;
}

void pack_skin_surface(const Var& values, int64_t start, int64_t count, Var& result) {
    constexpr size_t shading_bytes = sizeof(uint16_t) * 4;
    Packed<vertices_type> positions(values);
    const int64_t total = positions.count(vertex_size);
    if (start < 0 || count < 3 || count % 3 || start > total || count > total - start ||
            count > static_cast<int64_t>(INT32_MAX / (sizeof(Point) + shading_bytes))) {
        throw std::runtime_error("CPU skin surface has invalid corner range");
    }
    const auto* corners = static_cast<const uint8_t*>(read_vertices(positions.raw, start));
    const size_t shading_start = static_cast<size_t>(count) * sizeof(Point);
    WritableBytes packed(static_cast<size_t>(count) * (sizeof(Point) + shading_bytes));
    std::memcpy(packed.data, corners, shading_start);
    Point minimum, maximum;
    std::memcpy(minimum.data(), corners, sizeof(Point));
    maximum = minimum;
    for (int64_t triangle = 0; triangle < count; triangle += 3) {
        std::array<Point, 3> points;
        std::memcpy(points.data(), corners + triangle * sizeof(Point), sizeof(points));
        for (const auto& point : points) {
            if (!finite(point)) {
                throw std::runtime_error("CPU skin surface has a nonfinite corner");
            }
            for (size_t axis = 0; axis < point.size(); ++axis) {
                minimum[axis] = std::min(minimum[axis], point[axis]);
                maximum[axis] = std::max(maximum[axis], point[axis]);
            }
        }
        const Point normal = flat_normal(points);
        const Point tangent = normalize_skin_vector(cross({normal[2], -normal[0], normal[1]}, normalize_skin_vector(normal)));
        const auto packed_normal = skin_oct(normal, false);
        const auto packed_tangent = skin_oct(tangent, true);
        for (size_t index = 0; index < points.size(); ++index) {
            auto* destination = packed.data + shading_start + (triangle + index) * shading_bytes;
            std::memcpy(destination, packed_normal.data(), shading_bytes / 2);
            std::memcpy(destination + shading_bytes / 2, packed_tangent.data(), shading_bytes / 2);
        }
    }
    std::array<float, 6> bounds;
    for (size_t axis = 0; axis < minimum.size(); ++axis) {
        bounds[axis] = minimum[axis];
        bounds[axis + 3] = std::max(0.00001f, maximum[axis] - minimum[axis]);
    }
    Var box;
    destroy(box.data);
    from[GDEXTENSION_VARIANT_TYPE_AABB](box.data, bounds.data());
    set(result, "bounds", box);
    set(result, "vertex_data", packed.publish());
}

void call_pack_surface(void*, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr* args,
        GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError* error) {
    if (!particle_upload::count_ok(count, 3, result, error)) {
        return;
    }
    auto response = Var::dictionary();
    try {
        pack_skin_surface(Var(args[0]), Var(args[1]).integer(), Var(args[2]).integer(), response);
    } catch (const std::exception& reason) {
        set(response, "error", Var::text(reason.what()));
    }
    new_copy(result, response.data);
}

void call_flat_normals(void*, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr* args,
        GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError* error) {
    if (!particle_upload::count_ok(count, 1, result, error)) {
        return;
    }
    try {
        auto normals = flat_normals(Var(args[0]));
        new_copy(result, normals.data);
    } catch (const std::exception&) {
        Packed<vertices_type> empty;
        auto normals = empty.publish();
        new_copy(result, normals.data);
    }
}

template<class Property>
void register_numeric(const Name& class_name, Property property) {
    if (!read_vertices || !write_vertices || !read_weights || !read_indices) {
        return;
    }
    Name size_name("size"), resize_name("resize");
    vertex_size = builtin_method(vertices_type, size_name.data, 3173160232);
    weight_size = builtin_method(weights_type, size_name.data, 3173160232);
    index_size = builtin_method(indices_type, size_name.data, 3173160232);
    vertex_resize = builtin_method(vertices_type, resize_name.data, 848867239);
    if (!vertex_size || !weight_size || !index_size || !vertex_resize) {
        return;
    }
    Name name("cpu_skin_deform"), input("input"), empty("");
    auto result = property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, empty);
    auto arguments = property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, input);
    GDExtensionClassMethodArgumentMetadata metadata{};
    GDExtensionClassMethodInfo info{};
    info.name = name.data;
    info.call_func = call_deform;
    info.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL | GDEXTENSION_METHOD_FLAG_STATIC;
    info.has_return_value = true;
    info.return_value_info = &result;
    info.argument_count = 1;
    info.arguments_info = &arguments;
    info.arguments_metadata = &metadata;
    register_method(library, class_name.data, &info);

    Name normal_name("cpu_skin_flat_normals"), points("points");
    result = property(vertices_type, empty);
    arguments = property(vertices_type, points);
    info.name = normal_name.data;
    info.call_func = call_flat_normals;
    register_method(library, class_name.data, &info);

    Name pack_name("cpu_skin_pack_surface"), start("start"), count("count");
    result = property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, empty);
    decltype(arguments) pack_arguments[] = {property(vertices_type, points),
        property(GDEXTENSION_VARIANT_TYPE_INT, start), property(GDEXTENSION_VARIANT_TYPE_INT, count)};
    GDExtensionClassMethodArgumentMetadata pack_metadata[3]{};
    info.name = pack_name.data;
    info.call_func = call_pack_surface;
    info.argument_count = 3;
    info.arguments_info = pack_arguments;
    info.arguments_metadata = pack_metadata;
    register_method(library, class_name.data, &info);
}
} // namespace cpu_skin_deformation
