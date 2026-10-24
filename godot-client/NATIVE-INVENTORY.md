# Native inventory and equipment: core integration

The Godot local client now has a native inventory window using authoritative
server item proxies and the existing session request senders. Press I or the
Inventory button. X remains the live examine shortcut; offline I inspection
is preserved. Inventory, examination and spellbook can coexist. This is a
partial inventory migration, not acceptance of all player windows or stores.

## Implemented behavior

- Native equipment layout uses `src/inventory_layout.js`: fourteen normal
  slots, six 10-by-6 backpack pages, original per-item width/height, stack
  counts, server AC, weight/capacity and gold. Full icon boxes retain their
  aspect ratio and original data; captions do not alter button minimum sizes.
- Actual item icons reuse the original active-resource item-icon renderer,
  palette/layer decisions and source tables through the resource backend.
  Icons are asynchronous, bounded to four tasks and cannot block metadata,
  packet decoding or Godot's frame loop. Version/scope guards reject late icons.
- Four creature slots default hidden. The persistent checkbox is in native
  Options, accessed from the HUD, and is absent from inventory. Options state
  and draggable window positions use the existing native configuration files.
- Native drags carry only window-view/entry identities. Equipment drops check
  active slot masks and use existing equip packets; backpack drops submit grid
  coordinates. No native control fabricates an ownership transfer or local
  item result. Matching server replies clear pending controls; world updates
  own the actual move. Timeouts surface an unconfirmed request.
- Double-click/default activation reuses original item shortcut/property
  selection, item targeting, container-use request and equipment-toggle policy.
  Right-click uses the existing radial providers with inventory item ownership
  admitted separately from area placement. Item powers retain physical property
  indices and variants. Examination uses the real server response.
- Closing/area reset invalidates view/drag/widget identities. Replaced objects,
  actors, worlds and generations cannot authorize old actions. Icon work retires
  before host shutdown. Other menus and WASD stay active.

`tools/inventory-service.mjs` projects state and calls the proven session APIs;
`systems/server_inventory.gd`, `inventory_slot.gd`, `inventory_repository.gd`
and `native_options.gd` own native controls and their interaction. The prior
working JS client and production bundle were not changed.

## Evidence

`reports/native-inventory-local-v2.json` passes against the owned installed
server at 127.0.0.1:5121 running authored module GodotVisuals:

- All 16 prerequisite dialogue/examine checks and all 14 inventory checks pass.
- The actual selected character supplies eight item entries and eight original
  icons. The item radial opens, and Examine receives that real item's server
  description.
- The test requests page six, unequips the real robe into grid [0,30], observes
  successful native unequip acknowledgement and replicated backpack location,
  then invokes the native equip-drop callback. The server acknowledges equip
  and places the same item back into chest slot 2. Both real replies are retained
  in `inventoryResults`; requests are in `inventoryRequests`. The test does not
  manufacture a packet response or perform a local rules equip.
- Page one and the inventory reopen successfully. Native inventory and real
  spellbook stay open together during actual server-connected WASD movement.
  The rendered frame is `native-inventory-local-v2-inventory.png` in this project.
- Native engine log is clean, renderer errors are empty, and shutdown reports
  zero pending icon tasks. This is functional evidence, not a clean FPS test.

`reports/inventory-ui-native-v4.json` passes 16 authored native checks for layout,
full item dimensions, drag identities/coordinates, stale controls/icons,
aspect ratio, options-only/default-off creature slots, persisted preference,
reopen position and world reset. `tools/inventory-fixture.mjs` regenerates the
authored metadata fixture without original assets.

`reports/native-inventory-node-v2.log` passes 34 relevant inventory, action,
spellbook and gameplay-text cases. Inventory cases cover actual sender
selection, no optimistic item transfer, matching replies, invalid slot/grid
requests, actor/item/world replacement, late icons and page revisions.
`reports/inventory-spellbook-ui-regression-v1.json` retains all 22 native
spellbook/family/quickbar/input checks. Dedicated engine logs are clean.

