# Native particle migration

Status: **live partial migration, locally verified**. The v16 local bridge now
exports original emitter metadata/textures and drives native particle meshes
through persistent workers and binary transport. Supported particles animate
in the actual owned local-server world. Full particle/projectile parity,
loading performance and sustained 60 FPS remain unaccepted.

[NATIVE-REFERENCES.md](NATIVE-REFERENCES.md) records the subsequent v18 endpoint
milestone: reference-linked lightning is no longer excluded. Actual physical
attachment anchors and model revisions reach native poses and worker target
selection. Moving linked beams pass authored native/worker drawing checks;
actual server effect spawning, retarget notifications and full parity remain
incomplete. The v16 evidence below remains the earlier live-particle milestone.

## Live runtime

`tools/export-particles.mjs` discovers hidden/empty emitters as well as initially
visible ones. Stable physical-instance IDs bind emitter/model roots to native
rig nodes and model clocks where available. Original bitmap templates are
embedded in the existing external GLB; no installed asset is written into the
workspace. The zero-alpha templates are hidden after import and replaced by
live surfaces. The exporter retains original emitter controller tracks and
model events and exports original static collision planes only when needed.

`systems/particle_world.gd` owns native frame timing, camera matrices, rig poses,
per-model clocks, visibility and surfaces. It requests at most one worker frame
at a time, sampling at up to 60 Hz and accumulating elapsed time while waiting.
The simulation retains its original 0.5-second outer delta clamp; skipped
intermediate pose/time samples under load still require performance/fidelity
validation. Static models without native rigs retain a native-owned simple
float32 loop clock for emitter-property/event sampling; their animated ancestor
transform tracks and complete original run/blend semantics remain pending.
Native rigged models use their actual AnimationPlayer clock, including its
stored terminal time, without querying inactive players.

`model_rigs.gd` now exposes per-model events separately from primary-body
combat events. Explosion detonation reaches the owning emitter model only.
Original linear/Bezier emitter property sampling runs inside the worker using
the retained sampler. Model replacement patches worker membership without
resetting untouched emitters, storage or random state. First-emitter additions
also work when the original area had no emitters. Hidden/removed canonical
entities cannot leave world-space particle ghosts.

`tools/particle-delivery.mjs` owns scoped worker startup, patches, frame results
and teardown. Initialization/model-patch races and retirement cannot publish
late readiness. `particle-wire.cjs` frames packed buffers with bounded JSON
metadata and raw binary streams. `bridge_frames.gd` decodes those alongside
ordinary JSON control messages, preserving split UTF-8 and arbitrary newline
bytes in GPU attributes. Limits are 8 MiB per binary packet, 64 KiB metadata,
128 emitters per packet, 64 MiB per admitted frame and 4,096 emitters. These
share the private TCP connection; large-frame head-of-line costs remain a
performance measurement requirement. Movement/server IO does not await the
particle simulation. Retired connections/areas/transfers and frame sequences
cannot apply old results to a new native owner.

