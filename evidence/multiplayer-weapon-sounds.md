# Native combat sound selection and delay

Target NWN:EE89.8193.37-17 nwmain.exe SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original binaries/processes remain read-only. Installed resources are read
in memory; no proprietary asset files are copied into this workspace.

## Original flow

Complete805d20 coordinates sound presentation from the server's80-byte client
attack record. Missing record/target/client-object cast returns0. Phase1 does
not simply play a swing for every attack: ranged records select Miss; melee
result mask0x4ab and target parry classifier7625d0 control whether Miss is used.
Parry classifier recognizes206/207/208/262, separately from looping animation
classification. Phase0 is invoked from the model hit owner80e490.

Appearance.SoundAppType indexes appearancesndset2DA. MissIndex is preferred;
if unavailable the selected right/left hand's base-item WeaponMatType BYTE is
used. Only attack weapon types1/6 select right and2 left in this fallback.
Native base-item loader29fda8..29fe06 reads WeaponMatType and stores+aa
(retained scheduler-baseitems-loader-asm.txt). Miss0/1 uses one cosmetic CRT
draw; delay is (WORDduration>>2)+rand()%(WORDduration>>2), consuming another
draw. Zero divisor remains explicitly diagnosed rather than invented timing.

Impacts choose WeapTypeL/R/S/ClsLw/ClsH/Rch using the actual current attack
clip, then the same held weapon fallback for zero. Weapon type19 can add an
immediate Miss cue. Results3/10 add Critical0. Results2/4 against a parrying
target use Parry0. Other impact cues use the target's appearance ArmorType,
equipped armor index via defaultacsounds, or a door/placeable's SoundAppType
via placeableobjsnds. Native creature Custom sound and string460 override
branches are retained by the pure selector. Empty references produce no
hardware source, preserving random/table access ordering.

Armor index is NOT computed from final character AC: active-item reader76bd30
reads server SHORT35c for baseItem16 and writes client INT1b8. Existing
replicated item.field35c supplies it. Creature constructor7fb140 initializes
impact override string460 empty; its later effect-driven override owner is
not yet connected. No guessed replicated field is introduced for it.

All these cues use Play3DOneShot priority13, height1.5, optional volume0
(source default127), and the attacker's pose captured at invocation. The
sound does not follow subsequent movement. Selection and cosmetic CRT draws
remain synchronous before attack animation/bark selection. Async resource IO
does not reorder the native random draw stream or stall packet processing.
Canonical HP, attacks, equipment and movement remain server-owned.

## Delayed one-shot ownership

Wrapper1d9c40 adds height and forwards to internal1df170, which plays immediately
for delay0 or calls SetOneShotDelay1e1500. That stores UINTdelay/start timer,
status3 and adds the source at the delayed-list head. Render1e0c50..1e0c72
uses unsigned elapsed, subtracting one additional tick across timer wrap;
elapsed0 is never due, otherwise elapsed>=delay is due. NativeDelayedSounds
uses this comparison and head insertion, then starts the shared output only
when due. It captures the cue and fixed origin, defers resource demand,
rejects obsolete area/session scopes, and clears on output disposal.

NetworkAudioPresentation retains this queue through the existing GameAudio
output. Native sampler/mixer capacity and synchronized pause semantics remain
diagnosed, as before. Read-only backend research also confirms listener position
1e1410 is passed unchanged; initial source positioning1e0050 differs from
some moving-source setters. This pass preserves the initial one-shot coordinate
path and does not silently change the existing separate moving-source adapter.

## Validation before live rollout

633 complete original805d20 cases execute unchanged selection/control flow,
string composition, random/modulo/delay arithmetic. Tables, casts/equipment,
base item access, CRT draws and one-shot output are captured boundaries.
All production selector calls/results/draw counts match.248 native delay cases
cover complete setter1e1500 with captured timer/list services and the bounded
render expiration branch (not the whole renderer), including UINTwrap/zero.
46 focused regressions and buildv1 pass with the existing bundle-size warning.

