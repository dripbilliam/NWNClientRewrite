# Captured-room continuation, 2026-10-22

The user resumed the performance goal, authorized larger renderer changes if
Three.js options are exhausted, and retained the visual-fidelity requirement.
Only the frozen room was replayed. No Arelith connection or interaction was
performed. Normal `src/main.js` and `dist` were not changed.

Current continuation: full offline testing resumed after explicit user
authorization. Steady room controls are about 19 FPS; no tested renderer
experiment has approached 60 FPS. Point masks have passed the independent
target check; command/merged backends have remaining pixel differences and
remain unpromoted. Verified source checkpoints retain each major experiment.

## Earlier measurement interruption (ended by explicit authorization)

The user subsequently reported running another game concurrently. Performance
measurements are deferred until that game is finished. No replay remains
running; no further benchmark is queued. Timings from this continuation are
**confounded**, cannot establish a speedup, and cannot satisfy the 60 FPS goal.
This also limits interpretation of the earlier serial atlas comparisons,
which showed substantial control drift. Retain their raw reports, not a
promoted performance conclusion.

## Shadow geometry atlas

`src/renderer_shadow_atlas.js` is a private-build experiment combining different
rigid shadow geometries with per-object matrix textures and optional multi-draw.
It retains source hierarchy, source resources, full draw order, face-frustum
membership, alpha behavior, and unsupported-producer fallbacks. Front-facing
and two-sided shadow surfaces retain original draws: an authored point-shadow
case differed by one packed depth ULP. That gate was not loosened.

`runtime-logs/performance-queue/shadow-atlas-v1/gpu-v12.json` passed 40 authored
exact color/shadow comparisons across multi-draw and portable index paths.
Eight focused CPU cases passed before the pause. Context loss/restoration and
representative full-room visual comparisons remain required before promotion.

`baseline-a2`, `atlas-b1`, `atlas-b2`, and `baseline-a3` in that directory imported
898 objects / 1,077 models / 1,357 emitter entries, with zero new model failures,
zero resource gaps and zero console errors. The same 700 unsupported emitter
entries occur throughout; these are existing missing behavior, not solved.
The atlas reduced sampled shadow submissions from 781 to 554. Confounded frame
times did not establish a gain, and it remains disabled in the normal client.

The replay still fails its original recorded-frame parity gate because that
frame was partially loaded (896 objects / 1,044 models / 1,351 emitter entries).
Completing the import is not proof of exact native rendering parity. Do not
silently relax this gate.

## Compiled main projection and broader batching

`src/renderer_flat_scene.js` compiles transform-only ancestry out of Three's
main projection walk. It retains source parents, visibility/layer behavior,
group render order and source draw identity. The full source children are
restored for shadow rendering/direct submission. Unknown callbacks, LOD and
unsupported passes use ordinary traversal. No source geometry/material is
cloned or disposed by this owner. A subsequent source review tightened unknown
callback checking inside retained renderable subtrees; the final tightening
now passes its five CPU cases. Its GPU fixture still needs rerunning.

Five CPU cases and 18 exact authored color/shadow GPU cases passed for the
initial implementation (`flat-scene-v1/gpu-v1.json`). These are correctness
results, not timing acceptance. The private replay build additionally allows
all eligible rigid opaque meshes to use the existing batcher, rather than only
static tiles. Production eligibility, defaults and source remain unchanged.

`flat-scene-v1/compare-v1.json` ran baseline, compiled projection, broad batching
and both together, then reversed the order in one offline instance. It used
`index-pxIDaEst.js`, SHA-256
`dab6a38b4e332a85f2c74ebbcb8cc24cafe6987187614d36799f15b4f7591baa`.
All configurations retained 898 objects / 1,077 models and produced no missing
resources or console errors. Compiled projection submitted 4,810 source objects
instead of walking 20,551 hierarchy nodes through Three's projection function.
Broader batching reduced sampled main submissions from 2,208 to 1,358.
FPS varied substantially and is invalid as a speedup estimate due to concurrent
game activity. Rerun with the other game closed, and verify full-room visual
and callback/resource-lifetime behavior before considering promotion.

The renderer reports ANGLE / NVIDIA GeForce RTX 5070 Ti / Direct3D11; software
WebGL was not established as the cause. An exploratory visible-window control
changed buffer size and requested additional UI portraits, so it is not a
matched baseline. The replay now records GPU/build/harness identities and can
compare modes within one instance. Preserve offscreen/visible and exact buffer
dimensions in future comparisons.

## Prepared zero-contribution light experiment

`src/renderer_zero_light_work.js` is **not wired into any application build**.
It prepares a shader guard around the existing point-light body. It retains
the authored light list, shadow sampler order, attenuation and shading for all
contributing terms. A conservative bounding cube excludes points beyond a
finite light cutoff; zero-color padding is excluded only for safe nonzero
finite vectors. Invalid numeric inputs retain the original shading path.

Two CPU tests passed before the concurrent-game report. GPU pixel/shadow parity,
native material diversity, exceptional/context restoration and actual frame
benefit are untested. Prepare those GPU checks before any captured-room trial.
Do not infer a gain from fewer arithmetic operations or enable it by default.

Source preparation continued while measurements were deferred. Review found
that disposing the experiment could leave a compiled program's guard enabled;
disposal now resets owned live program flags to the ordinary shading path,
restores the preceding GL program, and preserves later owners' hooks/chunks.
The owner now handles replacement WebGL state after context restoration,
forgets lost/retired handles, avoids touching programs without its uniform,
rejects duplicate installation and disposes idempotently. All seven CPU
regression cases now pass as part of the 34 focused checks described below.

`scripts/renderer-zero-light-work-fixture.mjs` and
`scripts/performance-queue/probe-zero-light-work.cjs` prepare 32 comparisons
against separately compiled, unmodified Three programs. Coverage includes
Lambert/Phong/Standard materials, point shadows, 64/128 light layouts, neutral
padding, finite/infinite cutoffs, animated lights, zero intensity, negative/zero
decay, alpha/transparency, layer edits, negative scale, orthographic camera,
context restoration, toggling and post-disposal pixel/shadow parity. These GPU
checks remain **UNEXECUTED**. The runner requires `--run`, refuses other running
games, records source hashes, blocks external requests, uses a private temporary
profile and reports a bounded deadline. No game, benchmark, build or server
was launched during preparation or the later CPU-only checks.

