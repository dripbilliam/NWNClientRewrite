# Shared item-property construction

Continuation: Add/Remove and repository-item lifetimes now have implemented
paths. [Mutation evidence and remaining equipped owners](item-property-mutation.md).
Unbound mutation references below describe this factory checkpoint historically.

Target NWN:EE `89.8193.37-17`, original nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra and instruction captures remain read-only. No binary/asset copies,
Ghidra edits, injection or actual network traffic.

## Gameplay dependency and implementation

The current spell audit still finds AddItemProperty/RemoveItemProperty unbound.
These are shared dependencies of weapon buffs, rage and other authored spell
scripts. Their constructors are prerequisites. This pass implements the
shared native constructor; it does not claim item mutation is finished.

`src/item_property_factory.js` decodes ExecuteCommandItemPropertyEffect
1405338c0..140534ae3, with the complete return/cleanup path. Native argument
selection becomes engine property layouts, not spell-specific replacements.
Type91 starts with nine negative-one integers, integer7=100, integer8=1,
permanent duration2 and the actual caller creator. Active ITEMPROPDEF,
subtype, cost and parameter tables determine validation. Invalid inputs keep
the native effect storage but set type0. The returned value remains an engine
structure and uses existing uint64 effect identity, separate from object IDs.

The decoded branches include alignment limits, conditional on-hit subtype
layouts, spell-on-hit value decrement, unlimited-ammo subtype0 and custom
properties. Full assembly resolves misleading register aliases in Ghidra's
pseudocode. Actual argument-array stores occur at140533d31 and140534051;
other apparent local argument assignments are register reuse. Negative-argument
checks therefore use the original argument cells except these two decrements.
No invalid property is upgraded into an invented valid value.

Validation preserves query status versus output value, query order, null cache
behavior and bounds. Nonzero CostTableResRef status writes integer2. Subtype
and cost Name cells require successful nonzero INT values. A cost cache miss
invalidates a specified cost value; absent optional subtype/parameter tables
follow the original skip paths. Parameter-table resolution can fall back
through the selected subtype. Custom negative-one checks retain their distinct
conditions, including the positive cost-table-index requirement.

`NativeItemRuntime.propertyFactoryProviders()` supplies current active tables,
existing INT/CString conversions and diagnosed resource loads. Cost accessor
1402b38a0 rejects ID0 and IDs >= the BYTE cache count. Loader1402ba03c..040
stores the physical IPRP_COSTTABLE count as BYTE; altered tables retain that
narrowing. This binding follows the server cache path, not client-only loading.

`bindItemPropertyFactory` binds supported engine ordinals to names and arities
from the installed NWScript API during ModuleSession initialization. The static
spell audit performs the same binding. All79 installed constructors bind;
none of their names remain in the unbound-command list.

## Original execution and installed data

`inspect-native-item-property-factory.py` executes the complete unchanged
original command.1,262 cases compare final type/duration/integers and ordered
table queries, including mixed negative arguments, unknown selectors, bounds,
missing tables, zero Name values and custom-property sentinels. VM pops,
effect construction/storage/creator, allocation, table lookups and structure
push/destruction are explicit captured boundaries. This establishes the
constructor selector and validation, not every lower owner.

`probe-live-item-property-factory.mjs` initializes the ordinary installed
Prelude session and checks each of79 constructor bindings with its installed
API arity and three argument sets:237 cases,176 valid and61 invalid. Active
query values and row counts are recorded as read-only inputs.
`inspect-live-item-property-factory.py` runs the original command on those same
inputs. All237 outputs and query sequences match. Resource/table parsing is a
captured boundary in this cross-check; it is not a second native table parser.

Reports in backups/animations:

- native-item-property-factory-v2.txt and corresponding observation JSON.
- live-item-property-factory-v1.txt/live-item-property-factory.json.
- native-live-item-property-factory-v1.txt and corresponding observation JSON.
- native-item-property-constructor-remove-asm.txt and
  ghidra-item-property-constructor.txt; cost accessor/load assembly captures.

The refreshed static spell audit-v18 still loads596 of618 impact scripts
for840 spell rows. Unbound command names decrease160 to112;48 referenced
constructor names are now bound. All22 script-resource failures remain
recorded. Binding presence is not proof that a spell runs through completion.

## Validation and next owners

1,425 tests pass, build passes (item-property-factory-all-tests-v2.txt and
build-v2.txt). Rendered item-property-factory-transfer-ui-v1 passes radial
summoning, real slot consumption, Follow/Stand, out/back canonical summon576/
master565 and dismissal. Latest screenshot inspected; scene remains dark and
DoSinglePlayerAutoSave remains visibly diagnosed. Original hash unchanged.

Next required work is item mutation/propagation/expiry, before more protocol
helpers. Captured complete commands: AddItemProperty14050fb00..14050fd56 and
RemoveItemProperty14053b4a0..14053b627 in native-item-property-mutation-asm.txt;
Ghidra command captures are named by address. Application owner14042e5c0..
14042e971 already has a decoded pool/materialization front half, but the
runtime's possessed-item propagation currently throws. EffectRuntime does
not yet admit type91. Removal owner1404373c0..14043776b is fully captured in
native-item-property-constructor-remove-asm.txt and Ghidra removal capture.

Add accepts only duration1/2, preserves the native WORD duration flags, then
applies to an admitted item. Its permanent ILR branch includes native spell419;
that native branch must be reproduced rather than generalized away. Remove
matches uint64 effect IDs across the live pool, clears exposure DWORD20 and schedules
event14 for the last matching pointer; it is not immediate arbitrary property
deletion. DAT140dfc158=14 is captured. Existing event14 dispatch already reaches
EffectRuntime.remove for items. OnRemoveItemProperty removes the first matching
active/passive property by narrowed values/duration, with distinct active-use
and passive equipment/weight callbacks. Native OnItemPropertyApplied140559490
and corresponding removal dispatch still need their complete materialization
owners; do not substitute the older equipment projection as parity evidence.

The entire spell/combat/campaign goal remains active. Client area receiver/
ready work, autosave and continuous base-campaign acceptance are still open.
Verified backup report:backups/animations/item-property-factory-checkpoint-v2.txt.
