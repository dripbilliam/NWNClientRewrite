# AC, attack and final save providers — 2026-10-12

This extends the [base stat checkpoint](combat-stat-providers.md) with the native
nominal melee/offhand/ranged bonuses, script-visible AC, final save modifiers and
positive stat effects. These are inputs to combat, not attack resolution or
multiplayer parity. The [compatibility contract](combat-compatibility-contract.md)
still requires independent native runtime and server comparisons.

## Target and validation sources

- Read-only input: `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, x64
  NWN:EE `89.8193.37-17`.
- SHA-256: `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
- Ghidra bridge decompilation/disassembly cross-checked against complete,
  hash-checked PE assembly using [inspect-combat.py](../scripts/inspect-combat.py).
  Chained unwind ranges and verified leaf boundaries were included. Decompiler
  truncation after an incorrectly nonreturning helper was not treated as a
  complete function. The helper also supports read-only constant inspection.
- No game binary, installed resource or Ghidra database was edited. Installed
  resources were read in memory; source backups contain replacement code only.
- Ignored working transcripts: `backups/animations/final-stats-core-asm.txt`,
  `final-stats-extra-asm.txt`, `final-stats-constructors-asm.txt`,
  `final-stats-tables-asm.txt`, `final-stats-save-item-asm.txt`,
  `final-stats-haste-asm.txt`, `final-stats-constants.txt`, and per-address
  decompilation/disassembly files. These are static research output.

## Observed native behavior

Addresses below are virtual addresses in the target PE. Semantic names describe
the matched routine; they do not imply a new Ghidra database annotation.

| Provider | Native routine / significant callsite | Observed contract |
| --- | --- | --- |
| Script-visible AC | `GetArmorClass` `0x140390070..0x140390196`; VM `GetAC` `0x14051e120..0x14051e212` | 10 plus capped DEX, signed-byte armor/shield/natural/deflection/Dodge groups and Tumble; signed-short result. No size, opponent or combat-mode adjustment. The optional VM AC argument is popped and ignored. Invalid returns -1; items/placeables/doors return 0. |
| Armor item | `ComputeArmorClass` `0x140466500..0x14046665e`; parts lookup `0x14046660d`, floor `0x14046662d`, half test `0x140466639`, ceil `0x140466645` | ModelType 3 reads `Parts_Chest.ACBonus` as float32 at the torso part index. Fraction at least .5 rounds upward. Other models give BaseAC only for base items 14/56/57. |
| DEX cap | `GetDEXMod` `0x1403fd280..0x1403fd3da`; item call `0x1403fd2c5`, table lookup `0x1403fd316`, narrowing/min `0x1403fd32d..0x1403fd32f` | A positive computed armor value selects the physical Armor row. A positive DEXBONUS integer caps DEX after signed-byte narrowing; zero leaves it uncapped. |
| Natural AC / class gates | `GetACNaturalBase` `0x1403f3e90..0x1403f4118`; `GetUseMonkAbilities` `0x140396370..0x140396478`; class gain leaf `0x140299d00..0x140299d4d` | Monk/Shou armor/shield gate, feat 260 positive WIS, Monk levels /5, Defender levels /3, Armor Skin rule, authored NaturalAC and cumulative class NaturalAC gains. Class gain storage has 60 entries. Polymorph/shape alternatives are outside this import slice. |
| Tumble | `GetTotalACSkillMod` `0x14040a7f0..0x14040a853`; base-only rank path in `GetSkillRank` `0x140406a40` | Raw rank 21, signed byte and clamp to ±127, positive ranks / TUMBLE_NUM_RANKS_PER_AC_BONUS, default 5. Broader effective skill modifiers do not enter this query. |
| Final saves | Fortitude `0x1404024c0..0x1404025cd` (base call `0x1404025a2`), Reflex `0x140406820..0x14040692d`, Will `0x14040b7f0..0x14040b8fd` | Base + ability + authored byte + Luck of Heroes + signed CHA for Dark Blessing + applicable effects; signed-byte result. Dark Blessing can decrease saves. Serialized final save snapshots are not live inputs. |
| Authored save fields | `ReadStats` calls `0x140411136`, `0x140411161`, `0x14041118c` | Lowercase `willbonus`, `fortbonus`, `refbonus` are SHORT fields narrowed to bytes. |
| Effect aggregation | `GetTotalEffectBonus` `0x140393340..0x14039628c`; attack cap `0x140393bc3..0x140393bcf`; save cap / Sacred Defense `0x140395814..0x140395855` | Separate increase/decrease caps, default 20. Generic attacks group by spell; saves group by canonical item creator when it resolves to an item, otherwise spell. Each sign has 50 source slots; unsourced spell -1 is independent. Specific hand effects keep their strongest amount. Touch suppresses specific positive enhancement, not generic or negative effects. Sacred Defense is added after the save increase cap. |
| Nominal melee | `GetMeleeAttackBonus` `0x1404041c0..0x1404047b5`; include-base branch `0x14040427b`; Weapon Master division `0x140404565..0x140404585` | STR or eligible higher DEX, optional BAB/effects, focus feats, Nature Sense area flags, Epic Prowess, Weapon Master weapon choice and signed division, dual-wield penalties, light/double weapon, Ambidexterity and Two Weapon Fighting. Touch has separate branches. |
| Nominal ranged | `GetRangedAttackBonus` `0x140405b00..0x1404061eb` | DEX or higher WIS with Zen Archery, highest Enchant Arrow tier 1..20, focus feats, Good Aim wield restriction and halfling sling bonus. This routine does not add Epic Prowess. |
| Finesse / size | `GetWeaponFinesse` `0x14040b680..0x14040b6fd`; `GetRelativeWeaponSize` `0x140392fd0` | Feat 42 plus the base item's minimum creature size; unarmed is eligible. Relative signed-byte weapon size outside -2..1 returns sentinel -10. |
| Limits | GetAttackBonusLimit `0x14055b300`, GetSavingThrowBonusLimit `0x14055b940`; constructor default writes `0x14055c638`, `0x14055c64c` | Module nonnegative overrides precede server values; constructor defaults both to 20. Native limit setter/getter engine calls are not yet wired. |
| Resource tables | Load2DAArray `0x1402b3920`; Armor reference `0x1402b4c3c`, Parts_Chest reference `0x1402b4f33` | Native references correspond to Armor and Parts_Chest. Replacement uses the existing module/HAK/base resolver, not a campaign lookup. |