## Prepared measurement corrections

While GPU runs remained deferred, the replay harness was revised to retain
full RAF observations for loading and each measured phase, together with
completed render counters and start/end scene/resource identities. The former
rolling 15-second window omitted the beginning of the 20-second phase and could
miss a trailing stall. The new pure summary includes any unfinished tail in
elapsed/worst time, rejects dropped/truncated or mismatched frame coverage,
and checks exact camera, render buffer, flags, shadow maximum and fully drained
model preparation. Canonical render-eligible IDs are reconstructed separately
from decoded input, rather than trusting the renderer's object count alone.
Hidden/unsupported model rules are not inferred by this canonical membership
check; it is a conservative content gate, not a native visibility oracle.

The new report requires explicit `--uncontended` metadata before timing inference,
rejects profiling overhead, and invalidates comparisons with more than 5% drift
between repetitions of any mode. This flag records an operator-confirmed idle
machine; it does not discover arbitrary other games or establish GPU isolation.
The existing recorded partial-frame parity result stays separate and unchanged.
The summary cannot enable a candidate or complete the multi-scene goal.

Eleven CPU regression cases for the measurement/content gates now pass,
including the trailing-stall case. The full focused run passed 34/34 cases:
measurement guards, revised light-owner cleanup, tightened projection ownership,
capture/replay resources and diagnostic-transform regressions. The receipt is
`runtime-logs/performance-queue/replay-measurement-v1/focused-unit-receipt-v1.json`;
it records the observed test command/counts and source-contract hash, rather
than claiming to be raw TAP output.

The CPU-only private capture audit also passed. It reconstructs 939 canonical
objects and 898 render-eligible IDs (885 placeables, 8 creatures, 4 doors,
1 ground item), exactly matching the historical complete replay inventory.
`canonical-content-v1.json` in that directory records the verified timeline
hash, canonical IDs and resource-inventory hash
`a5202c7ad5157dfe67ac95d39f03c56cecaf1d012e59e41e9c2f2d5a6baa79b4`.
This validates content membership, not native appearance or performance.

Actual GPU/replay execution of the revised harness remains deferred. A new
private build is needed for the completed-frame marker hooks before future
comparisons. Normal source and dist remain unchanged. No GPU tests,
server/client launch or benchmarks ran during these CPU-only checks.

## Checkpoints and next work

### Authorized GPU and complete replay execution, 2026-10-22

After the user released the machine for full testing, the shadow atlas passed
40 exact GPU cases and compiled projection passed 18. The first zero-light
fixture timed out while Steam NWN was launched during the run; the separate
instrumented repeat completed all 32 frames but failed eight pixel comparisons.
Shadow maps and cleanup matched. Frames 1 and 20 differed with the guard off,
so compiler/source variance remains a hypothesis, not an established cause.
The guard remains excluded from room builds and production.

`runtime-logs/performance-queue/clean-replay-v1/compare-v1.json` contains the
complete eight-phase offline comparison. All phases retained 898 objects,
1077 models, 1357 emitter entries and the independently verified complete
resource inventory. There were no resource gaps or new object failures. Main
draws fell from 2214 to 1364 with broad batching, without a useful FPS gain.
Full observed rates were 17.17–18.26 FPS, with 60.9–67.4 ms p95. No steady-state
phase froze for one second; the loading observation still had a 1951 ms gap.
The baseline repetitions drifted 6.33%, exceeding the unchanged 5% gate;
`summary-v2.json` therefore rejects timing inference and promotion.

The endpoint validator now allows one nanosecond for floating-point roundoff
around the existing 100-microsecond clock tick tolerance. The actual captured
endpoint regression passes, and another 10 microseconds of missing coverage
still fails. All 12 measurement tests pass; raw reports are unchanged.

The fresh diagnostic CPU profile (`profile-v1.cpuprofile`, source-mapped in
`profile-summary-v1.json`) covers 21.845 seconds. Three renderer self time was
6.249 seconds, Three core 2.733, model_particles 1.133, main batches 1.049,
shadow traversal .778, light uniforms .777 and shadow budget .748. Garbage
collection sampled 1.252 seconds. These are sampled CPU times, not GPU times;
the profiled 18.1 FPS result is diagnostic only. This motivates reducing
repeated storage construction and audits before drawing architectural claims.
The room has only 115 active emitters; 542 empty and 700 unsupported entries
must not be mistaken for 1357 particle draw calls.

Original NWN PID 40876 had already exited when the user authorized closing it.
No live Arelith connection or modification to native binaries was performed.
Production main source and dist remain unchanged. The 60 FPS goal is unmet.

### Storage and light membership experiments

`ModelParticlePresentation.reuseFrameState` defaults off. The experimental path
reuses the immutable scalar-property dispatch table and per-emitter draw-provider
object, avoids copying the entries map for particle counting, and retires
emitters only on observed hierarchy changes. It does not skip simulation,
callbacks, atlas clocks, worker snapshots or RNG calls. Twelve paired storage
tests plus the existing thirteen presentation cases pass, covering all seven
render modes, live properties/poses, bursts, detonation, root replacement and
asynchronous vertex completion after removal. Four comparator tests also pass.

The first visible eight-phase run (`particle-storage-v1/compare-v1.json`) was
rejected: unsupported emitters increased from 700 to 706 after disabling the
submission owners, so its roughly 19–21 FPS cannot establish a gain. Those six
entries were tnp_gsol1c / AuroraEmitter01. The test now records particle error
messages and avoids needlessly rebuilding batch resources on particle-only
mode changes. No causal claim about those failures is established yet.

`prepareRendererLights.lightOnlyMembership` also defaults off. It retains the
full fresh material list for sampler budgeting but passes only light-like
objects to selection and slot counting, avoiding light-field checks/tables on
thousands of ordinary shadow meshes. Two paired lighting tests and ten existing
slot tests pass, including visibility, moving/parented lights, sampler changes,
shadow selection, type-flagged custom lights and removal/readdition.

The four-phase visible `light-membership-v1/compare-v1.json` passes all timing,
inventory, activation and drift gates. Full phase FPS: 19.01 baseline, 19.83 and
19.95 particle+light candidate, 18.92 baseline. Average frame time fell from
52.60/52.86 ms to 50.42/50.13 ms; candidate p95 remains 56.4 ms. Both mode repeat
spreads are below .6%. It retained all 898/1077/1357 objects/models/emitters,
700 unsupported entries, and zero resource gaps/new object failures. This is
one modest measured improvement, far short of the goal; not a production rollout.

