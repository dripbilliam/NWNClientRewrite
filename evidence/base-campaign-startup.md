# Original campaign startup coverage

Target: NWN:EE89.8193.37-17, original `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The installed game and Ghidra project remain unchanged. Reports contain
diagnostic metadata and synthetic oracle results, not copied game resources.

## Observed startup failure and correction

`scripts/audit-campaign-startup.mjs` starts each of the seven original campaign
modules in a separate process, with a fresh canonical registry, VM and resource
resolver. It initializes every IFO-listed area, enters the authored starting
area and pumps12 seconds of native AI with startup scripts enabled. The stock
installed `fighter.bic` is an import fixture, not a newly created low-level PC.
Later chapters start independently without carried quest state. Combat messages
are captured by a local callback; audio, renderer and UI are not exercised.

The first complete run failed during startup in five modules. `updateWorld`
incorrectly applied the fallback scheduler's256-event limit to the native AI
master, throwing while normal finite spawn batches remained queued. The corrected
adapter drains native due events without that fallback limit. Original
UpdateState140559cf0..14055acb2, particularly its event loop14055a300..14055a4e9,
has no such256-event cutoff and delivers due events before advancing the AI list.
Equal-time insertion order and newly appended due events remain unchanged.
The fallback scheduler retains its own bounded pump.

A regression exercises1250 queued events plus a same-time append, verifies the
complete order, checks that AI does not interrupt the batch and retains a future
event. The installed original campaign now completes the startup audit in all
seven modules without the previous fatal delivery exception:

| Module | Areas initialized | Initially queued events |
| --- | ---: | ---: |
| Prelude | 5 | 124 |
| Chapter1 | 113 | 723 |
| Chapter1E | 10 | 70 |
| Chapter2 | 79 | 1240 |
| Chapter2E | 38 | 496 |
| Chapter3 | 46 | 591 |
| Chapter4 | 30 | 372 |

The full journal preserves every occurrence in a per-module JSONL file. Grouped
JSON reports retain script PC, engine ordinal, object arguments, canonical IDs,
source keys, counts and severity. Initialization and startup are separate phases.
`--require-ready` fails when any module has a fatal error, an error diagnostic or
an observed unsupported/partial owner at any severity. Completion of the audit
is not a readiness pass.

## Native query and authored orientation evidence

Ghidra pseudocode for GetStringLeft truncated around exception cleanup. Complete
unwind assembly is retained instead. `scripts/inspect-native-campaign-queries.py`
executes original instructions read-only under Unicorn, with explicit boundaries
for VM pops/pushes, canonical lookups, string allocation, CRT C-locale setup,
floating status flags, sqrtf and the waypoint's unrelated position store.
The integer parser, atan2f and bounded orientation imports execute unchanged.
Door trigonometry executes the original CRT SSE branch. Other locales,
exceptional input and an unknown FMA dispatch state are not covered by this
oracle. Live math keeps existing exceptional/dispatch diagnostics.

| Owner | Native address | Original cases |
| --- | --- | ---: |
| CExoString::Left / script wrapper |14016bcb0 /1403139d0 |32 |
| StringConversions case232 / atoi / signed decimal parser |140547900 /140c81d54 /140c8047c |26 |
| GetAssociateType |14051f470 |42 |
| GetSittingCreature |14052ff70 |8 |
| GetFacing, including its CRT atan2f |140523a70 /140c8f29c |2244 |
| LoadCreatures orientation block |140360815..140360898 |72 |
| LoadWaypoint orientation block |14050a149..14050a21d |72 |
| LoadDoors bearing-to-vector block |140360a85..140360b9e |132 |

The2628-case capture is `backups/animations/native-campaign-query-observations.json`.
All cases match the replacement. Signed zero survives facing inputs; vector
output comparisons explicitly account for JSON's inability to preserve a zero
sign. Missing required canonical fields and unmapped text encoding still fail
with diagnostics.

Observed contracts:

- Left uses a signed count and stored byte length; negative produces empty text.
  StringToInt parses a C-locale decimal prefix, stops at NUL/junk and saturates
  at signed32 limits. JavaScript Number/parseInt conversion is not substituted.
- Associate type is WORD908 and only returned when master8fc is not INVALID.
  Sitting creature is placeable DWORD36c, initialized INVALID by its constructor
  at1404afd0d. The raw occupant ID is returned without validating that ID again.
  This query does not implement ActionSit or chair occupancy mutation.
- Facing uses original XY for atan2f and normalized Y only for360 adjustment.
  Native FLOAT constants, per-operation rounding and CVTTSS2SI after adding0.5
  are preserved. A missing/non-world object returns0. It reads current orientation,
  rather than a cached renderer bearing.
- Authored creatures now import raw X/Y/ZOrientation from the placement, matching
  LoadCreatures; waypoints normalize their authored vector. Doors/placeables use
  the half-angle quaternion conversion, preserving native FLOAT operations.
  LoadPlaceables140361b8b..140361cac repeats the verified door calculation;
  SetOrientation1404b7680 first stores its input vector. Initial loading occurs
  before area insertion, so its runtime collision replacement branch is not
  selected. Dynamic placeable rotation/collision remains an explicit limitation.
- CNWSObject's default orientation14048b998..14048b9af now initializes all its
  world object types, not only creatures. Authored orientation import is separate
  from the constructor and does not normalize raw creature vectors.

Complete captures are the `campaign-startup-*-full-asm.txt` and query-named
`campaign-*-plain.txt`/`campaign-*-asm.txt` files under `backups/animations`.
One initial import oracle stopped at an unmapped waypoint SetPosition dependency;
the revised oracle explicitly captures that separate owner. Its failure is kept.

## Validation and remaining gates

1177 tests pass and production build passes. The installed combat integration
still resolves retaliation, approach and attacks, clears all four members of the
authored encounter and deactivates its canonical encounter owner. Six observed
omissions still prevent combat readiness: traps, dirty-stat refresh, corpse
cleanup, automap, achievement presentation and voices. Corpse transfer/copy and
cleanup are not bound by this change.

The final campaign startup readiness check deliberately fails. Among its
remaining selected engine calls are DoSinglePlayerAutoSave, ActionSit,
ActionMoveAwayFromObject, SpeakOneLinerConversation, EffectSleep, EffectAppear,
EffectVisualEffect, EffectSpellResistanceIncrease, CreateObject and
ActionCastSpellAtObject. Native DoSinglePlayerAutoSave140516680 checks the app's
multiplayer flag, walks the player list until a creature with an area is found,
then sets the server's pending autosave flag. Its persistence owner is not mapped
or implemented; this research does not replace it with a successful no-op.
Installed missing resources (`plc_w02`, `plc_d07`, `script1`,
`nw_d2_bossspawn`) remain recorded, alongside unsupported gameplay owners.

Baseline: `backups/campaign-startup-baseline-20261014`.
Final strict audit: `backups/campaign-startup-final-1177-20261014`.
The intermediate event/query/orientation runs are retained separately. Their
sampled AI traces can vary with RNG and native elapsed-time budgeting.

The combined rendered cancellation/second-attack smoke failed to pick its target
again; its log and failure screenshot are retained as
`campaign-orientation-combat-ui*`. This is not a passing rendered cancellation
acceptance. A separate attack/animation check is recorded independently.
The spawned attack-only attempt also timed out waiting for a queued icon. Its
timeout snapshot shows the selected target574 already atHP-11/held-dead8,
the PC retargeted to588, and zero animation failures across26 actors. This
proves the target died during the attempt, not that the transient queue-icon
assertion or complete rendered smoke passed. The scripts, logs and failure
screenshots remain unchanged for follow-up.

The separate authored-target rendered smoke **passes**
(`campaign-orientation-authored-attack-ui.txt` and screenshots). Canonical target475
queues Attack in group0, retaliates, receives a real player swing202 and plays
220 fall ->222 death transition ->8 held dead, HP-11. All26 actors report zero
animation failures. The attack screenshot was inspected: PC and goblin are
visible, the real queue icon is present and combat feedback contains resolved
enemy/player rolls and damage. Camera obstruction remains visible elsewhere in
the scene. This passes this local rendered fight, not the failed spawned-target
attempts, a complete campaign playthrough or native/network parity.

The authored-target cancellation smoke also **passes**
(`campaign-orientation-authored-cancel-ui.txt`): an actual click on the queue icon
routes action3/group0 through the FIFO for actor565, the group disappears,
the same canonical target475 is selected through the real picker/radial again,
and the fresh attack finishes with HP-11/held-dead8 and zero animation failures
across26 actors. Neither authored test overrides stats, equipment, RNG or AI.

Entire-campaign acceptance still requires actual low-level character creation,
quest/dialogue/journal progress, companions, inventory and corpse loot, casting,
resting, leveling, stores, area/chapter transfers, save/reload and final completion
with the original campaign's scripts. Initializing321 areas and sampling startup
does not establish those behaviors or original-client/network parity.
