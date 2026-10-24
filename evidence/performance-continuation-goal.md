# Performance continuation goal — 2026-10-21

2026-10-22 renewal: use the captured server scene as the primary reproducible
offline workload, continue toward sustained >=60 FPS with unchanged appearance,
and make verified source backups before substantial changes and significant
accepted checkpoints. The active goal also retains all original p95, hitch,
fidelity, resource ownership, local native-server and no-automated-Arelith gates.
The first source checkpoint is `backups/captured-room-baseline-20261022.zip`;
see `offline-scene-replay.md` for verification and the complete frozen import.

The user requested an active goal to continue optimizing beyond approximately
25 FPS with shadow-light setting 1. They also authorized increasing memory use
and preloading resources when measurements show a benefit. Automated testing
remains offline or on owned local servers. Preserve the user's session; request
a live server comparison when local evidence is insufficient.

Acceptance remains sustained >=60 FPS, p95 <=16.7 ms in representative heavy
scenes, and no multi-second client-side freezes, with appearance, animation,
interaction, movement, networking and cleanup preserved. The goal is active
and incomplete. The original binary is a read-only guide for unresolved native
selection, scene, particle and rendering behavior.

The user's heavy room is now captured privately and renders offline with a
recorded camera path. Two exploratory replays reproduce approximately 16–17 FPS
without any live server connection. Content-completeness gates still fail;
these are not accepted baseline/gain measurements. See
[`offline-scene-replay.md`](offline-scene-replay.md) for the capture identity,
checks, omissions and reports. The user authorized closing the recording client
after sealing; it is closed, and normal game defaults remain unpromoted.

## Starting evidence

User sample at 3440x1369, shadow setting 1: 24.2 FPS, 41.4 ms average frame,
73.2 ms rolling-window p95, 40.5 ms frame work, 12.9 ms rendering/submission,
9.0 ms particles, 14.5 ms camera/light work, 849 main /208 shadow calls,
43 active lights /128 point shader slots, one shadow map drawn, four particle
workers, zero pending assets/shaders, and an 8433.9 ms worst interval.

Read-only inspection of the latest user log
`runtime-2026-10-22T00-14-49-471Z-06c32766-e11c-4b6f-ace9-f9a7aef804b9.jsonl`
found a frame at UTC 00:16:15.792 (the evening of October 21 locally) with
8328.6 ms total work and 8284.3 ms in rendering. Programs rose from 31 to 37.
This establishes a rendering/program-growth hitch, not network delay or
resource-download time. Its timing is consistent with changing the shadow
setting, which previously changed shadow shader capacity from six to two.
The log alone does not identify each newly compiled program.

An exact executable-matched source map for `index-e9m730-x.js` is preserved as
`native-shadow-policy-source-v1.json/.map`. The earlier owned local native run
has now been symbolized: `dense-local-native-shadows-v2-cpu-summary.json` and
`dense-local-native-shadows-v2-transform-summary.json`. Matrix composition and
scene traversal dominate substantial CPU samples. Transform-only samples
attributed to `prepareRendererLights` account for 2.46/3.00/2.68 seconds in
roughly 21-second steady profiles. Inclusive source totals overlap and are not
subsystem timings; the run was background/offscreen with concurrent client
load, so it is not a controlled FPS comparison with the user's scene.

## First fix

All supported shadow settings now reserve the same six point-shadow shader
slots (plus non-model lights, subject to hardware limits). Actual selected
shadow lights continue to obey settings 1–3 and the native lists/fades.
Neutral slots have zero intensity and allocate/render no shadow atlases.
This avoids changing every lit program merely because the user lowers the
shadow draw workload. The frame's 128 point-light pool remains a separate
optimization problem.

Seventeen focused tests pass, including settings 1/2/3, native original-code
selection/fade cases, bounded selections, unchanged illumination and retirement.
The updated real GPU fixture passes twelve frames while changing 3→1→3:
selected lights change 3→1→3, and the policy's compiled program count stays at
two throughout. Direct rendering with changing actual shadow counts adds a
third program. Policy/reference pixels match exactly in all twelve frames.
This proves shader-profile reuse for the fixture, not a measured live FPS
gain or full original stencil-shadow pixel parity. Artifacts:
`native-shadow-policy-v4.json`, `shadow-setting-profile-gpu-run-v1.txt`, and
`shadow-setting-profile-unit-v1.txt` under `backups/animations`.

## Next work

1. Split camera/light timing into camera queries, keyhole, audio/labels/picking,
   world matrices, membership traversal, light selection, sampler budgeting and
   uniform-slot maintenance. Keep measurement overhead bounded and compare
   whole-client results with fixed camera phases and deterministic actor/light
   workload. Preserve a normal rendering control.
