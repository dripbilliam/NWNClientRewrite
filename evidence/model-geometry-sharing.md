# Immutable rigid geometry ownership — local performance work

2026-10-21. Goal remains **active**. Previous goal turn made verified progress
with shadow-only grouping. This turn profiles its remaining costs, rejects a
slower matrix-cache experiment, and shares repeated rigid mesh buffers in the
replacement client. All network checks are against owned loopback servers.
No Arelith connection or input. Original installation/assets remain read-only;
only authored fixtures, first-party code and derived evidence are saved here.

## Production change

The network model builder rebuilt Float32 triangle lists, UVs, normals, bounds
and native camera-hit planes for every rigid instance and shader preparation
template, even when the same immutable parsed model node supplied all inputs.
`RendererModelGeometry` now owns one geometry per live rigid source node, with
one lease per built mesh. Source identity comes from the existing model cache;
it does not merge similar-looking resources or use unchecked hash equality.
Materials, object hierarchy, animation bindings, textures and gameplay IDs
remain private or retain their existing owners. Draw order is unchanged.

Both network instantiation and shader-template creation opt in. Other model
builder paths retain their existing behavior. `node.skinned` and explicit
transformed vertices always build private geometry, including animation-owned
skin buffers. The shared geometry carries immutable source indices and native
camera-hit planes. Per-instance bounding-sphere transforms, materials, picking,
keyhole and highlight behavior still use their original mesh instances.

`disposeVisualRoot` and scene cleanup release each mesh lease. Removing one
instance leaves the buffers alive for other instances and preparation owners.
The final owner disposes once and deletes the source cache record; repeated
release is harmless. A replacement geometry has a separate owner. Constructor
failure releases its acquired lease. Weak maps avoid retaining dead source or
mesh owners, while counters expose active records/leases in diagnostics.
No global Three prototype or original binary is changed.

## Correctness and actual GPU output

The focused pool, retirement, preparation batching and shadow grouping suites
pass **18 tests** (`model-geometry-tests-v1.txt`). They cover source reuse,
separate materials/meshes, last-owner disposal, repeated disposal, constructor
failure and privately replaced geometry, alongside existing renderer lifetime
and shadow cases.

`probe-model-geometry.cjs` extracts the actual production mesh-builder functions
from `src/main.js`. The offline WebGL fixture compares ordinary versus shared
builds of48 authored meshes from four source nodes, including multiple bitmap
groups, skinned/external transformed exclusions, moving nonuniform poses,
negative scales, alpha textures and removal of an instance while peers remain live. All HTTP
requests are blocked. The24 final images,24 point-shadow images, draw/triangle
counts and24 ray-picking query results match exactly. Materials remain distinct;
skinned/transformed instances remain private. All leases/buffers retire. The
fixture's live geometry count falls49→27 (only half the nodes qualify).
Artifacts: `model-geometry-v1.json/.png` and final run-v3. The initial run-v1 caught a
missing bitmapNames local during extraction; it was fixed before native checks.
It is retained as a rejected run, not counted as a pass. Final screenshots of
the authored fixture and native dense scene were visually inspected.

## Native dense fixture

Same authored module and3440×1369 render size as previous dense measurements:
two100-tile areas,48 wandering multipart NPCs+48 braziers+32 chests each,
a→b→a transfers,20seconds of observation and6seconds of camera rotation per
visit. The native server is private on `127.0.0.1:5123`. Existing source and
particle vertex worker pools remain active and are retired on each area change.

| Visit | Before FPS (v14) | Shared FPS (v16) | Before p95 ms | Shared p95 ms | Before render ms | Shared render ms | Ready seconds v16 |
|---|---:|---:|---:|---:|---:|---:|---:|
| a |30.44|33.29|36.7|33.7|17.9|16.5|11.57|
| b |33.97|38.64|33.4|29.2|14.0|12.0|11.58|
| a return |32.49|38.73|34.6|29.0|14.5|11.8|9.16|

These are medians of sampled rolling metrics, not independent per-frame p95s.
The final run uses107 active shared rigid buffers for roughly4576–4586 live
leases per area, including retained shader templates. Across all visits321
buffers are created and14121 reuse acquisitions avoid repeated construction.
All321 retire, with active records/leases zero before process exit. Main draws
remain1906/1873/1875; shadow draws323/81/81. No geometry is hidden or merged out
of the main scene to obtain this reduction in allocation and binding overhead.

Both v15 and v16 pass loading, movement, zero asset/worker/renderer failures,
all three area worker owners closed/drained, and complete template/shadow/
geometry retirement. **v15 overlaps an authored CPU microbenchmark** and is
used only for correctness/lifetime evidence. v16 has no concurrent benchmark.
Sequential wandering, visibility and cache state still vary; the table is not
a matched original-client benchmark or a universal causal FPS ratio.

Build `index-B6pHP0rE.js`, worker `resource_worker-zWTWWm2T.js`, CSS
`index-D6sJh7Rk.css` pass. Current byte-identical source map matches the new
bundle; v14's DGNFFs9Z map is preserved under model-geometry-baseline-source-v1.
The profile summarizer selects the matching map. `verify-model-geometry.mjs`
checks source hashes, actual GPU/picking results, loopback fixture identity,
render dimensions, movement and complete ownership retirement.

The final Prelude/academy check (`model-geometry-vanilla-v1.json`) also passes:
96.60FPS,12.1ms reported p95,4.2ms render submission,2.64seconds to first
controlled presentation and5.37seconds for the transfer. All1424 shared
geometry records and65 GPU preparation templates retire, with zero active
leases, shadow caches or captured renderer errors. The owned dense server
PID19364 was stopped after both dense clients exited; other servers were
untouched. No live input remains pending. Final proof/verifier pass; the
known trailing blank lines in main/resume predate this change.

## Rejected transform-cache experiment and remaining scope

`summarize-transform-profile.mjs` attributes matrix/traversal samples to their
real first-party callers. In v14's20-second steady visits, light preparation
accounts for2.32/2.93/3.19aggregate CPU seconds of these sampled operations;
animation accounts for roughly0.5–0.7seconds, while diagnostic bounds contribute
much less. This justified measuring a change-aware matrix arithmetic cache.

The candidate preserves automatic/manual flags, direct local/world edits,
reparenting, custom update methods, cameras, signed zeros and exact matrix
results over120 differential frames. Four tests pass. Its bookkeeping is
slower: on paired authored20101-node/100-frame runs, stock takes132–184ms,
the candidate424–633ms. It is **rejected and never enabled in production**.
Sources/tests live under `scripts/experiments`; production imports none of
them. `world-matrices-rejected-v1.json` records the benchmark and scope.

Dense p95 still29–34ms, above16.7ms, and native230FPS is not reproduced.
Per-draw shader/uniform work, matrix traversal and height queries remain
measurable costs. Sharing geometry helps future submission work but is not
main-scene instancing or a completed performance goal. Existing fidelity,
worker cancellation and lifetime requirements remain in force.
