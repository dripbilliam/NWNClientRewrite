# Current-build local round trip and residual movement trace

The previous goal turn made a production portrait chooser repair. This turn
tests that packaged build, `index-oVQBAT2o.js`, on the unchanged owned Prelude
server at127.0.0.1:5121. No remote server was joined. The previous replacement
session disconnected normally through its control file; no server or other
client was cleared. Production source was unchanged during these tests.

The first current-build run loaded the controlled character in3812.5ms. Normal
tutorial dialogue and the existing doorway transitioned to the100-tile academy.
Area acknowledgement took4451.4ms, controlled-character readiness8203.9ms, and
the first sampled complete92-object presentation8572.5ms after area-loading.
The last two timings are distinct: avatar readiness does not prove every object
is already prepared. Final objects/models have no preparation failures.

A60-second3100x1121 content-framebuffer observation includes3350degrees of
camera rotation. After excluding two seconds following resize,113 samples give
74.0–93.1FPS,12.0–18.2ms sampled p95 frames and3.7–7.7ms submission.22programs
remain stable, with zero new programs, pending assets/shaders or failed models.
No renderer errors; the run disconnected cleanly. This is one local campaign
area, not a causal before/after speedup, exclusive OS fullscreen or the earlier
modded/dense106ms report. The separate transition proof does not accept the failed
clear-space movement gate.

Host resource timing records301 requests during transition; the longest
measured host read is2.65ms. Appearance is read twice, each about2ms for6.9MB.
This does not measure parse, transfer, GPU preparation or all scene work. It
suggests profiling the renderer's entry/preparation phases before attributing
the8.6seconds to disk reads or adding a cache. It is not evidence of a particular
CPU bottleneck or authorization to share resource state across servers.

Movement setup failures are retained:

- The first sequential W/S/combined/strafe sequence reached constrained geometry.
  Its all-clear-space verifier remains rejected. Some very short slow strafes
  also cannot be judged by a universal1m net-displacement threshold.
- Reset-v3 did not settle at a guessed point. Reset-v4/v5 reached the known
  contact point, but a293deg reported heading did not change to the requested
 292.4deg within the existing0.003vector tolerance. Periodic repetition did
  not resolve that observation. The native notification/suppression owner is
  not established; this is not proof that the turn request itself was ignored.
- Reset-v6 used a normal quarter-turn then alignment and retained the tolerance.
  Those acknowledgements succeed. Its guessed E origin did not settle; the
  final run instead tests E as the ordinary return after Q.
- A diagnostic assertion initially treated every non-base strafe animation as
  idle. Captured `cwalkr`/turn selections show that assumption is insufficient.
  The final diagnostic records base-selection differences, actual zero/idle
  frames and clip names separately; it does not accept all animation selection.

Final run-v7 resets five inputs through ordinary server walk/turn requests,
then pairs the opposite strafe. It uses actual Chromium-routed key/repeat events,
not desktop physical-key input. W/S have zero stationary steps. Combined A/D
have6/2stationary steps; Q/E have5/0. Largest respective pauses are31.6/16.5ms
and25.6/0ms. Deliberate contact Q/E has4/2stationary steps,16.8/16.1ms maximum
pauses. Actual idle frames occur while paths are inactive; active-path zero/idle
frames are zero. These pauses remain open, not accepted as flawless motion.
The client loads in3598ms and the following19 passive starting-room samples
give111.7–130.0FPS. Scripted input and the bounded10-second sampler both finish.

The frozen current capture replays220 applied original6ea9e0/7fdeb0 predictions
with2060 captured collision queries, zero null paths and36 corrected-position
inputs. Maximum query-coordinate delta is9.54e-7 and endpoint delta2.38e-7.
Animation IDs/factors/shortened-path resend values agree within the unchanged
oracle's bounds. Collision answers, object lookup, path installation, timer and
idle-query boundaries remain captured. This does not execute the original world,
whole animation selector or full frame/reconciliation scheduler. Some short
paths complete between refreshes; matching prediction arithmetic does not prove
their presentation timing is correct.

`verify-current-local-transition.mjs` validates only loading/transition/camera.
`verify-current-local-trace.mjs` validates the captured diagnostic/original-code
comparison and explicitly labels movement acceptance incomplete. The original
all-movement gate and rejected setup reports remain available. Earlier v1 uses
the keyboard helper from checkpointv35; later opt-in reset instrumentation is
QA-only. No production movement, lighting, packet or authoritative-state change
was made to obtain these results.

Current idle client PID41792 / exec59922 remains connected to the local server.
Its control file is `creation-performance-current-drive-control-v7.json`, with
close:false. The frozen archive is `creation-performance-exact-drive-capture-v4.json`;
the active-name file is excluded from checkpoints. Both owned servers remain
unchanged. The goal stays active: next useful work is native frame/short-path
timing versus this trace, renderer entry profiling, and a varied cached scene
or exclusive-fullscreen check. Do not repeat generic neutral-light-slot tuning
or relabel the residual movement as accepted.
