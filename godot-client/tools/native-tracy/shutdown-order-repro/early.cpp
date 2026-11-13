// Source-only reproducer for root-owned validation. No Tracy or engine patch.
extern void early_probe();
#pragma warning(disable : 4075) // Match Tracy's user-defined initialization segment.
#pragma init_seg(".CRT$XCB") // Exact ordering class selected by Tracy0.13.0 on MSVC.
struct EarlyProfiler {
 EarlyProfiler() { early_probe(); }
};
EarlyProfiler profiler;
