# Combat timing and action-dispatch checkpoint — 2026-10-12

Live sessions now advance creature round timers before that creature's effect
expiry. Round end awaits the authored OnCombatRoundEnd script. Shared attack
action dispatch preserves native group pause duration, target selection and
callback order; range queries use active equipment and appearance rules.
The attack-request provider also reproduces the mapped AddAttackActions gates
and action-manager callback sequence, with explicit AI/perception dependencies.

**Ordinary attacks are still not playable.** The action dispatcher requires
explicit eligibility, movement/animation and strike providers. Missing
providers fail and are recorded before an action is removed or damage/RNG is
changed. Casting remains unimplemented, and native/server parity is unverified.
This extends [damage-effect evidence](combat-damage-bonuses.md).

The subsequent [object-action and eligibility checkpoint](combat-object-actions.md)
adds shared creature queues, AI summaries, cached visibility and geometry gates.
Its 322-test validation is current; the 302-test results below are historical.

Target: NWN:EE `89.8193.37-17`, x64 `nwmain.exe`, SHA256
`3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
Original assets, binary and the open Ghidra project remain unchanged.

## Evidence and behavior

Hash-checked PE-range disassembly is retained under `backups/animations/`:
`scheduler-native-full-asm.txt`, `scheduler-frame-queue-asm.txt`,
`scheduler-baseitems-loader-asm.txt`, and `scheduler-primitives-asm.txt`.
Verified leaf ranges end after their final return instruction. Read-only bridge
exports supplement this evidence; cleanup aliases can truncate them.

Full-range copy-only exports are `resolution-<address>-copy-decompile.txt`
for `14038a610`, `140375b80`, `14039be00`, `1403a7c50` and `14029dfa0`.
The three `headless-scheduler-*-copy.txt` logs confirm discarded changes.
`DecompileCombatCopy.java` now also clears incorrect CALL_RETURN overrides for
the verified returning cleanup thunk `0x140c10360`, which jumps to the already
verified helper `0x140c1148c`. Full disassembly controls function boundaries.

| Native function / call site | Connected behavior |
| --- | --- |
| AddAttackActions `0x14037d180`; ExecuteCommandAttack call `0x140510eff` | Provider-level commandable/state/visibility/reaction/DM/dead gates; distinct +724/+728/+738 target storage; duplicate-request check; clear/front flags; action 12 with object argument type 3; associate command -16, battle-cry RNG before initiative and exact-one door +FC event 34. AI/perception/action-manager providers remain unavailable in live sessions; ActionAttack remains unsupported and diagnosed. |
| UpdateCombatRoundTimer `0x1403a76b0`; AIUpdate `0x14037be20`, inline pause branch beginning `0x14037c5c1` | Signed int32 interval arithmetic, exact paused==1 gate, infinite pause handling, strict negative remaining-time resume, excess interval added to the round, life-state requery after direct round-end scripts and native stationary-animation gate before restoring state 1. AIUpdate orders timer work before UpdateEffectList and RunActions. |
| SetRoundPaused `0x140379c70`; SetPauseTimer `0x140379c30`; DecrementPauseTimer `0x140375a10` | Canonical uint32 pause owner, positive timer accumulation and native infinite-flag behavior. Finite SetPauseTimer does not clear an existing infinite flag. Damage reactions use these shared methods. |
| IncrementTimer `0x140376df0` | End only strictly after length. A due spell anywhere in the action list postpones end; a due attack postpones end only when it is at the head. Future actions and non-head attacks do not change these gates. |
| AnimationStationary `0x14048e320` | Exact ushort narrowing and movement-state exclusions 2..4, 78/79 and 84..87. These state numbers remain distinct from the creature AI-state byte used by GetFlatFooted. |
| EndCombatRound `0x140375b80`; ProcessPendingCombatActions `0x14039be00` | Reset timers before pending-action processing; cleanup and rule counters before direct round-end script; dead actors skip script; PC/familiar script named exactly default is skipped. Pending valid equip/unequip conversion remains unsupported and diagnosed, with queued operations retained. The async adapter awaits the same reset sequence as the synchronous provider. |
| GetActionPending `0x140375de0`; GetAction `0x140375da0`; AddAction `0x140374280` | Due equality, head removal even on premature GetAction, and insertion before strictly later timestamps. Equal-time order remains stable. |
| CombatRoundAction constructor `0x140373fc0`; SetCurrentAttack `0x140379b10` | Mapped scalar defaults, ordinary followTarget=1, byte attack-index narrowing, native warning for indices above 49. Records are internal simulation data, not network packets. |
| AIActionAttackObject `0x1403dcd50`, grouped pause `0x1403ddf22..0x1403ddf4a` | Dispatch sets animation, pauses, changes pending target, faces and resolves in order. Multiple attacks use float32 `(count+1)*0.5*duration` then native integer conversion. Pinned action targets, current targets and pending targets are separate inputs; ID zero remains valid. Pause, step, equipment-provider and skipped-attack branches are mapped. Unknown cases and currentAttack-zero warnings are retained. |
| DesiredAttackRange `0x14038a610`; MaxAttackRange `0x1403997d0` | Right-hand BaseItem PrefAttackDist, appearance PREFATCKDIST fallback for unarmed/base IDs 69..72/explicit override, P/F MODELTYPE weaponscale, target HITDIST, and native nonpositive-range warning. AmmunitionType selects ranged maximum 40 or 20; melee maximum is desired +1.5. |
| Load base items `0x14029dfa0`, float read `0x14029ed3a`; UpdateAppearanceDependantInfo `0x1403a6cfe..0x1403a6d9d`; UpdatePersonalSpace `0x1403a7c50` | Verified PrefAttackDist → base-item +0x3c, weaponscale → creature +0x720, PREFATCKDIST → +0x71c and HITDIST → path-info +0x10. Failed weaponscale reads use one; failed HITDIST reads use 0.5. Missing preferred-distance output with no established deterministic value fails explicitly. |
| AIActionAttackObject `0x1403dd83a..0x1403dd89f` | Geometric maximum-range gate requires the same area, full 3D float32 distance and float32 0.01 slack. This does not substitute for perception, LOS, dynamic use points or pathing. |

The native overshoot pause branch does not decrement the stored pause timer.
After an overshoot, a later SetPauseTimer can therefore add to that retained
positive value. Equality first decrements to zero and resumes on a later
positive interval. Tests preserve both observed paths.

## Validation

- All **302 tests** and the production build pass. New coverage includes
  pause equality/overshoot/infinite flags, overflow, round end retention,
  action ordering, grouped duration, pinned/pending targets, missing-provider
  preflight, native warnings and active physical-row reach calculations.
- Attack-request tests cover each native rejection, duplicate target behavior,
  canonical object zero versus the invalid sentinel, front/clear flags,
  associate target updates, RNG/initiative order and door event delivery.
  They validate the translated branches against disassembly, not an original
  game runtime trace. Field +700 and door +FC retain unnamed provider access;
  no speculative meaning or default value is assigned to them.
- An owned NCS fixture runs through the actual VM during live round end. At
  time 1000 the round and temporary HP remain; at 1001 OnCombatRoundEnd reads
  total HP 35 before temporary HP expires, leaving 30. No queued substitute
  event is used.
- `scripts/smoke-combat-scheduler.mjs` passes under Prelude and Witch's Wake
  for **62** and **229** loaded actors, respectively, including the imported
  PC. All reach queries are finite with zero session query failures. It checks
  live pause/round boundaries while preserving authored GFF, IDs, shared stats
  and HP. Startup is disabled; it does not request or resolve a strike.
- Existing live script-damage checks pass in both modules. All 39 BIC snapshot
  checks still report 39/39 AC, 17/17 available BAB and 38/39 final saves. The
  Weapon Master save discrepancy remains open.
- Hidden bundled full-scene character verification passes. Character stats,
  equipment and spellbook panels retain their expected imported values. The
  initial combined character/startup-journal check used incompatible fixture
  settings and timed out; the separate character check is controlling.
- The separate startup journal/UI check also timed out. Its preview actor had
  no imported creature stats: `ww1_start_onent@0x799` reported that failure,
  leaving startup busy and cutscene input locked after adding 11 journal
  entries. This is an unresolved startup/UI limitation, not a passing UI check.
  The harness now waits for cutscene release and asynchronous panel controls;
  it does not override gameplay input locks to obtain a pass.
- Logs are `scheduler-{all-tests,build}.txt`,
  `scheduler-{prelude,witchswake}.json`,
  `scheduler-{live,combat}-{prelude,witchswake}.json` and
  `scheduler-character-renderer{,-error}.txt` in `backups/animations/`.
  The failed startup check is `scheduler-ui-renderer{,-error}.txt`.
  These checks are not an independent original-game encounter oracle.

The earlier approval-service inspection limit resolved for this pass. Static
inspection and read-only saved-copy Ghidra analysis completed successfully.
Source was backed up before edits in `backups/combat-scheduler-before-20261012.zip`;
the final checkpoint archive is recorded in the roadmap.

## Remaining work

The native AI-level scheduler and world-time source are not fully mapped; this
local adapter iterates registered objects and supplies local simulation time.
RunActions, AddAttackActions request gates, action replacement/cancellation,
perception and LOS, dynamic movement/DoCombatStep, gameplay clip mapping,
attack-record pools, situational/special/defensive resolution and strike HP
consequences remain to be connected and validated. The dispatcher does not
provide fallback successes for these systems. Range comparisons cover geometry
only; equipment/appearance mutation and unusual missing/invalid float outputs
remain incomplete. Full death, equipment and skill coverage are still open.

Finish ordinary melee through those native inputs and compare a real encounter
against the original game, then connect spell action/slots/DC/metamagic,
interruption, impact scripts/effects and presentation through canonical state.
No campaign-specific implementation or invented server protocol was added.
