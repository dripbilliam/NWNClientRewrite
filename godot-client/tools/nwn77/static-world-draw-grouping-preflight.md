# NWN-77 static world draw grouping preflight

Status: **correctness preflight passed; performance acceptance open**. This is a read-only review of the current optional static scenery paths, plus isolated fixture runs. No normal-client FPS benchmark was run, and no default changed.

## Current route

- `AreaStream.static_scenery_mode` selects `individual` by default, `batched` with `--static-scenery=batched`, or `merged` with `--static-scenery=merged` (`systems/native_render/area_stream.gd:72`, `:100-101`). Both optional owners preserve the original model, material, light and collision owners. A successful replacement suppresses only the source RenderingServer draw instance (`systems/native_render/static_scenery_batches.gd:151-154`, `:186-190`). Unsupported surfaces retain individual drawing with a reason count.
- The separate `TerrainBatches` 4×4 tile route is not reachable in normal `LiveWorld` setup: `live_world.gd:326` sets `terrain.use_terrain_batches=false`; the `AreaStream` default is also false. Its visibility/overdraw and parity cannot be accepted from static scenery results.
- `static_scenery_merge.gd` inherits the conservative enrollment and withdrawal from `static_scenery_batches.gd`. The material-cell merge worker combines compatible immutable source streams; live draw publication occurs after the result's epoch/revision check. These are distinct from the unused `TerrainBatches` route.

## Current-source correctness checks

All three checks used the pinned private Godot executable SHA-256 `62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc`, copied their source closure into a private project, and reported zero source drift. Each engine exited 0. The existing wrapper's overall `success` is false because isolated user data caused only `ERROR: Failed to read the root certificate store.`; its assertions had no failures. Preserve that diagnostic rather than treating the wrapper as an unconditional pass.

| Check | Result | Receipt |
| --- | --- | --- |
| Headless same-mesh `MultiMesh` | 57 checks, 0 failures | `.cache/native-presentation-parity/static-scenery-agent/terrain-instancing-nwn77-headless-batch-v1/run.json` |
| Headless different-mesh merge | 46 checks, 0 failures | `.cache/native-presentation-parity/static-scenery-agent/terrain-instancing-nwn77-headless-merge-v1/run.json` |
| Vulkan Forward+ different-mesh merge | 52 checks, 0 failures; 640×360 individual/merged fixture images byte-identical; fixture draw count 9→1 | `.cache/native-presentation-parity/static-scenery-agent/terrain-instancing-nwn77-graphics-merge-v1/run.json` |

The graphical fixture shows three small authored surfaces, one light/shadow owner, source hit testing, event withdrawal and worker retirement. It does not prove appearance or draw savings for a dense Arelith area. The source closure in each receipt pins the exact test input. Current top-level hashes: `terrain_batches.gd` `54d1ae867a7a0f6e390749537de9906ad0e3cf0177eefc9d173c4b5916032506`; `static_scenery_batches.gd` `092a2b21b72fefb7b80d14b291b51b89b12fedeb100f13fd3b916160a41e2870`; `static_scenery_merge.gd` `b98c331f711b1d0d913bfcf812d4a980e0f4434c02a338977b0861ab48e4d262`.

## Historical matched replay, not current acceptance

The earlier private ABBA replay in `.cache/nwn74/base-merge-pair-a/matrix-review.json` used frozen source identity `f30c415a0a20c5e00c1bac265504b627dbe7be0d0c4cb522202002c58d0475a7`, private engine SHA-256 `35e47e75fb71dac4ae91140026d1b333988c1546e8033f86a8624702b12da64f`, the same generation-2 capture and 15-second steady windows. It changed **both** `--static-scenery=merged` and `--base-scenery-draw=merged` together. Off/on/on/off mean frame times were 11.46/11.33/11.17/11.42 ms; render-thread phases were 4.76/4.41/4.13/4.54 ms. Draw counters were about 2,250 off and 2,047 on. The combined opt-in therefore saved some render work but did not produce a large frame-time gain in that local replay. It cannot isolate terrain static scenery from BASE grouping, and the frozen code is older than the current source. All four runs had classified environment diagnostics; they are not live-server acceptance.

The on-run world report counted 2,479 terrain source surfaces: 1,086 enrolled, 933 actively replaced by 220 batches, and 1,393 rejected (818 authored render/tilefade, 529 emitter model, 46 blended material). It reported nominal terrain instance reduction 713, while the whole-scene measured draw decrease was only about 203 with BASE grouping also enabled. The smaller measured decrease is consistent with Godot already combining some draws; this replay does not identify the exact automatic-instancing share.

## Remaining acceptance

1. Run current-source **normal-client** off/on matched graphical scenes with identical camera, settings, resolution, engine and 3D content, after other ticket timing work is paused. Separate `--static-scenery=merged` from `--base-scenery-draw=merged` so each contribution is attributable. Record resident/visible instances, actual draws, material switches if an instrumented counter exists, render-thread CPU, GPU time and frame intervals.
2. Validate representative opaque, cutout, blended/fade, fog, light and shadow surfaces, picking/collision, animated/reference/effect tiles and area transition. Count rejected reasons and ensure each retains its original draw. The small fixture cannot substitute for this.
3. Keep the 4×4 `TerrainBatches` route unaccepted until owner wiring is intentionally enabled and its cell-level culling/overdraw is measured. It is not exercised by the static scenery flag.
4. Change the normal default only after a repeatable frame-time gain and the full visual/functional checks. Current evidence does not support promotion.
