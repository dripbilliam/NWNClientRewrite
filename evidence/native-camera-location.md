# Native scripted camera location — 2026-10-18

Full multiplayer goal remains ACTIVE. This extends the shared camera controller
and native received-command work. It does not complete camera attachment,
collision recovery, camera flags, remaining SP VM adapters, or multiplayer.
Read-only nwmain89.8193.37-17 SHA256:
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

Observed ownership and behavior:

- Receiver14077a7f0 family16/subtype1 reads a BYTE mask and optional FLOAT
  yaw radians/distance/pitch and INT transition value (bits1/2/4/8). The yaw
  conversion is float32 `(value - 1.5707964) * 57.295776`. Native Camera getters
  GetYaw140059020/GetPitch140058dd0/GetDist140058cc0 return raw Follow values.
  Partial packets with yaw omitted still store the receiver's converted current
  yaw in the target slot; snap commands only change axes present in the mask.
  This unusual partial-packet behavior was executed, not normalized away.
- Negative, zero, omitted, or greater-than180 transition values snap. Values
  1..180 are rates, not tween durations. Snap commands pass through native
  sprintf %f and command parsing. Target setter1407cfa00 clamps target distance
  and pitch even when those fields were omitted. Native active/global bounds
  are distinct from stored script limits and locked Follow bounds.
- Frame owner1407d0860 calls gameplay mode steering before transition1407d11f0,
  then clears transition rate when the helper reports complete. The latter
  derives synchronized rates from wrapped yaw difference, natural logarithm of
  distance ratio, and pitch difference. Its constants include90/log(4) and
  3.6734693. Yaw helper1407ccd90 uses shortest-path reduction and strict crossing
  checks. Distance1407ccb00 predicts the Follow exponential zoom step before
  snapping an overshoot. Pitch uses the corresponding linear crossing check.
  Stiff-chase mode2 intentionally ignores scripted distance/pitch interpolation.
- Native paused query1406ac030 suppresses active transitions. The pure helper
  and GameCamera update expose that input; multiplayer pause protocol wiring is
  not established by this change and must not be inferred from the fixture.
- Original positive SSE logf140c946b0 is already modeled in native_log.js. Camera
  transitions use its explicit SSE branch. Follow/transition pow is a finite CRT
  boundary. This is not new proof of the original FMA CPU profile. Camera-local
  exceptional logarithm inputs preserve IEEE NaN/Infinity results without
  changing the stricter shared gameplay log provider.

Implementation: typed location packets now route through NetworkFrontend into
GameCamera. The same controller applies scripted rates before Follow and keeps
native clamp/lock behavior. Restore cancels a pending transition even when its
saved slot is empty. No canonical objects, ownership, scripts, AI, combat or
outbound requests are changed by this presentation path.

Validation:

- inspect-native-camera-location.py executes original full receiver, setter,
  transition, yaw/distance helpers and actual SSE logf against synthetic state.
  App/camera accessors, mode application, sprintf/command parsing, pause query
  and pow are explicit lower boundaries. Frames stop before Follow integration.
  The base command oracle was refactored behind a main guard so imports do not
  overwrite its acceptance capture.
- Final oraclev2:104 packet cases,378 transition frames. All packet masks,
  negative/zero/positive/over-limit transition values, omitted-axis bounds,
  three modes, five elapsed times, dominant yaw/zoom/pitch axes and pause cases
  agree with the JS state/rates. Packet read diagnostics/overflow/underflow are
  clean. Original observations and REA dossiers are retained.
- End-to-end pure Follow integration reaches the scripted endpoint and
  preserves a locked pitch. Restore cancels transition state; malformed/truncated
  packet fields remain rejected. Final affected suite223 PASSv3; buildv2 PASS
  with the existing bundle-size warning. Syntax checks pass.
- Electron fixture adds actual typed-packet/frontend-queue/Three-camera
  playback, canonical-world snapshot invariants and final view-direction check.
  Earlier v1 applies96 cases plus one playback packet and reaches the native
  endpoint after116 frames. Final v2 uses the expanded104-case capture. These
  are isolated fixtures, not live vanilla-server command reception evidence.
- Built Prelude smokev1 preserves the actual authored Pavel camera mode script,
  entry33, native focus/distance/pitch and no dialogue error. As in earlier
  smokes, startup is disabled and the fixture selects a model-preview camera;
  its keyholing-disabled screenshot is not a gameplay occlusion acceptance test.
  The existing missing fxpa_cloud02 diagnostic remains. Final build smokev2 is
  retained separately; do not infer campaign completion from either check.

Attachment research: receiver10 delegates to1407cf6f0. Machine code confirms
that this first acquires a universal object through virtual140 with arguments
byte255/1, then changes module target ID124 and uses that universal object as
the Follow target. This is more involved than pointing the renderer straight
at an arbitrary proxy. Its dummy/active-object ownership/update lifecycle still
needs tracing and an oracle before implementation. Do not claim attachment is
working based only on decoded IDs.

Correction from the later [attachment milestone](native-camera-attachment.md):
the forwarded RDX target-ID argument was omitted by the thunk's pseudocode.
The render object belongs to that target, not a universal dummy. Actual native
lookup/attachment/constructor execution supersedes the earlier interpretation.

Userclientv76 PID37376 and ownedserver20964 remain running and untouched. The
new scripted-location build is not loaded into that interactive session.

Final Electronv2 applies107 earlier commands plus104 location cases and one
playback command:105 location packets,116 playback frames, native endpoint,
canonical snapshot unchanged, empty stderr. Final built Prelude smokev2 passes
authored entry33/scriptMode1 with no dialogue error and empty stderr; screenshot
inspected. Area-transition persistence of locks/limits/targets still requires
native lifecycle verification; the command/transition fixture alone does not
prove it.

Credential audit13,412 source/evidence/build text files: private credential hits0.

Checkpoint multiplayer-native-camera-location-20261018-v1.zip sealed and every
entry length/SHA256 verified:13,595 files/299,137,729 bytes. Scope24 required
present/forbidden0;13,596 entries including manifest. Writer13249 terminal0
consumed. Scope audit and this postseal note remain outside the sealed archive.
