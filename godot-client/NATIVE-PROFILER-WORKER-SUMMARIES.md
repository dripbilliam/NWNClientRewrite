# Bounded background profiler summaries

2026-10-27. Detailed profiling now computes numeric window summaries on one
low-priority data-only worker. Rendering, scene publication, gameplay and server
protocol execution remain on their existing paths. This is a routine diagnostic
change; it does not promote a new rendering/loading method or establish parity.
The synchronous reference remains available via `--profile-summary=main`;
offline replay also accepts explicit `worker`. Profiling off starts no new jobs.
Compact scenery retains the user's persistent opt-in choice, default off.

## Ownership and behavior

`frame_summary_job.gd` uses the unchanged summary calculation. A copied Array of
at most the normal240 immutable numeric frame dictionaries is passed to one
owned task. No worker reads Nodes, GPU APIs, scene resources, files or network.
It clears the private input Array before returning, keeping final release of
evicted numeric rows off main. Results are read only after completed-task join.

Until the first result, the UI displays collecting statistics and the snapshot
explicitly reports pending. Completed summaries describe their captured window,
with a capture timestamp and policy label; they are not a current-frame reading.
The existing500 ms refresh interval remains. Profile enable/disable and control
mode changes increment a generation; old results are discarded. At most one
packet is in flight. Exit/destruction drains the owned task, including a profiler
freed without entering the SceneTree. Asset-worker and summary-worker lifetimes
are separately exposed; both must drain. Waiting in normal presentation occurs
only after a task reports completion; shutdown may join an in-flight task.

## Same-source observations before default promotion

All `native-goal2-summary-area{3,4}-{main,worker}-v1` observations complete the
same sealed inputs/all441 or630 entities with clean engine/lifetime gates. Area4
runs main first; area3 reverses order. The exact authored candidate is preserved
in `native-goal2-summary-worker-candidate-v1.zip`, SHA256
c6ecbb2b88010230e2d551b4ffc210262ebf33c69491148b084428f0e3c25ea7.

| Area | Summary mode | Main summary peak ms | Adoption peak ms | Frame p95 ms | Worst interval ms | >50 ms intervals | Last sampled FPS |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | Main | 11.492 | 0 | 16.282 | 89.479 | 2 | 164 |
| 4 | Worker | 0.026 | 0.502 | 16.130 | 35.204 | 0 | 157 |
| 3 | Worker | 0.027 | 0.205 | 18.963 | 39.490 | 0 | 177 |
| 3 | Main | 11.562 | 0 | 19.912 | 40.786 | 0 | 179 |

Whole retained-window means are area4 main7.662/worker7.764 ms and area3
main7.526/worker7.328 ms. Frame interval summaries include loading, while the
last FPS sample and rolling summaries have different windows. These short
single comparisons do not prove a general hitch-rate or throughput improvement.
Steady FPS did not improve. The accepted benefit is removing measured summary
calculation from the frame thread; overall native performance remains unaccepted.
Worker task durations still consume CPU and may compete for allocation/bandwidth.

## Validation

The52-check oracle/lifecycle fixture pins the unchanged previous authored profiler
from `native-goal2-engine-frame-timing-v1.zip`. It checks exact numeric field
order, sum precision, negative/zero/sparse values, decimal cancellation, p95/max,
worst-frame ties, empty windows, actual off-thread execution, immutable caller
input, stale-generation rejection, bounded ownership and both destruction paths.
The synthetic example queues in0.044 ms while its worker calculation takes about
15 ms; those are diagnostic timings, not game benchmarks.

Final current-source checks:
`native-goal2-summary-final-{exact,options,api}-v1`:52+36+11 checks under normal-heap
CDB, with full engine/lifetime gates. The actual Options test supports bounded
waiting for the first asynchronous summary; its separate arithmetic fixture
explicitly uses the synchronous reference. No assertions were waived.
`native-goal2-summary-default-area4-v1`: default worker path, all630 entities,
closed/drained summary owner and no engine errors. Frame intervals now also
report p99 from the retained sample window; older comparison receipts lack it.
`native-goal2-summary-default-local-v1`: authoritative Prelude19-entity load,
11 summary jobs complete, no pending summaries/assets and finish acknowledged.
No public connection was made. Scope remains the recorded and local inputs.

Frame interval sampling is bounded (the existing4096-sample history compacts
to2048); long-session percentiles/hitches are retained-window measurements, not
unbounded lifetime totals. The dense manual room's35–36 ms transition disable
and100–140 ms unassigned gaps remain open.

## Next rendering investigation

Do not assume actor skinning dominates: the saved dense30-FPS observation's
rolling callbacks average about1.95 ms root,1.78 ms world and0.52 ms rigs, with
8.28 ms outside callbacks. Those differing windows cannot identify a cause.
Investigate engine setup/culling/submission and draw batching, including real
lights, original physical queries, transparency and independent state. First
separate clean rendering performance from detailed profiling overhead. Any
drastic replacement/default method still requires user approval after a tested,
reviewable candidate and verified rollback checkpoint exist.
