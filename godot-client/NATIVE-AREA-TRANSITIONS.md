# Native area transitions and reconnect

Status: **local A–B–A and saved-character reconnect verified; full multiplayer
world migration remains incomplete**. Original assets and the existing client
remain intact. No Arelith connection was made.

## Implementation

`tools/world-transfer.cjs` owns each connection/area/generation through an
immutable transfer ticket. A changed destination clears native admission once,
instead of repeatedly clearing the room on every loading poll. Package export,
file writes and native acknowledgements must still belong to that ticket and
the backend's current world. An old asynchronous area/content failure cannot
fail a replacement world. Disconnect/reconnect invalidates pending jobs even
when numeric area IDs and area generations are reused.

`tools/staging-area.mjs` captures the actual presenter, world and model binding
identities around asynchronous export. It rejects mismatched presenter areas,
new/deleted/replaced bindings, and transitions during texture/text work. This
prevents mixing old geometry with new-area metadata. Inconsistent initial
exports retry rather than publishing an incomplete world. The original source
renderer resumes for new-area preparation and stops again for native playback.

`systems/world_scope.gd` checks the expected connection, transfer ticket, area
and generation before native file access or admission. Stale loading, area,
pose and content packets cannot resurrect a retired room. Model/skin/physics
owners, transform targets and bounds are retired together. Deferred smoke
readbacks also check ownership after yielding. Weak references verify the
retired native owners have actually been freed after presentation.

Dialog delivery captures its receiving area before queued text work and
rechecks it after resolution. Global chat can finish within the same connection;
an older room's test reply cannot validate a newer room. New connections get
independent text queues. Complete rich-text/conversation parity remains pending.

Functional tests may coexist with the exact workspace project editor. The
launcher identifies `--editor` and its quoted project path, preserves that
process, and still refuses existing game clients and unrelated editors.
Clean GPU/FPS benchmarks remain deferred while that editor is running.

## Evidence

- **53 Node cases pass** across the current isolated tools. New cases cover
  world ownership, reused identifiers, asynchronous mixed-area exports and
  binding changes, and incomplete integration evidence. Prior model, protocol,
  lobby and content cases remain included.
- `reports/world-scope-authored-v1.json`: **16 native checks** pass. These
  exercise actual native message handling and removal of six owned nodes,
  duplicate/stale loading, rejected old area payloads before file access,
  stale poses, disconnect and same-ID/reset-generation reconnect.
- `reports/content-lifecycle-world-scope-regression-v1.json`: the existing
  **28 native content ownership checks** still pass with the new scope guards.
- **`reports/world-transition-local-v4.json`** uses the installed native server
  on owned UDP 5121 and the authored `GodotLifecycle` module. It drives real
  server chat scripts for spawn, badger shape/restore, clothing equip and
  `JumpToLocation`, without injecting decoded replication. Areas are:

  | Area | Server ID | Generation / ticket | Native meshes |
  |---|---:|---:|---:|
  | dense_a | 2147483649 | 1 / 1 | 2526 |
  | dense_b | 2147483655 | 2 / 2 | 2526 |
  | dense_a | 2147483649 | 3 / 3 | 2548 |

  During a second server-driven shape update, the test holds an exported,
  uncommitted content job for 1.5 seconds while the real server moves the
  character to B. That retired job is discarded. The A creature is absent from
  B's native registry, returns with its authoritative badger model, restores
  the previously equipped original clothing parts, then disappears on the
  server's DestroyObject update. Every admitted area has its own native movement,
  camera-follow, actual local bone/skin changes, chat round trip and screenshot.
  Retired owners are 6 after A→B and 12 after B→A, with **zero still alive**.
  Renderer errors and diagnostics are empty; exit 0 and explicit disconnect.
- `reports/world-scope-prelude-reconnect-v1.json`: the final build rejoins
  owned Prelude using the exported saved BIC. Connections 1 and 3 reuse area
  2147483649 and generation 1 but have different transfer tickets, 1 and 2.
  Both import 375 meshes and pass native animated movement/chat/camera checks.
  Three saved versions retain one ID in an external temporary regression vault.
  Preview/upload on the second connection read the prior disconnect save's
  SHA-256. Save-on-close, native exit 0 and explicit disconnect pass. The user's
  application vault is not modified by this test.

Fixture generation: `reports/lifecycle-server-fixture-v3.json`, authored module
SHA-256 `f7a3f538abd8d3102c6cc4b4dbfbca4b29016464125c1836c7b80537c3fa21f3`.
Installed server SHA-256 remains
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
The isolated source staging build is `v11`; normal main/dist hashes are checked
separately and unchanged.

The first real run reached all three areas but failed its final screenshot
gate because content sequence numbers restarted in each room. Snapshot names
now include the connection and transfer ticket. `world-transition-local-v1`
is retained as a failed overall run, not accepted by inference. Later runs
pass the complete flow. Integration completion no longer follows merely from
a clean engine exit or closing a test window early.

## Limits and next work

This is functional validation, **not a loading or FPS acceptance**. The project
editor remained open and screenshots perform GPU readbacks. In the v4 run,
native full-area imports alone took approximately 1.37–1.48 seconds. Source
preparation, external bundle writes, synchronization and native import still
add loading time; no end-to-end speedup is established. Weak node references
prove native owner release, not a complete VRAM or disk-cache lifetime audit.

The two server areas use the same authored terrain resources. Distinct server
IDs, generations, object membership and native ownership prove the transition;
these screenshots are not a diverse content/fidelity corpus. Rapid repeated
transitions under resource failure, real server-vault-only admission/creation,
cross-server handoff, per-part visual/controller and metadata deltas, particles,
full movement prediction/collision, combat/UI/NUI and complete model/material
coverage remain open. Full migration and sustained 60 FPS remain unaccepted.

The owned server has been restored to **Prelude on UDP 5121** and left running.
The user's project editor was preserved. To repeat the authored transition
check, first generate a new fixture report, start the owned module, then run:

```powershell
.\godot-client\join-local.ps1 -TransitionSmoke -Report transitions-new.json
```

Use an unused report name. Native reports and per-area screenshots refuse
overwrite. See `NATIVE-WORLD-LIFECYCLE.md` for fixture generation commands.
