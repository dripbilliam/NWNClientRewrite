# Native conversation frame and reply ownership

Scoped UI parity milestone. Full conversation and full UI parity remain open.
General porting stays deferred under [the active UI goal](NATIVE-UI-PARITY-GOAL.md).

## Original evidence

The in-game conversation is programmatic `CGuiInGameChatDialog`, not one of the
104 installed GFF GUI definitions. Its constructor at14087d1e0 loads
`PNL_DIALOG`, `CTL_DIALOG_ENTRY` and `CTL_DIALOG_REPLY`, with independent
read-only pixel-scrolling text owners. Native resource inspection records their
original hashes and hooks in `reports/native-conversation-model-geometry-v1.json`.
`reports/native-conversation-pose-v1.json` samples the actual `size` transform
and vertex tracks; resizing does not stretch a completed frame screenshot.

The default body/reply font is `ttf fnt_default 14`; the speaker name uses
`fnt_galahad14`. Original font pointers also identify the unported large-font
variant `ttf fnt_default_hr 16`. Default replies are blue0.4/0.7/1.0, hover and
selected text white, entry text white. Reply numbers have a separate
right-aligned16px attachment,20px left of the311px reply text column.

Reflow14087dd00 caps entry text at2.0 model units, adds0.39999998 and floors the
reply origin at1.12. It adds measured reply height and0.049999997, floors the
panel at2.54, then caps it to the manager's available clearance with a4.0 minimum.
The original `size` animation time is `(height-0.64)/0.01/30`, rounded at each
float32 operation. Logical height adds0.04. The reply model moves to the new
content-dependent origin. Scrollbars attach only when content overflows.

The authored read-only emulator `scripts/inspect-native-conversation-policy.py`
executes those original instructions and selection14087e750 unchanged. Its
378 sizing and160 selection observations are retained in
`backups/animations/native-conversation-policy-observations-v1.json` at workspace
root. Font, model initialization, protocol and ownership analyses are retained
in root `backups/animations/rea-native-conversation-policy-v2.json` (16 dossiers
plus font/vtable observations). The verified client SHA is
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Measurement, model operations, manager clearance and callback publication are
captured emulator boundaries; this is policy evidence, not a pixel comparison.

`reports/native-conversation-textures-v1.json` confirms the background meshes
use `gui_boxes_dialog`; only the portrait mesh uses `gui_replace01`. Original
SetModel1401fb710 invokes InitializeModel1401e58d0, an empty initializer in this
class. The current frame retains these source bindings and overlays the actual
speaker's64×100 medium portrait at its original attachment.

## Connected native behavior

`systems/native_conversation_frame.gd` lazily loads original models when a
received conversation opens. Godot owns text, fonts, artwork, clipping,
scrollbars, pointer/keyboard input and window placement. Entry/reply models
retain separate scroll positions. The speaker name/portrait comes from the
received speaker object, with the original unknown-name/portrait fallbacks;
the listener's portrait is not substituted.

`server_conversation.gd` preserves received unsigned entry/reply IDs and the
available/read-only reply partition. A chosen reply disables further selection
until a current server refusal or new entry arrives. Stale errors and retired
callbacks cannot unlock/select a newer offer. Selected-text subtype4 replaces
the matching reply or appends a read-only selected row, rather than appending
text to the speaker entry (original6fbbc0/87ed90).

An empty received offer creates the original localized synthetic end choice.
Both selecting it and Escape close locally without inventing a wire reply,
matching the original callback's-2 path. Ordinary Escape uses the existing
original-compatible abort request; the protocol owner's secondary-count-one
exception remains in `NetworkGameSession.replyDialog`. Nonterminal completion
and abort wait for authoritative server results. Menu position uses the supplied
layout file and its own `local-dialog` key. Dragging the name retains simultaneous
windows and outside movement. A related saved-layout regression now leaves the
character sheet at its default size when no size entry exists.

The long-entry regression exposed an intermediate empty-reply state between
the two packets. Resizing its hidden scrollbar produced an invalid short rail
and latched failure. Scrollbars now attach/resize only for overflowing content,
as the original does. The native test verifies the published reply rail is at
the current reply origin, not merely that its assets finished.

## Current verification and rollback

Final source-pinned receipts use `native-conversation-*-accepted-v2`:

| Receipt | Checks | Scope |
| --- | ---: | --- |
| oracle |544|378 original float32 sizing paths,160 original selection paths, input validation|
| input |41|Original native frame, speaker, fonts, tokens, wrapping, availability, unsigned IDs, stale/refused/pending/selected states, terminal close, scrolling, attachment, dragging, saved position,125percent scale and outside movement|
| desktop |41|Existing native desktop integration|
| resize |55|Existing original character-sheet footer/scrollbar resize input|
| text |35|Existing literal rich text, history, routing, disclosure and retirement|
| preparation |58|Existing native spellbook/preparation input|
| retirement |13|Existing GUI render retirement|
| playability |1314|Existing native gameplay regression corpus|
| server |116|Owned original server127.0.0.1:5125, including real dialogue start/reply/end/abort and existing UI actions|

All2,217 checks pass, with armed native exception monitoring, unchanged tested
source, no engine/lifetime errors, final native exit0 and workers remaining0.
The local module is `GodotIdentify2`, SHA
`369b70c775722852f9271b9150acedba443cbb9cde70778f9715ff8ed791e2fa`.
The live dialogue verifies `FIRST_ENTRY`, resolved server custom token,
`SECOND_ENTRY`, `GODOT_PICK_ACK`, `GODOT_END_ACK` and `GODOT_ABORT_ACK` using actual
received text and original-style reply controls. No public connections occurred.

`tools/audit-native-conversation.mjs` verifies receipt/source/research/screenshot
hashes and `backups/native-conversation-frame-v1.zip` with its read-back manifest.
The checkpoint includes authored source, documentation and inherited oracle
dependencies. Private keys, reports, imported game resources and caches are
excluded; separate research/observation files are hashed by the audit.
Historical candidate failures are retained, including v4's compile error,
v5's old text minimum width, v7's missing saved size, v9/v10/v11's stale scrollbar
attachment, the legacy text receipt's missing success field, and the first live
probe's omitted Talk action. No failed candidate is accepted as final evidence.

## Remaining parity work

This is not100percent conversation acceptance. Remaining work includes direct
original-client visual/input comparison; large-font options; exact original
manager placement/width/padding/clearance and scrollbar endpoint adaptation;
line/paragraph spacing, multi-digit numbering and read-only style2 appearance
(current dimming is provisional); all hover/selected/disabled/color/scale states;
complete party/listener/owner/DM and secondary-count variants; original sounds,
voice/cinematic/skip behavior, navigation beyond1–9, focus and camera interactions
over the window itself. The current360px logical panel width includes inferred
padding around original mesh bounds and still needs comparison.

The broader UI inventory, unique-menu styling and complete action audit remain
open. The historical intermittent blood-pixel failure in
`native-scrollbar-actions-accepted-v1` remains open; the passing116-action run
does not resolve that separate issue. General porting does not resume here.
