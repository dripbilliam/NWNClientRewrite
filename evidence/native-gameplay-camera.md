# Native gameplay camera — 2026-10-18

User correction: this task concerns the feel and framing of the normal gameplay
camera, not merely accepting server camera commands. The previous offset-follow
patch and generic OrbitControls were insufficient. Full multiplayer goal remains
ACTIVE; this is a camera milestone, not a completed multiplayer client.

Later milestone: [native keyholing](native-camera-keyholing.md) implements the
installed dissolve shader and native part eligibility gates.756 original-code
cases,216 affected checks, full Prelude rendering and actual vanilla-server
camera/movement runv75 pass. Collision and remaining scripted camera work stay
open; the earlier keyholing omission statements below describe the first seal.

Read-only target nwmain89.8193.37-17, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
REA dossiers are backups/animations/rea-camera-*.json. Original executable,
existing Ghidra project and original client were not patched or annotated.

## Observed owners

- Camera::SetFollow05b4c0 constructs CAurBehaviorCameraFollow053da0.
  Control055100 consumes yaw/pitch rates and angular impulses once per frame,
  applies enabled limits, changes distance by `2^(-dt*speed/2)`, and blends focus
  and orientation with `1 - .5^(dt*spring)`. Follow position uses the resulting
  quaternion's third axis times distance. Native quaternions are w,x,y,z in a
  Z-up world; the renderer must convert both position and camera orientation.
- Gameplay attach7cf6f0 installs Follow on the selected render object, restores
  stored camera parameters when available, sets spring750, and chooses a focus
  height of at least1. Top-down subtracts.5 from the creature height before
  applying that minimum. Client-mode owners below repeat this height choice.
- Input update6e6220 uses snapshot elapsed seconds. Keyboard tilt/yaw rates are
 75 degrees/sec; zoom rates are7.5. Mode steering7d0860 calls chase7d0d00,
  top-down7d0ab0 or stiff chase7d1c90. All reset to distance20/pitch50 when the
  mode/limits require reinitialization. Initial camera view angle is45 degrees
  (Camera0571f0). Initialized globals1412973d0..dc contain distance1..25 and
  pitch1..89; chase threshold1412973ec is30, multiplier1412973fc is1.
- Top-down preserves camera yaw. Chase measures heading against the displayed
  camera quaternion, begins steering beyond30 degrees, and continues until the
  difference is within1 degree. Its yaw rate is bounded to90 degrees/sec.
  Stiff chase uses five times the heading difference, bounded to180 degrees/sec,
  with an overshoot check. Manual camera input disables automatic chase steering
  until movement starts again. Native movement animation IDs, including creep,
  walking and running variants, determine that transition.
- Mouse yaw6f1300 and pitch6f13b0 write angular impulses. Their scaling uses GUI
  width, including the pitch formula's1080 reference. Native event dispatcher
 6edcfA accumulates wheel input at7.5 times the configured zoom multiplier.
- Camera packet receiver77a7f0 subtype2 reads a BYTE and calls settings6f49a0.
  Settings0/1/2 dispatch gameplay modes; the replacement now decodes16/2 and
  routes it to the same controller as local mode selection.

PE unwind records can split a logical function at its prologue. In particular,
6f49a0 and22f6d0 continue after their first runtime-function record. Retained
disassembly follows the continuation instead of treating that record as the
whole function. Interior-address REA lookups that failed are retained as failed
research attempts; successful dossiers use the actual function entry.

## Implementation

src/game_camera.js owns presentation-only focus, quaternion, distance, input and
mode steering. src/network_camera.js follows the currently controlled rendered
binding, including possession, and reads height from active appearance data.
Singleplayer uses its live animationState and existing native path height.
Canonical object positions, ownership, paths and gameplay remain unchanged.

Gameplay detaches OrbitControls input and skips its update, preventing its pan,
frame-based damping and orientation from overwriting the native camera. Model
inspection reconnects OrbitControls. Both gameplay modes expose top-down/chase/
stiff chase. Middle drag uses native angular scaling, and the wheel uses native
zoom-rate accumulation. DOM pixel/line-wheel normalization and the additional
Home/End/Insert/Delete/PageUp/PageDown bindings are renderer input adapters,
not a claim that the original configurable key map has been reconstructed.
Finite CRT sin/cos/acos/pow/sqrt returns are explicit presentation boundaries;
floating exception state and CPU-specific CRT dispatch are not emulated.

## Validation and remaining work

inspect-native-camera.py executes the original Follow, quaternion arithmetic,
chase/top-down/stiff-chase bodies and mouse handlers in isolated synthetic
memory. Dependency bookkeeping, scene lookups, virtual camera access, clipping
and finite CRT math are captured lower boundaries.432 Follow frames,720 mode
cases and100 mouse cases agree. The fixture does not prove ray collision,
keyholing/occluder dissolution, dialogue focus, scripted camera interpolation,
all camera flags/locks, user preference import or arbitrary server camera
packets. Unhandled server packet subtypes retain existing diagnostics.

208 affected network/camera/feedback tests pass (native-camera-tests-v7.txt),
including installed-model replay of concurrent original-client wire data.
Buildv2 passes with the existing chunk-size warning. Later edits require their
own final build/check entry below.

Livev72 on unchanged owned Prelude server22040: connected/playing,476 sampled
camera frames, all three modes,20 distinct rendered anchor positions,44 yaw
values, distance20->12.464932 after actual wheel input, two server movement
requests, actual middle-drag and dropdown handlers, no sample failure or runtime
errors. Capture local-network-renderer-v72.json, diagnostic summary and three
screenshots retained; screenshots inspected. Test closed cleanly using the
development harness close-control file; it did not reset the server. This is
replacement/vanilla-server evidence, not a new concurrent original-client test.

Earlier v69 had no addressable Windows window; its replacement-only process was
stopped for the authorized reconnect. v70/v71 launches inherited Electron's
Node-only environment flag and exited before admission. v72 clears that flag.
The original client and server were left running throughout. The harness now
accepts a capture-directory close-control file so future test clients can close
through their normal disconnect path without forced process termination.

Final focused suite208 PASSv8; buildv4 PASS; harness syntax checks pass. Installed
singleplayer smokev3 follows the actual authored Pavel dialogue to entry33,
observes cameraScriptMode1 independently from the default mode, and captures
native focus24,14,1.25/distance20/pitch50 with no dialogue error. Screenshot
inspected. Startup is disabled in this isolated fixture and a preview sun is
enabled; this is not a campaign-completion test. v1's default-mode assertion was
insufficient and v2 failed a transient empty error-element assertion; both
attempts are retained. v3 reads the error text atomically. A GPU teardown warning
appears after app exit; it is not a camera/script failure.

Final interactive v73 PID21088 is open on the unchanged server22040. No movement
or casting is queued. Frozen passive snapshot confirms mode1/distance20/pitch50,
appearance focus height1.25, camera target on the rendered controlled character,
and no sample failure. The continuously written live file is excluded from the
checkpoint; the frozen snapshot is included. Do not reset either process while
the user tests. Future authorized closure can write close:true to the v73
capture-directory control file, preserving the normal disconnect path.

Checkpoint multiplayer-native-gameplay-camera-20261018-v1.zip sealed:13,414
files/285,511,010 bytes. Writer70726 terminal0; writer verifies every archived
entry's length and SHA256. Credential audit13,244 text/source/evidence/build
files, private credential hits0. Scope24 required present/forbidden0 (13,415
archive entries including the manifest). Scope audit and this postseal note
remain outside the sealed archive. Full goal remains ACTIVE.