The live framebuffer test found a winding conversion bug missed by the
foundation's two-sided fixture. Retained streams use the existing renderer's
front-face convention; Godot treats clockwise triangles as front-facing.
`particle_surface.gd` now selects the opposite cull face for single-sided
streams, preserving their exact vertex/color/UV order. The official
[SurfaceTool reference](https://docs.godotengine.org/en/stable/classes/class_surfacetool.html)
documents Godot's winding convention. Both an actual installed flame and the
authored single-sided fixture now produce verified pixels.

### Live evidence

- `reports/particle-runtime-regressions-v4.log`: **53 Node cases pass** across
  worker simulation, hidden/empty emitter export, original texture bytes and
  physical binding, stable IDs, delta filtering, original controller sampling,
  membership patches, initialization/retirement races, binary bounds and
  evidence gates, plus existing exporter, staging, protocol and UI-flow guards.
- `reports/particle-wire-native-v2.json`: **44 native framing checks pass**,
  including byte-sized fragmentation, mixed binary/JSON, split UTF-8, embedded
  attribute newlines, unsigned scope, oversized frames and irreversible reject.
- `reports/particle-world-native-v2.json`: **15 native ownership checks pass**,
  including first-emitter startup, camera/controller/event requests,
  backpressure, exact stream/completion ownership, hidden entities and teardown.
- `reports/native-particles-local-v4.json`: **22 actual local checks pass**,
  including the existing 16 server dialogue/examine/chat checks. Ten original
  emitters are discovered, two workers produce 72 frames (71 acknowledged before
  the final report), and two supported emitters draw their actual installed
  textures. Native GPU vertex samples change between observations. A focused
  original brazier view changes **14,755 pixels** in a 180-by-180 region when
  particle surfaces are hidden. The native camera reaches the worker billboard
  path before that check. Exit is 0, disconnect is explicit, engine/renderer
  errors are empty, and teardown leaves **zero pending jobs/worker threads**.
- `reports/native-particles-local-v4-particles.png` and the matching
  `-particles-hidden.png` capture the original brazier with/without particle
  surfaces. The active frame was inspected: original flame art draws around
  the brazier. No broad native-binary pixel parity claim follows from this.
- `reports/native-particles-transitions-v1.json`: actual A–B–A passes with live
  particle frames in all three epochs, real shape/clothing/removal flow and an
  uncommitted old-area model export discarded. Six and then twelve retired
  native world owners have **zero surviving owners** at subsequent admissions.
  This run predates the single-sided cull fix; it proves delivery/lifetimes,
  not on-screen particle pixels. Active-emitter model replacement is covered
  by authored native/worker tests; the real creature fixture has no emitters.
- `reports/native-particles-reconnect-v1.json`: real save/disconnect/reconnect
  passes with two area admissions, three saved versions of one character,
  original animation/movement and six retired native owners released. Both
  worker epochs close with **zero pending jobs and zero remaining threads**.
- `reports/particle-combat-native-v1.json`: **4,595 retained combat/event/player
  checks pass** after the per-model event and terminal-clock changes.
  `reports/particle-rigs-gpu-regression-v1.json`: **65 real Vulkan model/skin
  checks pass**, maximum skin position error 0.0000169094765.
- `reports/particle-surface-gpu-v4.json`: **5,026 real Vulkan stream/pixel checks
  pass with single-sided particles**, including unchanged native positions,
  RGBA/UV streams, cleared capacity, expiry and resource ownership.

Functional tests preserve the project editor; none of these FPS counters or
per-frame observations constitute a clean sustained full-world performance
acceptance. The actual local room still has **six failed emitter instances**:
four reference absent `fxpa_cloud02` and two need unimplemented wind sampling.
`particle-missing-texture-catalog-v1.json` verifies read-only that neither TGA
nor DDS of that name exists in the installed base catalog. No substitute image
or zero wind was invented. Native stream/import failures remain zero; failed
simulation emitters are separately reported as `failed_emitters`.

Failed runs remain visible: the new pixel probe initially needed explicit
Image type declarations (`native-particles-local-v2.json`). The next run
correctly failed with zero changed pixels and exposed the single-sided cull
bug (`v3`); v4 fixes and verifies it. The v1 text-only flow passed delivery and
GPU coordinate changes but did not validate visible pixels. Initial parser
logs retain an indentation error and a Node `ready` signal/name collision,
both fixed before live admission. An evidence-test object literal typo in
`particle-runtime-regressions-v3.log` is fixed in the final v4 pass.

Run the current live check against owned `GodotGameplay` on localhost 5121:

```powershell
.\godot-client\join-local.ps1 -ParticleSmoke -Report unused-particle-check.json
```

## Implemented owners

`tools/particle-simulation.mjs` instantiates the retained
`src/model_particles.js` adapter in a CPU-only worker scene. It reuses the
original-derived Fountain, Explosion, Single and Lightning owners, initialization,
movement, lifetime, atlas, random and all seven vertex-generation modes. It does
not instantiate a Three renderer, run browser animation, access the server, or
decide authoritative gameplay outcomes. The API accepts camera/root/emitter
matrices, sampled properties, detonation commands, delta and monotonic scope
and frame identifiers. Static collision faces retain their original plane and
polygon data through the existing collision query.

`tools/particle-workers.mjs` starts one to four persistent Node workers. Stable
assignment retains each emitter's simulation storage and random stream. Typed
buffers transfer out of the worker rather than being cloned as float JSON.
There is one admitted frame at a time and no implicit dropped/reordered frame
queue. A busy caller receives an explicit result and must wait; the live Godot
owner now accumulates elapsed time as described above. Scene resets
reject retired completions; errors, worker exit and shutdown settle pending
requests. Assignment uses deterministic per-worker seeds for regression tests.
Native startup seeding/global random draw ordering remains unverified.

`tools/particle-buffers.mjs` converts the original 24-byte vertex stream into
native position and attribute streams, preserving float32 renderer coordinates,
RGBA bytes, UVs and six-vertex order. Capacity grows with a hard bound; unused
quads are zeroed. Invalid layout, sizes and nonfinite data fail explicitly.
Runtime failure also emits an empty stream so previously visible quads cannot
remain stuck on screen.

`systems/particle_surface.gd` owns a dynamic ArrayMesh and an unshaded native
material with explicit texture, blend, cull and depth-write behavior. It queries
the actual RenderingServer strides/offsets and rejects an unexpected layout.
Frame updates upload packed streams directly without a GDScript vertex loop.
The mesh is world-space, never casts shadows, hides when empty, bounds its active
geometry, rejects stale epochs/sequences and releases resources on retirement.
Reconfiguration starts a fresh epoch and cannot admit previous completions.
The underlying APIs are documented by
[Godot's RenderingServer reference](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html).

## Earlier foundation evidence

- `reports/particle-worker-regressions-v2.log`: **25 Node cases pass**. Eight
  new cases exercise all seven modes, moving root/parent/camera matrices,
  sampled properties, atlas/lifetime changes, detonation, Single and empty
  no-endpoint Lightning, original static bounce faces, missing services,
  NULL-textured simulation helpers, runtime failure hiding, stream validation,
  actual two-worker byte comparisons, busy admission, resets and shutdown.
  Seventeen retained source cases also pass, including their existing native
  arithmetic fixtures. This is reuse/differential evidence, not a fresh binary
  oracle or broad native-game fidelity acceptance.
- `reports/particle-stream-fixture-v1.json` and its `.bin` streams are entirely
  authored numeric data, produced by **two actual worker threads**. No installed
  models, texture pixels or binaries are copied into the workspace.
- `reports/particle-surface-gpu-v3.json`: **5,026 checks pass** using actual Godot
  4.7.2 Vulkan/Forward+ on the RTX 5070 Ti. Eighteen generated frames across two
  emitters cover 28 visible and eight empty owner frames. Readback verifies 672
  active vertices, byte colors, atlas UVs and cleared unused quads. An actual
  framebuffer pixel changes when a quad is drawn and returns to background
  after expiration. Reconfiguration, blend/cull/texture ownership, world-space
  parenting, truncated streams, stale frames and retirement are checked.
- `reports/particle-surface-gpu-v3-active.png` was inspected: the authored orange
  textured quad is present against the clear background. The expired capture is
  retained separately. The shader test uses an authored white image; original
  installed particle texture/color fidelity still needs live validation.
- The native GPU test's dedicated engine/stdout/stderr logs contain no engine
  errors. The interactive local preview and project editor were preserved.
  This functional GPU test is not a clean performance benchmark.

Failed evidence is retained. `particle-surface-native-v1.json` failed a test's
strict Dictionary comparison between native integer stride values and JSON
float values; individual numeric comparisons fix the assertion. Its sandboxed
headless log also reports unavailable certificate/log access. Actual Vulkan
v1 passed 5,020 checks, v2 added framebuffer/reconfiguration checks, and v3 adds
material/world-space checks and the active capture. A temporary missing-texture
test failure incorrectly supplied `textureAvailable:true` for its absent NULL
texture; the corrected fixture now exercises the actual missing-resource path.
The passing regression log contains the corrected final case.

Reproduce fixture generation with an unused output basename:

```powershell
node --test godot-client/tools/particle-workers.test.mjs
node godot-client/tools/particle-fixture.mjs --output=godot-client/reports/particle-stream-fixture-next.json
```

Run Godot with `--script res://tests/particle_surface_test.gd`, then user args
`--fixture=res://reports/particle-stream-fixture-next.json`, an unused
`--report=res://reports/particle-surface-next.json`, and `--gpu` for real Vulkan
readbacks/framebuffer checks. Use a dedicated absolute `--log-file` and preserve
other games. Headless setup checks do not replace Vulkan evidence.

## Remaining required work

1. Complete original reference retarget notifications and referenced model
   asset/animation lifetimes. First-direct endpoint selection and native
   attachment/revision delivery now work; see NATIVE-REFERENCES.md.
2. Port static-model animated ancestor transforms and full run/blend clock
   semantics. Validate controller-driven moving/held emitters and detonation
   against broader actual installed local/captured content.
3. Extend actual active-emitter model-replacement/late-asset tests. Current real
   transitions/reconnect verify complete world retirement; active same-area
   emitter replacement is still authored component evidence.
4. Measure the complete moving captured room with original particles, more
   dense binary traffic, frame latency, memory limits and loading behavior.
5. Migrate transient projectile asset/stage/path/impact ownership and remaining
   effect/audio/controller systems. Do not substitute decorative projectiles
   for the existing original-derived simulation owners.
6. Resolve existing explicit particle limitations: P2P non-Lightning movement,
   chunks, punch-through, scene tint/wind, dynamic collision and exact
   soft-depth/fog/gamma behavior. The reused owner retains its diagnostics;
   unsupported behavior is not declared migrated.

The full migration inventory and goal remain active. Production main/dist is
unchanged. The isolated local bridge is now v18; original art/asset bundles
remain external temporary data. No Arelith connection was made.
