# NWN-46 camera-shake owner boundary

Source-only checkpoint, 2026-11-13. No production edit, build, client launch or graphical test.

## Pinned client path

| Source | SHA-256 |
| --- | --- |
| `systems/visual_phases.gd` | `c375c5fc3b70f0d737a924b46c57ed86c852937d802ff74246640d133383c126` |
| `systems/visual_runtime.gd` | `c1ef8cef8214c074c811f1e5471e667318ce5563626f0f1012cfa7cef895b6b5` |
| `systems/visual_world.gd` | `e68bc0a8243ad08c928a19d74757eb4267088e324f9e7875d01a3afa38b9d9ac` |
| `systems/native_data/area_visual_definition.gd` | `29b16229b38124c2ff2cdaf9ecc3577ff43fc7699619ad988cd5ffdfd908803c` |

`visual_phases.gd:_geometry()` already reads original `ShakeType`, `ShakeDuration` and `ShakeDelay`. Under `scope10c == 0` and a non-null controlled client, type 1 dispatches `shakeOnce(client, milliseconds_long(f32(delay)))`; type 2 dispatches `shakeLoop(client, milliseconds_long(f32(delay)), milliseconds_long(f32(duration)))`. The focused `tests/visual_phases_test.gd` supplies both callbacks and records their arguments. This audit did not rerun it while the user's client was open.

The first unimplemented edge is `visual_runtime.gd:54-55`: both callbacks emit `visual.camera-shake-unimplemented` instead of scheduling a camera effect. `visual_world.gd` owns the effect list and retirement, and `live_world.gd` closes that world on area exit. `area_visual_definition.gd:20` separately flags area visual types 1/2 as pending. There is no proved camera-shake transform, waveform, interval, stacking/replacement rule, or post-retirement behavior in the saved client path, so merely wiring the callbacks to a generic camera offset would invent presentation.

## Next bounded implementation gate

Trace the two original callback targets from the pinned visual-phase native edge to the camera owner: establish delay/length clock, displacement or rotation formula, multiple-effect composition and stop/reset semantics. Then add one effect-ID and generation-scoped camera-shake owner called from these two existing callbacks. A headless oracle should cover type 1/2 argument conversion, controlled-only admission, delayed start, overlapping effects, stale generation, stop/removal and area retirement. Original-asset graphical comparison remains required for NWN-46 acceptance.
