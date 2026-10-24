# Cross-server handoff — ownership foundation, not enabled

This historical ownership-foundation note is followed by the real local
round-trip milestone in [NATIVE-HANDOFF-LOCAL.md](NATIVE-HANDOFF-LOCAL.md).
The native hook is now available in an explicit local regression mode;
normal-client handoffs remain disabled. The original findings below are retained
as development history, not the latest integration status.

The preceding scene/atmosphere milestone is `NATIVE-ATMOSPHERE.md`. This next
batch hardens session and native lobby ownership but **does not enable native
cross-server connections**. `tools/local-host.cjs` still rejects its portal
prepare hook. No online game server was connected or queried. Testing used
in-process authored sessions and the ordinary owned localhost server.

Changes in `electron/network_ipc.cjs`:

- Track the prepared destination while an optional native adoption hook waits.
  Cancel/disconnect or frame destruction disposes that session immediately;
  resolving or rejecting the late hook cannot connect it or remove a newer
  owner. Old-frame commands/messages remain rejected by the existing identity
  checks. The hook still finishes before destination connect starts.
- Optional `onPortalFailure` lets native presentation recover from hook or
  destination-connect failure. It receives private backend objects only.
  A destination can close itself inside a failed connect; the portal-connect
  latch preserves the exact owner until failure cleanup completes. Latches are
  keyed by session, so overlapping handoff completion cannot clear a newer one. Ordinary
  connection closure still releases its owner normally. Diagnostics remain
  generic and do not expose portal credentials or downloaded characters.

Changes in `tools/native-lobby.mjs`:

- Keep transfer cancellation available while the old server is released,
  no destination is attached, destination connection/resource work is pending,
  or required content fails. An unrelated join cannot race into this interval.
- Advance only the exact closed, handoff-ready old session, clear old selection
  and previews, and increment native connection ownership. Attaching the next
  session releases the temporary busy latch without losing transfer cancellation.
- Complete/fail/cancel releases the transfer latch. Late origin state cannot
  mutate the new lobby. Character selection/creation stays blocked during a
  portal login so a user cannot replace the handed-off character accidentally.
- Preserve the pre-existing rule that ordinary disconnect keeps the lobby busy
  until asynchronous cleanup completes; a terminal state alone cannot admit
  another login.

Evidence: `reports/native-portal-ownership-v4.log` has **69 passing tests**:
new async native-hook races and lobby barriers plus existing IPC, portal-wire,
identity, character handoff, frontend replacement and lobby tests. The original
wire oracles in `test/network-portal.test.js` remain read-only, bounded evidence;
fake sessions are not proof of an actual native-server handoff.
`reports/portal-ownership-local-v1.json` passes real localhost animated admission,
movement and **16 dialogue/examine checks**, clean disconnect/native exit0 and
no renderer/native errors. The last additional selection barrier is covered by
the final unit suite; it does not change ordinary admission behavior.

## Next integration work

1. Split native session preparation from presentation-service installation in
   `tools/local-host.cjs`. Keep its current persistence checks, NWSync handling,
   user settings and protected identity ownership. A prepared destination must
   not replace global native services while the old server is still active.
2. Check destination endpoint policy **before** invoking installed-session
   preparation (which can query server information). Clone the existing login
   identity with `forPortal(password)`, retain the transmitted waypoint/seamless
   sentinel, and use the proven43/1→43/2 or43/3 handoff. No credentials/BIC go to
   Godot. Default test policy remains localhost5121; opt in only another owned
   loopback endpoint for the two-server fixture.
3. In the adoption hook, validate prepared/old-session/native connection tokens,
   call `lobby.advancePortal`, invalidate the world transfer ticket, drain old
   native/bridge work and retire particle, UI, NUI, action, text, buff/party,
   content and visual services. Resume isolated resource staging for the new
   frontend epoch, then install the new session before connect publishes state.
   Native lobby connection changes already reset native world/UI owners.
4. Track/await asynchronous service installation during cancellation so a late
   cleanup cannot overwrite services of a new login. Rebind character persistence
   to the **new session and native connection**; reusing the old factory's export
   closure would reject destination saves. Hook failure must call `failPortal`
   only for its still-current native connection.
5. Build authored ActivatePortal fixtures on two owned loopback servers with
   separate profiles, publicserver0, and pinned installed server hash. Exercise
   actual character transfer, authoritative arrival/waypoint, animated gameplay,
   text/NUI/persistence, return handoff, cancellation/failure/reconnect and zero
   retired-owner survivors before enabling this path. No public-server test is
   authorized until the user returns and reauthorizes it.

Full migration and moving-scene performance goals remain active and incomplete.