2. Reduce repeated world-matrix and membership work with explicit producer
   invalidation. The earlier generic root-cache wrapper was not consistently
   faster and stays off; use the profiled call sites and validate moving,
   reparented, hidden, skinned and newly attached objects.
3. Profile particle simulation, pose sampling, vertex capture/upload and worker
   serialization separately. Four workers already exist; preserve native RNG,
   event/collision ordering and animation timing before moving more state.
4. Reduce unnecessary lighting/material submission work and point shader pool
   size while maintaining stable variants. Revisit the original binary's
   per-object/static light paths when replacement heuristics lack evidence.
5. Use the authorized memory allowance for resource-context-keyed decoded
   source retention, bounded texture/resource caches and prewarming known
   shader variants. Measure residency, hits, eviction and retained ownership.
   Existing program retention (128 references, 8 MiB source accounting) was
   not shown to be saturated in the starting scene; simply raising that limit
   is not established as a fix. Preserve invalidation across module/HAK/
   workshop changes, disconnects, cancellations and context loss. Driver GPU
   allocation is not represented by source-string byte accounting.

Request a live user-server comparison after a locally validated candidate needs
the representative room's content. No live connection or input is authorized
merely by the user's offer to log in when asked.

## October 22 UTC: local profiling and picking reuse

The user closed the game and authorized local tests. No Arelith connection was
made. `dense-local-camera-stages-v1.json` completed three native area visits
and full cleanup with zero renderer errors, at 3440×1369. Loads were
13.57/11.31/9.63 seconds. This is a different authored scene from the user's
room, not proof of those room's load times or FPS. New bounded stage timings
separate camera/audio, keyhole, labels/picking, world matrices, membership,
light selection, shadow budgeting, light slots and debug metadata.

Two candidates remain **disabled**:

- Managed matrix reuse preserved the GPU fixture's images and matrices but
  was slower in the alternating CPU benchmark: ordinary/reuse medians
  0.716/0.956, 0.783/1.122 and 0.756/1.250 ms at 0/12.5/100% moving Parts.
  See `managed-matrix-reuse-cpu-v1.json`.
- Scalar native pose transfer avoids per-Part temporary arrays and quaternions
  while preserving float field reads and quaternion operation order. The
  authored CPU fixture improved 3.529→0.560 ms, all 32 GPU frames matched,
  and 27 focused regression tests passed. However the native local comparison
  did not show consistent whole-client gain: paired FPS changes were
  +7.3/−6.7/+4.8/+1.2%, and this scene primarily exercises ordinary decoded
  playback. This is insufficient evidence to enable the native-pose candidate.
  See `pose-transfer-cpu-v1.json`, `pose-transfer-v1.json`, and
  `dense-local-pose-transfer-ab-v1-comparison-summary.json`.

The accepted change shares synchronous world-picking work between hover
highlighting and the pointer. Network picking previously updated the full
world twice per query, before independently raycasting for each consumer.
`WorldPickFrame` updates the world once when needed, shares identical ray
intersections, preserves each consumer's player/usable/occlusion filtering,
and drops all cached hits at the end of the presentation scope. Clicks outside
that scope get fresh matrices and intersections. No cache survives a frame,
movement, area change or disconnection.

`dense-local-picking-ab-v1.json` used the same running native scene, fixed
camera and pointer, four alternating pairs, 3 seconds settling and 9 seconds
measurement per mode, with CPU profiling active equally. Moving actors cause
draw-count variation (candidate draws were 0.9–2.5% lower); this is not a
perfectly deterministic renderer replay. FPS improved in all four pairs by
7.82/6.75/7.22/4.94%. Medians across phase metrics:

| Metric | Ordinary | Shared picking |
|---|---:|---:|
| FPS | 28.69 | 30.13 |
| Frame work | 34.7 ms | 32.6 ms |
| Camera/lighting bucket | 13.0 ms | 9.7 ms |
| Render submission | 16.6 ms | 16.4 ms |
| Median two-second p95 | 41.2 ms | 36.9 ms |

All owners retired and renderer errors were empty. The exact source map
`picking-ab-source-v1.json/.map` matches that test bundle. Nineteen focused
picking/portal/highlight tests passed. `world-pick-frame-v1.json` also passed
real Chromium pointer/Tab, hover/attachments, wall occlusion, invisible/menu
occlusion, click-through, live text/visibility, area and disconnect checks.
Shared picking is enabled by default; `VITE_REUSE_WORLD_PICKING=0` remains an
explicit control. Comparison-only window hooks are compiled out of normal
builds. Native pose and generic matrix reuse remain opt-in and off.

