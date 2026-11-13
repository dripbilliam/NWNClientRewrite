# NWN-78 current empty-stream audit, 2026-11-12

The current `systems/native_render/live_world.gd` SHA256 `ec5c12122567a3824650dedbc0b212b3a0e2651d20825493ece161ea6bd4f422` matches the pinned original-scene NWN-61 selection. That settled report has zero pending batches. `_profile_process()` still creates an empty adoption candidate Array, calls `Priority.sort_rows()` on it, and iterates a duplicate of the empty `batches` Array every frame. This is real but small work, separate from the already selected quiescent appearance planner.

A **private-only** copy, `live_world_empty_batches_candidate.gd`, skipped sorting candidate counts of zero/one and copied `batches` only when nonempty. The actual `LiveWorld._profile_process()` ran in a headless SceneTree, with no batches and with one empty pending owner. All 16 final-state, callback-count and batch-preservation checks passed. ABBA group medians for 32 callbacks were:

| Scope | Control A | Candidate B | Candidate B | Control A | Approximate saving/callback |
| --- | ---: | ---: | ---: | ---: | ---: |
| No batches | 132 µs | 116 µs | 116 µs | 127 µs | 0.42 µs |
| One pending empty owner | 140 µs | 133 µs | 132 µs | 139 µs | 0.22 µs |

The component fixture has no dense assets or rendered frames and does not measure FPS. This cost is too small to support a production edit as a major optimization, so `live_world.gd` was left unchanged. Raw report: `tools/nwn78/empty-stream-component-b.json`.

The current original-scene replay's native visibility bridge was unavailable, with no active fade-owner snapshot, so its per-frame scope duplicates and active-ID enumeration cannot be assigned a cost in that workload. Earlier live-walk visibility snapshots come from older source, not this current pin. A future dense current-source quiet/moving/streaming census should decide whether any retained world state is actually duplicated or re-enumerated at meaningful cost; no storage rewrite is justified now.
