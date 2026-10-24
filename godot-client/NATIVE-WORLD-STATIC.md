# Direct native captured-world assembly

The captured `udcityhubint` room now assembles directly in Godot from original
raw assets: **48/48 terrain placements and 889/889 static object entries**,
including doors, their available mesh geometry, area atmosphere and model lights.
The inspection camera and FPS overlay are native. Run `./godot-client/native-world.ps1`.
This is an offline captured-world entry, not the multiplayer game launcher.

No Node/Electron/Three renderer, JS asset preparation, GLB import/export or base64
scene transfer participates in this entry. A separately generated private fixture
contains decoded protocol state only; it selects no model resources and prepares
no rendering data. Native code selects models from original tables, resolves
original textures and constructs the scene. The V8 event format and fully native
protocol runtime remain separate migration work.

## Implemented

- Native raw area packet → original SET → tile model/height/quarter-turn rules.
- Native static placeable and door table lookup, raw pose conversion, bounded
  worker preparation, shared native resource templates and incremental publication.
- Original ASCII and binary MDL meshes; original bitmap decoding and persistent
  content caches. Cache revision 3 includes newly decoded light/properties data.
- Native area color/fog/clock state and original model light color, radius,
  multiplier and flags. Godot attenuation/shadow rendering differs from the
  legacy shader; ambient-only, flares, fades and animated light curves remain open.
  The capture's one-point-shadow budget is preserved. All 186 model-light nodes
  are retained, including disabled lights; this is not 186 active shadow maps.
- Explicit missing-texture handling: the original capture records `sam-material`
  as unavailable. That door keeps its untextured material and reports a warning.
  Unrecorded lookups remain errors; no bitmap is invented or silently substituted.
- Native worker draining, scene/resource retirement and debugger verification.

The normal terrain owner is the default. The mesh-only batching experiment is
disabled by default and rejects active model lights instead of silently losing
them. Further performance experiments are deferred per the user's instruction.

## Evidence

`reports/native-capture-world-v3.json` and `v4.json`, with their `.verification.json`
and screenshots, render every terrain/static entry with no preparation errors.
Both CDB runs are armed and finish without a trapped exception or engine/lifetime
error. V4 also covers the cache-publication fix. Source hashes cover the actual
entry, launcher and native systems. Earlier V1/V2 failed reports are retained:
an emitter's `render Normal` string had been mistaken for a numeric mesh flag.

`native-ascii-model-v4.json` passes 548 original-model and authored compatibility
checks. `native-installed-model-v5.json` passes 199 original binary checks.
`native-capture-catalog-v3.json` passes 23 resource/miss/checksum checks.
`native-prepared-cache-v3.json` passes 15 integrity/concurrency checks after
serializing final cache repair/publication and waiting for genuine worker
completion in its probe. The failed V2 cache run is retained.

## Still incomplete

Eight render-eligible creatures and one ground item remain deferred. Equipment,
skinning/animation, emitters/effects, dynamic door and light behavior, server visual
overrides, visibility/picking/collision and gameplay/UI integration are not yet
accepted in this entry. Static object roots do not imply their effects render.
World/migration completion flags remain false. The normal multiplayer launcher
still uses the transitional JS preparation path.

The separate legacy frozen-GLB profile trapped a native AV; these two clean native
world runs do not establish its root cause or resolve historical shutdown faults.
No public server was contacted. No FPS/performance acceptance is claimed from
this incomplete workload or its on-screen counter. Current priority is complete
game rendering, followed by further efficiency work.
