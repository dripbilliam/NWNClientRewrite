# Creature-stat and combat-data serialization

Target: original read-only NWN:EE89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
This continues [class-info serialization](creature-class-save.md), required by
CopyObject600 and the authored spell scripts that use it.

## Original owners and behavior

Complete SaveStats body: `1404145e0..14041524b`. Complete
CCombatInformation::SaveData: `1402ad6d0..1402add58`. Complete localized-name
coordinator CExoLocString::GetString: `140169920..140169ae5`. REA dossiers are
`rea-copy-save-creature-stats.json`, `rea-stats-save-combat-data.json` and
`rea-stats-save-localized-name.json` under `backups/animations`.

SaveStats writes native field widths and original ordering for base identity,
conversation, stats, appearance, body parts, hit points and class information.
The creature equipment-lock INT+97c selects saved pre-polymorph physical
abilities, race, sound, portrait, appearance, BAB, saves, AC, maximum HP and
combat-information owner. Mental abilities and remaining directly saved fields
still come from current stats, as in the original body.

CurrentHitPoints is SHORT(baseHP - GetMaxHitPoints(1) + GetCurrentHitPoints(1));
the base field is sampled before either virtual query. The flag1 current getter
excludes temporary HP. MaxHitPoints and PregameCurrent have a separate lock
branch. For locked creatures, PregameCurrent is capped by the saved **maximum**
HP at+a58, not a separate saved current-HP field. Assembly414c3f..414c56 confirms
this. The <= branch calls the current getter again; the port preserves its call
order. Plot is forced0 for a non-DM PC. PortraitId=FFFF writes Portrait instead;
other IDs, including FFFE, write the WORD ID.

Native DWORD-and-BYTE writer `1401a3270..1401a334f` and WORD-and-BYTE writer
`1401a3790..1401a387d` write a legacy BYTE plus an x-prefixed full-width field.
Values above255 write legacy0. The original format literals at140d85db8 and
140da578c are `%s%s` and `x`; checked in
`native-gff-extended-label-literals-v1.txt`. Native labels are bounded to16 bytes.
The final right-foot literal is **ArmorPart_RFoot**, unlike the other body-part
labels. The port retains it rather than inventing BodyPart_RFoot.

After SaveClassInfo, SaveStats selects the live or saved combat-information
owner and refreshes weapon text from each resolved item's live localized name
at+420. A missing item leaves the previous text and damage bytes intact. A failed
name lookup leaves its output intact. A ranged weapon other than wield11 may
append the equipped ammunition name as `weapon (ammo)`. Formatting uses native
C strings, so embedded NUL terminates each argument. The right weapon's base
item supplies damage dice/die bytes at+1a/+1b. These are the two bytes represented
by the existing combat owner's `flags` WORD at+68; they are not status flags.

SaveData writes CombatInfo struct typeCAAA, selected BYTE/CHAR scalars, canonical
DWORD weapon IDs, three creature-weapon dice/die pairs, both strings, damage
bytes, AttackList (AAEE) and DamageList (DDEE). Node modifiers are signed CHAR;
the remaining node fields are BYTE. It does not save pointer addresses or padding.

Localized-name GetString first searches the requested embedded language/gender,
optionally its opposite gender when language is nonzero, then TLK. It preserves
the output on fetch failure. A successful empty TLK value with translation
enabled searches embedded language0, then languages1..4 in gender order.
GetString sets the native TLK gender state before fetching and leaves resulting
state visible. The embedded-list and TLK-fetch owners remain explicit lower
boundaries; this section does not claim their entire allocation/import lifecycle.

## Implementation and checks

- `src/creature_stats_save.js`: whole SaveStats coordinator.
- `src/combat_information_save.js`: whole SaveData owner, including field widths,
  struct IDs, signed modifiers and empty lists.
- `src/localized_string.js`: whole GetString coordinator.
- `src/creature_stats_save_runtime.js`: existing canonical creature, spellbook,
  inventory, combat, item-name and TLK providers. Exposed as
  `SpellBookRuntime.saveStats`; failures use session diagnostics.

`native-creature-stats-save-v1.txt`: **101 original-code cases PASS**. These
execute SaveStats, SaveData and both extended-field writer bodies. GFF storage,
string allocation/formatting/localization, class save and lower stat queries
are captured boundaries. Cases cover locks, PC/DM/Plot, signed HP extremes,
portrait branches, extended widths, missing weapons/names, ammunition and
wield11, signed combat nodes and random scalar values. Typed GFF trees, lower
call order and both combat owners' name/damage mutations compare with the port.
This is not a claim that all captured lower functions execute in that oracle.

`native-localized-string-v1.txt`: **800 original-code GetString cases PASS**,
comparing return status, output retention, lookup order and TLK gender state.
Embedded lookup and TLK fetch are captured; TLK already has its own original-code
checks. Positive/negative languages, multiple gender bytes, absent TLK, empty
entries, fetch failures and embedded NUL are covered.

`creature-stats-save-focused-v3.txt`: **26 focused tests PASS**, including the new
comparisons plus class save, combat information, maximum HP, polymorph and TLK
regressions. No full suite run. `creature-stats-save-build-v1.txt`: **PASS**, with
the existing chunk-size warning. No UI behavior changed.

`installed-creature-stats-save-v3.json`: **PASS**, actual parsed NCS spell/feat
consumption in installed wizard/cleric/sorcerer BICs in Prelude. All writes are
read back as typed UTC GFF; IDs/allocator state and original resource records
are unchanged by saving. Live spell pools, base HP, combat names, weapon IDs,
damage bytes, active movement rate and gold are checked. Temporary feat exclusion
and temporary-HP exclusion pass with public effect cleanup. A real polymorph
effect changes appearance1 to171 while the save retains original appearance,
race, physical abilities and sound. Its public removal plus native half-second
transition restores the original form. Effect IDs retain full64-bit form.
No error diagnostics; existing unsupported/load warnings remain in the report.

Retained fixture correction: installed-v1 passed basic whole-stat checks but
reported the older class-only byte count. V2 added full-stat assertions,
temporary HP and polymorph; it incorrectly expected immediate untransform on
RemoveEffect. V3 waits through the existing native501ms transition and passes.
No production polymorph timing or spell-selection gates were altered.

## Limits and next work

This completes the save coordinators above, not SaveCreature/CopyObject or full
character export/import. Runtime calculations use the existing canonical stat
providers; the oracle's captured lower-query boundaries do not prove all combat
rules or all installed characters. Import normalization for arbitrary extended
authored creature fields remains incomplete. The live adapter diagnoses those
fields rather than copying a stale x-prefixed value. Missing base-item damage
loader values are diagnosed rather than guessed: ctor29c750 does not initialize
these bytes. Remaining general malformed feat/history/import cases still need
the native loader audit.

Next implement SaveCreature's native equipment/repository traversal, perception,
combat-round, quick-button, visual/object-state and database save dependencies,
then the matching load lifecycle. Other object kinds also need their save/load
owners. CopyObject stays unbound until the actual lifecycle is ready. All forms
of spellcasting, combat and campaign completion remain the active goal.

Checkpoint `backups/creature-stats-save-20261017-v1.zip` sealed successfully:
11295 files/167290889 bytes, every archived length and SHA256 verified.
Log `creature-stats-save-checkpoint-v1.txt`, process30530 terminal0 consumed.
This verification note was added after sealing.