### Item properties and active effects

`ApplyACBonus` `0x14046d9b0..0x14046dcd0` uses cost table 2 and the
base item's AC_Enchant category. Improved save handlers
`0x140471f30..0x14047202f` and `0x140472030..0x14047212f` use native cost
table 1, even when authored CostTable metadata suggests otherwise. Reduced
handlers `0x1404723f0..0x1404724ef` / `0x1404724f0..0x1404725ef` use table 20.
`ApplyChangedSavingThrow` `0x14046e8d0..0x14046e9ee` maps specific subtypes
1→Fortitude, 2→Will, 3→Reflex. `ApplyChangedSavingThrowVsX`
`0x14046e9f0..0x14046ecd4` reads iprp_saveelement.SavingThrowType, with the
observed fixed fallback map when the lookup fails. The integer value chooses
increase/decrease; property labels alone do not determine its sign.

Attack properties follow slot-to-hand mapping in `ApplyAttackBonus`
`0x14046dfe0..0x14046e3eb`; enhancement `0x14046fee0..0x14047077d` also
generates damage, which remains an explicit omission. Double weapons project
the offhand attack effect too. This projects imported equipped properties;
it does not implement native equip/unequip actions or general item execution.

Equipment Haste's AC contribution is applied once across equipment. Static
tracing of `OnApplyHasteOrSlow` `0x14042dba0..0x14042df04` and
`OnApplyHasteInternal` `0x14042d950..0x14042db97` establishes the default Dodge
AC contribution of 4. Haste speed, extra attacks, slow balance, icons and the
full runtime Haste lifecycle remain unimplemented and recorded.

Positive constructors are AC `0x1405173a0..0x140517505`, saves
`0x14051b480..0x14051b5ed`, attack `0x140517b70..0x140517ca4`. Native effect
types 48/26/10 and their integer layouts, subtype and invalid-category fallbacks
are mapped. Apply handlers are AC `0x140426ad0..0x140426da2`, saves
`0x1404314a0..0x1404315d7`, attack `0x140427920..0x140427a1c`.
Nonpositive/dead/non-creature applications are consumed without a stat change.
Successful application retains separate uint64 effect IDs and canonical uint32
creator/target IDs. Native effect icons/feedback are still missing and logged.

AC cache updates reproduce native signed-byte accumulation for Dodge and
strongest-category updates for the other groups, including overflow behavior.
`OnRemoveACIncrease` `0x140435ad0..0x140435d04` subtracts Dodge or rescans the
strongest remaining category. Deferred removal hides enumeration immediately
and changes stats on scheduler deletion; expiry is strictly after its timestamp,
following the previously traced [effect lifecycle](startup-effects-audio.md).
Already returned effect copies keep their identity/validity state.

