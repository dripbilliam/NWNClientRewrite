#include "particle_reads.h"
// The source preparer installs the exact particle-agent-owned frozen header.
#include "nwn_particle_read_abi_v1.h"

#include "core/extension/gdextension.h"
#include "core/object/class_db.h"
#include "core/os/thread.h"
#include "scene/3d/node_3d.h"

#include <atomic>
#include <cstring>

static_assert(sizeof(real_t) == sizeof(float), "Private v1 requires real_t=f32");
static_assert(sizeof(Transform3D) == 12 * sizeof(float), "Original ptrcall carrier must remain 12 f32 words");

namespace {
std::atomic<bool> scene_active{false};
bool interface_registered = false; // Normal engine init/teardown is main-thread owned.

uint32_t context_status() {
    if (!scene_active.load(std::memory_order_relaxed)) {
        return NWN_READ_INACTIVE_V1;
    }
    if (!Thread::is_main_thread()) {
        return NWN_READ_UNSUPPORTED_CONTEXT_V1;
    }
    return NWN_READ_OK_V1;
}

template <typename T>
uint32_t publish(T *out, const T &value, uint32_t status) {
    // In particular, do not dereference a caller-supplied alignment here.
    std::memcpy(out, &value, sizeof(T));
    return status;
}

uint32_t NWN_READ_CALL eligible(uint64_t id, NwnEligibilityV1 *out, uint32_t out_bytes) {
    if (out == nullptr || out_bytes < sizeof(NwnEligibilityV1)) {
        return NWN_READ_BAD_ABI_V1;
    }
    NwnEligibilityV1 value{};
    value.bytes = sizeof(value);
    const uint32_t context = context_status();
    if (context != NWN_READ_OK_V1) {
        return publish(out, value, context);
    }
    Object *object = ObjectDB::get_instance(ObjectID(id));
    if (object == nullptr) {
        return publish(out, value, NWN_READ_MISSING_V1);
    }
    value.completed_stage = NWN_ELIGIBLE_RESOLVED_V1;
    // Match the original object_cast_to C interface's exact class predicate,
    // rather than the newer cast_to template's optional ancestry optimization.
    if (!object->is_class_ptr(Node3D::get_class_ptr_static())) {
        return publish(out, value, NWN_READ_WRONG_TYPE_V1);
    }
    Node3D *node = static_cast<Node3D *>(object);
    value.completed_stage = NWN_ELIGIBLE_TYPED_V1;
    if (!node->is_effective_process_thread_group_main_thread()) {
        return publish(out, value, NWN_READ_UNSUPPORTED_CONTEXT_V1);
    }
    value.inside_tree = node->is_inside_tree() ? 1 : 0;
    value.completed_stage = NWN_ELIGIBLE_INSIDE_READ_V1;
    if (!value.inside_tree) {
        return publish(out, value, NWN_READ_OK_V1);
    }
    value.visible_in_tree = node->is_visible_in_tree() ? 1 : 0;
    value.completed_stage = NWN_ELIGIBLE_VISIBLE_READ_V1;
    if (!value.visible_in_tree) {
        return publish(out, value, NWN_READ_OK_V1);
    }
    value.can_process = node->can_process() ? 1 : 0;
    value.completed_stage = NWN_ELIGIBLE_PROCESS_READ_V1;
    value.eligible = value.can_process;
    return publish(out, value, NWN_READ_OK_V1);
}

uint32_t NWN_READ_CALL validate_node3d(uint64_t id) {
    const uint32_t context = context_status();
    if (context != NWN_READ_OK_V1) {
        return context;
    }
    Object *object = ObjectDB::get_instance(ObjectID(id));
    if (object == nullptr) {
        return NWN_READ_MISSING_V1;
    }
    return object->is_class_ptr(Node3D::get_class_ptr_static()) ? NWN_READ_OK_V1 : NWN_READ_WRONG_TYPE_V1;
}

uint32_t NWN_READ_CALL global_transform(uint64_t id, NwnTransformV1 *out, uint32_t out_bytes) {
    if (out == nullptr || out_bytes < sizeof(NwnTransformV1)) {
        return NWN_READ_BAD_ABI_V1;
    }
    NwnTransformV1 value{};
    value.bytes = sizeof(value);
    const uint32_t context = context_status();
    if (context != NWN_READ_OK_V1) {
        return publish(out, value, context);
    }
    Object *object = ObjectDB::get_instance(ObjectID(id));
    if (object == nullptr) {
        return publish(out, value, NWN_READ_MISSING_V1);
    }
    if (!object->is_class_ptr(Node3D::get_class_ptr_static())) {
        return publish(out, value, NWN_READ_WRONG_TYPE_V1);
    }
    Node3D *node = static_cast<Node3D *>(object);
    if (!node->is_effective_process_thread_group_main_thread()) {
        return publish(out, value, NWN_READ_UNSUPPORTED_CONTEXT_V1);
    }
    // Preserve the original getter, including its outside-tree error/default.
    // No Node pointer, reference, transform or selection survives this call.
    const Transform3D pose = node->get_global_transform();
    for (size_t row = 0; row < 3; ++row) {
        for (size_t column = 0; column < 3; ++column) {
            std::memcpy(&value.rows_and_origin[row * 3 + column], &pose.basis[row][column], sizeof(float));
        }
    }
    for (size_t axis = 0; axis < 3; ++axis) {
        std::memcpy(&value.rows_and_origin[9 + axis], &pose.origin[axis], sizeof(float));
    }
    return publish(out, value, NWN_READ_OK_V1);
}

const NwnParticleReadAPIv1 read_api = {
    NWN_PARTICLE_READ_ABI_REVISION_V1,
    sizeof(NwnParticleReadAPIv1),
    64,
    32,
    NWN_PARTICLE_READ_REQUIRED_FEATURES_V1,
    &eligible,
    &validate_node3d,
    &global_transform,
};
} // namespace

extern "C" const NwnParticleReadAPIv1 *NWN_READ_CALL nwn_particle_reads_get_v1(
        uint32_t requested_revision, uint32_t minimum_api_bytes,
        uint32_t caller_pointer_bits, uint32_t caller_real_bits) {
    if (requested_revision != NWN_PARTICLE_READ_ABI_REVISION_V1 ||
            minimum_api_bytes != sizeof(NwnParticleReadAPIv1) ||
            caller_pointer_bits != 64 || caller_real_bits != 32) {
        return nullptr;
    }
    return &read_api;
}

int64_t NwnParticleReadBridgeV1::abi_revision() {
    return NWN_PARTICLE_READ_ABI_REVISION_V1;
}

void NwnParticleReadBridgeV1::_bind_methods() {
    ClassDB::bind_static_method(NWN_PARTICLE_READ_MARKER_CLASS_V1,
            D_METHOD("abi_revision"), &NwnParticleReadBridgeV1::abi_revision);
}

void nwn_particle_reads_activate() {
    if (!interface_registered) {
        GDExtension::register_interface_function(NWN_PARTICLE_READ_GET_PROC_V1,
                reinterpret_cast<GDExtensionInterfaceFunctionPtr>(&nwn_particle_reads_get_v1));
        GDREGISTER_CLASS(NwnParticleReadBridgeV1);
        interface_registered = true;
    }
    scene_active.store(true, std::memory_order_relaxed);
}

void nwn_particle_reads_deactivate() {
    scene_active.store(false, std::memory_order_relaxed);
}
