# Damage-effect and equipment checkpoint — 2026-10-12

Physical and energy damage-effect queries now use the shared active rules,
equipped item projections and live effect handles. Energy queries can update
the caller-owned attack record and consume resistance budgets in native order.
This does not schedule an attack, subtract attack HP, implement casting or
demonstrate independent native/server parity.

Target: NWN:EE `89.8193.37-17`, x64 `nwmain.exe`, SHA256
`3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
The original binary, game assets and open Ghidra project remain unchanged.
This extends [live scripted damage](combat-damage-runtime.md).
The subsequent [timing and action-dispatch checkpoint](combat-scheduler.md)
adds shared pause methods, live round-end scripts and active-rule reach queries;
the latest [object-action and eligibility checkpoint](combat-object-actions.md)
adds shared creature queues, AI summaries and cached visibility/spatial gates.
Its 322-test validation supersedes the historical results below.

## Controlling evidence

Full hash-checked disassembly is retained in `backups/animations/`:
`attack-effect-full-asm.txt`, `attack-effect-item-lifecycle-asm.txt`,
`attack-effect-penalty-query-asm.txt` and
`attack-effect-script-type-bridge-asm.txt`. Full-range copy-only Ghidra exports
for `140393340`, `140406a40`, `14046fee0`, `140470780` and `14046f230` are
`resolution-<address>-copy-decompile.txt`. Headless logs confirm discarded
changes. Truncated bridge pseudocode is supplementary.

| Native function | Connected behavior |
| --- | --- |
| GetTotalEffectBonus `0x140393340..0x14039628c`, damage branch | Active `iprp_damagecost` Rank selection, race/alignment and hand aliases, specific highest-index components, fifty generic slots per sign, grouping by spell AND exact flags, critical rerolls and native traversal/RNG order. Separate increase/decrease caps are applied after draws. |
| Damage constructors `0x1405192a0`, `0x140518e80`; GetScriptEffectType `0x140423fe0` | Cost validation by physical table count, magical default flags, retained zero cost; native types 13/14 map to script types 42/43. |
| Apply `0x14042a290`, `0x140429ce0`; remove `0x140436540`, `0x1404362e0` | Live handles, sorted insertion, creature combat-dirty flag, decrease immunity 21, deferred script removal and strict expiry. Linked icons remain diagnosed. |
| ApplyDamageBonus `0x14046ece0`; enhancement `0x14046fee0`, `0x140470780`; damage penalty `0x14046f230` | Properties 6..10, 16..19 and 21 project damage effects with canonical item creators. Double weapons copy offhand before original, versus conditions are retained, bonuses above +5 search the active fixed-damage rows, and attack/damage penalty immunities remain independent. Ammo bonus properties are excluded from creature projection. |
| Query ammunition; GetArraySlotFromSlotFlag `0x1404629b0` | Active weapon AmmunitionType selects ammo base-item EquipableSlots. Exact single-slot lookup, raw permanent/temporary properties, Rank selection for bonuses and raw CostValue comparison for penalties. Invalid slots and weapon-type warnings are retained. |
| GetDamageRoll `0x1403fee20` | Default physical effect provider replaces the missing callback requirement. The effect query uses native main-hand critical/fallback context even for an offhand base-damage query. |
| GetDamageBonusLimit `0x14055b3f0`; server constructor default | Local query defaults to native cap 100; caller/session overrides remain explicit. No native configuration loader is claimed. |
| AddDamage `0x140374810` | Highest flag component, empty/nonpositive floor zero, existing positive floor one, int32 arithmetic then signed-short storage in an explicit 32-component record. Complete bridge export supports this helper; fresh hash-checked assembly confirmation remains pending. |
| GetSkillRank `0x140406a40`; script wrapper `0x14052fff0` | Partial base-only query: byte skill ID/count, signed-byte rank, final -127..127 clamp, native DM/invalid gates and non-creature -1. Effective ranks fail explicitly. The native zero-rank gate's skill-info +0x28 mapping is pending a full loader audit and is not inferred from the Untrained column name. |

Energy bonuses run immunity then resistance before AddDamage. The native
legacy generic path uses bit 31 for mitigation unless the active
`FIX_EFFECTDAMAGEINCREASE_BYPASSING_DR_AND_DI` rule enables exact flags.
Generic energy penalties update attack components without subtracting from
the query's returned total. Negative energy components also mutate the attack
record during maximize queries. These observed quirks are preserved explicitly.

The async session adapter awaits capacity mutation/removal before the next
component. Maximize queries retain finite resistance budgets; ordinary queries
consume them. Both query variants use one shared rolling algorithm. Querying
components alone does not apply HP, run a strike or send a network packet.

## Validation

- All **278 tests** and the production build pass. New tests cover selection,
  grouping, native draw order, critical context, caps, energy mitigation,
  maximize side effects, ammo lookup, item projection, live effect lifecycle,
  resistance depletion and attack-record arithmetic. Effective skill paths are
  tested to fail instead of returning an approximation.
- `scripts/smoke-damage-bonuses.mjs` passes for all **39 installed BICs** in
  both Prelude and Witch's Wake. Each character gets a fresh module session;
  the same generic probe applies/removes physical and energy bonuses while
  preserving canonical IDs, shared stats, HP and authored GFF. No startup
  scripts or player attacks are scheduled.
- Existing corpus checks still match **39/39 AC**, **17/17 available BAB** and
  **38/39 final-save** snapshots in both rule chains. The existing Weapon
  Master save discrepancy remains open. All **61/61** Prelude and **228/228**
  Witch's Wake placed creatures still load stats.
- Existing live script-damage checks pass in both modules. Authored AI scripts
  still encounter ActionEquipMostDamagingRanged; effective GetSkillRank remains
  incomplete. These failures stay in diagnostics.
- Logs are `backups/animations/attack-effects-{all-tests,build}.txt` and
  `attack-effects-{bonuses,combat,creatures,live}-{prelude,witchswake}.json`.
  These are replacement integration checks and imported snapshot comparisons,
  not independent original-game encounter results.
- The previous checkpoint's renderer check is historical. It was not rerun
  for this slice. Additional native inspection could not execute because
  automatic approval review hit an approval-service usage limit. That service
  failure was not a determination that the read-only action was unsafe.

Source was backed up before edits in
`backups/combat-effects-before-20261012-161811.zip`; the final checkpoint archive
is recorded in the roadmap. No original game resources are included.

## Remaining work

Ordinary attack action scheduling, perception/range inputs, native animation
pauses and cancellation, damage-to-HP strike integration, full defensive/special
attack/death providers and independent encounter validation remain open.
Equipment mutation, complete item/effect coverage, saved-effect restoration,
effective skills and linked icons are not complete. Spell slots, DCs,
metamagic, interruption, impact scripts and casting presentation follow combat.
No campaign-specific exceptions or invented multiplayer packets were added.
