# Worker and renderer performance goal — active

Latest investigation is in [material-state-reuse.md](material-state-reuse.md).
Consecutive equivalent-material reuse matches32actual GPU views/484shadow
readbacks and native keyhole reveal, but its dense bookkeeping consumes the
saved uniform work. It remains disabled. Final production v28 observes
35.0/40.0/41.5FPS,p9532.2/28.6/27.4ms, readiness11.09/10.57/8.10seconds;
all owners retire and the small-area check passes97.8FPS/p9512ms. This is
rejection evidence, not a newly adopted speedup. Goal stays ACTIVE; no Arelith.

Latest adopted optimization is in [ground-height-index.md](ground-height-index.md).
Static area grounding now searches indexed candidates in original order and
uses the unchanged exact height calculation.25,693real-resource queries match;
56focused checks and live local movement/transfer/cleanup pass. Dense CPU
query trials drop roughly435ms to9ms; whole-client FPS remains34–41 with
p9528–34ms, so no overall FPS win or completion is claimed. Both numeric-light
cache candidates regress and remain disabled, documented in
[lighting-uniform-cache.md](lighting-uniform-cache.md). The goal stays ACTIVE;
no Arelith connections.

The prior adopted optimization is in [managed-local-matrices.md](managed-local-matrices.md).
Explicit animation/pose writers now compose owned local transforms, avoiding
repeated query/render compositions.43focused tests,32actual GPU image/matrix/
shadow comparisons and an offline real-model animation check pass. Two dense
native runs reach33–41FPS, with p9527.8–33.3ms and readiness8.1–12.7seconds;
all workers and GPU owners retire. Improvement is modest; dense performance
still misses the target. Goal remains ACTIVE; no Arelith connections.

The previous investigation is in [ordered-main-batches.md](ordered-main-batches.md).
The prototype matches32actual GPU views with full lights/shadows and installed
target shaders, but v18/v19 dense performance regresses. It remains explicitly
OFF in production. Final v20 ordinary submission observes33.2/36.0/38.5FPS,
p9533.8/31.7/30.4ms and readiness11.25/11.43/8.65seconds, with all owners
retired; smaller-area check94.9FPS/p9512.2ms passes. This is rejection evidence,
not a newly adopted FPS gain. Goal remains ACTIVE; no Arelith connections.

Earlier adopted optimization is in [model-geometry-sharing.md](model-geometry-sharing.md):
rigid source-node buffers now serve thousands of separately owned instances.
Final native dense run v16 at3440×1369 observes33.3/38.6/38.7FPS,
p9533.7/29.2/29.0ms and readiness11.57/11.58/9.16seconds. Each area uses107
shared rigid buffers for roughly4600 leases; all321 buffers and all workers/
templates/shadows retire after the two transfers. Extracted production builder
matches24actual GPU main images/shadows/picking queries;18focused checks pass.
Small-area check96.6FPS/p9512.1ms also passes. A matrix cache was measured slower
and rejected; production imports none of that experiment. Dense p95 still fails
16.7ms, so the goal remains ACTIVE. No Arelith connections.

Previous [shadow-instances.md](shadow-instances.md) work: private
rigid caster groups reduce dense shadow submissions85–94%. Final local dense
run at3440×1369 reaches30.4/34.0/32.5FPS, p9536.7/33.4/34.6ms and readiness
12.15/13.05/10.15seconds over twoarea transfers. Main rendering stays unchanged;
all workers, templates and shadow buffers retire. Thirty focused checks and
40actual WebGL main images/80point atlases match; directional depth packing is
within onefloat32ULP with unchanged coverage. A lazy dirty-light scan restores
the small-area check to95.9FPS/p9512ms. Main draw submission/traversal remains
large; this STILL misses the full dense performance goal. Previous preparation
batching in `model-preparation-batching.md` reduced readiness18–23s→10–14s.
No Arelith connections.
Earlier entries below retain their narrower scopes and historical measurements.

User request, 2026-10-21: make area loading and steady rendering smooth with
multiple workers. **Only the owned local server is authorized for testing.
Do not connect to Arelith until the user explicitly permits it again.** Existing
Arelith logs may be read. This is a new active goal, separate from previously
paused parity/attunement investigations.

## Recorded baseline

The user's populated-area observation was 14.9 FPS, average/p95 67.1/83.0 ms,
631.2 ms worst, 2,305 cumulative hitches over 50 ms, at 3440×1369 and 1× pixel
ratio. CPU/driver measurements: frame work64.9 ms, render24.1 ms, particles14.8
ms, camera/lights18.3 ms, network2.0 ms, other presentation5.7 ms. Main/shadow
draws1,499/1,093; main/shadow triangles51,662/77,307; nine shadow maps reused,
six drawn. There were zero pending assets/shaders and no new programs, with
63 actual point lights but193 declared slots. This is a steady-state rendering
problem as well as a loading problem; CPU decode workers alone cannot fix it.

