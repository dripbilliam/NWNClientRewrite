# Native area-map frame and notes — scoped milestone

The area map now uses the original generated `PNL_MAPGEN_%dx%d` frame and
original zoom, pin, close and pan artwork. The note editor uses `map_pin_text`
with its source font, original OK/Cancel/Delete controls and content scrollbar.
This replaces the generic visible map. Full map/UI parity remains open and
general porting stays deferred under [the active goal](NATIVE-UI-PARITY-GOAL.md).

## Original evidence and ownership

[Initial research](NATIVE-AREA-MAP-RESEARCH.md) recovers the generated frame,
three zoom levels (8/16/32 pixels), original marker/icon models and coordinate
conversion. The data plan matches 576 original frame decisions and 108 float32
coordinate observations from unchanged original instructions.

`../backups/animations/rea-native-area-map-followup-v1.json` retains 15 further
read-only function dossiers tied to original client SHA
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The constructor selects the middle zoom. The cap command at140892470 can set
caps with maxima21×24; examined cap writes do not establish viewport resizing.
The native frame uses those initial caps. Marker following uses the original
central20% region. Pan geometry uses source vertex poses and original range
arithmetic; exact original pointer gesture comparison is still outstanding.

Original server-side handler code present in the client confirms note protocol
and storage policy. It is separate from the actual owned `nwserver.exe` checks;
we do not claim those client dossiers disassemble the server executable.
The note editor retains the source title, “Edit pin text,” including new notes;
140893b60 imports that caption without replacing it for Add.

Native Godot owns presentation, hit testing, input, source-art preparation,
clipping, zoom banks and editing. Existing JavaScript transport services only
validate and encode protocol requests/decode replies. There is no JS map renderer.

## Control and outcome record

| Control/action | Behavior and evidence | Remaining limits |
| --- | --- | --- |
| Zoom In / Out | Original three levels, endpoint disable states, generated frames and separate source tile banks; pin artwork keeps native size. Actual isolated button input passes. | Direct original-client all-scale comparison. |
| Pan / player follow | Original pan models and pose/range geometry, source horizontal orientation, native drag, central20% following. | Exact rail gesture and subpixel hook/opacity comparison. |
| Server map pin | GUI53/1, WORD7, WORD0, full target ID, build-gated zero vector. Actual original server OnPlayerGuiEvent receives type7 and authored target. | Wider server scripts/roles. |
| Personal pin | Opens source editable/deletable note with received unsigned reference and text. | Original-client mixed-session comparison. |
| New pin | Real source drag/drop onto exact-one explored tiles; original float32 map-to-world conversion; Delete hidden. | All edge gestures/localizations and original preview comparison. |
| OK Add |32/2, three floats and CExoString. Transport send leaves pending; matching received32/4 Added supplies actual identity/coordinates. Duplicate identical requests cannot consume one reply twice. | Original protocol has no request ID in Added; identical remote changes cannot be distinguished beyond received identity/text/position. |
| OK Edit |32/5, original position/text and reference. Sent presentation stays separate and marked unconfirmed; raw received notes remain intact. Actual server script confirms stored new text. | Ordinary Edit has no reply; receipt cannot invent one. Later received matching content reconciles the local overlay. |
| Delete |32/3, received reference. Local sent overlay hides the pin separately; original server script confirms destroyed stored text. | No ordinary Delete reply; a later received removal retires the overlay. |
| Cancel / Escape | Close editor, keep received state and emit no gameplay action. Escape applies only to the front native editor. | Wider focus/modal/default-key comparison. |
| Close / reopen | Close editor/map; retain profile position. Stale closed-view callbacks cannot act. | Full transitions, reconnect/import and runtime cap changes. |

All requests validate current generation, area and controlled actor. Hidden or
undisclosed pins, unexplored drops and attempts to relocate edited notes are
rejected before send. Refused transport leaves editor text and feedback intact.
Uncertain Add disables duplicate resend, allows cancellation and can still
complete from a late matching Added. Scope retirement clears pending/local
presentation; raw server state is never replaced with claimed success.

## Verification

`native-map-frame-input-v1` passes48 actual isolated native-input checks,
including typing, long-note caret scrolling, cancellation/refusal/pending,
duplicate reply ownership, received reconciliation, zoom/pan,125% scale,
dragging/profile placement, close/reopen and world WASD/middle/outside input.
No physical pointer movement or capture is used. Native and live screenshots
were reviewed; this is not a direct original-client screenshot acceptance.

The authored immutable `GodotMap1` module has SHA
`6db130f83841a972216421d2c433fd81887cd4e7be3ff16d7c6439bf7b062b61`.
It adds a waypoint and scripts to the owned baseline, using original server
APIs for exploration, map enable, GUI event feedback and stored personal-note
inspection. `native-map-frame-server-v2` passes20 checks against loopback5125.
Original server SHA is
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
The existing116 action and17 journal lifecycle checks also pass on owned local
servers. All test workers/processes retire and the isolated port is released.

`native-map-frame-protocol-v2` passes54 local packet/session/captured-area
tests. Its first run had one sandbox denial reading installed campaign data;
the authorized read-only rerun passes, with the failed receipt retained.
Source-pinned native regressions cover the705-check map plan,13-model metadata,
compile, desktop, journal, conversation, spell preparation, retirement, fonts,
party/health, resize, quickbar, window layers and playability. Reports are
retained under `reports/native-map-frame-*` with debugger/source proofs.

Earlier failed candidates remain retained: initial parse/type/lifetime issues,
pin-source drag accidentally panning, invisible edit-anchor rasterization and
long-note caret timing were corrected and retested. No failed receipt was
overwritten or relabeled as passing.

`tools/audit-native-area-map-frame.mjs` checks the scoped receipts, source pins,
original evidence, screenshots, protocol proof, fixture and verified rollback
archive `backups/native-area-map-frame-v1.zip`. Its acceptance deliberately
leaves `goalComplete` and `fullMapParity` false.

## Still open

Direct original-client appearance and gesture comparison; DM teleport/role
branches and availability; minimized/runtime-cap policy; exact pan-rail and
horizontal-hook behavior; large fonts/localizations; personal-note persistence
across area reload/reconnect and mixed native/replacement clients; all changed
control/area/connection states; original tooltips/sounds. Source-art screenshots
and scoped passing tests do not close these gaps. The historical intermittent
blood-pixel issue and other UI inventory gaps also remain open.
