# Original party protocol — verified local foundation

Native requests can now invite, accept, reject, ignore, transfer leadership,
kick, leave and refresh the party list using the original protocol. The actual
two-player original-server lifecycle passes. This is a protocol foundation;
the visible Players window remains generic and the new actions have not yet
been connected to its original-resource frame at this historical checkpoint.
The later [native player frame](NATIVE-PLAYERS-FRAME.md) connects source controls
and invitation UI, with further local-server validation. Full player/UI parity is open.

## Wire and authority

`src/network_party_input.js` implements the original1407c3390 writer policy:
major14, minors2/6/7/8/9/10/11/12. The list request has no payload; other
operations carry one full client OBJECT_ID, never a PLAYER_ID. Server handler
14045b4a0 validates and performs actual membership/leadership changes. Leave
reads the wire target but acts on the requesting player. No client-side party
simulation or local success/membership edits were added.

`NetworkGameSession.partyInput` checks current controlled actor, area and
generation, resolves selected PLAYER_ID through the latest received player
list, and checks the current target identity. Kick/transfer require received
membership and leadership. Replies require the pending inviter from the
controlled creature's actual party fields. Missing/invalid permission fields
cannot authorize requests. Received BOOL values are numeric0/1; compatible
boolean representations are accepted explicitly without string/null coercion.
The original server remains responsible for admission, refusals and outcomes.

An accepted transport result says only `sent:true,serverAcknowledged:false`.
Party lists, leader flags, pending invitations and server feedback arrive
through the ordinary receive path. Request correlation retains actor/scope
ownership through the native bridge; it is not a server acknowledgment.

The original party Invite sender14/5 is a stub in this binary. Actual invitation
text uses the general popup writer1404dee90: popup type1 sends36/3 with just a
CExoString. We now decode that message as `party-invite-notice`. Its name and a
local receive serial are retained separately from the controlled creature's
pending/inviter fields. A popup does not create membership or invent a target.
Connection reset clears the notice. Native full/delta headers forward the
notice and party-list receive revision; both are provenance, not game rules.

## Original evidence and owned test

`../backups/animations/rea-native-players-protocol-v1.json` retains four
read-only original-client dossiers for the shared server dispatcher, original
invitation setter, stub Invite sender and popup writer. These are tied to
client SHA `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
They are not described as disassembly of `nwserver.exe`; the actual server
checks are separate. The preceding19-window dossiers and resource plan remain
in [the player-window research](NATIVE-PLAYERS-RESEARCH.md).

`tools/test-native-actions.ps1 -Players` uses the existing owned two-peer
harness and immutable `GodotActions` fixture, SHA
`0ca076e61104c4759991a73de6df9d8f92f4742c7b779557a1d03c59ab537b1d`.
Only this scenario adds `-oneparty 0`, so that actual independent groups can
exercise invitations and leadership. Read-only original-server strings and
SHA are retained by `inspect-native-party-server-options.mjs`. Server SHA is
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
Both keys are supplied through current-user-only protected pipes; they are not
written into test receipts, command lines or backups. Manual clients remain
untouched. Endpoint policy permits only the owned127.0.0.1:5125 test server.

`native-players-protocol-server-v1` passes21 checks, including two real peers
starting separately, recipient invitation fields and actual popup text,
Reject, a fresh invitation/Accept, both updated member lists, original leader
flags, transfer, new-leader Kick, rejoin, Leave, peer-initiated invitation,
Ignore and an explicit refresh receiving a new server list. These requests
currently come from the native typed test driver, not finished player-window
button gestures. No physical input or pointer capture/warp is used.

The first candidate correctly failed because default server settings grouped
both clients automatically. Original-server option strings established the
correct `-oneparty` switch. The second candidate completed the whole group
lifecycle but failed its explicit refresh observation: the native UI projection
dropped the new receive revision. Both full and delta projections now retain
it; candidate3 and the final source-pinned run pass. Failed receipts remain.
Live numeric BOOLs also exposed strict-boolean assumptions, corrected and
covered by actual numeric fixtures plus unknown/mistyped-field rejection.

## Regression, checkpoint and remaining work

`native-players-protocol-packets-v1` passes78 source-hashed local tests,
covering new party input, malformed popup messages, full target widths, stale
ownership, permission/refusal paths, unchanged received state, existing map,
HUD, session and original party/command observations. Native desktop41,
map48, retirement13 and playability1,314 checks pass. The existing two-peer
barter regression passes48 checks after the shared peer harness additions.
Original local sessions shut down cleanly with zero workers remaining and
the isolated port released. This does not claim performance or full UI parity.

`tools/audit-native-players-protocol.mjs` verifies these scoped receipts and
the read-back-verified rollback `backups/native-players-protocol-v1.zip`.
Every complete-player-window and goal-complete flag remains false.

Next connect the tested original frame/row plan to actual native controls,
recover selection/Tell GUI events, invitation/leader button states and
tooltips, row checkbox/reaction behavior, source scroll/help controls and
original role-gated Boot/Ban confirmations. Privileged actions are not exposed
by this protocol foundation. Then exercise real button input and local-server
outcomes, original-client comparisons, fonts/scales, pending/refusal/reentry,
control/area/disconnect changes and other roles/content. General porting stays
deferred until the complete UI audit passes.
