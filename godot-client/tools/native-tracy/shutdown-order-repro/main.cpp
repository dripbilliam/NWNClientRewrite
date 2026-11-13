// Compile both TUs with the selected MSVC /std:c++17 /O2 /EHsc /W4 /WX.
// Baseline: no define. Narrow candidate: /DNWN_NARROW_ATOMIC_COUNTER=1.
// Alternative broad-constructor candidate: /DNWN_CONSTANT_COUNTER=1.
// This models the relevant pinned Godot atomic/TLS initialization, not gameplay.
#include <atomic>
#include <cstdint>
#include <cstdio>

template<typename T> class SafeNumericRepro {
 std::atomic<T> value;
public:
#ifdef NWN_CONSTANT_COUNTER
 constexpr explicit SafeNumericRepro(T initial = T(0)) : value(initial) {}
#else
 explicit SafeNumericRepro(T initial = T(0)) { value.store(initial, std::memory_order_release); }
#endif
 T increment() { return value.fetch_add(1, std::memory_order_acq_rel) + 1; }
 T get() const { return value.load(std::memory_order_acquire); }
};

#ifdef NWN_NARROW_ATOMIC_COUNTER
std::atomic<uint64_t> counter{1};
uint64_t increment_counter() { return counter.fetch_add(1, std::memory_order_acq_rel) + 1; }
uint64_t get_counter() { return counter.load(std::memory_order_acquire); }
#else
SafeNumericRepro<uint64_t> counter(1);
uint64_t increment_counter() { return counter.increment(); }
uint64_t get_counter() { return counter.get(); }
#endif
thread_local uint64_t caller_id = increment_counter();
std::atomic<bool> assigned{false};
uint64_t early_id = 0;
uint64_t early_counter = 0;

void early_probe() {
 early_id = caller_id;
 early_counter = get_counter();
}

int main() {
 const auto initial_id = caller_id;
 const auto initial_counter = get_counter();
 // Exact important make_main_thread early return/claim relationship.
 if (caller_id != 1) { if (assigned.exchange(true)) return 2; caller_id = 1; }
 const bool release_would_pass = caller_id == 1 && assigned.exchange(false);
 std::printf("{\"early_id\":%llu,\"early_counter\":%llu,\"main_initial_id\":%llu,\"main_initial_counter\":%llu,\"release_would_pass\":%s}\n",
  static_cast<unsigned long long>(early_id),static_cast<unsigned long long>(early_counter),
  static_cast<unsigned long long>(initial_id),static_cast<unsigned long long>(initial_counter),
  release_would_pass ? "true" : "false");
 return release_would_pass ? 0 : 1;
}
