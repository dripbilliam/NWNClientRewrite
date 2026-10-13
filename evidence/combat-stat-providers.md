# Base combat stat providers — 2026-10-12

Historical base-provider checkpoint. The subsequent [final modifier slice](combat-final-modifiers.md)
adds script-visible AC, nominal melee/ranged bonuses, final save modifiers and
positive stat effects; its evidence and open-work list supersede the pending
modifier work below.

This slice implements shared base attack and base saving-throw providers from the
installed native routines. It does **not** implement attack resolution, final
saving throws, armor class, or multiplayer replication. The
[combat compatibility contract](combat-compatibility-contract.md) remains the
acceptance gate; the checks below do not establish combat or server parity.

## Target and sources

- Target: `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, x64,
  version `89.8193.37-17`.
- SHA-256: `3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
- Read-only Ghidra bridge decompilation/disassembly, checked against direct PE
  assembly. No original game binary, asset, or Ghidra database was changed.
- [Inspection helper](../scripts/inspect-combat.py) verifies the hash, follows
  chained PE unwind ranges, and accepts explicitly verified ranges for leaf
  functions without unwind entries. A single unwind entry can cover only the
  prologue; treating that as the complete function would miss relevant behavior.
  Ghidra also incorrectly marks `0x140c10370` as nonreturning, truncating several
  loaders. Complete assembly, including their cleanup tails, was inspected.
- Local working transcripts: `backups/animations/combat-complete-asm.txt`,
  `combat-providers-asm.txt`, `combat-loaders-asm.txt`,
  `combat-table-parse-getters-asm.txt`, `combat-*-ghidra-asm.txt`,
  `combat-class-*-asm.txt`, `combat-epic-*-asm.txt`, `combat-fnv-asm.txt`, and
  `combat-constructor-set-asm.txt`. These contain research output, not copied
  binary/assets. Installed 2DA/BIC resources were read in memory.

## Observed native behavior

