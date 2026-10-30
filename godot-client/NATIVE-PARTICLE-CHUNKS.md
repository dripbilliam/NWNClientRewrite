# Native chunk-particle owners: partial integration

Current follow-up: [NATIVE-CHUNK-BINDING.md](NATIVE-CHUNK-BINDING.md) implements
automatic native world bindings and fixes effect retirement during live model
admission. The sections below retain the earlier bounded-owner checkpoint;
their pending automatic-binding statements describe that checkpoint. Complete
scene physics/effects/performance remain unfinished.

The native particle runtime now has the bounded chunk constructor, initialize,
destructor and model-transform draw flow. Explicit native model services can
activate it. Automatic live-world chunk asset/service binding remains pending;
ordinary worlds continue diagnosing that gap. This is not full effect parity.

## Original read-only evidence

Target NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executable/assets/Ghidra remain unchanged.

| Owner | Complete body | Observed behavior |
|---|---|---|
| ChunkyParticle constructor |1400602b0..140060373 |Base particle initialization, create named chunk model at140060340, scene attachment if present at140060362 |
| ChunkyParticle initialize |1400663d0..14006644c |Forces base initialization factor1 at1400663e9; model scene attachment140066401, scale virtual1b0 at140066414, impact animation virtual30 at14006643f |
| ChunkyParticle destructor |1400608a0..1400608dd |Model deleting destructor with flag1 at1400608c4; clears child78 and restores base vtable |
| PartEmitter RenderNothing |140064190..1400643ab |Source/instance fade gates, forward active traversal, world model position, optional rotation around normalized particle direction; no standard quads |

The exported name RenderNothing does not mean an empty function. Its540-byte
body updates chunk models. Nonzero particle rotation updates orientation unless
the particle is stopped; otherwise its existing model orientation remains.
COMISS/JA fade exits treat unordered values differently from a negated >= test.

Derived complete views in `backups/animations`:
`rea-particle-chunk-constructor-v1.json`, `rea-particle-chunk-initialize-v1.json`,
`rea-particle-chunk-destructor-v1.json`,
`rea-particle-chunk-model-transform-draw-v1.json`. Duplicated raw results and
high-pcode excluded with scope declared. Indirect lower targets are not all
resolved by these selected views; ScaleObject's virtual1b0 binding has earlier
independent evidence in multiplayer-held-equipment-investigation.md.

`scripts/inspect-native-particle-chunks.py` executes these four complete unchanged
bodies in isolated Unicorn.110 cases include14 lifecycle and96 model-transform
cases. Base particle initialization, model creation, scene/scale/animation,
destruction, pose setters, normalization, sin/cos and vector multiply are explicit
captured lower providers. Directions are nonzero, rotation angles bounded, and
debug emitter spheres are off. This does not establish arbitrary trig/zero-axis
policy, original model creation, complete material/scene behavior or GPU pixels.
Output: `backups/animations/native-particle-chunks-v1.json`.

## Native integration

`systems/native_render/particle_chunks.gd` follows those owner calls. The existing
`particle_emitter.gd` supplies native GDScript/compiled base initialization and
simulation. For chunk particles, base initialization uses1 while the caller's
source factor scales the private model. Impact playback, scene detach on expiry,
free-list reuse and destruction of active/pooled models remain separate operations.
Only the model draw path runs; no replacement quad bitmap or geometry is supplied.
Failed model creation remains observable through `missing_chunk_models`.

Seven required native presentation services must be supplied before admission:
createChunkModel, chunkScene, chunkScale, chunkPlay, chunkPosition,
chunkOrientation and destroyChunkModel. Partial service sets remain unsupported.
The runtime adds the existing lifetime detach hook and preserves standard quad
behavior. Original source transforms stay Z-up until the native publication
provider converts them to Godot coordinates. No canonical IDs or server RNG are
allocated for these visual models.

The GPU fixture supplies actual native Actor/rig/mesh services and a file-backed
authored model prepared by an actual asset worker. Automatic native-world
request/deduplication, source cycles, ready gating, ownership/teardown and nested
chunk/reference models still need to be integrated before ordinary gameplay can
use this path. No such live readiness is inferred from the authored service test.

## Verification

- `native-particle-chunks-v3`:119 checks, including110 exact float32 original
  call/state comparisons. Coupled emitter/kernel runs120 explicit simulation
  steps; two private models serve15 impact plays and13 expiry detaches, sharing
  immutable mesh data while keeping private rigs/transforms. Source scale2 is
  retained, quad vertices0, models destroyed exactly once with no survivors.
  The authored ASCII impact clip uses the existing native Godot ASCII clip path;
  the fixture does not claim original binary clip/pixel parity.
- `native-particle-chunks-standard-regression-v2`:30 established native GPU
  standard-particle/actual-original-model checks remain green.
- `native-session-particle-chunk-owners-v1`:actual default native launcher on
  owned localhost Prelude. Player ready1445.190 ms during background loading;
  native/server movement during streaming, final20 entities/nine tiles, finish
  acknowledged, workers0 and clean exit. Live chunk services remain unavailable:
  57 emitters/42 diagnosed failures are unchanged in count, not claimed fixed.

Accepted checks use normal-heap CDB with four traps, unchanged runtime sources
and no trapped native or engine/lifetime error. v1 GPU fixture had one assertion
failure because it requested binary-only playback for an authored ASCII clip;
the fixture now uses the existing ASCII path. Retained as failed evidence. The
first oracle development run shadowed an emulated pointer variable and aborted
before producing output; corrected final110 cases execute successfully.

Earlier installed/Workshop catalog investigation already established absent
fxpa_cloud02/fxpa_feather bitmaps. No lookup alias or fabricated replacement was
added. Those missing quad textures remain distinct from chunk models and from
dormant damage emitters. Wind, collisions, point-wind, full fade/tint and native
scene ordering remain incomplete. No clean FPS/full-world acceptance follows.
Continue BINARY-WORLD-STREAMING-GOAL.md; full migration/wiki remain unfinished.
