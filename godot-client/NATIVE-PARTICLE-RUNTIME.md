# Direct native particle runtime: partial migration

The normal Godot entry now constructs native emitter instances for original
static model parts and actor/equipment parts. GDScript owns frame scheduling,
lifetime/recycling, initialization, visual RNG, standard movement, animation
parameter sampling, all seven standard quad modes, atlas mutation and GPU
publication. The protocol host rejects JS particle simulation/drawing imports.
No JS-prepared particle output enters this path.

Current performance follow-up: [NATIVE-PARTICLE-IMPACT-PERFORMANCE.md](NATIVE-PARTICLE-IMPACT-PERFORMANCE.md)
records persistent native bouncing sprites, conservative terrain lookup and
native original-face/Part queries, including real-server Heal animation profiles.
Historical ownership statements below retain their original milestone scope.

Current follow-ups: [NATIVE-SCENE-POINT-WIND.md](NATIVE-SCENE-POINT-WIND.md) adds
native per-world point sources; [NATIVE-PARTICLE-DISPATCH.md](NATIVE-PARTICLE-DISPATCH.md)
records fused dispatch and current partial-scene CPU evidence. Reports and
pending-service statements below retain their historical checkpoint scope.

Follow-up: [NATIVE-PARTICLE-CHUNKS.md](NATIVE-PARTICLE-CHUNKS.md) adds bounded
original chunk lifecycle/model-transform owners and a coupled native GPU service
fixture. [NATIVE-CHUNK-BINDING.md](NATIVE-CHUNK-BINDING.md) adds automatic native
model services and preserves effects across live stream adoption. Scene physics
providers and full-effect acceptance remain incomplete.

Packed templates contain original properties, channel data and shared immutable
textures. Active/free lists, clocks and surfaces belong to each instantiated
emitter. The admitted world supplies one shared local visual RNG stream; this
does not establish the original process's startup seed or complete draw order.
Explicit emitter arguments avoid a reference cycle from particles back into
their owner. Scene retirement clears callbacks and state and retires surfaces.

Binary channels retain their original controller and complete value pool.
Each pool is stored once per original emitter node, with channel indices;
neither the raw model cache nor the rig cache duplicates it per channel.
ASCII channels compile natively. Existing original-derived scalar/vector
samplers handle their arithmetic. Actor channels consume the selected model's
clock. Static pause/default selection, crossfade blending, reset/restoration
and full authoritative object/equipment animation/event ownership still need
broader verification. The original torch's base pose has zero birth rate;
its `equip` clip enables its flame/smoke. The fixture requests that original
clip explicitly. Ordinary item equip/unequip event wiring is still pending.

Only native Fountain, Explosion and Single owners with standard movement are
currently connected. Unsupported updates, P2P, chunk models, unavailable
scene-wind/intersection providers, punch-through materials and required
point-wind registration produce explicit per-emitter diagnostics. A missing
named bitmap retains existing model geometry and never draws a substitute.
Tinted particles delegate lighting to Godot with an explicit limitation;
original point tint, fog, soft-depth and complete opacity/fade remain open.
The new CPU/GPU path does not consume midpoint/percentage fields as a complete
original effect system. Non-numeric detonate controllers and original event
delivery remain incomplete. Do not infer full effect parity from field decoding.

The native simulator currently runs on the presentation thread. Surface
capacity grows geometrically, but packed CPU streams are still built and
converted each frame. An explicit 196,608-vertex surface limit reports failure
rather than silently dropping geometry. Dense moving-world frame pacing,
bounded native particle jobs and allocation reduction remain required work.
Removing JS does not prove this code faster than either prior renderer.

## Original evidence

The reused observations target read-only NWN:EE 89.8193.37-17, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
This port does not execute, modify or inject into the original process.
See [existing particle research](../evidence/particle-emitter-runtime.md).

- Lifetime: `140065f10..1400660bf`, 290 stored executions.
- Outer frame: `140061210..1400615ec`, 800 stored executions.
- Fountain: `140064b30..140065281`, 165 stored executions.
- Explosion/Single: `1400647c0..140064b29` / `140065cd0..140065f05`,
  647 stored executions with explicit lower provider boundaries.
- Initialization: `140066450..140066685`, random position/direction,
  inheritance and atlas helpers; 876 stored executions.
