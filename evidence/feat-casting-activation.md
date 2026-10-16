# Feat activation and shared casting

Target NWN:EE89.8193.37-17 x64, original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only Ghidra and complete verified PE instructions were used. No original
game assets or Ghidra project data were modified.

## Native owners and integration

`src/use_feat.js` ports UseFeat1403a91d0 through1403a9f68: highest successor,
ownership/state/reaction/uses gates, compiled modes and special attacks, form
variant selection, active feat/spell metadata, parent target checks, queued
casting and immediate event8. Its 857 original executions compare result and
lower-provider call order. Lower ownership, equipment, events, modes and queue
providers are captured; this does not establish their complete implementation.
Numeric exceptional feat branches here exist in the original binary. Ordinary
behavior is loaded from the active tables, with no campaign or spell-name cases.

LoadFeatInfo1402a8800/constructor1402a1180 are distinguished: SpellId defaults
to-1, ReqAction defaults to1 and normalizes successful reads to boolean,
TargetSelf defaults to0 after a failed read. HostileFeat is written
unconditionally from GetINTEntry output1402a9bb4..1402a9be1, including a nonzero
table default for a missing column. Blank cells yield0. TargetSelf/HostileFeat
successful reads retain signed INT values.

Shared AIActionCastSpell1403ada70 now accepts feat sources and follows native
feat readiness, special weapon checks and one-time use consumption. An added
960 original feat cases expand the existing cast-action fixture to4725 cases.
Class255 feat casts preserve class slots; class254 innate casting remains
separate. AddSpecialAttack140374da0 is ported in combat_round.js with1620
original queue/physical attack placement and WORD sequence cases.

Input6 branch1404533e9..1404534f7 adds387 original decoded-dispatch cases. It
preserves actor/packet/area gates, raw WORD feat and auxiliary fields, canonical
target IDs and a nonnull zero point for object targets. Dispatch acceptance is
separate from UseFeat's result. FeatRuntime connects this to the player FIFO,
live registry, shared casting/event/effect owners and native feat use pool.
Native wire serialization and multiplayer synchronization are not established.

Client target setup140703310 has517 original cases. It uses requested metadata,
compiled mode routes, automatic self targeting, signed auxiliary matching and
physical target registrations. It does not install the ordinary spell veto.
The live local targeter shares this decision projection. Full native pointer
picking and target preview rendering remain open.

## Installed execution and actual UI

`probe-installed-feat-casting.mjs` v2 uses unchanged installed druid/barbarian
characters: owned Wild Shape338 and Rage329 execute their authored scripts,
consume their own feat uses, preserve class/innate pools and canonical identity,
and drain their queues with zero errors. Original v1 failure is retained.
It exposed missing shared native item-level restriction configuration. The
native registered default is false140574db1; callback14057ba10 writes server
field134. ModuleSession now supplies that boolean and the equipment adapter.
Enabled restrictions still require minimum-item-level/pricing owners; this is
not a complete external server configuration loader.

Hidden Electron `smoke-live-casting-ui.cjs --feats` selects unchanged druid.bic,
drags its owned feat338 from Feats to F2/type4, activates F2 through input6,
observes uses5->4 and a live model change, then restores through the radial
Cancel Polymorph entry. Canonical player565 is retained. No spell/feat grants
or original-install writes occur. Startup-off entry fixture is not campaign
acceptance. Native immediate ReqAction0 is covered in the instruction fixture,
but has not been accepted through an installed character/UI test.

Warnings about impact broadcast and effect presentation remain visible. Full
audio/projectile/event lifecycle and every authored effect are not complete.
Class/feat radial submenus, NWScript ActionUseFeat and other spell/effect owners
remain open. Combat and a continuous base campaign playthrough are not accepted.

## Validation

All1580 tests pass (`feat-casting-full-tests-v2.txt`); production build passes
with the existing chunk-size warning (`feat-casting-build-v2.txt`). Actual feat
UI passes (`feat-casting-ui-v1.txt`, `live-feat-casting-ui.json/png`). Existing
ordinary casting UI regression passes (`feat-existing-casting-ui-v2.txt`),
including book/radial/F2 consumption, targeting/cancellation and counterspell.
The first restricted-sandbox UI attempt failed to launch its renderer and is
retained as v1; the outside-sandbox run passes. Innate UI regression is recorded
in `feat-existing-innate-ui-v1.txt` and passes. Known absent plc_w02.pwk is
retained explicitly when encountered,
and is not silently counted as clean whole-area loading.
