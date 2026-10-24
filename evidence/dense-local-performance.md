# Native-server dense performance follow-up, 2026-10-21

Subsequent work: [multipart preparation batching](model-preparation-batching.md)
reduces this fixture's observed readiness from 18–23 seconds to 10.5–13.8 seconds
in two further runs, with retained visual/lifetime checks. Dense steady p95
still misses the target. The measurements below describe the preceding build.

Goal remains **active**. No Arelith connections were made. All live protocol
traffic in this pass used the separately owned `127.0.0.1:5123` fixture server.
The original executables and other servers/clients were not modified.

## Workload and accepted evidence

`scripts/create-dense-server-fixture.mjs` authors a new MOD containing only new
GFF data and two small NCS scripts. It references installed resource names;
it does not copy an installed module, model, texture or script body. There are
two 100-tile rural areas, each with 48 independently wandering multipart humans,
48 braziers and 32 chests. Server-side `ActionRandomWalk` supplies genuine native
movement/animation replication. An authored module chat handler assigns native
`JumpToLocation` to the player for the two measured area transfers. This is not
a client-side teleport or synthetic registry replacement.

The fixed-loopback production-client probe uses the existing protected login
only in main-process memory, wipes the credential object and BIC buffer after
login, and records no secret. It renders at 3440 × 1369, samples each area for
20 seconds, rotates the camera for six seconds, and collects renderer CPU
profiles. Screenshot v4 was inspected: populated terrain, animated humanoids,
chests and flame emitters are visible; this is not an empty benchmark scene.

Accepted traversal: `dense_a → dense_b → dense_a`. Readiness means attached
scene, controlled player rendered, graphics barrier complete, at least 100
bindings, and no reported pending assets/shaders or preparation. It does not
claim every actor stays in perception range simultaneously.

`dense-local-v3.json` is the baseline for this pass (already includes the earlier
resource and particle workers). `v4` and `v5` use `index-CDkpMJ_1.js` with the
light matrix change below. v5 failed the new shutdown gate; v6 also includes the
main-process terminal-state fix described below. The module hash, workload, bundle hashes and summaries
are checked by `scripts/verify-dense-local-performance.mjs`; derived proof is
`backups/animations/dense-local-proof-v1.json`.

| Run | Area | Ready threshold | Median FPS | Median reported p95 |
| --- | --- | ---: | ---: | ---: |
| v3 | a, initial | 20.62 s | 23.64 | 43.0 ms |
| v3 | b | 21.28 s | 28.93 | 37.6 ms |
| v3 | a, return | 18.61 s | 28.16 | 39.0 ms |
| v4 | a, initial | 20.39 s | 25.76 | 41.3 ms |
| v4 | b | 22.34 s | 30.34 | 36.2 ms |
| v4 | a, return | 18.81 s | 27.43 | 40.1 ms |
| v6 | a, initial | 20.89 s | 24.15 | 43.4 ms |
| v6 | b | 23.38 s | 29.26 | 37.9 ms |
| v6 | a, return | 17.71 s | 26.81 | 38.9 ms |

These are sequential profiled runs with random native wandering, different
visible casters and uncontrolled driver caches. **Do not claim a causal FPS
speedup from this table.** The narrow static fixture's earlier 15.9 ms average
does not establish full-client 60 FPS. Neither run reproduces the user's native
230 FPS comparison under matched conditions.

The workload actually exercises both four-worker pools: about 893–894 source
jobs per area (37 rules tables, 64–65 models, 13 TGAs and 779 PLTs) and hundreds
of completed particle draw frames / tens of thousands of emitter results.
Source decoding consumed about 0.67–0.69 aggregate worker CPU seconds per area
in v3, much less than the roughly 19–21-second elapsed readiness threshold.
Worker job failures and model/render errors were zero. Occasional stale draw
frames used the established discard/synchronous fallback; they are not counted
as zero-latency frames or physics failures.

## Production change and validation

`prepareRendererLights` resolves the scene and external/parented camera matrices
once. Light selection and shadow admission use those matrices directly in the
prepared path, avoiding repeated `getWorldPosition` ancestor-chain updates for
each light. Standalone callers still resolve current matrices. Colors,
intensities, native priorities, visibility/layers, shadow limits, resolution and
draw quality were not reduced.

The new regression compares prepared and independently queried paths over 40
changing parent poses, negative scales, visibility changes and a separately
parented camera; it also rejects redundant per-light position queries in the
prepared path. The focused light/slot/budget/traversal/cache suite passed all
24 tests (`light-matrix-regression-v1.txt`). Build passed
(`light-matrix-build-v1.txt`). This change is small; the dense frame budget is
still missed.

The v5 shutdown gate exposed a real IPC cancellation defect: explicit
`network:disconnect` marks its owner cancelled before `NetworkGameSession.finish`
emits the final closed state. The old `watchSession.active()` guard suppressed
that state, so the renderer never ran `onExit` and retained the last area's
workers until process exit. v5 timed out and exited 1; its three traversals are
not accepted as cleanup success (the early `success` field was subsequently
corrected in the harness, and the verifier independently rejects any `failure`).

The fix forwards that real terminal state only while the exact cancelled owner
and session are still current. Gameplay messages and nonterminal states stay
suppressed; a stale portal/session cannot close the new owner. The regression
fails before the fix (`dense-disconnect-before-v1.txt`), then all 49 IPC, portal,
area-graphics and worker checks pass (`dense-disconnect-regression-v1.txt`). This
is a main-process change; the built renderer bundle remains CDkpMJ_1.

The final v6 harness waits for renderer `onExit` disposal, then checks all three
area owners for closed source and vertex pools, zero workers/pending/queued
jobs and a drained prefetch queue before process exit. v3/v4 exited normally but
did not explicitly await that final renderer owner; they are not used as proof
of final worker retirement. v6 **passed and exited 0**; the derived verifier
also passed. All 48 NPCs moved in each area, with zero failed models/renderer
errors. Its final closed event reached the renderer; all three source and
vertex pools retired with zero pending/queued jobs. The owned dense server was
stopped afterward; other servers remain untouched.

## Remaining bottlenecks and next work

Symbolized renderer CPU profiles use byte-identical hidden source maps. Preserve
`dense-local-baseline-source-v1.json/.map` for the baseline; the current map is
`creation-performance-entry-source-v1.json/.map`. Summaries and raw `.cpuprofile`
files are retained. Inclusive stack samples overlap and are not GPU durations.

The initial v3/v4 profile spends about 8 seconds cumulatively inside model
preparation, including repeated full-scene light/profile scans, matrix updates
and shader work. During steady v4 observation, Three's binding-state
`needsUpdate` has about 3.42 seconds of self samples over 20.44 seconds;
`updateMatrixWorld` has about 1.47 seconds. Thousands of main/shadow draws,
uniform uploads, visible traversals, material sampler scans and ground-height
queries remain substantial. Pure source decoding is not the dominant remaining
cost. Next: bound redundant shader-profile work during assembly and reduce
renderer submission work while retaining per-object picking/highlighting,
animation and exact shadow/camera behavior. More source workers alone will not
resolve these measured renderer costs.

## Rejected or narrower evidence

v1 picked a mismatched cliff tile and could not complete the intended walk into
a transition. v2 changed terrain but automatic trigger entry still did not
transfer; both timed out after the first area and are excluded from accepted
transfer/load claims. The accepted fixture uses the authored server chat/jump
script. This pass does not establish a production trigger defect or validate
door/trigger input, server handoff, arbitrary NUI, equipment changes, every
Workshop asset or original-client performance parity.
