# Multiplayer melee playback — 2026-10-18

The multiplayer goal remains ACTIVE. Server attack records now reach visible
melee playback, model hit events, linked attacks, typed object reactions and
readiness restoration. This is not full combat/casting or concurrent play with
an original client. Previous goal turn PROGRESS: verified packet projection and
the native animation queue, checkpoint `multiplayer-attack-queue-20261018-v1.zip`.

## Original target and ownership

Read-only installed `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`,
build89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Server SHA256 remains
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
No binary/Ghidra project edits, live injection, native patches, game asset copies
or NWNX additions. All native oracle fixture boundaries are described in their
Python docstrings. REA session99283 remains available; use address/pseudocode,
not provisional filenames, to identify functions.

Native creature PlayAnimation1407fc7d0 uses the client action record, selects
clips via14080f5e0, and inserts fire-and-forget cues via1407635a0. Moving melee
on assembled bodies is deferred. Defender reaction admission excludes result
mask4AB, admits current0/1, and uses the transmitted reaction duration. The262
reaction delay affects its speed divisor, not a fabricated start timestamp.
Existing independently checked melee selectors140800780/14080ffd0/140810c20/
14080f7b0 are reused with active appearance/baseitems values and client-only CRT
cosmetic randomness. No server ResolveMeleeAttack/ResolveDamage/AI/scripts run.

Creature LoadModel140802cc0 registers model event `hit` at call site14080320d,
handler14080e490, literal140e47bb0, with the stable current80-byte action record.
Handler14080e490 advances linked+40 attacks on that event, before clip completion.
It also owns sound/reaction, parry and impact presentation decisions. The new
`client_attack_playback.js` ports these attack branches with explicit providers.
Unimplemented sound, wield/VFX, parry model query and projectile work remains
diagnosed. No guessed missing-model result is returned for the parry query.

`inspect-native-client-attack-playback.py` executes both complete owners with
synthetic source/target/model records and captured selector, clip-length, queue,
sound/bark/effect boundaries. Native getters, record copy, parry classifier and
end-animation helper execute.1310 cases cover movement/body/ranged flags,
result masks, missing objects, targets, linked/nonlinked records, reactions,
barks and draw counts. FLOAT length returns use XMM0; the impact flag uses lowDL,
not dirty upper EDX. Successful oraclev5, comparisons PASS in testsv9.

`NetworkCombatPresentation` owns render bindings, client queues and stable event
userdata. NetworkWorld presentation events are delivered after scene sync, every
received group including identical consecutive groups. Linked copies retain
canonical uint32 IDs. Model events use the existing dispatcher, and held objects
update after the animated skeleton. Removing/replacing a binding clears its
queues, listeners and animator ownership. A newer object looping base cancels
stale reaction cues; the existing door bridge keeps its transition ownership.
Generic base transitions and special client movement/model hooks are not all
ported by this adapter.

## Object name and countdown boundaries

Placeable loader140871440 allocates animation base ctor1409b1fe0,
vtable140e78250; name virtual+58→1409b20a0. Door loader14086e080 uses ctor
1409b06d0/vtable140e778b0/+58→1409b0790. These differ from creature961540.
`client_object_animation.js` retains their enum/name mappings, including damage
for213..216.1281 complete original name executions cover WORD0..425/FFFF,
door model flag0/1, empty override pools; all PASS. A missing door destruction
model flag is an explicit unsupported boundary rather than a guessed default.
Placeable PlayAnimation140870420 forces speed1; door14086da30 uses speed+60.
Clip-length virtual1409614b0 returns FLOAT seconds*1000.

Original queue GetNext1407632d0 returns UINT remaining duration. Its consuming
sequence stores that DWORD at+74 and later decrements/compares it as signed INT.
Placeable AI140870030 calls sequence140870480, door AI14086d640 calls14086dab0;
creature sequence1407fcd70 uses the same signed countdown. Keeping UINT in the
JS playback owner made an overdue short reaction last billions of milliseconds.
`advanceClientAnimationCountdown` now preserves signed conversion and DWORD
subtraction wrap.64 complete original placeable-sequence executions verify
strict-negative expiry, zero remaining, UINT-to-INT cue storage and queued work.
GetNext/Remove, base setter, destruction cleanup and model playback are captured
boundaries in this countdown oracle; this is not complete SetBaseAnimation proof.

