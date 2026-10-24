# Character selection and first-level creation

## 2026-10-19: profile portraits, resource errors, feat groups and voice sampling

Target remains NWN:EE89.8193.37-17 x64 nwmain.exe, SHA2563b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a. Native GetMasterFeatNameText0x1402a3e30 reads the indexed STRREF array; GUI available-feat info handler0x1409c7830 distinguishes the master-feat flag0x10000 and uses the master name/description/icon. Active feat.MASTERFEAT and masterfeats.2da drive replacement groups without name-prefix or server-ID rules.

Native CharacterGen handler0x1408e7110 resets preview code0 when the soundset row changes, otherwise advances through0..48 and wraps. It calls807240 with positional0. Replacement double-click uses those codes, active SSF/WAV resources and the existing audio adapter. Silent SSF entries and the server EmptyVoice row remain silent. Physical sound-device equality is not claimed.

User-authorized portrait copy:1,463 TGA files,143,943,134 bytes, source Documents/Neverwinter Nights.0/portraits to Documents/Neverwinter Nights/portraits; each SHA256 verified. No image bytes enter this workspace. Portrait folder mounts only TGA/DDS, cannot supply rules or HAKs. The selected server context stays isolated; user portraits are intentionally shared profile images. Local custom portraits are enumerated separately from server portraits. Missing catalog images retain explicit diagnostics and a labelled placeholder.

The optional half-orc PLT error exposed dropped Error.code properties at two boundaries: main-process IPC and preload contextBridge. Expected misses now travel as structured envelopes and are rebuilt in the renderer, preserving fallback and type/ref metadata; untrusted error fields are excluded. The real isolated Electron fixture exercises the same renderer decoder and extracted production appearance-asset loader. Final appearance acceptance is pending.

Native cache observations: HasAdvertisedData0x1401b1910 asks HasManifest; SQLiteStorageProvider::Has0x1401c3d60 queries FindShardIndexForReading. This supports catalog-based availability, not opening every cached blob on every join. The current client still scans headers individually; changing that and slow world presentation is the final phase of the user goal.

51 focused regressions and the build pass at this stage. UI evidencev6 verifies portrait scroll550->550, skill scroll400->400, unavailable feats hidden,2 groups/28 submenu choices/243 disabled rows revealed by toggle, real vs_nbarbam1_attk audio start and disposal. Earlier failed UI runs are retained; v6 still fails appearance because the second Error boundary was not yet fixed. Do not treat its partial success field as final acceptance.

## 2026-10-19: server prerequisite tables and extended package IDs

The interactive Arelith wizard failed with `undefined.toLowerCase` because
every player-selectable class had a PreReqTable. The previous blanket exclusion
selected class ID-1; unconditional spell-option validation then tried to use its
missing SpellTableColumn. This was reproduced offline from the authenticated
manifest `1fb727f690a7e0c462f79ef9177f5977c73d756f`, without HTTP access.

Read-only original owners:

- `GetIsClassAvailable140402e10` checks flags, alignment, level limits and calls
  `GetMeetsPrestigeClassRequirements140403810..1404041bb`; a nonempty table is
  not itself a ban. Arelith's base class table contains CLASSNOT restrictions,
  satisfied by a new character with no existing class levels.
- The requirement dispatcher preserves exact case, AND requirements and the
  independent RACE/FEATOR/CLASSOR groups. Supported native types are SKILL,
  FEAT, RACE, FEATOR, BAB, SPELL, ARCSPELL, VAR, CLASSNOT, CLASSOR and SAVE.
  Unknown strings are ignored as in the original dispatch. The first-level
  adapter supplies pre-class state: racial feats, no acquired class/skill ranks,
  zero class BAB/base saves and empty script locals. Alignment remains checked
  in its later creation step. This is not a completed general level-up owner.
- `CResGFF::ReadFieldDWORDorBYTE1401a1590`, called at `1405706d9` during
  `ValidateCreateServerCharacter`, reads an x-prefixed DWORD before the legacy
  BYTE. The existing native SaveStats writer similarly preserves large values.
  Fresh BICs now write xStartingPackage and keep legacy StartingPackage0 for
  values above255. No package or class IDs are special-cased in production.

New `class_prerequisites.js` is compared against1,564 executions of the original
requirement function. C2DA IO, scalar getters, allocations and local-variable
lookups are explicit captured boundaries; full wizard/validator execution is
not claimed. Oracle attempts v1/v2 exposed incomplete function-boundary and
security-cookie ABI shims; v3 corrects them and preserves the return value.
REA dossiers are `rea-creation-class-*`, `rea-creation-prereq-type-literals.json`
and `rea-creation-package-reader.json`. The original binary/project was unchanged.

