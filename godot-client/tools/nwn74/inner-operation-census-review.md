# NWN-74 inner-operation census, dense replay

This is a read-only, source-pinned count pass over the existing 720 settled frames. Run `node tools/nwn74/inner-operation-census.cjs` to verify the seven source/capture hashes and regenerate `.cache/nwn74/inner-operation-census-a.json`. It launches no client, changes no engine, and measures no FPS. Script SHA-256: `c7dcb848ee14241150a1a254a027ce2541c99a6b5972b8d5fb1533639e6bbc35`; generated report SHA-256: `781349b9ceb7ac73b951976166383aa8153e3a9b7e7f6ccfc6187c08a87ca6cb`.

Independent root rerun on the restored baseline source passed all seven pins and reproduced the 720-frame counts and means below, exit 0. The private trait-hoist experiment is separate from this census.

| Stage | Observed work per settled frame | Existing inclusive phase mean |
| --- | ---: | ---: |
| Shadow preparation | 6 shadow passes; about 890 Forward+ shadow draws | 601.4 µs |
| RendererSceneCull geometry admission | 16,365 registered instances; 1,437 visible geometry records | 149.6 µs |
| Visibility-range cull | No active nonzero visibility bins in this scene | 0 µs |
| Rendering-device scene span | About 3,054 Forward+ direct draws: 1,253 color, 911 depth, 890 shadow; no indirect draws | 1,095.5 µs |

The spans overlap or include different work and must not be added. The shadow count is `max_shadows_used` (passes), not distinct lights. The shadow-preparation loop updates transforms, coverage, dirty state, atlas membership and per-pass instance lists. Their inputs can change with camera and light state. Geometry culling visits the registered set and admits a much smaller visible set. The visibility-range branch is absent here, so it cannot explain the current cost.

The Forward+ draw loop updates `push_constant.base_index` and emits one draw command per element. Existing counters show about 2,865 pipeline reuses, 747 material binds and 2,595 vertex-array binds within the 3,054 draws; earlier candidate work already examined those guards. The RenderingDevice draw path batches dirty descriptor sets and appends each draw to the command graph. No duplicate draw with identical state and required output is proven by this capture.

One idempotent inner lookup is visible in source: `RenderingDevice::draw_list_draw()` calls the Vulkan driver's `api_trait_get(API_TRAIT_HONORS_PIPELINE_BARRIERS)` inside its descriptor-slot loop. Vulkan falls through to a device-constant return value of `1`. The getter may run multiple times per draw, but the saved counters do not include the active set count or the getter's isolated cost. The 1.10 ms rendering-device scene span is an upper bound across many other operations, not evidence that this getter is expensive. Hoisting it is therefore a candidate for a private counter and timing gate, not a justified production change today.

**Conclusion:** No substantial repeated idempotent operation with both measured invocation count and isolated cost is established in these three stages. NWN-74 remains open. If prioritized, instrument only active descriptor slots and trait-call counts in a private RenderingDevice build, and compare its per-draw cost and command stream with the pinned replay before changing accepted source.
