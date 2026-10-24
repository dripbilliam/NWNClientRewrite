# Producer-owned local matrices

2026-10-21. Performance goal **active**. This change removes repeated local
transform composition from explicitly owned model nodes and fixed scene roots.
It preserves rendered output, animation timing, picking hierarchies, light
counts, shadows and render resolution. Tests use offline fixtures and owned
loopback servers only. No Arelith connection was made.

## Implementation and ownership

`managed_local_matrix.js` opts an object into explicit local-matrix ownership.
It composes the initial matrix and disables `matrixAutoUpdate` on that object.
The flag lives in clone-compatible `userData`, without a global owner map.
`ModelAnimator` commits each node after all reset/track writes, public reset
commits immediately, native physical-part controllers commit after writing
position/orientation/scale, and manual pose services commit their local writes.
Existing world updates, skin evaluation, events and controller clocks remain.

Only the production network/template builders opt model nodes and identity
meshes in. The renderer opts in the fixed scene/area roots and tile placement
roots. Moving creature roots, attachment wrappers and arbitrary Object3Ds keep
automatic behavior. `NetworkScene` retains its automatic default; production
explicitly calls `manageLocalMatrices()`. Any future PQS writer on an opted-in
object must commit before world-matrix consumers; reparenting a fixed subtree
under another fixed parent would require marking it dirty. This is an explicit
producer contract, not a global Three.js prototype patch or a claim about the
original executable's matrix implementation.

The earlier generic matrix-cache experiment remains rejected: checking every
object on every query cost more than it saved. The ordered main-draw batching
prototype also remains **disabled**, following its measured regression.

## Correctness evidence

- `managed-matrices-final-tests-v1.txt`: 43 focused tests pass, including
  animation, native physical-part controllers, manual poses, clone/reparent,
  negative/nonuniform parents, skin bindings, attachments and scene loading.
- `managed-matrices-v1.json`: actual WebGL comparison of automatic vs managed
  hierarchies over32 frames, with64 fixed and12 animated authored models.
  All final images, both point/directional shadow atlases, raw local/world
  matrix hashes, draw counts and triangle counts match exactly; no GL errors.
  At frame5, local compositions fall613→56 and world multiplications613→164.
  First-frame world initialization still happens. Shadows and animation are
  enabled in both variants. The screenshot was inspected.
- `managed-matrices-transformed-v1.json`: eight offline production-scene checks
  pass with real cached `invis_cr_160`/`c_golstone` resources: visible-controller
  selection, hit ownership, idle/walk/run, cast, attack, keyboard preview and
  revert cleanup. HTTP attempts0, joins0; cached resources are not a live test.
- Both dense native runs retire all three areas' source/particle worker pools,
  templates, shared geometries and shadow owners before client exit. No model,
  worker or renderer failures. Between45 and48 independently wandering actors
  move per visit. Final dense screenshot inspected.

## Native local performance

Same authored DensePerf module, loopback5123,3440×1369 buffer at1× pixel ratio,
three20-second steady samples with camera rotation. Median FPS and median
rolling frame p95 below; readiness includes all preparation before sampling.
The local server executable and module identities are recorded by the probe.

| Run | Visit A FPS / p95 | Visit B FPS / p95 | Return A FPS / p95 | Ready A / B / A |
| --- | --- | --- | --- | --- |
| Before v20 |33.19 /33.8ms|35.97 /31.7ms|38.53 /30.4ms|11.25 /11.43 /8.65s|
| Managed v21 |33.45 /33.3ms|39.34 /28.8ms|39.64 /27.8ms|12.68 /10.61 /8.23s|
| Managed v22 |33.87 /33.3ms|38.98 /29.3ms|40.82 /27.9ms|11.77 /10.64 /8.12s|

These sequential runs show a modest improvement, especially in later visits.
Wandering/visibility/cache/profiling variation prevents a universal FPS
multiplier claim. The exact-operation fixture establishes the eliminated work.
The first area is still around34FPS and dense p95 remains far above16.7ms.
This does **not** reproduce the user's original-client230FPS comparison or
establish parity. The full goal is not achieved.

The unchanged small Prelude/academy server on loopback5121 also passes:
92.99FPS, rolling p9512.6ms, first readiness2.64s and transfer5.49s, with no
renderer errors and all65 templates/1424 geometries retired. The prior v20
small run was94.91FPS/p9512.2ms; this slight sequential variation is not
credited as a small-scene improvement. The authored dense server was stopped
after testing; other existing local servers were left running.

Current bundle `index-DCXFqZYV.js`; current matching source map is
`creation-performance-entry-source-v1`. Previous v20 map is preserved as
`managed-matrices-baseline-source-v1`; the profile summarizer selects matching
maps rather than attributing old minified samples against a new build.
`verify-managed-matrices.mjs` records report/source hashes, equality and
cleanup checks in `managed-matrices-proof-v1.json`, explicitly goalCompletefalse.

Next work: shader/light-uniform and per-draw submission bookkeeping still
dominate. Source workers already finish their queued work well before steady
sampling. Additional fetch workers alone cannot recover this frame time.