Acceptance remains **unmet**. Rendering (~16 ms), ordinary animation/world
transforms, raycasting, material/sampler scans and scene traversal still need
work. This local fixture's particles (~2 ms) do not represent the user's
9 ms particle workload; do not infer that it is solved. Next work should
continue from the measured ordinary playback and picking stacks, improve
deterministic local actor/camera workloads, and retain the shader-profile fix.

Normal production verification: `index-BAyXpSOG.js` (SHA-256
`9a3c9071e9723acbd81919dd875845efbd72524a84a35e6267913f4c7dc9009e`)
completed `dense-local-shared-picking-production-v1.json`: three native area
visits, 48/48/45 moving actors, loads 15.49/13.20/9.22 seconds, empty renderer
errors and all three worker/resource owners retired. Observed phase mean FPS
29.84/31.01/36.91 is descriptive only; random NPC walking and camera rotation
make these different phases unsuitable as a before/after estimate. Thirty-six
focused checks pass. `shared-picking-production-proof-v1.json` binds the exact
source-map contents, production bundle and validation artifacts. The client
exited and the owned dense server was stopped after testing; no user game was
reopened or external server joined.

The next owned-tile matrix-walk experiment consistently removed about 0.5 ms
from world-matrix preparation, but full-client FPS/frame results were mixed.
It remains disabled. Exact current/historical source identities, 32-frame GPU
parity, 30 focused checks, native coverage/cleanup and next submission targets
are recorded in `renderer-matrix-subtree.md`. Normal build CTP8rA1Q boots with
the experiment disabled and no joins/fetches. The overall goal remains active.

The next continuation found and fixed duplicate target-preview shader hooks
when keyhole clones an already-bound material. Compressed static tile arrays
reduced native local main draws by about 30%, but remain disabled: the whole
client gain was modest/mixed and cold activation still hit 656 ms. The user's
new teleport log independently shows source preparations continuing for 68.56
seconds after area start, long after tiles and area shader preparation. See
`teleport-loading-followup.md` for the timed evidence, unknown network-arrival
portion, rejected/confounded experiments and current normal-build validation.
The goal remains active; overall acceptance is not achieved.

Prepared-model persistence now has an opt-in disk/worker implementation and
renderer context reuse, but stays OFF by default. A twelve-visit same-client
comparison found resident reuse improved two hot transitions by 5.31/18.18%,
while restoration regressed by 6.62/4.95% and FPS remained mixed. Saving model
parsing alone (about 151 ms of worker CPU in a measured area) does not explain
the live minute-long tail. See `prepared-model-cache.md` for exact artifacts,
96 focused checks, installed-model roundtrip, GPU parity, current default-off
normal build and next resource/texture-queue work. The owned server is stopped
and no Arelith connection was made. Overall acceptance remains unmet.

The user then reported an active game and requested test preparation only.
`scripts/performance-queue/README.md` describes a deferred 38-group queue:
38 new authored cases plus existing regressions, three GPU fixtures, a native
installed-model roundtrip, five local scenarios totalling 24 area visits and
a final normal-build boot. New audit-only candidates cover current texture
consumption and hidden editor-preview hierarchy costs. A local resource probe
records API metadata and post-disconnect model consumer audits; a separate RAF
observer retains rare frame gaps and loading freezes. The staged runner has
explicit execution, live-game guards, source/build hashes, fail-fast reports,
unique outputs and exact owned-server leases. All new tests remain UNEXECUTED;
no build, server, connection or client restart was run for this preparation.
Production source and dist were preserved. No performance gain is claimed;
the optimization goal remains active and acceptance remains unmet.

The user subsequently authorized execution. Thirty CPU groups, three GPU
fixtures, an installed-model audit and 24 local area visits passed; the paired
preview comparison failed before entry because its isolated document was
rejected by IPC. That trust configuration is corrected, but the paired run
and final normal boot still need execution. Historical native timing endpoints
include profiler-stop overhead and are exploratory. At user request an isolated
ten-candidate diagnostic client was then launched; the user connected manually.
The supplied heavy-area sample reports 18 FPS, later settling near 24–25 FPS,
with persistent render, camera/light and particle cost and a two-second render
stall. No representative acceptance or new proven default is established.
The next default-off candidate short-circuits input inspection for shadow maps
that already require a redraw; twelve focused checks pass. See
`performance-live-candidates.md` for exact evidence, limitations and deferred
validation. The running client/build was not changed during the follow-up.