`backups/animations/area-performance-log-review-v1.json` summarizes the existing
10:58:37 UTC runtime log without packet bodies or credentials. It records five
area preparations: shader waits9.15,12.92,14.20 seconds in the slow cases;
106 resource warnings with median541 ms, p952,335 ms and maximum7,526 ms;
actual render submissions4,449.7 and4,912.2 ms in two stalled frames. Resource
durations overlap and include waits, so their sum is not CPU time. Long frame
callback gaps are not necessarily continuous work. Two portal preparation
pairs took3.13 and1.37 seconds before destination login; that is not the whole
area-loading time.

## First implementation

- Up to four actual module workers per area/resource owner parse MDL models,
  parse2DA tables, and decode TGA/PLT textures. Archive reads retain the main
  process's existing connection/resource ownership and asynchronous filesystem
  I/O. Renderer fetches/decode requests overlap in bounded batches.
- Model sources, inherited animations, and palettes remain area-scoped.
  World and hotbar share parsed rule tables instead of rereading/reparsing them.
  Input bytes are copied before transfer so cached archive bytes are never
  detached. Pixel outputs transfer back; model/table graphs preserve maps and
  aliases. Null-prototype property/row dictionaries are restored after clone.
- Area retirement terminates workers and rejects queued/in-flight work before
  awaiting scene synchronization. Crashes, malformed resources and timeouts
  reject affected jobs; retired results cannot attach to another owner.
- Neutral light capacity no longer adds50% headroom to an already bounded
  area light pool. Capacity resets before a new area, rather than retaining
  a large area's193-slot profile in a small room. Real lights and authored
  shadow requests are retained. Shader specialization and real drawing still
  have one WebGL owner; several workers cannot render concurrently into that
  same context. A separate render-worker migration needs explicit profiling
  and design, not multiple competing canvas owners.
- New stage timings distinguish tileset, rules, tile assets, tile instances,
  walkmesh and initial object work. Worker counters are available in
  `#model-canvas.dataset.resourceWorkers` and retirement diagnostics.

## Validation and measurements

Build `index-3nMf3xxv.js` / worker `resource_worker-D94pIWoR.js` passes.
`resource-workers-focused-v2.txt`:36 focused tests pass, including real Node
workers, malformed-input recovery, cancellation before scene teardown,
concurrent source caching, cyclic supermodels, rule table physical rows and
aliasing, light admission, shader preparation and graphics retirement.
`resource-workers-regression-v1.txt`:58/59 pass under sandbox; the one failure
was EPERM reading installed assets. `resource-workers-quickbar-regression-v2.txt`
reruns that complete native quickbar file successfully with read-only access.

`resource-workers-browser-v1.json`: production bundled worker runs in Chromium,
HTTP blocked, five installed binary models exactly match parser output; stone
golem inherits42 animations; the installed6.9 MB /15,100-row appearance table
matches, as do TGA pixels and palette color output. Zero renderer errors.
Synthetic16×1024² TGA decoding: main54–55 ms vs warmed workers24–36 ms;
maximum main-thread timer gap55–56 ms vs10–12 ms. Includes copies/clone costs;
not an in-game FPS comparison or a cold-start benchmark.

Two local production-client runs on unchanged Prelude at127.0.0.1:5121:

| Measurement | Model/image workers + light fix | Also rule workers + shared tables |
|---|---:|---:|
| Initial connect to fully prepared player |5.69 s|4.67 s|
| Transition request to fully prepared next area |11.34 s|8.97 s|
| Next-area loading phase to native admission |6.67 s|4.81 s|
| Resource requests over both areas |504|489|
| Academy tiles / objects |100 /92|100 /92|
| Median sampled FPS at3440×1369 |92.0|91.9|

Reports `resource-workers-local-v1.json` and `-v2.json`. Both have zero reported
asset failures, zero worker failures and zero captured renderer errors, and
the controlled player is present. The final area completed192 jobs in run1
and229 jobs in run2 (37 rule tables), with no pending jobs. These are single
successive runs, not a controlled cold-driver-cache experiment. Run2 still
waited3.63 seconds for academy shader preparation. These lighter local scenes
do **not** establish improvement from the user's14.9 FPS populated-area case.
The probe's debug IPC registration was repaired after run2 reported an
untrusted debug-status request; that harness-only cleanup is not credited as
a measured renderer improvement.

