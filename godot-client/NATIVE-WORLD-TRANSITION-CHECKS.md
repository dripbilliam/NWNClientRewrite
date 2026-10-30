# Repeated authoritative Prelude transitions

The active goal's local transition coverage now includes three real area-door
traversals in one native client. This is scoped stability evidence. It is not
complete world/effect parity, reconnect acceptance, a controlled cold/warm test
or dense-world 60 FPS acceptance.

Follow-up: [NATIVE-SESSION-CONNECTION-SCOPES.md](NATIVE-SESSION-CONNECTION-SCOPES.md)
now verifies owned Prelude reconnects in one default native client process,
including real pending-worker disconnect and stale bridge-message rejection.
Remote handoffs and broader acceptance remain open; results below retain their
original transition-only checkpoint scope.

## Entry points and ownership

Run from the workspace with an unused report name:

```powershell
./godot-client/tools/test-native-local-world.ps1 `
  -Run unused-transition-run -TransitionCount 3 `
  -ProtectedKeyFile runtime-logs/local-multiplayer-server/native-test-key.dpapi
```

The launcher verifies the owned localhost original Prelude server, ensures the
native kernel build and preserves other applications. The test accepts 1..8
transitions; interactive inspection uses the ordinary single-transition default.
The time bound grows with the requested transition count. Private credentials
still enter through redirected stdin and are not part of the report.

`tools/native-local-world-host.mjs` remains a **temporary JS protocol test host**.
It sends decoded original server state and ordinary native input requests. It
does not prepare rendering data. Multiple-transition runs select
`tests/native_world_transitions_test.gd`, a subclass of the production live-world
entry. This test uses the real registered door and normal `world_action` callback;
the original server opens doors, moves the character and changes areas. No test
teleport, forced player position, fabricated area-ready packet or replacement
assets are used. The nearest return transition door is selected from the real
current-area registry.

Before counting a leg, the test observes a newer generation, different area,
native control readiness and complete desired-object admission. Early player
readiness is intentionally separate from full admission: an empty batch queue
between bounded batches is not completion. The game continues to allow movement
while those background objects stream. Source/DLL/build-manifest pins and four
normal-heap CDB traps cover the run. The test harness now includes the compiled
kernel inputs in its source pins instead of pinning only GDScript.

The production retirement adaptation and original binary teardown evidence are
documented in [NATIVE-WORLD-DEFERRED-RETIREMENT.md](NATIVE-WORLD-DEFERRED-RETIREMENT.md).
This increment changes the test harness/probes, not that retirement algorithm.

## Accepted run and limitations

`reports/native-prelude-three-transitions-v3.json` passed: generations 1,2,3,4
alternate between original areas 2147483649 and 2147483685. Each leg admitted all
objects: 92 entities/100 tiles, 20 entities/nine tiles, 92 entities/100 tiles.
Measured door-action-to-complete-admission durations are 2876,986,1288 ms. Those
include action/network/load work, depend on an already-running server and cache
state and are not isolated asset-preparation times or a paired speedup.

Actual server walk/WASD, equipment roundtrip, examine/conversations and inventory
reopening after generation4 pass. Final retirement totals are three retired and
three released worlds, zero pending worlds/workers, no forced drain; the largest
retire-begin time was5.261 ms. No trapped native exception or engine/lifetime
error, all source pins unchanged and exit0. Final screenshot inspected. Its FPS
counter is a small-room sample with incomplete effects, not performance acceptance.
No new public-server connections occurred.

These real transitions had no outstanding worker at retirement. The earlier
explicit blocked-worker test separately covers that path; do not pretend this
run reproduced it. Same-process network disconnect/reconnect, repeated transfer
to different server processes, large-area cold/warm comparisons and complete
effects are still required. The normal default launcher has separate local
entry evidence; this extended gameplay harness is not the default menu flow.

Retained preliminary evidence:

- `native-spawn-words-prelude-transition-v1`: successful existing one-way probe.
- `native-prelude-three-transitions-v1`: three legs completed, but the host still
  selected the old probe after a patch-helper failed to run. It records only
  the last native leg; not promoted as the final per-leg acceptance.
- `native-prelude-three-transitions-v2`: stricter test stopped at the deliberately
  early player-ready stage (one of92 entities; no object error). The probe's
  empty-batch condition was replaced with full-admission observation. This was a
  test-gate failure, not evidence of a native crash.

`tools/check-native-world-transitions.mjs` validates the final source/DLL pins,
all four admissions, three complete per-leg records, input/UI checks, retirement
totals, clean logs and protocol-only module inventory. Output:
`reports/native-world-transitions-v1.verified.json`. Its initial screenshot-path
check omitted `.native`; corrected without changing the gameplay run.

Continue [BINARY-WORLD-STREAMING-GOAL.md](BINARY-WORLD-STREAMING-GOAL.md). Full JS
migration and the final reference wiki remain ordered follow-on work.
