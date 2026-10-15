# Starting-area geometry, movement seams and polling diagnostics

Target: NWN:EE 89.8193.37-17, PE64 SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Installed data and Ghidra project were read only. No campaign-specific runtime
branches, changed object IDs, collision bypasses or copied game assets.

## Observed failures and native evidence

The user's Prelude m0q1a session rendered nine tiles with zero final missing
textures, models or walkmeshes. Nevertheless the left bedroom tiles had visible
floor/furniture/wall gaps. Binary `tic01_e01_01` retained original MaxFace lists
alongside optimized combined vertices and separate draw-index buffers. For
example Object49 had 79 vertices, 12 original faces and 123 draw indices (41
triangles). Reading only original faces omitted the joined geometry.

Ghidra `FUN_14007abe0` dispatches to mesh reader `FUN_14007be10` (PE call sites
`0x14007ac6a`, `0x14007b04f`, `0x14007b692`). Its draw counts come from serialized
node +0x204; raw-index offsets from +0x210, array length +0x214. The copy at
`0x14007c386..0x14007c397` populates runtime +0x258; allocation at
`0x14007c3dd` uses count*2 and copy at `0x14007c411` reads those unsigned-short
indices from raw data. The MaxFace array is loaded separately. Inference from
this data flow, confirmed by installed geometry coverage: rendering must consume
the actual draw groups. Parser now reads every triangle-list draw group and
checks count, bounds and indices; original-face fallback covers older records
without draw groups. Other primitive modes remain explicitly unsupported.

The movement viewer separately used trigonometric, double-precision WOK
transforms. Exporter offsets left narrow cracks at adjacent tile boundaries
(around native Y=20 in the user's room). Simulation's previously reconstructed
loader already implements `CNWTileSurfaceMesh::LoadWalkMesh` `0x1402c1020`
vertex snapping and f32 transforms, and CNWTile quarter-turn helpers
`0x1402c57d0/0x1402c56a0`. Area movement now uses those implementations too,
including physical surfacemat row indices and nonzero Walk integer semantics.
The local route planner and player capsule checks remain replacement algorithms;
this does not establish full native pathfinding parity.

Raw read-only captures: `backups/animations/ghidra-wok-seam-loader.txt`,
`ghidra-binary-mesh-reader.txt`, `ghidra-binary-node-copy.txt`,
`native-world-draw-buffer-asm.txt`. The PE inspector captured both unwind-bounded
dispatcher/reader functions; asking it for the separate leaf copy helper failed
because that helper has no unwind entry. Its field copies were inspected in
Ghidra instead; no guessed leaf range was used.

## Diagnostic recording

The user's log contained 1,484,387 occurrences each of trap-check and frame-stat
refresh omissions, plus 197,593 per-object dialog update omissions. These are
known polling gaps, not new exceptions on every frame. They now record the first
occurrence immediately and retain per-context total/delta counts and first/last
timestamps, flushed every ten seconds and on close/export. Ordinary engine calls,
script executions and load failures remain individual records. This reduces log
volume without claiming the underlying trap/refresh/dialog owners are finished.

Other observed outstanding entries include SpeakOneLinerConversation from the
authored Pavel script, missing `script1.ncs`, missing `plc_w02.pwk` in another
area, binary light/emitter payloads, optional portraits and an HP snapshot
comparison. Those were not the cause of the repaired geometry seam and have not
been declared resolved by this change.

## Validation

- 1,286 tests and production build pass. New regressions cover combined draw
  groups vs MaxFaces, bad indices/truncated buffers, all four snapped tile
  orientations, physical surface rows and both movement/planner seam crossing,
  and durable polling counts without deduplicating separate script calls.
- Installed m0q1a floor coverage: 324 uncovered sample points before; zero after.
  The affected tile's rendered triangle count changes from 161 to 431. Other
  tile counts remain consistent. `scripts/probe-area-render-coverage.mjs` reads
  installed resources directly and outputs measurements, not extracted assets.
- Electron keyboard test starts at [15,0,-19], crosses to
  [15,0,-21.233920000004773], and returns to [15,0,-18.775040000009536]. It uses
  normal keyboard controls and collision checks, with a test-only in-memory
  entry-point override and startup disabled. 46,210 trap-check occurrences are
  represented within 794 total diagnostic records. This is not a full campaign
  or script interaction acceptance test.
- Installed animation smoke passes across eleven door, tile, placeable and
  creature models, including skinned magetail. Existing reported unbound human
  skeleton helper tracks remain explicit.
- Screenshots inspected: `prelude-library-restored.png` and
  `prelude-world-geometry-fixed.png` under `backups/animations`. These captures
  use the labeled manual preview sun; native binary lighting remains incomplete.

The user's persistent character vault is `backups/character-play-profile`.