Same-task canvas/shadow checks retain every pixel difference. The last run's
reference itself changed 40 channels in 32 pixels, maximum one byte, across
repeated draws. Candidate changed 33 channels in 26 pixels, maximum one byte.
All active shadow bytes matched. The exact default-framebuffer gate fails;
reference instability prevents attributing these tiny differences to the
candidate. No tolerance was substituted and no native/UI fidelity is claimed.
Investigate an independent non-MSAA target before accepting visual evidence.

### Larger batches and GPU diagnostics

Explicit larger batch/member capacities default to the existing 32. An opt-in
128-member / 128-layer path retains the hardware and byte bounds. Eleven CPU
checks pass, including the old 32-layer boundary, all layer bytes, 128 transform
slots, hardware clamping and retirement. Nine authored GPU color/shadow/triangle
comparisons match exactly (160 draws to two in the simplest case). The fixture
also logs old-context deletion warnings after context restoration; its initial
`success:true` is insufficient for lifecycle acceptance. The probe now rejects
those warnings. Keep the original receipt rather than rewriting its status.

The six-phase complete room comparison (`large-batches-v1/compare-v1.json`)
passes timing/content/drift guards. Larger batches alone give about 19.4–19.5
FPS; the combined particle/light/trimmed-audit mode gives about 20.9 FPS versus
about 19 FPS controls. Main draws fall from about 2214 to 1134, but batch texture
storage rises to 536,271,372 bytes. That cost and modest gain do not justify
promotion. All 898 objects, 1077 models, 1357 emitters and 700 unsupported entries
remain stable, with no resource gaps or new object errors.

The separate non-MSAA color target has a byte-stable repeated reference, and
both larger-batch modes match every color and active shadow byte. The default
MSAA framebuffer still has maximum one-byte differences on a few dozen pixels,
including between reference repeats. Both receipts remain separate; this does
not establish native/UI fidelity or relax the exact default-buffer result.

The 21.891-second wide-mode CPU profile (`submission-profile-v1`) attributes
6.109 self seconds to Three renderer, 3.067 to core, 1.751 to main batching,
.994 to particles, .869 to shadow budget and .808 to shadow traversal. The
larger batcher's own work offsets much of the submitted-draw saving. Its later
occlusion audit failed because direct draws were outside Three's active render
state; the completed CPU profile is retained as diagnostic evidence.

The corrected audit (`submission-profile-v2/audit-v1.json`) runs read-only box
queries in an after-render callback. It changes no visibility. Its restrictions
admit only seven objects and reject 891, mostly because mapped materials all
use polygon offset; it therefore cannot establish useful room-wide occlusion
headroom. Its asynchronous, non-disjoint GPU timer measured 21.10304 ms for one
cached ordinary fallback draw, excluding simulation and queries. This is one
GPU sample under diagnostic fallback, not an average, native comparison or FPS
acceptance. It motivates testing spatial light lists alongside further CPU work.

### Conservative point-light masks

The private point-grid prototype now owns per-material shader hooks and one
bounded 64 KiB UBO, with ordinary rendering on unsupported shaders or capacity
overflow. It keeps the original unrolled light and shadow accesses. The native
light adapter encodes legacy attenuation using negative decay: these lights
have infinite support even with a positive radius. The first room experiment
incorrectly treated that radius as a cutoff and is explicitly rejected in
`point-grid-v1/compare-v1-rejected.json`; its apparent speed cannot be used.

The corrected fixture installs the actual legacy shader adapter. All twelve
authored GPU cases match every color and shadow byte, with compiled shader
activation verified (`point-grid-v1/gpu-native-mask-v5.json`). Thirteen CPU
ownership/membership/transform cases also pass. Real GPU context restoration
remains unverified for this candidate. Nothing is imported by normal main.

The corrected four-phase room run (`point-grid-v2/compare-v1.json`) passes the
full observation, activation, inventory and repeat-drift guards. Its rolling
diagnostic reads about 18.8/19.2 FPS for baseline controls and 21.0 FPS for the
combined mask/storage/light-membership mode. The independent non-MSAA target
and all active shadow bytes match exactly, with a byte-stable reference.
All 898 objects, 1077 models, 1357 emitter entries and the same 700 unsupported
entries remain present; no resource gaps or new object failures occurred.
The old partial-capture parity gate remains failed rather than being weakened.
This is still far short of 60 FPS and has not been promoted.

The mask retains an average 101.32 of 128 light slots per tile, limiting its
headroom in this room. Per-phase single GPU elapsed queries range 32.8–42.9 ms;
they span command submission and may include idle time waiting for CPU work.
They are not GPU utilization or steady-state FPS measurements. Next priority
is reducing submission bookkeeping without the existing large texture arrays.

### Cached command and merged-index experiments

`RendererCommandBatches` is an unimported normal-client experiment. Its first
backend uses Three's multi-draw path, a bounded immutable geometry atlas,
cached CPU-computed transform rows, and a small table of the original 2D
textures. No texture resampling/array copies. Unknown callbacks, deformation,
reflection, unsupported materials and capacity overflow use ordinary draws.
New geometry stays ordinary until Three has uploaded its cached copy. Picking,
shadow meshes, parent links and source resource ownership remain intact.

Eight CPU tests cover ordered ranges/indices, transform and texture changes,
capacity fallback, geometry edits and retirement. The authored GPU fixture
passes 26 paired cases across both multi-draw and merged-index backends,
including actual native legacy lighting, transparency, mirrored transforms,
UV/tint/state changes, context restoration and disposal. Earlier raw reports
are retained: v1 used an unavailable private render-state accessor; v2/v3
reported stale *fixture source-resource* disposal listeners after context
restoration; v5 found an invalid first index-buffer binding target. The source
fixture now retires its resources during context loss and verifies no invalid
deletions. `command-batches-v1/gpu-v6.json` passes without GL errors or invalid
operation warnings. That does not establish production lifecycle behavior.

