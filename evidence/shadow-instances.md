# Shadow-only rigid caster batching — local performance work

2026-10-21. Performance goal remains **active**. This is replacement-renderer
engineering, not a claim about native engine internals or matched native FPS.
All network tests use the owned native servers at `127.0.0.1:5123` (authored
DensePerf) or `127.0.0.1:5121` (Prelude). No Arelith connection or input.

## Implementation and ownership

`src/renderer_shadow_instances.js` groups equivalent rigid, leaf shadow casters
into private `InstancedMesh` proxies. These proxies exist only in the temporary
shadow traversal scene. Main rendering, picking, labels, highlighting, keyhole
fading, animation hierarchies, source geometry and source materials retain
their existing owners. Production enables the adapter with at least twelve
vertex attributes. It does not move a shared WebGL context between workers.
The existing source and particle vertex worker pools remain active.

Geometry keys include exact position/UV/index data, draw range and layers.
Hashes select buckets; full byte comparisons establish equality. Palette
textures can share shadow output only when every alpha byte and all relevant
texture sampling/UV parameters match. RGB does not enter the stock alpha test.
Only immutable initial RGBA byte DataTextures use this alpha canonicalization;
other/dynamic textures retain exact identity. Mutable/deformed geometry,
skinning, morphs, negative transforms, custom shadow producers, material
arrays, clipping and displacement retain ordinary draws. VSM retains the
original traversal. Effective front/back shadow-side inversion is preserved.

Two supported `GLBufferAttribute` VBOs hold each group's world and exact
CPU-computed shadow model-view matrices. Each face retains the original
per-caster frustum tests. Explicit per-face COPY_WRITE_BUFFER uploads avoid
Three's ordinary once-per-frame attribute upload cache and preserve VAO
bindings. Empty faces upload nothing. Owned geometry/materials/VBOs retire on
group removal, area reset and context loss. They are released during context
loss, before Three installs a replacement attributes owner after restoration.
Strong geometry/alpha/member caches are area-owned and clear at reset.

The final revision computes grouping keys only for light caster lists whose
shadow maps actually need redrawing. Reused shadow maps avoid this scan.
Light planning and drawing keep their existing order. A frame-end prune
releases unused groups; area reset also clears all retained canonical data.

## Correctness and failure checks

`test/renderer-shadow-instances.test.js` and the related traversal, point-cache,
light, budget and retirement suites pass **30 tests**. These include exact
six-face float32 transforms, member frustum membership, source ownership,
alpha/UV/version/layer/draw-range changes, unsupported producer fallbacks,
partial VBO allocation failure, group retirement and skipped cached lights.
Allocation failure releases partially allocated buffers and retains ordinary
draws until reset. This is not a silent loss of geometry.

`scripts/probe-shadow-instances.cjs` runs the actual production adapter and
Three WebGL renderer against authored geometry. It blocks HTTP requests.
Forty moving poses/camera views include separate equivalent geometry copies,
different RGB palettes, alpha/UV changes, deformed and custom fallback cases,
negative/nonuniform scale, hidden/removed objects, secondary UVs, a directional
light, two point lights, and real context loss/restoration at frame twenty.

* All **40 final main images** and **80 point shadow atlases** are byte-identical
  between ordinary and grouped shadow rendering.
* Main draw counts, shadow triangles, shadow hook counts and source owners
  agree in all forty cases.
* Directional RGBA depth packing is **not bit-identical**. Decoded depth differs
  by at most `2^-24` (one float32 ULP), with zero changed coverage pixels and
  identical tested final main images. This is an explicit numerical limit.
* Context restoration succeeds with zero WebGL errors. Private VBOs are gone
  after disposal, source geometry was not disposed, and all cache/member
  counts are zero after reset.

Artifacts: `backups/animations/shadow-instances-v1.json/.png`, regression-v9,
run-v14, build-v6, and `shadow-instances-proof-v1.json`. The proof verifier
checks source hashes, raw output comparisons, loopback endpoints, movement,
render size, failures, worker retirement and GPU owner retirement. Earlier
rejected upload/depth/context experiments remain in the artifact directory;
they are not counted as passing tests. The ordinary-attribute prototype used
stale per-face matrices. The first context prototype deleted old registrations
too late and produced error1282. Both paths were corrected before acceptance.