The UI now checks actual prerequisites when enabling classes. Optional/missing
column names and an unselected/non-casting class no longer crash spell-option
lookup. `probe-server-creation.mjs` validates all47 player-class rows and19
playable races without exceptions;19 classes qualify for the tested initial
race/pre-class state. Ordinary validation errors on an unfinished draft remain
expected. See `arelith-creation-before-v2.json` / `arelith-creation-after-v1.json`.

`arelith-creation-ui-v4.json` verifies the actual CharacterFrontend across all15
steps, including selecting a visible server package rather than its hidden
configured default, recommendations, skills/feats/spells and appearance controls.
It creates an8,615-byte level1 wizard BIC in memory with package270, legacy0,
12 known cantrips,7 known level1 spells and no world object ID. The buffer is
cleared; no character was uploaded, persisted or admitted to Arelith. Zero HTTP
attempts/console errors. Earlier UI harness failures are retained. This does not
prove every custom class combination or public-server character validation.

Final focused checks:107 pass, including native field readers, shared SaveStats,
creation, spellbook and session/IPC regressions (`creation-prerequisite-focused-v5.txt`).
Production build passes (`creation-prerequisite-build-v2.txt`).

---

2026-10-18 correction: fresh BIC ClassList now uses the original typed INT/SHORT
fields and first-level history metadata. Earlier local parser checks did not
detect the BYTE/WORD mismatch that vanilla character admission rejects. Corrected
fresh wizard admission is verified. See [native type investigation](multiplayer-character-native-types.md).

Checkpoint: 2026-10-14. Character selection now precedes module-session creation
and startup scripts. Existing installed/local BICs and newly created characters
share the canonical ModuleSession import path. Changing the selection does not
replace a character inside an already running world.

