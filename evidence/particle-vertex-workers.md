# Particle draw preparation workers — 2026-10-21

Strictly offline fixtures and the owned local server. No Arelith connections
or input. The performance goal remains active.

## Implementation

Dense multiplayer particle rendering now uses a second area-owned pool of up
to four actual module workers, separate from the resource-read/decode pool.
WebGL calls remain on the renderer thread. An empty task warms each worker
while area graphics prepare. Loads below512 active particles use the existing
synchronous path to avoid small-job IPC overhead.

Simulation, spawn/free ordering, events, RNG, collision and mutable texture
atlas clocks remain in their existing main-thread order **every frame**.
There is no frame-rate cap, reduced simulation frequency or separate RNG.
The native atlas mutation was factored out of vertex construction so it still
advances when a previous draw snapshot is in flight. Workers only compute
vertices from immutable numeric snapshots. The normal synchronous builder
keeps its original mutation behavior.

One frame of draw work may be outstanding, split by particle count among the
workers. No unbounded snapshot queue is created. Completed geometry is uploaded
only for the same current pool/root and still-live emitter entry. Root changes,
removal, area closure and newer synchronous results invalidate old work. A
worker failure resumes synchronous drawing; a result delayed beyond250ms is
discarded and the owner draws synchronously until that bounded work drains.
Simulation and clocks continue in either case.

Normal drawing pipelines a completed snapshot, usually one simulation frame
behind. This latency is explicit; this is not a claim of zero-latency rendering
or identical intermediate pixels to a synchronous simulation/draw pair. Main
atlas/physics state is never replaced with an older worker snapshot.

Transfer buffers contain compact numeric emitter headers and particle fields,
not cyclic emitter owners, callbacks, Three objects, actor IDs, connections,
archive resources or credentials. The buffer is a private draw snapshot, so
transferring it never detaches authoritative simulation arrays. Only fields
used by each draw mode are written. Float64 headers preserve input parameters;
native f32 record fields and signed frame integers retain their required bits.
The existing native vertex builder runs in each worker, and output buffers
transfer back without copying the full object graph.

Per-frame world pose caching also replaces repeated getWorldPosition/
getWorldQuaternion/getWorldScale ancestor walks and decompositions. The cache
is discarded on every update. Geometry/light/animation transforms finish
before the synchronous particle update; particle CPU services read those poses
without mutating scene transforms. Negative scales and changing parents are
covered. No original binary, resource, or process was modified.

The debug performance view displays particle worker/pending-frame counts;
`#model-canvas.dataset.particleVertexWorkers` publishes detailed counters every
200ms. Both worker pools terminate on area retirement, including queued work.

## Correctness validation

`particle-vertices-worker-regression-v2.txt`:41 focused tests pass.

- All245 saved original native draw cases produce exactly the same packed
  vertices/soft parameters through actual worker threads. Main-thread atlas
  mutations also match. Includes all seven modes, fades, colors, sizes,
  elevation, atlas directions and stopped/splat conditions.
- Sixty moving simulation frames with changing deltas, parents, camera,
  fountain/explosion events and recycled particles retain identical RNG state,
  draw counts, physics/atlas state and uploaded position/UV/RGBA bytes.
- A deliberately busy worker over18 frames does not delay simulation, change
  RNG, or skip atlas updates. Queue size remains bounded. Older results never
  write atlas/physics back.
- Tests cover stale results versus synchronous fallback, owner changes,
  removal, failures, malformed individual snapshots, detached-buffer ownership
  and normal existing particle/frame/lightning/reference-target paths.
- Existing resource-pool, area graphics/retirement and debug shutdown checks
  still pass.

The270-frame authored CPU fixture retains its pre-change full particle/vertex
SHA256 `655dda1ddb50654339a0ae6f4d2cb133b581f4045630311a56e900f661808ce1`
after pose caching. Its current synchronous mean is12.54ms versus19.59ms at
the original baseline; no throughput from that synchronous run is attributed
to workers.

## Combined Chromium/WebGL measurement

Same3440×1369 authored fixture:1,501 solid meshes,63 real point lights, native
keyhole/targeting shaders,80 emitters /9,760 active particles,1,581 main draws
/67,522 main triangles,711 shadow draws. Production unrolled light path;
compact-loop experiment remains disabled. Every measured iteration yields to
the browser event loop, so worker messages can arrive between real frames.
Reports: `heavy-renderer-combined-sync-v2.json` and `-workers-v3.json`.

| Measurement | Synchronous | Workers + pose/packing improvements |
|---|---:|---:|
| Mean CPU/driver frame work |21.61ms|15.87ms|
| p95 CPU/driver frame work |23.10ms|17.70ms|
| p95 completion-to-completion gap |23.70ms|18.80ms|
| Mean main-thread particle work |11.73ms|5.63ms|

Worker run:71 submitted/completed measured frames,5,680 emitter results applied,
one initial coalesced draw submission, no failed jobs, discarded results or
stale-frame fallback. Four workers complete292 tasks including warmup and a
final verification snapshot. No queued/pending tasks remain after draining.
Results are not a controlled cold-driver-cache experiment or a direct
measurement of the user's modded world.

After flushing current draw data without advancing simulation, both images
have SHA256 `e704fb0143a6abcbcc771403347271665537257caf165fad947b970436878365`.
Particle state/counts, draws and shadow statistics match. The worker screenshot
was visually inspected; it contains the dense meshes and visible particle
effects. Actual intermediate rendering retains the pipeline latency described
above; the final-pixel comparison does not prove zero latency.

## Integrated local multiplayer run

Build `index-EyIUWmDN.js` / worker `resource_worker-zWTWWm2T.js` passes. Report
`particle-vertices-workers-local-v1.json` loads both Prelude areas,100 tiles /
92 objects, controlled player rendered, zero reported asset/model/worker/
renderer failures, and successful camera rotation. Transition to all prepared
6.08s. At3440×1369, excluding two seconds after resize, median sampled96.51FPS
and median sampled p9512.0ms. The small vanilla scene is below512 particles:
the dedicated pool warms but submits zero particle draw frames. Thus this run
checks integration, transitions and resource lifecycle, **not** heavy worker
throughput. The dense browser fixture supplies that evidence.

The full local probe exited0 cleanly after awaited disconnect/report write;
the earlier debug-window close fix is now verified in the full process too.
Other clients and servers were not interrupted. The local test server remains
running. There is no new public-server connection.

`scripts/verify-particle-vertex-workers.mjs` validates the recorded invariants
and writes `particle-vertex-workers-proof-v1.json`.

## Remaining objective

The dense p95 work/gap is still above16.7ms, and the fixture lacks animated
creature/UI/network costs. Need representative dense **local multiplayer**
stress, further light/shadow/material/submission work, and continued shader/
first-use loading improvements. The original client's reported230FPS is not
reproduced by these measurements. The goal is not complete.
