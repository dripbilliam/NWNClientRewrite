# Polymorph form ownership — 2026-10-15

Target NWN:EE89.8193.37-17, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project unchanged. Full assembly and derived
observations remain under ignored `backups/animations`.

`src/polymorph_form.js` ports the full coordinators Polymorph140399e20 and
UnPolymorph1403a5b50. Existing9f4 is area-event suppression;97c is the equipment
lock;9f8 is cancellation lock. Saved980/a00 arrays each hold18 canonical item
IDs. Active physical polymorph.2da supplies appearance, portrait, sound, race,
STR/CON/DEX, naturalAC, temporaryHP, equipment resources and spell overrides.
Existing stats/equipment/property/effect/racial/area owners are shared. Shape
items use the canonical object array and are destroyed on reversal; original
item instances are restored. A successful Equipped query suppresses all three
CreatureWeapon queries even on template failure. Original index comparisons
against ammo flags never match0..17 and are preserved, not reinterpreted.

CORRECTION to an earlier resume note:14039e6b0 is RemoveFromArea(actor,1), NOT
ResetUpdateTimes. Transform searches with native float20.0, copies the final
destination, removes/re-adds through existing native lifecycle with9f4 active.
Restoration only searches/repositions. Local completed enterArea now mirrors
the same4f4/4f8 pending area/destination cells, preventing a false ClientArea
request during a same-area form change. IDs/spatial membership/player count
and attached effects use existing shared owners. UpdateAppearanceDependantInfo
1403a69f0 now lives in src/appearance_info.js, including failed-query outputs,
weapon scale fallback1 and dirty53c, and is shared by import/form changes.

Renderer observes canonical appearance and live equipment. Asynchronous model/
part/texture loading replaces children inside the SAME wrapper and rebinds
animations after removing obsolete clips. Results for a superseded form/area/
object are rejected. Player/controller/registry identity stays stable. Failed
loads remain diagnosed. Root authored Equip_ItemList is not reused as live armor.

Cancellation is Input30, not UseFeat289. Feat289 is creature-weapon proficiency.
Self radial14098ec00 gateclient408!=0/40c==0 offers slot4IR_SKILLSELFtooltip2050.
Callback9960c0 ->804cc0 ->7bf460 emits message6/subtype30/OBJECT_ID. Server
455373..45541e resolves that creature, guards8ac/9f8, removes FIRST type62 ID
group; no extra dead/commandable/feat gate. Local input FIFO delivers this decoded
request. Shared removal retains parent exactly500ms, restores strictly afterward.

Four shared materializers added: FreeAction75/140470c90 (independent22 immunity
effects6/9/10/24); Skill52/1404726d0 (55, zero returns before construction);
Reduction22/14046f540 (12, cost6Amount, selector+1); Resistance23/14046f6a0 (2,
cost7Amount, native WORD/shift arithmetic). Constructors, query order and both
ApplyEffect flags retain native behavior. No per-spell/form template overrides.

Evidence:1037 original transform/restore coordinator cases compare saved cells
and captured call order;984 materializer cases execute original effect ctor/
SetInteger;144 original decoded-cancel cases compare guards/selection. Lower
combat queries, item/equipment/effect/area/string/allocator operations are
captured in those fixtures, not a full native spell or live-process parity claim.
Five installed forms3/0/1/2/4 pass actual shared runtime transform/cancel/500ms
retention/501ms restoration, preserving SAME root/stats/equipment/player and
original item instances, destroying shape IDs, leaving one player entry/count1.
Full1569 tests and build pass.

Isolated rendered UI smoke FINALv4 passes real self radial ->Cast ->Wizard ->
Level4 ->PolymorphSelf ->GiantSpider387, normal casting pipeline and prepared
parent130 consumption, live appearance1/pme0 ->159/c_SpidGiant ->1/pme0 and
radial cancellation. Object565 remains controlled throughout. The owned wizard
fixture replaces known/prepared127 with same-level130 in memory; installed BIC
is untouched. All load diagnostics retained (baseline DM-preset import rejection);
casting-phase errors and console errors0. Existing standard UI regression also
passes spellbook, self radial, slot use, F2 targeting/cancel and counterspell.
Screens retain known wall/camera occlusion; this is no full visual-parity claim.
Polymorph smoke assigns parent130 toF2 but does not activate it: native parent/
child selection from book/hotbar still needs checking. Startup/entry fixtures
remain separate from continuous campaign acceptance.

Open: native full combat d70 cache is not represented. Saved a48 is explicitly
labelled combat-projection and diagnosed, not claimed as native CCombatInformation
copy; restoration never consumes it. Broad107-form probe stops after five at
TrueSeeing property71/140472cb0. Derived active coverage lists25 property types
across103 templates and missing installed x1_it_frostghide; no assets copied.
TemporaryHP/stat feedback/icons and other lower owners remain diagnosed. Native
networking/saved-GFF polymorph import, full spells/combat/campaign are unfinished.
