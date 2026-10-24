# Fully native Godot migration

The user's latest instruction supersedes the earlier permission to retain a JS
runtime backend as the final architecture: **Godot is to do everything
natively.** GDScript and native Godot extensions may own the implementation.
JS remains useful for offline reference tests and the preserved comparison
client; it is not a dependency of the intended game executable.

The running game is still the transitional client. No default launcher has
been switched to an incomplete native implementation. Its JS networking,
resource/scene preparation and particle workers have **not** been removed.
This milestone does not improve its current loading time yet.

A separate [native model/raster entry](NATIVE-DIRECT-RENDER.md) now has persistent
preparation caches, shared GPU resources and debugger-protected Vulkan evidence.
Its reports supersede the foundation source pins below. Multiplayer still uses
the old preparation path; full-area and moving-world migration remain open.

## Native resource foundation implemented

Production source lives in `systems/native_data/`:

- `binary_data.gd`: bounded little-endian fields and CP1252 text. Large text
  conversion uses engine string operations rather than per-character appends.
- `archive_index.gd`: file-backed KEY/BIF and ERF/MOD/HAK indexes, both supported
  versions and ERF 24/40-byte key layouts. Only requested payloads are read.
  Changed-file stamps, count/range/type checks and KEY path traversal rejection
  prevent using an invalid index. Zero-length resources still exist.
- `resource_catalog.gd`: explicit ordered mounts, case-insensitive presence,
  separate KEY-local BIF slots, lazy BIF index caches and session retirement.
  Installed base/retail/localization use the existing 1M/2M/3M priority rules
  documented in `src/resource_archive.js` from native registration
  `0x1401947b0`, insertion `0x14018e330`, lookup `0x14018ffb0`.
- `gff_document.gd`: all 19 field formats, lists/structs/localized strings,
  separate field/struct metadata, section bounds and depth/cycle checks.
  Signed 64-bit fields remain native integers. Unsigned 64-bit values retain
  exact low/high words; rules/math/string consumers still need that typed
  representation ported, rather than converting them to doubles.
- `two_da.gd`: quoted cells, defaults, duplicate column names and physical row
  order distinct from printed row labels.
- `binary_model.gd`: original binary MDL physical hierarchy, static P/Q/scale,
  alpha/self-illumination controllers, original vertex/normal/UV streams,
  texture names, optimized draw lists and independent collision triangle lists.
  Behavior-dependent node kinds are explicitly recorded as pending; this does
  **not** accept animations, skin deformation, light/emitter/reference behavior,
  ASCII MDL, complete material semantics or native scene creation.
- `asset_service.gd`: bounded native WorkerThreadPool reads/decodes, independent
  file handles and lazy BIF caches per worker, main-thread result delivery,
  generation retirement and actual task draining. No scene/server identity is
  created by a data worker. Bytes/GFF/2DA/binary-MDL decoders are connected.

All of these paths run without Electron, Node, Three, GLB or base64. They are
not yet wired into the existing live area's GLB replacement.

## Verification

`reports/native-data-v5.json` validates authored versioned archives and GFF/
tables against existing offline JS parsers, ordered overrides, unused payload
avoidance, missing/zero resources, malformed inputs, modified archives and
KEY/BIF type mismatches. Twelve actual native worker GFF decodes, retired-scope
discard, subsequent table decode and task draining are exercised.

`reports/native-installed-model-v2.json` passes **199 checks** using the
installed originals read-only. Five resource byte hashes agree, an actual
4.46MB visualeffects table and an item GFF parse, and `c_golstone` physical
hierarchy/static-controller/vertex/normal/UV/render-index/collision-index
hashes agree with `src/binary_mdl.js`. A real native worker loads/decodes the
original model and drains cleanly. Truncated/cyclic/count/flag variants are
mutated only in memory and rejected. Reports retain hashes/counts, not original
asset payloads. No original game binary is executed or modified by these tests.

These are headless correctness and data-loading checks, not GPU benchmarks,
complete-world scene acceptance or sustained FPS evidence. The existing native
shutdown access violation remains unresolved; unrelated later passes cannot
establish that it is fixed. Public tests remain user-directed.

## Remaining conversion order

1. Native original texture formats/materials, complete MDL/animation/reference/
   skin data, tileset/area definitions, reusable model/texture resource caches
   and direct Godot scene assembly. Remove whole-area GLB/base64 conversion.
   Publish scenes/textures on the main thread from bounded worker results.
2. Native install/content/Workshop/override precedence and NWSync manifests,
   downloads, SQLite stores, verification, scoped mount/unmount and persistence.
   Content hashes must invalidate reusable resources when actual bytes change.
3. Native encrypted UDP/login/session protocol, replication, server browser,
   character vault/creation, movement/collision/pathing and cross-server transfer.
   Preserve existing packet/original-client oracles and owned-local scenarios.
4. Replace JS gameplay/UI-data services: inventory/stores/character/spellbooks,
   level-up, rich text, all NUI bindings/events/layout, combat/targeting, effects,
   native particle simulation, audio selection and settings/Windows-protected
   credentials. Existing native controls/render owners are retained and adapted.
5. Port remaining offline rules/scripts/actions/saves/campaign systems. Run the
   full feature ledger, repeated moving local/captured scenes, resource cleanup,
   fidelity and sustained performance acceptance before retiring the bridge.

The full migration baseline remains 866 modules and 747 test files. New native
counterparts annotate that baseline; no existing feature is dropped merely
because its native replacement is not yet implemented.
