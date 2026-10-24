# Direct native original-resource rendering

`./godot-client/native-model.ps1` starts pinned Godot directly, reads installed
KEY/BIF resources, decodes original binary MDL and rasters on bounded workers,
and publishes shared native mesh/texture/material resources on the main thread.
No Node, Electron, Three, GLB or base64 scene conversion participates.

This is a separate static-model entry. The normal multiplayer launcher still
uses JS preparation. The rendering-removal goal remains active.

Prepared data is addressed by original-content hash, decoder revision and engine
identity, with integrity-checked atomic files outside the workspace. Instances
have private transforms and share immutable resources. Retirement drains workers.

## Evidence

- `native-data-v6.json`: 80 archive/worker checks, including one shared BIF
  index build for twelve concurrent jobs, independent payload handles and cleanup.
- `native-installed-model-v3.json`: 199 original-resource, hierarchy, vertex,
  normal, UV and render/collision-index comparisons.
- `native-texture-data-v2.json`: 369 checks over 66 authored DDS/TGA/KTX cases.
  This does not cover every implemented raster format.
- `native-prepared-cache-v1.json`: 15 typed-data, invalidation, corruption,
  concurrent atomic-write and external-storage checks.
- `native-direct-render-v5.json` and `.debugger.json`: 153 Vulkan checks for
  original stone-golem rendering, raster upload round-trips, source UV/winding,
  resource sharing and retirement. CDB armed, no trapped exception or engine/
  lifetime errors. Failed v1–v3 runs are retained.
- `native-model-entry-v2.json` and `.verification.json`: actual launcher,
  warm cached original model, 90 frames, source hashes and clean task/engine exit.

Reports live under `reports/`. Isolated v5 model preparation measured 53.177 ms
cold and 9.926 ms warm. Sharing BIF indexes and avoiding repeated file-length
queries removed a measured 2.34-second warm-path regression. These are single
model costs; installation indexing, publication and complete-area loading are
separate. The editor was preserved, so these are functional tests, not clean GPU
benchmarks or full-world FPS evidence. No public server was contacted.

## Remaining work

Native areas; animation, skinning, equipment, references and emitters; complete
material/TXI semantics; ASCII MDL, PLT and remaining formats; native loose/
Workshop/override/NWSync mounts; multiplayer render integration; full moving
local/captured world and >=60 FPS acceptance. Incomplete mip chains currently
fail publication explicitly. ETC1 uses native CPU decompression on unsupported
desktop GPUs. Missing originals fail without substitutes.

The historical shutdown access violation is unresolved; these clean smaller
runs do not establish a fix. The prior accepted rollback remains unchanged.

For a bounded test use `-CaptureCrash -Frames 90 -Report <unused-absolute-path>`.
Existing user game/editor sessions are preserved.