Failed authored UI v1 is retained (incorrect PNG helper name); its verified
failed helper was stopped before rerun. UI v2 exposed fallback text expanding
the item box, fixed by an independent clipped caption. UI v3/v4 pass. The first
live launch correctly waited for the owned prior Electron host to finish
retiring; it did not terminate an unrelated process. Both live inventory v1
and v2 pass; v2 adds radial/item-examine acceptance.

## Remaining work

Containers and stores need native views, status-driven opening, page navigation,
transfers and transactions; the backend projects C entries but this window does
not yet display them. Empty-slot native artwork, additional item details,
split-stack/learn-scroll and unsupported radial branches remain. Real server
checks for property-item activation/variants, world pickup/drop, rejection,
container races, full physical mouse dragging, mount/shape restrictions and
inventory-open transitions/reconnect are still required. Creature slots have
authored native UI coverage, not a real server creature-equipment transaction.

The inherited drag-layout persistence is used; the actual local check covers
same-session reopen, not an application-relaunch position test. Full NUI,
character sheet, map, journal, creation/level-up, main-menu settings integration,
audio and other checklist entries remain. No complete feature or sustained
moving-world >=60 FPS claim follows from this room or its on-screen FPS counter.
No Arelith connection was made. The editor and prior working client remain.

Subsequent [container core acceptance](NATIVE-CONTAINERS.md) adds automatic
primary-container opening, native page controls, two-way server-confirmed item
transfers and scoped close/reopen. The pending-container sentence above is the
prior milestone state; stores, alternate/nested containers and the explicitly
listed broader acceptance cases remain open.

Subsequent native merchant buy/sell/identify and category/page acceptance is
recorded in [NATIVE-STORES.md](NATIVE-STORES.md), including current ordinary
inventory and container live regressions. Broader inventory/store and player
window limits remain on the full migration checklist.

## Inventory item shortcuts

Owned backpack and equipped items can now be dragged onto any of the three
native quickbar pages. Assignment reuses the existing item shortcut rules;
the backend resolves the item from private inventory and quickbar owners and
rechecks ownership after loading rules. Retired views, changed items, pending
transfers, merchant stock and container contents cannot create an owned item
shortcut. Unidentified or unusable items retain the existing rule rejection.
The item icon adapter now receives the raw item metadata, preserving original
item artwork on the shortcut.

`reports/native-inventory-shortcut-local-v1.json` passes 20 actual local checks,
including assignment to slot 35, original name/icon delivery, shortcut-triggered
unequip and re-equip confirmed by the server, clearing the binding, radial
examination, sixth-page transfers and WASD with inventory and spellbook open.
The four equipment acknowledgements and configured item binding are recorded;
the test uses an external temporary character vault. Exit 0, explicit disconnect,
no native or renderer errors, and the final menu screenshot were checked.

`reports/inventory-shortcut-ui-rendered-v1.json` passes 12 authored Vulkan GUI
checks, including a synthetic viewport mouse press/motion/release through
Godot's actual drag dispatch, private drop identity and stale-owner rejection.
The existing inventory and spellbook regressions pass 24 and 22 checks. The
backend inventory/spellbook/protocol suite passes 40 cases in
`reports/inventory-shortcut-node-v3.log`; native engine logs are clean.
The earlier authored shortcut UI attempt is retained: its fixture was delivered
before opening inventory and therefore correctly ignored by the UI. The owned
failed test was stopped and the test initialization corrected.

This accepts the owned-item default shortcut path. Property-selection menus,
secondary weapon icons, broader item activation/targeting, persistence across
reconnect and physical-device review remain pending. Synthetic input and one
local room do not establish full UI or performance parity. Only localhost 5121
was contacted; the existing project editor and local server were preserved.

The next [item-power migration](NATIVE-ITEM-POWERS.md) adds wheel-leaf dragging,
original family/paged power choices, primary/secondary icon ownership and
charge disabling. It also fixes presentation refreshes overtaking item and
shortcut input. Authored checks pass and local v5 passes all 26 checks, including
one consumed potion, both clears, four equipment acknowledgements and clean
shutdown. Earlier failed attempts remain rejected in that document.
