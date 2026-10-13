# Character rules and stored-history progression

Current combat-linked feat-use, NPC loading, skill cache and live provider status: [Combat action-loop checkpoint](combat-action-loop.md). Earlier unavailable-provider lists below are historical; manual creation/selection remains unfinished.

Checkpoint: 2026-10-12. This implements the PC XP/history mutation slice. It does **not** complete character creation, manual level-up validation, combat stats or every native LevelUp/LevelDown side effect.

Target: NWN:EE **89.8193.37-17**, local `nwmain.exe`, SHA-256 `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`. Analysis was read-only. Source checkpoints are under ignored `backups/progression-*`; no game assets or binaries are included. Ghidra was not modified.

## Observed native mutation contracts

| Routine / address | Contract used in this slice |
| --- | --- |
| `SetExperience` `0x140415640..0x140415956` | Stores uint32 XP, treats subtraction as signed int32, reconciles levels only on the feedback-enabled path. Loss walks XP thresholds down to the server minimum. Gain replays existing history while CanLevelUp succeeds. |
| `CanLevelUp` `0x1403f1b30` | Associate types 3 and 5–8 cannot advance. A connected player is capped at level 40; the server maximum and the stats XP-requirement flag also apply. The replacement currently supports imported PC stats, with configurable local minimum/maximum and an explicit NPC stats limitation. |
| `LevelDown` `0x14040bbd0..0x14040c849` | Decrements the matching class slot and updates memorized slot counts before ability/feat changes. Subtracts the recorded hit die, ability increase, skill rank deltas and feats; reverses known/removed spells; restores remaining skill points from the preceding record. Removes and frees the active history record. Drops a zero-level class only when it is the final class slot. |
| LevelDown HP tail `0x14040c7ee..0x14040c82c` | Adds the maximum-HP difference to current HP, narrows to signed short, then clamps to at least 1. This branch does not use the LevelUp dead check. |
| `LevelUp` `0x14040c870..0x14040d64e` | Stored-history replay passes the final flag as zero, so it does not append history or replace domains/school. Applies the recorded changes, including feat ability bonuses and spell swaps. Living creatures gain the maximum-HP difference without the LevelDown clamp; dead PCs retain current HP. |
| `ComputeFeatBonuses` `0x1403f2110`, `GetStatBonusesFromFeats` `0x1404097c0` | Great Strength/Dexterity/Constitution/Intelligence/Wisdom/Charisma feats modify stored ability bytes, separately from derived class stat gains. Default engine constants are used; custom ruleset constant overrides remain open. |
| `SetClassLevel` `0x1404153f0`, `UpdateNumberMemorizedSpellSlots` `0x140418a60` | Class changes refresh memorized slots. Counts combine class spell gain, base casting ability, specialization, prestige progression and separately maintained item bonus slots. Growing adds empty slots; shrinking removes the tail. |
| `GetSpellGainWithBonus` `0x140408120`, `CNWClass::GetSpellGain` `0x140299e40` | Primary ability comes from class rules. `NumSpellLevels` gates access to gain-table cells. Effective caster level includes qualifying prestige progression; ties for the highest class of the same magic type favor the later slot. Native class spell-gain lookup accepts effective levels 1–40. |
| `ApplyBonusSpellOfLevel` `0x14046e820`, `ModifyNumberBonusSpells` `0x14040f110` | Every applied bonus-slot item property increments one class-slot counter. Subtype selects the class; the low byte of CostValue selects spell level. CostTable is not a spell-level remapping table. Counters survive ordinary level changes; a newly constructed class slot starts with zero counters. |
| `SaveItemProperties` `0x14046c130` | Confirms the native property layout: Subtype at +2, CostTable at +4, CostValue WORD at +6. Installed NWScript defines bonus spell slot property type 13. |
| `AddKnownSpell` `0x1403ef2e0`, `RemoveKnownSpell` `0x140412890`, `ComputeNumberKnownSpellsLeft` `0x1403f22c0` | Resolve the spell level from the class's spell-table column. Removal erases the first matching known entry. Addition obeys known-spell capacity for restricted non-memorizing casters and the native spellbook flag. |
| `ClearMemorizedKnownSpells` `0x1403f1e30..0x1403f1fb0` | Clears matching base-level slots, then visits metamagic masks with the observed `i ^ 2` sequence for i=0..5. This unusual XOR loop does not visit Quicken's mask. Empty slots remain at their positions. |

Several decompilations end early because the cleanup thunk is marked non-returning. Full bounded disassembly was used for the LevelDown/LevelUp bodies, HP tails, slot resizing and the metamagic loop. The replacement preserves the observed XOR behavior instead of substituting an assumed metamagic loop.

**Erased history and future history are different.** XP gain after normal level loss cannot recover choices that LevelDown freed. A character already authored with extra future records can replay those records. Loss removes active records while leaving future records beyond them in the array; subsequent replay uses their new positions, as the native routine does.

## Implementation and canonical state

[character_progression.js](../src/character_progression.js) prepares mutations on an isolated clone, then commits them to the existing canonical creature. IDs, owned-item IDs and the shared stats object retain their identity. Corrupt/missing rules fail before mutation. This atomic failure behavior is a replacement safety boundary, not a claim that the native engine rolls back corrupt input.