The multi-draw room run (`command-batches-v1/compare-v1.json`) passes timing,
content and drift guards, with complete object/model/emitter membership and no
new failures/gaps. It reduces 2368 opaque submissions to 297, including 2358
objects in 287 batches, using 17,842,176 bytes of bounded GPU storage. Full RAF
FPS is 18.81/19.18 for controls and 20.84/20.97 for the combined candidate;
candidate p95 is 54.1–54.6 ms. This remains a small gain, despite the submission
reduction. The independent reference is stable, but nine candidate pixels
differ by one byte; all shadow bytes match. Exact pixel acceptance fails.
No candidate has been promoted.

An alternate backend merges the same ordered ranges into an owned index buffer
and uses stable per-instance vertex row IDs. This replaces backend multi-draw
loops with one ordinary indexed draw per group. Geometry/indices/transforms
are retained when unchanged; original samplers and shadow sources are kept.
It passes the authored CPU/GPU checks above. The four-phase D3D11 room run
(`merged-commands-v1/compare-v1.json`) passes timing/content/drift guards, but
achieves only 20.22/20.40 FPS versus 18.65/18.95 controls. It uses 22,036,480
bytes, 322,683 cached vertices, 2365 allocated transform rows and zero steady
index uploads. It has the same nine one-byte color differences and exact
shadow bytes. Lower backend draw count did not establish a large gain.

The isolated OpenGL backend is confirmed as ANGLE/NVIDIA/OpenGL 4.5 rather than
D3D11. It passes the 26 authored cases (`gpu-gl-v1.json`), but the complete room
still measures 20.07/20.10 FPS for merged commands and 18.71/19.01 for controls.
Its independent-target difference is much larger: 48,635 pixels, maximum 101
bytes, despite exact shadow bytes and a stable reference. Both speed and full
room fidelity fail to justify changing backend. The normal launcher remains
unchanged; no software-rendering fallback is used for these comparisons.

The 21.799-second merged D3D11 CPU profile (`command-profile-v1`) attributes
3.078 self seconds to the new command owner, 4.604 to Three renderer, 3.786 to
Three core, and 1.436 to GC. Recursive visible traversal alone takes 1.605 self
seconds; command descriptors take 1.002. Inclusive source totals overlap and
must not be added. This identifies substantial remaining CPU bookkeeping.

A new diagnostic places timer windows immediately around raw draw entry
points. Three CPU cases verify cleanup on errors/capacity/timeout, disjoint
handling and target grouping. Its room audit observes 719 main draw calls,
4.309216 ms summed windows and 31.8 ms instrumented CPU submission. This warmed
frozen frame reused shadows (zero offscreen queries), so it cannot represent
all moving-frame GPU work. Uploads, clears and between-draw preparation are
excluded; instrumentation overhead prevents using it as FPS acceptance.
The separate whole-draw query reads 26.442688 ms and may include CPU submission
gaps. Neither result alone establishes GPU utilization.

The next private revision removes repeated material-key arrays, source-range
string keys, per-row transform arrays and descriptor/render-item allocation.
It uses the already computed conservative sampler reserve to avoid a duplicate
scene traversal. Ordinary fallbacks and live state checks are retained;
26 authored GPU cases pass (`gpu-v8.json`), including the reserve-provider path.
The new full-room repeated comparison (`command-hotpath-v2/compare-v1.json`)
passes timing/content/activation/drift guards: 18.53/18.80 FPS controls and
22.58/22.57 FPS candidate, p95 50.8/51.2 ms. Opaque draws stay 2368 to 297;
the gain comes from reduced CPU bookkeeping. Complete source membership is
retained without gaps/new failures. The same nine one-byte independent-target
differences remain, with a stable reference and exact shadow bytes. It is still
not promoted, and the 60 FPS goal remains unmet. The next architectural target
is repeated hierarchy/projection/submission work, not another light truncation.

### Shared membership and frozen command lower bound

An implicit-sampling variant did not remove the nine one-byte room differences
(`command-sampling-v1/parity-v1.json`). Its 52 authored GPU cases pass; this is
not a full-room fidelity acceptance or measured FPS improvement.

The optional same-pass handoff feeds prepared visible objects to flat projection
and shadow collection, preserving parent links, visibility/layers, group order,
drawable subtrees and unsupported-pass fallback. A live group marker preserves
light slot replacement/order. The handoff is consumed once and defaults off.
Four new CPU cases plus 22 related cases pass; 18 authored GPU cases match all
color/shadow bytes (`shared-frame-v1/gpu-v2`). Initial GPU fixture v1 failed its
hook-restoration setup check and is retained.

Three initial room attempts failed before timing because a diagnostic callback
entered snapshot metadata. A structured-clone regression test now covers it.
`shared-frame-v2` has exact room color/shadow parity but cannot establish speed:
its baseline constructs unused handoff data and its validator expected unrelated
owners disabled. The control now passes no callback when reuse is off; tests
verify shared mode keeps unrelated particle/submission owners unchanged.

The corrected `shared-frame-v3/compare-v1.json` passes timing/content, activation
and drift guards. Full RAF FPS: 18.90/18.97 baseline, 19.52/19.57 shared; candidate
p95 58.4–58.5 ms. Projection consumes 4891 prepared objects, submitting 4800;
shadow collection visits 4891 while retaining all 3131 casters and selected 756.
Color and shadow bytes match a stable independent reference. This small gain
does not approach 60 FPS and is not a rollout.

`frozen-stream-v1/audit-v1.json` captures a warmed frame's GL commands in memory
only, then replays without simulation, fresh culling/transforms/material or light
preparation, and with reused shadows. Reference, first replay and repeated replay
match all color/shadow bytes, with no GL errors or resource lifetime commands.
It records 12081 commands (2211 draws) and 435560 bytes of transient argument
copies. Three passes drain in 10.7 ms, about 3.57 ms each. This is a frozen lower
bound, not animated gameplay FPS, GPU utilization, a gameplay cache or goal
completion. No commands, GL handles or asset payloads are saved. Three CPU cases
check copying, raw replay, hook restoration and lifetime-work rejection. This
motivates a compiled executor with live state bindings and ordinary fallback.

Read-only original-client settings inspection found `graphics.lighting.max-lights
= 32` in Documents/Neverwinter Nights.0/settings.tml, with schema default 32
and permitted values 3/8/16/32/64/128. This is configuration evidence only,
not proof of live native per-object light membership or shader execution.
The room experiments above have not changed admission or dropped real lights.

### Warm native dispatch and prepared projection

