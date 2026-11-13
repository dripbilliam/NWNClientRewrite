# NWN-74 static vertex-array cache checkpoint

## Source and scope

- Accepted Forward+ source and accepted executable remain unchanged. Private source: `.cache/nwn74/source-vertex-cache-i.cpp`, SHA-256 `05b7e8379000b331fbb26dedc9577b594eca7d09d7ea7872cbc54078b3837e74`.
- Private engine: `.cache/nwn74/engine-build-i-cache/Godot_nwn74_vertex_cache_i_win64.exe`, SHA-256 `3d0e9e6ed669c0c936405332b6e576031a3b65adfaec10494308edc71c05fca7`. Receipt: `.cache/nwn74/engine-build-i-cache/receipt.json`.
- It uses an opt-in 8,192-slot direct-mapped cache keyed by static mesh-surface pointer, input mask, motion-vector flag and point-size flag. Slots expire each rasterizer frame. Collisions cause the original lookup. Mesh instances with dynamic vertex buffers always take the original path. Cache-off calls the original function.
- The original `MeshStorage::mesh_surface_get_vertex_arrays_and_format` locks each surface and scans up to approximately four versions before returning an array RID and format (`mesh_storage.h:511-540`). A successful cache hit skips that lock and scan, plus the underlying call.

## Evidence

- The original-scene observer counted 3,054 vertex lookups per settled frame: 3,043 static, 11 dynamic, and 1,759 duplicate static keys. Evidence: `.cache/nwn74/vertex-census-h/receipt.json` and `reports/nwn74-vertex-census-h.json`.
- Private cache count-only replay found 206,760 hits in each of the last three 120-frame periods: **1,723 static lookups skipped per frame**, or 56.6% of all lookups. The 36-hit gap from ideal reuse is from direct-map collisions. The remaining static path executes approximately 1,320 calls/frame. Evidence: `.cache/nwn74/vertex-cache-i/receipt.json` and `reports/nwn74-vertex-cache-i.json`.
- The same small Vulkan Forward+ fixture with cache off/on passed and generated identical raw red and green pixel hashes across the two modes: red `66271bad39816657165a6c00594d95fbd9308d1d15aba5378e2497d1f9d35383`, green `b9bf79bd926618e19258eb5f6f53496c209f2287c4dec157f137fa755774f5b5`. Reports: `.cache/nwn74/vertex-cache-fixture-i/off.json` and `on.json`. A third run of the prior private guard engine under the **same current fixture invocation** also matched both hashes (`control-f/control-f.json`). Older fixture hashes differed because of changed surrounding invocation/runtime conditions, so compare only matched invocations.
- Build dry-run and actual compilation both touched exactly one Forward+ translation unit with `-j2`. Compiler peak working set was 4.11 GiB, disk minimum 23.75 GiB, accepted binary hash unchanged.
- Raw replay diagnostics report `Native engine/lifetime diagnostics observed` in both prior observer and cache runs. Source and runtime hashes remained unchanged; treat this as diagnostic evidence, not strict replay acceptance.

## FPS decision

The coordinator completed the pinned same-engine ABBA normal-client pair with cache off/on, 15 seconds steady per leg, profiling off. OFF averaged 8.2541 ms/frame; ON averaged 8.2188 ms/frame, a 0.0353 ms apparent improvement. Adjacent comparisons reversed direction (−0.1130 and +0.0424 ms for ON minus OFF), so there is no repeatable FPS gain. Keep the cache private and opt-in. See `tools/nwn74/vertex-cache-fps-review.md` and `reports/nwn74-vertex-cache-pair-summary.json`. The accepted material-used guard had no repeatable FPS gain in its own ABBA pair and remains a separate source change.
