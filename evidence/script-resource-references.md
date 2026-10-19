# Script resource references and sound ownership — 2026-10-17

Target NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project remain unchanged. Goal ACTIVE; single-player first.

## Native owner and storage

The independent command table maps **GetResRef582 and GetTilesetResRef814**
to ExecuteCommandGetResRef**14052fba0..52fe61**. Earlier working notes guessed
the second cast was a module cast; the active API, original vtables and actual
area pointer adjustment disprove that guess. No implementation uses it.

Mandatory StackPopObject52fbf3 fails with -639 before lookup or output. A
successful pop always calls GetGameObject52fc14, using the complete DWORD ID.
For582, the first AsNWSObject call52fce8 gates a second call52fcf6; the second
may be null, in which case the result stays empty. A generic object copies
**CNWSObject+30's explicit-length CExoString**, including embedded NUL bytes
after a nonzero first byte. A leading NUL/null buffer normalizes empty. The
query does not impose a16-byte cap on this owning string.

Only a failed first generic cast tries AsNWSArea52fd29/52fd3b, returning the
area's CResRef at+120 as a C string. Selector814 goes directly through area
casts52fc43/52fc55 and reads the tileset CResRef at+1a8. Unsupported selectors,
missing objects and failed casts produce empty strings. All successful-pop
paths call original LowerCase52fdd3 (owner14016bd70..16bddd), then
StackPushString52fe23; failed push returns -638. Cleanup paths execute in the
native oracle, while native string ownership is captured below JS GC.

Original vtable slots+20/+50:

| Vtable | AsNWSObject | AsNWSArea |
| --- | --- | --- |
| CGameObject140dc2ab0 | 1402962e0/null | 140296270/null |
| CNWSObject140df0fb8 | 140382910/identity | 140296270/null |
| Area CGameObject140ddad88 | 1402962e0/null | 14035c250/this-138 |
| Module CGameObject140def280 | 1402962e0/null | 140296270/null |
| Sound140df6320 | 140382910/identity | 140296270/null |

Area ctor140359f90 constructs CGameObject at+138 and resource ref at+120;
LoadTileSetInfo140362700 reads typed `Tileset` into+1a8. The original area
virtual cast executes in the oracle, not a synthetic pointer-equivalence stub.
Module, sound and generic virtual leaves also execute from the original image.

CNWSObject ctor48b7b7..48b7c6 initializes template string empty. Serialized
GIT/BIC imports now read actual typed RESREF TemplateResRef, default empty,
preserving case until the query. Evidence includes LoadCreature3975e0 with
assignment39771f, LoadTrigger502ac0/assignment502c07, LoadDoor4208a0's complete
retained pseudocode, successful LoadEncounter43c490/assignment43c791, and the
previously verified item/placeable/waypoint/store loaders. This adds the selected
template field, not a claim that every one of those complete loaders is ported.
Dynamic template/copy owners retain their separate native assignments. Queries
never infer a resref from tags, display names, source keys or stale authored data.

**Sound16 is a CNWSObject**, confirmed by ctor1404f3600 calling that base with
type16 and vtable+20's identity leaf. Expanded native comparison exposed the
old range-based exclusion. Sound now receives the selected shared base state,
including template/effects/actions/creator-target list. Its complete Load4f4b60
does **not** read TemplateResRef; GIT sound load retains the constructor's empty
string. The query still reads a changed live sound string correctly. Native
CanCarryUUID is a separate predicate and continues to exclude sounds.

The shared `asNWSObject` projection also fixes sound admission in effect creator,
caster-target tracking/removal, AoE creator attribution and copied-item fallback.
It does not broadly replace every older adapter's object-type admission; those
owners remain subject to their own parity checks. Noncreature sound caster level
is0 under the existing native caster-level owner. Canonical IDs/effect IDs remain
unchanged in representation, allocation and ownership.

## Verification and limits

- **682 original-code cases PASS** (`native-script-resref-observations.json`,
  `native-script-resref-v2.txt`): complete shared handler and LowerCase, native
  virtual casts from five vtables, pop/push failures, invalid selector/lookup,
  empty/leading/embedded NUL,16-byte area refs, longer generic strings, first-cast
  precedence and synthetic changing second-cast/null behavior. Boundaries are
  VM, game-object lookup, owning-string allocation/copy and ASCII CRT tolower.
  Locale-specific high-byte case conversion remains explicitly diagnosed by
  the existing script string adapter; no guessed Unicode/CRT locale behavior.
