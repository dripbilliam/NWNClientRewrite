# Casting actions and script context

This is the1211 checkpoint. The1225 metadata/admission/caster/travel continuation
is recorded in [Casting metadata and projectiles](casting-metadata-projectiles.md).

Target: NWN:EE `89.8193.37-17`; read-only original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original installation or Ghidra project changes. Ghidra's HTTP service was
unavailable after reboot; verified PE instructions and retained listings were
used. No agents or formal goal were created.

Sealed checkpoint: `backups/live-native-casting-actions-1211-20261014.zip`,
3833 files,23082767 bytes; every manifest entry's length/SHA256 verified.
The archive contains source, captures and these notes before this bookkeeping
backlink was added. Prior1194 spellbook checkpoint remains retained.

**Casting remains unavailable in gameplay.** Action15 and the command-cast
coordinator are not connected to live execution. The UI records its placeholder.

## Live owners

RunActions1404ac010's61-entry table1404ad2cc proves the prior dispatcher
misrouted action19 to interarea pathfinding:

|Action|Jump-table destination / callee|Current behavior|
|---|---|---|
|4|1404ac5c5 /1403b1dc0|Interarea path check; route-advancement dependencies remain explicit|
|19|1404ac665 /1403b0510|Face canonical object on native horizontal XY|
|49|1404ac615 /1403b0d70|Face stored point on native horizontal XY|
|16|1403cf7e0|Wait for current round unless any spell action is due|

Facing uses exact-one life flags, type/area gates, float threshold0.0001 and
native normalization arithmetic. It preserves route allocations. Trigger
ctor1404febc2/1404febc9 zeroes four cached bounds; GetFacingPosition140501780
derives their polygon midpoint and area height. The live asynchronous height
provider is awaited. Empty polygons are diagnosed and their action is retained.

`initializeSpellContext` maps CNWSObject ctor14048bab9..14048bb24 stores.
Current spell+218, last received spell+234 and saving-throw spell+184 remain
distinct. GetSpellId, GetSpellFeatId, GetSpellCastSpontaneously,
GetLastSpellCaster, GetLastSpell and GetLastSpellHarmful are live. History
permits types5/9/10; feat IDs use signed WORD conversion. Missing fields fail.
Projectile time+220 has no constructor initializer here and is not guessed.

## Pure owners awaiting live casting

`spell_queue.js` maps AddCastSpellActions14037d540's twelve typed parameters,
FFFF/FFFE groups, front/tail order, visibility/uses/carried-item gates and
movement/check/turn/wait/cast sequencing. Request position is copied before
target lookup changes the reference position. ComputeSpellRange140388d20
uses five physical active Ranges rows plus each creature's personal space
minus0.1. The existing rules loader already loads Ranges.2da; the spell range
cache is not attached to live cast requests yet.

`spell_cast_action.js` maps ordinary AIActionCastSpell1403ada70 timing,
Quicken/haste, animation state selection, release LOS, consumption guard,
projectile calculation, impact guard and cleanup. Required lower providers
are not implemented by the synthetic capture fixtures. Special feat,
counterspell, spontaneous, concentration and automatic-metamagic paths remain
unavailable. Helper14048fe20 is projectile timing, not a class-context setter;
class254 is preserved.

`spell_round.js` maps StartCombatRoundCast14037a000 and
RemoveSpellAction140378f80. Start sets started/paused, subtracts signed
overlap/bleed into an unsigned length, clears all prior actions and inserts
the constructor-initialized type2 entry. +2f20 is pausedBy; +2f24 pauseTimer.
Cleanup removes every BYTE type2, including future entries. These cores await
the live cast coordinator.

## Original executions and validation limits

|Capture script|Cases|Captured lower boundaries|
|---|---:|---|
|inspect-native-spell-queue.py|369|157 queue,54 wait,66 range,92 facing; original normalization executes; rule/lookup/append helpers captured|
|inspect-native-cast-action.py|109|Ordinary timing; lower eligibility/time/LOS/round/presentation/projectile/impact captured|
|inspect-native-casting-support.py|165|30 trigger,128 start,7 removal; height/list storage/allocation captured|
|inspect-native-spell-context.py|403|Constructor stores/six scalar commands; lookup/casts/VM push captured;6 push failures retained|
|inspect-native-empty-region.py|864|Empty graph return status; original wrapper rotation executes; indeterminate output is never consumed/compared|

These1910 executions supplement the earlier spellbook/request captures. They
do not prove an original end-to-end cast, authored spell effects or networking.
Capture JSONs are included in the checkpoint allowlist.

`casting-actions-full-suite-v2.txt`:1211/1211 tests.
`casting-actions-build-v2.txt`: successful build, existing bundle-size advisory.
`casting-actions-combat-regression-v3.txt`: passes retaliation, approach,
kills and encounter deactivation under concurrent suite/build load. Missing
installed resourcesplc_w02/script1 and six omitted readiness owners remain:
trap check, stat refresh, corpse lifecycle, automap, achievements and voice.
This is local integration, not combat/campaign readiness acceptance.

Failed facing integration, round-offset comparison and earlier campaign runs
remain captured. The facing test's clock/budget expectation and the test's
reversed pausedBy/pauseTimer ordering were corrected against original evidence.

## Observed path failure and correction

Earlier concurrent regression failed on tile[8,11], path kind84, region0,
zero region count. Full context/stack is retained in
`casting-context-combat-regression-v1.txt`.

Surface1402becb7 returns0; tile wrapper1404fdbdb rotates uninitialized local
scratch. InterTileDFSGenerateSuccessors14036d560 makes two extra region
queries whose output is ignored. The replacement had thrown for those
discarded outputs, aborting movement. Ignored failed output is now null and
recorded as `geometry.native-region-query-failed` at info severity. Required
coordinates still throw; negative/missing/unloaded data is not hidden. This
is an original status/unused-output correction, not an area/path-kind exception.

## Next owners

Active casting metadata and admission/components/release failures; caster
level/save DC/target context; projectile14048fe20; impact14049c4b0/authored
ImpactScript/effects/scheduler; live requests/actions15/18, consumption,
interruptions and renderer animation bindings; authored cast regression.
The projectile scalar140c946b0 requires accurate mapping: do not mistake it
for RNG or substitute guessed travel speed. Counterspell/spontaneous/feat/epic
casts, concentration, dirty refresh and original/network acceptance remain open.
