#include "frame_probe.h"
#include "core/object/class_db.h"
#include "core/os/thread.h"
#include <atomic>

namespace {
std::atomic<bool> enabled{false};
std::atomic<uint64_t> generation{0}, frame_id{0}, writer_thread{0};
std::atomic<uint64_t> published[NwnFrameMetrics::COUNT]{};
std::atomic<uint64_t> pending[NwnFrameMetrics::COUNT]{};
thread_local bool recording = false, in_setup = false;
thread_local uint64_t values[NwnFrameMetrics::COUNT]{};
thread_local uint64_t frame_started = 0;
const char *names[] = {
 "frame_wall_us", "setup_wall_us", "scene_us", "canvas_us",
 "bvh_geometry_us", "bvh_volumes_us", "scene_render_update_us", "particle_colliders_us",
 "dirty_drain_setup_us", "dirty_drain_late_us", "resources_setup_us", "resources_late_us",
 "uniforms_us", "materials_us", "multimeshes_us", "skeletons_us", "decal_atlas_us", "light_atlas_us",
 "dirty_instances_setup", "dirty_instances_late", "dirty_aabb", "dirty_dependencies",
 "dirty_mesh", "dirty_light", "dirty_other",
 "queue_requests", "queue_coalesced", "queue_added", "pending_after_resources",
 "range_calls", "range_equal", "range_changed", "shadow_calls", "shadow_equal",
 "bone_calls", "bone_equal", "bone_changed", "skeleton_uploads", "skeleton_upload_bytes"
};
static_assert(sizeof(names) / sizeof(names[0]) == NwnFrameMetrics::COUNT);
}
namespace NwnFrameMetrics {
bool active() { return recording; }
bool collecting() { return recording || enabled.load(std::memory_order_relaxed); }
bool setup() { return in_setup; }
void add(Key key, uint64_t value) {
 if (recording) values[key] += value;
 else if (enabled.load(std::memory_order_relaxed)) pending[key].fetch_add(value, std::memory_order_relaxed);
}
void begin() {
 recording = enabled.load(std::memory_order_relaxed);
 in_setup = recording;
 if (!recording) return;
 for (int i = 0; i < COUNT; ++i) values[i] = pending[i].exchange(0, std::memory_order_relaxed);
 frame_started = OS::get_singleton()->get_ticks_usec();
}
void end_setup() {
 if (!recording) return;
 values[SETUP_WALL_US] = OS::get_singleton()->get_ticks_usec() - frame_started;
 in_setup = false;
}
void finish() {
 if (!recording) return;
 values[FRAME_WALL_US] = OS::get_singleton()->get_ticks_usec() - frame_started;
 // All payload fields are atomic: a rejected read still has no C++ data race.
 // seq_cst provides one publication order across generation and payload.
 generation.fetch_add(1);
 for (int i = 0; i < COUNT; ++i) published[i].store(values[i]);
 frame_id.fetch_add(1);
 writer_thread.store(Thread::get_caller_id());
 generation.fetch_add(1);
 recording = in_setup = false;
}
}
void NwnFrameProbe::set_enabled(bool p_enabled) { enabled.store(p_enabled); }
Dictionary NwnFrameProbe::completed_frame() {
 Dictionary out;
 out["available"] = false;
 for (int attempt = 0; attempt < 5; ++attempt) {
  const uint64_t before = generation.load();
  if (before & 1) continue;
  uint64_t copy[NwnFrameMetrics::COUNT];
  for (int i = 0; i < NwnFrameMetrics::COUNT; ++i) copy[i] = published[i].load();
  const uint64_t id = frame_id.load(), thread = writer_thread.load();
  if (before != generation.load() || id == 0) continue;
  out["available"] = true; out["frame_id"] = int64_t(id); out["writer_thread"] = int64_t(thread);
  out["units"] = "elapsed render-thread wall microseconds; counters since previous frame begin";
  for (int i = 0; i < NwnFrameMetrics::COUNT; ++i) out[names[i]] = int64_t(copy[i]);
  return out;
 }
 return out;
}
void NwnFrameProbe::_bind_methods() {
 ClassDB::bind_static_method("NwnFrameProbe", D_METHOD("set_enabled", "enabled"), &NwnFrameProbe::set_enabled);
 ClassDB::bind_static_method("NwnFrameProbe", D_METHOD("completed_frame"), &NwnFrameProbe::completed_frame);
}
