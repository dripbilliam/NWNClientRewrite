# Nominal damage and item-column corrections — 2026-10-17

Target: read-only NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project unchanged. Single-player remains priority;
this increment does not establish complete spell/combat/campaign readiness.

## Implemented and corrected behavior

Complete nominal GetMeleeDamageBonus1404047c0..140404a98 and
GetRangedDamageBonus1404061f0..14040681d are ported in nominal_damage_bonus.js,
with live canonical-equipment/feat providers on CombatRuntime. These are
prerequisites for UpdateCombatInformation, distinct from target-specific/random
strike damage. No target, favored-enemy, point-blank, combat-mode or RNG additions
are invented for the nominal queries.

Melee chooses left before right-hand double-weapon fallback. Natural BYTE255
selects right;0/1/2 select creature weapons. Selected ranged items return0.
Signed cached STR, creature size718, positive-only single-precision strength
scaling, active ruleset and ordinary/epic specialization follow native branches.
Ranged preserves thrown/negative-strength/crossbow exclusions, Mighty, highest
Enchant Arrow tier and both specialization queries. No-item queries still check
unarmed specialization. Actual float multiplication uses MULSS/CVTTSS2SI into
a DWORD, including INT_MIN on invalid/overflow conversion.

Actual GetDamageBonus1403fd4b0..1403fee14 reads Mighty property45's WORD+6
CostValue, not WORD+2 Subtype. The old live strike implementation read Subtype.
It now shares the checked Mighty/scaling primitives with nominal queries.
This corrects real ranged damage, not just a UI summary.

Installed property testing exposed a separate loader bug: NativeItemRuntime
queried a nonexistent BasePropColumn header. Native Load14029dfa0 reads
**PropColumn** at call14029f6e5 and stores its output BYTE at14029f712 into
base-item+32. Corrected the header; retained native internal basePropColumn
field. Existing test fixtures now name the real installed header. No fallback
to the invented header is provided. This repairs eligibility across item types.

The live roll exposed invalid-slot warnings from another field mix-up:
GetTotalEffectBonus140393340, ammunition call chain1403942d8..14039430d,
reads base-item BYTE+18 as an ammunition BASE-ITEM ID, then that item's
EquipableSlots. BYTE+18 is loaded from **RangedWeapon**, not AmmunitionType.
Corrected the shared damage-effect query and its old evidence/table fixtures.
Native RangedWeapon loader14029ec06..14029ecbb also writes0 on failed lookup,
unlike PropColumn's unconditional query-output narrowing; now preserved.

## Native evidence and validation

REA dossiers: nominal-melee-damage-owner, nominal-ranged-damage-owner,
strike-damage-bonus-mighty-current. inspect-native-nominal-damage.py executes
original complete nominal functions and controlled actual strike calls with
original FNV-1a hashing: **1771 cases** (875 melee,444 ranged,452 strike).
Equipment/base/feat/property/ruleset lookup and unrelated strike helpers are
captured boundaries. No debug-string, random/target bonus or full encounter
claim. Fixtures cover signed cache bytes, offhand/natural selectors, raw Mighty
costs, specialization/arrow tiers, active rules and float-to-int overflow.

inspect-native-base-property-column.py executes two bounded loader blocks
(48 cases) and exact ammunition lookup instructions (42 cases). **1861 total
new native cases**. These do not execute the complete base-item loader or
GetTotalEffectBonus. Full old hash-checked assembly remains in
scheduler-baseitems-loader-asm.txt and live-total-effect-bonus-decompile.txt;
new exact ammunition window: native-damage-ammunition-lookup-window-v1.txt.

REA full analyses of LoadBaseItems and GetTotalEffectBonus completed but their
complete MCP responses exceeded transport budgets. Their retained evidence
was recovered through inspect_analysis_view: page0 plus rest, both exhausted,
57725 and84099 UTF16 units. IDs respectively
ev_7f4f2af84f109cee7319be01b6eb38f021e24ca53c98b9233839c4ec407f4166 and
ev_f4b28e0d63f62bb53678efb3f98f580065090784aaf49a068a9911ef2070da1c.
The transport errors are retained, not misreported as missing native analysis.

Installed probe **v3 PASS**: untouched Prelude/wizard/light crossbow; generic
NCS STR buff and Mighty constructor/AddItemProperty/RemoveItemProperty; actual
equip/unequip, nominal query and maximized damage-roll pipeline. STR modifier6,
Mighty CostValue3/Subtype65535; damage **8->11->8** and nominal0->3->0. Item,
character, original inventory/equipment/properties and canonical cursor restore.
No errors or invalid-slot warnings during checks. All63 initial diagnostics
retained, including one known absent plc_w02.pwk load error. Startup/general
AI isolated; direct roll does not prove queued attack, HP impact or visuals.
v1 retained genuine property rejection caused by wrong PropColumn; v2 passed
Mighty but exposed three invalid-slot warnings; v3 removes their actual cause.

1906/1906 tests and build pass; existing chunk-size warning retained. Final
offscreen items UI passes prepared equipped-item target, F2 carried-item target,
native item spell wheel, resource consumption and right-click cancellation;
zero engine omissions, terminal exit0. Entangle/failure probev15 and bonus
attacks/slots/Tenser probev11 also pass after the PropColumn correction.

## Outstanding shared refresh

Superseded by [combat-information rebuild](combat-information-refresh.md): the
complete orchestration and synchronous callers are now connected. Real GUI
subscriber input and polymorph copy/snapshot ownership remain open. The following
paragraph records the state before that subsequent increment.

UpdateCombatInformation1404171e0..140418523, its constructor2a22b0, node ctor
2a2370 and GetFilteredEffectList390560 are mapped in retained REA dossiers.
The refresh also owns filtered attack/damage nodes, ammunition property ranking,
weapon IDs, critical/unarmed summaries and ability caches. This full owner is
NOT yet ported or connected: existing synchronous refresh diagnostics and
polymorph snapshot limitation remain. New nominal methods supply two missing
dependencies; they do not silently replace that larger owner with a projection.
Next: exact filtered-effect/node/cache lifecycle, then integrated shared refresh
and ordinary campaign acceptance. Goal remains ACTIVE.

Verified checkpoint: backups/nominal-damage-items-1906-20261017-v1.zip,
10177files/132996959bytes; every archived length/SHA256 verified, terminal exit0.
This note was added after sealing; archive contains pre-verification notes.
