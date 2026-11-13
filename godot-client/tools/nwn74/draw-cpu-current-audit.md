# NWN-74 draw CPU source audit, 2026-11-12

Status: read-only current-source review. No engine/client edit, build, graphical run, FPS claim, or ticket promotion.

## Pins

- Forward+ source: `.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp`, SHA-256 `fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd`.
- Pipeline-key header at review: sibling `scene_shader_forward_clustered.h`, SHA-256 `f2720b4717f05184ab973bc286d7c4e63fe8e5a9e52483559a437a5fd933f7e1`.
- Four-window original-scene phase report: `.cache/nwn74/render-probe-a/phase-summary-c.json`, SHA-256 `4f662bf9f6ef3c0dd3b345daac894470f387c85ced47a34ee6deb1d59946054`.
- Draw census: `tools/nwn74/forward-census-checkpoint.md`; raw control report `reports/nwn74-forward-census-d.json`, SHA-256 `f4ea2dff16070a9ef2f36da1ba75753ac833677fec437f74a3d7c9d9177baddf`.

## What remains measured

Four settled 240-frame original-scene windows average 3.84–3.86 ms completed render-frame wall, 2.12–2.15 ms camera scene, 0.66–0.69 ms shadow preparation, 1.31–1.33 ms Forward+, 0.13–0.14 ms Forward+ list fill, and 0.80 ms Forward+ draw list. These spans nest or overlap. The separate live `thenewone` Tracy busy window reports 5.30 ms `draw_cpu`, but its scene and runtime are different. The original-scene census has about 1,437 visible geometry, 3,054 Forward+ draws (1,253 color, 911 depth, 890 shadow), 189 pipeline lookups, and 2,865 pipeline reuses per frame.

The current Forward+ loop constructs a pipeline key and calculates its 11-step Murmur hash on each draw, including pipeline reuse. An exact-key comparison could skip some of those hashes. The census's 2,865 reuses is an *upper bound* on exact-key matches, because it records hash reuse rather than complete key equality. The loop already skips the pipeline map lookup and `draw_list_bind_render_pipeline` call on that reuse path. Its vertex-array lookup is independently covered by the prior private cache experiment: 1,723 skipped calls/frame produced no repeatable whole-frame gain. `mesh_surface_get_index_array` is an inline field load. The guarded material-used call also removed 791 calls/frame without an FPS gain.

I did not add another hash/equality fast path: the replacement compares 11 key fields before deciding whether to skip 11 small hash steps, with no direct timing or exact-key count showing a useful net reduction. A whole-record `memcmp` would also depend on struct padding and is not a valid equality oracle. Skipping color, depth or shadow draws from these counts alone would change coverage, and static grouping is already NWN-77's scope. The last source-only instance-data audit also found only invariant inline fields; the full record varies by pass and owner state.

## Next evidence gate

In a future exclusive window, instrument the *same representative busy scene* at `_fill_instance_data`, `_fill_render_list`, render-list sort, `_render_list_template`, shadow preparation, and RenderingDevice draw-graph submission, with draw/state counts and matched main/render lanes. Only make a private candidate where a measured span and exact work count outweigh the guard and cache's prior negative FPS results. Preserve color/depth/shadow coverage and visual output; require a matched normal-client ABBA before promoting. NWN-74 remains In Progress.
