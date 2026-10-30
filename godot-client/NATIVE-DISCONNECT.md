# Connection cancellation and disconnection

Implemented 2026-10-25. Verified against the owned localhost Prelude server;
no Arelith or other public server connection was made.

## Player controls

- Main Menu → Disconnect leaves the active game without requesting an optional
  local character export. Server-owned character persistence remains authoritative.
- Cancel connection interrupts preparation, login or server resource downloads.
- Back in the server browser cancels its pending connection or server query.
- Back from a loading screen cancels the connection even while character upload
  or area loading is busy. Escape cancels the pending connection/loading view.
- Optional Save character when disconnecting appears only for admitted local
  characters. An export failure reports that saving failed and still disconnects.
- A server disconnect retires the world and returns to server selection, keeping
  the server's reason visible. Reconnecting gets a fresh connection scope.

## Ownership and implementation

`tools/native-command-pump.mjs` gives connection controls an independent lane.
Previously the single command queue awaited a login handshake for up to 45 seconds
before it could execute the Cancel command. Ordinary game actions remain ordered.

`tools/native-lobby.mjs` invalidates ownership before closing the old session.
Its AbortController releases pending join callers without waiting for filesystem
preparation. The factory checks cancellation before publishing a prepared session;
a late preparation cannot attach to a newer login. Disconnect targets the captured
session rather than whichever session happens to be current later.

`electron/installed_network_session.mjs`, `electron/server_browser.mjs` and
`electron/network_abort.mjs` propagate cancellation through resource preparation
and server queries. `electron/network_peer.mjs` immediately closes a peer that has
not completed admission. An admitted peer retains the protocol disconnect packet.
The browser also aborts discovery/query work on retirement.

`native_session_world.gd` retires world/input owners immediately on a local
disconnect request and rejects late world/setup messages, including messages in
the old connection before the host acknowledges its new scope. Asynchronous game
command responses retain their original connection. The browser's own connection
counter advances with the lobby so it can accept subsequent views and reconnects.
Catalog workers retire under their own bounded retirement owner; they cannot
publish a completed catalog into a new connection.

## Evidence

- `reports/native-disconnect-node-v3.log`: 56 passing lifecycle, cancellation,
  browser, resource-progress, transfer-coordinator and peer regression checks.
  Includes blocked preparation, Back followed by reopening, stale attachment,
  pending character upload, real loopback query cancellation and peer cancellation
  while login preparation is blocked.
- `reports/native-disconnect-ui-v2.debugger.json`: 11 native UI/ownership checks,
  normal heap, four exception traps, unchanged sources, no engine/lifetime errors.
- `reports/native-disconnect-local-v1.json` and `.native.json`: cancelled a real
  pending loopback login, then streamed Prelude, disconnected with three world
  workers still active, and completed two subsequent gameplay cycles. The native
  Cancel probe to closed-peer interval was 2.53 ms in this run; this is a functional
  sample, not a universal latency guarantee. Both gameplay cycles confirmed
  approximately 1.5 m movement in native presentation and authoritative state.
  Zero public connections, zero remaining workers, clean finish acknowledgement,
  no debugger exception, and unchanged sources. Old connection/input probes were
  rejected. Existing particle-intersection warnings remain outside this change.

Reproduce the integrated functional check with the owned Prelude server running:

```powershell
.\godot-client\join-native.ps1 -LocalCheck -LocalCycles 2 -LocalStreamAbort -LocalCancelCheck -Debugger -Profile -Run native-disconnect-local-NEW
```

The cancellation fixture binds an ephemeral loopback UDP sink and explicitly
allows that endpoint only for this test. It does not enable public servers.

Source backup before changes: `backups/native-disconnect-before-v1.zip`.
This change does not complete the remaining native migration or direct native
cross-server handoff integration.
