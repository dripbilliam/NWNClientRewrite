# Native connection ownership and reconnects

The normal client now scopes its private protocol-service bridge by connection
identity as well as area generation/ID. A real Prelude disconnect with unfinished
workers followed by three complete joins in the same Godot process passes.
This is a lifecycle correction during the active binary-guided streaming goal;
complete rendering/effects, remote handoffs and full JS migration remain open.

## Failure mechanism and implementation

Actual local joins restart area generation at1 and reuse the same original area
ID. Previously, the native bridge checked those fields but omitted connection
ownership on some messages. Retired movement/UI/raw-world messages and catalog
or snapshot acknowledgments could therefore match a later session. This was an
identified gap, not a claim that a specific historical access violation was
reproduced by it.

`native_session_world.gd` now accepts monotonic connection boundaries from the
lobby/reset coordinator, rejects retired envelopes before interpreting their
payloads and tags native commands. Per-connection movement/observation diagnostics
reset too. `tools/native-session-host.cjs` checks connection identity before
accepting world inputs, catalog/raw-snapshot acknowledgments or observations.
Retired commands are diagnosed without being forwarded to the original server.
`raw-world-frames.cjs` preserves the scope on every bounded frame while leaving
original server objects opaque and unchanged. Menu and final handshake messages
retain their separate lifecycle roles.

These connection fields belong to the authenticated localhost bridge, **not to
original NWN server packets**. No original wire format is extended. The JS
protocol service remains temporary; no JS rendering/resource/UI preparation is
introduced. Existing actor/terrain/asset/retirement owners remain native.

## Original binary evidence

Read-only target: NWN:EE89.8193.37-17 x64, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Complete analyzed `CNetLayerInternal::DisconnectFromSession` body is
`140239f60..14023a016`. Its selected-window field+28a56d8 must differ from-1 and
active field+28a5698 must be nonzero. It calls SendBNDM at140239f89, then rechecks
both fields. When still active, it notifies interface+80 at140239fa9, calls
`CNetLayerWindow::ShutDown` at140239fc3 and invalidates the selected index at
140239fc8. Presence cleanup follows. The bridge fence is a Godot lifetime
adaptation; these instructions do not prove an identical original bridge token.

The complete selected shutdown-reason wrapper140254e80..140254ebf records reason
and text, then delegates to interface+40. Its indirect target remains unresolved;
do not claim the complete application logout implementation from this wrapper.
Dossiers in `../backups/animations`:
`rea-native-session-disconnect-v1.json` and
`rea-native-client-shutdown-reason-v1.json`.

`../scripts/inspect-native-session-disconnect.py` executes the unchanged183-byte
disconnect coordinator on270 cases. Eligibility, post-send mutation/recheck,
notification/shutdown ordering, index invalidation and optional presence branches
are observed. BNDM transport, interface notification, window shutdown and presence
services are explicit lower providers, not actual network/crypto execution.
Output: `../backups/animations/native-session-disconnect-v1.json`.

The send argument is loaded from the named `_INVALID` global, whose PE initializer
is0xFFFFFFFD, distinct from the selected-index sentinel0xFFFFFFFF. The fixture
also supplies explicit alternate words to verify forwarding. Its initial
assumption that both sentinels were-1 failed before producing observations and
was corrected; startup initialization/packet semantics are not inferred from
these fixture globals.

## Actual default-client checks

```powershell
./godot-client/join-native.ps1 -LocalCheck -LocalCycles 3 `
  -LocalStreamAbort -Debugger -Run unused-local-reconnect-run
```

Repeated cycles and streaming-abort modes require the owned local check; the
launcher/host reject their use as automatic public-server tests. The abort probe
presses the native Disconnect button with export disabled, exercising the normal
NativeLobby leave/peer disconnect path. A bounded test-only two-second interval
allows server-side disconnect processing before the next join. This does not add
a delay to normal user joins. The same installed wizard and existing protected
login are used without logging the private key.

Accepted current reports:

- `native-session-stream-reconnect-v2`:Godot PID30412 for the aborted connection1
  and complete connections3/5/7. Each has area generation1. Disconnect was
  requested with one of19 entities admitted, two batches pending and six
  unfinished workers. Two were still unfinished when deferred world retirement
  began; the difference is work completing between observations. Afterward,
  three complete20-entity/nine-tile joins each show native and independently
  replicated server movement1.500033 m. First-playable times1395.471,1397.864,
  1425.200 ms reflect existing caches/server state, not controlled cold loads.
- The host injects explicit **test** envelopes from each retired bridge scope:
  reset, setup, an invalid raw header and UI close. Native processing rejects
  all12 before payload handling. Native probes send old-scope walk, catalog ack,
  raw-world ack and observation commands; the host rejects all12. These are
  lifecycle probes, not claimed captured original-server packets.
- Three worlds retire/release; no forced drain, no pending worlds/workers at
  shutdown. Cache bindings are zero after final release. Completed joins create
  no further pooled resources after the first completed visit:277 meshes,
  45 textures,53 materials,13 templates; hits continue to grow. Screenshot
  inspected. The49 explicit effect failures remain unchanged.
- `native-session-reconnect-default-v2`:ordinary single-join default entry,
  player-first readiness and authoritative movement while objects still stream,
  final20 entities/nine tiles, acknowledged finish and clean shutdown.
- `native-session-reconnect-menu-v2`:ordinary headless menu check with no server
  connection. The updated connection envelopes do not break startup.
- `native-reconnect-protocol-tests-v1.tap`:58 existing/extended raw framing,
  lobby, peer-lifecycle and game-session tests pass. These use fixtures/mocks,
  separately from the live original local server checks.

Native runs use normal-heap CDB with four armed traps, unchanged pinned inputs,
no trapped exception or engine/lifetime error and exit0. No public connection
occurs. Earlier reconnect-v1/v2 and stream-reconnect-v1 reports retain their
incremental source scope; final stream-v2 adds per-cycle process identity.
`tools/check-native-session-reconnect.mjs` audits the three current report sets,
original cases, private-bridge negative probes, cache/worker cleanup, source pins,
module inventory and test log. Output:
`reports/native-session-reconnect-v1.verified.json`.

Remaining limits:remote server handoffs; cancellation during catalog discovery
or before character/terrain admission; broader modules/characters; complete
effects/culling; clean dense cold/warm/full moving replay and60 FPS. The local
session still diagnoses unsupported server message major18/minor20 once per
connection, including the aborted join; its meaning is not established here.
Native shutdown faults are not globally declared resolved. Continue the ordered
goal before treating full migration or the final reference wiki as complete.