The optional private Vite bridge exposes Three's existing uniform, material,
attribute and binding owners. It transforms exact guarded sites in the QA bundle;
the installed dependency and normal main/dist are unchanged. Warm dispatch keeps
ordinary projection/uploads/callbacks and refreshes live uniforms, while reusing
compiled programs with conservative mutation/unsupported-path fallback.
`warm-draws-v2/gpu-v1.json` passes 19 authored exact color/shadow cases.
`warm-draws-v2/compare-v1.json` passes complete-content and repeated timing guards:
18.51/18.79 FPS baseline versus 20.17/20.26 warm, p95 55.2–55.9 ms. Independent
non-MSAA color and active shadow bytes match a stable reference exactly.

`RendererScenePlan` optionally fills Three's native render list from the same-frame
lighting membership, preserving source hierarchy, native uploads, layer/group
order, culling, native sorting and draw callbacks. Unknown scene callbacks, LOD,
array cameras and XR use ordinary projection. It reconnects its private hook
after graphics-context restoration and owns no GPU resources.
`planned-draws-v1/gpu-v1.json` found a missed post-restoration hook: pixels still
matched because ordinary projection ran, but activation failed. The corrected
`planned-draws-v2/gpu-v1.json` passes 50 authored exact comparisons, including
live visibility/layers, groups, sprites, LOD fallback and restoration.

The first room run `planned-draws-v2/compare-v1.json` failed its final screenshot
step because the parity allow-list omitted the new mode. No timing acceptance
is claimed from it. A regression now checks all replay modes have a parity path.
Corrected `planned-draws-v3/compare-v1.json` has complete inventory, no new model
or particle failures, and valid repeated timing: baseline 18.95/18.92 FPS versus
20.86/21.49 prepared/warm, p95 53.3–55.7 ms. All independent color/shadow bytes
match the stable reference. Default MSAA comparison remains failed and separate;
no tolerance or recorded partial-capture gate has been weakened. This remains
experimental and far below 60 FPS. About 7 ms particle work and 8 ms lighting/
matrix preparation persist outside submission. These results do not establish
full-game/native parity or production readiness.

### Ordered point-shadow prefix cache

The opt-in GPU prefix cache preserves draw order: it stores only leading stable
casters, copies both packed color and depth, and restores them before drawing the
live suffix. It has bounded GPU storage, current source-input stamps, ordinary
fallback and context-loss retirement. Cached commands or asset bytes are never
serialized. Five CPU cases cover ordered stability, owned instance inputs,
capacity rejection, framebuffer binding/scissor restoration and exception cleanup.

The first fixture did not prove activation, so it remains a failed receipt.
The corrected fixture reads the candidate before independently redrawing the
ordinary shadow reference; it clears only the whole-map reuse metadata between
these authored comparisons. `shadow-prefix-v3/gpu-v1.json` passes 56 cases.
The first room run had valid repeated timing (18.85/19.03 control versus
23.55/23.46 FPS) and identical color pixels, but 48 shadow pixels differed.
That fidelity result is rejected, not hidden by a tolerance.

The revised cache retains existing shadow-instance shaders and original proxy
ordering, with source identities/stamps covering every proxy member. The owned
instance adapter exposes membership through a method, not serializable userData.
`shadow-prefix-v5/gpu-v1.json` passes 58 authored exact comparisons, including
three verified cached/live coplanar boundaries, live changes, context recovery
and nested native draws. Ordinary warm-dispatch fallbacks also invalidate its
per-frame program cache, so later fast draws refresh camera/light uniforms after
an unknown callback renders another scene.

`shadow-prefix-v5/compare-v1.json` passes the complete-content, activation and
repeated timing guards. Baseline is 18.32/18.81 FPS; candidate 22.56/22.45 FPS,
p95 49.3–49.9 ms. Steady shadow submissions fall from 781 to 300, reusing 391
leading proxy objects before 247 live suffix objects, with 16 MiB owned storage.
Independent color and active shadow bytes match a stable reference exactly.
Default MSAA/readback and recorded partial-capture gates remain separate; these
experiments remain disabled in the normal client. The 60 FPS goal is unmet.

### Matrix owner cooperation and particle pose samples

Known renderer matrix owners previously forced one another into ordinary
fallback. The optional cooperation setter re-registers existing subtree owners
at mode boundaries; unchanged commits can skip the known wrappers, while unknown
methods remain live. Disabling forces a fresh walk and restores the former
fallback policy. A CPU test covers toggles, edits, queries, reparenting and custom
delegation. `matrix-cooperation-v2/gpu-v1.json` compares all three repeated draws
per authored case (174 color/shadow reads): exact, with skips and prefix-cache
activation checked. The preceding fixture failed activation despite matching
pixels, so it is retained; its last repeated draw had ordinary shadow output.
The first room build failed a duplicate-import check and its mistaken launch was
stopped using verified executable/script/build identity. A full-entry compile
regression now catches this before launch.

`matrix-cooperation-v3/compare-v1.json` passes repeated/content/activation guards:
baseline 19.10/18.63 FPS; shadow prefix 22.46/22.78; cooperative 22.90/22.90.
Independent color and shadow bytes match for both candidates. All 48 owned tile
subtrees (3125 nodes) are active, with over 22000 skips per measurement interval.
The extra gain is small. The separate CPU profile is not an FPS comparison;
its 32.24 seconds include about 7.38 seconds Three renderer self time, 5.14 Three
core, 2.68 warm dispatch and 1.88 garbage collection. Submission/material work
remains a major cost, distributed across many functions.

Optional particle pose reuse still resolves current world matrices and copies
derived outputs, preserving caller isolation; unknown decomposition stays live.
Eight added CPU cases match full simulation/RNG/vertex state across all seven
draw modes, edits and toggles. `particle-poses-v1/compare-v1.json` passes content,
activation and repeated timing guards, with exact independent color/shadow bytes.
It reuses 1142 samples with 19 computed in the sampled frame, but yields only
22.61/22.63 FPS versus 22.32/22.57 cooperative controls. This is no meaningful
performance advance and is not promoted. Ordinary controls remain 18.59/18.68.
Both optional features default off; normal main/dist are unchanged.

Verified source-only checkpoints:

- `backups/captured-room-baseline-20261022.zip`
- `backups/shadow-atlas-experiment-20261022.zip`
- `backups/compact-render-graph-start-20261022.zip`
- `backups/captured-room-renderer-prepared-20261022.zip`
- `backups/zero-light-work-prepared-20261022.zip`
- `backups/replay-measurement-prepared-20261022.zip`

