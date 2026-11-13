# NWN-71 transition wait checkpoint

Status: **producer unresolved; no scheduling or warmup change justified**. This separates the original unlabelled Arelith wait from a later labelled entry capture. Thread durations below overlap and must not be added.

## Original Arelith stall

The saved `newertrace.tracy` review at `.cache/nwn71/critical-path.json` and `critical-path-review.txt` places a 53.331 ms main render sync inside a 67.885 ms gameplay frame. The overlapping render-thread draw lasts 67.803 ms, with 51.292 ms in `scene->update` and 49.892 ms in a worker-group wait. The exported worker scopes have no group ID or description, so temporal overlap does not identify its producer. The next draw starts after the stalled draw and lasts 1.197 ms; it is not the stalled render work. This trace measures CPU elapsed waits, not GPU execution.

## Later labelled original-asset entry

The separate-render-thread diagnostic capture `.cache/nwn71/capture-scene-cull-entry-d/rd-stall-review-b.json` contains a 63.591 ms main render sync overlapping a 73.810 ms `NWN71/RD/render_scene` span. Its nested `NWN71/RD/compositor_effects` span takes 71.699 ms; `NWN71/RD/scene_body` takes 73.800 ms. The same interval contains **no group wait**. A `vkCreateGraphicsPipelines` scope takes 0.143 ms and a `driver->fence_wait` scope takes 0.003 ms. These are far too small to assign the 71.699 ms compositor elapsed interval to either of those specific measured operations. The earlier group wait and this compositor stall are different observed phenomena.

The instrumented `_process_compositor_effects` body in `.cache/nwn71/rd-inner-proposal-b/after/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp:299-320` wraps the whole function, including each effect's `callback.callv(arr)`. It does **not** time individual callbacks. The normal camera stack can contain `native_gamma_effect.gd` and `particle_stream_effect.gd` (`systems/native_render/camera_effects.gd:6-20`, `native_gamma.gd:21`, `particle_stream_group.gd:157`). In `reports/nwn71-scene-cull-entry-d.json`, the gamma effect is enabled and reports 1,757 passes; the native particle stream reports 1,757 submissions but zero actual draws/uploads by shutdown. This proves those owners were present, not which callback consumed the 71.699 ms. The gamma callback may create compute shader/pipeline resources on first use (`native_gamma_effect.gd:145-181`); the particle callback can create a framebuffer or invoke native draw (`particle_stream_effect.gd:17-52`). Both remain candidates. No compositor subtype, compute-pipeline/driver wait, or resource operation is identified for the slow interval.

## Controlled first-use work does not identify either live stall

The controlled shader fixture in `.cache/nwn71/first-use-review-a.json` labels an exact ShaderCompilation group and a 16.096 ms wait inside `scene->update`. A separate controlled material case in `.cache/nwn71/driver-findings-a.json` labels a PipelineCompilation task whose render wait is 53.779 ms; its worker spends 61.964 ms inside `vkCreateGraphicsPipelines`, while its cache lock wait is 0.000124 ms. Those prove possible first-use mechanisms in authored fixtures. They cannot assign the unlabelled Arelith group or the later compositor callback.

The original-asset normal-frame screening pair in `.cache/nwn71/app-verdict-a.json` had zero new 3D pipelines in its first-visible window. Its private presentation fence prolonged veil retention by 11.943 ms and increased observed-ready to first-visible main completion from 8.591 to 14.782 ms. It was correctly parked. The authored prewarm experiment moved about 82 ms of work under the cover but left total first-visible latency about 87.5 ms; it did not reduce work.

## Narrow next probe and acceptance

Instrument **individual effect callbacks** during a representative transition, with a stable effect identity and callback type. Within the identified slow effect, time first-use resource creation, buffer updates, native draw dispatch, resolve and compute-list submission separately. Capture the exact same frame's main sync and render span, plus actual worker group/pipeline/fence labels. A no-FPS diagnostic run can establish identity; normal-build matched entry and frame-interval results are still required before a production fix or ticket completion. Avoid changing the shared normal client or engine until this branch is identified.
