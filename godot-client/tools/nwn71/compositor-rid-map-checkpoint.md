# NWN-71 compositor callback RID map

## Capture identity and limits

- Private trace: `.cache/nwn71/capture-compositor-callback-v2/entry.tracy`, SHA256 `d79ae3e336ab0d7dfa687d82974545614b2bf7e590b00a5e7614e84d34a6ecdf`, 145,494,444 bytes. Export: `callbacks.csv`, SHA256 `85758d692319fe35f9b0aca09c2ef4d06b1b99f6c337b7a990a6efe2f767ee35`.
- Private engine: `.cache/nwn71/compositor-callback-a/Godot_nwn71_compositor_callback_v2_win64.exe`, SHA256 `633473723181e5b6a5c5190a84f4e2be80b8e15fa81ab46d8318ad3b497ed910`. `build-receipt-v2.json` records 14 actual TUs, `-j2`, 4.14 GB peak working set, and 18.55 GB minimum disk free. Accepted engine and client were untouched.
- This was one original-asset diagnostic replay, not an FPS comparison. Tracy capture exited 0. The strict replay exited 1 because the private scratch engine could not supply `NwnLightHistory` to the native extension; see `reports/nwn71-compositor-callback-v2.engine.log`. The scene reached playable state and reported gamma and shared particle stream active, but this trace cannot pass full acceptance.

## RID mapping

| Trace RID | Low RID slot | Calls | Median / maximum CPU callback | Owner and confidence |
| --- | ---: | ---: | ---: | --- |
| `3783866187776` | 0 | 390 | 0.041 / **34.9897 ms** | **Native gamma/postprocess**, high confidence |
| `29051158790150` | 6 | 390 | 0.041 / 0.1462 ms | **Shared particle stream**, high confidence |
| `19963007991813` | 5 | 8 | 0.013 / 0.0195 ms | **Icon viewport draw fence**, high confidence |

`core/templates/rid_owner.h` constructs a RID from a generated validator in the high 32 bits and the owner's free-list index in the low 32 bits. `RendererCompositorStorage::compositor_effect_allocate` uses one `compositor_effects_owner` (`servers/rendering/storage/compositor_storage.cpp:47-52`). Slot 0 was allocated before slots 5 and 6. The frozen replay source constructs `gamma_controller` before world creation (`native_live_world.gd:149,293`), and `native_gamma.gd:9` constructs its `CompositorEffect` immediately. The shared particle effect is constructed later by `particle_stream_group.gd:52` during world `_enter_tree` (`live_world.gd:273-277`). The icon viewport draw fence is created when `native_item_icons.gd:54-57` configures its own `SubViewport`; only it uses a one-effect compositor.

The trace repeatedly records slot 6 followed by slot 0 in the same camera draw. `camera_effects.gd:14-20` inserts a non-final effect before the one marked `native_final_color`; `native_gamma_effect.gd:72` sets that marker, while `particle_stream_effect.gd` does not. `RendererCompositorStorage::compositor_get_compositor_effects` retains vector order (`compositor_storage.cpp:177-192`), and `renderer_scene_render_rd.cpp:300-330` invokes callbacks in that order. The separate 8-call slot 5 matches the icon-only viewport. Both the gamma and shared stream were reported active in `reports/nwn71-compositor-callback-v2.json`; the stream made 1,780 submissions but zero actual draws/uploads during this run.

The trace's `String(callback)` text was empty, so no direct callback-to-script string was captured. The assignment above rests on the RID allocation sequence, camera stack order, active effect report, and separate icon viewport. It would be overturned by an unrecorded production `CompositorEffect` created earlier than gamma or inserted into the same camera stack; the frozen project search found only gamma, shared particle stream, and icon draw fence production effect classes.

## Implication for the stalled frame

The 34.9897 ms slot-0 event is its first captured callback; the next-longest slot-0 event is 0.1379 ms and its p99 is 0.1096 ms. `native_gamma_effect.gd:146-154` calls `prepare(tonal)` from the callback, and `prepare_tone` at lines 124-144 compiles two compute shaders and creates two pipelines on first use. This is a **first-use preparation candidate**, not evidence of a 35 ms steady-state gamma cost. The older 71.7 ms compositor-zone stall was in a different source/build trace and cannot be assigned to this exact first-use event from these data. A matched original-entry trace with an engine compatible with `NwnLightHistory` is still required to attribute that historical stall and validate any fix.

