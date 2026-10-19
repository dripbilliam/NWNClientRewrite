# Native camera commands — 2026-10-18

Full multiplayer goal remains ACTIVE. This extends the camera follow/keyholing
milestones; it does not establish complete camera or multiplayer parity.
Read-only target nwmain89.8193.37-17, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

Receiver14077a7f0 and helpers1407cfd30/1407cf350/1407cf9d0/1407cc5f0..72b:

- Family16 subtype3 stores mode/distance/yaw/pitch. Subtype4 restores that
  single slot, then clears it; a second restore is a no-op. Stored zero distance
  and pitch become20 and50 for modes0..2. Native restore formats each command
  through sprintf %f before the camera command parser.
- Subtype5 reads FLOAT height. Zero restores the module's default follow height;
  other values, including negative heights, directly replace the follow offset.
- Subtypes6/7/8 read BOOL and lock pitch/distance/yaw respectively. Locking sets
  min=max to the current value. Yaw unlock restores0..360 and disables yaw clamp;
  other unlocks consult script limits or configured fallback settings.
- Subtype9 reads four FLOATs in order minPitch,maxPitch,minDistance,maxDistance.
  Negative limits select configured fallback values. Receipt stores the values;
  active bounds change during native mode initialization or unlock, rather than
  immediately resetting the camera when the packet arrives.
- Subtype2 retains the previously implemented mode routing. Location/timed
  interpolation1, attachment10, flags12 and other unimplemented subtypes remain
  explicitly diagnosed as unsupported. They are not silently accepted.

Implementation: network_camera_message.js owns typed decoding; NetworkFrontend
routes camera messages through the current session queue; GameCamera applies
the commands. Recenter preserves server locks and saved state. Deferred first
appearance binding preserves an already received explicit height override;
actual target changes/mode initialization reset the height normally. This
deferred renderer ordering is an adapter decision, not a separately executed
native appearance-lifecycle oracle. No canonical object state, authoritative
gameplay result, or outbound player request is synthesized.

Original-code validation: inspect-native-camera-commands.py executes the full
original receiver with original scalar writers/readers, native store/restore,
limits and limit getters. Synthetic app/camera virtual accessors, mode-setting
application, finite sprintf and command parsing are explicit lower boundaries.
The52 rows include5 exploratory flag cases;47 implemented rows/107 steps agree
with JS decoded state, raw limits, clamp bounds, height, locks and saved slot.
Native read overflow/underflow/type diagnostics are clean. Native uninitialized
padding bits retain the oracle's A5 heap tail; packet writer checks compare all
defined bits, not padding. Modes/collision/attachment and full scripted camera
interpolation are not proved by this fixture.

Oraclev1..v3 failed harness boundaries/ABI/empty-payload handling. v4 was rejected
after inspection found transport envelope bytes were being passed to the body
reader; v5 fixed that boundary, v6 initialized native fallback settings, v7
also resets native globals and records read-boundary diagnostics. Only final
v7 observations are acceptance evidence. Testv1 exposed a synthetic baseline
height mismatch and native undefined padding; v2 corrected those comparisons.
Final220 affected network/camera/feedback/resource checks PASSv4; buildv2 PASS
with the existing bundle-size warning. Syntax checks pass.

Isolated Electron frontend fixturev3 applies107 original-body camera commands,
ignores stale-session messages, preserves canonical world snapshot, and records
0 runtime errors. This is DOM/message routing evidence, not a live server
command acceptance claim. v1 used the shared default Electron profile and emitted
cache access warnings; v2/v3 use dedicated profiles and have no stderr.

Camera collision research clarified this milestone's boundary:

- Registration1406b3749 defaults graphics.keyholing.disables-camera-collisions
  to1. Its function object at140e2b5b8 calls1406bcf70, which writes settings148.
- Input frame1406e6220 calls1406f4770 (shader integer globals8 AND9). It calls
  collision dispatch1407d07d0 when keyholing is inactive, settings148 is0, or
  module camera flags bit1 is set. Dispatch skips attachment140 or flags bit2,
  and chooses stiff1407d3840 versus other modes1407d2940. Consequently a generic
  always-on wall-push camera would contradict normal native defaults.
- The helper1407da6d0 is an area/tile ray query with four arguments, not the
  keyholing bypass. The exploratory dossier name camera-collision-keyhole-gate
  was assigned before its full signature/body were examined; no such semantic
  rename was applied to Ghidra or source. Camera input/settings/bypass are now
  separately traced. Full collision geometry/recovery remains unimplemented.
- The read-only RIP-reference helper now handles immediate suffixes, exposing
  CMP references missed by its earlier displacement-at-end assumption. Candidate
  overlapping decodes remain exploratory until instruction alignment is checked.
- REA session91238 is live and reusable. Analyze6db800 exceeded the MCP response
  budget; retained pseudocode was read completely through inspect_analysis_view,
  coverage43,927/43,927 UTF16 units. It sets unrelated shader parameter35 and is
  not the collision setting consumer. The failed full response and continuation
  evidence are retained. Original executable/Ghidra project were not edited.

Interactive replacementv76 PID37376/server20964 remain untouched while the user
tests. This command build has not been reloaded into that live client. Native
singleplayer camera engine calls beyond the existing SetCameraMode adapter,
remaining server camera commands, complete collision recovery and end-to-end
original-client multiplayer gameplay still need implementation/verification.

Final built-renderer singleplayer smokev2 passes the actual authored Pavel
dialogue to entry33/scriptMode1, focus24,14,1.25/distance20/pitch50, no dialogue
error and empty stderr. Screenshot inspected. As with the previous smoke, the
fixture intentionally selects an NPC model-preview camera and disables startup;
its final keyholing-disabled view is not a normal gameplay occlusion acceptance
claim. Existing missing fxpa_cloud02 diagnostic remains visible. Native command
fixture is isolated, so no new vanilla-server command reception is claimed.
Credential audit13,381 source/evidence/build text files: private credential hits0.

Checkpoint multiplayer-native-camera-commands-20261018-v1.zip sealed:13,562
files/297,034,059 bytes; all archived lengths/SHA256 verified. Scope25 required
present/forbidden0;13,563 entries including manifest. Writer32620 terminal0
consumed. Scope audit and this postseal note remain outside the sealed archive.
Final process check confirms userclient37376 and ownedserver20964 still live.
