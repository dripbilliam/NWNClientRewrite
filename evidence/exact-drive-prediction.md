# Exact local prediction replay and completion state

Prediction now replans if asynchronous work outlives its input pose, and path
completion updates motion state together with model playback. Final build
`index-BJ24korJ.js` passes51 focused checks and a current local live check.
Residual short contact pauses remain under investigation.

This work uses only the owned Prelude server at127.0.0.1:5121, PID20964.
The original game/server binaries and original installation remain unchanged.
No Arelith connection or asset copy is made. The previous goal turn validated
the current client but retained short contact pauses and an unexplained DOM
input trial with active position correction.

## Exact diagnostic inputs

The opt-in keyboard capture now records predicted position, displayed position,
orientation, movement rates, correction timer and the plan at preview entry.
The collision adapter records its private membership/pose snapshot and every
requested line with its result. These are metadata, not mesh/texture payloads.
Trace arrays are detached from canonical objects and collision-store inputs.
Cancelled previews are explicitly marked unapplied. Normal play does not
enable this trace. Unit tests cover ownership, exact origin/display distinction
and asynchronous cancellation.

The first contact-only setup failed to obtain a server heading acknowledgement
before any contact test executed. That rejected setup is preserved. The full
six-section movement prerequisite used by earlier successful trials was then
restored without changing the heading or contact acceptance checks. Its two
four-second contact sections produced160 exact predictions and1823 line
queries, including one fully blocked result.

The pinned original is NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Unchanged `0x1406ea9e0` and `0x1407fdeb0` instructions execute against those
exact input poses and recorded collision answers. Query order, all coordinates,
endpoints, factors, animation choices and partial-refresh values agree. The
maximum observed coordinate/endpoint/factor delta is zero. This verifies the
outer prediction/path search, including the blocked case. It does not execute
the original collision world, input/frame scheduler, GUI or GPU. Controlled
object lookup, idle animation query, allocation, path installation and timer
notification are explicit captured lower boundaries.

## Completion handoff repair

The live pre-fix capture contains43 frames where inactive motion still has a
walking/strafe animation ID while the model is already idle. Scene completion
updated model playback but omitted the motion animation state. The original
`0x1408114d0` completion branch calls the selector at`0x140811f34`, notification
at`0x140811f44`, then animation setter at`0x140811f4f`. These target
`0x140763220`, `0x140765f50`, and `0x140764300`, respectively. Existing original
acknowledgement/completion instruction cases capture those lower interfaces.
The isolated motion test supplied this state handoff manually; the actual
scene owner had omitted it.

Scene completion now copies its existing selected resting animation to the
motion state before handing it to the model/combat owner. It does not change
replicated actor data or invent a route. The new integration regression fails
with79 versus expected0 on the prior code, then passes after the repair. A
second case verifies the handoff even when the combat owner consumes the
request. An initial test used a fixed-model fixture with a humanoid clip name;
the final fixture uses the actual humanoid model type. All32 focused motion,
facing, scene, geometry and trace checks pass.

## Corrected-build verification

Intermediate build`index-DU70qZVl.js` reaches controlled presentation in3448ms.
The six-section Chromium-input free check passes391 translation frames with
zero stationary translation steps. The longer contact check passes facing,
active-path animation, displacement and final server-position checks, with30
partial refreshes and61 slide paths. The pre-fix43 state mismatches become
zero in this capture. This is state consistency evidence, not a controlled
speedup claim.

Another162 predictions and1789 line queries replay through the original code
with zero coordinate/endpoint/factor delta. In total,322 predictions and3612
queries match. Neither exact capture has an active position correction at
preview entry, so the earlier corrected DOM-input rejection remains outside
this proof. The corrected contact run still has five held idle frames per
direction and pauses up to16.7ms(Q)/24ms(E). continuousHeldAnimation remains
false; the repair does not establish that all contact stutter is eliminated.

## Asynchronous pose revalidation

The exact trace then exposed a separate race. A128ms applied prediction had
started at[6,3] while captured frames show the actor advancing0.232m before
it completed. A second applied call spanned another0.044m of movement. Its
collision query had validated the earlier origin, but installation starts at
the actor's current origin. The original preview calls its synchronous path
installer at`0x1406ead5a`; accepting a plan for a different starting pose is
not a faithful equivalent of that call.

Prediction now rechecks the actor/area owner, server animation/control gate,
position, displayed correction, facing, rates and appearance after asynchronous
work. Changed poses are replanned from current inputs. Work is bounded to three
attempts per input call; that limit is a client work budget, not a claimed
native constant. Later held-key ticks can retry. A server interruption or
replacement actor cancels the pending result. No replicated state, packet
codec or gameplay rule changes. Two regressions fail on the earlier code;
additional cases cover bounded work, changed facing/rates and lost control.

Final build`index-BJ24korJ.js` passes51 focused checks. Its local full setup
reaches controlled presentation in3722ms;394 free translation frames have no
stationary steps. The capture records one stale attempt being rejected and
replanned after10.1ms/0.032m of movement, with zero applied stale-origin cases
under the same frame-based diagnostic. Completion state mismatches remain
zero. These are correctness observations, not a controlled timing ratio.

Another161 accepted predictions/1801 queries match original instructions with
zero coordinate, endpoint or factor delta. The combined three corpora contain
483 predictions and5413 queries, including one blocked path. All exact entries
still have zero active position correction, so the earlier corrected DOM case
remains outside this acceptance. Final contact shows10(Q)/2(E) held idle
frames, maximum pauses17ms/8ms,28 partial refreshes and62 slides. It is not
declared fully smooth. The source-current cache benchmark still has identical
final geometry and provider counts30600/600; its synthetic median is0.952ms
prior versus0.075ms current, outside live FPS/latency acceptance.

Current proof is exact-drive-proof-v2; native-exact-drive-preview-v3 and frozen
exact-drive-capture-v3 preserve final data. Built main-v9 and the current-source
cache proof pass. The final replacement is left connected locally after finite
recording; the later checkpoint note records its current PID/control handle.

The bounded30-second passive capture finishes, with59 samples and no renderer
errors or failed objects. Recording and scripted inputs then stop. The final
client remains open as PID14592; control exact-drive-control-v3 is false and
live exec handle46882 remains available. Server20964 is unchanged. Built
main-v8 also passes native portrait IPC/menu/missing-ref checks without a game
join/content fetch; its debug font request is cancelled.

`creation-performance-exact-drive-proof-v1.json` hashes current sources and
both frozen captures/oracles. Native reports are
`native-exact-drive-preview-v1/v2.json`. Goal remains active. Next useful
investigations are combined input/prediction/draw ordering under controlled
local latency, and measuring the200ms full network-scene debug snapshot under
replicated density. The latter performs per-object bounds traversal; it is a
source-identified suspect, not a measured bottleneck yet. Portrait source gaps
and broader performance acceptance remain open.

Checkpoint v28 independently verified: 1,483 files, 62,529,359 bytes, SHA2565513cbeac5b853fbe28b202fdf5ac5857778b79a0f2e432d991333ce05978997;56 parents/252required entries, zero missing/newcredential candidates. Current client PID51564 remains open locally, control exact-drive-control-v4 false, exec2149live; bounded recording is finished. Post-seal verification only.