Actual installed muted Chromium fixture dynamically selects active appearance,
base-item material and mono Miss/impact resources. Production combat provider,
native260ms deadline, shared one-shot output and clientAttackHit owner produce
real PCM peaks0.1054404/0.0553347. Resource demand does not start before the
deadline; queued origin stays fixed while the isolated model pose moves;
impact captures the new pose. Canonical objects/cursors are unchanged and
disposal clears active/queued sources. PNG inspected. Synthetic actor/model
records do NOT prove a live attack, native device/mixer equivalence, or actual
MDL event dispatch. Native attack/model event owners have separate earlier
original-code and live checks; new live acceptance is recorded separately.

The full multiplayer goal remains active: native effect override/weapon VFX,
parry/damage effects, further live combat/casting, original-origin concurrent
active gameplay and campaign progression are still required.

## Actual vanilla-server encounter

Source checkpointv1 was independently verified before rollout:50files,
2276877bytes;52entries/14parents/50required, zero missing/forbidden/duplicate/
new credential candidates.105 focused regressions now pass (v2). Buildv1
BBbqXxBW was loaded in replacement152/PID32524 after normal-save151 closed.
Original33744 and server20964 stayed running unchanged throughout.

Three ordinary native door requests approached/opened doors from a distance;
normal movement entered the encounter corridor. The unchanged server generated
hostile skeleton/goblin behavior, summoning, attack records, damage, deaths and
voice26/1 packets. Replacement issued one normal typed Attack at Tough Goblin
2147484214; the server resolved its crossbow damage and subsequent combat.
Live data contains delayed enemy swings, immediate enemy melee impacts,
controlled crossbow shots, attack/hit/death voices and actual one-shot starts.
No client AI, damage rolls, health changes or spawned enemies were introduced.

Sealed152 verification replays original packets against active installed data:
51 distinct live cue signatures,22 sampled output start counters,9 native26/1
voice packets, controlled weapon material validated against weaponsounds2DA,
server HP77 down to68, other player's HP86 unchanged. No scene load failures,
runtime errors, combat-audio-unhandled or sound-failed errors. One native
character export precedes normal disconnect. An earlier frozen "settled"
snapshot was HP69 with an empty player action queue; a surviving skeleton was
still attacking and subsequently reduced HP to68 before close. That snapshot
is NOT evidence all hostiles had stopped.

Replacement153/PID33496 reconnects using the saved vault character. A further
ordinary attack targeted surviving skeleton2147484799. Server combat removed
it and delivered damage against a Weak Goblin in the resulting exchange.
Current HP74 is stable in the final passive samples; the original player
remains86. No further automated gameplay inputs are scheduled. Current153
full capture/live/control and interactive stdout/stderr are active and excluded
from backups; explicitly frozen bounded current data and ready PNG are safe.
Native admission may restore health; no local heal or BIC-health persistence
claim is made from reconnect HP.

Duplicate hit callbacks were investigated rather than suppressed. Installed
a_ba parent resource SHA256
a38c9f0de00a7e401419d1e668ad1b9d825cfc9635712cdb9ae63e840104ee2b
contains two physical hit entries at0.5 in both nwcloseh and xbowshot. The
format-aware inherited model probe preserves both and the previously ported
original event iterator emits both physical entries. Metadata/output retained
in installed-combat-events-v1.json; no asset copy. This is not an execution of
the original model loader. Existing whole AnimateEvents/dispatcher oracles
separately establish physical iteration, without an invented deduplication.

This run uses ordinary typed requests for attacks; it does not establish a new
physical radial Attack click or original-origin active shared combat. Native
mixer limits, later creature material overrides, weapon/parry/damage VFX and
broader concurrent gameplay remain open. In particular, moving buffered-source
initial positioning should be compared separately with1e0050; this one-shot
pass preserves its verified initial native position behavior.