Target: NWN:EE **89.8193.37-17**, read-only
`../../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The existing Ghidra project was reopened; no annotations/database edits or
original executable modifications were made.

## Native evidence

| Owner | Observed contract / implementation use |
| --- | --- |
| `CNWClass::GetIsAlignmentAllowed` `0x140299900` | Independent law/chaos and good/evil axes, bit restrictions, and inverted restriction mode. Reproduced 2,304 original-code executions covering all masks0..31, axes0..3, inversion and the nine alignments. |
| Client ability increment helper `0x1408e05e0` | Compares the current score against active CHARGEN_ABILITY_COST_INCREMENT2/3/4 thresholds. Reproduced36 original executions using stock and changed thresholds. FNV hashing/ruleset lookup are explicitly captured boundaries in this oracle. |
| Client ability decrement admission `0x1408e0790`, initialization `0x1408e36d0`, calls `0x1408e3986..0x1408e3c0a` | Minimum casting ability follows class SpellcastingAbil and SpellCaster, accounting for race and first-level class adjustment. It is not the class's recommended PrimaryAbil for every martial character. |
| `CalcLevelUpNumberFeats` `0x1403f15c0` | First-level normal feat allowance comes from NumberNormalFeatsEveryNthLevel plus ExtraFeatsAtFirstLevel. Class BonusFeatsTable supplies the separate bonus pool. |
| `LoadFeatsTable` `0x14029a9a0`, list dispatch `0x14029ade7..0x14029af16`; `IsGrantedFeat` `0x14029a130` | List0 normal,1 both,2 bonus,3 automatic. GrantedOnLevel alone does not make List0/1/2 entries automatic. |
| `ValidateCharacter_SetNormalBonusFlags` `0x1404c1610` | Class-specific normal/bonus flags take precedence; AllClassesCanUse supplies normal eligibility only when neither class flag applies. |
| `IsSkillClassSkill` `0x14029a250`, `IsSkillUseable` `0x14029a300` | Active class skill rows determine class status; global AllClassesCanUse or a class entry admits purchase. |
| `ValidateLevelUp` `0x140418b80`, first-level skill branch `0x140418dca..0x140418edb` | max(1,class base + ability modifier), then race extra points and first-level multiplier; class ranks cost1/max4 at level1, cross-class cost2/max2. The race's SkillPointModifierAbility is parsed as an ability name, not as an integer. Unspent skills may be retained. |
| `FeatRequirementsMet` `0x1403f2a40`, `FeatRequirementsMetAfterLevelUp` `0x1403f3190` | First-level choices check ability minima, base attack, levels/classes, epic restriction, Fortitude, AND/OR prerequisite feats, skill use/ranks and spell levels. Creation sees race/class adjustments and earlier choices. This is a first-level selection view, not a general manual level-up implementation. |
| `CNWClass::GetSpellsKnownPerLevel` `0x140299e70` | Known-spell capacities use active gain/known tables and class flags. |
| `CNWSPlayer::ValidateCharacter`, `0x1404c0bc3..0x1404c0bfc` | First-level LearnScroll allocation is3 + nonnegative INT modifier. Cantrips are automatic; school opposition filters learnable spells. General validation decompiles incompletely; bounded PE disassembly was retained. |
| `GetSpellGainWithBonus` `0x140408120` | Creation reuses the already native-compared shared spell-slot provider. Prepared slots and spontaneous remaining uses are written to the native class-list fields. Domain slots retain DomainSpell flags. |
| `InitializeClothesVariations` `0x1408e8410`, restrictions `0x1408e8870..0x1408e8ac8` | ChargenClothes supplies ItemResRef and optional exact class/race/gender and two-letter alignment restriction. True neutral uses TN. |
| `ValidateCreateServerCharacter` `0x14056fbc0`, package lookup `0x1405709ec..0x140570af8`, GFF writes `0x140570b97..0x140570c38`, clothing `0x140570dc8..0x140570fe8` | Package equipment becomes ItemList; selected creation clothes become chest-slot Equip_ItemList separately. The replacement resolves active UTIs in memory, preserving their field types. No package gear is arbitrarily auto-equipped. |

Where Ghidra incorrectly treats cleanup thunk `0x140c10370` as non-returning,
the full bounded original PE body was read with the hash-checking inspection
script. No function was considered completely recovered from truncated
pseudocode. Raw outputs are `backups/animations/chargen-*.txt`; the isolated
oracle is `scripts/inspect-native-character-creation.py`.

## Working flow and storage

The Characters button opens selection/creation after Game Data is selected.
Opening a module always asks for a character using that module's active
resolver, before allocating its session or running entry/startup scripts.
Cancel leaves the previous world intact. World advancement/input are suspended
while selecting; module loads are serialized.

The wizard exposes gender, race/subrace, portrait, class, alignment, package,
point-buy abilities, domains/school, skills, general/class bonus feats, known
and prepared spells, body/head/clothing/palette appearance, voice, names,
age/deity/biography and familiar/animal companion choices. Active package
preference tables support recommendations; individual choices remain editable.
The appearance preview uses the world renderer's hierarchy, body assembly,
palette decoder, skinning and inherited idle pose in a separate scene, without
creating simulation objects.

New characters are serialized as fresh level1 BICs with XP0, native class and
level-history lists, base ability bytes before racial adjustment and base hit
dice before CON restoration. The writer retains BYTE/WORD/SHORT/RESREF and
localized-string distinctions and UTI struct/field metadata. Native object IDs
are allocated only by the existing importer, including equipment/possessions.
No installed BIC or high-level character is cloned as a creation shortcut.

The local vault uses IndexedDB in the current Electron/browser profile, keyed
by content SHA256. Created/imported characters persist across reloads and can
be exported as BIC files. This is a replacement-client local vault, not a write
to the original game's localvault/servervault directories. Unsupported/corrupt
imports and load failures remain in diagnostics; installed DM characters are
excluded from ordinary player selection.

## Validation and remaining parity boundaries

- `node --test`:1282 passing tests at this checkpoint; build passes.
- Original-code comparisons:2,304 alignment cases and36 client increment cases.
- Installed audit:154 race/gender/base-class combinations create valid fresh
  BICs; eleven classes also pass canonical ModuleSession import with first-level
  HP, clothing slot, distinct item IDs and spell-use state checked.
- Hidden Electron test imports39 installed playable characters, verifies no
  world before confirmation, cancellation, manual human specialist creation,
  six prepared slots, world entry, cancellation preserving an existing world's
  actor/area IDs, and vault persistence across a completed reload. No
  renderer errors. Screenshots are under `backups/animations/character-*.png`.

This establishes a working first-level creation/selection workflow, not proof
that the entire original creation validator or every native GUI behavior has
parity. Arbitrary custom prestige prerequisite tables remain explicitly gated;
manual level-up is separate. Optional native random-name generation, voice
auditions, custom portrait import and exact native GUI layout remain open.
New authored text currently saves in Western CP1252; unsupported characters
are rejected rather than silently corrupted. Original-client/server acceptance
of generated BICs, campaign saves and a continuous base-game playthrough remain
separate acceptance gates. Existing casting/combat limitations are unchanged.

Source/evidence checkpoint: `backups/live-character-creation-1282-20261014.zip`
(manifest records every file's length and SHA256; the checkpoint script verifies
the archive after writing it).


## 2026-10-20 completion of creator fixes and UI steering

Offline experience fixturev14 passes all requested creator interactions, actual profile portrait decoding, voice decode/source start and17-model/16-part/26-texture human and half-orc asset paths with zero HTTP. See creation-experience-ui-v14.json. Cached admission and presentation IO improvements followed these creator fixes. The requested in-game character sheet is implemented and separately validated in singleplayer/vanilla multiplayer. The user now restricts live testing to the local server; do not reconnect to Arelith. A two-minute local academy check at3100x1121 stays66.6–96.2FPS, with100tiles/92objects prepared in5981ms after area-loading, no new shaders during sustained rotation and no renderer errors. This is not complete dense/modded-world acceptance. The held-key refresh correction and remaining contact gaps are documented in multiplayer-keyboard-repeat.md; the goal remains active. Character-sheet details are in multiplayer-character-record.md.
