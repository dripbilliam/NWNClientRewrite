# NWN-74 Forward+ draw census checkpoint

Status: private candidate verified for less work and pixel parity; **not promoted**. No matched FPS result or strict original-scene acceptance. The accepted engine and client were not changed.

## Source and capture identity

- Private control engine: `.cache/nwn74/engine-build-d/Godot_nwn74_forward_census_d_win64.exe`, SHA-256 `8003bd798f217053971ee4194577d7d85e5d937a6c7d9f3292057e3447447ab3`. Its three changed source files were copied to `engine-build-d/source-snapshot` before the candidate edit. Build receipt: `.cache/nwn74/engine-build-d/receipt.json`.
- Private candidate engine: `.cache/nwn74/engine-build-e/Godot_nwn74_material_dedup_e_win64.exe`, SHA-256 `37fddca06fe823a30c7158a40543d1116116b7abe1f8545fa22f952ef836e01d`. The only candidate source difference is the consecutive identical-material guard around `MaterialData::set_as_used()` in `engine-source-b/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp`. Dry run and actual build compiled one TU, with `-j2`; peak compiler working set 3.4 GiB and free disk stayed above 28 GiB. Build receipt: `.cache/nwn74/engine-build-e/receipt.json`.
- Both short original-scene diagnostic replays used the same frozen generation-2 capture (recording SHA-256 `1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463`), staged production selection SHA-256 `a74356055e5533199458be57e09dc2068d13b06ac61006865c42ffc95a4734e1`, detailed profiling on, `--steady-ms=4000`, and `--preview`. Reports: `reports/nwn74-forward-census-d.*` and `reports/nwn74-material-dedup-e.*`.
- The saved replay entered area `2147618622`. Both reports say source/runtime unchanged, but both exit with `Native engine/lifetime diagnostics observed`; root certificate and other sandbox diagnostics remain. This is a count/correctness diagnostic, not a clean acceptance or FPS comparison.

## Recurring work

The earlier four-window phase probe (`.cache/nwn74/render-probe-a/phase-summary-c.json`) measured a roughly 3.85 ms completed render frame, with about 2.35 ms viewport work, 2.14 ms camera scene work, 0.67 ms shadow preparation, 1.32 ms RD scene work and 0.80 ms Forward+ draw-list work. These are nested wall spans; do not add them. The live `thenewone` trace has a larger render-thread draw CPU mean of about 5.3 ms/frame in the busy 100–110 second window. These are different scenes/runtime states.

Three settled 240-frame profile windows per private original-scene run give means per completed render frame:

| Operation | Control | Candidate |
| --- | ---: | ---: |
| Scene instances | 16,365 | 16,340 |
| Visible geometry | 1,437 | 1,437 |
| Forward+ draw calls | 3,054 | 3,054 |
| Color / depth / shadow draws | 1,253 / 911 / 890 | 1,253 / 911 / 890 |
| Vertex-array lookups | 3,054 | 3,054 |
| Vertex-array binds | 2,595 | 2,603 |
| Pipeline lookups/binds | 189 | 172 |
| Pipeline reuses | 2,865 | 2,882 |
| Material uniform binds | 747 | 749 |
| `MaterialData::set_as_used()` calls | **1,253** | **462** |

The small differences in scene instances and state binds come from imperfect time alignment of these diagnostic replays. The candidate does not alter draw calls, shader selection, pipeline key construction, or material binding. The observed call reduction is 791 calls/frame (63.2%) in this scene. `set_as_used()` only loops over `render_target_cache` and sets each target's `was_used` bit, so repeating it on adjacent draws of the same material is idempotent. This is a real reduction in CPU instructions; the time/FPS benefit is not established and may be very small if those caches are empty.

## Correctness checks

- Private 24-frame Vulkan Forward+ fixture, `tests/nwn74/forward_census_smoke.gd`: 24 distinct meshes share two materials, with a shadowed directional light. Both engines passed 23 completed-frame samples and produced the **same raw pixel SHA-256** `b3659d71732bb6745e264c34c4d09da4c2cf4aa88f78875d9dc3ef70648d68a8`. Draws stayed 114/frame, including 24 color draws; material marks fell from 24 to 2. Receipt: `.cache/nwn74/forward-census-smoke-d/unique-pair-receipt.json`.
- Original-scene ready screenshots have 99.54% of pixels within 8 channel values; shutdown screenshots have 99.56% within 8. They are asynchronous screenshots and cannot establish exact frame parity. Both original-scene runs retained 33 visible lights and six shadow count in the settled windows.
- The headless fixture cannot exercise Forward+ on this Windows engine: it published no render frame. The hidden-window Vulkan fixture was used for correctness. It exited normally and left no private process running.

## Next step

The coordinator must claim the exact accepted engine source file before a production edit. Then integrate the guard, build with the accepted engine configuration, run matched normal-client visual/correctness checks and an exclusive FPS/Tracy pair. Keep the ticket open until those gates pass. The larger recurring draw burden is approximately 3,054 draws over color, depth and shadow; the pipeline is reused for most draws. Static batching is NWN-77's separate scope. Any further NWN-74 work should inspect which depth/shadow draws are necessary and the cost of the 3,054 vertex-array version lookups, without conflating them with pipeline creation.
