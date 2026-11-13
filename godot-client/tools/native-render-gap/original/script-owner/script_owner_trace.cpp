#include "script_owner_trace.h"
#include "core/os/os.h"
#include "core/os/thread.h"
#ifdef WINDOWS_ENABLED
#include <windows.h>
#endif

extern "C" {
alignas(4) std::atomic<uint32_t> nwn_script_trace_active_id{0};
}
static_assert(sizeof(nwn_script_trace_active_id) == 4, "Sampler schema requires four bytes");
static_assert(std::atomic<uint32_t>::is_always_lock_free, "No hidden lock on the hot path");

namespace {
constexpr uint32_t REGISTRY_LIMIT = 8192;
struct Row { String source; String name; int line = 0; };
// The main thread alone accesses the registry and cached function IDs. Copied
// strings outlive a destroyed function; IDs are never recycled or reset.
Row rows[REGISTRY_LIMIT];
uint32_t registered = 0;
uint64_t overflow_functions = 0;
uint64_t native_main_tid = 0;
bool shutting_down = false;
}
namespace NwnScriptOwnerTrace {
bool enabled() {
	if (!OS::get_singleton()) {
		return false;
	}
	static const bool on = []() {
		for (const String &arg : OS::get_singleton()->get_cmdline_user_args()) {
			if (arg == "--script-owner-trace=on") {
				return true;
			}
		}
		return false;
	}();
	return on;
}
uint64_t enter(uint32_t &r_cached_id, const StringName &p_source, const StringName &p_name, int p_line) {
	// This check precedes every access to the function-local cached ID, the
	// immutable-name registry, and the main-thread active ID. Worker calls are
	// intentionally not attributed and cannot alter a suspended main scope.
	if (!Thread::is_main_thread()) {
		return NO_SCOPE;
	}
	if (shutting_down) return NO_SCOPE;
	if (r_cached_id == 0) {
		if (registered == REGISTRY_LIMIT) {
			r_cached_id = UNKNOWN_ID;
			++overflow_functions;
		} else {
			Row &row = rows[registered];
			row.source = String(p_source);
			row.name = String(p_name);
			row.line = p_line;
			r_cached_id = ++registered;
#ifdef WINDOWS_ENABLED
			if (native_main_tid == 0) native_main_tid = GetCurrentThreadId();
#endif
		}
	}
	const uint32_t previous = nwn_script_trace_active_id.load(std::memory_order_relaxed);
	nwn_script_trace_active_id.store(r_cached_id, std::memory_order_relaxed);
	return previous;
}
Dictionary snapshot(bool p_include_rows) {
	Dictionary out;
	out["version"] = 1;
	out["enabled"] = enabled();
	out["available"] = false;
	out["scope"] = "Diagnostic innermost active main-thread GDScript call, including its native callees and cleanup; not a complete stack, exclusive time, or FPS measurement. Await restores the caller until resumed. IDs immutable and never recycled; unknown means bounded registry exhaustion. Worker calls do not publish.";
	if (!Thread::is_main_thread()) return out;
	if (shutting_down) return out;
	out["available"] = true;
	out["active_id"] = int64_t(nwn_script_trace_active_id.load(std::memory_order_relaxed));
	out["active_id_address_hex"] = "0x" + String::num_uint64(uint64_t(reinterpret_cast<uintptr_t>(&nwn_script_trace_active_id)), 16);
	out["active_id_bytes"] = 4;
	out["active_id_endian"] = "little";
	out["outside_id"] = 0;
	out["unknown_id"] = int64_t(UNKNOWN_ID);
	out["main_godot_thread_id"] = int64_t(Thread::get_main_id());
	out["main_native_thread_id"] = int64_t(native_main_tid);
#ifdef WINDOWS_ENABLED
	out["process_id"] = int64_t(GetCurrentProcessId());
#endif
	out["registered"] = int64_t(registered);
	out["capacity"] = int64_t(REGISTRY_LIMIT);
	out["overflow_functions"] = int64_t(overflow_functions);
	if (p_include_rows) {
		Array copied;
		for (uint32_t i = 0; i < registered; ++i) {
			Dictionary row;
			row["id"] = int64_t(i + 1);
			row["source"] = rows[i].source;
			row["function"] = rows[i].name;
			row["line"] = rows[i].line;
			copied.push_back(row);
		}
		out["rows"] = copied;
	}
	return out;
}
void shutdown() {
	// Module CORE teardown runs after GDScript SERVERS teardown, while String
	// allocation and the main-thread identity are still valid. No authored code
	// or Object/Variant is retained here. Rows are not reused or reset at runtime.
	if (!Thread::is_main_thread()) return;
	shutting_down = true;
	nwn_script_trace_active_id.store(0, std::memory_order_relaxed);
	for (uint32_t i = 0; i < registered; ++i) {
		rows[i].source = String();
		rows[i].name = String();
	}
}
}
