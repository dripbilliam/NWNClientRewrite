# NWN-71 private sync-owner clock checkpoint

Status: diagnostic only; ticket remains In Progress. No accepted engine/client source was edited and no FPS comparison was made.

## Source and run identity

- Four translation units were clock-instrumented in a private engine copy. The probe source receipt is `.cache/nwn71/sync-owner-clock-a/source-receipt.json` (SHA-256 `18616d3a608a81baf2d65192376dc4eb222d9b34bf916bb0cdec9c9a864cc729`); private engine SHA-256 `32cea75ad505e774df16ae25c971f849515396f68c145ab83ec5ee62525744e5`. The build receipt verifies the private sources, objects, binary and SCons state were restored after the binary copy, and the accepted sources/binary were unchanged.
- One bounded offline original-asset generation-2 replay produced `reports/nwn71-sync-owner-clock-a.engine.log` (SHA-256 `21f1f3862da64c125791609fb5ec5f4f1bf6a731c0cc63efe2a9914a0a757fee`). Run receipt: `.cache/nwn71/sync-owner-clock-a/run-receipt.json`; peak private memory 6.80 GB. The replay report reached its steady window, but its overall `success` is false due to native engine/lifetime diagnostics. Therefore this is a diagnostic sample, not client acceptance.
- `tools/nwn71/correlate-sync-owner-clock.cjs` verifies the log and binary hashes, parses 195 rows, checks interval arithmetic and exact overlap, and writes `.cache/nwn71/sync-owner-clock-a/correlation.json` (SHA-256 `2d42d8b5491a1cafa58adad90a91884df82a55014b71affc5436ea7392299609`). Overlap is measured by union within a parent interval; overlapping rows are never added blindly.

## What the clocks establish

The private source clocks `RenderingServerDefault::sync()` at `rendering_server_default.cpp:478`, render `_draw` at line 96, queue `flush_all()` at line 462, and render-thread `yield()` at line 461. Group-join clocks are at `shader_rd.cpp:745–747` and `renderer_scene_cull.cpp:3425–3427,3535–3537`. The Vulkan device probe covers the single `vkWaitForFences` call at `rendering_device_driver_vulkan.cpp:3055–3057`. Logs are emitted only above 20 ms for main/render/queue clocks, 2 ms for group joins, and 1 ms for that fence call.

| Observation in this offline replay | Exact result |
| --- | ---: |
| Main sync intervals at or above 20 ms | **0** |
| Render draws at or above 20 ms | 30; maximum 641.382 ms |
| Named group joins at or above 2 ms | 100 shader, 1 scene cull, 0 visibility cull |
| Vulkan fence waits at or above 1 ms | 13; maximum 3.593 ms |
| Draws with named joins covering at least half the draw | 20/30 |
| Draws with no named join overlap | 5/30 |

- A 39.240 ms render draw at clock 14.819140–14.858380 s contains 35.037 ms in `SceneForwardClusteredShaderRD` group 3282. A 94.948 ms draw at 6.985853–7.080801 s contains 75.342 ms across the same shader's groups 660 and 668. These establish shader variant group joins as a substantial owner of **some offline render-thread intervals**. The initial 1,211.026 ms queue flush contains 751.255 ms of named shader group joins, including first-use shader families.
- The largest 641.382 ms draw at 7.972049–8.613431 s has **zero** intersection with a logged group join or Vulkan fence wait. A 194.889 ms draw has only 5.883 ms of named shader wait. Those bodies are unresolved by this probe. A nearby or earlier fence is not evidence that it caused the draw.
- Long `render_yield` spans are scheduler waits, not measured CPU work. The two ~1.19 s yield spans cannot be assigned to an active render task or a main-thread sync in this run.

## Bounded conclusion and next gate

This offline replay did **not** reproduce a main-thread sync above 20 ms. Consequently it cannot assign the saved Arelith 50–70 ms main sync tails to shader compilation, scene culling, GPU fences or any other producer. The saved live Tracy checkpoint `tools/nwn71/new-live-sync-checkpoint.md` still shows 35.775/40.975 ms overlaps with unlabeled render group waits in two long syncs, and separate long draw bodies with no retained group wait. The offline result makes shader joins a plausible mechanism for the first family, but it is not causal proof in those live captures.

For the next exclusive live capture, retain the same join-site labels and emit exact group IDs plus producer task IDs in the engine running the matched Arelith route. Add a bounded nested phase clock for the unresolved draw body, including device calls beyond `vkWaitForFences`. Correlate each live main sync to the render draw and exact group/task or device interval before proposing a production change. No fix or FPS claim is justified from this offline probe alone.
