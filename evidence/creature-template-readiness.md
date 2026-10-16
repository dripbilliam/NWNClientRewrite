# Creature template readiness and effective ruleset keys — 2026-10-16

Target: NWN:EE89.8193.37-17 x64, original unmodified `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game install remains read-only. No Ghidra database changes.

## Creature template wrapper

`creature_template.js` ports the complete LoadFromTemplate397dd0..398162.
135 original executions compare wrapper order/flags, resource failure and
cleanup, reversed stats-read result (nonzero means failure), template/tag writes,
ignored lower return values and the ten final ReadySpellLevel calls. Resource,
root/stat read, feat bonuses, script/item/spell/variable reads, AsTAG, postprocess
and spell-use updates are explicit lower boundaries in this wrapper oracle.
Original root-read status is ignored. Allocation failures/exception unwinding
and full lower creature-data import are not claimed by this comparison.

The original sequence is ReadStats(0,0,0,1), ComputeFeatBonuses, template write,
ReadScripts39cb00, ReadItems39c170(1,1), ReadSpells40f3e0(0), variables497ba0,
optional AsTAG/raw tag assignment, PostProcess39b3e0, ReadySpellLevel4123b0
for0..9, release resource, return1. The resource warning text was read at its
verified RIP target140dddad0. The old Ghidra decompile ends early through
inaccurately recovered branches; the complete verified unwind-range assembly
and original execution are the validation sources.

`ModuleSession.loadCreatureTemplate` now follows that wrapper. Previously it
inserted the authored tag before any override, imported variables before items
and spells, omitted feat ability bonuses, and never readied template spellbooks.
The override now reaches postprocess tag lookup; no premature old-tag alias is
inserted. ReadStats40f87a..40f89c confirms the last flag1 forces stats-PCb0 to0;
the bridge computes a separate NPC creature-data view while retaining authored
IsPC. Stats Tag40fa36..40fac8 applies AsTAG twice with the current tag as typed
default. Plot uses the current BYTE default. Script fields use typed RESREF11
and existing script names converted to CResRef as defaults, per39cb00's virtual
GetScriptName/CResRef/GFF sequence.

Talent/spell pools initialize before ReadSpells. Postprocess no longer resets
the already imported pools; its other existing initialization is retained. The
template caller then uses the independently compared existing RestRuntime.ready
owner for all ten levels. No slots or spells are manufactured here: existing
prepared records are readied, and spontaneous counters use the native gain
owner. Complete creature ReadStats/PostProcess support remains a broader gate.
Saved creature polymorph/effects still diagnose and reject explicitly.

## Feat ability bonuses and progression

`feat_ability_bonuses.js` ports full delta helper4097c0..40a68b and
ComputeFeatBonuses3f2110..3f22b4.937 original executions compare the fixed
great-ability feat enum ranges, descending membership queries, active rule
lookup per match, signed INT accumulation/negation, base BYTE wrap, current
score/modifier query order, encumbrance, polymorph base snapshots and dirty544.
Membership, ruleset values, derived score/modifier/encumbrance remain captured
lower boundaries; the native hash continuation now executes unchanged.

Strength updates encumbrance before polymorph Str9de. Dex9e0/Con9df update
when nativeField97c is nonzero. CON does not adjust hit points in this owner.
Mental abilities dirty544. Concrete template loading uses existing ability
score/modifier and encumbrance owners. Level-history replay/reversal shares the
same rule-aware delta helper, replacing its prior hardcoded +1/-1 increments.
A regression changes the active great-stat bonus to2 and checks exact reversal.

## Correction: a literal suffix is not the effective rule key

The inspected call sites seed FNV with a prehashed first character, then pass
the remaining suffix to hash continuation2ae870..2ae898. Earlier price evidence
used `AX_CHARGES_FOR_ITEM_COST` as the full lookup name; that was incorrect.
The first ability implementation likewise used its visible `PIC_` suffix.
Both have been corrected, along with four existing companion-interaction bridges.

| Effective key | Seeded first byte | Suffix at call | Verified call site |
| --- | --- | --- | --- |
| EPIC_GREAT_STAT_BONUS | E / af63f84c86021c20 | PIC_GREAT_STAT_BONUS |140409823|
| MAX_CHARGES_FOR_ITEM_COST | M / af64004c860229b8 | AX_CHARGES_FOR_ITEM_COST |14046518e|
| ALL_ASSOCIATES_CAN_INTERACT | A / af63fc4c860222ec | LL_ASSOCIATES_CAN_INTERACT |1403d14dd; also1403ca022|

The complete hash leaf is verified by CFG capture
`create-object-rule-hash-leaf-v1.txt`. `inspect-native-rule-prefixes.py` executes
the three actual suffix/length/seed inputs unchanged, and tests compare the
outputs with `rulesetHash` of the **full** label (and reject the suffix hash).
The937-case feat and1,439-case price oracles were regenerated with this leaf
executing unchanged; their rule-value boundary asserts the full effective hash.
Their prior hash-boundary stub could not establish the correct active key.

The read-only source/active-label audit checks literal one-character suffix
candidates against424 installed ruleset labels. It found four LL_ companion
bridges; after correcting those, audit v2 has no candidates. This limited static
audit does not prove every dynamic label, rule query or native hashed call.
Regression tests distinguish ALL_ from a deliberately present wrong LL_ value
for all four concrete equipment, unequip, repository-move and use-object bridges.

Use Magic Device item restrictions now reach the implemented item pricing owner
with their existing GetCost(0,1,1,1) flags; the old concrete itemCost placeholder
is removed. Its regression exercises ILR factor7 and plot override alongside
GetGoldPieceValue's different flags. Minimum equip-level/ILR policy owners are
still separately incomplete.

## Installed and rendered validation

`probe-installed-creature-templates.mjs` v4 passes with four real UTCs:
x3_antoine574, x3_blckcobra001576, x3_caladnei579 (four prepared spells ready),
and x3_curstsword588. Caladnei's robes reference is unavailable in the active
Prelude resolver: `robesofthepuremi`, failed item ID580. The probe independently
rechecks the declared reference against the resolver and verifies its canonical
item was destroyed; no assets are substituted and the failure remains recorded.
This is an expected missing module-specific item, not a clean full-stock claim.

A RAM-only UTC fixture based on the installed wizard BIC creates canonical
creature592 and items593..600. Active EPIC_GREAT_STAT_BONUS2 changes Str by2;
authored IsPC1 becomes runtime NPC0; typed locals load; tag override reaches
lookup without an old alias; a wrong-typed ScriptSpawn retains its existing
name. All34 authored-unready prepared records become ready. UUID remains empty
because this template wrapper has no generic UUID import. Destruction owns all
children and retains allocator cursors. Startup/AI are isolated for this probe.
It does not execute Engine243 or place/render these fixture creatures.

All42 installed UTM templates/4,597 direct stock items pass again with the
corrected MAX_ key (`installed-store-templates-v3.json`). Actual summoning
regression v2 passes all six lifecycle cycles with no error diagnostics; the
existing missing-script and impact-broadcast records remain visible. Rendered
right-click summoning, follow/stand-ground/unsummon, model binding/removal, real
slot consumption, and spellbook/radial/hotbar/counterspell/cast-animation checks
pass against the final build. All owned processes reached terminal exit.

All1,746 tests and production build pass (`create-object-loader-full-tests-v4`,
`create-object-loader-build-v3`). Existing bundle-size warning remains. Checkpoint
target: `backups/creature-template-1746-20261016-v1.zip`, verification log
`backups/animations/creature-template-checkpoint-v1.txt`.

CreateObject243 remains unbound. Remaining work includes concrete creation
placement/orientation/map-pin providers, dynamic ground-item rendering and
their script/UI validation. The full spell ecosystem, combat and campaign goal
is not complete.
