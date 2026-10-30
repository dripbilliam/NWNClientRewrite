# Pregame Spells — scoped native migration

The chooser's fourth original record tab now opens a native Spells list and help
page. The shared mode-zero list owner keeps the source models, icons, Galahad14,
scrollbars, row geometry, clipping and original-scale proportions. Known rows
select active spell help. Summary rows select their radio button but retain
the previous description and scroll position, matching the original ID-1 path.
No casting, preparation or fabricated gameplay request is sent by this page.

`native_data/pregame_spells.gd` reads typed WORD Spell fields from BIC KnownList
records, retaining duplicates and import order. It regroups them using each
active class's SpellTableColumn, rather than trusting the KnownList suffix.
Active classes/races/skills/ruleset/spells and selected class stat/skill/spell-gain
tables supply the rules. The native asset service loads missing dependencies;
connection ownership guards publication. No JavaScript display/rules rendering
path was introduced. Native BIC bytes are not reparsed for late text changes.

Unrestricted casters get the original highest-level summary when their minimum
ability and slot checks pass above level zero. The source's class-3 Druid refs,
other-class Cleric refs and level icons are retained exactly, with active TLK
resolution; custom classes are not silently assigned a different summary policy.
Specialization, ability modifiers, signed/byte arithmetic,40-row spell-gain
storage, prestige progression and highest-class/index tie selection follow the
original calculations. Slot arithmetic remains separate from the minimum check:
the original can return slots for a noncaster with configured gain data, while
its minimum check prevents a summary. This is pregame inspection, not acceptance
of complete gameplay spellcasting parity.

## Original evidence

Binary SHA256 is `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Root `backups/animations/rea-native-pregame-spells-v1.json` retains original
SetData1409c1b50, minimum1407f7130, slots1407f6b20, gain140299e40,
AddKnownSpell1407ebed0, class/spell-level getters, summary arrays/icons and a
complete retained class-loader pseudocode view. The full loader dossier exceeded
the tool transport budget; its47,440-code-unit view is complete and explicitly
identifies the retained original evidence, binary and coverage. The separate
`rea-native-pregame-spell-word-v1.json` verifies strict type2 WORD reads.
Selection/row construction remain in `rea-native-pregame-record-pages-v1.json`.

`scripts/inspect-native-pregame-spells.py` executes unchanged original slot,
minimum, prestige, AddKnownSpell grouping and complete SetData instructions for
72 deterministic cases. UI row construction, TLK and spell/active-level lookup
services are captured. Typed GFF reads and initial score writes remain fixture
boundaries; it is not a full import or original-client visual oracle. Accepted
data is `native-pregame-spell-observations-v2.json`. Cases cover custom class
columns, unrestricted/restricted casters, empty/noncaster roles, specialization,
ability thresholds, prestige class selection/ties, duplicates and byte widths.

## Current verification

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-pregame-spells-data-v3` |296| Original72-case comparison, typed WORD/defaults, regrouping and error states |
| `native-pregame-spells-skills-v1` |373| Original skill/source arithmetic regression |
| `native-pregame-spells-frame-v2` |61| Actual native BIC, all three original list tabs, spell duplicates/summary/help, text/tooltip updates, scroll/stale input and100/125-percent input |
| `native-pregame-spells-worker-v1` |24| Preview integrity/selection/worker regression |
| `native-pregame-spells-preview-v1` |15| Raw preview/text publication regression |
| `native-pregame-spells-chooser-v1` |25| Selection/New/Cancel and remaining controls |
| `native-pregame-spells-pages-v1` |32| Server Info/Player List regression |
| `native-pregame-spells-phase-v1` |22| Pregame/gameplay visibility/input ownership |
| `native-pregame-spells-startup-v1` |12| Original entry routes with no connection |
| `native-pregame-spells-local-v1` |207| Twelve actual record-tab/row checks before seven admission,18 roster and170 authoritative gameplay/UI checks on original localhost5125 |
| `native-pregame-spells-service-v1` |55| Protocol/lobby/raw-source service regression |

These1,122 checks have different scopes, not an overall completion percentage.
Original-scale and125-percent native Spells screenshots were reviewed. Windows
remained unfocused on secondary screen0, primary2; public connections were zero.
The owned local run released workers and removed its raw preview source.
`tools/audit-native-pregame-spells.mjs` verifies evidence/scopes and rollback
`backups/native-pregame-spells-v1.zip`.

Retained development evidence: the first Python run used an incomplete getter
boundary, corrected from the provider's exact range. Oracle-v1 injected grouped
books; its data and script are retained but unaccepted. V2 executes AddKnownSpell
itself, which also excludes rows that a noncaster player class could not import.
Data-test-v1 retained22 slot-calculation mismatches; separating the original
slot/minimum checks corrected them, with all72 cases passing afterward. The
earlier Feats-v2 startup heap exception remains unresolved; these later clean
runs do not establish complete stability.

## Still open

All four pregame record tabs now have native owners, but Character statistics
remain incomplete, including race/class-adjusted display, full HP/AC/save/attack/
damage details and source title/flag policy. Local row metadata, editing/deletion,
keyboard/audio/gesture/role/resolution coverage, exact hover/pressed/selection
styling, full description-token context and original-client comparisons remain
open. Complete BIC import and every malformed/custom table behavior are not
accepted. Beyond-width known-row loops and invalid class-gain storage stay
unavailable with data errors rather than reproducing invalid reads or hangs.
Gameplay spellbooks, family/casting actions and every other UI surface retain
their separate open requirements. The startup exception and earlier capture/
sampler/blood-pixel failures stay unaccepted. Full UI remains unfinished, and
general porting remains deferred.
