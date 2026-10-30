# Native server-list input and label follow-up — partial

The subsequent [server-row activation follow-up](NATIVE-SERVER-ACTIVATION.md)
adds double-click and Enter request handling. Its separate receipts supersede
the earlier unported-input notes below; full original keyboard/role/visual
acceptance remains open.

The native browser now captures internal keyboard ownership after a list row
click. Left/Up select the preceding row; Right/Down select the following row.
Selection is acknowledged by the catalog service, respects current connection
and view ownership, does not wrap, and crosses transport pages as one original
list. An acknowledged offscreen row is revealed in the shared six-column scroll
viewport. Opening a modal or returning to Multiplayer releases list focus.
Navigation itself never logs in or queries a server.

Original CGuiListBox::HandleKeyEvent `0x1401e9790` consumes four cursor-key IDs,
checks pressed/disabled state and row bounds, scrolls, then updates selection
and callbacks. `scripts/inspect-native-server-list-keys.py` executes its unchanged
instructions with captured GUI helper boundaries. The 240 cases in
`../backups/animations/native-server-list-key-observations-v1.json` cover empty,
single and larger lists, deselection, both boundaries, irrelevant keys, release
and disabled state. They validate selection policy, not pixels or all keyboard
mapping. Static dossiers are `rea-native-server-list-input-v2.json` alongside it.

Details captions now distinguish bounded and unbounded original labels. In
`CGuiPanel::CloseLayoutFile` (`0x1401fdbb0`), unclaimed labels go directly through
`CAuroraStringWrapper::LoadGffTextData`, bypassing the bounds flag checked by
`CGuiLabel::LoadGffData` (`0x1401fe260`). The Details initializer `0x1408d4090`
sets that flag only on Title. Its other captions use text-sized rectangles at
their source alignment anchors, including after asynchronous bitmap-font load.
The former painter clipped long rule captions to editor metadata widths. The
title retains its fixed original bounds. Other callers opt in explicitly;
unverified label owners are not globally reclassified. Static evidence is
`../backups/animations/rea-native-server-labels-v1.json`.

The user's open replacement session is preserved. Current evidence is headless:
`native-server-list-keys-headless-v1` (15 native input checks),
`native-server-labels-headless-v3` (28 Details input/text-fit checks), and
`native-server-labels-entry-headless-v1` (31 Multiplayer/Direct regressions).
`native-server-list-keys-service-v2.tap` passes 58 service/protocol checks,
including the 240 original key-policy cases as nested evidence. These are not
graphical or local-server acceptance receipts for this source version. The
earlier Details/page startup/local receipts describe their prior checkpoint.

Graphical text placement, other resolutions/scales, original-client comparison,
fresh full startup/local admission regression and sound remain pending for this
follow-up. Full UI/browser parity remains false. Double-click/Enter connection,
game-type filtering, exact PvP/version text, local NWSync completeness and the
remaining admission/dialog roles still need migration or verification. The
original Sync column calls HasAdvertisedData (`0x1401b1910`), so an advertised
manifest alone must not become a claimed local cache success.
