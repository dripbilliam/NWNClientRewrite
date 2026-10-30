# Profiling-off and post-loading measurement controls

2026-10-27. Keep these diagnostic controls and the previously validated bounded
summary worker. No new rendering method is promoted. Stop automated testing for
the user's requested live test after this comparison. The optimization goal
remains active and native-client performance parity is unaccepted.

## Controls

`tools/replay-native-loading.mjs --profiling=false` explicitly disables detailed
profiling for that process even if the saved preference is enabled. It does not
overwrite that preference. The default replay policy remains profiling enabled.
Normal menu preferences remain available under Options / Performance.

`--steady-ms=6000 --settle-ms=1500` waits for the selected captured area's visual
completion and settling, then requests an offline-only measurement boundary.
Native code validates connection, generation, area and readiness before clearing
only the numeric frame-interval samples. The scene, assets, camera and server
input are not reset. Acknowledgement, elapsed duration and completion are recorded.
This option cannot be combined with interactive or duration-limited replay.

Receipts pin project configuration, native extension declarations, runtime engine
and kernel hashes alongside existing source/input hashes. Shutdown records actual
profiling, focus, viewport, renderer, MSAA, VSync, memory and cached draw counters
before diagnostic captures. These counters are one observation, not a trace of
the entire window. Explicit profiling-off is rejected if not verified in native
output. No forced GPU fence or per-frame disk capture is added.

## Next-test result and decision

Frozen capture `capture-pUQlR4`, generation4, all630 entities, original captured
3440x1369 view, ForwardPlus/Vulkan, MSAA2, VSync0, separate static Parts. Receipts:
`reports/native-goal2-clean-area4-{off,on}-v1.json`. Same recorded input, source and
runtime hashes; each reports zero game-network connections, zero remaining
workers, acknowledged finish and no engine/lifetime error. Both six-second steady
windows have zero intervals above50ms.

| Requested detailed profiling | Frames | Mean ms | P95 ms | P99 ms | Worst ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Off | 1489 | 4.039 | 4.947 | 6.183 | 9.036 |
| On | 1193 | 5.035 | 6.867 | 8.472 | 12.654 |

**Do not accept this pair as an isolated performance improvement.** Shutdown
observations differ: off is unfocused with1131 draws/68593 triangles, while on is
focused with2214 draws/96056 triangles. Matching input/source hashes alone does
not establish identical rendered workload or focus throughout the window. The
single cached draw sample also cannot identify when or why the workloads diverge.
The raw timings are observations only. No claim that profiling causes the full
difference, nor a comparison to the native binary, follows from this pair.

The37-check Options regression `native-goal2-clean-profiling-options-v1` passes
under normal-heap CDB, including explicit false override with saved true and
unchanged persisted preference. Worker correctness and owned Prelude loading
remain covered by the prior accepted summary-worker checkpoint; this change does
not replace those historical receipts with a new local gameplay claim.

Keep the controls because they prevent a saved profiling preference from silently
contaminating future rendering tests and separate loading from steady sampling.
Keep the worker for its previously measured removal of summary calculations from
the frame thread. No batching, culling, shadow, lighting or asset policy changes
were made in this comparison. Do not start another benchmark before the requested
live handoff. Future comparisons need matched focus and rendered workload as well
as repeated/order-reversed samples before throughput acceptance.