## Remaining goal work

Latest update: `particle-vertex-workers.md` records the now-integrated second
worker pool for immutable particle draw preparation, exact native/simulation
checks, combined dense mean15.87ms /p9517.70ms, and a clean local two-area run.
This is progress, not completion: dense frame-gap p9518.8ms still exceeds
16.7ms and representative animated local multiplayer stress is outstanding.

Further update: `source-prefetch-performance.md` records bounded independent
scene-source overlap, two local transitions at5.96/6.46s, and the first combined
dense renderer/particle benchmark. That combined workload is still23.7ms p95,
so the performance target is unproven. Particle vertex preparation off-thread,
shader waits and representative animated multiplayer stress remain open.

Update after the next goal turn: `particle-camera-performance.md` records
verified particle allocation/math/upload and camera broad-phase improvements,
a dense native-shader rendering comparison, and a local two-area regression.
The goal remains active; combined dense-scene and additional off-thread visual
work, independent object resource overlap and shader waits remain open.

1. Profile a reproducible heavy local/offline scene, preserving the user's
   resolution and comparable light, particle and draw counts. Store per-stage
   CPU/driver timings, loads, p95/hitches and visual-equivalence checks.
2. Overlap independent actor/placeable resource preparation without delaying
   the controlled player, violating attachment order, or carrying state across
   areas. Measure IPC/clone/upload and shader waits separately.
3. Reduce shader preparation and first-use driver stalls; keep known variants
   available under correct resource lifetime ownership.
4. Address camera/light traversal, particle simulation/vertex generation and
   shadow/main draw submission. Move suitable CPU batches to workers only with
   deterministic animation/RNG/collision and cancellation tests. Evaluate a
   dedicated rendering owner if measurements justify that migration.
5. Repeat local area transitions, movement/camera and populated-scene steady
   benchmarks. Aim first for16.7 ms p95 frame time on the representative local
   fixture, much shorter area entry, and removal of multi-second stalls;
   document hardware/scene limits and compare against the original client.

The goal is **not complete**. No Arelith connection or input was made for this
work; both local benchmark clients exited and their sessions disconnected.

## Local loading/worker follow-up, 2026-10-21

The user explicitly confirmed there was no current session and authorized local
testing and restarts. Six accepted three-area dense native-server runs now cover
the shader-program cache, an experimental frame work queue, an experimental
automatic-root matrix cache, repeated baselines, and resident PLT palettes. The
endpoint was fixed to loopback UDP5123. The clients disconnected and the owned
dense server was stopped; no Arelith connection was made.

Production now uses `ResourceWorkerPool.decodePlt` for immutable palette sources
from the area's ModelSourceCache. Each worker receives one private palette
snapshot and subsequent jobs send only texture input, colour rows and palette
identity. A worker retains at most one set, capped at8MiB; larger/unfamiliar sets
use the existing ordinary task path. Replacement workers receive the snapshot
again. Separate area pools cannot share it, source buffers are never detached,
and disposal terminates the workers and drops the main-thread snapshot registry.

In each measured area,779 PLT jobs previously sent the full palette set779 times;
the new path sent it4 times and reused it775 times, with zero fallback/failed
jobs. The measured transmitted palette pixel bytes were5,046,272 per area.
The old982,761,472-byte figure is inferred from779 jobs and the same measured
palette-set size, rather than measured network traffic. This is worker cloning,
not a reduction in server downloads. The ordinary decoder and worker output
matched byte-for-byte for256 installed-asset/colour-row cases.74 focused checks
passed, including pool isolation, crashes/replacement, cancellation, ownership,
frame scheduling, graphics barriers and renderer-program retirement.

`FrameWorkBudget` and `RendererTexturePreparation` implement priority queues,
synchronous upload/construction/attachment slices, stale-owner checks and
disposal before awaiting scene sync. Eight real GPU texture frames match
exactly; the native frame-scheduler run drained all three area queues and
source/particle worker pools. Driver operations and constructors cannot be
preempted, and work outside those tasks remains unbounded. The queue remains
**off by default**, because the measured loads and steady frame times did not
show a consistent end-to-end improvement.

The automatic-root cache also stays **off by default**. Although13 matrix/scene
checks and24 main/shadow GPU frames matched, the later warmed baseline
outperformed its native candidate. Its apparent early gain must not be credited
as a causal improvement. Existing explicit managed model matrices remain on.

