# Script skill checks and item AC query

Previous goal turn made verified progress on public item copying and sealed
`backups/script-item-copy-1990-20261017-v1.zip`. This continues the full ACTIVE
single-player spell/combat/campaign goal. Complete spells, combat and continuous
campaign acceptance remain unproven.

Read-only target: NWN:EE89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original installation or Ghidra project changes. Native REA dossiers and
original-code observations are retained under `backups/animations/`.

## Complete engine-call owners

`script_checks.js` ports complete ExecuteCommandGetItemACValue
`140527d80..140527e47`. It looks up the canonical item, starts with cached
CNWSItem+35c, and adds each nonnull passive type1 property's unsigned cost-value
WORD. Multiple properties accumulate with native INT wrap. The passive count
is reread on each iteration. Missing/non-item sources return0. This is neither
final wearer AC nor a fresh computation from authored equipment/template data.

Complete ExecuteCommandGetIsSkillSuccessful `140527910..140527b85` preserves
typed object/skill/DC pop order, signed skill<255 gate, object-array BYTE status
and creature cast. Valid creatures call the existing effective GetSkillRank
with BYTE skill, null versus and baseOnly0; the returned CHAR is sign-extended.
RollDice(1,20) is narrowed to WORD. Native result classification is success1,
possible failure0 or impossible failure3 (rank+20<DC). There is no natural1
failure, automatic20 success, eligibility check or take10/20 behavior added.

Skill broadcast data carries creature ID and native skill-name strRef, roll,
rank, DC, zero and classification. Existing BroadcastSkillData handles native
owner/direct-client delivery. Invalid/noncreature targets or skill>=255 still
compare the default total0 against the caller's DC; they do not draw RNG or
create a skill broadcast. Decoder/push failures remain distinct-639/-638 statuses.
Runtime nativeStack bindings separately return the pushed integer.

## Native skill-name storage

Read-only investigation of complete LoadSkillInfo
`1402ac6f0..1402ad108` corrected an initial adapter assumption. The loader
allocates256 CNWSkill records, then fills only the BYTE physical skill row count.
CNWSkill constructor `1402ae8a0..1402ae8e5` initializes name and description to-1.
Unused rows, including254/255 with the installed table, still have storage.
They are not rejected merely for exceeding the active row count.

`skillNameReference` compiles active physical `Name` values into256 cached cells,
initially-1, honoring BYTE row-count wrap. A new table object rebuilds the cache;
mutating an already-loaded table does not silently change stored native records.
The bounded Name-loading fragment `1402ac8b0..1402ac936` reads Name and writes
the INT regardless of reader status. Existing native 2DA INT admission supplies
the reader's result. Negative skill values preserve the wrapper's signed gate
and subsequent WORD index; indices beyond the allocated256 records are diagnosed
as the native out-of-bounds domain rather than receiving fabricated names.

## Validation

`inspect-native-script-checks.py`: **575 original-code cases PASS**. These cover
33 item-AC cases,509 skill-wrapper cases and33 constructor/Name-store cases.
Complete wrappers execute original typed-pop/order/arithmetic/classification;
lookup/cast, passive getter, effective rank, RollDice, message allocation/setters/
broadcast and temporary-array cleanup are captured boundaries. The constructor
and Name-store fragment also execute original instructions. Synthetic mapped
skill-name data permits observing malformed WORD index arithmetic; it does not
prove the real executable safely supports those out-of-bounds indices.

The first Name-store capture stopped at the wrong presumed instruction boundary;
the actual eight-byte store ends at1402ac936. Corrected oracle-v3 passes. Earlier
542-case observations passed before the additional native storage investigation.
No production behavior was changed to fit an invalid capture.

`script-checks-focused-v3.txt`: **35 relevant tests PASS**, including the new
native comparisons, name cache, effective skills, skill action/buffs, item
runtime and prior copy/repository checks. The full suite was not repeated for
this narrow new binding change. Final production build status is recorded below.

`installed-script-checks-v4.json`: **17 query checks plus four untouched authored
script outcomes PASS**, using installed Prelude, cleric, goblin and active rules.
VM item queries cover seven equipped items and live passive-pool additions;
skill queries cover all classifications, invalid/noncreature/default-total
behavior, skill>=255 and unused native slot254 with Name=-1. Query checks
preserve the canonical allocation cursor and validate recipient message payloads.

The installed ruin-armor NCS runs through the normal on-hit event19 with an
actual triggering weapon. Its own script selects success, copy-and-remove,
module-switch permanent destruction or already-ruined guard. Controlled dice
give native rank2/DC7 outcomes. Default failure copies the armor with local
variables into the PC repository, then destroys/unequips the original. The
copied armor retains its marker without inheriting a flag written later to the
old object. Permanent destruction creates no copy. Success/guard preserve the
original canonical equipped item. No individual spell outcome was coded in JS.
General AI/startup are isolated; dice, switch and locals are explicit fixtures.
All four authored paths have no new warnings/errors in this isolated probe.

Initial installed-v1 failure was a case-sensitive test assertion against an
installed mixed-case ImpactScript resref. The fixture assertion was corrected;
production resolution remains unchanged. Source assets were read, not copied.

`installed-script-checks-copy-regression-v1.json`: all15 previous public-copy
scenarios PASS. Active spell auditv56:840 rows,596 loaded impact scripts,
**50 unbound commands** (previously52),22 load failures. Audit exit1 remains
intentional. Binding presence alone is not complete spell acceptance.

## Remaining gates

The rendered client still records type9 skill-message presentation as
unimplemented; the native broadcast payload/delivery is connected, but its
original GUI/log formatting remains separate work. No UI changes are claimed
or new UI smoke asserted in this increment.
Final production build `script-checks-build-v2.txt` PASS after the native name
cache correction; the existing chunk-size warning remains. Final probe-v4 also
retains the corrected query-rank reporting for unused slot254.

CopyItemAndModify was researched at `1405128f0..1405134a6` but remains unbound.
Its model/part/color validation, resource existence, weights/AC and placement
need complete native implementation and independent comparison. Dye scripts
also call WriteTimestampedLogEntry; an attempted guessed native procedure name
was absent. Use native procedure search to locate its real dispatcher before
binding it. Preserve explicit diagnostics while these owners remain unfinished.
Other spell effects, inventory/save/autosave, death/combat and full campaign
requirements remain open. No goal completion or pause is claimed.

Verified checkpoint `backups/script-checks-20261017-v1.zip`:10957 files,
158695243 bytes. Every archived length/SHA256 verified; checkpoint log
`script-checks-checkpoint-v1.txt`, terminal exit0. This note was added after
sealing. Goal remains ACTIVE; no pending validation jobs.
