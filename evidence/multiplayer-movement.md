# Native multiplayer movement — 2026-10-18

Ground input now sends a native waypoint request through the session-owned
preload/IPC interface. The session requires a live controlled creature, matching
area ID and area generation, and renderer-completed admission. It increments a
per-creature BYTE sequence and sends the request without changing replicated
position, action, path, animation or combat state. Singleplayer retains its own
existing input/action implementation.

## Original-code evidence

Read-only NWN:EE 89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Existing Ghidra project and original binaries remain unchanged.

Client sender `1407c0970` creates a native message with allocation hint 0x12,
then writes raw client OBJECT_ID area, full FLOAT XYZ, sequence BYTE, run BOOL,
client-path BOOL, fractional BYTE and raw target OBJECT_ID. Generic sender
`1407c25c0` supplies lowercase `p`, major 6, minor 1. Client OBJECT_ID helper
`1409737f0` preserves all uint32 bits; server reader `140476130` masks bit 31.
Server envelope dispatcher `140458b90` selects input dispatcher `1404531b0`,
whose subtype 1 invokes `HandlePlayerToServerInputWalkToWaypoint140455860`.

Ground-input wrapper `1406f3650` increments controlled-creature sequence 2d2
before sending. Constructor `1407fb140`, instruction `1407fb4b2`, zeroes 2d2
and last-sent 2d3. Other wrapper behavior includes repeat-click suppression,
client path calculation and keyboard/controller input; this pass does not claim
to reproduce all of that UI behavior. Group sender `1407c0ab0` is separate and
not connected. The request uses clientPath=false; server pathfinding owns the
route. See `player-movement-input.md` for the previously verified server action
handler and native run/walk action flags.

`scripts/inspect-native-network-walk.py` executes the original client sender,
OBJECT_ID helper, native scalar writers and GetWriteMessage, then the original
server SetReadMessage/scalar readers/whole walk handler. 67 cases pass across
flags, sequence values, fractional bytes, coordinates and high-bit identities.
Allocation/copy/logging/transport and controlled-object lookup, AI/mode/action
insertion are captured lower boundaries, not claims to emulate live pathfinding.
Three residual padding bits contain native uninitialized bytes; tests compare
all defined bytes/bits and our deterministic zero padding. Fixture:
`backups/animations/native-network-walk-observations.json`. REA dossiers and
remaining dispatcher projection are retained alongside it.

## Actual app and original-server verification

The user authorized clearing all owned test-server sessions. The profile-scoped
launcher stopped only that server and restarted installed nwserver as PID48532,
Prelude, UDP5121. Original nwmain and unrelated apps were not terminated.

`local-network-renderer-v9.json` admitted and rendered 9 tiles, 177 walkable
ground triangles, 33 canonical proxies and 19 object bindings. Its physical
pointer check was interrupted with Escape; it is not counted as a click pass.
It subsequently exited normally and logged out at 01:24:24.

`local-network-renderer-v10.json` uses the real Electron renderer, preload,
trusted IPC, production session and encrypted/reliable peer with the unchanged
installed wizard BIC. The probe ran hidden without taking desktop focus.
It invoked the same narrow `nativeNetwork.walkTo` method used by ground clicks.
Server join 01:25:14 / logout 01:25:59. The requests and returned scene states:

| Request | Server-returned position (native XY) | Animation / rendered clip |
| --- | --- | --- |
| sequence 1, run to (6,5) | (6,3.62), then (6,4.99) | 4 / run, then 0 / pause1 |
| sequence 2, walk to (6,3) | (6,4.96), then (6,3) | 2 / walk, then 0 / pause1 |

The player ID remains uint32 `0xffffffff`. No local ModuleSession, AI, scripts,
combat or spell resolver runs in the network scene. Fixture tests also assert
the request leaves the entire canonical actor unchanged. Final state closed,
failedObjects empty; 67 diagnostic records include zero errors and zero missing
animation/object-load failures (`local-network-renderer-v10-diagnostics.json`).
Unimplemented envelopes/effects/robes/equipment/audio remain explicitly recorded.

31 focused tests pass (`network-walk-tests-v3.txt`): original codec comparisons,
real installed walkmesh picking, session stale-area/sequence/ownership/cancellation,
IPC ownership, captured live movement, and peer/area/object regressions. App
build passes (`network-walk-build-v1.txt`), existing bundle-size warning only.
Harness syntax check passes. Credential audit scanned 2987 source/root-note/
network-evidence files: zero private full-key matches; four synthetic test-key
fixtures are identified separately (`network-walk-credential-audit-v1.txt`).

## Remaining scope

Physical floor clicking is wired and geometric picking is tested, but its live
desktop verification was interrupted. Native client path interpolation,
prediction/reconciliation, repeated-input suppression, keyboard/controller and
group movement are not complete. Current poses apply received authoritative
positions directly; smooth native presentation still needs work. Scenery/WOK
picking is an approximation, not verified parity with all native hit priorities.

Native interactions, transitions, conversations, inventory/equipment, multiplayer
GameUi/radials, shared combat/casting/effects, NWSync download and concurrent
original-client gameplay remain open. The full goal is ACTIVE and uncompleted.

Post-seal checkpoint: `backups/multiplayer-movement-20261018-v1.zip`, 12067
files / 198274386 bytes. Writer18748 exited0 after verifying every archived
length and SHA256. All 21 selected movement source/test/capture/validation
entries are present; forbidden native/compiled assets, character/module files,
CD-key configuration and private server profile absent. This note was added
after sealing. Owned server PID48532 remains running, test peer disconnected.
