# Original client world admission: investigation in progress

Target: read-only NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binaries/assets and the existing Ghidra database remain unchanged.
Fresh REA uses an ephemeral immutable import, Ghidra12.1.4. Evidence is derived
analysis/instruction observations, not copied game assets or a live public test.

## Mapped paths and evidence

| Boundary | Original function/call site | Current observation |
|---|---|---|
| Module/scene bootstrap | Handler1407a4d30, calls1407a4e7e→1407cffb0 and1407a4e86→1407cd2c0 | Module/camera/area construction has its own failure/status UI. This is not the whole join lifecycle. |
| Received area admission | Handler14076d910, call14076e315→LoadArea1407dba70 | Original ClientArea receiver and scene loader are separate from later object messages. Existing packet evidence remains in complete-client-area-client-identity.md. |
| Area/tile creation | LoadArea1407dba70..1407dea0e;1407dd0c2→850110 and1407dd119→84ef10 | Reads tile state, applies it, attempts original tile scene loading, and releases area scene/tile state on failed required creation. Exact lower resource scheduler remains open. |
| Responsive load loop |1407dcfb7 compares50000 µs;1407dcfc7 compares15000 µs;1407dcfeb→UpdateScreen1400451c0 | Separate timer-triggered update flags; final tile also requests an update. Godot should retain cooperative frame/network service rather than copying a nested native UpdateScreen call. Exact original flag semantics remain open. |
| Connection gate |1407dd03b→CNetLayer::GetClientConnected1402376a0 | Checked inside the tile-loading loop; disconnect leads to area cleanup rather than continuing construction. |
| Held model priority | SwitchWeaponEvent14080e9d0, existing220 original cases | Controlled model priority2, remote4. Routing is already independently documented in multiplayer-held-equipment-investigation.md. Scheduler enforcement remains to be traced. |
| Missing attachment part | Gob::AttachToObject14008c540..14008c6eb; missing branch14008c594→14008c6c7, clear call14008c6cf | Missing parent/part clears behavior and returns null without scene adoption. Wield14099d340's virtual98 call does not abort the creature on that return. |

Fresh dossiers: `backups/animations/rea-world-join-bootstrap-v1.json`,
`rea-world-stream-wield-v1.json`, `rea-world-stream-gob-attach-v1.json`.
Complete new area pseudocode is `native-world-area-loader-rea-v1.txt` (70307
UTF-16 code units, all three REA pages consumed). Retained parent REA evidence
is `ev_f95eaa0a0bafbeb7b15f37558791794c8c2a1933dffefee3b9c58131537cf941`.
Its complete dossier exceeded transport budget; it was not treated as missing or
silently truncated. Existing full assembly is
`backups/animations/native-client-area-load-message-asm.txt`.
`scripts/inspect-native-world-join-loading.py` independently checks the listed
11 exact original instructions and refuses an unexpected binary hash.

## First implemented correction

`native-session-1792920068197` intentionally exits1 because a remote creature
requests `lhand` on a model with no such physical Part. Controlled ID4294965453
differs from failed ID4294965096. Failed batch model names include `c_direrat`,
`c_minowiza` and `it_torch_000`; the report does not retain that creature's full
raw equipment state, so a specific original model combination is not asserted.

Native `actor_instance.gd` now excludes only P/Q held-equipment pieces whose
named physical anchor is absent. It keeps the original creature and other valid
equipment, compacts model/rig indices consistently, records each unattached item,
and propagates those diagnostics into creature-stream warnings. It fabricates no
anchor/root placement and changes no inventory or server state. Missing required
body-part anchors and corrupt model preparation still fail. This implements the
observed missing-anchor admission behavior; it does not yet port every original
Wield animation/attachment state or generic background-error recovery.

`inspect-native-world-attachment-admission.py` executes the complete unchanged
Gob body on168 cases, including126 missing-part/null-parent cases. Named-part
lookup, world-pose getter, allocator, five behavior constructors, setter and
SetScene are explicit captured providers, so lower lookup/pixel parity is not
claimed. `native-world-attachment-admission-v1.json` records all cases.

`native-equipment-anchor-v2` passes145 native checks with those original results,
an authored missing-middle/valid-later equipment graph, required-body failures,
and actual local catalog models from the failed batch. Both original creature
models have no lhand; they retain20/30 meshes and do not publish the torch at an
invented location. GPU screenshot inspected: authored triangles plus original
rat/minotaur rest models. Maps in this fixture are empty, so its rest pose does
not establish full animation parity. The first attempt v1 lacked Workshop/NWSync
and failed on the unavailable custom minotaur; retained as failed evidence.

`native-session-world-methods-attachment-v1` passes the default native launcher
against owned local Prelude: player ready at1444.324 ms, native and server movement
both observed during background streaming, eventual20 entities/nine tiles,
finish acknowledgment, workers0 and clean exit. GPU/native/local checks use
normal-heap CDB, four traps, unchanged sources and no trapped native or
engine/lifetime error. No new public connection was made.

## Remaining research and acceptance

The loading-screen and completed-owner-disposal follow-up is recorded in
[NATIVE-LOADING-SCREEN.md](NATIVE-LOADING-SCREEN.md), including exact original
screen entry points, the current reveal policy, Ctrl+Shift+L, two rejected empty
tile meshes, worker disposal measurements and scoped local validation.

The full join/streaming phase is not complete. Trace bootstrap/admission/ack timing
through the complete receiver and module update; resource-demand priorities,
cache eviction, asynchronous completion, visibility/culling, object-update and
delete queues, incremental construction, attachment teardown and cancellation.
Add original-code comparisons for the bounded owners before adapting them.
Then verify cold/warm and dense moving captures, repeated authoritative local
transitions/reconnects, input/UI, effects and cleanup with end-to-end timings.
Existing ~38 FPS incomplete captured-room results do not accept60 FPS. General
missing resource/error isolation and the historical native shutdown fault remain
open. Continue the ordered goal in BINARY-WORLD-STREAMING-GOAL.md; full JS-native
migration and the final reference wiki follow this phase.
