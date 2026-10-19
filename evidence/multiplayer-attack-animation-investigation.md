# Multiplayer attack records and animation queue — 2026-10-18

The multiplayer goal remains ACTIVE. This checkpoint verifies attack-record
projection, delivery of repeated attacks as presentation events, and the native
animation queue. It does **not** connect that queue to NetworkScene playback or
claim full multiplayer combat, casting, or concurrent original-client play.

## Target and original-code evidence

Read-only installed `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`,
build89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No binary/project edits, live injection, copied game assets or server patches.
REA dossiers are in `backups/animations/rea-network-combat-*.json` and
`rea-network-animation-*.json`; reuse persistent REA session99283.

Server UpdateObject1404eb590..1404edc50 writes the mask4 speed FLOAT from+DC
and animation WORD from+D8. Animation9 uses creature+880 combat round,
BYTE current index+2F2C and GetAttack140375e40, strideF0. It counts matching
groups among at most the last three attacks, then sends the last count records.
The noncontiguous synthetic group2/1/2 deliberately retains that exact behavior.
GetTotalDamage1403767a0 is a captured aggregation boundary in this oracle;
actual packet damage width9 executes unchanged, including512 becoming0.

Client creature update140781e80..1407857e8 reads the complete record and invokes
the virtual+150 PlayAnimation owner with a linked list of80-byte action records.
Constructor1407fb0e0 supplies zero reaction delay, not a transmitted timestamp.
The first FLOAT is speed, stored at client+60. The old decoder property name
`animationTime` remains compatible; NetworkWorld also exposes `animationSpeed`.

Wire fieldA/C/2/result/7A/damage/5C/68/56 maps to client reaction WORD+16,
reactionDuration WORD+18, duration WORD+8, result BYTE+C, attackType WORD+1A,
damage WORD+A, ranged DWORD+1C, killingBlow DWORD+20, weaponAttackType BYTE+24.
Source/target IDs retain their uint32 values. Empty groups allocate one default
type0 record. Missing-client-object cases still consume the packet without
calling the animation boundary. The JS projection matches96 original complete
server-writer/client-reader executions across formats0/1, groups, missing
objects, damage truncation and result widths.

Oracle `scripts/inspect-native-network-attack-records.py` executes real scalar
writers/readers, GetAttack, admission classifiers and record constructor.
Object lookup, stationary path classification, damage aggregation and final
model/UI/motion/audio/PlayAnimation calls are explicitly captured boundaries.
It does not emulate a combat round, movement interpolation or a complete client.
Result `native-network-attack-record-observations.json`, successful runv8.

## Queue behavior and production changes

`src/client_animation_queue.js` ports InsertFireForgetAnimation1407635a0,
GetNextFireForgetAnimation1407632d0 and RemoveFireForgetAnimation140763fb0.
Entries grow in groups of8 and are stably sorted by world start time. Duplicate
record pointer identity is rejected; separately allocated equal attacks remain
separate. Remove shifts every field and restores the inactive tail defaults.
GetNext retains native uint32 subtraction, minimum50ms and FLOAT speed
rescaling. Overdue unsigned underflow is not silently changed to a signed clamp.
GetTimeDifferenceFromWorldTime140597090 uses one time-of-day borrow after its
date check; it does not multiply elapsed full days. Native date wrap behavior is
retained. Invalid start dates and BYTE queue overflow are explicit errors before
undefined native storage behavior; they are not claimed as supported playback.

`scripts/inspect-native-animation-queue.py` executes these complete owners,
entry constructor140761730, native AddWorldTimes140596b40,
CompareWorldTimes140596e50, GetWorldTime140597180 and elapsed-time arithmetic.
Synthetic paused timer dates, allocation/free, app timer lookup and warning
output are boundaries.60 sequences cover growth beyond8, stable equal dates,
duplicate/nonduplicate pointers, null records, removal/empty defaults, future
and overdue playback, zero duration,50ms floor and day/DWORD wrap. All observed
entries and output fields match JS. Fixture `native-animation-queue-observations.json`.

NetworkWorld now atomically publishes `attack-animation` presentation events
for each mask4 attack group. Equal successive animation9/speed values produce
distinct records. Attack groups no longer persist as stale replicated state.
An unrelated position update emits no attack event. Failed mixed-type imports
retain the prior registry and prior published events. Packet inputs remain
unchanged. No local combat resolver, AI, NWScript, HP edit or RNG was introduced.

## Actual vanilla-server capture

Same owned native nwserver PID48532, Prelude,127.0.0.1:5121. All QA peers closed;
the server remains running. User authorized clearing sessions if required.
Capturev33 used unsupported shorthand `attack` in the QA harness; its rejected
request is a harness input error, not evidence of a failed native attack packet.
Capturev34 used real `combat.attack` requests through existing renderer/IPC.
Both requests sent; report ends closed without failure/sampleFailure.

`scripts/replay-network-attack-capture.mjs 34` replays25 complete object updates
and finds one actual server attack for playerFFFFFFFF against placeable80000012:
duration916ms, damage24, result3, killingBlow1, reaction14, reactionDuration0,
weaponAttackType1. The other request targeted a creature but did not demonstrate
a repeated encounter. This proves real attack traffic and projection, not final
visible animation or a complete combat cycle. The old renderer still reports
its attack/cast coordinator diagnostic. No new live peer was launched afterv34.

## Validation and remaining work

139 focused networking/client-animation/world-timer tests PASS
(`network-animation-queue-tests-v4.txt`), including all original-code comparisons,
transaction rollback, repeated-event identity and actualv34 replay. Build PASS
(`network-animation-queue-build-v1.txt`), existing large-chunk warning.
Credential pattern audit2175 source/note/network-evidence files:0 unexpected
keys,4 synthetic fixture keys. No private credentials were written by this pass.

Next: original attack action lifecycle and native animation-event ownership,
then bind the verified queue and existing client-only melee selectors to
NetworkScene. Preserve linked attack groups, moving-melee deferral, native
defender reaction admission/timing and ranged projectile/parry travel. Static
PlayAnimation1407fc7d0 and select attack14080f5e0 are mapped, but those complete
owners still need isolated oracle comparison before claiming faithful playback.
CNWCCreature ctor1407fb140 vtable140e474e8 slot150→1407fc7d0; slot1C0→1408107a0
is area/timer gating, not linked-attack advancement. Function1407fcca0 is a
defender reaction helper, not next-attack advancement.140805d20 schedules combat
sound, not queue insertion. Some older REA filenames used those provisional
names; follow target addresses/pseudocode instead.

Spell requests, cast coordinator/effects/audio, full combat results UI,
equipment torch/worn-model transitions, containers and actual simultaneous
original-client play remain open. Do not mark the multiplayer goal complete.

Post-seal checkpoint `multiplayer-attack-queue-20261018-v1.zip`:12529 files,
218097353 bytes. Writer77683 terminal0 consumed; all entry lengths and SHA256
verified.24 selected required entries present,0 forbidden assets/private config.
Scope check initially used uppercase.MD for the on-disk lowercase.md roadmap;
correcting that case-sensitive ZIP lookup passed. No archive content changed.
These seal notes were added after archive creation.
