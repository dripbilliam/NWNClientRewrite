# Native player window and invitation — scoped milestone

The Players window now uses original `ingame_pvp`/MDL framing, constructed
player rows, source icon buttons, an original scrollbar, separate local and
incoming attitudes, reaction text and party states. Actual party invitations
open their own original `party_invitation` popup. This replaces the generic
visible player panel. Full player/UI parity is still open; general porting
remains deferred under [the active goal](NATIVE-UI-PARITY-GOAL.md).

## Original layout and state

The [chat dispatch/transport follow-up](NATIVE-CHAT-DISPATCH.md) corrects an
earlier reversed interpretation of player object fields. Selection/party use
character.id (+38); Tell GUI uses current objectId (+34) and primes the original
full-character `/t` command. Earlier equal-ID local scenarios did not expose
this distinction; the current headless checks deliberately separate the IDs.

[Player research](NATIVE-PLAYERS-RESEARCH.md) retains the original constructor,
runtime control inventory and data plan. The native frame is360×461, its rows
use335×29 art with approximately31-pixel source linkage, and name/attitude/
reaction/scroll placement follows source hooks. Original GUI/TLK/font resources
are used. Active GUI roots and descendant resource references are requested
from the current catalog; stock-coordinate substitutes are not used for controls.
Source hover clips are selected when present. The current implementation is
still subject to a direct original-client visual/gesture/font comparison.

Original initialization selects the last valid row without sending selection
events during data refresh. Local/controlled and DM entries are excluded.
Actual user selection sends GUI event12 against the current controlled-object
ID. Tell sends event28 against the player's character ID and primes the quoted
`/t "name" ` chat entry. Entering a message sends channel4 with the recipient
and body, without prematurely sending chat or including that display prefix.

The original client stores two attitude slots. Receiver1407a7250 routes the
last BOOL to setters1406e1ec0 (local preference) or1406e1f70 (incoming attitude).
It does **not** clear the list. The previous decoder/storage interpretation
was corrected. The checkbox uses local attitude; happy/mad artwork uses the
other player's attitude. Original sender1407c31b0 uses character field+34,
distinct from controlled-object field+38; that session lookup is corrected.
Received updates remain separate from requests, and one player's update never
clears other players. Old capture records with the former `clear` field name
are interpreted using its actual wire meaning.

Reaction labels and colors come from original140889ae0: neutral0x1918,
friendly0x1919, hostile0x1917, unknown/Elsewhere0x1076b. Retained other-area,
removed and non-creature proxies cannot disclose an old reaction. The PvP-zone
caption uses original140887ee0 references. Source label overflow is allowed
for this caption so text is not cropped to the small stored alignment width;
full original clipping/font comparison remains unaccepted.

## Control record and authority

| Control | Native behavior verified | Remaining limits |
| --- | --- | --- |
| Player row | Original art, current identity, local selection, GUI event12 and actual server script target. Rebuild/retirement rejects old cards. | Exact native sorting/selection/scroll/key gestures and all roster variants. |
| Attitude checkbox | Original nested control and source hover; real local-server Like/Dislike changes. Separate incoming state controls face art. Same-party changes disabled. | Wider server refusal/disclosure and original-client comparisons. |
| Invite / Kick | Original icons/help and context availability; real server invitations and leader removal. | All roles, invitation limits and server-mod variations. |
| Transfer / Leave | Received membership/leader state enables source buttons; actual two-peer server outcomes. | Wider groups/associates/control/transition variants. |
| Invitation toolbar | Original Accept/Reject/Ignore icons and distinct wire operations. | Wider focus/state comparisons. |
| Tell | Original icon, event28, character target, focus and quoted chat preparation. Actual server receives its GUI event. | Complete native chat-command grammar and broader name/token variants. |
| Popup Accept / Reject / Ignore | Original utility model/buttons, centered tokenized inviter text and nested “Never show this again” caption. Distinct real party reply operations. | Full original default-key, placement/height and long/localized-text policy. |
| Popup preference | Original checkbox changes persistent **local popup visibility**, not server invitation permission or difficulty. | Wider Options/config parity and recovery controls. |
| Close / Escape | Source close control and existing front-window close policy; popup Escape uses Ignore. Positions persist. | All focus/modal/original-client states. |
| Boot / Ban | Hidden for the current unprivileged join-client context. No administrator permission is inferred from DM status. | Privilege0x40 disclosure, role/hosting availability and original confirmations/actions remain unimplemented. |

