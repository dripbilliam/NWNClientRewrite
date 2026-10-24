# Particle and camera performance — 2026-10-21

Only offline fixtures and the owned Prelude server at127.0.0.1:5121 were used.
No public-server connection, chat, gameplay input or original process control.
The broader performance goal remains active.

## Measured particle work

`scripts/benchmark-particle-presentation.mjs` builds80 authored emitters under
20 model hierarchies, all using the production CPU particle pipeline. It runs
150 deterministic warmup frames, then120 sampled frames with a moving camera
and a rotating parent. Final workload:9,760 particles /58,560 vertices. This
uses no installed/proprietary assets. The profile identified vertex generation,
movement, allocation/GC and upload conversion as the main costs.

Production changes:

- `nativeFastRsqrt` reuses one synchronous scalar bit-cast buffer per JS module
  instance instead of allocating a new ArrayBuffer/DataView per scalar call.
  There are no asynchronous callbacks inside the cast; workers each have their
  own module instance. The verified native f32 operations are unchanged.
- Particle vertex generation computes only required quaternion axes. The
  common zero-spin path caches the results of the existing native operations
  within that emitter draw, separately for positive/negative zero. Stopped,
  splat and custom sine/cosine-provider paths retain individual evaluation.
- Upload conversion uses direct attribute-array writes rather than allocating
  a Uint8Array view for every vertex. Buffer update ranges cover active vertices
  rather than the full spare capacity. Positions, UVs and normalized RGBA stay
  byte-for-byte compatible with the previous conversion.

| CPU particle fixture | Before | Current |
|---|---:|---:|
| Mean update |19.59 ms|13.48 ms|
| p95 update |21.25 ms|14.72 ms|

Final vertex/state SHA256 matches across baseline, scalar/upload and axis-cache
runs: `655dda1ddb50654339a0ae6f4d2cb133b581f4045630311a56e900f661808ce1`.
Reports/profile files: `particle-presentation-baseline`, `-scalar`, `-axes`.
These are component timings, not whole-game FPS. The original baseline report
hashes the presentation module only; subsequent script versions also record
the math/vertex/helper hashes. No retrospective source-hash claim is made.

## Camera / particle-collision broad phase

`cameraSceneQuery` previously transformed/tested every static face on every
query. It now caches geometry bounds from **original native hit faces**, not
reconstructed visible draw geometry, plus inverse/world bounds for each current
mesh pose. A segment outside conservative bounds skips the exact polygon test;
all remaining tests use the same native f32 kernel in the same order.

Only well-conditioned, consistent triangular planes can be filtered. Uncertain
planes, slivers and non-triangular/nonplanar polygons remain unfiltered. Bounds
include a conservative32-float-ULP-scale margin; this is a broad-phase margin,
not a changed native polygon edge/distance tolerance. Replacing a source face
array or geometry invalidates the cache automatically; `query.invalidate`
supports an editor changing immutable source-face data in place.

Authored1,500-mesh /48,000-triangle camera benchmark:

| CPU query | Before | Current |
|---|---:|---:|
| Mean |2.72 ms|0.25 ms|
| p95 |3.28 ms|0.37 ms|

All120 crossing positions/normals match exactly. A final query rejects1,468
distant meshes and416 faces, and performs608 exact face tests. Additional
tests compare first-hit, nearest and normal queries over600 deterministic
segments with changing rotations, negative scales, geometry and source lists.
The broad phase rejects none of the recorded original polygon crossings;
the existing1,876-case native kernel oracle still passes. Collision queries
also serve bouncing particles, so their existing regression is included.

## Dense rendering / prior light-slot change

`scripts/benchmark-heavy-renderer.cjs` and its fixture use1,501 authored meshes,
48,002 main triangles,63 actual point lights and512² point-shadow maps at
3440×1369. Installed native keyhole and targeting shaders are read in place,
never copied into the workspace. HTTP is blocked. Measurements use the real
production unrolled light path and changing caster poses.

Same fixture with the recorded legacy193-slot profile versus current64 slots:

| Renderer measurement |193 slots|64 slots|
|---|---:|---:|
| Shader preparation |6,039.6 ms|2,385.3 ms|
| p95 CPU/driver frame work |10.9 ms|9.8 ms|

Both images have SHA256
`52de7a8c58cf1fd0c31e4e77a2fabaf98b5bd484bae1ae41e87d2d3a63d98c19`.
Real lights, casters, draw counts and shadow triangles match:1,501 main draws,
711 shadow draws,15 admitted shadow lights with11 reused /4 drawn. Fewer
neutral nodes reduce traversal visits, as expected. Hardware reports RTX5070Ti
via ANGLE D3D11. Driver-cache state is uncontrolled; these are single successive
runs and not proof of the complete original-game performance gap closing.

The earlier `heavy-renderer-native-legacy` report accidentally enabled the
already-disconnected compact-loop experiment. It is retained as experimental
evidence, **not** the production comparison. It reproduced multi-second stalls
with sampled stacks in uniform uploads, consistent with the earlier recorded
reason for leaving that experiment disabled. Production comparison reports
are explicitly `native-legacy-unrolled` and `native-current`, both
`compactLoops:false`. The plain `baseline` fixture also enabled that experiment
and is not used for production improvement claims.

## Validation / local run

`particle-camera-regression-v1.txt`:49 passed, one installed-resource test
skipped by sandbox availability. The complete installed native polygon file
was rerun with read-only access:6/6 pass, no skips
(`camera-query-installed-native-v1.txt`). This includes245 original native
particle streams plus14 additional mixed-zero-spin/splat/mode comparisons,
packed upload values/ranges, frame/movement/path-grid and camera checks.

Build `index-ePPCFyNh.js` passes. Local production report
`particle-camera-local-v1.json` loads the starting room and100-tile /92-object
academy, controlled player rendered, zero reported asset/worker/renderer
failures, and no pending preparation at sampling time. At3440×1369, excluding
two seconds after resize, median sampled FPS96.82 and median sampled p95
12.4 ms. Transition request to all prepared9.63 seconds, versus8.97 seconds in
the preceding single run: **no loading improvement is claimed for this patch**.
The vanilla area has far fewer active particles than the dense CPU fixture.

The local probe successfully awaited disconnect and saved its report, then
Electron did not terminate. Its verified owned PID22512 was stopped after
completion; the harness exited-1 on that cleanup. It is not counted as a clean
process exit. The probe now explicitly exits after awaited disconnect/report
write, as other isolated fixtures do; that harness-only change was not rerun
and is not credited as a measured improvement.

`scripts/verify-particle-camera-performance.mjs` checks the measurements/output
invariants and writes `particle-camera-performance-proof-v1.json`. It verifies
component outputs and local regression, not completion of the broader goal.

## Next work

Follow-up: the shutdown exception was subsequently reproduced in real Electron
and fixed in the debug owner's `closed` handler, which accessed destroyed
webContents. Changing only the harness exit was insufficient. See
`source-prefetch-performance.md` for the before/after exception proof, two more
local measurements and the combined dense workload; goal remains active.

Combine the dense particle and renderer workloads and profile frame scheduling.
Evaluate persistent worker ownership for suitable CPU visual work, preserving
emitter order, RNG, atlas clocks, collision and area cancellation. Overlap
independent object resources without delaying controlled-player admission.
Shader warmup and the remaining multi-second preparation waits are still open.