- Standard movement: `140068010..1400687f9`, 384 stored executions with
  camera, wind/intersection and chunk boundaries supplied by the fixture.
- Standard draw: `140062900..14006416c`, 245 stored streams across seven
  modes, compared as exact packed uint32 vertex words plus atlas mutations.

Godot's JSON reader can reconstruct a different binary64 decimal value from
the original JSON number. Tests compare exact binary32 values, without an
epsilon; integer identities, capacities and vertex words remain exact integers.
The bounded CRT SSE trigonometric port passes the initialization/draw corpus;
exceptional/large-angle and differing CPU-dispatch behavior are not accepted.

## Current checks

- `native-particle-schedule-v4.json`: **1,907 checks**, clean isolated log.
- `native-particle-physics-v3.json`: **1,262 checks**, clean isolated log.
- `native-particle-vertices-v3.json`: **491 checks**, clean isolated log.
- `native-particle-runtime-v8.json`: **29 checks**, clean isolated log.
  Authored direct model, packed clones and actor-clock routes; independent
  lists/surfaces, shared texture, shrinking lists and node retirement; original
  installed torch equip channels and portal resource drawing. Also checks that
  four binary channels share a single retained original value pool.
- `native-particle-runtime-gpu-v2.json`: **30 checks** under normal-heap CDB,
  four exception traps armed, no trapped exception or engine/lifetime error.
  Inspected PNG shows original torch flame/smoke and portal rings. Its scene
  includes direct, packed-template and actor owners after the shared-pool and
  direct-in-SceneTree initialization fixes. It is a scoped GPU check, not
  full-world or frame-pacing acceptance.
- `native-emitter-data-runtime-v2.json`: existing **601** authored emitter
  decode/worker/cache checks pass after retaining original controller storage.
- `native-actor-particle-regression-v2.json`: existing **266,819** original
  actor skin/transform/animation checks pass on the named corpus.
- `native-session-particles-v3.json`: final normal-entry Prelude check under
  normal-heap CDB. **20 entities / 9 tiles / 277 meshes / 45 textures**;
  native movement 1.50003326 m and independently observed raw server movement
  1.50003333 m; finish acknowledgment, zero remaining workers, unchanged pinned
  sources and exit 0. Four traps armed; no trapped exception or engine/lifetime
  error. Its stderr retains expected warnings. No JS particle/render module is
  in the 129 loaded protocol-module inventory. No public connections.
- `native-particle-core-v2.verified.json`: offline audit of these eight final
  report sets, exact case/check counts, clean isolated/full engine logs,
  debugger traps, current native-source hashes against the final local run,
  and the loaded protocol-module inventory. It explicitly keeps complete
  particle/world migration and performance acceptance false.

The Prelude result exposes **57 emitter nodes**, including **32** missing
`fxpa_cloud02` bitmaps and **four** unsupported chunk-model emitters. Six
emitters have advanced; no particle quads are active at the sampled final
frame. Consequently its HUD FPS cannot accept particle performance or visual
parity. The successful torch/portal drawing check is a separate fixture.
The historical missing-texture finding is in
`../backups/animations/creation-experience-emitter-resource-gaps-v1.json`;
it does not establish the original binary's missing-texture fallback.

Earlier runtime v2/v3 retain a failed expectation that an un-equipped torch
would emit in its base pose. V4 explicitly requests the actual equip clip.
The first schedule run used binary64 JSON equality and a restricted profile;
later runs use exact binary32 comparison and normal profile access. The first
attempt at isolated logs used `res://` in `--log-file`, which Godot rejects
before resolving the project. The final isolated logs use absolute paths.

Full particle migration, lightning/P2P/chunks, weather/projectiles/effect
ownership, the remaining UI/rendering systems, captured-room moving-scene
acceptance, repeated transitions/reconnects, sustained >=60 FPS and historical
native fault diagnosis remain open. Existing accepted rollback is preserved.
# Follow-up

[Native references and lightning](NATIVE-REFERENCE-LIGHTNING.md) adds private
child-model ownership, first-direct-reference targeting, original cold-ray GPU
checks and the latest captured-room CPU profile. Source pins in earlier reports
are historical after that increment; full migration/performance remain open.