Final production `index-Cyvjh728.js` passed all three native area visits, with
47–48 moving actors per pass, no failed models or renderer errors, and zero
remaining workers, jobs, geometry owners, model preparation owners or program
leases after disconnect. The executable JavaScript was identical in both tests after excluding the
source-map comment. The tests
produced substantially different FPS results, so these runs establish correctness
and reduced palette copying, **not** a reliable FPS or total-load improvement.
The final run took15.77/17.20/13.84 seconds to reach the probe's complete-world
readiness condition and averaged reported FPS18.0/22.6/24.5. Earlier executable-equivalent
build results were28.9/34.3/26.0 FPS. Visibility, native wandering, camera
rotation, CPU profiling and uncontrolled driver/OS state limit direct comparison.
The stored p95 summaries average rolling windows, not a whole-run percentile.

Frozen checks and full measurements:
`backups/animations/worker-loading-progress-proof-v1.json`, reproduced by
`node scripts/verify-worker-loading-progress.mjs`; installed pixel checks in
`resident-palette-installed-v1.json`; source-mapped CPU summaries for the baseline,
frame queue, root cache and both resident-palette runs are preserved beside them.
The first rejected baseline attempt used an isolated build outside the trusted
application path and timed out; it is excluded. The fixture was corrected to use
the normal dist path without weakening IPC trust checks.

The five-part goal remains **active and incomplete**. Per-object/spatial lighting,
profitable main-draw batching, further dirty-state reuse, broadly effective
frame-budgeted loading, and the60FPS/p95≤16.7ms acceptance are still open. A
render worker remains an architectural evaluation, not an implemented or proven
FPS fix. The next comparison needs controlled camera/view phases and larger
reductions in light/shader and draw/traversal work, rather than more wrappers
around uploads Three already skips.

## Local comparison completed before requested pause — 2026-10-21

The final comparison used only the owned dense local server and offline GPU
fixtures. No Arelith connection was made. The user requested pausing after this
test. The goal remains incomplete; experimental main batching and per-object
light packets remain disabled. Resident palette workers remain enabled.

The main-batch grouping-key cache now avoids rebuilding unchanged material keys
while checking direct render-state mutations every draw. Nine focused batch and
palette tests passed. The combined native keyhole/target shader GPU fixture
matched 32 frames exactly, including shadow output and callback behavior, and
retired its private resources. Its initial failed run used the wrong shader-hook
order in the test harness; the passing fixture uses production order. Production
shader-hook behavior was not changed to address that harness error.

The offline 1,500-object stress test reduced main calls from 1,501 to 48 with
matching final pixels and triangles. CPU median fell from 6.5 to 4.3 ms, and GPU
elapsed-query median from 11.652 to 7.638 ms. These are fixture results, not proof
of an equivalent improvement in the full client.

The full native comparison visited three areas with at least 40 moving actors
per visit. Both configurations passed rendering and disconnect cleanup checks.

| Visit | Batching off load / FPS | Batching on load / FPS |
| --- | --- | --- |
| dense_a | 21.72 s / 21.0 | 17.48 s / 25.1 |
| dense_b | 16.41 s / 25.2 | 16.90 s / 21.6 |
| dense_a return | 13.17 s / 23.4 | 11.88 s / 24.1 |

FPS values average reported rolling windows. Their p95-window averages were
59.1/51.8/54.7 ms with batching off and 46.4/59.1/52.6 ms with it on; these are
not whole-run percentiles. Random native wandering, different camera routes,
CPU profiling and uncontrolled driver/OS state limit causal comparison. Main
draw counts must not have shadow counts subtracted from them: Three reports the
main pass after resetting its counters. Main calls decreased substantially, but
whole-client timing gains were mixed, so batching stays off. Multi-second stalls
and the 60 FPS / p95 <=16.7 ms target remain unresolved. Batch first-use GPU
preparation before area reveal also needs work before enabling it.

The separate point-light packet prototype matched all 32 GPU frames, but its
dense stress case was slower: CPU median 8.3 versus 6.3 ms and elapsed GPU query
median 13.049 versus 10.195 ms. GPU query intervals can include CPU supply
bubbles. This prototype is not imported by the application.

Full results, source hashes and cleanup evidence are preserved in
`backups/animations/dense-local-batch-keys-base-v1.json`,
`dense-local-batch-keys-v1.json`, `main-batches-hooks-v2.json`,
`main-batches-performance-v2.json`, and `point-light-packets-v7.json`/`v8.json`.
`node scripts/verify-main-batches-pause.mjs` verifies their source hashes and
native cleanup, and verifies that the restored normal production executable
matches the batching-off native-tested build after excluding its source-map
comment. It records both full-file hashes separately in
`backups/animations/main-batches-pause-proof-v1.json`.

The normal production build succeeded and experimental batching is off. No
dedicated rendering worker was implemented or established as an FPS fix.
