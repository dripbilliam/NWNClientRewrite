# Original captured assets rendered natively

Current user priority: get the complete game world rendering. Further performance
experiments are deferred; keep reasonable resource reuse and bounded work while
finishing terrain, creatures, equipment, lighting and effects. The goal to remove
JS from rendering remains active. No public server connections are authorized.

`systems/native_data/capture_catalog.gd` reads original raw assets directly from
the sealed private capture and its frozen supplement. Event and resource hashes,
payload sizes, context identity and supplement parent checksums are verified.
Original recorded misses and texture choices remain authoritative. There is no
installed/network fallback, Node/Electron lookup, JS geometry or GLB transfer in
this resource path. V8 timeline decoding and complete world assembly are separate.
The capture has 491 recorded model resources and the original `twc03` tileset.

`ascii_model.gd` adds original ASCII MDL hierarchy, axis-angle poses, face-corner
geometry/UVs/normals and separate material groups alongside binary MDL. Static
model worker jobs select the original format automatically. Collision-only and
authored non-rendering meshes retain their CPU data without requiring unused
bitmaps or creating display resources. The original WOK's `Obscuring` bitmap was
the demonstrated blocker; its node is an invisible AABB walkmesh.

## Functional evidence

- `reports/native-capture-catalog-v2.json`: 22 raw-capture checks, including the
  actual sealed capture/supplement, checksums, original misses, texture choices,
  zero bytes, corrupt objects and independent reader state. Failed v1 retained.
- `reports/native-ascii-model-v2.json`: 546 original-model comparisons, including
  geometry/UV hashes, parent relationships and normal directions at 1e-4. Actual
  originals have 48/22 physical nodes. Failed v1 WOK test retained and corrected
  to check independent invisible collision geometry.
- `reports/native-capture-model-render-v2.json` / `.debugger.json`: 14 actual
  Vulkan checks. `twc03_a01_03` renders 44 visible mesh parts with five original
  textures; `twc03_a01_02` renders 18 with seven textures. Screenshots retained.
  Native workers and rendering use no JS/Three/glTF. CDB armed; no exception,
  engine error or lifetime warning. Failed v1 texture-dependency run retained.
- `reports/native-data-v7.json` (80), `native-installed-model-v4.json` (199) and
  `native-direct-render-v6.json` / `.debugger.json` (153) preserve archive/worker,
  original binary-model and GPU raster/model behavior after adding ASCII support.

These are functional asset-rendering checks, not full-world, lighting, animation,
gameplay or performance acceptance. The multiplayer launcher still uses its old
JS preparation path. ASCII skin/animation/light/emitter/reference behavior, full
materials, PLT and remaining formats/content mounts still need implementation.

The separate frozen-room diagnostic `captured-render-profile-v1` loaded all 898
objects/4145 meshes but trapped a native c0000005 before a completed report.
Its debugger failure remains recorded; it produced no accepted performance
result and does not establish a cause or a fix for the historical native AV.
No further performance experiments are scheduled under the current priority.

Next: native area assembly from raw area packets and captured SET/MDL assets,
then actors/equipment and existing native lighting/effect/animation owners. Keep
full-world rendering and usable gameplay as the acceptance target.
