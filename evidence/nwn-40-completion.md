# NWN-40 browser and character-vault acceptance

The remaining defects in the existing player connection workflow are addressed.
Game-type selection now applies the native game-type ordinal to cached Internet
rows, supports All, keeps History/Favorites independent, and rejects stale or
malformed requests. Labels come from the installed GameSpyRooms table and TLK.
The table's discovery group ID is distinct from the ordinal used in server data.
The retained original `CConnectionLib` constructor and `GetStrrefFromGameType`
evidence is in `backups/animations/rea-native-server-pages-v1.json`.

Local preview and Play remain pinned to the displayed file identity, including
Workshop aliases and saved-vault revisions. Loose-file reads are bounded before
allocation, including files that grow while being read. Server rejection now
reaches the lobby with its original TLK reference, resolves natively, and clears
on a new selection or connection. Retired sessions cannot replace that state.

| Ticket requirement | Validation |
| --- | --- |
| Game-type and existing advanced filters | Native original-resource selector and filter modal; ordinal/All, stale input, cached rows, saved pages, occupancy/module/vault/password predicates and persistence tests; real server metadata through the production browser service. |
| Details, password/key/status and row activation | Original-resource Details, password modal, exact selection acknowledgments, keyboard/double-click, pagination, refresh cooldown and retirement checks; actual password rejection followed by successful admission. |
| Local/server/Workshop vault policy and unusual entries | Unicode/punctuation filenames, alias precedence and rebinding, same-size file replacement, saved revision changes, oversized loose files, stale reads, and original-server local/server-vault admission. Server-vault sessions hide and reject local choices. |
| Permitted deletion | Native pointer-driven confirmation, cancel/refuse/refresh/reselect and changed-file checks; original installed data remains intact. Remote and DM-vault deletion remain unavailable under the current player role. |
| Rejection, content failure, cancellation and reconnect | Original server rejects a level-15 preset under a level-1 limit, returns selection and its reason; a server-only HAK causes a client resource failure that can be cancelled; export/save/disconnect/reconnect and server-vault entry reach an original controlled creature. |

The final Node regression log is `.cache/nwn-40/final-node.tap` (177 tests).
Native graphical proofs are under `godot-client/.cache/nwn40/nwn40-secondary-*`.
They use a detected secondary monitor with unfocusable windows; the game-type
test explicitly checks the observed monitor and absence of focus. The live
receipt is `godot-client/.cache/nwn40/nwn40-live-v6/result.json` (36 checks).
`tools/audit-native-browser-completion.mjs` verifies the results and current
source hashes and writes the aggregate completion receipt.

The live leg composes the production browser, lobby, installed session, protocol,
discovery and vault classes against the unchanged original server executable.
Native UI/input is a separate real-engine leg. These tests do not substitute
authored acknowledgment DTOs for server outcomes. Test module/profile copies,
characters, stores and server identities are isolated from user data. Each login
is attempted once. A short observation interval separates disconnect from the
next independently launched test server; it is test orchestration, not a new
production retry policy. All owned servers stop and inputs remain unchanged.

Rejected evidence is retained: initial sandbox certificate-store failure;
headless refresh artwork readiness; an asynchronous-preview probe assertion;
an invalid empty HAK fixture; omitted protocol selection flags; and an immediate
cross-server login failure. These runs are excluded from acceptance. Later
success does not resolve the separate intermittent-admission investigation in
NWN-14.

This closes the supported player browser/vault edge-case scope. Existing-character
Customize (NWN-19), character creation (NWN-18), new DM authentication/admin tools,
hosting/LAN discovery, general crash/shutdown work, full original-client pixel/audio
equivalence, and world/rendering performance remain separate work. No claim of
complete client parity or public-server/mod coverage is made. Changes are local
and uncommitted.
