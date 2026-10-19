# Creature class and spell-resource serialization

Target: NWN:EE89.8193.37-17 x64, original read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

## Native evidence

CopyObject600 `140513500..14051389c` calls
NWSVMachineUtils::SerializeToGff `140582760..140583324`, followed by
DeserializeFromGff `14057f3d0..140580912`. The serializer selects an object's
native save owner and a V3.2 GFF type. A creature goes through SaveCreature
`1403a0a60..1403a1754`, SaveStats `1404145e0..14041524b`, and SaveClassInfo.
It does not copy an original UTC or BIC resource. The optional local-state flag
separately controls SaveObjectState for non-item CNWSObjects. DM creature copies
are rejected. Full wrapper/deserializer implementation remains pending.

The implemented SaveClassInfo body occupies two inclusive ranges:
`140413880..140413b3a` and `140413b40..1404145d8`. Its output includes:

- ClassList (struct type2), Class INT and ClassLevel SHORT, optional school and
  domain BYTEs from the active class definition.
- Ten SpellsPerDayList records (type0x4567) for non-memorizing classes.
- KnownList0..9 with WORD spell IDs (type3). Native counts narrow to signed
  SHORT but the traversal cursor is BYTE. Positive counts above255 cannot
  terminate; the port reports this condition. Counts32768 narrow negative and
  omit the list, as observed in the original code.
- MemorizedList0..9 (type3), only if a valid slot exists. Null/INVALID slots are
  omitted and holes compacted. Ready is the low byte of the live DWORD, not a
  boolean. DomainSpell=1 is written only when the full domain INT is nonzero.
  SpellMetaMagic is a BYTE. Assembly at413cf0..413d10 confirms that the initial
  scan limit is retained in R15D; the decompiler's reused variable is misleading.
- LvlStatList for PCs or creatures with more than one history record. First-level
  ability is omitted; later ability6 is omitted. History spell additions/removals,
  skill changes, feats, hit die, class, epic flag and skill points are saved.
- Familiar/companion fields when MinAssociateLevel BYTE is not255, split by
  the active class Arcane flag. LoadClassInfo writes MinAssociateLevel at+524;
  CNWClass2992e0 does not initialize this cell. The adapter diagnoses a missing
  active table value rather than choosing a default.
- SkillPoints WORD, base skill ranks via GetSkillRank(null,baseOnly1), permanent
  feats in owned order (type1), with Uses omitted only when remaining uses=100,
  and special abilities (type4) with WORD IDs and BYTE uses/caster level.

AddFeat `1403ef170` appends absent valid feats; it does not sort them. The
adapter reads the canonical permanent list, not derived/effect-granted feats.
Remaining uses come from the live feat-use pool. Full malformed feat-import
normalization is outside this section's acceptance scope.

Selected complete lower native owners executed in the oracle:
GetMemorizedSpellInSlot404aa0, Ready404db0, MetaType404c70,
GetIsDomainSpell402ff0, GetSpellsPerDayLeft409680 and
CNWLevelStats::GetSkillRankChange2969a0. Skill-rank and feat-use calculation
are captured lower boundaries with existing independent verification.
LevelStats constructor2965f0 supplies ability6, hit-die0, class0, epic0,
empty spell/feat arrays and zero skill changes. ReadStatsFromGff40f7f0 retains
these defaults for absent fields. The level SkillPoints cell has no such
constructor initializer; the adapter requires it when a history is saved.

## Implementation and validation

`src/creature_class_save.js` implements the owner using typed GFF records.
`src/creature_class_save_runtime.js` supplies canonical base data, active class
definitions, live spell pools, live feat uses and base skill queries.
`SpellBookRuntime.saveClassInfo` exposes it and reports failures through the
existing session diagnostics. It may append to an existing typed root for the
future SaveStats owner. It does not allocate game object IDs.

- Original-code oracle: `scripts/inspect-native-creature-class-save.py`.
  Final `native-creature-class-save-v4.txt`: **97 cases**, including two native
  nonterminating known-list cases stopped by the emulator, with corresponding
  diagnosed failures in the port. Typed trees and lower call arguments compare
  in `test/creature-class-save-native.test.js`.
- `creature-class-save-focused-v3.txt`: **48 focused tests PASS** (new owner,
  spellbook, feat uses, decrement command, skill ranks and progression). No
  full suite run.
- `installed-creature-class-save-v4.json`: **PASS**, real installed wizard,
  cleric and sorcerer BICs in Prelude. Actual parsed NCS calls consume spell
  and feat uses; newly written/read GFF reflects the current pools. Checks cover
  field widths, struct IDs, permanent-feat order, special-ability projection,
  prepared slots and per-day counts. Object IDs and imported resource snapshots
  remain unchanged. EffectBonusFeat/ApplyEffectToObject proves a temporary feat
  is omitted; public RemoveEffect plus event pumping verifies cleanup. The full
  effect ID is retained as `0000000000000088`. No error diagnostics; existing
  unsupported/load warnings are retained.
- `creature-class-save-build-v1.txt`: **PASS**, existing chunk-size warning.
  No UI behavior changed, so no redundant UI smoke run.

Retained fixture failures: installed-v1 compared a null-prototype parsed GFF
with structuredClone (prototype loss), fixed by comparing resource bytes as a
JSON value in v2. V2 selected only known spells for a cleric, which learns its
list through class rules; v3 also examines actual prepared slots. V4 adds the
temporary feat check. Production spell gates were unchanged.
Native-v2/v3 attempted255 inline class records, overwriting unrelated fields
beyond the native eight-record allocation; instruction exhaustion was observed.
V4 uses all eight valid inline records. This does not establish corrupt-memory
behavior or acceptance of more than eight stored classes.

## Remaining work

This is the class-info part of native serialization, **not a complete UTC/BIC
export, CopyObject binding, or cloning-spell acceptance**. Next implement the
remaining SaveStats branches, including polymorph/base-stat choices, followed
by SaveCreature inventory, object state, visual state and the matching loader.
Other object save/load owners are also required. Keep unsupported CopyObject
diagnostics until its real lifecycle can run; do not bind a stale authored-GFF
clone. Combat and full campaign completion remain open. Goal stays active.

Checkpoint `backups/creature-class-save-20261017-v1.zip` sealed successfully:
11263 files/166262470 bytes; every archived length and SHA256 verified.
Log `creature-class-save-checkpoint-v1.txt`, process58297 terminal0 consumed.
This verification note was added after sealing. The next SaveStats pseudocode
has now been read in full: its original-form/polymorph branches and stateful
combat-information name/damage refresh require their own provider/oracle audit.