## Dense native-server measurements

Same authored fixture as `dense-local-performance.md`: two100-tile areas,
48 wandering multipart NPCs,48 braziers and32 chests per area. Each run
traverses a→b→a, observes twenty seconds per area with six seconds of camera
rotation, captures renderer CPU profiles and uses3440×1369 pixels at1×.
The original proprietary assets are read from the existing installation;
asset bodies are not copied into this workspace.

Before grouping (`dense-local-v8.json`) versus the last eager-scan build
(`dense-local-v13.json`):

| Area visit | Before FPS | Grouped FPS | Before shadow draws | Grouped shadow draws | Before render ms | Grouped render ms |
|---|---:|---:|---:|---:|---:|---:|
| a |26.77|30.55|2203|328|23.1|18.2|
| b |30.46|34.23|1361|81|17.7|14.0|
| a return |30.81|33.18|1345|81|17.6|14.3|

Values are medians of sampled rolling performance windows, not individual
frame distributions. Shadow submissions fall85–94%; main submissions remain
about1850–1900. v13 reported frame p95 medians are36.9/32.9/34.0ms.
Area readiness is12.93/12.90/9.82seconds; this step primarily addresses steady
submission, while the preceding preparation batching reduced readiness from
18–23seconds to roughly10–14seconds. Wandering, visibility, shader caches and
profiling vary between runs. These sequential observations are not a matched
original-client comparison or a universal causal FPS ratio.

Final lazy-scan build `index-DGNFFs9Z.js` (`dense-local-v14.json`):

| Area visit | FPS | Reported p95 ms | Shadow draws | Main draws | Render ms | Ready seconds |
|---|---:|---:|---:|---:|---:|---:|
| a |30.44|36.7|338|1881|17.9|12.15|
| b |33.97|33.4|81|1856|14.0|13.05|
| a return |32.49|34.6|81|1858|14.5|10.15|

This preserves the dense submission reduction. `dense-local-v14-cpu-summary`
maps its captured profiles through a byte-identical bundle source map. Three
matrix updates remain about1.5–2.3aggregate self CPU seconds per twenty-second
observation; Three render code dominates. Inclusive stacks overlap and are
not additive GPU timings.

All accepted dense runs have zero failed models/worker jobs/renderer errors,
at least47 NPCs moving in each visit, and complete source/particle pool and
GPU template retirement. v13 retired all2338 templates; all three area worker
owners are closed/drained and final shadow groups/geometry keys/alpha keys/
members are zero before process exit.

## Small-area regression and remaining work

The initial eager scan's Prelude/academy check passed loading, rendering and
cleanup but measured85.85FPS,13.2ms reported p95 and5.3ms render submission.
An earlier worker build measured96.51FPS,12.0ms and3.9ms in the same bounded
script. Those builds include other changes, so this does not isolate a causal
regression. It motivated the final lazy scan and a repeated production check.
Never describe that initial observation as a performance pass against the
older baseline simply because it exceeds60FPS.

The final lazy scan's repeat (`shadow-instances-vanilla-v2.json`) passes with
**95.86FPS**,12.0ms reported p95 and4.1ms render submission. Initial controlled
presentation takes2.71seconds and the academy transfer5.42seconds. All65 GPU
templates retire, all shadow cache/member counts return to zero and there are
no captured renderer errors. At the last sample only191 dirty-light casters
need instance keys, versus1653 live casters. These sequential observations
support removing the eager scan overhead; they are not a universal FPS claim.

The focused suites, offline GPU fixture, final dense/vanilla runs and build
all pass. Final authored fixture and dense screenshots were visually inspected.
The owned dense server was stopped after testing; other existing servers were
left untouched. No live client input remains pending. `git diff --check` still
reports pre-existing trailing blank lines in `src/main.js` and the resume note;
the changed runtime modules pass syntax and focused checks.

The goal is not complete: dense frame p95 remains above16.7ms and performance
does not approach the user's native230FPS report. Main-scene draw submission,
matrix/traversal work and height queries remain measurable costs. GPU profile
times here are CPU/driver samples, not GPU timer queries. Fidelity and cleanup
checks must continue alongside further batching or worker work.
