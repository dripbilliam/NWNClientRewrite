# NWN-74 private vertex-cache FPS review

Four coordinator-run normal-client legs used the same private engine binary (SHA-256 `3d0e9e6e`), original generation-2 capture, frozen client source, runtime files, camera, area `2147618622`, and render settings. The cache was OFF / ON / ON / OFF. Each leg retained 1,813–1,839 frame intervals from a 15-second steady window after full area completion. Profiling, VSync and the frame limiter were off; the viewport was 3440×1369 with 2× MSAA. Particles were enabled and collision disabled. The full machine-readable audit is `reports/nwn74-vertex-cache-pair-summary.json` (SHA-256 `428413a9ca5f54061a00b547d5c00a9051455af94ec04273318e510fc4fb834e`).

| Run | Cache | Mean ms | Median ms | p95 ms | p99 ms | Derived FPS |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| a | OFF | 8.2715 | 8.025 | 8.890 | 18.832 | 120.90 |
| b | ON | 8.1585 | 7.890 | 8.785 | 18.412 | 122.57 |
| c | ON | 8.2792 | 8.013 | 8.889 | 18.749 | 120.78 |
| d | OFF | 8.2368 | 7.970 | 8.838 | 18.860 | 121.41 |
| OFF average | | 8.2541 | 7.9975 | 8.864 | 18.846 | 121.15 |
| ON average | | 8.2188 | 7.9515 | 8.837 | 18.5805 | 121.68 |

ON averaged 0.0353 ms less per frame, or 0.53 derived FPS more (about 0.43%). The adjacent comparisons disagree: b was 0.1130 ms faster than a, while c was 0.0424 ms slower than d. This is **not a repeatable whole-frame FPS gain**. The 2-second rolling engine FPS observations averaged 121.2 OFF and 121.6 ON, consistent with a small, noisy difference.

The count-only replay still proves approximately 1,723 static vertex-array lookups skipped per dense-scene frame. The cache-on/off Vulkan fixture and prior private guard engine had identical pixel hashes under the same invocation. All four FPS legs had identical diagnostic fingerprints and returned `Native engine/lifetime diagnostics observed`; their source and runtime hash checks passed, but strict acceptance did not. No Arelith acceptance was run. Keep the cache private and opt-in; do not promote it as the default. The accepted engine executable/source are unchanged by this candidate. NWN-74 remains In Progress for a larger render-thread reduction and matched end-to-end benefit.
