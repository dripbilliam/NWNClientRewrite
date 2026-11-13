// Included once by the private particle kernel translation unit, after its normal headers.
#ifndef NWN_TRACY_DLL_BIND_V1_HPP
#define NWN_TRACY_DLL_BIND_V1_HPP
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include "nwn_tracy_bridge_api.h"
namespace nwn_trace {
inline bool bind_engine_once() noexcept {
 // The main module remains loaded for the entire extension lifetime. No LoadLibrary,
 // extra profiler instance, search path change, or third-party DLL is involved.
 const auto engine = GetModuleHandleW(nullptr);
 if (!engine) return false;
 Api found;
 found.begin = reinterpret_cast<NwnTracyBeginV1>(GetProcAddress(engine, "nwn_tracy_zone_begin_v1"));
 found.end = reinterpret_cast<NwnTracyEndV1>(GetProcAddress(engine, "nwn_tracy_zone_end_v1"));
 found.connected = reinterpret_cast<NwnTracyConnectedV1>(GetProcAddress(engine, "nwn_tracy_connected_v1"));
 found.snapshot = reinterpret_cast<NwnTracySnapshotFnV1>(GetProcAddress(engine, "nwn_tracy_snapshot_v1"));
 if (!found.begin || !found.end || !found.connected || !found.snapshot) return false;
 api = found;
 return true;
}
}
#endif
