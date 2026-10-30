# Native inventory and container frames — partial parity

The inventory now uses the active original `INV_PANEL.gui` and `INV_CONTAINER.gui`,
their model attachment points, repository artwork, tabs, labels and buttons.
The existing native equipment controls and typed server requests remain the
owners of item membership, transfers, pending operations and outcomes.

## Original evidence and layout

Original client: NWN EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only evidence is retained in `backups/animations/rea-inventory-frame-interaction-v1.json`,
`rea-inventory-container-pages-v1.json`, and the equipment evidence linked in
[the equipment milestone](NATIVE-INVENTORY-EQUIPMENT.md).

The original main model is360×470 source pixels. Its equipment hook is(0,217);
the10×6 repository has33px cells and lower-left icon attachment. Six page buttons
chain through the original `next` hook. The container repository is7×5; its
page label follows the original `%02d/%02d` format. The layout reader validates
active GUI tags, hierarchy, model resources and geometry. It does not compile
a server-specific item catalog or reuse JS rendering.

`scripts/inspect-native-inventory-reposition.py` executes unchanged original
function140882b70 under the pinned read-only emulator harness. It captures only
the final transform/parent virtual calls.180 cell/footprint cases match the native
float32 output bits. Incoming repository coordinates stay bottom-origin;
screen positions and drops are converted at the native view boundary.

The original Examine button140856070 starts item selection. The native eye
button now selects that mode; the next item click sends its real Examine request.
Container page/close controls retain the existing request path and await received
state. Inventory/container dragging and saved positions remain native.

## Artwork proportions and retirement

Static MDL bounds differ from the animated up/hover/down poses. Fitting every
pose into one static rectangle stretched some assets. Each button now positions
and draws the complete raster at that pose's original bounds. Normal close art
is17×17, eye/gold38×38 and tabs16×34 source pixels. Wider pressed tab poses keep
their own width instead of being squeezed into the up-state rectangle.

The shared native GUI renderer also snaps near-integer raster extents before
rounding and projects at equal pixel density on both axes. Raster metadata now
includes fractional-extent padding, with the underlying geometry bounds retained
separately. Optional creature slots, still default off and configured in Options,
insert a gap between separately cropped upper/footer artwork; they do not stretch
the original frame or icons.

A broader desktop run exposed an active icon coroutine resuming after its owner
was freed. Render completion now uses an owned one-shot post-draw callback and
pending record. Closing disconnects that callback and retires both cached and
transient pending models before releasing resources.

## Verification and limits

Current scoped debugger receipts have unchanged pinned native sources, no caught
native exception and no script/lifetime errors:

| Receipt | Scope |
| --- | --- |
| native-inventory-frame-layout-final-v3 |206 checks, including180 unchanged original transform cases and raster rounding. |
| native-inventory-frame-ui-final-v4 |118 graphical checks: original artwork/poses, actual GUI dispatch, selection/Examine, bottom-origin drops, pages, container controls, dragging/persistence, optional slots and cleanup. PNGs inspected. |
| native-inventory-frame-desktop-final-v2 |41 broader native desktop/HUD/map/menu checks. |
| native-inventory-frame-radial-final-v1 |32 original radial artwork/input checks. |
| native-gui-render-retirement-v1 |13 cached/transient in-flight render retirement checks across actual later rendered frames. |
| native-inventory-frame-rules-final-v2 |607 existing original-table icon/rule/item-routing checks. |
| native-inventory-frame-playability-final-v2 |1314 existing gameplay/UI rules and routing checks. |

The GUI fixture uses a manually notified, explicitly injected SubViewport,
displayed1:1 through a TextureRect. It exercises native GUI dispatch without
moving the physical cursor or activating the game window. It does not claim
hardware-mouse or full live-server acceptance. See the official
[Viewport input documentation](https://docs.godotengine.org/en/4.5/classes/class_viewport.html).

The first current-source full owned-server action run passed equipment transfers,
casting, advancement and familiar controls, then failed its combat-feedback check.
`native-inventory-frame-actions-v1` is retained and is not accepted as a completed
gameplay regression. Diagnostic assertions now record the chosen target and
confirm that the native radial selected the actual attack interaction. The next
run, `native-inventory-frame-actions-v2`, passes68 unchanged-server checks,
including actual attack animation, facing, visible impact and cancellation.
Its target is the authored Native Speaker, not the summoned familiar. Native
exit0, no caught exception/UI errors, workers0, frame ready, public connections0
and source unchanged. This does not establish the cause of the first run's
intermittent missing attack feedback; that failure remains retained and open.
`native-inventory-frame-actions-v3` independently repeats all68 checks with the
same clean exit, unchanged source, zero public connections and zero remaining
workers. No production combat behavior was changed between these runs.

Earlier failed receipts remain retained: layout-v1 assumed465px height instead
of the model's470; early UI runs exposed static/animated pose bounds and dragging
issues. Root-window injected drops queried the physical mouse, and a
SubViewportContainer forwarded physical mouse exits; the isolated fixture fixes
that test ambiguity without warping the cursor. UI-final-v1/v2 exposed pressed
pose fractional bounds/raster padding. Desktop-final-v1 passed assertions but
reported the freed render coroutine and is not accepted; final-v2 verifies the fix.

This checkpoint left the gold button disabled. The [native gold follow-up](NATIVE-INVENTORY-GOLD.md)
now connects original140856190/140856340/1407bdc70 amount/drag controls and transfers.
Player barter, exact native fonts/hover polygons/count presentation, store framing,
all custom GUI variants and broader mixed-client/combat acceptance remain open.
Missing artwork leaves the prior usable generic view available. These changes
do not complete the active UI/combat goal or constitute a performance benchmark.

Rollback: before `backups/native-inventory-equipment-v1.zip`; after
`backups/native-inventory-frame-v1.zip`. Read-back manifests retain individual
source identities and the archive digest.
