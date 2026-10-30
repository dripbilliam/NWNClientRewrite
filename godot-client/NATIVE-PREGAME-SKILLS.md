# Pregame Skills — scoped native migration

The [pregame Spells follow-up](NATIVE-PREGAME-SPELLS.md) supersedes the
disabled-Spells state below and carries current regression/rollback evidence.
Complete Character statistics and the broader UI audit remain unfinished.

The original chooser's Skills tab now opens a native original-model list and
description page. It uses typed BIC data and the active server's skills/classes/
racialtypes/ruleset tables, plus each selected class's SkillsTable and StatGainTable.
Missing tables keep the tab pending while native workers fetch dependencies.
Publication follows connection ownership; changed text/table revisions refresh
the projection. No JavaScript display/rules calculation was introduced.

`native_data/pregame_skills.gd` extracts BYTE abilities/race/ranks and INT/SHORT
class fields through the native GFF type map. It reproduces the original base
constructor defaults and nonzero class-level setter behavior. Wrong field types
use original defaults instead of accepting any integer. The raw preview worker
publishes only bounded skill-source fields alongside the existing display data.
This is data extraction, without world scripts/effects or gameplay mutations.

Pregame values follow original client import: per-level class stat gains wrap
to a signed byte for each class, their aggregate clamps to[-128,127], and race/
base/class adjustments form byte-sized scores. Native ability rules then produce
the rank-plus-modifier value, again a signed byte. Trained/untrained admission
follows the original class-use checks and32-bit mask, including index aliasing
above31 and the byte-sized skill count. These are original preview semantics,
not a replacement for authoritative in-world skill/effect calculations.

The shared mode-zero record list owner uses CTL_CHR_BTN_SKIL with its separate
value hook, original icons, Galahad14 and original row/scrollbar geometry. The
description changes on actual row selection. Connection/character changes retire
held input. Feats keeps its existing page and controls; Spells remains disabled.
Only actual native BIC previews enable Skills, rather than treating older display
fixtures as complete source records.

## Evidence

Root `backups/animations/rea-native-pregame-skills-v1.json` retains15 original
read-only dossiers: BIC import1407f7e20, skill calculation1407fadc0, class gains
1407f1110/140299710, skill/class loaders and membership, constructors and pregame
Skills SetData1409bffb0. Binary SHA256 is
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

`scripts/inspect-native-pregame-skills.py` executes unchanged original arithmetic,
class-gain, membership, value getter and eligibility instructions, including the
exact import mask block1407f8ba8..1407f8d89. Hash/ruleset services and initial
effective-score/BIC writes are captured boundaries. Its72-case fixture is
`native-pregame-skill-observations-v1.json`; it is not a complete GFF-import or
original-client visual oracle. It covers custom rules, negative/wrapped values,
invalid class normalization, multiple classes, class-gain saturation and0/33/40/
255/256-row skill tables.

Current source-pinned receipts:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-pregame-skills-data-v3` |373| Original72-case arithmetic/admission comparison, typed BIC defaults and pending/error states |
| `native-pregame-skills-frame-v6` |49| Real native BIC, class dependencies, original Skills/Feats input/help/value geometry, scroll, stale input and100/125-percent review |
| `native-pregame-skills-worker-v1` |24| Preview integrity/selection/worker regression |
| `native-pregame-skills-preview-v1` |15| Preview/text publication regression |
| `native-pregame-skills-chooser-v1` |25| Selection/New/Cancel and unported-control regression |
| `native-pregame-skills-pages-v1` |32| Server Info/Player List regression |
| `native-pregame-skills-phase-v1` |22| Pregame/gameplay visibility/input regression |
| `native-pregame-skills-startup-v1` |12| Entry routes without a connection |
| `native-pregame-skills-local-v2` |204| Nine actual Skills/Feats checks before seven admission,18 roster and170 authoritative gameplay/UI checks on owned original localhost5125 |
| `native-pregame-skills-service-v1` |55| Protocol/lobby/raw-source service regression |

These811 checks cover different scopes, not complete UI parity. Current native
Skills images at original and125-percent scale were reviewed. Windows remained
unfocused on secondary screen0, primary2. Public connections were zero. The owned
local run released its workers and removed its preview source. Its first local
run also passed; v2 additionally covers final base-table readiness guards.
`tools/audit-native-pregame-skills.mjs` verifies scopes, original evidence and
the rollback `backups/native-pregame-skills-v1.zip`.

Development failures are retained: the first Python harness used an incomplete
function boundary and was corrected to the provider's exact end. Graphical
frame-v1/v2/v3 wrongly expected all28 stored ranks to become rows. Inspection
confirmed stock skill11's Untrained=1, AllClassesCanUse=0 and absence from the
wizard SkillsTable. The original eligibility rules omit that row, giving27 rows
with value7 for the fixture. Final graphical checks require those source table
conditions and that exact omission; the runtime algorithm was not changed to
make the assertion pass. The earlier Feats-v2 native startup heap exception is
still unresolved; later clean runs do not accept complete stability.

## Remaining requirements

Spells still needs original summary/known-spell rules and controls. Complete
Character statistics (including race/class-adjusted display, AC/HP/save/attack/
damage details), local row metadata/editing, keyboard/audio/gesture/role/scale
coverage, primary/bonus import and full original-client comparison remain open.
This does not migrate general gameplay skill bonuses or grant casting/actions.
Malformed modifier rules and class-gain levels beyond the original60-row storage
remain unavailable with explicit data errors rather than reading invalid memory.
Full BIC import, every malformed/custom table behavior and full Skills/UI visual
and interaction parity remain unaccepted. The broader UI goal stays active;
general porting remains deferred.
