# Native transfer cancellation and destination failure

Owned-loopback tests now cover native pointer cancellation, actual destination
unavailability and retry through the displayed Connect button. Normal-client
server transfer adoption remains disabled. These results do not establish full
multiplayer, rendering or performance parity. No online game server was queried
or connected.

## Behavior and ownership

`NativeLobby` keeps joining blocked while a failed destination is still being
disposed. A successful peer-connect acknowledgement releases that specific
pending-connect barrier; later resource-loading disconnects can then recover
normally. Acknowledgements and failures from retired sessions cannot change a
new connection. `network_ipc.cjs` publishes the acknowledgement only after the
destination connect resolves and its session is still open and owned.

The native recovery probe clicks actual Cancel and Connect controls using
Godot input events. It checks that the old world is gone, cancellation advances
the connection epoch, failure explains the destination problem, the lobby is
usable again, and no cancelled destination world is admitted. Prepared private
character data is wiped on disposal. Credentials and BIC bytes never go to Godot.

The local test driver stops only the exact owned secondary fixture server after
the real source character download, waits for its UDP endpoint to disappear,
then permits the real destination connection attempt. It restores that owned
server afterwards. It refuses a foreign PID or port owner.

## Accepted evidence

- `reports/native-handoff-cancel-v3.json`: 12 native recovery checks, pointer
  Cancel at connection2, pointer retry3→4, zero destination connect calls,
  disposed destination and wiped character, joining disabled during cleanup.
  Both source and retry complete animated gameplay, 32 dialogue/examine checks
  and two server character exports. Exit0, disconnected, no retired native
  survivors and no remaining particle jobs or worker threads.
- `reports/native-handoff-failure-v3.json`: exact owned UDP5122 server stopped,
  one actual failed destination connect, 12 native recovery checks, pointer
  retry2→3. Both gameplay admissions, 32 dialogue/examine checks and two exports
  pass. Cleanup, private-character wiping and join barrier pass. Exit0 and all
  worker epochs released.
- `reports/native-handoff-local-v6.json`: successful A→B→A regression after the
  acknowledgement change, three animated admissions, 48 dialogue/examine checks,
  three exports and complete shutdown. Strict handoff evidence gate passes.
- `reports/native-handoff-recovery-backend-v3.log`: 90 passing backend, ownership,
  lobby, portal, particle and acceptance-gate tests. Tests reject early joining,
  stale acknowledgements, self-closing resolved connects and partial evidence.

Recovery screenshots were inspected: cancellation returns to the menu without
an error; failed transfer displays its destination error and usable Connect
control. This is a functional check alongside the preserved editor, not an FPS
benchmark. Installed binary hashes and fixture hashes are recorded in
[NATIVE-HANDOFF-LOCAL.md](NATIVE-HANDOFF-LOCAL.md).

Reproduce against the two owned fixtures with `test-handoff.ps1 -Scenario cancel`,
`-Scenario failure`, and the default `roundtrip`, each with an unused report name.
`tools/handoff-recovery-evidence.cjs` requires completed native checks, actual
pointer retry, correctly owned gameplay and exports, disposal evidence and final
shutdown; a timeout or partial trip is not accepted.

## Retained failures and limits

Cancelv1 reached retry but the dialogue probe was not reset for fresh joining;
it timed out and remains failed. Fresh joins now reset it unconditionally.
Failurev2 stopped the right server but saw its lingering Windows UDP entry and
aborted before acknowledgement; its failed report is retained. The driver now
waits up to eight seconds for that exact PID's endpoint to clear and fails
promptly if acknowledgement cannot be established. Cancelv2 and failurev1 were
successful before the cleanup-barrier field was added; v3 is the accepted pair.

NUI/window/token state is subsequently verified in
[NATIVE-NUI-HANDOFF.md](NATIVE-NUI-HANDOFF.md). Server-vault reference transfers
and NWSync content changes still need real owned-server checks before enabling
normal-client adoption. Public-server behavior, full migration and sustained
moving-scene 60FPS remain unaccepted. Online game-server tests remain prohibited
until the user returns and reauthorizes them.
