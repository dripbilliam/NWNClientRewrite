# Inventory input, pages and item containers

Target: NWN:EE89.8193.37-17 x64, original nwmain.exe SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original installation and Ghidra database remain unchanged.

## Original owners and runtime connections

`inventory_input.js` maps full HandlePlayerToServerGuiInventoryMessage
140451db0..452025. Subtype1 reads raw BOOL and character OBJECT_ID, checks
overflow/underflow, fetches the controlled object twice, and routes to primary
for self/INVALID or alternate otherwise. Alternate SetOpen occurs before
SetOwner; close resets that alternate character ID to INVALID. Subtype2 reads
BYTE page and raw BOOL selecting primary(nonzero)/alternate(zero); unknown
subtypes are accepted. This is decoded input, not packet codec parity.

SetOwner1404beab0 looks up both old/new creatures before clearing the old weight
dirty flag, setting the new flag and updating encumbrance, then commits owner ID.
Same ID skips those calls. SetPanel1404beb40 fetches client54's object twice,
performs its creature cast, uses repository BYTE dimensions/unsigned boundary,
compares against the LOW BYTE of the page count and clears LUO list90 only when
changing to a valid page. Live session inputs and unequip page selection now
use these owners; alternate unequip GUI routing is available.

`item_inventory.js` maps full item OpenInventory14046ad80..46afa5 and
CloseInventory140465f80..466136. Active BaseItem.Container nonzero gates both.
Open selects alternate only if possessor differs from player AND matches that
alternate character; otherwise primary. Reopen skips observer increments. Old
item/placeable close precedes owner setter/SetOpen/message. Observer transitions
zero→one and one→zero enqueue event10 payload22/23. GUI mismatch returns before
decrement. Closing an alternate container with retained field4 still calls
SetOpen on PRIMARY, as the original does. These are deliberately separate from
placeable inventory animation/callback behavior.

Full item EventHandler140466f70..467fdb has no event10 branch: bag22/23 payloads
are ignored. The live dispatcher now honors that. Constructor140462f85 zeros
item observer364. UseObject, retained-GUI closure, movement closure, scheduled
open-item destruction and client enumeration now use the concrete item owners.
Canonical repository/item IDs and recursive destruction are preserved.

## Installed failure and HP correction

The first installed bag action failed with `Native life-state HP provider is
unavailable`. Item targets had no common object HP views. Verified common
constructor14048ba08/12 writes baseE0=1/maxE4=1/tempE8=0 in the item subobject+48.
The item's object vtable140ded448 points to GetCurrent140495130 at140ded580;
exact flag1 returns base WORD, other flags return base+temp WORD. GetMax140420350
returns maxE4 WORD. Signed SHORT query interpretation is preserved. Runtime
items now own these cells and participate in ordinary life checks/NWScript HP
queries. No item-specific life-check bypass or stock-template HP constant was
added. Other effect/HP mutation owners remain separately gated.

## Verification and boundaries

`inspect-native-inventory-input.py`: full original228 input,24 character-owner,
294 page cases =546 observations. `inventory-input-native.test.js`:3 tests.
`inspect-native-item-inventory.py`:979 open,576 close,6 full event10 and160 HP
cases =1,721 observations;4 tests in item-inventory-native.test.js. Final
item-inventory-native-v3.txt explicitly places event caller in R8 and payload
in R9 according to the prologue/signature; earlier captures did not correctly
populate those unused event10 operands. Both full original event10 traces
return without payload effects. Final combined7 tests pass.

Installed inventory-input probe passes normal pending-input drain, raw open
flags, primary/alternate page changes, invalid-page cache retention, placeable
observer closure/cache reset/B8 retention, callback caller and absent alternate
owner routing. Explicit primary SetOwner is fixture setup: native login's
primary-owner initialization remains unmapped, and no substitute initialization
is silently installed. `installed-inventory-input-v1.json`, final
inventory-input-installed-v2.txt. Installed item probe dynamically selects active
UTI nw_it_contain001, creates canonical bag574 for player565 and passes native
UseObject open/close/reopen, repeated-open count, ignored item events, scheduled
DestroyObject while open and repository cleanup. Failed v1 retained; v2 passes.
Startup/AI disabled; all diagnostics retained and no new errors.

All1,694 tests pass and build succeeds with existing chunk warning:
item-inventory-full-tests-v1.txt/item-inventory-build-v1.txt. Rendered right-click
Use/action40/NCS/body-bag/pick/revisit regression passes:
item-inventory-body-bag-ui-v1.txt/live-body-bag-ui.json/.png. All owned processes
finished normally. The test's preview sun is inspection setup, not native lighting.

Actual container-window content, pickup requests, item shortcut default/equipment
activation, native primary-owner login path and original client sender flags are
still unfinished. No rendered item-bag window or campaign looting claim.
GuiContainerMessage140451810 is a separate owner; its decompile was captured
without claiming implementation. EvaluateLock/FailedOpen/trap26/corpse equipment
broadcast remain explicit unsupported. Full spell/combat/campaign goal ACTIVE.