Keep experiments isolated. Full tests resumed after the user released the GPU;
the measured gains above remain insufficient. The overall goal
remains incomplete. Changing renderer is authorized, but Three.js has not yet
been ruled out by uncontaminated measurements of these options.

### Texture arrays and compiled main-pass experiment (continued offline)

`array-commands-v1/compare-v1.json` only combined uncompressed textures and
regressed to 20.75/21.04 FPS versus 22.97/22.54 cooperative controls. The revised
lossless S3TC array path passes 90 authored GPU cases, including source edits,
sampling/mips, compressed formats and context recovery. In
`array-commands-v2/compare-v1.json`, controls measure 18.55/18.64 FPS, cooperative
22.22/22.31, array commands 25.56/25.67 (p95 about 45.6 ms). Opaque submissions
fall from 2368 to 142 using 14 arrays, 566 layers and 102162348 bytes of palette
storage. Nine color channels/pixels differ by one byte; shadow bytes and the
repeated reference match. This is a rejected exact-fidelity result and remains
disabled. More memory and fewer calls alone do not reach the target.

The next prototype records warmed native GL calls in memory and updates live
uniform/draw arguments, retaining native shaders, projection, sorting, resource
ownership and shadow draws. Unknown producers fall back to ordinary submission.
No command stream, handles or resource bytes enter reports. It is not a frozen
frame replay. The isolated bridge also exposes an after-pass boundary while the
native light/render state is still active. Program/uniform-cache coherence and
per-draw sampler mappings required corrections: earlier failed GPU receipts are
retained. `compiled-pass-v7/gpu-v1.json` passes 72 authored cases with three reads
each, including color and real shadow bytes; no GL errors. A nested render could
leave a warm-dispatch material bound to another scene’s light uniforms; nested
renders now invalidate its records. Empty-range and instanced geometry use
ordinary dispatch. Expanded activation tests are still being added.

A per-update ancestor pose query cache is prepared, default off, with CPU
simulation/RNG/vertex parity checks. No room timing claim exists for it yet.
The source contract will be refreshed after the current room comparison. The
normal entry and distributed bundle remain unchanged; 60 FPS is still unmet.

The compiled main pass was exercised in the real captured room (2796 draws,
about 69275 recorded commands). V1 regressed to 18.16/18.24 FPS versus
22.71/22.47 cooperative controls and failed independent color parity (89973
pixels); shadows matched. V2 skips 49492 unchanged uniform uploads, but still
failed room pixels despite passing authored scenes. The defect was an inherited
GL state dependency across the shadow/main boundary. Resetting the native state
owner and restoring the target before capturing a pass fixes it.

An incorrectly admitted parity CLI option initially left Electron on a startup
error dialog. The verified owned PID 16132 was stopped; the failed launch log is
retained. The harness now shares comparison/parity CLI modes and exits on
uncaught startup errors. The CPU all-mode guard checks CLI admission too.

`compiled-pass-v11/gpu-v1.json` passes 76 authored cases with three reads each,
including 33 planned cases that actually replay, source/texture changes, shared
uniform callbacks, empty ranges, opacity and context recovery. The profiled
room check `compiled-main-v3/parity-v1.json` is exact but is not FPS evidence;
it identifies allocation/validation and material-refresh overhead. Nonallocating
validation and a single late validation replace duplicate frame checks.

`compiled-main-v4/compare-v1.json` passes content, activation and repeated
timing validation: baseline 19.14/18.79 FPS, cooperative 22.43/22.42, compiled
22.19/22.20, shared ancestry 22.36/22.30. Independent color and shadow bytes
match a stable reference for all three candidates. The ancestry mode updates
2793 nodes and reuses 1159 ancestor queries in sampled frames. Neither new
mode improves on the previous candidate, so neither is promoted. All experiments
remain off in the normal client. Normal source entry and dist are unchanged.

The 60 FPS target remains unmet. A compiled GL call list alone does not remove
CPU preparation or enough work from the main thread; a larger architectural
change must account for those costs, rather than merely replaying calls.

### Worker-owned GL execution: first architecture checkpoint

After the compiled-pass and pose-cache experiments failed to improve timing,
a separate worker-owned context now mirrors the source renderer's actual GL
resource creation, uploads, programs, uniforms and draw commands. The transport
remaps opaque resources and transfers independent typed payloads; commands,
shader strings and asset bytes are never written to reports or disk. It uses
existing shaders without a replacement lighting approximation. Unsupported
operations, bounded storage failure and source context loss retire only the
mirror; ordinary source rendering remains available. Hook cleanup preserves
later owners and restores original property ownership. This remains an offline
duplicate-rendering diagnostic, not a gameplay renderer or FPS gain.

`worker-stream-v1/gpu-v1.json` passes fourteen authored color comparisons.
`worker-stream-v1/room-v1.json` matches the complete captured room's independent
color target exactly with 898 eligible objects. The revised authored fixture
also compares actual shadow-map bytes. The first room shadow audit failed
because padded neutral slots expose a texture placeholder rather than a render
target. The corrected audit retains all actual shadow targets while excluding
those placeholders, exactly as the existing frame-parity comparator does.

`worker-stream-v3/room-v1.json` passes independent color and active shadow bytes
exactly, with no renderer errors. It completed 1457 mirrored batches and had no
pending batch at readback. The final audit batch includes new independent-target
program compilation; its 194.9 ms submission is not steady timing. Earlier
ordinary mirrored batches submitted in roughly 5–7 ms, but these are worker CPU
submission measurements in a duplicate-rendering diagnostic, not GPU time or
whole-game throughput. Overall FPS acceptance remains unmet.

Nine CPU cases cover transferred ownership, source drawing after rejection,
command/byte/resource bounds, context-loss cancellation, hook retirement and
installed Three GL operation coverage. The current GPU fixture includes fourteen
live geometry/material/texture/light/camera changes, transparent double-sided
rendering, deletion/recreation and a shadow-mode change, comparing both buffers.
The FPS summary rejects mirror diagnostics so their results cannot be mistaken
for a gameplay performance comparison. Existing partial-capture content failures
remain unchanged. Source and distributed normal entry are untouched.

