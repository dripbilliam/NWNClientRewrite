# NWN-74 accepted-source guard checkpoint

Status: the accepted engine **source** contains the reviewed material-use guard; the accepted engine **executable is unchanged**. A private same-source control/candidate pair passed bounded compilation and Vulkan pixel correctness. Matched FPS remains unmeasured; NWN-74 stays open.

## Accepted source and safety

- Source: `.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp`. Original SHA-256 `49fc6ca310573c5a0704e5a6d9dfa4cf769b37d756239f7e49aa9502d1d97705`; backup `.cache/nwn74/accepted-forward-before-guard.cpp`. Patched SHA-256 `fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd`; exact two-hunk diff `tools/nwn74/accepted-material-guard.diff` (SHA-256 `60151dda7158466cce7dfb96bbc6fa1ffc40d67f3bae306c35e29e063d248414`).
- The guard remembers the last material within one Forward+ render list and calls `set_as_used()` only when the material pointer changes. `MaterialStorage::MaterialData::set_as_used()` merely loops over `render_target_cache` and sets each target's `was_used=true` (`material_storage.cpp:1251–1255`). The cache is populated only in `update_textures()` (line 1004) and cleared in `update_parameters_uniform_set()` (line 1190). Neither operation is called in `_render_list_template`; its only material call is `set_as_used()`. The local guard preserves a mark on the first use of each consecutive material, including a live render-target texture.
- The accepted executable `.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe` stayed SHA-256 `0a2710bd80c0a2cbfeca8ac28338a071561ba741c52a01857df233d69efe02d1` throughout. No accepted engine build was run.

## Private build provenance

The private clone `.cache/nwn74/engine-source-f-control` copied only the default engine outputs, excluding 3.13 GiB of obsolete manual variants and using no hardlinks to accepted files. The private control restored the original Forward+ source and rebuilt **25 translation units** from the current engine source state. Those TUs were:

```
platform/windows/os_windows.cpp
platform/windows/godot_windows.cpp
main/main.cpp
modules/gdscript/gdscript_vm.cpp
modules/nwn_frame_probe/frame_probe.cpp
modules/nwn_frame_probe/register_types.cpp
modules/openxr/openxr_api.cpp
drivers/vulkan/rendering_device_driver_vulkan.cpp
scene/main/scene_tree.cpp
scene/3d/skeleton_3d.cpp
servers/rendering/renderer_scene_cull.cpp
servers/rendering/renderer_viewport.cpp
servers/rendering/rendering_device.cpp
servers/rendering/rendering_light_culler.cpp
servers/rendering/rendering_server_default.cpp
servers/rendering/renderer_rd/renderer_scene_render_rd.cpp
servers/rendering/renderer_rd/shader_rd.cpp
servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp
servers/rendering/renderer_rd/storage_rd/light_storage.cpp
servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp
servers/rendering/renderer_rd/storage_rd/utilities.cpp
core/profiling/nwn_tracy_bridge.cpp
core/profiling/profiling.cpp
core/os/memory.cpp
core/object/worker_thread_pool.cpp
```

This is the **rebuild delta relative to the accepted executable**, not evidence that all 25 individual source files changed. Their precise source hashes and actual compile list are in `.cache/nwn74/engine-build-f-control/receipt.json`. Control executable SHA-256: `0c5b840e4dfd9500dcbba4e8aa68b1aed635461659281cda543d331916be4795`. The candidate copied only the accepted two-hunk Forward+ patch into this same clone and recompiled exactly **one TU**, `render_forward_clustered.cpp`. Candidate executable SHA-256: `52d8c4f85e126c28de5d321119b3a67310ec121a307a9c6e83802a529a6a7af3`; receipt `.cache/nwn74/engine-build-f-candidate/receipt.json`. Both builds used the same release/Tracy flags and `-j2`, peaked around 4 GiB working set, and stayed above 21.7 GiB free disk. The control/candidate pair isolates the guard; **candidate versus accepted executable does not**, because the control incorporated those 25 pending rebuilds.

## Correctness and measured work

- The private Vulkan fixture `tests/nwn74/accepted_pair_pixels.gd` samples a live `SubViewport` texture from one material shared across 24 distinct meshes. It uses `UPDATE_WHEN_VISIBLE`, changes the source red to green, and verifies both states render. Both private engines exited 0. Red raw pixel SHA-256 was `0a390baa1265341325787a019a72c1b04bcd26922b27aa625eb00390f5e3c26a` in both; green was `72c78ea30cb1e5131db4d9261add9e4d61300a1a495c44758f7834d4f07d6696` in both. Receipt: `.cache/nwn74/accepted-pair-fixture-f/pair-receipt-b.json`.
- Earlier isolated instrumented engines measured the dense original scene at about 3,054 Forward+ draws per settled frame. The guard reduced `set_as_used()` from 1,253 to 462 calls/frame (63.2%) with unchanged draw count. The 24-mesh synthetic census reduced those calls 24→2 and preserved exact pixels. See `tools/nwn74/forward-census-checkpoint.md`. These are **work-count and correctness results**, not FPS evidence. The earlier original-scene replays had the same sandbox lifetime diagnostic in both modes.

## Exclusive FPS pair prepared

`tools/nwn74/run-accepted-source-pair-fps.cjs --verify-only` passes. Plan: `.cache/nwn74/fps-pair-f/plan.json`, SHA-256 `bc6e5a4dbf1b148f43d98268d534f94305994c44c0f8430a8684266aaf1b1f4b`. It pins all 2,431 frozen normal-client source files, the same generation-2 original-input capture and preferences, profiling off, and runs control/candidate/candidate/control. Each leg requests a 15-second steady window **after** `object_visuals_complete` and the driver's 5-second settle. Both mode-specific drivers passed capture verification (5,704 events, one catalog, no game network). The driver is idle until the coordinator grants exclusive timing. `tools/nwn74/summarize-accepted-source-pair-fps.cjs` will report mean/median/p95/p99/worst frame intervals, derived mean FPS and area-ready entry cost; strict replay success is reported separately.

Do not promote the accepted executable until the coordinator reviews the 25-TU provenance and exclusive pair result.