- **51 final focused tests PASS** (`script-resref-focused-v7.txt`): resource
  query/native field widths, world templates, object construction/UUID/lifecycle,
  sound state, inventory/copy, effects/creator/rest targets and AoEs. No full
  ~2,000-test suite rerun was needed. The earlier682-case extension exposed
  sound admission; first514 cases had not included its native vtable.
- **Installed `installed-script-resref-v5.json` PASS**:16 query/copy scenarios
  covering actual Prelude ARE/GIT/BIC and all12 available object kinds,
  missing/internal-vs-external IDs, separate area/tileset results and a native
  copied item whose authored record is empty. Queries allocate no object IDs.
  Parsed-NCS CopyItem onto a real sound falls back to its actual ground area/XYZ.
  Parsed-NCS effect creation with sound self, temporary HP application to the PC,
  public RemoveEffect and scheduler delivery verify creator ID/level0, the live
  creator-target list and cleanup. Existing temporary-HP presentation omission
  remains recorded; no invented visual/icon acceptance.
- The same installed probe executes untouched **x0_s3_prayer**, selected from
  active spell619 metadata, through event19. The actual `des_prayer.2da` recipe
  chooses reagents and expected summon. Empty bowl and unmatched pair produce
  original speech refs40144/40145; both valid ingredient orders create the
  expected canonical summon, type4 associate/master/area and temporary effect.
  Ingredients remain, matching the script. Public effect removal plus deferred
  destruction cleans both summons and associate/effect entries. No engine errors.
  Startup/general AI are isolated; no script replacement or per-spell production
  behavior. This proves impact/effect paths, not full input/cast-resource use,
  mount lifecycle, save/protocol, rendering or campaign completion.
- Diagnostics retain native speech/temporary-HP presentation omissions and the
  summoned template's unavailable `script2` resource. Native RunScript failure
  is preserved; no fabricated success or no-op script.
- Public CopyItem regression **15 checks PASS** after final owner changes
  (`installed-resref-copy-regression-v2.json`). Final build-v3 PASS. Final
  isolated offscreen casting UI-v2 PASS, session41313 terminal0 consumed:
  book/radial self cast, slot consumption, hotbar targeting, animation, cancel
  and counterspell. First UI-v1's shutdown GPU text is retained.
- Auditv60:840 spells,618 impact references,596 loaded,**44 unbound calls /
  22 load failures**. GetTilesetResRef adds a binding outside this active
  impact dependency list, so two bindings remove one unbound row. Audit exit1
  is intentional. Counts do not prove complete spell/combat/campaign acceptance.

Failed fixture/check reports are retained. Installed-v1 incorrectly assumed
container iteration followed creation order; membership preservation is the
relevant native invariant, corrected in v2. Installed-v4 checked effect removal
before pumping the public deferred event; v5 checks after native event delivery.
The extended682-case unit failure revealed the real sound-cast gap and led to
the production constructor/query/ownership fixes. Final focused/installed checks
were rerun after those changes; no original behavior was weakened to pass.

REA dossiers use prefixes `rea-object-resref-wrapper`, `rea-*-ctor-resref`,
`rea-*-load-resref`, `rea-area-tileset-resref`, `rea-string-lowercase-resref` and
`rea-sound-template-loader-resref` in backups/animations. The complete door
report exceeded stdio budget; retained view `rea-door-load-resref-pseudocode.json`
contains the full requested pseudocode. REA session99283 remained live and was
reused. Next casting gap:581 maps to DecrementSpellUses1405155c0; its complete
wrapper dossier is saved but not implemented. Other effects/combat/campaign
gates remain open. No goal completion claim.

Verified checkpoint `backups/script-resref-sound-20261017-v1.zip` contains
11180 files/162703430 bytes. Every archived length/SHA256 was verified;
session25370 terminal0 consumed, `script-resref-checkpoint-v1.txt`.
This verification note was added after sealing.