Next architecture work must remove duplicated source preparation and move a
useful preparation/simulation workload with drawing; moving GL calls alone
retains too much main-thread work. Persistent worker resources, bounded frame
queues, fresh uniform/transform data, particle RNG order, callback fallback and
interaction-visible state must remain covered as that integration develops.

## Persistent complete particle simulation worker — 2026-10-22

The private fixed-topology codec transfers initialized emitter state, cyclic
active/free records and their physical aliases, RNG state/draw count, reference
targets, static collision geometry, hierarchy world poses and dynamic properties.
A shared service runs the existing CPU simulation and vertex generator in a
dedicated worker. It does not import a renderer, DOM or network session. The
ordinary client does not import this experiment.

Fourteen CPU cases cover seven render modes, bursts, detonation, empty targets,
pose/topology rejection, and actual Node dedicated workers for Fountain, targeted
Lightning and collision. The room oracle uses a browser dedicated worker. Its
first bootstrap comparison raced source renderer attribute-range consumption;
that failed report is retained. Capturing the reference before the worker await
fixes the oracle without removing range comparisons.

`particle-simulation-v2/room-v1.json` matches bootstrap plus four full simulation
frames after twenty warm frames: 20,470 hierarchy nodes, 1,357 emitters, 571
collider geometries and the same 700 already unsupported emitters. Complete
cyclic state, RNG, attributes and ranges match exactly. Sparse frames send about
892–893 changed pose/property rows. Sampled worker simulation takes 6.6–8.7 ms.
These are worker CPU measurements, excluding producer capture/transfer/rendering;
there is no whole-game FPS claim and no gameplay worker integration yet.

The codec deliberately rejects topology changes and unknown pose writers. Asset
metadata/collider geometry is fixed for this oracle. Live model additions, worker
failure recovery, state handoff and overlapped scheduling remain required before
promotion. The normal source entry and distribution remain unchanged.

## Buffer storage replacement experiment — in progress

The private upload owner replaces storage using bufferData while retaining
existing buffer handles, VAOs and shader math. Initial/external/resized arrays
fallback to Three. Partial ranges qualify only for registered nonindexed particle
draw prefixes. A separate disabled-by-default shadow instance option renames
world/model-view storage before each face upload. This tests driver dependencies
between successive writes, not an assumed bottleneck.

The first authored test preserved all pixels/shadows but failed its activation
gate because changing every geometry version prevented the existing stable shadow
prefix path. The revised fixture updates one geometry, preserves that gate and
passes all 76 cases with three independent reads each, exact color/shadow bytes,
context recovery and resource retirement. Reports remain in orphan-v1 and
orphan-v2. Whole-room repeated timing and independent parity are pending.

### Upload experiment disposition and current status

The first eight-phase room run (orphan-room-v1/compare-v1.json) completed its
timing endpoints but then failed the parity harness's missing candidate allowlist.
It is retained as a failed run and the acceptance summary rejects it. Its raw
samples were baseline 18.58/18.57, cooperative 22.49/22.36, renamed dynamic
22.33/22.58 and renamed all 22.38/22.32 FPS. These are diagnostic evidence for
rejecting the new option, not a newly accepted timing comparison.

The corrected orphan-room-v2/parity-v1.json has no renderer errors and all three
candidates match independent color and actual shadow bytes exactly, with a stable
repeated reference. Its complete particle worker oracle also passes after the
additional raw-buffer and unknown-pose checks. The harness retains the preexisting
partial-recorded-frame content mismatch and raw success remains false. Fifty
focused CPU cases pass across particle workers, uploads, shadow instances, frame
parity and measurement boundaries.

No upload candidate is promoted. The last accepted repeated timing remains about
22–23 FPS at 1424 x 921 with the specified one-shadow experimental profile; this
is not evidence of 60 FPS or of equivalent performance at 3440 pixels wide.
Normal src/main.js and dist remain unchanged. Worker simulation/GL execution
are fidelity-tested building blocks, not a completed faster gameplay pipeline.

## Radical submission/backend experiments — 2026-10-22

The packet backend retains warmed shader/resource ownership and fresh scene
projection, but submits the main pass using bounded generated JavaScript blocks
of direct fixed-arity WebGL calls. Only authored API operations and numeric slots
enter generated code. Server strings, shaders, names and resource payloads never
become executable text. Mutable uniform arguments, first upload after shadows,
range/group changes and indexed offsets remain live. Code generation is bounded
to 96 MiB with a 100,000-command limit and never written to disk.

The first authored report retained pixels but rejected an unhandled fixed vertex
state operation. The expanded explicit operation list passes all 76 authored
cases and their three reads (packet-v2/gpu-v1.json), including context recovery,
material/texture changes and callback fallback. The full-room repeated comparison
is pending. This is a private backend experiment, not promoted code.

An additional authored native-WebGPU probe compares WebGL draws, fresh WebGPU
encoding and persistent render bundles for 3,000 independent draws with mutable
matrices/colors. It has explicit WebGL-versus-WebGPU pixel comparisons and fences
between samples. It measures submission architecture only and contains no game
assets or NWN lighting/shadow/material port. It cannot establish game FPS.

