# Combat reputation, attack storage and delivery — 2026-10-12

## Status and target

**Combat is not ready.** This pass extends native-traced providers and connects
scheduled creature damage effects to the existing live HP runtime. The renderer
still does not drain a complete attack/approach/strike backend, and its Attack
radial entry remains a placeholder. Casting and original-server coexistence
are not implemented or validated.

Target: NWN:EE `89.8193.37-17`, installed x64 `nwmain.exe`, SHA256
`3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
Static inspection checks that hash. The original binary, assets and open Ghidra
project were unchanged. Cleanup-flow fixes for faction decompilation were made
only on the saved copy under `backups/ghidra-saved-before-combat-20261012-042456`
with `-readOnly -noanalysis`; the successful headless log confirms discarded
changes. Earlier oversized-range/leaf inspection failures were corrected; the
complete assembly exports below control over truncated bridge pseudocode.

## Verified native evidence

- `LoadFactions 0x140357d20`, `LoadReputations 0x140357f40`,
  `GetDefaultPCReputation 0x1403577e0`: NPC count is FAC faction count minus
  the initial PC faction. Reputation matrix has `N*(N+1)` cells initially 100.
  FAC writes row `FactionID2-1`, column `FactionID1`, and clamps values 0..100.
  `GetNPCFactionReputation 0x140357cc0` selects its row using the **first
  argument**, swaps only when that argument is non-NPC and the second is NPC,
  and validates the resulting flat index. Do not replace this with a guessed
  symmetric map or independently validate a column that native code permits
  to spill into a later row. Module load calls are at `0x1404824b4/0x1404824f1`.
- `CNWSFaction` constructors `0x1404ad3e0/0x1404ad520` append a distinct PC
  faction without increasing NPC count. `PostProcess 0x14039b72b/0x14039b736`
  allocates/sets an independent PC reputation vector when absent. Saved BIC
  `ReputationList` remains live ordered data, separate from the FAC matrix.
- `GetReputation 0x1404abcd0`, `GetCreatureReputation 0x1403d4e20`,
  `GetAIStateReaction 0x1404ab6c0`: PC/NPC delegation, master inheritance,
  associate types 7/8, own-child/master rules, AOE creator traversal, DM/self
  rules, final clamp, PC PVP list and live PC vector. AI queries the target
  receiver's reputation toward the actor. `GetReputation` VM wrapper
  `0x14052fae0` looks up the second object argument and queries with the first.
- `CalculatePersonalReputationAdjustment 0x1403d10b0`: reverse matching-record
  traversal, target/master matching, familiar exemption, expiry removal and
  float32 decay using **180000 ms**, irrespective of the record duration.
  It uses the elapsed time remainder and ignores elapsed days.
  `SubtractWorldTimes 0x140597a20` preserves unsigned borrowing and failure
  status. Actual native world-time generation is not yet connected.
- `GetPVPSetting 0x14035ea70`: inherited area value 3 and actual configured
  server masks. A missing server setting is required input for nonzero area
  settings, rather than a guessed value. ARE header load `0x14035faf0` uses
  zero as the missing `PlayerVsPlayer` field default.
- `CNWSCombatAttackData` ctor `0x140373d20`, clear `0x1403756c0`,
  `ClearAllAttacks 0x1403754d0`: embedded **50-record pool**, each `0xf0`
  bytes, cleared in place. Damage has **32 signed shorts initialized -1**.
  Group byte +0 is not weapon type; weapon type is +56, combat mode +57,
  ranged int +5c, coup-de-grace int +6c, result byte +78, special type +7a.
  `GetAttack 0x140375e40` clamps indices >=50 to slot 49 with a warning.
  Negative native indices are explicitly unsupported rather than simulated
  out-of-bounds memory. `Copy 0x1403757d0` copies scalars/optional strings,
  **not** the attached effect/message lists. Padding is not treated as state.
- `SetAnimation 0x1403a2bb0`, `SetCombatState 0x1403a2f60`,
  `SetLockOrientationToObject 0x1403a3320`: body/combat idle remaps, seated
  gate, case-sensitive MODELTYPE letters, full 3D float32 unlock orientation,
  missing versus cross-area target behavior, timer/initiative reset and
  in-place attack clear. Clearing combat state does not end/unpause a round.
  Vtable entries at `0x140ddd5d8/0x140ddd660/0x140ddd668` verify animation,
  orientation setter/getter calls. Normalize `0x140230920` calls sqrtf
  `0x140c7d6d8`; `SetOrientation 0x14049b910` copies the full vector.
- `ChangeAttackTarget 0x1403e2530`, attack `ClearAction` branch
  `0x1403871be..0x140387200`: separate +724/+728/executing target IDs,
  following versus pinned round actions, sticky-mode dependency, pending
  equipment processing, animation and attack cleanup, and unlock order.
  `UpdateAttackTargetForAllActions 0x14037a140` only updates type-1 actions
  whose follow flag equals one. Other action cancellation/path reset remains
  required work. The object-action argument model stores the low 32-bit ID;
  it is not a byte-for-byte native pointer-slot or wire representation.
- Forced mode zero follows `SetCombatMode 0x1403d8c50` and `SetActivity
  0x1403a2650`: single-bit clear, locked mask veto, defensive casting/stance
  side effects. Missing side-effect providers fail before mutation. Native
  defensive stance type constant `0x140de7b40` is 95. Full mode activation,
  pending-mode/equipment changes and round-end activity side effects remain
  separate integration work.
- `ResolveAttack 0x1403e3c60` inlines `ResolveMeleeAttack 0x1403e64e0`:
  group/target/mode/weapon, situational and cached-special resolution, attack
  roll, hit-mask `0x4ea` damage/post-damage, animations, current-attack update,
  then signaling. Call sites `0x1403e6587/0x1403e6595/0x1403e65bb/
  0x1403e65d8/0x1403e65e3/0x1403e65f8` establish the sequence. The generic
  group dispatcher requires the unported strike providers; it cannot stand
  in for the complete native `ResolveAttack` preparation phase.
- `ResolveRangedAttack 0x1403ea290`: ammunition cap, ranged record flag,
  distinct miss branch, no melee +57 mode copy, available count to signal.
  Missing ammunition/projectile/equipment/special providers remain explicit.
- `ResolveMeleeAnimations 0x1403e6280`: busy animation mask, miss/parry/hit
  reaction metadata, defender pause ownership and full-duration admission
  before half-duration pauses for earlier group members. `CheckActionLength
  0x140375430` uses exact-one state tests and int32 arithmetic. Animation
  misses call MSVC rand `0x140c7ed00` at `0x1403e634b`, **a different stream
  from NWN dice**. Its generator is ported, with required explicit seed;
  native startup seeding and model clip routing are still open.
- `SignalMeleeDamage 0x1403ed7e0`, `SignalRangedDamage 0x1403edcc0`:
  AI event IDs 15 (attack data), 20 (AoO), 22 (feedback), 5 (effect), 19
  (actor/other effects); copied attack data versus original list payloads;
  reverse feedback and forward effect order; distinct impact/release/travel
  delays and melee/ranged effect flags. These are **internal AI events**, not
  network packets. Event 5 reaches creature ApplyEffect at `0x14038e556`.
  Other live event handlers remain diagnosed; standalone receiver event-15
  logic is available with required providers, not auto-enabled.
- Event 15 `0x14038eaa7..0x14038edb0`: receiver attack history even on misses,
  caller weapon slot, direct OnAttacked after initiative, and separate dead/
  possessed-script-suppressed retaliation branch (`0x14038ed37/0x14038ed8a`).
  VM getters `0x140529b60/0x140529cb0/0x14052ae40` translate internal attack
  type/mode IDs, respect current combat-state gates, and retain weapon IDs.

Controlling exports: `backups/animations/live-reputation-asm.txt`,
`live-faction-loader-asm.txt`, `live-faction-callers-asm.txt`,
`live-faction-constructors-asm.txt`, `live-target-cleanup-asm.txt`,
`live-strike-lifecycle-asm.txt`, `live-cancel-signal-asm.txt`,
`live-attack-copy-events-asm.txt`, `live-combat-events-animation-asm.txt`,
`live-strike-damage-length-asm.txt`, `live-combat-getters-object-ctor-asm.txt`,
and the successful `headless-live-factions-copy.txt`. Original-project bridge
exports have `live-<address>-decompile.txt` names.

## Validation and limits

The tests exercise asymmetric faction data, unsigned borrowing, PC vectors,
associate/PVP/decay rules, canonical references, persistent pool identity,
cancel/retarget/animation gates, strike call order, ammo limits, effect flags,
snapshot ownership, delayed HP delivery and direct receiver-event order.
The delayed-HP integration deliberately supplies a resolved strike fixture:
event 15 remains diagnosed and event 5 applies 8 damage at **428 ms** after
an 857 ms animation. It is not a playable encounter or native combat oracle.

Installed-data checks pass under both Prelude (62 stat-loaded actors) and
Witch's Wake (229), including FAC/PC vector queries, mutable reputation,
action storage, timing, script damage and 39-character damage bonuses.
Startup remains disabled in these fixtures. The bundled full-module character
renderer passed; its screenshot was inspected. Its first invocation inherited
Electron's Node-only mode and never started the renderer; the corrected child
environment passed. Existing resource/controller/camera limitations remain.

Source backups before/through this pass:
`backups/combat-live-before-20261012.zip`,
`backups/combat-reputation-progress-20261012.zip`,
`backups/combat-strike-progress-20261012.zip`.
The final archive/test total is recorded in the roadmap.

Next: complete actual perception/LOS/approach and client/associate ownership,
native ResolveAttack preparation and default strike/post-hit providers,
event 15/19/20/22 integration, ammo/projectiles, defensive/special/death/status
branches and model animation routing. Drain the shared action queue only when
those operations are available. Compare complete ordinary and exceptional
encounters against the original game before accepting combat readiness;
then complete casting through the same canonical state and event ownership.