Native Godot owns every visible control, source-art request, hit test, layout
and interaction. Existing JS services only carry raw protocol/resource data
and typed validated requests. Actor, generation, target and invitation ownership
remain checked. Transport success does not claim server acceptance, change
membership/leadership, alter attitudes or retire a received invitation.
Refusals retain usable controls and feedback. Source action capture prevents
a held click from retargeting after roster changes. World-scope retirement
clears stale actions. Movement/camera input remains available outside menus.

## Evidence and tests

`../backups/animations/rea-native-players-frame-v1.json` retains16 new original
client dossiers and10 string/vtable/constant observations, in addition to the
earlier19-window and four-protocol dossiers. Client SHA is
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Evidence distinguishes original functions from implementation inferences and
does not claim to inspect the original client's live window.

`native-players-frame-input-v2` passes39 actual isolated viewport-input checks:
source proportions, roster filtering, row/checkbox/Tell gestures, refusal and
pending ownership, independent attitudes, member/leader/invitation states,
popup replies/preference persistence, source hover, retained dragging/reopening,
125% scale, stale held clicks, changed scope and outside WASD/middle/click input.
Source and live screenshots were reviewed; this is not original-client comparison.
No physical pointer capture, warp or focus acquisition is used.

The immutable owned `GodotPlayers1` module, SHA
`c1a9dffe353222dfbbd7acaac8b53ae61f3cbcdd456bba751a8403052b33c260`,
adds an OnPlayerGuiEvent observation script to the existing owned action fixture.
`native-players-frame-server-v2` passes38 checks with two real protected test
identities against original server SHA
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6` on
127.0.0.1:5125. It verifies selection12/Tell28 and the remote target account,
actual checkbox acknowledgments, distinct reciprocal attitudes, and Invite/
Reject/Accept/Transfer/Kick/Leave/Ignore/list-refresh outcomes through native
controls. Live control signals are driven programmatically; isolated checks
separately exercise mouse/key input. Existing two-peer barter48 and native
desktop41/map48/retirement13/layers16/journal45/playability1,314 regressions pass.
The packet/session/original-policy suite passes81. Test processes/workers retire
and the owned port is released. No public game-server connection was made.

Failed candidates remain retained. The reserved Node `ready` name and a test
void-return guard were corrected. Visual review caught the clipped PvP caption,
missing nested popup caption and wrong message alignment, which were fixed.
The first live frame attempt finished GUI/attitude and most party actions but
its test driver raced a membership repaint after Kick; the driver now waits
for the actual enabled/icon state before emitting the next control signal.
No failed receipt was overwritten or recast as acceptance.

`tools/audit-native-players-frame.mjs` verifies the scoped evidence, source
pins, screenshots, fixture and read-back-verified rollback
`backups/native-players-frame-v1.zip`. It deliberately leaves `goalComplete`,
`fullPlayersParity` and direct original-client comparison false. The prior
[party protocol checkpoint](NATIVE-PLAYERS-PROTOCOL.md) remains historical.

## Still open

The later [Leave correction](NATIVE-PLAYERS-LEAVE.md) removes a source-inaccurate
singleton-flag rejection during split party-list/creature updates and preserves
the selected target. It passes42 native editor/release headless checks,
62 packet/session regressions and82 authoritative local HUD/player/chat checks.
These scoped results do not replace the remaining original-client audit.

Administrator/hosting privileges and Boot/Ban confirmations; direct original
client appearance, gesture, sort, keyboard and tooltip comparison; all
enabled/disabled/default-key/focus states; long/localized/colored names/text;
exact clipping/opacity/font/placement policies; all role/disclosure/associate,
invitation-limit, error, timeout, control, transition and connection variants;
full chat and Options/config parity. The rest of the UI inventory is also
unfinished. This milestone does not grant complete player-window or UI parity.
