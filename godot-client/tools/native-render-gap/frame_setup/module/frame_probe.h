#pragma once
#include "core/object/ref_counted.h"
#include "core/os/os.h"
#include "core/variant/dictionary.h"

// A completed render-thread frame, never a synchronous RenderingServer flush.
// Timings are elapsed wall microseconds. Nested spans must not be added.
namespace NwnFrameMetrics {
enum Key {
 FRAME_WALL_US, SETUP_WALL_US, SCENE_US, CANVAS_US,
 BVH_GEOMETRY_US, BVH_VOLUMES_US, SCENE_RENDER_UPDATE_US, PARTICLE_COLLIDERS_US,
 DIRTY_DRAIN_SETUP_US, DIRTY_DRAIN_LATE_US, RESOURCES_SETUP_US, RESOURCES_LATE_US,
 UNIFORMS_US, MATERIALS_US, MULTIMESHES_US, SKELETONS_US, DECAL_ATLAS_US, LIGHT_ATLAS_US,
 DIRTY_INSTANCES_SETUP, DIRTY_INSTANCES_LATE, DIRTY_AABB, DIRTY_DEPENDENCIES,
 DIRTY_MESH, DIRTY_LIGHT, DIRTY_OTHER,
 QUEUE_REQUESTS, QUEUE_COALESCED, QUEUE_ADDED, PENDING_AFTER_RESOURCES,
 RANGE_CALLS, RANGE_EQUAL, RANGE_CHANGED, SHADOW_CALLS, SHADOW_EQUAL,
 BONE_CALLS, BONE_EQUAL, BONE_CHANGED, SKELETON_UPLOADS, SKELETON_UPLOAD_BYTES,
 COUNT
};
bool active();
bool collecting();
bool setup();
void begin();
void end_setup();
void finish();
void add(Key key, uint64_t value = 1);
class Scope {
 Key key; uint64_t start = 0;
public:
 explicit Scope(Key p_key) : key(p_key) { if (active()) start = OS::get_singleton()->get_ticks_usec(); }
 ~Scope() { if (start) add(key, OS::get_singleton()->get_ticks_usec() - start); }
};
}
class NwnFrameProbe : public RefCounted {
 GDCLASS(NwnFrameProbe, RefCounted);
protected:
 static void _bind_methods();
public:
 static void set_enabled(bool enabled);
 static Dictionary completed_frame();
};
