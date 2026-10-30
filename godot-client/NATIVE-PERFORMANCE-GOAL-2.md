# Native performance gap: second optimization goal

Started 2026-10-27 at the user's request. Active; no overall performance or
native-client parity acceptance. Starting verified source checkpoint:
`backups/native-loading-compact-options-v1.zip`, SHA256
035304f1b9538ab04b8355432efe9034a3c9ad4afcb656b7984b21fd27dc86d9.
The earlier six-stage research and receipts remain historical reference.

## Authorization and acceptance

Investigate and test ambitious changes in isolated candidates. Obtain user
approval **before promoting a drastic change as the main/default method**.
Before that request, prepare the implementation, comparable timing receipts,
visual/behavior checks, limitations, risks and a verified rollback checkpoint.
Ordinary reversible fixes/instrumentation remain authorized. Never silently
reduce required content, break authoritative protocol/resource precedence, or
substitute node counts and passing checks for actual performance improvements.

No automated public/Arelith connections. Use frozen recorded resources and owned
local Prelude/server tests. Original binary and analysis database are read-only;
no patch/injection/annotations. Preserve original geometry/textures and private
per-creature state. Native Godot remains the rendering owner. Compact scenery
stays a persistent opt-in choice, default off, per the user's decision.

## Measured priorities

1. Attribute the 100–140 ms outside-callback stalls with engine-level evidence.
   Current asynchronous CPU/GPU readings and zero compilation deltas on some
   rows do not identify their cause. Check deferred work and profiler overhead.
2. Isolate and reduce old-world hide/processing disable, combined35–36 ms in the
   dense manual scene. Preserve immediate removal of stale input/physics and
   correct worker lifetime. Small Prelude timings do not prove dense behavior.
3. Reduce source/template construction and scene-entry work (sampled7–13 ms
   components), retaining bounded player-centric publication and all assets.
4. Investigate scheduling, rendering/culling/submission and lifecycle methods
   against the original binary when evidence is missing or an approach stalls.

Measure cold/warm area readiness, player/camera delay, pop-in, steady frame CPU/
GPU, p95/p99/hitches, memory and draw/submission cost. Match content, camera,
resolution, preferences and process contention for comparisons; isolate setup,
diagnostic captures, warmup and profiler overhead. Record unavailable matching
native evidence as a limitation, not proof of parity.

## Evidence and decisions

- Current122-check scoped option audit plus complete630-entity offline and
  authoritative19-entity Prelude load: native-loading-compact-options-audit-v1.
- Automatic ready PNG capture is opt-in; its measured1-second work is removed
  from normal play. Empty collision model lookup no longer logs errors.
- Compact Parts preserve exact original pixels/queries and remove about23% of
  scene nodes; short comparisons show no established steady FPS benefit and do
  not establish a statistical regression. Keep the optional choice while broader
  memory/transition measurements remain open.
- Earlier prototype clone, material-order and separate-render-thread candidates
  remain archived with their failures/limits. Do not relabel them as improvements.

First next action: inspect installed engine profiling/frametime API boundaries
before choosing a new mechanism for the remaining unassigned stalls. The goal
requires measured progress; it is not completed by this plan or a new profiler.

## First investigation outcome

See `NATIVE-PERFORMANCE-ENGINE-TIMING.md`. Installed-version engine setup and
pre/post draw timing is now recorded without a forced GPU fence. A complete
630-entity offline observation distinguishes callback stalls from render work;
it does not reproduce the denser manual area's100–140 ms gaps. Profiling summary
construction itself reaches10.866 ms in that capture. Two exact packed-numeric
GDScript candidates were slower on the synthetic workload, archived, and removed
from production. The original summary algorithm and all rendering policies remain.
The final timing-only build passes native API/UI checks and owned local loading.
Next evaluate bounded data-only background or compiled statistics, then isolate
dense-scene engine waits/culling with the same approval boundary for drastic
default changes. Routine new counters do not constitute a performance win.

## Accepted diagnostic work

`NATIVE-PROFILER-WORKER-SUMMARIES.md` records the bounded data-only worker,
unchanged statistic semantics, generation rejection and full owned-job cleanup.
It removes roughly11.5 ms summary calculations from the frame thread in two
short recorded-area comparisons, without establishing improved steady FPS.
The default applies only to detailed profiling; rendering/asset methods and the
drastic-change approval boundary remain unchanged. Current99-check scoped
regressions, complete630-entity default playback and owned Prelude19-entity load
pass. P99 is now also reported for the retained frame interval window. No public
connection or overall performance/parity acceptance is claimed. Rendering costs,
dense transitions and unassigned engine waits remain the next required work.

## Live-test handoff after the next comparison

`NATIVE-PERFORMANCE-CLEAN-WINDOWS.md` records explicit non-persistent profiling
overrides, runtime/configuration pins and offline post-completion measurement
windows. Both630-entity six-second runs finish cleanly, but focus and observed
draw workload differ: no causal throughput improvement is accepted from this
pair. Keep the diagnostic controls and the previously validated summary worker;
no new rendering method is promoted. Automated tests stop here for the user's
requested live test. Overall optimization/native parity remains unaccepted.

## User-directed live animation follow-up

See `NATIVE-ENTITY-INSPECTOR.md`. Investigation of the reported Skrul'nak bind-pose
walk found exact-string MODELTYPE classification inconsistent with the original
binary's compound flags (the saved server row usesFW). The native classification
is corrected without hardcoded server/NPC IDs; a local, explicit entity inspector
can export received and private playback evidence after restart. Headless checks
pass; visual confirmation for this NPC is pending. These are compatibility and
diagnostic changes, not evidence that the overall performance gap is resolved.
No automated public connection or competing graphical benchmark was made.
