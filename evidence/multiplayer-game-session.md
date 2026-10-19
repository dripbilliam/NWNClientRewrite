# Multiplayer application-session admission owner

2026-10-18. The full multiplayer goal remains ACTIVE. This milestone is a
headless application-session integration, not a visible/playable client.

## Native evidence and scope

Target remains the unchanged installed NWN:EE 89.8193.37-17 client/server pair.
Client SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Server SHA256:
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.

This reuses the previously verified admission sequence: lowercase p/1/0 status,
P/1/3 resource requirements, unchanged BIC p/2/1, P/2/5 confirmation,
P/3/1 module information, p/3/2 module ready, P/4/1 area information and p/4/3
area ready. Native area handler 0x1404435a0 transitions load state 1 to 2 and
moves the player into the area. The renderer will own the completion signal;
receiving an area packet alone does not acknowledge that its assets loaded.
No original executable, live process or Ghidra project was modified.

`electron/network_game_session.mjs` now owns resource/rules resolution,
character admission, authoritative world import and explicit area readiness.
The reliable `NetworkPeer` remains independent. This owner creates no
ModuleSession, script VM, AI, local combat resolver or spell resolver. Parsed
message/state events contain no credentials, authentication packets or resolved
filesystem paths. Resource access accepts archive references/types, not paths.
It is ready for subsequent IPC attachment; no IPC/UI connection is claimed here.

Character bytes are structurally checked as BIC, copied unchanged for upload,
and cleared after the upload request is built. Server character validation
remains authoritative. Cancellation immediately closes admission/presentation,
clears pending character bytes and disposes private identity/build state.
Late asynchronous resource results cannot resume admission. A generation token
prevents a renderer acknowledgement for an old area from advancing a newer one.

## Validation

`scripts/probe-network-session-stdin.mjs` exercises this actual owner against
the existing original local server, with private stdin credentials. Its bounded
observation period and headless area acknowledgement belong to the probe;
the application session has no observation lifetime limit.

`backups/animations/local-network-session-v1.json`: successful original-server
authentication, required resources resolved, installed unchanged wizard BIC
confirmed, area entry and 33 explicit-ID proxies, PLAYER_ID 0 controlling
OBJECT_ID 0xffffffff, 43 known spells and 34 prepared slots, clean raw BNDM
logout and helper closure. All received object-update records decode fully.
The nine unsupported-envelope occurrences are recorded, covering majors/minors
18/11, 2/12, 52/3, 28/12, 9/5, 54/2, 30/1 and 18/20. No invalid/failed object
or session diagnostics occurred. These omissions remain work, not suppressed.

Focused tests cover resource/character gates, one area acknowledgement, stale
area generations, cancellation during lookup, archive-access validation,
diagnostics and the real-server capture. Renderer IPC/view/input, movement,
other message families, NWSync download and original-client concurrent gameplay
remain open. The session phase `playing` identifies completion of its admission
handshake; it does not assert that the replacement app is playable.

14 focused session/peer/player-state tests PASS in
`network-game-session-tests-v1.txt`. Client build PASS in
`network-game-session-build-v1.txt` (existing bundle-size warning). Private
source/network-evidence audit: 2014 files, zero full credential matches.

Post-seal checkpoint: `backups/multiplayer-game-session-20261018-v1.zip`,
11990 files / 195693187 bytes. Writer session 94666 completed with exit 0;
every archived length and SHA256 verified. All seven selected new source,
capture and validation entries are present; compiled executables, character/
module assets and the private server profile are excluded. This paragraph was
appended after sealing the archive.
