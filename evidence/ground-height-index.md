# Static ground height-query index

2026-10-21. Performance goal **active**. The preceding managed-matrix turn made
verified progress. This turn rejects a slower lighting cache and adopts a
spatial broad phase for repeated creature-grounding queries. No Arelith
connections; tests use offline resources and owned loopback5123/5121 servers.

## Behavior and lifetime

`NetworkScene` previously grounded every moving creature by scanning every
walkable triangle in the area. `WalkableHeightIndex` builds a10-unit X/Z grid
once from immutable area ground. Each cell contains original triangle objects
in original source order. Querying still calls the unchanged
`findWalkableHeight`: same arithmetic, barycentric tolerance, reference-height
selection, maximum delta and tie order. It does not quantize height or use a
cached answer from a preceding frame. Collision/path acceptance and mutable
door/object obstacles keep their existing owners and calculations.

Bounds expand for the original barycentric tolerance and numerical roundoff.
Ill-conditioned/extreme/oversized triangles join every cell in source order.
Outlying/nonfinite coordinates, a changed source-array length and a bounded
reference-budget overflow take the original full-scan path. Default memory
bound is one million triangle references. Changes to static source vertices
require rebuilding; current area-ground producers create immutable geometry.
Replacing or closing an area clears cells, references and the source pointer.
A cancelled/closed scene cannot install a late index. Ground-index retirement
metadata accompanies the existing area-worker retirement log.

This is renderer-side acceleration of an existing client grounding calculation,
not a claim about the original executable's walkmesh implementation. The
queries remain synchronous so movement does not wait for worker messages or
use stale floor heights. Existing source/particle worker pools remain active.

## Exact-query and movement evidence

`height-index-final-tests-v1.txt`:56 focused checks pass, including actual
installed-module movement replay, keyboard/drive geometry, scene delivery and
cleanup, reference-height ties, negative coordinates, tolerant edges, layered
slopes, exceptional numeric geometry and bounded-memory fallback. Initial
unprivileged test run lacked permission to read the installed module; the
scoped read-only rerun passes. No source correction was needed for that error.

`height-index-offline-v1.json` compares25,693 queries against the original
function using read-only installed Prelude and authored DensePerf ground.
Every result is `Object.is` equal before hashing. No HTTP or joins. Median
five alternating CPU-query trials, not frame-rate measurements:

| Area | Triangles | Queries | Full scan | Indexed | Candidates / full |
| --- | --- | --- | --- | --- | --- |
| Prelude m0q1a |177|5593|10.19ms|2.25ms|17.0%|
| Academy m0q1b |1240|6700|103.58ms|2.91ms|2.50%|
| Dense A |6500|6700|435.42ms|9.04ms|1.62%|
| Dense B |6500|6700|440.19ms|8.73ms|1.62%|

Index construction takes0.52/1.45/8.81/7.82ms respectively. No raw installed
asset bodies are written. Native dense runs test live moving/animated actors,
camera rotation and two area transfers at3440×1369/1×:

| Run | A FPS / p95 | B FPS / p95 | Return A FPS / p95 | Ready A / B / A |
| --- | --- | --- | --- | --- |
| Before v22 |33.87 /33.3ms|38.98 /29.3ms|40.82 /27.9ms|11.77 /10.64 /8.12s|
| Indexed v25 |34.79 /32.7ms|39.30 /30.0ms|39.30 /29.4ms|11.21 /11.57 /8.73s|
| Indexed v26 |33.97 /33.5ms|39.15 /29.3ms|41.14 /28.1ms|11.00 /11.58 /8.21s|

These do not establish an overall FPS improvement: changes are mixed within
sequential run variation. They establish active, correct integration and much
less grounding work. v25 tests5.49million candidates instead of303.93million;
v26 tests4.99million instead of277.94million. No full-scan fallbacks in these
areas. Existing walkmesh sampled self CPU drops from about0.59–0.86 aggregate
seconds per20-second baseline sample to0.036–0.045 seconds in v25. These are
statistical CPU samples, not GPU timings or a universal speedup multiplier.

Both runs have47–48 NPCs moving on every visit, zero renderer/model/worker
failures and all three areas' indices/source and particle worker pools/
templates/shared geometry/shadow owners retired before exit. The final dense
screenshot was inspected. Rendering remains the main frame-time bottleneck;
dense p95 still exceeds16.7ms and the user's native230FPS case is unmatched.

The smaller owned Prelude/academy run also passes:95.84FPS/p9512.1ms,
first readiness2.66s and transfer3.87s. Bounded trusted Chromium keyboard input
tests W/S/A/D/Q/E; W/S have147/126 moving steps and zero stationary steps in
the hold windows, with maximum steps0.064/0.024 units. This is a modeled input
stream, not a physical-keyboard trace. Both area ground indices, all source/
particle worker pools,65 model templates and1424 geometries retire; zero
renderer errors. The authored dense server was stopped after testing and all
owned Electron probes exited; other existing local servers were untouched.

## Rejected rendering experiment and remaining work

[lighting-uniform-cache.md](lighting-uniform-cache.md) records two GPU-correct
but slower native candidates. Both main-draw batching and lighting-uniform
caching are explicitly **disabled** in production. Their passing output tests
are not counted as performance gains.

Current bundle `index-1nqxG9D1.js`; `creation-performance-entry-source-v1` is a
byte-identical matching source map. Prior v22/v23/v24 maps are archived and
selected by the profile helper. `verify-height-index.mjs` hashes current
sources/reports, validates exact queries, native index use and retirement,
disabled prototypes, small-area movement/transfer and GPU output evidence.
Its proof explicitly keeps goalCompletefalse. Next work must reduce dominant
render submission/traversal or improve justified per-object light handling;
the full loading/frame-rate goal remains open.
