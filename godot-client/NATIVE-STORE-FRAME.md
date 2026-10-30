# Native merchant layout and confirmation — partial parity

Follow-ups: [Examine/Identify](NATIVE-EXAMINE.md) owns the original Identify
control, and [shared original scrollbars](NATIVE-SCROLLBAR.md) now decorate
the confirmation. This document retains the earlier merchant checkpoint.
General porting/combat expansion is deferred by NATIVE-UI-PARITY-GOAL.md.

The direct native client now reads the active `INGAME_STORE` and
`BUYSELL_CONFIRM` GUI resources and their original models. The merchant uses
its original panel, linked category tabs, page arrows, page label, Examine eye,
10×10 repository, 33-pixel cells and bottom-origin icon attachment. Item icons
retain their own raster size. The confirmation uses original panel/button art,
text hooks, localized Buy/Sell wording and OK/Cancel captions. Windows remain
draggable; the confirmation occupies only its own pointer area. This is a UI
milestone, not full merchant or UI/combat parity.

## Original-binary evidence

Read-only NWN EE 89.8193.37-17 x64 executable SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Selected complete function body/assembly facets are retained in
`backups/animations/rea-native-store-layout-v1.json` and
`backups/animations/rea-native-store-confirm-v1.json` at workspace level.
These are static observations, not original-code execution oracles.

- Constructor `14097b4b0` selects `INGAME_STORE`, initializes a 10×10 box and
  category TLK references `f85c` through `f860`.
- Importer `14097c810` binds the named controls and creates five
  `CTL_INV_STO_TAB1..5` models. `CGuiTabSet::AddToPanel` attaches the first to
  the panel's `tabs` hook; `AddTabLinked` attaches later tabs to `next`.
- `14097cd70` formats the category and current/total page label. Native labels
  now use the active TLK instead of approximate hardcoded category names.
- `14097c3d0` fills hover information with an item name and price, using local
  custom tokens 0/1 and Buy reference `f0b4`.
- Constructor `1409aa430` selects `BUYSELL_CONFIRM`. Importer `1409aaae0`
  binds `ItemDesc`, `OkButton` and `CancelButton`; it makes the text read-only
  and attaches the original simple scrollbar.
- `1409aaba0` selects Buy `f0b4` or Sell `f0b3`, substituting item name/price.
  `1409aa8a0` sends the actual buy/sell request on confirmation.

`reports/native-store-resources-v3.json` and
`native-store-confirm-resources-v1.json` retain original GUI/model metadata.
`CTL_ST_OK` intentionally has no drawn mesh: `text0` and `text1` define its
edit rectangle. The native layout parser accepts those hooks only for edit
controls, retaining validation for missing geometry on other control types.

## Native implementation and authority

`systems/native_data/store_layout.gd` derives panel bounds, grid, text rectangle
and tab attachments from the active resources. `systems/native_store_frame.gd`
owns bounded native resource workers and decorates `server_store.gd` using the
existing original-art painter. No JS scene, image preparation or UI rendering
is added. Rules, prices and resource lookup remain scoped to the active server.

The existing validated transaction path is preserved. Selection captures the
store generation, canonical item, channel and displayed price. A changed view
invalidates stale selections; pending transactions cannot send duplicates.
Requests never predict balances or item ownership. Received server updates
drive delivery, sale proceeds and closure. Category/page selection likewise
waits for server state. Incoming prices still use the existing native pricing
projection, checked against actual local-server charges; all custom-content
pricing cases are not yet accepted.

Merchant confirmation text uses per-call `localCustomTokens` on the native
talk resolver. It never overwrites the server's custom-token dictionary. Rich
text uses explicit native color spans. The detached confirmation is raised
after its parent merchant, blocks its own pointer rectangle, and dismisses on
Cancel or Escape. It does not consume outside world clicks or WASD input.
Resource owners drain on retirement; no original client or existing server is
closed by these tests.

## Current acceptance

- `native-store-ui-final-v1`: 28 graphical checks with original resources and
  injected input in an isolated SubViewport. Covers category/page requests and
  acknowledgements, native grid/icon placement, hover/Examine, original scoped
  confirmation text, one pending purchase, Cancel/Escape, saved dragging,
  closure and resource retirement. Four visible model-raster rectangles retain
  uniform axis scale; the captured Buy frame was visually inspected. This
  audit does not prove every source UV, font or other menu correct.
- `native-store-actions-final-v1`: 88 checks against the unchanged original
  server on `127.0.0.1:5125`. Explicitly requires original merchant meshes and
  grid, then verifies purchase/sale ownership and exact gold charges plus
  inventory, casting, levels, combat and cancellation regressions.
- `native-store-barter-regression-v1`: 48 real original-server checks with two
  authenticated participants, including item/gold exchange and cancellation
  refunds in both roles.
- `native-store-text-final-v1`: 1,025 original TLK/token/RGB and raw UI checks.
- `native-store-playability-final-v1`: 1,314 native gameplay routing checks.
- `native-store-frame-regression-v1`: 157 inventory/container graphic checks.
- `native-store-barter-ui-v1`: 28 barter graphic checks.

The debugger was armed, sources stayed unchanged during each test, workers
retired and no native exception or script/lifetime error was accepted. All
server connections were owned loopback connections. These are functional
checks, not clean FPS benchmarks.

Earlier failed receipts are retained: resource-v1 queried an absent GUI name;
UI-v1/v2 exposed the meshless text control; UI-v3 exposed confirmation layering.
The corrected resource name, typed text hooks and raise order are verified by
the final receipts. Intermediate passing runs predate the final text/hover work
and do not replace the final evidence.

Before: `backups/native-player-barter-v1.zip`. After:
`backups/native-store-frame-v1.zip`, read back and source verified.
`reports/native-store-acceptance-v1.json` indexes the checkpoint and current
receipt pins; rerun `node godot-client/tools/audit-native-store.mjs` with a new
`--report=native-store-...json` filename to audit the same pinned source state.

## Remaining work

Identification remains available through the existing extra action below the
confirmation. Its original examine-window placement, simple scrollbar art,
complete original fonts, hover/radial/drag callback details, failed transaction
feedback, range/area/control changes, stack/quantity variants and mixed original
client acceptance remain open. Other gameplay windows and complete animation/
combat parity remain active goal work. The user's reported stretched assets
remain an open visual follow-up beyond the rectangles measured here.
