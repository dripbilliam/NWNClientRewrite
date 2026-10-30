# Native character-sheet resizing — partial parity

The original `CTL_CHRSHT_RESIZ` footer is now an actual resize control. Dragging
it changes the native Character/Skills/Feats viewport height, keeps window width
and source artwork dimensions fixed, preserves current private view/entry handles
and selected description, and sends no gameplay request. Position/front ordering
remain owned by the existing draggable window. Releasing the footer clears the
real Button pressed state. Closing, hiding or losing window focus ends resizing.

Size persists beside placement in the native layout configuration's `sizes`
section. Reopening keeps it, and a fresh native frame owner reloads it from disk.
Pointer coordinates pass through the actual canvas transform: at125% UI scale,
50 screen pixels resize40 original GUI pixels. No physical pointer movement,
capture/warp API, public server or JS presentation service is used by the tests.

## Original layout rules and native publication

`CPanelCharSheet`14088a0a0 selects the resizable in-game model when its mode is
nonzero. Callback14088aa90 locks movement to the vertical axis and passes the
footer's world Y plus0.11 to the active page. The page adds another0.14 for the
scrollbar endpoint. Gob vtable slots130/138 are `SetPartPosition`1400950b0 and
`GetPartPosition`14008f4d0, both world-space;140095050 is the separate local-space
setter. In original screen coordinates this places the text/list bottom11 GUI
pixels above the footer, and its scrollbar endpoint another14 pixels above it.

The native frame applies these attachment changes to its live scroll controls.
Skills/Feats retain the fixed description region while their lower list grows.
Character details use the corresponding text anchors. The earlier guessed22-
pixel detail inset and scrollbar-offset sign are removed. Original panel artwork
uses a cached2048-pixel source region at native density and is clipped as height
changes; it is never stretched to fill the resized window. Original texture caps,
UVs, fonts, labels, portrait and row geometry keep their sizes.

`native_scrollbar.gd.relayout()` coalesces raw input into the latest desired
layout. It permits one rail/thumb packet in flight per widget and publishes the
pair together once native model textures are ready. While waiting it keeps the
previous complete pair. Intermediate input cannot build an unbounded render
queue. A64-motion burst is verified to schedule one layout packet. Existing
scroll values, model/font ownership, held-input cancellation and widget teardown
remain native. Failed asynchronous artwork now stops its polling path with an
explicit diagnostic; a completed idle widget does not keep processing frames.

TLK detail captions are trimmed before adding the separator, removing duplicate
colons from labels that already contain a colon and trailing whitespace.

## Verification and limits

Root `backups/animations/rea-native-character-resize-v1.json` retains original
drag/resize, world/local part positioning and scrollbar stretch code. The main
mode/inset callback is retained in `rea-native-character-frame-research-v1.json`.
All refer to original client SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

Clean unchanged-source debugger receipts:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-character-resize-v3` |55| Actual original-footer input; Character/Skills anchors; current selection/handles;64-motion coalescing; focus/close/reopen; fresh-owner size persistence;125% input; viewport/structural guards |
| `native-character-resize-examine-final-v1` |62| Shared scrollbar and Identify input regression |
| `native-character-resize-store-final-v1` |32| Merchant/confirmation UI regression |
| `native-character-resize-retirement-final-v1` |13| In-flight native GUI render teardown |
| `native-character-resize-desktop-final-v1` |41| Native desktop/targeting/menus regression |
| `native-character-resize-playability-final-v1` |1314| Existing headless regression aggregation |
| `native-character-resize-actions-final-v1` |99| Original-server authoritative localhost5125 regression |

Native screenshots were reviewed at normal and125% scale, including Character
and Skills grown windows. The server run exited0 with no workers remaining and
zero public connections. Early retained failures were compile-time inferred test
types and are not acceptance evidence.

Full character-sheet/resize parity is still false. The replacement currently
uses a structural71-pixel minimum to keep title/close/footer reachable, and a
viewport clamp. The original's exact limits, HUD-aware lower bound, pressed/
capture/focus-loss behavior and scene clipping/draw order need original-client
input/visual comparison. Exact text/list page extents, partial lines, all fonts/
scales/server/role variants and complete record content/disclosure remain open.
The earlier intermittent blood-model viewport assertion remains open separately.
The full UI goal is active; general porting remains deferred.
