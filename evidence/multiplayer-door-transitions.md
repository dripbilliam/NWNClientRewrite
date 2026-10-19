# Native door flags, clicks and area transitions — 2026-10-18

The client now sends the original targeted waypoint request for an open
transition door. Explicit radial Close remains a door action. Replicated updates
replace creation-time lock/lockable/transition flags. Doorway picking uses a
bounded closed-DWK region owned by the render binding, preserving selection when
the animated leaf moves aside. No local pathfinding, collision decisions, locks,
door scripts, destination lookup or area changes execute for these requests.

## Original-code evidence

Read-only NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executables and existing Ghidra project remain unchanged. REA PTY99283
was reused; full dossiers/projections are archived under rea-network-*.json.

Client door add796dd0 initializes BYTE19c from animation22/50/51/72 to0/1/2/3.
Setter86e690 writes that byte. Common object update79c050 updates it for
22/50/51 only; a following dead72 animation preserves the previous byte. The
network proxy now preserves this distinction. Render resting-state mapping is
separate from the byte used by click input.

Door update797780 reads six BOOLs. They write client190, trap state18c, locked184,
lockable188, conditional trap194, and transition1c0. Setter86e640 also notifies the
body shader and writes1c0. Server UpdateObject4eb590 confirms its third/fourth
flags come from native door424/428 and its final flag from transition lookup.
The decoder retains the entire raw flag array while updating field424/428 and
hasTransition for consumers. This fixes stale creation-only menu flags.

Click wrappers6efca0 and6efec0 check object/input gates. Nonzero door BYTE19c plus
transition1c0 sends native p/6/1 through7c0970 with the door's area, XYZ, literal
sequence0, selected run mode, clientPath0, fractional0 and canonical target door
ID. Closed/nontransition branches use86e810 -> p/6/3 action21/22. Run/walk input
is retained in the typed transition request; no ordinary movement sequence is
incremented for this native door wrapper path.

`inspect-native-network-door-click.py`:128 original wrapper/getter/sender cases
PASS, including state0..3, transition/run flags, disabled/modal/blocked gates;
the real server walk reader verifies target ID, area, XYZ and action arguments.
Run-mode and message-owner lookup are captured UI boundaries. Queued movement
insertion and AI/object lookup retain the earlier walk oracle's captured lower
boundaries; this is not an emulation of full native pathfinding.

`inspect-native-network-door-flags.py`:128 native BOOL packet writer/full
client door update cases PASS, all six flags and previous trap state. Object
lookup/trap presentation/body shader are captured lower boundaries; the actual
transition setter and field assignments execute. Fixtures are
native-network-door-click-observations.json and native-network-door-flags-
observations.json. Three-fragment padding comparisons follow the existing native
message policy; all defined bits are compared, unused heap padding is excluded.

## Actual vanilla-server gameplay

Owned installed server PID48532 remained running on UDP5121, Prelude. Hidden
real Electron probes used production preload/owned IPC/session and persistent
encrypted peer, and the unchanged installed wizard BIC. No desktop focus was
taken. Test choices/IDs are QA inputs, not module-specific client branches.

v15 approached the locked door, triggering Pavel's authored conversation; the
transition was correctly unavailable while it stayed closed. v16 ended that
conversation and reached Bim, but also aborted Bim before selecting his offered
tutorial choice. Both are retained as incomplete gameplay attempts.

v17 selected the transmitted tutorial-decline reply. The server executed its
authored unlock/open script; the door changed locked1->0, animation22->51.
Explicit Close returned22, Open returned51, then p/6/1 target-door request moved
the same player0xffffffff from area0x80000001/m0q1a to0x80000025/m0q1b.
The new area loaded100tiles/91render bindings,181canonical records; renderer
acknowledgement completed areaGeneration2 and control still bound the same ID.
Captured diagnostics: no error severity, malformed game messages, incomplete
object records, missing clips or object-load failures. v17 report and diagnostics
are archived as local-network-renderer-v17*.json.

v18 then checked movement/return and exposed an area-lifecycle bug: the area
rendered, but the existing player proxy still belonged to the old area and was
excluded from the new scene. This run is not a movement/return pass. Captured
wire data proves the server sends no new A record or area-ID bit for the player;
it supplies P/4/1 and later an ordinary position/reaction U mask65.

Original client Area handler76d910 explicitly calls controlled-object virtual118
to attach the new area, virtual128 to set the entry position, stores position
history, and virtual120 with [cosf(facing),sinf(facing),0]. The world adapter now
applies those transmitted entry values transactionally to the same canonical
controlled creature. It uses the existing original-derived native f32 sin/cos
owner. The capture replay test verifies identity, new area, pose and following
delta-only updates; requests still perform no local area change.

Final v19 repeats the tutorial unlock, explicit close/reopen, area entry, run/
walk in the hallway, and return transition. Native server join02:34:16/logout
02:35:56. Area sequence is0x80000001 ->0x80000025 ->0x80000001; generation3
is ready, final render has9tiles and the same player0xffffffff. The hallway
movement changes native X43.60->44.60 with animation4/run, then returns43.60
with animation2/walk, followed by idle. Both target-door requests were accepted.
255 diagnostics contain zero errors, malformed/incomplete object messages,
missing clips or object-load failures. Captures local-network-renderer-v19.json
and its diagnostics are archived. No physical desktop-input claim is made.

52 focused tests PASS (`network-door-tests-v8.txt`), including both128-case
native comparisons, old/new canonical area ownership, dynamic flag replacement,
actual return/movement capture and prior dialog/movement/IPC/peer/object/area
regressions. Build PASS (`network-door-build-v4.txt`), existing bundle-size warning.
Private credential audit:3063 source/root-note/network-evidence files, zero
full-key occurrences; four synthetic fixture keys counted separately
(`network-door-credential-audit-v1.txt`). Harness syntax check passes.

## Remaining acceptance

The larger interoperability goal remains ACTIVE. Full native hit priorities,
smooth path presentation, physical desktop clicking, doors with other models/
scripts, cross-module/resource transitions, map/loading-screen/audio/UI parity,
inventory/equipment, complete combat/casting/effects and concurrent original-
client users still require work and actual gameplay verification. There is no
claim that request codecs or one campaign transition make multiplayer complete.

Post-seal checkpoint: `backups/multiplayer-door-cycle-20261018-v1.zip`,12181
files /202244629bytes. Writer68841 exited0 after verifying every archived
length/SHA256.29 selected required source/test/capture/validation entries present;
forbidden native/compiled assets, BIC/module files, CD-key config and private
server profile absent. Scope check uses the filesystem's actual roadmap `.md`
casing. This note was added after sealing. Owned server PID48532 remains running;
all integration peers logged out cleanly.
