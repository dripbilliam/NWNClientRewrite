# Consecutive material-state reuse — disabled

2026-10-21. Performance goal **active**. This turn implements a rendering
candidate, fixes an actual GPU mismatch, and measures its cost. The candidate
is not adopted: production explicitly uses `enabled:false`. No Arelith
connections; native tests use owned loopback5123/5121 and GPU tests block HTTP.

## Mechanism and correctness

`RendererMaterialReuse` keeps every sorted draw, object, geometry and triangle
in place. It temporarily substitutes the immediately preceding equivalent
Lambert material in a run, reducing repeated common-uniform/material setup.
It never rewrites `object.material`, reorders objects, batches geometry or
allocates GPU resources. Maps, colors/emission, normal/environment/blend
vectors and scalar render state must match. Generic/subclass/custom shaders,
pending source programs, unsupported callbacks and texture upload hooks retain
ordinary drawing. Temporary render-item edits and callback substitutions are
restored on success or error; the only persistent cache is a WeakMap.

Native keyhole material and mesh callbacks now expose renderer-owned metadata
through the existing weak hook registry. The callback implementation itself is
unchanged. Known keyhole flags are evaluated once per relevant draw, and only
matching flags and shader-owner chains can reuse a material. Target previews
and keyholes retain their original installed shader includes and uniforms.
Unknown callbacks are checked before any main draw, including a callback that
clears itself on the first draw. Nested shadow rendering cannot start this
main pass. The original render methods are restored afterward.

The first GPU oracle exposed different images on two shadow-toggle frames.
Skipping a material's first or pending lighting refresh changed its compiled
program history. Reading state after the shadow pass was insufficient: Three
finalizes its light-layout version later. The corrected adapter lets the first
lit main draw run normally, reads the actual current lighting version, and
leaves source materials with stale versions/programs on their ordinary path.
Only matching initialized programs are reused. This preserves the original
draw's program-cache behavior, including the tested renderer-mode transitions.
The rejected initial mismatch is retained; it is not a passing result.

`material-reuse-run-v7.txt` / `material-reuse-v1.json` pass32 actual WebGL views:
all final images,484 shadow-atlas readbacks, draw counts and triangle counts
match. Per-mesh keyhole flags match every frame;194 observed draw-uniform
records also match in the formerly failing frames. The fixture uses64 point
lights/15 point shadows, directional/spot/hemi lights, real installed target
and keyhole includes, transparent/particle draws, negative/nonuniform scale,
camera/material/light changes and context restoration. Source materials and
hooks are asserted unchanged after every pass. Authored GPU images were
inspected. Source and harness hashes are recorded.

The separate original keyhole fixture also passes: center pixel changes from
red `[250,0,0,255]` to green `[0,255,0,255]`, revealing the player through the
wall. Ownership/restoration pass; its screenshot was inspected.
`material-reuse-final-tests-v2.txt` records28 focused unit checks, including
pending versions/program changes, light invalidation, live material edits,
callbacks, exception restoration and keyhole-state separation.

## Native performance decision

Same authored dense module,3440×1369 at1×, three20-second steady visits with
camera rotation,47–48 independently moving NPCs and two area transfers.

| Run | A FPS / p95 | B FPS / p95 | Return A FPS / p95 | Ready A / B / A |
| --- | --- | --- | --- | --- |
| Prior v26 |33.97 /33.5ms|39.15 /29.3ms|41.14 /28.1ms|11.00 /11.58 /8.21s|
| Reuse v27 |34.32 /32.4ms|38.08 /29.9ms|40.05 /28.6ms|10.77 /11.78 /8.85s|
| Final OFF v28 |34.97 /32.2ms|39.98 /28.6ms|41.54 /27.4ms|11.09 /10.57 /8.10s|

The candidate reuses a median300–305 material setups per visit, far fewer than
the authored fixture's high reuse ratio. Its profile attributes about0.98
aggregate self CPU seconds per20-second sample to its own code; `equal` and
`patch` dominate that cost. Common-uniform work falls, but this bookkeeping
consumes the savings. There is no convincing full-client improvement, and the
final disabled run is faster on all three visits. Sequential actor/visibility/
cache/profile variation prevents a universal percentage claim. Output parity
alone does not justify enabling the candidate.

Native v27 predates the final additional preflight/subclass guards; its exact
source is preserved by `material-reuse-candidate-source-v1` and verified
against the report's source hash. Final production v28 uses the latest code
with the feature disabled. Both native runs pass zero-error and all-area
worker/index/template/geometry/shadow retirement checks. Final dense image was
inspected. The small owned Prelude/academy check passes97.82FPS/p9512.0ms,
first readiness2.61s/transfer3.92s and final template/geometry retirement.
These small-scene observations are not an adopted optimization claim.

The final bundle is `index-ooxPi9ec.js`; its current hidden source map is
byte-identical. Prior `index-1nqxG9D1.js` and candidate `index-Dk9sIhTl.js` maps
are archived. `verify-material-reuse.mjs` checks report/source hashes, GPU and
uniform equality, the historical candidate source, production-disabled flags,
native movement/retirement and small-area checks. The proof explicitly records
`candidateAccepted:false`, `productionEnabled:false`, `goalComplete:false`.
The authored dense server was stopped; all owned Electron probes exited and
other existing local servers were untouched.

## Next measured work

The prior main-batch prototype already caches unchanged geometry streams;
reimplementing that cache is not a new optimization. Its remaining material
and palette descriptor work, small runs and lack of native keyhole support
limit the draw reduction. Current source also eagerly reserves32 texture-array
layers per pool: a1024² RGBA pool requests128MiB, exceeding its64MiB budget
and falling back even when fewer layers would fit. Adaptive bounded palette
allocation and complete keyhole/target batching are concrete avenues to test,
with exact sampling/depth/hook/cancellation evidence required before adoption.
The full goal remains unachieved: dense p95 is still27–32ms and there is no
matched original-client230FPS baseline.
