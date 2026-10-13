# Damage checkpoint — 2026-10-12

Target: NWN:EE `89.8193.37-17`, x64 `nwmain.exe`, SHA256
`3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
The installed game and live Ghidra project remain unchanged. This checkpoint
extends [combat resolution](combat-resolution.md) and does **not** establish
playable combat, casting or multiplayer compatibility.

The subsequent [live damage runtime checkpoint](combat-damage-runtime.md)
connects a partial script-damage/HP/event/death adapter and passes 255 tests.
The 233-test validation below records the earlier provider checkpoint.

## Observed native behavior and implementation

Full hash-checked disassembly is retained in `backups/animations/`, including
`resolution-damage-mitigation-asm.txt`, `resolution-native-resource-hp-asm.txt`,
`resolution-2da-array-load-asm.txt`, `resolution-weapon-power-flags-asm.txt`,
`resolution-damage-power-immunity-asm.txt`,
`resolution-immunity-lifecycle-asm.txt` and
`resolution-hp-resistance-query-asm.txt`. Full-range, copy-only Ghidra exports
include `resolution-1403fee20-copy-decompile.txt` and
`resolution-140428740-copy-decompile.txt`. Returning cleanup calls were checked
against assembly; truncated bridge output is not treated as a complete handler.

| Native function / call site | Implemented behavior |
| --- | --- |
| KEY setup `0x1401947b0`; calls `0x140194a7e` / `0x140194af4`; AddKeyTable `0x14018e330`, lookup `0x14018ffb0` | Retail priority 2,000,000 precedes base priority 1,000,000; first matching KEY resource wins. `resource_archive.js` preserves each KEY's BIF/resource indices when combining them. |
| Load2DArrays `0x1402b3920`; damage type assignment `0x1402b585d` | Active `damagetypes` physical row count drives flag validation. The installed retail table has 13 rows. Module/HAK overrides still resolve through the shared resolver. |
| EffectDamage `0x140518c70`; highest flag `0x1402a3c00`; index `0x1402a3b60` | Constructor emits 39 native integers, chooses highest flagged damage component, normalizes amount/flags/power and preserves uint64 effect identity with canonical uint32 creator IDs. A subsequent partial live application adapter is documented separately. |
| GetDamageRoll `0x1403fee20..0x1404009d0` | Base dice and critical/maximize branches, No Damage consumption, sneak/death ladders, one-time random bonus calculation, Massive Critical, effect floor, signed-short narrowing and ordered immunity/resistance/reduction queries. |
| GetDamageBonus `0x1403fd4b0`; special damage `0x140413030` | Strength/hand/ranged/Mighty gates, Point Blank range, Enchant Arrow, favored enemy/Bane, mode/Dirty Fighting, specialization and alignment/class-dependent smites. |
| Unarmed dice `0x14040aa70`; die `0x14040ad60` | Native Monk/Shou thresholds, separate small-creature dice/die progressions, rule-key spelling and byte narrowing. |
| Item damage flags `0x140468800`; creature flags `0x140390440` | WeaponType mapping, first applicable extra melee/ranged property, permanent-before-temporary search and native invalid-type warning. A zero current hand requires an explicit resolved native selection. |
| Weapon power `0x140396770`; damage power `0x140385610` | Versus/hand-qualified strongest positive attack effect, natural weapon reduction-power contribution, native cap, energy-index skip, Ki/arrow branches and final byte narrowing. Trap creator context must be supplied explicitly. |
| Damage immunity flags `0x140495180`; mitigation `0x140491690` | Weakest signed-byte immunity among flagged types, fire feat shortcut, vulnerability and minimum-one positive absorption. |
| Resistance `0x140492620`; maximum-vs-flag `0x140495710` | Native energy-feat branch priority, feat stage before effects, physical base-weapon minimum, hardness ties, budget handling and simulation feedback asymmetry. |
| Reduction `0x140491950` | Power/ranged eligibility, strongest capacity selected before budget, native innate progressions/ties, budget updates/removal and simulation rules. |
| HP getter `0x140495130`; DoDamage `0x14038a930` | Stored int32 base/temp HP with signed-short getters, ordered live temporary HP consumption and immediate removal/restart, difficulty option 5 and exact immortal flag gate. |
| GetDead `0x1404953b0`; GetIsPCDying `0x140495620` | Total HP determines NPC death at less than 1, PC/possessed death below -9, and PC/possessed dying from -9 through 0. |
| Immunity constructors `0x140519140` / `0x140518ff0`; application `0x14042a080` / `0x140429e10`; removal `0x140436430` / `0x140436320`; cache setter `0x14049ae80` | Live effect types 16/17 recompute exact-flag groups on apply/remove/expiry. Cache setter writes only the lowest flagged byte, capped at ±100. Decreases reject plot/immunity-22 targets and negative constructor percentages on application. Linked icon omissions are recorded. |

The damage-property field audit is significant: SaveItemProperties
`0x14046c130` writes WORD `Subtype` from offset 2 and WORD `CostValue` from
offset 6. GetDamageRoll reads offset 6 for Monster Damage and Massive Critical;
the implementation therefore indexes fixed `iprp_monstcost` and
`iprp_damagecost` with **CostValue**, not Subtype or a saved CostTable label.
Load2DArrays confirms their fields at calls/assignments around `0x1402b89e1`
and `0x1402b5172`. Regression fixtures deliberately give the two fields different
values. Extra damage-type flags and Mighty separately use Subtype.

## State and authority boundaries

`damageRoll` resolves a query; it does not subtract HP or publish an outcome.
Missing effect-bonus or mitigation providers throw rather than supply zero.
`damageResistance` / `damageReduction` return ordered local operation plans.
Those descriptors are **not native wire messages**. The current local runtime
adapter executes budget edits and immediate removal against live uint64 handles
before feedback. Object IDs, including external-ID bits and object ID zero, remain
unchanged in those records.

`doCreatureDamage` requires live temporary-effect/removal, difficulty and life
flag providers. Removal can itself cause dying/death or change the effect list;
the primitive requeries that list and restarts as native does. The subsequent
checkpoint binds its async variant to ModuleSession's live base/temporary HP
and updates UI getters to display total HP.

Multiplayer will apply authoritative server state. These local providers cannot
commit competing damage merely because a client attack animation runs. The
[compatibility contract](combat-compatibility-contract.md) remains the gate.

## Validation

- All **233 tests** and the production build pass. Targeted cases include
  critical draw order, maximize asymmetry, cost/subtype separation, signed
  overflow, native division faults, conflicting mitigation sources, budget
  depletion, live HP removal ordering and immunity cache restoration.
- Prelude loads 61/61 placed creatures; Witch's Wake loads 228/228; both report
  no creature-load diagnostics. The same shared code handles both modules.
- All 39 installed BICs load under both rule chains. AC matches 39/39 stored
  snapshots; available BAB matches 17/17; final saves match 38/39. The previously
  recorded Weapon Master save discrepancy remains open.
- Hidden Electron full-area/character UI verification passes. Existing missing
  bitmap/walkmesh/model-controller omissions remain visible and diagnosed;
  this was not a live combat test.
- Evidence reports: `resolution-damage-lifecycle-tests.txt`,
  `resolution-damage-combat-{prelude,witchswake}.json`,
  `resolution-damage-creatures-{prelude,witchswake}.json`,
  `resolution-damage-renderer.txt` and `resolution-damage-character.png`.
- Periodic source backups include
  `combat-damage-before-resource-fix-20261012-143657.zip` and
  `combat-damage-mitigation-20261012-150129.zip` under `backups/`.

These are source/regression/resource checks informed by original disassembly,
not independent observed native encounters. No original/replacement client
pair has been tested on the same server.

## Open work

GetTotalEffectBonus damage branches, broader damage item-property projection,
temporary item properties and equipment changes, live immunity initialization
from every supported source, native perception/attack-action scheduling, and
the broader damage/death lifecycle remain incomplete. Last-damage state,
direct-versus-queued scripts and partial HP/death/reaction state are now connected;
OnApplyDamage's cast concentration, charm/sleep cleanup, shield recursion and
full death/presentation providers remain required. Then connect combat cues/UI
and obtain an independent native melee oracle, followed by casting and the
multiplayer acceptance matrix. Localization/loose-override resource providers
also remain open; correcting installed KEY precedence is only that slice of
resource parity.
