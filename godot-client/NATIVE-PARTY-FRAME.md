# Original party HUD framing — partial UI parity

The native right-hand HUD now uses original `PNL_PARTY_BAR`, portrait, button,
member and name-tag model geometry. The generic card margins, stretched action
backgrounds, horizontal HP row and repeated self-name are replaced by the
original layout. This is a scoped frame/input milestone, not full party parity.

`CPanelPartyBar1408503c0` supplies the eight action resource/hook/tooltip
bindings. The80-pixel rail anchors against the right edge, with the original
64×100 player portrait at(12,4),7×100 health at(3,3), and35×17 menu artwork on
its original hooks. Menu clicks retain the actual map, inventory, journal,
character, rest, spellbook, options and PvP routes.

The controlled portrait/actions stay outside the member ScrollContainer.
`CPanelPartyMember1408509c0` supplies31×50 member portraits, separate narrow
health, frame and66-pixel linked rows. The list uses the shared original
scrollbar art/input. Removing all members or disconnecting closes that bar,
including pending artwork listeners; it cannot reappear from an old completion.
Unknown HP stays undisclosed and unavailable membership stays disabled.

`AddMember140851220` uses default-dialog text in grey(0.8,0.8,0.8),62-pixel
width, and the name-tag's `Text` hook. `CGuiLabel` construction1401e80b0 sets
left/bottom alignment. Name text is therefore anchored separately from the
background plane; treating the ten-pixel background as a text rectangle cut
off glyphs. Exact native font baseline, name fitting and localization remain
unaccepted pending original-client comparison.

The original level-up control is a portrait overlay, not an extra text button
under the menus. `CClientGUI1406f63d0` attaches `CTL_BTN_PB_LVLUP` to `Portrait`.
The existing server-gated Level Up owner now uses that art/geometry and still
sends the real level-up begin request. Revoked availability removes the overlay.

`native_status_bar.gd` samples original health animated vertices/UVs using
`CGuiStatusBar::SetStatus1401ec270`: clamp0–100, then sample `percentage` at
percent/30. Division/multiplication/time use float32 rounding. The rendered
footprint follows the animated model; it does not squeeze a full-health picture.
It permits one pose in flight and coalesces bursts to the latest received HP.
A64-update burst is checked to schedule exactly one request. Unknown health
hides the visual, idle controls stop processing, and retirement disconnects
pending publication. `party_skin` diagnostics expose preparation/health status.

Party portrait/action callbacks now reject retired cards. Real member clicking
also exposed an existing conditional-expression bug that attempted to use a
void result; explicit branches preserve the intended examine/record dispatch.
Right-click coordinates use the actual control/canvas transform.

## Evidence and verification

Root evidence:

- `backups/animations/rea-native-party-hud-research-v1.json`:12 original analyses,
  plus the status-name pointer bytes (`percentage`).
- `backups/animations/rea-native-party-hud-controls-v1.json`:6 original control,
  member-name and level-overlay analyses.
- Both identify original client SHA256
  `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
- `reports/native-party-model-parts-v1.json`:18 original model-node observations.
- `reports/native-party-model-geometry-v1.json`:20 original resource hashes,
  geometry/hooks/clips and sampled health vertices/UVs. These are read-only
  research receipts, not current UI acceptance.

Current unchanged-source debugger receipts:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-party-frame-final-v1` |44| Original geometry; actual portrait/eight-action/level input; HP/coalescing; undisclosed/unavailable rows;24-member scrolling;125% scale; movement/camera input; stale callback and disconnect retirement |
| `native-party-quickbar-final-v1` |43| Native quickbar input/art regression |
| `native-party-character-final-v1` |55| Native character resize/selection/art regression |
| `native-party-desktop-final-v1` |41| Existing native desktop/actions |
| `native-party-retirement-final-v1` |13| Shared native render teardown |
| `native-party-playability-final-v1` |1314| Existing headless regression aggregation |
| `native-party-actions-final-v1` |99| Authoritative original server at localhost5125 |

Normal, quarter-health, level-overlay, long-roster and125% screenshots are
reviewed. Tests inject input into an isolated SubViewport; they do not move or
capture the physical pointer. Public connections are zero. The first retained
candidate failed the real member-click handler and premature roster-scroll
observations; it is not acceptance evidence.

## Remaining gaps

Full party/HUD parity is **false**. Member locator/status/leader indicators,
associate/DM/possession behavior, original roster
ordering/disclosure, viewport inset settings, all name/font/tooltip/state/input
variants and original-client visual/input comparison remain open. The current
portrait-left-click behavior retains the existing replacement action and is not
asserted identical in every original game mode. Passing44 authored native checks
or99 local-server regressions does not close those gaps. The earlier unrelated
intermittent blood-model viewport assertion stays open. General porting remains
deferred until the entire UI goal's audit passes.

The [health-variant follow-up](NATIVE-PARTY-HEALTH.md) restores original
poison/disease clip selection with an independent original-instruction oracle.
Its scoped checks do not establish live affliction or full health/party parity.