| Native entry / callsite | Observed behavior implemented |
| --- | --- |
| `CNWSCreatureStats::GetBaseAttackBonus` `0x1403f8e90..0x1403f9033`; class attribution call `0x1403f8f0a`, class attack call `0x1403f8f15`, epic call `0x1403f900a` | Class attack bytes sum in an integer. Epic attack is separate and omitted in the nonzero-argument mode. Nonzero runtime byte `stats+0xd52` overrides either mode; checked at `0x1403f9014`. |
| `GetNumLevelsOfClass(class, mode)` `0x1404055d0..0x140405701` | When the level-history count equals the total level byte, count every matching history class with `EpicLevel == 0`, rather than slicing the first twenty records. Class and epic checks are at `0x140405637` / `0x140405640`. Otherwise attribute at most twenty levels by live class-slot order. |
| `CNWLevelStats` constructor `0x1402965f0..0x1402966b5`; stores `0x14029669b` / `0x1402966a2`; GFF reads `0x1404112da` / `0x140411305` | Missing history class and epic fields retain constructor defaults of zero. Older installed BICs omit `EpicLevel`; requiring the field would wrongly reject them. |
| `CNWClass::GetAttackBonus` `0x1402997b0..0x1402997c2`; save getters `0x1402998e0`, `0x140299d50`, `0x140299ff0` | Levels narrow to unsigned byte, accept 1..60 and read row `level-1`; other levels return zero. |
| Class loaders `0x14029a3c0..0x14029a6bc`, `0x14029b050..0x14029b424`; attack write `0x14029a66d`; save writes `0x14029b2eb`, `0x14029b35a`, `0x14029b3d9` | Load sixty physical rows. Attack uses `BAB`, saves use `FortSave`, `WillSave`, `RefSave`. Failed attack cells are explicitly zeroed; save loaders retain the `GetINTEntry` output, including table defaults on missing rows/columns. Values narrow to byte. |
| Epic loaders `0x1402b9b90..0x1402b9d11`, `0x1402b9d20..0x1402b9f7a`; getters `0x1402b3810`, `0x1402b3830`, `0x1402b3850`, `0x1402b3870` | `EpicAttacks.BAB` and `EpicSaves` save columns, same sixty-row bounds; epic level is `max(0, totalLevelByte - 20)`. Epic loaders retain integer-entry output even on failure. |
| `C2DA::GetINTEntry` `0x1401a7010..0x1401a7116`; `Load2DArray` `0x1401a73a0..0x1401a8824` | Physical row index and first case-insensitive column match. Nonempty cells use `atoi` or leading `0x` conversion. Empty cells return false/output zero; missing row/column returns false/output `atoi(DEFAULT)`. Loader clears explicit `****` at `0x1401a8666..0x1401a867b`; missing row data copies the default at `0x1401a877b..0x1401a87a0`. Printed labels may be repeated or nonnumeric. |
| Base Fortitude `0x1403f9040..0x1403f954f`, Reflex `0x1403f9550..0x1403f9a54`, Will `0x1403f9a60..0x1403fa02f` | Sum class pre-epic bonuses, epic bonuses and specific feat bonuses with signed-byte result. Feat presence includes the additional native feat array. Positive signed Charisma modifier at `stats+0xd43` contributes for Divine Grace (217); nonpositive modifiers contribute zero. |
| `GetCHAStat` `0x1403fa050..0x1403fa0ee`; effect call `0x1403fa08a`; `SetCHABase` modifier call/store `0x14041527a` / `0x14041527f`; import modifier call/store `0x140411098` / `0x14041109d` | Charisma modifier is derived from effective ability state, including racial/class/effect adjustments, rather than the raw BIC ability. This slice supplies the existing equipped-ability provider; temporary ability effects remain unsupported. |
| `CalcStatModifier` `0x1403f16c0..0x1403f182a`; integer divisions `0x1403f17a8`, `0x1403f1823` | Uses ruleset neutral value (default 10) and increment (default 2). Below an even neutral, subtract one before signed division; below an odd neutral, truncate directly. Return signed byte. Invalid division constants fail explicitly in the replacement. Constitution HP calculation now also uses this shared provider. |
| `LoadRulesetInfo` `0x1402ac0c0..0x1402ac6e2`; label/value calls `0x1402ac23c`, `0x1402ac2f7`; integer conversion `0x1402ac42b`; `GetRulesetIntEntry` `0x1402a4130..0x1402a4183`; `fnv1a` `0x1402ae870..0x1402ae898` | Load nonempty `Label`/`Value`, cache by FNV-1a uint64 using signed resource bytes, use `atoi` for integer values, warn on duplicate hashes and retain the last entry. Missing keys use the getter's default. Rules are fixed until table reload. |
| VM `ExecuteCommandGetBaseAttackBonus` `0x14051f6d0..0x14051f750`; call `0x14051f725` | Resolve canonical creature ID; return full base attack including epic, or zero for invalid/noncreature targets. A valid creature with unavailable replacement stats fails explicitly and is journaled with its script/call/target context. |
| Stats constructor zero store `0x1403ee49a`; saved stats caller `0x140414911` | The constructor clears `stats+0xd4f..0xd52`, including the runtime override. The replacement does not import the saved base-attack/save snapshot as an override or a derived provider result. |

Base save feat branches use these exact IDs and ruleset defaults:

| Save | Feat → constant (default) |
| --- | --- |
| All | Divine Grace 217 → positive live signed Charisma modifier; Lucky 248 → `LUCKY_SAVE_BONUS` (1) |
| Fortitude | Great Fortitude 14 → `GREAT_FORTITUDE_SAVE_BONUS` (2); Strong Soul 388 → `STRONG_SOUL_SAVE_BONUS` (1); Epic Fortitude 583 → `EPIC_FORTITUDE_SAVE_BONUS` (4) |
| Reflex | Lightning Reflexes 24 → `LIGHTNING_REFLEXES_SAVE_BONUS` (2); Snake Blood 386 → `SNAKE_BLOOD_REFLEX_BONUS` (1); Epic Reflexes 585 → `EPIC_REFLEXES_REFLEX_BONUS` (4) |
| Will | Iron Will 22 → `IRON_WILL_SAVE_BONUS` (2); Bullheaded 380 → `BULLHEADED_WILL_SAVE_BONUS` (1); Strong Soul 388 → `STRONG_SOUL_SAVE_BONUS` (1); Epic Will 695 → `EPIC_WILL_SAVE_BONUS` (4) |

