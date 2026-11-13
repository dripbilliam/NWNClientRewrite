// Private diagnostic ABI. No Tracy headers or C++ objects cross the DLL boundary.
#ifndef NWN_TRACY_BRIDGE_API_V1_H
#define NWN_TRACY_BRIDGE_API_V1_H
#include <stdint.h>

enum NwnTracyZoneV1 : uint32_t {
 NWN_TRACY_PARTICLE_FRAME = 1,
 NWN_TRACY_PARTICLE_SETUP = 2,
 NWN_TRACY_PARTICLE_ADVANCE_BATCH = 3,
 NWN_TRACY_PARTICLE_SORT_PACK = 4,
 NWN_TRACY_PARTICLE_GEOMETRY_BATCH = 5,
 NWN_TRACY_PARTICLE_PUBLICATION = 6,
 NWN_TRACY_PARTICLE_COUNTERS = 7,
 NWN_TRACY_PARTICLE_SCENE_FRAME = 8,
 NWN_TRACY_PARTICLE_REFRESH_VISIBILITY = 9,
 NWN_TRACY_PARTICLE_RENDER_SUBMIT = 10,
 NWN_TRACY_MODEL_POSE_PUBLICATION = 11,
 NWN_TRACY_LIGHT_HISTORY_STEP = 12,
 NWN_TRACY_PARTICLE_RENDER_DRAW = 13,
 NWN_TRACY_ZONE_COUNT = 14
};

struct NwnTracySnapshotV1 {
 uint32_t version;
 uint32_t bytes;
 uint64_t begin_requests;
 uint64_t begun;
 uint64_t end_requests;
 uint64_t ended;
 uint64_t disconnected;
 uint64_t overflow;
 uint64_t invalid_token;
 uint64_t live_scopes;
};
using NwnTracyBeginV1 = uint64_t (*)(uint32_t);
using NwnTracyEndV1 = void (*)(uint64_t);
using NwnTracyConnectedV1 = uint32_t (*)();
using NwnTracySnapshotFnV1 = uint32_t (*)(NwnTracySnapshotV1 *, uint32_t);

namespace nwn_trace {
// Bind ONCE during extension initialization, before any registered class can run.
// These pointers remain immutable until process exit; no hot GetProcAddress calls.
struct Api { NwnTracyBeginV1 begin = nullptr; NwnTracyEndV1 end = nullptr; NwnTracyConnectedV1 connected = nullptr; NwnTracySnapshotFnV1 snapshot = nullptr; };
inline Api api;
class Scope {
 uint64_t token = 0;
 NwnTracyEndV1 finish = nullptr;
public:
 explicit Scope(uint32_t zone) noexcept : finish(api.end) { if (api.begin && finish) token = api.begin(zone); }
 ~Scope() { if (token && finish) finish(token); }
 Scope(const Scope &) = delete;
 Scope &operator=(const Scope &) = delete;
};
// Sequential batch phases without introducing a C++ block or changing local lifetimes.
class Phase {
 uint64_t token = 0;
 NwnTracyEndV1 finish = nullptr;
public:
 explicit Phase(uint32_t zone) noexcept : finish(api.end) { if (api.begin && finish) token = api.begin(zone); }
 ~Phase() { close(); }
 void close() noexcept { if (token && finish) finish(token); token = 0; }
 void next(uint32_t zone) noexcept { close(); if (api.begin && finish) token = api.begin(zone); }
 Phase(const Phase &) = delete;
 Phase &operator=(const Phase &) = delete;
};
}
#endif