`authored` retains the imported BIC. `creatureData` is the mutable character adapter. `ClassList[].bonusSpellSlots` holds runtime class-info counters, not an invented GFF field. `cloneGff` retains GFF struct-type metadata, so equipment slot masks survive cloning. Script feat/spell queries, character panels and spellbook views use live data; healing also updates live current HP. Spell panels now refresh when shared stats change. Saving this state to BIC is still pending.

The rules loader follows the names in `classes.2da` for StatGainTable, SpellGainTable, SpellKnownTable, AttackBonusTable, SavingThrowTable, SkillsTable, FeatsTable, BonusFeatsTable and PreReqTable. The installed corpus resolves **115 distinct referenced tables** through the normal module/HAK/base resolver. Loading a table does not mean its whole consumer is implemented. Runtime code contains no Witch's Wake branch, script-name substitution or fixed campaign object IDs.

## Broader class/feat/skill/stat work

The following entry points are located and their initial decompilations reviewed. These are starting maps for the next slice, **not completed validators**:

| Area | Native entry points | Remaining work |
| --- | --- | --- |
| Class availability | `GetIsClassAvailable` `0x140402e10` | PlayerClass flag, alignment masks/inversion, MaxLevel/EpicLevel and prestige requirements. Map `GetIsAlignmentAllowed` and `GetMeetsPrestigeClassRequirements`, including prerequisite-table interpretation. |
| Feat selection | `CanChooseFeat` `0x1403f1830`; `FeatRequirementsMetAfterLevelUp` `0x1403f3190`; `CalcLevelUpNumberFeats` `0x1403f15c0` | Ordinary vs class-bonus eligibility, racial/general feat cadence, automatic grants, prerequisites, pending selections, domains/school and epic exceptions. Verify cleanup/return tails in assembly. |
| Skill purchases | `ValidateLevelUp` `0x140418b80`; `IsSkillClassSkill` `0x14029a250`; `IsSkillUseable` `0x14029a300` | Class tables govern class-skill and exclusive availability separately. The reviewed validator charges one/two points, applies class/cross-class caps and checks the budget. Map racial skill ability, first-level multiplier, unspent points and exceptional classes before implementing choices. |
| Other stats | `GetBaseAttackBonus` `0x1403f8e90`; base Fortitude `0x1403f9040`, Reflex `0x1403f9550`, Will `0x1403f9a60` | Base providers and the subsequent script-visible AC, nominal attack/final save modifiers and positive stat effects refresh live state after XP mutation. Canonical equipped items and active effects survive rollback. Opponent-specific combat, immunity-aware decreases and actual equipment mutation remain open; saved snapshots are not live inputs. See [base evidence](combat-stat-providers.md) and [final modifier evidence](combat-final-modifiers.md). |
| Final application | `ValidateLevelUp` `0x140418b80`; player level-up message handler `0x140457170` | Validate the complete proposed record, domain/school choices, hit die and ability cadence; post the native level-up event and update combat information. Keep selection/application separate from trusted stored-history replay. |

Use that order to make the creation and level-up UI consume shared rules. Do not create separate UI-only prerequisite formulas or infer complete behavior from 2DA column names alone.

## Validation and limits

- `npm test`: **121 tests pass**. New coverage includes XP boundaries, signed delta wrap, deleted vs future history, zero-level intermediate class slots, ability/feat/skill reversal, HP/death behavior, atomic rejection, native metamagic behavior, custom class 127 and table-driven spell slots with item bonuses.
- `smoke-progression.mjs`: all **17 installed BICs above level 1**, including ordinary, multiclass and prestige characters, reduce to level 1. Source data and equipment metadata remain intact. XP alone leaves choices pending. Separate preauthored-history replay restores classes, abilities, skills, feats, maximum HP and known-spell multisets. Run under both Witch's Wake and the base Prelude resource chains. These are checks against the mapped implementation and installed corpus, **not a live original-game oracle**.
- All **39 installed BICs** still parse. The earlier Pale Master HP snapshot discrepancy remains **102 computed / 114 saved**; it is not resolved by this pass.
- Startup-enabled NCS now resets the wizard from XP 105000/level 15 to XP 0/level 1, maximum HP 5, without a startup bypass. The real exit/reward check then heals 4 HP and awards 100 XP. Canonical PC/owned IDs remain unchanged.
- Full-area Electron startup check observes XP 0, level 1, 12 feats, HUD **5/5**, and live spellbook counts **15 known / 5 memorized**. The cutscene remains locked after the unsupported damage call. Panel tests run separately with an explicit import fixture: level 15, 20 feats, 43 known/34 memorized, five carried and three equipped items. No test clears the cutscene to claim a successful opening.

Open native mutation side effects include automatic equipment legality/unequip actions, feat-use counters, quickbar cleanup, familiar/companion notifications, special class/feat state, broader combat state refresh, encumbrance and ruleset-constant overrides. Base and mapped final combat providers now recompute after XP mutation; this does not update an implemented attack round or native equip actions. General NPC stat loading and NPC HP rules remain unimplemented. Stored item bonus-slot counters are initialized for imported equipment; adding/removing equipment and newly applicable item properties require the later inventory lifecycle system.

The opening still reports **CopyObject at `ww1_start_onent@0x245`** and **EffectDamage at `@0x7d9`**. This checkpoint does not satisfy the roadmap's startup or encounter exit gates. Shared object creation/destruction remains a separate next slice after the character rules validation work.
