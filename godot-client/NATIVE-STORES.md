# Native merchant trading: core acceptance

Status: **partial; owned-local merchant core verified; full store parity open**.
Godot owns presentation. The existing JS `storeInput`, original price helper
and canonical `NetworkWorld` own protocol validation and replicated state.
No store ID is invented from a speaking NPC: OpenStore does not transmit it.
Original sender/decoder evidence is in
[multiplayer-stores-and-rule-tokens.md](../evidence/multiplayer-stores-and-rule-tokens.md).

## Behavior and ownership

- Actual store-open automatically opens inventory and an independently movable
  merchant window with persistent positions. The merchant uses its original
  ten-by-ten grid, installed TLK labels, full-height original item icons,
  categories/pages and server store gold. Trading hides equipment and ordinary
  Use/Drop controls; closing returns to normal equipment/backpack presentation.
- Click, double-click, right-click or drag an item to select it. Buy/Sell is an
  explicit priced confirmation. Examine uses the actual server description;
  unidentified carried items offer the server's identification fee. Dragging
  selects confirmation rather than silently transferring ownership.
- Real session senders handle transactions. A successful send or native reply
  never fabricates success, item transfer or gold. The reply has no success
  BOOL; actual world updates prove outcomes. Pending items reject duplicates
  and time out with a notice. On this server identification charges gold
  without a buy/sell transaction message. An ordered follow-up examination
  lets the server's actual identified flag refresh the item and retire pending
  identification; the adapter never locally identifies it.
- Current category/page reselection is a no-op. Otherwise the generic sender
  clears stock while the server need not resend an unchanged selection.
  Category navigation waits for matching actual M/P; page navigation waits
  for real merchant records. Further navigation is disabled while pending,
  with Close and a bounded timeout available. Empty categories work.
- Views retire when new asynchronous metadata is ready to emit. Context checks
  cover world/actor/connection/area, pages, container serial and store generation
  and navigation. Separate item checks cover canonical identity, GUI membership,
  location and metadata. Unrelated arriving items/statistics no longer reject
  valid clicks; changed price/ownership/location and retired selections still do.
  An old failed send cannot clear a replacement request reusing the same item ID.
- Close/world reset clears native stock, selection, textures and pending state.
  Merchant/inventory bounds block world hover/click behind them. Outside input
  and WASD remain available through simultaneous windows.

## Actual owned-local evidence

`reports/native-store-local-v7.json` passes **16 live gameplay +25 merchant checks**,
native exit 0, empty renderer errors, no inventory request rejections and zero
pending icon tasks at shutdown. Its clean engine log is
`reports/native-store-local-v7.engine.log`.

The real installed server creates eighteen installed clothing items in an
authored merchant, yielding two populated pages. Next/Previous, independent
player page six and return, a distinct empty category and return, close/reopen
and stale drags are checked. Buy and Sell use **the same finite item 2147483670**;
both actual requests/replies and canonical ownership are checked. Authoritative
player gold is **51529 → 51528 → 51529 → 51429** after buy, sell and identification
of item 2147483689, whose actual examination identified flag is 1. The report
retains merchant record metadata and actual store/examination replies.

Every visible clothing icon must have a native texture. The captured project
frame `native-store-local-v7-store.png` shows the full merchant grid and Buy
confirmation beside the backpack. A prior passing v5 frame was also inspected.
The real spellbook opens concurrently and actual WASD displacement is checked
with all three windows open. Scripted native callbacks do not establish every
physical mouse drag, camera gesture or window-overlap pattern end to end.

`reports/native-store-node-v4.log` passes **40 Node cases**, including original
store writers against retained binary evidence, command bounds, unsigned price
arithmetic, ownership/stale data, delayed metadata, unrelated replication,
acknowledgement/timeouts, old sends and inventory/container/PLT regressions.
`reports/store-ui-native-v4.json` passes **20 authored native merchant checks**;
`reports/store-inventory-ui-regression-v2.json` passes **23 authored existing
inventory checks**. Their dedicated engine logs are clean.

The actual existing container regression also passes **16 gameplay +16 container
checks** on the final sources: `reports/native-store-container-regression-v1.json`.
Renderer errors/rejected inventory requests are empty and pending icons retire
to zero. That check uses the inherited chest fixture, not a simulated store.

`reports/native-store-inventory-regression-v1.json` additionally passes
**16 gameplay +14 ordinary inventory checks** on the final sources, including
real unequip/equip, item radial/examine, original icons and simultaneous-menu
movement. It has no rejected inventory requests or renderer errors, and icon
cleanup is zero. Both regression engine logs are retained separately.

`tools/create-store-server.mjs` extends the verified authored GodotContainers
module without copying installed payloads. Its own empty UTM and chat script
reference installed item templates, create stock and give the test character
gold using installed API signatures. Fixture metadata is
`reports/store-server-fixture-v1.json`: GodotStores SHA256
`0897df56e2a97e72d0cfeb8e6b48b5374cbc1cc78367288ddb05e0ac172082ad`.
From a fresh owned GodotStores server run
`join-local.ps1 -StoreSmoke -Report <unused-name>.json`.
Setup creates a tagged merchant each time, so clean repeats require resetting
the owned fixture. No installed asset bytes enter the workspace.

Earlier failed/weak runs remain. V1 watched page six while purchases used the
first available page. V2 had unsettled initial data and wrongly classified any
new carried ID as a purchase; acceptance now requires the finite stock ID.
V3 exposed unchanged-category clearing and a test closure state bug. V4 exposed
rapid category clearing before acknowledgement. V5 passed all checks with a
rejected redundant initial test request; V6 exposed broad snapshot invalidation
during arriving stock. V7 passes with scoped context/item guards and no rejection.

## Remaining scope

Quantity/stack confirmations, infinite-stock cloning, black-market/restriction
branches, actual affordability/refusal/full-pack failures, price-change/item
destruction/concurrent-user races, associates/nested containers, last-page
shrink/transfers and pending operations across actual transitions/reconnect
still need native acceptance. Original store skin/art, full placeable animation,
remaining inventory actions, player windows and full NUI remain on the ledger.

The working JS main/dist and original resources remain unchanged. Only the
owned local server was contacted; no Arelith. The unrelated editor was preserved.
The fixture's displayed FPS does not prove complete moving captured-world
fidelity or sustained >=60 FPS. Full migration remains active and incomplete.
