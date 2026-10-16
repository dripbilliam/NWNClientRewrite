# Native item spell requests

The request-only execution omission recorded below is now superseded by
[item execution and lifecycle evidence](item-cast-execution.md). Action46 and
decoded player input9 are connected; wheel/hotbar item selection remains open.

Target NWN:EE89.8193.37-17 x64, original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only Ghidra and hash-verified complete PE instruction captures were used.
Original game files and Ghidra project remain unchanged.

`item_cast_request.js` ports complete UseItem1403a9f70..1403aa20c and
AddItemCastSpellActions14037f030..14037f936. The second owner's actual exported
name is AddItemCastSpellActions; earlier research called it AddUseItemActions.
Neither is a replacement for AIActionItemCastSpell1403c07b0.

UseItem resolves item and target before ownership checks. One parent bag level
and compiled associate types7/8 are accepted. CanUseItem runs with identification
required. The active index is BYTE narrowed; GetActiveProperty itself uses INT
bounds1404686d0. Property15 checks remaining readiness and target perception.
The native perception rejection returns2 (DAT140df04e0), not a boolean. Active
base metadata EquipableSlots+4 is read even for the compiled exception bases;
outside those exceptions a nonzero slot mask requires actual equipment and
feedback244 otherwise. The field mapping was confirmed at14029e36e..14029e3c0.
Property55/80 route to skill9/4;70 routes to AddTrapActions29 with the canonical
item ID from its native object subobject+50. Constructor140462ecd initializes
the CNWSObject subobject at+48. These branches do not become spell casts.

AddItemCastSpellActions preserves native target/override ordering, PC/possessed
polymorph gates, DM bypass, target/carried-item area and perception checks,
active iprp_spells SpellIndex, commandability, range and physical queue records.
The original point is saved before the caller's vector is overwritten by a
resolved target. Both outputs are compared. Appended actions are17/18 (range),
19/49 (facing),16 (round wait) or30 with native1.0 seconds for bases49/104,
and46 with ten typed parameters. GroupFFFF/FFFE and the shared native group
allocator remain intact. The final flag normalizes to nonzero/zero and controls
resource consumption in the executor. Older oracle JSON calls this field
`automatic`; the product calls it `consume`, following its actual branch use.

NativeItemRuntime now adapts these requests to canonical objects, equipment,
perception, active tables, ComputeSpellRange, movement and action queues.
ModuleSession.itemUseProviders shares CanUseItem providers with talent selection,
including scroll schools, identification and the native ILR setting. Enabled
ILR pricing/minimum-level computation is still explicit. Trap placement and
non-pickpocket admitted skill owners also remain explicit omissions.

## Verification and outstanding execution

`inspect-native-item-cast-request.py` executes4575 full UseItem and661 full
AddItemCastSpellActions cases. It compares results, call order, target fields,
caller vector mutation and every typed action parameter. Registry/casts,
CanUseItem, properties/tables/spells, visibility, equipment, range, movement,
queue allocation and lower skill/trap owners are captured boundaries. This is
not native action46 execution, projectile/effect rendering or charge acceptance.

An unchanged installed wizard's actual potion570/property0/spell31 passes
typed ActionUseTalentOnObject ->UseItem ->AddItemCastSpellActions. Native
17/19/30/46 records queue, resource parameters identify that actual item and
class/innate pools and charges/stack/property readiness stay unchanged at the
request stage. Continuing the actual action loop explicitly reports
`Native live action 46 dispatch is not implemented`, which the probe asserts
and retains. It does not simulate an impact or spend charges to hide that
missing executor. Report: `installed-item-cast-request-v2.json`. No grants,
inventory substitutions or original asset writes occur. This is request-stage
acceptance only; item/scroll casting is not yet playable.

All1596 tests pass (`item-cast-request-full-tests-v2.txt`); production build passes
with the existing chunk-size warning (`item-cast-request-build-v2.txt`). The
earlier1594-test talent checkpoint and existing innate UI regression remain
separate. New code does not yet bind the item quickbar/world item UI. The active
spell dependency audit remains90 unbound names/22 missing NCS (v32); binding
presence does not prove all branches.

Next: full AIActionItemCastSpell46 lifecycle, resource count/consumption/cache
owners and delayed item destruction, then decoded player item input and native
item/scroll target menus/hotbar. Full execution instructions are captured in
`native-item-cast-action-v1.txt`; Ghidra truncates at free(NULL) and is not a
complete decompilation. Goal ACTIVE; spells, combat and campaign remain open.
