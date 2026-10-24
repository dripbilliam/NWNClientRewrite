# Native server-requested handoffs enabled

Normal Godot sessions now install `NativePortalAdoption` without a test flag.
A server-requested transfer follows the existing character download/reference,
source release, destination identity/login, resource admission and native world
installation path. NUI, character persistence and resource work use the new
connection owner. The local launcher retains its endpoint restriction; explicit
public browsing retains its user-selected policy. Enabling this hook does not
initiate a connection by itself. No online server was queried or connected in
this work, and public-server acceptance is still pending user reauthorization.

This activates the locally verified feature; it does not complete the full
Godot migration, every multiplayer case or sustained moving-scene60FPS.

## Validation before activation

The rollback checkpoint `backups/native-sync-recovery-tested-v1.zip` contains
the still-disabled hook with verified combined destination-content recovery:
539 source files, SHA256
`672b9e30780a20d9e592b1bf7c119b36820d90799598df70f5ddffbe48129a05`.
See [NATIVE-SYNC-RECOVERY.md](NATIVE-SYNC-RECOVERY.md) for actual pointer
cancellation/failure/retry, private BIC wiping, disabled early admission and
retirement, including the retained initial gate failure. Earlier local evidence
covers both source2/17 server-vault references, ordinary BICs, source/destination
waypoints, NUI callbacks/token reuse and changed NWSync data/images/cache return.

## Activation and backend lifetime fix

`tools/local-host.cjs` now binds adoption for every native session; the smoke
flag controls regression probes only. Preparation still checks endpoint policy
before identity cloning or server-info queries. Existing IPC owner rotation,
late-result/cancel fencing, native connection epochs and resource admission
remain unchanged. `tools/session-endpoint.mjs` now describes that actual policy.

A live backend lifetime check found an additional retention issue after native
scene owners had already retired. The destination's diagnostic callback retained
the origin predicate, which closed over the old source session/world. Resource
config also forwarded the initial IPC diagnostic callback into destinations.
`tools/preparation-diagnostic-scope.mjs` now releases the origin predicate when
preparation completes or is cancelled; later diagnostics require the installed,
open session and matching connection. Sanitized portal config no longer forwards
the original diagnostic callback. The normal source's callback remains available
during its own preparation.

`reports/native-handoff-origin-before-v1-roundtrip.json` is a retained failure:
the entire three-admission NUI/NWSync trip completed, but explicit backend GC
showed both retired sessions and both old worlds still reachable while the new
destination remained live. `native-handoff-origin-after-v1-roundtrip.json` repeats
the actual trip after the fix and reports both old sessions/worlds collectible.
The corresponding outer `native-handoff-origin-after-v1.json` also requires
completed cold HTTP requests, zero-request cached return and closed repositories.
This is measured session/world lifetime, not proof of full backend heap parity.

The explicit `--native-origin-gc`/`-OriginGc` path is restricted to local handoff
regressions and requires the test-only V8 GC flag. It is never enabled in normal
play. GC and the preserved editor make those runs unsuitable for FPS acceptance.
The authored4MiB production-helper probe in
`reports/preparation-diagnostic-lifetime-v1.json` independently finalizes its
origin while keeping the destination/scope live; it does not replace live proof.

## Final local evidence

- `native-normal-handoff-binding-v1.json`: ordinary native startup without a
  handoff-test flag records the enabled binding, actual animated local gameplay,
 16 dialogue/examine checks and clean shutdown. The binding is recorded with
  `regression:false`.
- `native-handoff-origin-after-v1.json` and child: the enabled ordinary binding
  completes real A→B→A, three animated admissions,48 dialogue and48 NUI checks,
 45 resource hash/length checks, changed/restored native texture pixels, old
  unique resources unmounted, three scoped saves, all old native owners/workers
  retired, and collectible old backend sessions/worlds. All three bindings are
  enabled. Endpoint policy is still enforced before network preparation.
- `native-sync-cancel-enabled-v1.json` and its child: destination content
  cancellation after activation and lifetime fix,18 pointer recovery checks,
 32 dialogue checks,31 NUI checks, source/retry gameplay and cleanup.
- `native-sync-failure-enabled-v1.json` and its child: real required-data404
  failure, explanatory native content state, pointer Cancel/Connect and the same
 18+32+31 recovery/dialogue/NUI checks after activation and lifetime fix.
- `native-handoff-enabled-backend-v1.log`:183 passing focused backend/ownership/
  NWSync/NUI/vault/recovery/preparation-scope cases.
  `native-handoff-enabled-endpoints-v1.log`:3 additional endpoint-policy cases.

Native success gates require actual animations, dialogue, canonical callbacks,
resource/HTTP evidence, private character cleanup, stale-input rejection,
retired owners and final exit0/disconnectedtrue. A socket login or partial trip
cannot substitute. Expected stale NUI close attempts are counted explicitly;
additional rejected inputs fail acceptance. The original main/dist sentinels,
original native binaries and editor are preserved. The ordinary GodotFeedback1
server is restored; secondary game and HTTP fixtures are closed.

Screenshots were reviewed for the content failure/cancel controls and destination
menus. Those sparse authored scenes retain existing atmosphere/particle/fidelity
gaps. Current work still needs broader public-server/device/content coverage,
remaining UI/rendering/weather/combat/audio/single-player migration and complete
moving-world performance validation. The feature inventory remains866 modules
and747 test files; no migration row is silently dropped or marked fully complete
by this handoff milestone.
