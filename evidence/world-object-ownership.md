# World inventory ownership and destruction

Target: NWN:EE89.8193.37-17, original read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original install or Ghidra database edits.

## Verified implementation

`world_object_state.js` maps full placeable/store/waypoint constructor ownership
at1404af9c0/1404f9a70/140508d60. The base canonical ID precedes repositories;
placeables register AI before their7x5/boundary35/expand1 repository, stores
create five10x10/boundary100 repositories before AI, waypoints do not register
AI. Requested INVALID sets placeable static-load override5a4=1. Base area
constructor48ba30 copies INVALID from140dc2a50 and position starts zero.
HasInventory4f8 is load-owned, not initialized by the placeable constructor.
The qword504 zero initialization includes open-observer count508.

Placeable inventory loading now follows1404b647e..65f3: canonical item allocation
before load, Item::LoadFromGff last flag0, WORD coordinates narrowed to BYTE,
AcquireItem(sourceINVALID,feedback1), failed-load destruction and tag ownership.
HasInventory does not gate the authored ItemList load. HasInventory/DieWhenEmpty
use native BYTEasBOOL defaults0 at4b50b9/4b52a2.

`item_acquisition.js` maps full placeable AcquireItem1404b11d0 and
RemoveItem1404b69d0. Source equality, old-owner removal before destination-null
checking, exact Container1, ignored repository AddItem result, pointer merging,
SetPossessor and exact membership1 are preserved. CreateItemOnObject uses this
path. Repository child deletion and failed creation use the lifecycle destructor,
rather than registry-only deletion.

`object_destruction.js` maps full placeable/store/waypoint destructor ordering
at1404afd70/1404f9c20/140508dd0. Children precede placeable area/collision removal;
stores own five repositories and reverse live client records; waypoints do not
remove AI. Concrete cleanup removes canonical registry, source/tag, AI, spatial,
trap and collision snapshot ownership. Direct destruction and scheduled event11
remain distinct owners.

`world_destroy_event.js` maps event11 branches1404b3898..38cb,
140509c32..9c62,1404fb4ca..b50f. Waypoints alone test destroyable!=0;
placeables close inventory then spawn loot before removal/deletion; stores clear
area while retaining XYZ. Dispatcher now reaches those paths. Full placeable
CloseInventory1404b1fa0 and direct GetItemCount1404b3db0 are independently ported.
CloseInventory captures enumeration bounds, rereads current client/owner, uses
nonzero gates, decrements even for an absent current client, and queues23/event10
plus animation76 only at count1. Placeable vtable140df32f0+100 resolves to
common SetAnimation14049abc0 (direct DWORD d8 write), not creature remapping.

## Independent original-code checks

- `inspect-native-world-object-ownership.py`:408 full constructor/destructor
  cases, real ItemRepository ctor executed; lower base/AI/area/GUI/string/memory
  owners captured. Authoritative `world-object-ownership-native-v2.txt`.
- `inspect-native-placeable-acquisition.py`:615 full acquisition/removal cases,
  source types, BYTE coordinates, null repositories, add/merge pointer changes,
  exact container/membership and nonzero clear flags. Final
  `placeable-acquisition-native-v2.txt`; v1 fixture failure retained.
- `inspect-native-world-destroy-events.py`:96 event branches,480 full inventory
  close calls,96 full item counts. Area/GUI/body-bag/destructor are captured
  boundaries. Final `world-destroy-events-native-v1.txt`.
- Six comparison tests cover all1,695 observations. Initial comparison test
  had only an incorrect expected fixture count960 (actual480); v2 passes.

Research captures: `native-world-blueprint-load-owners-v1.txt`,
`native-world-inventory-acquisition-v1.txt`,
`native-placeable-item-removal-v1.txt`,
`native-world-destroy-events-v2.txt`, `native-store-destroy-event-v1.txt`,
`native-world-destroy-close-owners-v1.txt`,
`native-placeable-close-gui-owners-v1.txt`,
`native-world-animation-vtable-v1.txt`, `native-world-set-animation-v2.txt`.
An early capture queried an unverified table140df0ce8; that table is discarded
as evidence. Only verified event global140dfc174=11 is used. Animation v1
reported no unwind; v2 decodes the verified vtable leaf to its return.

## Installed integration and current limits

The following body-bag gap was subsequently resolved for populated placeables;
see [body-bag lifecycle](body-bag-lifecycle.md) for the concrete spawn/load/
transfer/area/render integration and remaining creature/GUI limits. The historical
ownership checks below predate that integration.

`probe-installed-world-ownership.mjs` passes against Prelude m0q1a/m0q1d with
installed wizard BIC. Seven populated placeable inventories use canonical IDs,
correct repository parameters and script enumeration order. Installed active UTI
`x3_harathide` creates item574 on placeable16, transfers unchanged ID to17,
then DestroyObject removes it from repo/registry/tag. Direct destructor removes
placeable52 and child53 with collision slot0, spatial/trap/AI/tag ownership;
ID allocation cursors do not rewind. Scheduled destruction removes empty
placeable3 even when destroyable0; waypoint25 survives0 and deletes with1.
Player565 remains the same record. No new error diagnostics. AI/startup disabled,
load diagnostics retained. Final `world-ownership-installed-v3.txt` and
`installed-world-ownership-v1.json`; earlier fixture setup failures retained.
Placement regression also passes with updated ownership:
`world-ownership-placement-installed-v1.txt`/`installed-world-ownership-placement-v1.json`.

All1,671 tests and production build pass (`world-ownership-full-tests-v2.txt`,
`world-ownership-build-v1.txt`, existing chunk warning). Rendered polymorph
wheel/cast/prepared-slot/form rebind/restore regression passes
(`world-ownership-polymorph-ui-v1.txt`). The restored screenshot remains wall
occluded with overbright FX; no visual parity claim.

Body-bag spawn14049c170 calls LoadBodyBag1404b4080 and transfer1404b1350,
then delayed area event17/1000ms. This is loot generation, not conversation
cleanup. Empty/no-area placeables correctly short-circuit; populated scheduled
placeables still diagnose the missing full lower owner before deleting loot.
GUI list cleanup1404be9a0/1404be930 remains explicitly diagnosed for live open
inventory. Store loaded inventory/GUI closure remains incomplete and guarded;
constructor repositories are not sufficient evidence of store import parity.
Store count/pricing/category ordering and nested StoreList need their own port.
Creature death/corpse scheduling, CopyItem, body-bag population/area insertion,
concrete CreateObject243 UTP/UTW/UTM loaders, presentation and installed authored
creation remain outstanding. Entire spell/combat/campaign objective stays active.