Installed pmh0/a_ba inheritance metadata contains2 hit events in1hslashr,
3 in1hslashl and2 in1hstab. These are physical binary entries, not duplicate
listener registrations. The read-only metadata probe compares raw event-array
entries with the parser and stores only three clips' names/lengths/events, not
geometry/controllers/full resources. Physical events remain intact, matching
the separately checked native AnimateEvents/DoEvent ordering.

Repeated hit events can queue multiple short damage reactions. The native UINT
overdue path is retained; signed consumption expires its negative countdown on
the next update. Synthetic integration and livev39 show recovery within one
frame. Intermediatev38 exposed the unsigned-consumer stall. Its old deadline
warning is historical evidence; final code records an `overdue` presentation
trace with both widths instead of reporting this implemented boundary as an
unimplemented engine call. Full original-client capture of these asset/lifecycle
combinations and the rest of SetBaseAnimation cleanup remain independent work.

## Clock and live server verification

Native scheduling uses world-time snapshots, not a clamped render delta. The
scene supplies a monotonic microsecond provider and snapshots immediately at
cue insertion as well as update. A slow-frame regression verifies insertion
after a10-second gap still has900ms remaining16ms later. Browser frames no longer
accumulate the old100ms clamp into the multiplayer scheduling clock.

Owned native server was reset between captures to restore destroyed module
objects, using the exact-install/profile-scoped launcher and the user's session
clearing authorization. Current server PID54292, Prelude,127.0.0.1:5121. All QA
peers are closed; final test PID10828 is terminal/missing and report ends closed.
Installed fighter BIC upload and server binary remain unchanged.

v35: first real visible run,3 native attacks, damage5/9/7, correct weapon clips;
exposed wrong creature-name lookup for placeable reactions and slow-frame clock.
v36: unbounded frame delta exposed stale snapshot/unsigned-underflow behavior.
v37: monotonic insertion fixes attacker timing; object names correct, reaction
countdown issue still open. v38: offscreen GPU1412 paints/~16ms frames proves the
hidden-window1fps test condition, exposes the signed countdown consumer bug.
v39: final signed consumer,1424 GPU paints,2 real native attack groups/records,
1hslashr then1hslashl at speed1.0917/1.0929,5 physical hit callbacks, damage/dead
object clips, restored ready stance. All remaining actors have pending0,
remainingnull, deferredfalse. Short overdue damage reactions restore base in
under40ms. No failure/sampleFailure, scene-combat-unhandled, unavailable clip or
error diagnostics. Audio/wield/VFX omissions remain explicit. Both final PNGs
were inspected; the later image shows the destroyed chest gone and weapon ready.
No full enemy encounter, ranged or casting completion is claimed by this test.

The QA harness now optionally uses real offscreen WebGL without showing/focusing
a desktop window. Installed Electron declarations and the official
[offscreen guide](https://www.electronjs.org/docs/latest/tutorial/offscreen-rendering)
and [webContents API](https://www.electronjs.org/docs/latest/api/web-contents#contentssetframeratefps)
were checked. The harness records paints and actual frame intervals; it does not
fabricate events or simulate combat results. Runtime resolution remains server
authoritative. Production GPU/native pose, materials and all model lifecycle
parity are not claimed complete.

## Validation and next work

174 focused network/client-animation/model-event/clock and singleplayer
presentation regression tests PASS (`network-combat-presentation-tests-v9.txt`).
Build PASSv7, existing large-chunk warning; harness syntax PASS. Credential audit
2249 files:0 unexpected full-key patterns,4 synthetic fixture keys. No private
game credentials were written to source, argv, environment or captures.

Next continue native ranged selection/parry travel, projectile creation/impact,
weapon/impact VFX and audio, then multiplayer spell requests/cast presentation.
Full base/body transitions, pause/time ownership, combat result UI, NPC encounters
and actual simultaneous original-client play still require verification. The
overall multiplayer goal must remain ACTIVE.

Post-seal checkpoint `multiplayer-melee-playback-20261018-v1.zip`:12645 files,
224551369 bytes. Writer88112 terminal0 consumed; every entry length and SHA256
verified.32 selected required files present,0 forbidden game assets/private
configuration entries. These seal notes were added after archive creation.
