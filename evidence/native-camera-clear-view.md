# Native camera clear-view search — 2026-10-18

The full multiplayer goal remains ACTIVE. This milestone addresses ordinary
area-entry camera initialization and the one-shot clear-view search used by
AttachCamera. It does not establish complete camera or multiplayer parity.
Read-only nwmain89.8193.37-17 SHA256:
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

Observed native behavior:

- Engine callback1406ab410 calls1406d65f0, which installs the controlled PC's
  render object into area Scene248 and invokes attachment1407cf6f0 with
  find-clear-view1. This is an ordinary initialization path, not only a script
  camera feature. Attachment replaces Follow while keeping module camera state.
- Module render update1407cffc0 calls search1407cc070 when module140 is set,
  writes returned yaw/pitch only on success, then ALWAYS clears140 before
  Scene update. The earlier replacement left140 pending, suppressing mode
  steering and scripted-location updates indefinitely after a true request.
- Search first sets manual-latch13c=1 and turning138=0, resolves target124,
  and sets raw Follow yaw to target facing. It uses creature orientation2b4
  when available, otherwise object orientation44. Ordinary chase steering
  separately uses the controlled PC; these are different inputs.
- Prediction1407cc730 uses target render position, module offset118 and module
  focus10c, current camera quaternion, current raw Follow pose and current-frame
  rates/impulses. Spring is750, pitch/distance use global effective limits,
  quaternion slerp and distance integration match Follow. Prediction changes
  module focus, but does not consume or change the actual Follow state.
- If the predicted segment is blocked, search tries the opposite XY position
  at the same height, then the perpendicular candidate. Clear candidates select
  yaw+180 or yaw-90, preserving pitch. The final query repeats the ORIGINAL
  segment and, if clear, selects yaw+90. This surprising behavior is present in
  executed instructions; it is not silently replaced by a guessed fourth ray.
  Initial clear/all blocked returns failure, while target-facing yaw remains.
- Scene::HitCheck1400c9c90 receives CHitInfo mode1, maskFFFFFFFFBFFFFFFF and
  box-check0. Its dynamic Gob branch is mode0, so it does not test ordinary
  dynamic characters/doors here. BSP callback1400d9f20 visits registered static
  objects/meshes/AABB parts. AABB140090170 applies the64-bit surface mask,
  excluding surface30; PartTriMesh1400905b0 checks face polygons. polyhit140231810
  accepts front-to-back crossings only, including polygon edges/endpoints.
- Removal receiver1407a8240 explicitly compares the removed object with
  module124 and reattaches the controlled PC with find-clear-view0. This is
  binary support for the destruction lifecycle previously documented from
  installed nwscript comments. Exploratory1406ed720 is a key-command switch,
  not the frame owner; exploratory1407d1690 is combat/target framing.

Implementation and inference boundaries:

- GameCamera runs the verified search before actual Follow integration, skips
  the normal steering/script step for that search frame, and clears the request
  whether successful, blocked or unavailable. Prediction has its own focus and
  leaves Follow inputs/display quaternion intact. Missing geometry is diagnosed
  once rather than permanently disabling normal camera updates.
- NetworkPlayerCamera supplies target facing to clear-view while continuing to
  use the controlled PC for chase steering. Canonical proxies, player control,
  ownership and outbound movement are unchanged.
- Area entry now drops an old attachment, keeps the camera module's pose,
  limits/locks/saved command state, and waits for the asynchronous PC render
  binding before attaching with clear-view1. Full session reset still clears
  those values. Keeping module state follows the observed callback/attachment
  path; every higher area-transition/cutscene/configuration callback has not
  been exhaustively audited. Loading-screen recenter/bootstrap is a renderer
  adapter, not a complete original startup-constructor oracle.
- camera_scene_query maps static tile render meshes and loaded WOK triangles
  to the native static scene query boundary. It ignores dynamic objects,
  applies the WOK surface30 exclusion and front-face finite-segment tests,
  independent of visible material opacity, keyhole discard or wireframe mode.
  This is an explicit geometry adapter: Three triangle math and our scene
  membership/transforms are NOT the native BSP, cached face planes, clipping,
  registration hierarchy or f32 polygon edge arithmetic. Exact grazing-edge,
  unusual custom static registration and incomplete-asset outcomes remain open.
  No claim is made that render triangles alone perfectly reproduce native BSP.
- Continuous collision recovery1407d2940/1407d3840 is separate and still open,
  including its native keyholing bypass. Camera flags12, remaining SP VM camera
  adapters, attachment-aware keyhole semantics and original-client visual
  comparisons are also unfinished. Shared search is wired to network entry and
  attachment here; SP automatic entry-search wiring is not claimed.

Validation:

- inspect-native-camera-clear-view.py executes full1407cc070/1407cc730 and
  original quaternion routines using the pinned PE in Unicorn. Synthetic
  object/render accessors, CHitInfo bookkeeping and controlled scene-ray
  results are explicit boundaries. It records all ray endpoints/order, query
  mode/mask, result pose, predicted focus and mode flags.
- Final oracle v3:257 cases, including256 facing/delta-time/ray-result matrices
  and a missing-target case. JS agrees with native prediction and candidate
  choices; actual Follow state/input preservation is checked. v1 failed because
  synthetic accessor addresses exceeded the mapped hook page; v2 corrected
  those addresses. v3 records the64-bit mask as hex, avoiding JSON precision loss.
- Final focused tests v2:84 PASS across camera modes/input, command/location/
  attachment/search/keyhole, native motion, network scene/session/resources and
  tile geometry. Includes area-entry render waiting, state retention, target vs
  controlled-PC semantics, static/dynamic filtering, mask, front-face direction,
  finite segment length, and recovery after missing geometry.
- Isolated Electron v2 PASS:107 native command steps,105 location packets with
 116 playback frames, native attachment routing/reversion, and native16/10 true
  request selecting the opposite angle around a rendered static wall. No
  canonical mutation or unexpected diagnostic; stderr empty. v1 was a fixture
  setup failure (omitted canEnter), corrected in v2. This is not live server or
  original-client visual acceptance evidence.
- Build v1 PASS, existing bundle-size warning only. Built Prelude singleplayer
  smoke v1 reaches authored Pavel entry33/scriptMode1 with no dialogue error
  and empty stderr; screenshot inspected. Its camera is intentionally detached
  for dialogue picking, so it verifies shared-code regression only.
- Interactive replacement v76 PID37376 and owned nwserver PID20964 were left
  running untouched. The new build is NOT loaded in that user session. No
  original process/Ghidra mutation or installed asset copy was performed.

Sealed checkpoint: backups/multiplayer-native-camera-clear-view-20261018-v1.zip,
13683 files/302727888 bytes. Writer90640 finished exit0; every archived length
and SHA256 verified. Scope audit:26 required files present,13684 entries with
manifest, zero forbidden proprietary assets/live-session files/settings. The
initial scope regex falsely matched a REA impact-settings evidence filename;
anchoring private settings filenames removed that audit false positive.
Broad key-shape scan13498 files found7 candidates in5 files, all unchanged from
the previously exact-key-audited attachment checkpoint (public synthetic login
fixtures and a resume-note token); zero new candidates. No new authentication or
credential input occurred in this milestone. This post-seal note is outside zip.
