#pragma once
// NWN_SCRIPT_OWNER_TRACE_V1: diagnostic attribution only, default off.
#include "core/string/string_name.h"
#include "core/variant/dictionary.h"
#include <atomic>
#include <cstdint>

// Deliberately externally named for the exact image's linker MAP. The sampler
// reads these four bytes only while it owns a suspension of the main thread.
extern "C" std::atomic<uint32_t> nwn_script_trace_active_id;

namespace NwnScriptOwnerTrace {
constexpr uint32_t UNKNOWN_ID = UINT32_MAX;
constexpr uint64_t NO_SCOPE = UINT64_MAX;
bool enabled();
uint64_t enter(uint32_t &r_cached_id, const StringName &p_source, const StringName &p_name, int p_line);
Dictionary snapshot(bool p_include_rows);
void shutdown(); // CORE module teardown only, before unregister_core_types().
class Scope {
	uint64_t previous;
public:
	_FORCE_INLINE_ explicit Scope(uint64_t p_previous) : previous(p_previous) {}
	_FORCE_INLINE_ ~Scope() {
		if (previous != NO_SCOPE) {
			nwn_script_trace_active_id.store(uint32_t(previous), std::memory_order_relaxed);
		}
	}
	Scope(const Scope &) = delete;
	Scope &operator=(const Scope &) = delete;
};
}
