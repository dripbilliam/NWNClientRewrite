// Private engine diagnostic implementation. Compiled by core/profiling/SCsub's *.cpp.
// One Tracy client in the engine owns all storage, timestamps, TLS, and transport.
#include "core/profiling/profiling.h"
#include "nwn_tracy_bridge_api.h"
#include <atomic>
#include <new>

#if defined(_WIN32)
#define NWN_TRACE_EXPORT extern "C" __declspec(dllexport)
#else
#define NWN_TRACE_EXPORT extern "C"
#endif

namespace {
struct Counters {
 std::atomic<uint64_t> requested{0}, begun{0}, end_requested{0}, ended{0}, disconnected{0}, overflow{0}, invalid{0}, live{0};
} counters;
#if defined(GODOT_USE_TRACY)
// Fixed engine-owned locations have process lifetime. No DLL String/Variant or
// SourceLocationData address is retained by Tracy.
static const tracy::SourceLocationData locations[NWN_TRACY_ZONE_COUNT] = {
 {"unused", "unused", "NWN/private", 0, 0},
 {"NWNCapture/Particles/frame", "particle_presentation::Owner::frame", "NWN/native/particle_presentation.hpp", 0, 0xF0A040},
 {"NWNCapture/Particles/setup", "particle_presentation::Owner::frame", "NWN/native/particle_presentation.hpp", 0, 0xF0A040},
 {"NWNCapture/Particles/advance_batch", "particle_presentation::Owner::frame", "NWN/native/particle_presentation.hpp", 0, 0xF0A040},
 {"NWNCapture/Particles/sort_pack", "particle_presentation::Owner::frame", "NWN/native/particle_presentation.hpp", 0, 0xF0A040},
 {"NWNCapture/Particles/geometry_batch", "particle_presentation::Owner::frame", "NWN/native/particle_presentation.hpp", 0, 0xF0A040},
 {"NWNCapture/Particles/publication", "particle_presentation::Owner::frame", "NWN/native/particle_presentation.hpp", 0, 0xF0A040},
 {"NWNCapture/Particles/counters_summary", "particle_presentation::Owner::frame", "NWN/native/particle_presentation.hpp", 0, 0xF0A040},
 {"NWNCapture/Particles/scene_frame", "particle_presentation::Owner::scene_frame", "NWN/native/particle_presentation.hpp", 0, 0xF0A040},
 {"NWNCapture/Particles/refresh_visibility", "particle_presentation::Owner::refresh_visibility", "NWN/native/particle_presentation.hpp", 0, 0xF0A040},
 {"NWNCapture/Particles/render_submit", "particle_stream_render::Owner::submit", "NWN/native/particle_stream_render.hpp", 0, 0xF0A040},
 {"NWNCapture/Rigs/native_pose_publish", "model_pose_storage::Owner::publish", "NWN/native/model_pose_storage.hpp", 0, 0x70BF90},
 {"NWNCapture/Lights/history_step", "light_history::Owner::step", "NWN/native/light_history.hpp", 0, 0xE5DE65},
 {"NWNCapture/Particles/render_draw", "particle_stream_render::Owner::draw", "NWN/native/particle_stream_render.hpp", 0, 0xF0A040}
};
constexpr uint32_t MAX_NESTING = 64;
struct Slot {
 alignas(tracy::ScopedZone) unsigned char storage[sizeof(tracy::ScopedZone)];
 uint64_t token;
};
struct Local {
 Slot slots[MAX_NESTING];
 uint32_t depth = 0;
};
thread_local Local local;
#endif
}

// Referenced by the already-live profiling.cpp object. This forces extraction of
// this TU from a static core archive before normal export/dead-code processing.
extern "C" void nwn_tracy_link_anchor_v1() noexcept {}

NWN_TRACE_EXPORT uint32_t nwn_tracy_connected_v1() noexcept {
#if defined(GODOT_USE_TRACY)
 return tracy::GetProfiler().IsConnected() ? 1u : 0u;
#else
 return 0;
#endif
}

NWN_TRACE_EXPORT uint64_t nwn_tracy_zone_begin_v1(uint32_t zone) noexcept {
 const auto request = counters.requested.fetch_add(1, std::memory_order_relaxed) + 1;
#if defined(GODOT_USE_TRACY)
 if (zone == 0 || zone >= NWN_TRACY_ZONE_COUNT) { counters.invalid.fetch_add(1, std::memory_order_relaxed); return 0; }
 // Test before touching TLS or constructing a zone. Tracy itself still has its
 // own startup allocations/transport thread; this does not claim a zero-cost build.
 if (!tracy::GetProfiler().IsConnected()) { counters.disconnected.fetch_add(1, std::memory_order_relaxed); return 0; }
 if (local.depth == MAX_NESTING) { counters.overflow.fetch_add(1, std::memory_order_relaxed); return 0; }
 if (!request) { counters.overflow.fetch_add(1, std::memory_order_relaxed); return 0; }
 auto &slot = local.slots[local.depth];
 slot.token = request;
 // ScopedZone preserves Tracy's full connection ID across disconnect/reconnect.
 // A packed C-zone context alone would lose that 64-bit connection lifetime.
 new (slot.storage) tracy::ScopedZone(&locations[zone], -1, true);
 ++local.depth;
 counters.begun.fetch_add(1, std::memory_order_relaxed);
 counters.live.fetch_add(1, std::memory_order_relaxed);
 return slot.token;
#else
 (void)zone;
 (void)request;
 counters.disconnected.fetch_add(1, std::memory_order_relaxed);
 return 0;
#endif
}

NWN_TRACE_EXPORT void nwn_tracy_zone_end_v1(uint64_t token) noexcept {
 if (!token) return;
 counters.end_requested.fetch_add(1, std::memory_order_relaxed);
#if defined(GODOT_USE_TRACY)
 if (local.depth == 0 || local.slots[local.depth - 1].token != token) { counters.invalid.fetch_add(1, std::memory_order_relaxed); return; }
 auto &slot = local.slots[--local.depth];
 reinterpret_cast<tracy::ScopedZone *>(slot.storage)->~ScopedZone();
 slot.token = 0;
 counters.ended.fetch_add(1, std::memory_order_relaxed);
 counters.live.fetch_sub(1, std::memory_order_relaxed);
#endif
}

NWN_TRACE_EXPORT uint32_t nwn_tracy_snapshot_v1(NwnTracySnapshotV1 *out, uint32_t bytes) noexcept {
 if (!out || bytes != sizeof(NwnTracySnapshotV1)) return 0;
 *out = {1, sizeof(NwnTracySnapshotV1), counters.requested.load(std::memory_order_relaxed), counters.begun.load(std::memory_order_relaxed), counters.end_requested.load(std::memory_order_relaxed), counters.ended.load(std::memory_order_relaxed), counters.disconnected.load(std::memory_order_relaxed), counters.overflow.load(std::memory_order_relaxed), counters.invalid.load(std::memory_order_relaxed), counters.live.load(std::memory_order_relaxed)};
 return 1;
}
