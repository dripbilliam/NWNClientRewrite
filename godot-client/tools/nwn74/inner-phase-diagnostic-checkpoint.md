# NWN-74 Forward+ inner-phase diagnostic, 2026-11-12

The new live Arelith Tracy captures expose `draw_cpu` only; they do not contain inner Forward+ zones. The current private engine source's generated `core/profiling/profiling.gen.h` says `/* NO CONTENT */`. A one-translation-unit overlay using `GodotProfileZone` therefore built successfully but produced no Tracy listener. The two attempted collectors yielded no trace. I did not use them as timing evidence or rebuild the profiler across the engine.

I instead added an opt-in `NWN74_INNER_PHASES=1` clock to a private copy of `render_forward_clustered.cpp`. It accumulates `OS::get_ticks_usec()` spans by rasterizer frame and prints a row per 120 completed render frames. The accepted Forward+ source is SHA-256 `fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd`. Probe A overlay is `1e403149df32010d86a60aef350ca1255787a443648a983e9eee952433c97fca`; its built engine is `28e5d6e4c22ecbddab2a50dfe9e074041c7e6c524813d34cd42dfb7752738c17`. Its build receipt confirms exactly one TU compiled and the private source, object, binary, SCons state, accepted source and accepted binary were restored or unchanged. The offline original-scene replay used the pinned generation-2 capture and source selection, wrote 19 completed rows and no FPS file. The replay's `exit=1` reflects existing native engine/lifetime diagnostics; the phase log and source/binary pins were retained. Peak observed Godot private memory was 6.33 GiB.

In nine settled rows covering 1,080 render frames, Probe A measured these **inclusive** means per frame:

| Forward+ span | Mean |
| --- | ---: |
| `_render_scene` | 1.366 ms |
| Draw-list wrapper | 0.828 ms |
| `_render_list_template` | 0.780 ms |
| `_pre_opaque_render` | 0.291 ms |
| `_fill_render_list` | 0.153 ms |
| Primary + secondary sort | 0.088 ms |
| `_fill_instance_data` | 0.071 ms |
| `_setup_environment` | 0.019 ms |

The draw-list wrapper contains `_render_list_template`; `_pre_opaque_render` can also contain secondary draw lists. These columns **must not be summed**. The 0.78 ms template is the largest directly isolated draw-list phase in this captured scene.

Probe B adds clocks to one out of eight draw slots inside the template. Its overlay SHA-256 is `0d3c0d5c1f9b1aa3ebf9167615ba68b4783b655098557af5f22e638eadd67e64`, engine SHA-256 `9f87365d5688cad65b313c6c8e68635c8c26195e662752cddbdb5cd47f4c8875`. Exactly one TU compiled; all accepted and private build inputs were restored or unchanged. Seven settled rows cover 840 render frames and 3,054 submitted draws/frame. Sampled means per frame were binding 54.8 µs, draw submission 31.4 µs, vertex-array resolution 27.1 µs, pipeline selection 12.9 µs, push constant 9.3 µs and input mask 9.1 µs. Binding ranked highest within the sampled operations. The sampled timer overhead is material: total template mean was 0.882 ms in Probe B versus 0.780 ms in Probe A, from separate replays. Therefore these samples cannot be multiplied by eight to claim a whole-frame cost or saving. Probe B's memory process-name monitor returned zero, so its advertised 8 GiB guard was not confirmed; its run completed in 50 seconds without a watchdog stop.

No substantial safe code change is supported yet. The current renderer already skips unchanged pipeline, vertex-array, index-array and uniform-set binds. Binding contains required device commands and material uniform-set validity checks; this probe does not count which operation dominates or prove an avoidable duplicate. The earlier static vertex cache removed 1,723 lookups/frame without a repeatable FPS benefit, and the pipeline-hash shortcut's best standalone bound was about 0.021 ms/frame. A next count-only gate should distinguish material validity checks and each actual `RenderingDevice` bind/draw command in the same settled scene. Only after a repeatable unnecessary operation is proven should a private optimization and matched client A/B be attempted. NWN-74 stays **In Progress**.

Evidence: Probe A `.cache/nwn74/inner-phase-clock-a/{receipt.json,build-receipt.json,run-receipt.json,summary.json}`; Probe B `.cache/nwn74/inner-phase-clock-b/{receipt.json,build-receipt.json,run-receipt.json,summary.json}`; full phase rows in `reports/nwn74-inner-phase-clock-{a,b}.engine.log`. No accepted engine, client, visual output or FPS acceptance was changed, and no detailed private-path Linear post was made.
