# Inventory GUI state and observer ownership

Target: NWN:EE89.8193.37-17, read-only original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No Ghidra database, original executable or asset changes.

## Original owners

`inventory_gui.js` ports CNWSPlayerLUOInventory ctor1404c1d50 and
InventoryGUI ctor1404b7bf0. Eighteen cached object IDs and companion fields,
four distinct lists90/A0/B0/B8, last ID98 and dirtyA8 are represented.
Uninitialized C0/C4 cells are not invented. Constructor object IDs use native
INVALID; companion fields start-1. The local client now represents both primary
and alternate GUIs with independent state.

ResetEquipment1404c2dc0 writes all18 ID/field pairs. ClearList1404c2d80/2b00
release list90/B0 entries in live head order. ClearList1404c2b40 releases A0 and
sets dirtyA8=1, including empty lists. SetOpen1404be9a0 retains B8, character
ownerId10 and fieldC; a raw flag assignment would miss these distinctions.
Only requested0 with a previously nonzero GUI flag resets storage. Exact
notification1 looks up a previous valid container and calls item/placeable
CloseInventory(...,0); other notification integers do not. Container owner state
is cleared after that callback, then A0 and the requested flag are written.

SetOpenInventory1404be930 clears the matching GUI's A0 list when changing ID.
Primary wins if both primary/alternate IDs match the previous ID, including when
the supplied owner record belongs to alternate. Same-ID assignments do not clear
updates. It writes raw field4 and clears byte8. It does not change the separate
character inventory ownerId10.

Placeable OpenInventory1404b6720 gates on nonzero HasInventory and returns early
if this client already holds the same container ID. A previous item/placeable
owner closes with flag0 before replacement. New GUI open-state determines the
container field4; opening within an already open character inventory sets it0.
Missing clients still increment the observer count. The first observer queues
OnOpen event22 and animation75; later observers do not.

Per-player CloseInventory1404b1e10 gates on HasInventory/count!=0. Close flag0
skips client lookup. A found client with a different current container returns
without decrement. Missing clients still decrement. Count1 queues OnClosed23 and
animation76. A container opened within an existing inventory (field4=0) clears
its owner without closing that existing inventory. Whole-placeable closure
1404b1fa0 remains the independently ported enumeration owner.

Original switch tables1404b3b4c/3b0c map22/23 to1404b32f1/3302. They write
caller fields520/524 then RunEventScript8/0 with flag0. The runtime now delivers
these callbacks with canonical caller IDs and GetLastOpenedBy/GetLastClosedBy
state, independent of current observer count. Internal payloads use the existing
CServerEvent `type` field; an earlier new coordinator used `scriptEvent`, which
was corrected before this integration (trace tests also use type now).

## Integration and independent validation

Lifecycle providers now use real GUI/LUO owners for whole-placeable closure,
per-player open/close and associate inventory closure. Native SetOpen retains
fieldC; the old associate provider incorrectly assigned it the notify argument.
Placeable closure is supplied to the movement panel-cleanup coordinator. Item
container closure140465f80 remains explicitly unavailable, rather than silently
using placeable semantics. GUI transport uses the existing local internal
callback; this is not native packet/PLAYER_ID replication evidence.

`inspect-native-inventory-gui.py` executes full original owners and bounded
post-dispatch observer branches. Linked-list removal/free, old-owner closure,
client/message lookup, scheduler and animation are captured boundaries. Two
constructors,288 owner setters,864 SetOpen calls,648 placeable opens,432 closes
and8 observer branches (2,242 cases) match six comparison tests. Final
`inventory-gui-native-v2.txt`, `native-inventory-gui-observations.json`,
`inventory-gui-tests-v2.txt`. Synthetic GUI/owner cases include nonboolean flags,
canonical external IDs, primary/alternate precedence, null client, old lookup
failure, empty/populated lists and raw observer counts. General allocation
failure/alternate remote-client synchronization remain outside this fixture.

Captures: `native-loot-inventory-action-owners-v1.txt`,
`native-inventory-gui-constructors-v1.txt`,
`native-inventory-gui-luo-reset-owners-v2.txt`,
`native-placeable-close-gui-owners-v1.txt`,
`native-placeable-script-event-map-v1.txt`. The first reset capture reported a
missing unwind entry; v2 uses verified call-target leaf decoding to returns.

Installed `probe-installed-inventory-gui.mjs` passes Prelude canonical player565
and placeables16/17. Actual lifecycle entry uses the new GUI providers, scheduler
and normal NWScript VM with in-memory OnOpen/OnClosed marker scripts. It checks
first-open/reopen, last-close, callback object IDs, all18 cache pairs and three
lists cleared/B8 retained, switching containers with event order23 then22,
existing-main-inventory preservation, and destroying an open placeable. No new
error diagnostics; all load warnings retained. Direct lifecycle entry, AI/startup
disabled; this is not a rendered looting/input acceptance claim.
`inventory-gui-installed-v1.txt`/`installed-inventory-gui-v1.json`.

All1680 tests pass (`inventory-gui-full-tests-v1.txt`) and production build
passes with existing chunk warning (`inventory-gui-build-v1.txt`). Rendered
right-click/NCS/body-bag/pick/revisit and summoning/associate dismissal regressions
pass (`inventory-gui-body-bag-ui-v1.txt`, `inventory-gui-summoning-ui-v1.txt`).
All processes finished normally.

## Next owner boundary

Player looting is still unfinished. The legacy placeable interaction queue
requires OnUsed; it must be replaced by the native action40 UseObject request,
execution, movement/range/lock/trap/corpse rules, wait and cancellation owners.
The complete original AIActionUseObject1404a9790..4aa8c3 and AddUseObjectAction
1404ab5b0 are captured in native-loot-inventory-action-owners-v1.txt; no native
action40 executor is connected yet. Full GUI content presentation/pickup and
item container owners also remain. Concrete GUI ownership is a prerequisite,
not a substitute for those action and UI paths.

Useful verified downstream branches: the event constructor at4aa7cd queues OnUsed
event25, which switch25 maps to4b33f9 (Useable264 gate, caller528,
RunEventScript12). Event24 is disarm, not OnUsed. Successful UseObject writes
node state48=1, waits for server timer+500ms at4aa894..8b7. Inventory-path
Open/Close calls occur4aa529..79b. Do not bypass these with an unconditional
OnUsed script or call OpenInventory immediately from every wheel click.

Full spells/combat/continuous campaign goal remains active.
