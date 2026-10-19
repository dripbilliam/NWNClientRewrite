# Ground clicking and locomotion — 2026-10-17

The launched campaign exposed two real gaps: the world pointer handler returned
on ground hits, and keyboard/legacy interaction movement changed position through
a fixed-speed preview without setting a native animation. Ground clicks and WASD
now submit canonical waypoint movement. Interaction approaches also submit those
actions instead of applying preview position changes. Existing native pathfinding,
movement rates, collisions, subareas, orientation and SetAnimation own the result.
Normal ground clicks request running; Shift-click requests walking. The HUD
describes these controls. No character, spell or campaign-specific branch was added.

Read-only original NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project unchanged. This is a user-requested fix while
the larger spellcasting/combat/campaign goal remains paused.

## Native command boundary

`CNWSMessage::HandlePlayerToServerInputWalkToWaypoint`140455860..140455f43 reads
area OBJECT_ID, native XYZ, sequence BYTE, two BOOLs, another BYTE and target
OBJECT_ID before overflow/underflow admission. It checks controlled object/area,
creature8ac and the existing path destination. Duplicate area/target/3D position
within squared distance strictly less than float32(.01) updates only sequence20.
Reversed path storage uses point64 and area70; ordinary point4c uses area60.
It resets a changed path and sets19c only for the final BYTE exactly1.

Nearby combat state8d6==2 uses native distance strictly less than2.25, target8d8,
round pause1/500 and DoCombatStep. The original assembly455cf4 copies the target
direction's z into the clicked direction's z before dot/cross; this unusual
behavior is retained rather than repaired from the decompiler's apparent intent.
Otherwise commandability must equal1. ComputeAIState selects groupFFFE for
state1, FFFF otherwise. Sticky modes, forced mode0, clearing special attacks,
ActionManager8 and AddMoveToPointAction14037f940 execute in that order. The
existing native move action selects animations2/4 and returns to idle at its end.

`scripts/inspect-native-player-walk-input.py` runs the complete original handler
and original normalize/cross using synthetic objects. Scalar codec, lookup/cast,
path reset, AI/mode/action manager, round and move insertion are captured lower
boundaries. The retained215 cases cover admission, exact commandability, flags,
sequences, reversed paths, duplicate tolerance and directional combat steps.
This does not validate network encoding or complete native event scheduling.
REA dossier: `backups/animations/rea-ground-move-handler.json`; full assembly:
`backups/animations/native-ground-move-input-asm.txt`. The full outer input
dispatcher decompile failed; no claim depends on that failed output.

## Local input and checks

Player input queues snapshot XYZ and controlled object/area identities. Stale
requests are discarded. Keyboard input submits bounded lookahead commands at
120ms intervals, using camera-relative heading, including the overhead camera's
right axis. This is a local keyboard adapter, not a complete port of native
keyboard messages. Release/opposed keys cancel only the still-current movement
sequence through existing native cancellation; a newer command is preserved.
Ground picking retains scenery occlusion and requires a nearby walkable height.
The foreground wall can still obscure the entry room with the initial low camera;
wall fading/camera parity is outside this fix. No click-through-wall behavior.

Tests:215 original-code comparisons, request-copy/stale identity/area checks and
release-versus-replacement cancellation checks. All1882 tests and build pass.
Installed Prelude UI with unchanged wizard BIC and startup scripts enabled:
actual Shift-floor-click changes canonical position, plays `walk`, advances the
sampled clip and returns idle; actual W key runs and key release stops position
and returns idle with unchanged object ID. This uses an ordinary orbit gesture
to raise the camera above the foreground wall. Final capture:
`backups/animations/live-player-movement-ui.json`/PNG, UIv5 PASS.
Installed casting/chant/CC8/projectile travel/body attachment/cleanup regression
also passes. Existing resource and unfinished-system diagnostics remain recorded.

Earlier UIv1 failed because candidate clicks hit the foreground wall. UIv2 passed
walking but exposed the overhead keyboard-heading defect, now fixed. UIv3..v5
pass. The test now returns a nonzero exit on assertion failure; v1's text was a
failure despite Electron initially returning0. No failed run is counted as passing.

Verified checkpoint: `backups/player-movement-1882-20261017-v1.zip`,9849 files,
125576344 bytes; every archived entry length/SHA256 verified. Process21803
completed with exit0. Verification notes added after sealing.
Full reference-model rendering, remaining spell effects/combat and campaign
completion remain open; no automatic continuation of the paused goal.
