# Live native content lifecycle

Status: **implemented and locally verified for ordinary replicated model
replacement; full world/gameplay migration remains incomplete**.

The native client no longer depends on its initial area export for all model
content. The existing source presenter assembles original assets when a creature,
item, placeable or door appears or changes its render signature. A per-binding
revision distinguishes a replacement from a position/animation update, including
the same object ID being destroyed and recreated. Missing source preparation
keeps the existing native model until its replacement is ready. Authoritative
removal retires the native entity.

`tools/staging-content.mjs` exports only changed objects, including held/worn
roots, original rig/skin data, textures and owned lights. It excludes unrelated
scenery, camera and ambient lighting. Batches are bounded to eight objects and
prepared asynchronously without awaiting the entire asset job in the 20 Hz pose
delivery path. Godot owns animation and rendering; animated vertex arrays are
not streamed each frame.

Each update is scoped by connection, area, generation and ordered sequence.
Async preparation rechecks the source binding revisions before committing.
The authenticated local envelope includes separate GLB and metadata SHA-256
digests, covering supplementary rig/revision metadata as well as mesh bytes.
Proprietary payloads stay in external temporary runtime bundles.

`systems/content_bundle.gd` imports and configures the complete update off screen
before existing content is retired. Native registry, collider, rig and palette
bindings must all succeed. Adoption preserves the entity's interpolated root
pose and destination, camera, unrelated objects and existing menus. Retiring an
entity disables its nested pick bodies immediately, releases its visual/rig
ownership, removes lookup/overlay references and refreshes the object list.
Owned particles/lights move with the entity; particle simulation remains pending.

## Evidence

- **39 Node cases pass** across content revision/race checks, scoped exporter,
  metadata digests and prior rig/export/lobby/protocol regressions.
- `reports/content-lifecycle-authored-v3.json`: 28 headless native checks using
  entirely authored external GLBs. Spawn, GPU skin/rig construction, pose
  preservation, unrelated camera/entity identity, actual old-node release,
  connection/area/generation/sequence rejection, metadata tampering and three
  remove/recreate cycles pass. Mesh/skin/player ownership remains bounded.
- `reports/content-lifecycle-gpu-v1.json`: the same 28 checks pass on native
  Vulkan/Forward+. This checks ownership and import, not steady-state FPS.
- `reports/model-rigs-live-content-regression-v1.json`: all 64 independent native
  GPU animation/skin oracle checks still pass; maximum skin position error
  0.0000169094764714828 and rigid error 0.000000357627868652344.
- `reports/live-content-baseline-v1.json`: actual owned Prelude admission,
  movement/chat/camera and native body/robe movement pass, including a late
  content update after initial import. Exit 0 and explicit disconnect.
- **`reports/live-content-server-v4.json`**: native NWN server runs the authored
  `GodotLifecycle` module. Ordinary chat invokes server-side CreateObject,
  SetCreatureAppearanceType, ActionEquipItem and DestroyObject. No synthetic
  decoded updates or client-side shape changes are injected. The native client
  imports 2,526 initial meshes, then presents a spawned original human model
  (16 meshes), dire-badger shape (24), restored human (16), changed original
  clothing parts (16), and removal. Each step has a post-draw screenshot and
  scoped native acknowledgement. Rig nodes return from 211 to the initial 104
  after removal; active players return from three to two. Renderer errors empty,
  native exit 0 and disconnected true. The v2 module places the test creature
  separately from the player so its appearance can be inspected.
- Fixture source: `tools/create-lifecycle-server.mjs`; authored archive hash
  `12241ce6e2a25587f73b19e8a2d0d9c3bbf68a18404561598a7625404a0b2aae`.
  Generation report: `reports/lifecycle-server-fixture-v2.json`. Installed
  server hash remains `98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.

The first authored test exposed numeric dictionary comparison across JSON
serialization; revision identity is now compared by explicit integer fields.
The first fixture-v2 generation caught an incorrect waypoint API argument count
before writing the module. `live-content-server-v3` still used the earlier
module and is not evidence of the separate-position fixture. Those failures
are not promoted into passes.

## Bridge costs and remaining acceptance

The bridge reuses the JavaScript protocol/resource backend and a hidden Electron
source presenter. It adds memory and duplicates some model preparation/import
work. It is a migration architecture, not a proven final loading architecture.
The source renderer's animation loop stays stopped after staging.

In the v4 **functional fixture run**, 74 content snapshots totaled 82.20 ms
(about 1.11 ms each). Four model exports totaled 1119.91 ms; external bundle
writes totaled 419.30 ms. Native model-update imports took 64–274 ms, with an
initial full-area native import of 1337.75 ms. These timings include IPC/data
transfer and test work; they are not isolated CPU or GPU attribution. The 94
pose intervals averaged 62.24 ms, with a 111.82 ms maximum, despite asset work
being independently awaited. Shared-thread serialization and native import
still cause hitches. Screenshots also introduce deliberate GPU readbacks.

No complete-room FPS, smooth-loading or performance-parity claim follows.
Content-addressed native resource reuse and background/ staged import remain
important loading work. Extended real transition/reconnect stress, richer metadata-only
updates, per-part visual-transform deltas, full attachment/mount/custom-content
coverage, combat queues/events, light/material controllers, particles, exact
animated skin picking and the rest of gameplay/UI remain pending.

Follow-up: [NATIVE-AREA-TRANSITIONS.md](NATIVE-AREA-TRANSITIONS.md) records real
A–B–A with pending content, native owner release and a new saved-character
reconnect on the final scope-aware build. The other Godot process was identified
as this exact project editor and preserved; functional checks now allow it,
while clean FPS benchmarks remain deferred. The owned server is restored to
Prelude on UDP 5121. No Arelith connection was made.

## Reproduce locally

Keep existing game sessions closed for these checks. Use unused report names.
The authored DensePerf baseline must already exist; generate it with
`node scripts/create-dense-server-fixture.mjs` if needed. The lifecycle generator
verifies its authored baseline hash before deriving any records. Installed
resources are referenced by resref, never copied into the authored module.

```powershell
node godot-client/tools/create-lifecycle-server.mjs --report=lifecycle-fixture-new.json
.\scripts\local-multiplayer-server.ps1 -Action Stop
.\scripts\local-multiplayer-server.ps1 -Action Start -Module GodotLifecycle
.\godot-client\join-local.ps1 -ContentSmoke -Report lifecycle-check-new.json
```

The normal `join-local.ps1` still uses whichever owned module is already running
on 5121, starting Prelude only when that server is absent. Restore Prelude
deliberately after fixture testing when no local client is connected.
