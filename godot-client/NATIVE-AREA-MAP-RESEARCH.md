# Original area-map reconstruction — active work

This document preserves the initial data-plan investigation. The subsequent
[native frame and note milestone](NATIVE-AREA-MAP-FRAME.md) implements the
generated source frame, zoom/pan controls, pin editor and original-compatible
actions. Full map parity is still unaccepted. The preceding
[journal milestone](NATIVE-JOURNAL-FRAME.md) is scoped acceptance; the
[entire UI goal](NATIVE-UI-PARITY-GOAL.md) remains active and general porting
stays deferred.

## Actual original screen

Original CPanelAreaMap initializes its controls programmatically at140893360.
The primary screen uses generated `PNL_MAPGEN_%dx%d` models, rather than simply
loading the installed `map_area.gui`/`map_mini.gui` resources. Their inventory
does not establish the main in-game map layout.

140893030 selects one of three original table entries:8,16 or32 pixels per
tile, using `CTL_ICON_MINIMAP`, `CTL_ICON_AREAMAP` or `GUI_ICON_0X0L`. The current
generic8–64 zoom range has now been replaced by these source levels and endpoint
availability. The binary and current native implementation retain separate
per-level tile objects.

140894720/140893c70 choose frame columns/rows by rounded tile-pixel extent,
clamped against current cap globals and a minimum4×2. The initial file values
are21×24. Follow-up inspection of140892470 and both cap-global reference lists
finds an explicit console cap command, rather than automatic viewport writes.
The native frame uses the initial caps; its data plan still accepts cap inputs.
The frame then binds source hooks for zoom-in/out, new pin, close,
map center, viewport corners and both pan indicators. Examples from original
model geometry:

| Model | Full bounds | Map viewport |
| --- | --- | --- |
| `pnl_mapgen_4x2` |74×61|64×32|
| `pnl_mapgen_10x10` |170×189|160×160|
| `pnl_mapgen_21x24` |346×413|336×384|

The top-row pin/zoom/close artwork and its positions come from these hooks.
Original tooltip references are0x10807/0x10808/0x10809. The original map frame
alpha is0.5; individual tile alpha is separate. Current source-frame checks do
not accept rendered opacity, depth or typography.

## Pin behavior and authority

140892a30 routes clicked pins by their native origin flag. A personal pin opens
`CPanelPinText`/`MAP_PIN_TEXT` for editing; the other branch sends GUI action7
against the pin's target ID through1406f9bd0/1407bdf30. That outgoing message is
0x35/1, with two WORD action fields, object ID and build-gated position data.
The follow-up owned original-server check confirms this as OnPlayerGuiEvent,
event7 with the correct target. Native input now sends that event.

140892bc0 handles the pin-source drag/drop callback and converts the dropped
map point back to world coordinates through140892010 before opening a new-note
editor.140892d10 distinguishes Add/Edit/Delete/Cancel results. Actual original
outgoing note writers use0x20/2 (three floats plus CExoString),0x20/5 (same plus
INT reference) and0x20/3 (INT reference). Wire widths, indexes, server ownership,
pending/refusal handling, role restrictions and authoritative outcomes must be
retained in the native controls. The initial data-plan checkpoint wired no
actions; the follow-up frame checkpoint verifies them against the original
local server without fabricating received state.

The original marker update and pan/autocenter logic live at140894af0. The
former replacement projection dropped pin identity/origin. The frame follow-up
preserves these, full unsigned references and view/scope ownership. Hover
remains a distinct rich-text tooltip path140892af0.

## Evidence and rollback

`../backups/animations/rea-native-area-map-v1.json` retains21 original function
dossiers and supporting zoom-table/string/vtable reads, tied to client SHA
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
`../scripts/inspect-native-area-map-policy.py` executes unchanged frame sizing
and coordinate instructions in an isolated emulator. It records576 frame
decisions and108 float32 coordinate results. Model binding/formatting, slider,
viewport and publication calls are explicit captured boundaries. No GPU, live
client, profile or network is involved.

`native-area-map-layout-v2` passes705 headless checks for that policy and source
attachments. The13-model inventory `native-map-model-geometry-v2` separately
passes. The first metadata attempt used two nonexistent assumed resource names;
its failure is retained. The first plan test compared decoded JSON doubles
against native float32 results directly and had three precision failures.
Normalizing expected numbers to float32 gives exact matches; no broad tolerance
was substituted. Those receipts also remain retained.

`tools/audit-native-area-map-plan.mjs` verified this scope, original observations,
model hashes, source/debugger pins at that historical checkpoint and the read-back-verified
`backups/native-area-map-plan-v1.zip`. This is not map visual/action acceptance.
The prior journal implementation remains backed up separately and unchanged.

## Follow-up disposition

The frame follow-up implements the default middle zoom, generated frames,
source controls/editor, original coordinate conversion, exact-one exploration,
pin identity, scoped callbacks and retained movement/window behavior. Native
input and authoritative local note/GUI-event checks pass. The remaining direct
original-client comparison, exact gestures, role/DM, localization, transition
and full map audit are tracked in NATIVE-AREA-MAP-FRAME.md. Neither milestone
proves complete map or UI parity.
