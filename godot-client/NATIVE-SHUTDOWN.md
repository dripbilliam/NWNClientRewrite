# Explicit native retirement before quit — owned-local verification

The replacement now retires its active native world and UI before asking the
engine to exit. Previously, a backend quit immediately disconnected IPC and
called SceneTree.quit with the current scene still installed, leaving its
animation, effect, particle and UI owners to final engine teardown.

`systems/local_connection.gd` now stops input/bridge updates, invalidates the
admitted world, stops probes, resets NUI/status/party/creator/browser state,
uses the normal area-retirement path, clears the custom cursor, waits for
actual queued owner destruction and reaches a rendering boundary while the
renderer/window still exist. It reports retirement counts before closing IPC.
The host allows a bounded5-second shutdown window and records forced exits.
Successful checks require a native retirement acknowledgement and exit0;
exit0 by itself cannot pass. The acknowledgement must belong to the exact
current connection, with no surviving world/NUI/party/buff owners.

This is an application lifecycle correction. The precise original C++ access
violation instruction is **not known**, and broader engine/driver stability is
not claimed. The evidence below supports the implemented retirement ordering
and its owned-local regression scope.

## Reproduction and comparison

The historical `horizon-portals-local-v2.json` failure is retained. It was
initially intermittent: a debugger rerun exited cleanly. The subsequent
`horizon-shutdown-batch-v1.json` reproduced it on the third full local A-B-A
session, with exit0xc0000005 and forced termination false. The batch stopped and
restored the ordinary server. This disproved treating shader sharing or one
clean rerun as a sufficient resolution.

After explicit retirement:

- `horizon-shutdown-retired-v1.json`:five successful local sessions.
- `horizon-shutdown-retired-v2.json`:five more, including the mandatory backend
  retirement gate. Each completes three animated admissions,14 portal checks
  and a non-forced exit0. All18 tracked world owners are released before quit;
  the tracked NUI, party and buff resource/owner survivor counts are zero.
- The batches record the exact six relevant source hashes used for the run and
  stop if those files change. The native retirement code is identical across
  the two batches; the second adds the host's explicit acceptance gate.
- `native-shutdown-normal-v1.json`:ordinary dialogue/examine16 checks, six
  retired world owners and clean exit. This initial check preceded the final
  mandatory backend gate.
- `native-shutdown-menu-v1.json`:actual Main Menu exit without a game-server
  connection or world; zero owners, two cleanup frames and clean exit under
  the mandatory gate.
- `native-shutdown-sync-v1.json` and its roundtrip child:two owned servers,
  actual NWSync/NUI A-B-A, three animated admissions,48 dialogue checks,
 48 NUI checks,45 resource hash/length checks, changed/restored authored icon
  pixels and warm return with zero HTTP downloads. Final native retirement
  releases18 world owners and tracked NUI/status/party resources. Every admitted
  particle epoch closes with zero remaining worker threads. Both retired
  backend sessions/worlds are collected while the destination is still live.
- `native-shutdown-backend-v1.log`:48 focused backend/ownership/gate cases,
  including rejection of missing/stale retirement, surviving owners, forced
  termination, a crashed exit and an exit-only false positive.
- `native-shutdown-sync-cancel-v1.json` and `native-shutdown-sync-failure-v1.json`
  plus their child reports recheck real in-flight content cancellation and
  required-data404 recovery/retry. Each passes18 pointer recovery checks,
 32 dialogue checks,31 NUI checks and two animated admissions; final quit
  releases12 world owners and all tracked NUI/status/party resources, without
  forced termination. Both loopback repositories and the secondary server close.

The original35 sky/horizon Vulkan checks,24 original-instruction material GPU
cases,24 replacement cycles/120 original model imports,570 sky-state and6468
atmosphere comparisons remain relevant: those presentation methods did not
change in this shutdown follow-up. See [NATIVE-HORIZON.md](NATIVE-HORIZON.md).

All work uses offline inputs or owned localhost servers. Ordinary GodotFeedback1
is restored by each test harness. The editor and original game installation are
preserved. This is not public-server, full migration or moving-scene60 FPS
acceptance. Precipitation/lightning, dynamic atmosphere commands, broader audio/
rendering/UI/combat fidelity and the remaining migration checklist stay active.

The verified milestone archive is `backups/native-retirement-tested-v1.zip`.
The previous `native-horizon-wip-v1.zip` and accepted `native-sky-tested-v1.zip`
remain available as historical rollback/evidence points. Acceptance covers the
original-model horizon/material work plus this owned-local retirement behavior;
it does not identify the exact former C++ fault or prove every possible shutdown.