Representative feat-constant calls: Fortitude `0x1403f92f0`, `0x1403f93ad`,
`0x1403f946c`, `0x1403f952c`; Reflex `0x1403f97f9`, `0x1403f98b6`,
`0x1403f996d`, `0x1403f9a2c`; Will `0x1403f9d10`, `0x1403f9dcd`,
`0x1403f9e8c`, `0x1403f9f4c`, `0x1403fa00c`.

An important adjacent observation: NWScript `SetBaseAttackBonus` is documented
as setting **base attacks**, not the base attack modifier. Its native command at
`0x14053e260` clamps 1..6 and writes `stats+0xd53` at `0x14053e2d4`, a different
field from the override above. It remains unimplemented pending the attack-round
trace; wiring it to `stats+0xd52` would be wrong.

## Integration and validation

- [Shared providers](../src/combat_stats.js) return base totals and a source
  breakdown. [Character import/recomputation](../src/character.js) loads module/
  HAK/base rules through the existing resolver, including epic and ruleset tables.
  No class growth formula or campaign-specific override replaces those tables.
- XP rollback/future-history replay recomputes these providers while retaining
  canonical actor/item IDs, the shared stats object and immutable imported BIC.
  Saved snapshot fields remain available in authored data only.
- Character UI labels these values **Base**. Full saving-throw engine calls are
  not connected to these partial totals. Other combat calls retain diagnostics.
- `npm test`: **141 passed**. Eleven new tests cover physical/duplicate labels
  and columns, empty/default/hex entries, pre-epic history versus fallback,
  epic separation, runtime override versus snapshot, byte boundaries, exact feat
  branches, pending feats, ruleset hashing/defaults/duplicates, ability arithmetic,
  recomputation, invalid IDs and missing-NPC-stat diagnostic context. These are
  assembly-derived checks, not an independent live combat oracle.
- `npm run build`: passes; the existing large-bundle size warning remains.
- [Installed corpus check](../scripts/smoke-combat.mjs): **39/39 BICs** under
  **Prelude and Witch's Wake**, independently resolving each module's rules.
  All **17/17 available saved base-attack snapshots match**. Twenty-two older
  files have no attack snapshot. All seventeen higher-level characters also
  pass rollback/replay, shared-object/ID and read-only-source checks.
- Base saves plus currently supported ability modifiers match **31/39** saved
  save snapshots in each module. The eight discrepancies are retained in the
  reports: `dwarfdefend`, `fighter`, `paladin`, `palemaster`, `rogue`, `shifter`,
  `torm`, `weaponmaster`. Non-ability item properties, special final-save branches
  and other remaining modifiers require tracing; assigning a guessed correction
  to make those snapshots match would not establish fidelity.
- Bundled full-module character/UI check: imported wizard level 15 has BAB 7
  and base saves Fortitude 5 / Reflex 5 / Will 9, verified in the panel and canvas
  state. Output/screenshot: `backups/animations/combat-character-ui.txt`,
  `combat-character.png`.
- Real startup enabled: authored `SetXP(0)` reduces that wizard to level 1,
  BAB 0 and base saves 0 / 0 / 2, preserving the existing 5/5 HP and cutscene.
  The final journal/file/export checkpoint contains 4,913 records, including
  unsupported `CopyObject` and `EffectDamage`. The harness distinguishes these
  checkpoints and checks final persistence before shutdown, including records
  from the later queued area reload. The opening remains blocked by
  those systems; it was not bypassed. Output: `combat-startup-ui.txt` / `.png`.
  The headless character run also emitted a Chromium GPU synchronization
  warning on shutdown; stderr is retained in its adjacent `.err.txt` file and
  the captured scene was visually inspected successfully. The final startup
  audit has no stderr output.

## Open work

Trace and implement effective armor class, melee/ranged attack and final-save
providers, equipment/effect application and removal, situational branches and
native limits. NPC stat import, runtime attack-override mutation, additional
feat-selection state, and the adjacent base-attacks setter need integration.
Other class/race/skill/spell providers and broader 2DA lexical edge cases are not
certified by this combat slice. Then implement a narrowly scoped native melee
round and establish an independent native runtime oracle, RNG draw order and
event timing before claiming attack parity. Original/replacement clients sharing
an unmodified server remain a required separate interoperability test.
