# Native character-sheet frame — partial parity

The later [record-value milestone](NATIVE-RECORD-VALUES.md) corrects active-rule
modifiers, received Dexterity/score adjustments, original colors and localized
labels. The receipts below describe this frame checkpoint's historical source;
the newer milestone has its own current-source acceptance.
Subsequent [entry admission/order](NATIVE-RECORD-ENTRIES.md) and
[content-sized scrollbar](NATIVE-SCROLL-THUMB.md) work retain separate evidence.
The [native resize follow-up](NATIVE-CHARACTER-RESIZE.md) now makes the original
footer functional; the static-footer gap below describes this older checkpoint.

The in-game controlled-player record now uses original `PNL_CHRSHT`, Character,
Skills and Feats page artwork, radio tabs, close/level-up buttons and native
scrollbars. `native_character_sheet_frame.gd` is presentation over the existing
`server_character_sheet.gd` owner and `native_game_desktop.gd` requests. It loads
its models only after the record is wanted. Active catalog resources supply all
models, fonts, TLK captions, portraits, ability glyphs and skill/feat definitions.

`native_data/character_sheet_layout.gd` resolves original attachment points and
fails back to the usable generic window if a required model/hook is unavailable.
The normal installed frame is360×468 GUI pixels. Its default409-pixel page is
clipped at the original footer; the tall source background is never squeezed
into that rectangle. Native row artwork is `CTL_CHR_BTN_SKIL`/`CTL_CHR_BTN_FEAT`,
with34-pixel mesh height and36-pixel linked spacing,32-pixel icons, original text
and value anchors. The separate `CTL_ICONLST_20` is **not** their row model.

Character labels and descriptions/rows use original Galahad14. The original
detail-list constructor reads `CTlkTable::s_szDialogFontName`: static initializer
140016810 loads14128f1d8, whose pointer140da3638 names `ttf fnt_default 14`.
The native frame loads that original TTF. Large-dialog-font switching remains
unimplemented here. Model hooks and source font metrics replace generic sizes.

The received `canLevelUp` flag now controls the real Level Up button. Previously
the record received that flag but its button stayed hidden. Clicking the native
button invokes the existing `native-level-up` begin flow; it does not grant a
level locally. Record pages continue to send the existing original-compatible
panel subscription, and closing unsubscribes. Private skill/feat drag handles,
per-page selection/scroll and persistent movable-window ownership are retained.
Received hit-point changes now participate in the record refresh signature.

## Bounded original-model rendering

`native_data/gui_render_region.gd`, `native_item_icons.gd` and `native_ui_art.gd`
accept an optional source region in original GUI pixels. Existing callers and
whole-model keys stay unchanged. A region changes the private camera bounds,
not the original vertices, texture coordinates or model scale. Its key includes
the region, so it cannot alias a whole-model render or another source rectangle.
The same model cache may be reused because its geometry/material identity does
not depend on camera framing. Invalid/nonfinite/oversized regions create no work.

The graphical original-header comparison checked7,056 interior pixels against
the corresponding whole-model render: zero mismatches, maximum channel delta0.
The visible tall page retains100 pixels per model unit rather than inheriting
the low density needed to fit its full3,455-pixel height in the render limit.
Closing an in-flight region retires its model, workers and post-draw callback.

Dynamic native record rows/scrollbars use the shared button painter. Its button
registration now retires when that control exits the tree, avoiding retained
freed-row geometry in the shared artwork callback. Existing inventory input and
render-retirement regressions cover this helper change.

## Evidence and verification

Original binary SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Root `backups/animations/rea-native-character-frame-research-v1.json` retains the
main/page constructors and callbacks. `rea-native-character-controls-v1.json`
adds original Skills/Feats/list/row/resize/font functions. The separate
`rea-native-character-content-research-v1.json` retains all103,037 characters of
the original Character SetData pseudocode for the outstanding content audit.

Current source-pinned clean debugger receipts:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-character-frame-v4` |23| Actual isolated tab/row/close/reopen/level-up input, original frame/fonts/aspect and stale private handles |
| `native-character-frame-desktop-v1` |41| Existing native desktop/menu/targeting integration |
| `native-character-region-regression-v1` |21| Original-art source-region comparison, compatibility and active retirement |
| `native-character-inventory-regression-v1` |160| Existing original inventory/container/input/amount actions |
| `native-character-retirement-regression-v1` |13| Native in-flight GUI render teardown |
| `native-character-playability-regression-v1` |1314| Existing headless regression aggregation |
| `native-character-actions-v1` |99| Existing authoritative original-server localhost5125 action regression |

The local-server run is a regression of its existing actions; it does **not**
accept complete record disclosure/level-up behavior against every server. The
new frame-specific input uses received-state fixtures. All runs used zero
public connections. Original installed resources are read-only. The v1 smoke
compile failure, missing-row-hook v1 and rich-text observation failure v2 remain
retained; only the final source receipts above support this milestone.

## Open work — full character-sheet parity is false

- Audit and port the full original detail content and disclosure/formatting,
  rather than the current seven generic detail rows; ability adjustments,
  effective modifiers, alignment/classes, localized XP labels and combat fields.
- Implement the original vertical resize interaction and exact viewport/text
  range/page mapping. The original footer artwork is currently static; resizing
  is not accepted. Complete wheel/arrow/rail/input behavior in both row lists.
- Verify selection/hover/pressed/disabled artwork, audio, row ordering, feat
  replacement/grouping, value colors, tooltip and drag behavior in each context.
- Compare actual original-client and replacement output at supported UI scales,
  resolutions, languages, portrait variants and server resource overrides.
- Cover non-controlled/lobby record variants, the fourth selection tab, all
  original close/keyboard rules and original-server outcomes for every action.

The whole UI goal remains active. General porting is still deferred. The earlier
intermittent local blood-model viewport assertion remains open; this passing
regression run is not a particle fix or closure of that separate limitation.