Negative application is deliberately unsupported: `OnApplyACDecrease`
`0x140426860..0x140426acf` checks immunity 23 and plot state;
`OnApplySavingThrowDecrease` `0x140431360` checks immunity 25 and plot state.
Negative attack properties also require their native applicability provider.
Pure aggregation accepts already-resolved negative records for arithmetic tests,
but engine constructors/application and negative item applicability do not
silently bypass immunity checks.

## Replacement implementation

- [combat_modifiers.js](../src/combat_modifiers.js) supplies the shared providers
  and breakdowns. [character.js](../src/character.js) loads tables through the
  general resolver and combines them with base providers and equipped abilities.
- [module_session.js](../src/module_session.js) reads equipped canonical item
  records, refreshes shared stats after XP mutation and area entry, and connects
  GetAC and the three final-saving-throw queries. Unsupported unloaded creature
  stats remain diagnostic failures, not fabricated values. Non-creature save
  fallbacks follow the door/placeable VM branches.
- [effect_runtime.js](../src/effect_runtime.js) refreshes those same stats on
  positive effect application, deferred removal and expiry. No actor/item ID is
  reassigned during refresh or rollback; imported character data stays immutable.
- [game_ui.js](../src/game_ui.js) shows armor class, melee/offhand/ranged bonuses
  and Fortitude/Reflex/Will separately from base values. These nominal bonuses
  are not the final attack roll against a selected opponent.
- Unsupported item execution and missing effect presentation join the durable
  [runtime diagnostic journal](runtime-diagnostics.md).

## Checks and remaining discrepancy

- `npm test`: **159 passing**, including 18 modifier/lifecycle tests for native
  narrowing, armor rounding/caps, Monk gates, feat branches, source grouping,
  item table/subtype contracts, AC cache restoration and deferred/strict expiry.
  These are assembly-derived checks, not an independent native oracle.
- `npm run build` succeeds; Vite's existing large-bundle warning remains.
- [smoke-combat.mjs](../scripts/smoke-combat.mjs): **39 BICs** under each of
  Prelude and Witch's Wake. **39/39 AC**, **38/39 final saves**, **17/17 available
  BAB snapshots** match. All 17 higher-level loss/replay checks restore the
  entire computed combat record; temporary bonuses survive rollback and restore
  on removal without changing shared stat identity or canonical object IDs.
- `weaponmaster.bic` remains divergent: computed Fortitude/Reflex/Will
  **11/9/5**, saved **13/7/5**. AC 26 and BAB 15 match. The snapshot is not
  overwritten, and no exception keyed to this character or campaign was added.
  Historical rules or equipment state could explain it, but that is unverified;
  an independent native runtime comparison must resolve it.
- Bundled character UI check passes in full Angmar's House: AC 17,
  melee/offhand 7, ranged 10, saves 6/8/9; all seven rows were checked and the
  screenshot visually inspected. Startup is disabled only for this import fixture.
- Separate authored-startup check passes in MODULESTART001: level 1, HP 5/5,
  BAB 0, AC 17, melee/offhand 0, ranged 3, final saves 1/3/2. It leaves startup
  enabled, follows queued jumps and preserves the cutscene lock. Panels are not
  opened through that lock. CopyObject and EffectDamage still block the opening
  and remain durable diagnostics. Export/check captured 1,642 records; the later
  final flush verified all 3,278 records present with zero pending/storage errors.
- Local outputs: `backups/animations/final-stats-{prelude,witchswake}.json`,
  `final-stats-character-ui.txt` / `final-stats-character.png`,
  `final-stats-startup-ui.txt` / `final-stats-startup.png`. Both UI checks exit 0.

## Next fidelity work

`GetArmorClassVersus` `0x1403f47f0` is a separate, substantially broader
opponent-specific path: size, visibility/flat-footed state, Dodge targets,
Mobility, Defensive Training, combat modes and conditional effect filters.
It was inspected as a boundary, not implemented here. Trace and implement it
with GetAttackModifierVersus, negative-effect immunity/plot rules and temporary
ability effects before resolving a melee hit. Finish actual equipment mutation,
NPC stat loading, runtime limit changes and effect presentation alongside them.

Then establish an independent native oracle for modifier queries, RNG draws,
round/action/event order, attack consequences and UI feedback. Resolve the
Weapon Master save discrepancy without guessing. Shared snapshots/unit checks
cannot establish live combat parity or interoperability with an unmodified server.
