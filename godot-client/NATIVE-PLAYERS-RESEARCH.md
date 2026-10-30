# Player and party window — native reconstruction in progress

This document preserves the initial player-window data-plan investigation.
The subsequent [native frame and invitation milestone](NATIVE-PLAYERS-FRAME.md)
connects source controls and actual local-server actions. The entire UI goal
and general-porting restriction remain active; full player parity is open.

## Original screen and controls

Original `CGuiIngamePVPPanel` at140887570 imports `ingame_pvp`. Its shipped
13-control metadata tree consists of the root and12 children. The original
adds a constructed `CTL_IG_PLYR_LIST`, linked `CTL_IG_BTN_PVP` rows and nested
`CTL_IG_BTN_ATTIT` checkbox controls at runtime. A GUI-resource count alone
therefore omits meaningful controls and state.

The original frame is360×461. Its player-list attachment is(0,456); source
list hooks define the viewport at(1,124.9), size358×330.1. Rows have335×29 art
and source next-link spacing approximately31 pixels. Name clipping, attitude
checkbox, reaction label and scrollbar endpoints use model hooks. No Godot
container spacing is a substitute for these attachments.

Initialization140889350 binds the following icons, tooltip references and
callbacks. These are original controls, not additional replacement features.

| Control | Normal icon / tooltip | Original callback and state |
| --- | --- | --- |
| Invite | `ir_invite` /0x42b |140888a30; can switch to Kick (`ir_kick` /0x42c), or Accept (`ir_accept` /0x1051d). |
| Leave | `ir_leave` /0x42f |140888c30; invitation state changes it to Reject (`ir_reject` /0x1051c). |
| Transfer leader | `ir_transleader` /0x18ef |140889280; invitation state changes it to Ignore (`ir_ignore` /0x1051b). |
| Tell | `ir_chat` /0x104db |140889140; emits GUI event0x1c and prefills `/t "name" ` in chat. Target field namespaces require care. |
| Boot | `ir_boot` /0x1f3e |140888820; original tokenized confirmation text0x104c6 and a distinct callback. |
| Ban | `ir_ban` /0x1f3d |140888610; original tokenized confirmation text0x104c7 and a distinct callback. |
| Close | `ctl_btn_x` | Original close callback at140889340; full dismissal lifecycle remains to recover. |

Boot/Ban are removed when `GetLocalPrivileges(0x40)` is absent; disabled states
alone are insufficient. Original140888ce0 also changes button enabled state,
icons and tooltips based on selection, same-party membership, leader and
invitation state. Selected rows can emit GUI event12 against the selected
object. Rebuild1408883c0 excludes local/controlled and DM entries, preserves a
valid selection or clamps to the last row, and suppresses selection GUI events
while restoring selection. The exact underlying field meanings remain an
investigation, not permission to infer authority from a visible row.

Original update1408898b0 polls state after a one-second countdown, changes
happy/mad artwork and reaction availability, and updates invitation state.
The initial row140887b20 contains the player name, original nested attitude
checkbox, and reaction text.140889810/140889ae0 derive disclosed creature
reaction and apply original colors; unknown reaction uses grey. Raw decompiler
TLK call signatures are incomplete, so final label IDs still need instruction
inspection. A failed symbol-name search is retained in session evidence;
functions were located through the `INGAME_PVP` string and vtable instead.

## Protocol and authority follow-up

Original writer1407c3390 accepts one full object ID and an operation selector,
then sends major14. Selector0..7 maps to minors6,7,13,8,9,10,11,12; selector8
sends minor2 without a payload. Invite/Kick, party leadership, leave and
invitation-response callbacks select among these. This table is evidence, not
a completed native protocol implementation. Server-side field/privilege and
outcome checks are required before enabling controls.

The current native bridge only routes `native-player-attitude`; original
party membership replication does not by itself implement these outgoing
actions or invitation lifecycle. Preserve raw server outcomes and pending/
refusal ownership. Do not locally declare party membership/leadership changes.
Test real two-peer owned original-server invite/accept/decline/kick/leave/
transfer and disconnect/area/control changes. Privileged Boot/Ban must remain
unavailable without verified authority and require proper confirmation.

## Evidence, tests and next integration

`../backups/animations/rea-native-players-ui-v1.json` retains19 read-only
original-client dossiers with function addresses, pseudocode, assembly,
references and limitations. Target SHA is
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No live client, installed profile or public game server was touched.

`native-players-model-geometry-v1` passes9 headless metadata checks.
`native-players-layout-v1` passes27 checks against actual installed GUI/MDL
resources: main/list/row geometry, nested attachments, font/TLK metadata,
source-sized icons, active GUI coordinate/frame substitution and refusal of
missing controls/artwork. All reported full-parity/visible-frame flags remain
false. The active plan is data only and does not expose new dead buttons.

Next: recover remaining callback/authority/invitation fields, reaction TLK IDs
and row list gesture rules; implement original-compatible transport and two-peer
local outcomes; bind the native frame/selection/checkbox/help/confirmations;
then test actual isolated input, window/world behavior, content variants,
scales and direct original-client comparisons. General game porting is still
deferred. The data-plan checkpoint is `backups/native-players-plan-v1.zip`;
its separate scoped audit must not be mistaken for visible UI acceptance.