Primary migration references consulted: Three's WebGPURenderer guide
(https://threejs.org/manual/pages/webgpurenderer) explicitly requires porting
ShaderMaterial/RawShaderMaterial/onBeforeCompile customizations to node materials
and TSL. Babylon's own documentation describes GLSL-to-WGSL compatibility through
compiler tools (https://github.com/BabylonJS/Documentation/blob/master/content/setup/support/webGPU/webGPUWGSL.md).
Native render bundles are specified at
https://gpuweb.github.io/types/interfaces/GPURenderBundleEncoder.html. These facts
justify testing a separate backend; they do not establish a faster full port.

### Packet and WebGPU submission results

packet-room-v1/compare-v1-summary.json accepts repeated timing/control coverage
and independent room color/shadow comparisons are exact. At 3440 x 1343, the
packet backend regresses to 9.22/9.29 FPS against cooperative 19.63/18.94 and
baseline 16.10/16.68. Generated code is 83.6 MB across 729 blocks for 93,293
commands and 3,534 draws. This direction is rejected and remains disabled. The
viewport differs from earlier 1424-wide tests: do not compare absolute FPS across
those profiles. The raw partial-capture gate still fails, unchanged.

webgpu-bundles-v1/gpu-v1.json passes all six authored pixel comparisons, with
NVIDIA WebGPU available in the current Electron build. Repeated CPU submission
for 3,000 draws: WebGL 0.435/0.427 ms, freshly encoded WebGPU 0.090/0.065 ms,
WebGPU bundles 0.057/0.043 ms. Bundle construction 0.3 ms, 240,000 mutable bytes.
These exclude game simulation/preparation, material/lighting/shadow port and full
frame rendering acceptance. The absolute difference is under half a millisecond
in this simple workload; it does not predict removing the game's entire CPU cost.

The next private port consumes actual in-memory captured geometry and base-map
textures. Source animation is stopped and restored around the audit. Both APIs
use an equivalent opaque unlit subset, CPU-decoded base mip with linear sampling,
linear output, the same draw ranges/transforms/cutouts/sides/depth. The first
phase deliberately excludes actual game lighting, shadows, particles and special
materials. It reports subset pixel error rather than hiding incomplete fidelity.
No game assets/geometry/texture payloads are written to the workspace.

### Actual-room WebGPU port milestone

webgpu-room-v1/port-v1.json executes 2,368 actual room opaque draws from 1,355
geometries and 599 base-map textures at 1424 x 921, with no API errors. All
resources remain private and in memory. This is an UNLIT BASE-MAP SUBSET, not the
full game. Cold resource/shader preparation is about 4.4 seconds.

webgpu-room-v2 adds GPU timestamp queries. The actual unlit GPU pass averages
about 0.087 ms (coarse hardware/query resolution), while the queue/map completion
wall time is about 10.8 ms and cannot be called GPU shader execution time. CPU
pose packing/submission averages about 0.93 ms in that run. This excludes normal
game simulation, animation, lighting preparation, shadows, particles and special
materials. It is not whole-game FPS evidence.

The subset comparison exposed opaque alpha semantics: Three's installed
opaque_fragment.glsl.js forces output alpha to 1 after alpha testing. Matching
that behavior in WGSL removes all alpha discrepancies. In webgpu-room-v3, 4,852
of 1,311,504 pixels differ (0.37%); 6,093 of 6,308 differing channels differ by
one byte, 147 by two, 26 by three and 42 by more than three, with maximum 24.
The exact comparison still FAILS and no tolerance was introduced. Both independent
reference and WebGPU PNGs were visually inspected and retained.

Latest subset CPU pose packing/submission 1.38 ms average / 1.70 ms p95; GPU pass
timestamps 0.090 ms average / 0.131 ms p95. Mutable object storage is 303,104
bytes, refreshed each frame. These are scoped preparation/subset pass metrics,
not gameplay FPS or a native-client comparison. The normal renderer is unchanged.

Next port stages: preserve real lighting/attenuation and material terms, full mip
sampling, fog/color output, shadow passes, particles, keyhole/transparency and
special callbacks; live topology/resource retirement and pose/buffer updates;
then worker overlap and repeated whole-client comparisons at matching resolutions.
The 60 FPS/fidelity goal remains incomplete.

## Equivalent base-scene comparison — methodology

The follow-up comparison uses the same 2,368-draw opaque unlit subset, viewport,
CPU-decoded base-map textures, linear filtering/output and depth/cutout settings
through stock WebGL submission, cooperative WebGL submission and native WebGPU
bundles. Full game animation/simulation and UI are stopped throughout. The order
is stock/cooperative/WebGPU/WebGPU/cooperative/stock; each phase warms 20 frames
and records 60. CPU preparation/submission excludes the following fence/map wait.
GPU durations use each API's own elapsed/timestamp queries where available;
WebGL disjoint samples are omitted. Draw counts must remain equal. Completion
wall time is retained separately and is not converted into gameplay FPS.

This comparison can identify base-pass savings. It cannot establish the cost of
porting the game's lights, shadows, particles, hierarchy, animation or UI, and
cannot prove full-client 60 FPS. Existing exact pixel mismatches remain visible.

### Equivalent base-scene result

webgpu-room-paired-v1/paired-v1.json completes both repeats for 2,368 draws at
1424 x 921 with no API errors. CPU preparation/submission averages:
stock WebGL 8.552/8.600 ms; cooperative WebGL 9.872/10.215 ms; native WebGPU
1.470/1.468 ms. This is real base-pass CPU headroom of about 7–9 ms, with
substantial costs still absent. It is not a full-frame FPS measurement.

The WebGL GPU elapsed queries average 5.44–6.77 ms, while WebGPU render-pass
timestamps average 0.084/0.094 ms. The elapsed WebGL range can include gaps
between CPU-fed commands; this does not establish a 60x change in shader speed.
CPU/GPU durations overlap and must not be added. Asynchronous fence/map wall
time is recorded separately and excluded from those durations.

The equivalent subset still fails exact pixels (4,846 differing pixels, maximum
24), so there is no fidelity acceptance or normal-client promotion. Source scene
simulation, real lighting/shadows, particles, UI and hierarchy costs remain
excluded. The base-pass comparison supports continuing the backend experiment
but cannot prove that a complete port meets the 16.7 ms whole-frame budget.

## Point/ambient lighting candidate and engine assessment

A separate private lighting candidate extends persistent object storage with
normal matrices and emissive terms, packs actual point-light shader values once
per frame, and handles native quadratic/ambient-only attenuation. Its equivalent
reference uses cloned point/ambient lights and Lambert materials. Other light
kinds, shadows, light/emissive maps, fog, particles, vertex colors and special
materials remain excluded. This candidate is NOT GPU verified: the build guard
found the user's original nwmain.exe PID 27848 running and preserved it. Only
syntax and shared harness CPU checks can be reported until a clean GPU test.

An established JavaScript engine remains a candidate, not a proven speedup.
Babylon's own specifications list WebGPU/WebGL rendering, scene/animation
systems, particles and GPU picking (https://www.babylonjs.com/specifications/).
Its official WebGPU documentation describes native WGSL shaders and the async
engine initialization boundary
(https://github.com/BabylonJS/Documentation/blob/master/content/setup/support/webGPU.md).
A focused adapter trial can retain NWN protocol/resource/NUI logic while testing
maintained rendering infrastructure. A fully featured representative room and
visual/animation/interaction checks must justify migration; the engine name
alone cannot remove NWN-specific preparation or simulation costs. No new engine
dependency was installed or application migration performed in this assessment.
