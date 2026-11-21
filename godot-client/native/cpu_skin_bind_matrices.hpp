namespace cpu_skin_bind_matrices {
struct Pose {
    V3 position;
    Q4 rotation;
    V3 inverse_position;
    Q4 inverse_rotation;
};

template<size_t count>
std::array<float, count> read_components(const Var& stream, int64_t index) {
    const auto row = at(stream, index);
    if (row.type() != GDEXTENSION_VARIANT_TYPE_ARRAY) {
        throw std::runtime_error("Native skin bind row is unavailable");
    }
    const auto numbers = values<count>(row);
    for (const auto component : numbers) {
        if (!std::isfinite(component)) {
            throw std::runtime_error("Native skin bind row is non-finite");
        }
    }
    return numbers;
}

Var build(const Var& input) {
    auto slots = get(input, "slots");
    auto positions = get(input, "positions");
    auto quaternions = get(input, "quaternions");
    auto inverse_positions = get(input, "inverse_positions");
    auto inverse_quaternions = get(input, "inverse_quaternions");
    const auto slot_count = std::min<int64_t>(size(slots), 64);
    const auto pose_count = size(positions);
    const auto quaternion_count = size(quaternions);
    const auto inverse_position_count = size(inverse_positions);
    const auto inverse_rotation_count = size(inverse_quaternions);
    auto output = array_empty();
    method(output, "resize", {Var::integer(slot_count)});
    std::unordered_map<int64_t, Pose> physical_poses;
    physical_poses.reserve(static_cast<size_t>(slot_count));
    bool root_seen = false;
    for (int64_t slot = 0; slot < slot_count; ++slot) {
        const auto physical = at(slots, slot).integer();
        if (physical < 0 || physical >= pose_count) {
            continue;
        }
        if (physical == 0) {
            if (root_seen) {
                break;
            }
            root_seen = true;
        }
        auto current = physical_poses.find(physical);
        if (current == physical_poses.end()) {
            if (physical >= quaternion_count || physical >= inverse_position_count || physical >= inverse_rotation_count) {
                throw std::runtime_error("Native skin bind row is unavailable");
            }
            const Pose original{
                read_components<3>(positions, physical),
                read_components<4>(quaternions, physical),
                read_components<3>(inverse_positions, physical),
                read_components<4>(inverse_quaternions, physical)
            };
            current = physical_poses.emplace(physical, original).first;
        }
        // Duplicate physical indices accumulate the inverse bind in slot order.
        // The helpers preserve the existing float32 operation boundaries.
        auto& pose = current->second;
        pose.position = add(pose.position, rotate(pose.rotation, pose.inverse_position));
        pose.rotation = multiply(pose.rotation, pose.inverse_rotation);
        const auto x = axis_x(pose.rotation);
        const auto y = axis_y(pose.rotation);
        const auto z = axis_z(pose.rotation);
        const std::array<float, 16> matrix{
            x[0], y[0], z[0], pose.position[0],
            x[1], y[1], z[1], pose.position[1],
            x[2], y[2], z[2], pose.position[2],
            0.0f, 0.0f, 0.0f, 1.0f
        };
        for (const auto value : matrix) {
            if (!std::isfinite(value)) {
                throw std::runtime_error("Native skin bind matrix is non-finite");
            }
        }
        put_index(output, slot, array(matrix));
    }
    return output;
}

void call(void*, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr* args,
        GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError* error) {
    if (!particle_upload::count_ok(count, 1, result, error)) {
        return;
    }
    auto response = Var::dictionary();
    try {
        set(response, "matrices", build(Var(args[0])));
    } catch (const std::exception& reason) {
        set(response, "error", Var::text(reason.what()));
    }
    new_copy(result, response.data);
}

template<class Property>
void register_method_for_class(const Name& class_name, Property property) {
    Name name("cpu_skin_bind_matrices"), input("input"), empty("");
    auto result = property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, empty);
    auto arguments = property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, input);
    GDExtensionClassMethodArgumentMetadata metadata{};
    GDExtensionClassMethodInfo info{};
    info.name = name.data;
    info.call_func = call;
    info.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL | GDEXTENSION_METHOD_FLAG_STATIC;
    info.has_return_value = true;
    info.return_value_info = &result;
    info.argument_count = 1;
    info.arguments_info = &arguments;
    info.arguments_metadata = &metadata;
    register_method(library, class_name.data, &info);
}
} // namespace cpu_skin_bind_matrices
