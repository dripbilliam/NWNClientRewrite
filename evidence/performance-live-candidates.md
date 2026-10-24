# Experimental live performance follow-up — 2026-10-22

The optimization goal remains active and acceptance is unmet. The current
user session is preserved. No automated live-server input, connection,
restart, flag change or benchmark was performed during this follow-up.

## Executed queue evidence

All paths below are relative to `runtime-logs/performance-queue/`.

* `queue-2026-10-22t04-28-31-997z-ab1eb0/summary.json`: 30 CPU groups,
  244 checks passed. Later preview graph checks fixed a circular emitter/RNG
  fixture assumption and passed 10 cases. Initial failed runs are retained.
* `queue-2026-10-22t04-32-38-227z-5de77b/summary.json`: three GPU parity
  fixtures and installed native-model roundtrip passed. These establish
  correctness of those fixtures, not a whole-client speedup.
* `queue-2026-10-22t04-35-25-880z-43b400/summary.json`: five owned local
  scenarios passed, totalling 24 visits with retirement checks. **Profiler
  stop overhead contaminated observation endpoints.** Their maxima/loading
  durations are exploratory and must not be used as isolated game-hitch or
  strict speedup evidence. The probe now stops observation before stopping
  the profiler; matched comparisons need to use that corrected version.
* `queue-2026-10-22t04-47-36-261z-171068/summary.json`: preview comparison
  failed before any area loaded. IPC rejected the isolated build document.
  This is not an FPS result. Exact-document URL configuration is corrected;
  43 launcher/IPC/debug/profile checks passed in console output. The native
  paired comparison and final normal boot remain pending.
* `live-v3/build.json`, `live-v3/offline-smoke-v2.json`: isolated diagnostic
  build and offline controls/menu check passed. Ten candidates were enabled
  at user request, with a baseline switch. The user joined Arelith manually.

Normal `dist/assets/index-iKrqbPaC.js` remains SHA256
`602ad6067124d175a23344a9ffd961d334ae6459cc0e075a386891876543b5bc`.
The existing build is not rewritten by this follow-up.

## User sample and subsequent read-only log evidence

User attachment: `Pasted text.txt`, attachment id
`bb134b0b-87ac-40c9-aafc-2ca85e675951`. Runtime log:
`runtime-2026-10-22T05-13-10-325Z-e55fbad4-1bf5-4fd2-bacb-0ceb32364f65.jsonl`.
Area `udcityhubint` / 2147625684. All ten requested flags match area settings.

The attachment records 18.04 FPS, 55.43 ms average, 81.7 ms p95, with mean
render 20.13 ms, camera/light preparation 12.27 ms and particles 8.73 ms.
Its render buffer is **1424 × 921**, not the earlier 3440 × 1369. These are
not matched before/after measurements.

The live log later settles near 24–25 FPS, roughly 17.8 ms render, 9.2 ms
camera/light preparation and 8.1 ms particles. Source prefetch is then empty.
This improvement over entry is not evidence for a particular candidate:
loading, camera/caster membership and scene content also changed.

One admitted shadow light submits 1,020 shadow draws in the attachment;
later samples show approximately 730. The count covers all point-map faces.
The material-state reuse counter is zero. Static texture batching reduces
555 original opaque entries to 409, but that draw reduction does not establish
the requested frame-rate gain. Light-uniform reuse does report skipped uploads.

Resource decoding workers are idle at the sample. Their cumulative decoder
CPU is 427 ms, while resident prepared sources report zero hits in this first
context. Generic decoding workers and a larger model cache cannot by themselves
explain or solve the steady frame cost. The attachment still has 23 queued
prefetch requests and two pending; later samples finish them. The serialized
whole-object preparation pipeline remains a separate loading investigation.

At 05:14:24.703Z, a frame records 2,036.8 ms render time and a program-count
change from 19 to 20. This is evidence of a render stall coincident with a new
program; it does not isolate all that time as shader compilation or GPU time.
Generic shader preparation has not eliminated cold first-draw stalls.

Particle availability is also incomplete: 258 failures name fxpa_cloud02,
with additional missing bitmap/provider failures. These are counted separately
from performance; missing effects must not be credited as optimization gains.

## Next isolated changes, not applied to the live client

The cache previously inspected every caster even after a producer returned an
uncacheable stamp. The opt-in `shortCircuitVolatile` candidate now immediately
returns `reuse:false` with no input baseline at that point. Rendering still
uses the complete selected caster list. After removing a volatile producer,
a complete rendered baseline is required before map reuse can resume. Normal
construction defaults to false; no speedup is claimed yet.

The next diagnostic build has an eleventh `shadowInputs` flag, independent
of the existing candidates. A diagnostic-only profiler separates shadow
submission, input inspection and grouping from total shadow work, and captures
particle runtime separately from the enclosing frame stage. Durations are
inclusive synchronous CPU/driver waits, not GPU time; nested values must not
be added together. Particle vertex-worker state is included in copied telemetry.

Twelve focused correctness checks passed in console output: six cache tests,
two profiler tests and four private-build/profile tests. They cover live
mutation, volatile removal/re-baselining, default-off behavior, timing nesting,
exception propagation and ownership-safe restoration. No new GPU/native
comparison or build has run while the user is playing. Before promotion,
require exact color/shadow parity and alternating same-scene whole-client
comparisons, including moving casters and transitions.

## Shadow-input continuation and local rejection

`runtime-logs/performance-queue/shadow-inputs-v1/gpu.json` passes 19 exact
color/six-face map cases in each mode (38 total). Volatile movement, texture
alpha changes and full baseline recovery are included. Fifteen focused checks
pass with raw TAP retained in `unit-console.txt` in that directory. The isolated
`build.json` and `offline-smoke.json` pass; normal dist remains unchanged.

The twelve-visit `local-comparison.json` is **failed**, not accepted performance
evidence. Every area records 336 emitter entries, including 208 failed entries;
the particle guard correctly rejects the summary. Raw steady FPS is about
36–38 after warmup, but does not support a candidate improvement or promotion.
In much of this camera path only a directional shadow pass is active; no
volatile input shortcut is observed in the sampled late frames. A future local
fixture must retain its point-shadow workload and have functioning particle
providers/resources before it can prove the desired heavy-area benefit.
The summary guard is retained, rather than relaxed to accept missing effects.

The owned DensePerf server PID 42308, creation
`2026-10-22T05:33:00.2604370Z`, was stopped after the failed comparison using
its exact lease. Other servers were preserved. The first manual Ready query
lost timestamp precision through PowerShell's automatic JSON date conversion;
revalidation with `-DateKind String` confirmed the same leased server ready.
No replacement server or duplicate test client was started. Because the run
failed before its post-disconnect assertions, it also does not establish the
complete retirement acceptance gate.

The user offered another manual Arelith observation. The isolated diagnostic
build is suitable for observation, not a claimed faster release. It exposes
the eleven test flags and separates inclusive shadow input, grouping and draw
submission timings, alongside particle runtime and vertex-worker state.
