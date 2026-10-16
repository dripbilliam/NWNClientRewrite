# Scripted talent actions and accessors

Target NWN:EE89.8193.37-17 x64, original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only Ghidra and hash-verified full PE captures were used. Original install
and Ghidra project remain unchanged.

`talent_actions.js` ports complete AddUseTalentOnObjectActions140380fb0 and
AddUseTalentAtLocationActions140380e20. The object wrapper requires a target
creature and nonzero actor commandability, copies target XYZ and queries actor
area twice. Kind0 dispatches shared casting or UseItem for a non-sentinel item
plus property index. Kind1 calls UseFeat with a null point; compiled called-shot5
chooses auxiliary65000/65001 using CRT RNG. Kind2 calls UseSkill with BYTE ID,
zero mode and copied target point. Unknown kinds return1 without an action.
The location wrapper only dispatches kind0. Item-backed location talents check
actor area, clear actions, re-read actor area and invoke UseItem. Location's own
area ID is not used. All lower action results are ignored by these wrappers.

The old innate-only wrappers delegate to these shared owners without changing
the native class254, caster/meta fields or decoded input35 return behavior.
TalentRuntime connects creature/area/position, RNG, shared feat/cast/pickpocket
skill and action-clear owners. Other admitted skills remain explicit errors.
UseItem1403a9f70 is still an explicit lower omission, not fabricated casting;
full original UseItem and AddUseItemActions14037f030 are now captured for the
next step. No claim of working item/scroll casting is made by this milestone.

ExecuteCommandActionUseTalent14050f620 copies the talent fields before resolving
script-self. Kinds<=-1 skip both self lookup and the second argument pop. Missing
self also leaves the target on the VM stack. `NwScriptVm` now supports a native
handler's conditional typed-pop adapter; the two real commands309/310 use it.
Other handlers retain their generic argument path. A skipped target cell is
preserved even if it has the wrong type; valid dispatch still rejects a wrong
typed target. Engine context/arity checks and diagnostics remain in the VM.
This matches original control flow rather than correcting its leftover stack
cell. JavaScript value lifetime is not native allocation identity/cleanup.

The original installed accessors are GetTypeFromTalent362 and GetIdFromTalent363.
The prior GetTalentType/GetTalentId names did not bind those engine calls. They
are replaced with the actual API names and raw signed INT access through
TalentAccess1405485f0. Negative kinds/IDs are returned without validity filtering.

## Verification

`inspect-native-talent-actions.py` produces12444 complete original executions:
object/location wrappers, script dispatcher and accessor owners, including
commandability/lookup/area gates, item sentinel/property widths, every kind,
compiled called-shot behavior, class/caster/meta narrowing, lower result
discarding, conditional pops and raw signed access. VM primitives, registry,
area, RNG, lower UseFeat/UseSkill/UseItem/AddCastSpellActions and cleanup are
captured boundaries. This is not full native VM or lower item/skill gameplay.
Focused tests compare result, lower call trace and actual pop order; typed VM
tests additionally validate leftover stack cells and actual accessor names.

`probe-installed-talent-actions.mjs` runs actual typed commands with unchanged
installed character and NPC pools. Five profiles execute authored scripts:
prepared Light100 on an object; prepared ElectricLoop520 at a location; druid
WildShape305 through its owned highest feat338; NPC544 innate126 on an object;
NPC461 innate36 at a location. Actual imported pool records supply class,
caster and metamagic fields. No spell/feat/ability grants, BIC modifications,
fake charges or original data writes are used. Slots/innate readiness/feat uses
decrease in their respective pools; class slots remain untouched by feats and
innate casts. Queues drain and canonical actor/root/stats remain unchanged.

The first run failed its blanket diagnostic assertion on the existing absent
plc_w02.pwk reached by NPC location LOS. v2 retains and separately asserts only
that exact known resource failure; every new failure remains fatal. It passes
all five profiles with no thrown errors or new error diagnostics. Startup/AI-off
fixtures are not campaign or all-spell effect acceptance. Existing effect and
impact broadcast presentation warnings remain visible.

All1594 tests and production build pass (`talent-actions-full-tests-v1.txt`,
`talent-actions-build-v1.txt`). Existing actual innate radial/drag/F2/duplicate
charge UI regression also passes (`talent-actions-existing-innate-ui-v1.txt`),
retaining its one known PWK failure separately. Active static auditv32 has90
unbound impact dependency names and22 missing NCS, down from94 after binding
the two actual accessor and two talent-use names. Binding presence does not
prove all branches. Item/scroll use, other effects, combat and continuous base
campaign acceptance remain open. Goal ACTIVE.
