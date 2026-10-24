# Reference-linked particle endpoints

Status: **partial native endpoint migration, tested**. Reference-linked
lightning is now admitted to the existing live particle runtime. The exporter,
native pose owner and worker preserve the original first-direct-reference
selection and attachment ownership. This does not yet migrate transient server
effect/projectile creation, every retarget notification or full effect parity.

## Behavior and ownership

`export-particles.mjs` queries the actual retained physical reference owner.
Its first direct reference child wins, even when another reference is nearer
or appears earlier inside a nested non-reference part. It transfers that child
model's actual root pose and attachment anchor. The anchor is an actual physical
rig node when available, with a canonical-pivot/local-pose fallback for static
unrigged objects. It never chooses endpoints by nearest object or guessed name.

Native bindings carry the source model-content revision. Initial-area and
same-area exports stamp the current revisions, including external targets.
Sparse model exports now index other creatures' physical nodes without
re-exporting their skins, clips or rest poses. A newly added beam can therefore
follow another creature's animated node while its own content transfer remains
sparse.

`particle_world.gd` resolves the endpoint from the current native physical
node or attachment. Ordinary attachment copies position/rotation and preserves
the referenced model's scale. Mode 3 preserves its existing orientation while
following position. A replaced, removed or absent canonical owner yields an
unavailable endpoint rather than stale coordinates or another model using the
same object ID.

`particle-simulation.mjs` supplies a data-derived reference view to the retained
particle owner. The existing Lightning initialize, first-reference selector,
fractal generation, cached-motion updates, random stream, storage reuse and
vertex production execute unchanged. Workers now accept linked emitters instead
of excluding them. Frame endpoint matrices are validated before simulation
advances. Explicit endpoint retirement clears the old target/listener, drains
the chain and prevents that old emitter from reconnecting to a recycled model.
A newly owned emitter can create a new link.

Two shared source APIs have additive changes:

- `src/model_particles.js` accepts an optional `referenceScene` provider. Its
  default remains the existing physical scene lookup used by the working client.
- `src/visual_scene_pose.js` exposes `attachmentFor`, a read-only record of the
  existing attachment anchor and flags. Mutating the returned record cannot
  change the manager's flags or ownership.

`reports/reference-shared-source-scope-v1.json` reconstructs the previous pinned
hashes by removing only those additions. It verifies that unrelated pre-existing
changes in these already-dirty source files are preserved. Main and dist are
unchanged. Existing default source behavior is regression-tested; no native
binary/process was modified.

## Evidence

- `reports/particle-reference-regressions-v3.log`: **102 Node cases pass**.
  This includes the new endpoint tests, sparse external-node binding test,
  current native-particle/export/protocol/evidence guards, and retained particle,
  reference-owner, reference-scene, attachment and worker-scene tests. The
  existing recorded **97 native target/initialize cases** and **2,697 native
  Lightning updates** still pass. These are retained observations, not fresh
  binary instrumentation.
- The new source/worker comparison runs **180 authored frames** across three
  render modes and both attachment modes, with moving roots, joint rotation,
  scale and cached Lightning phases. Vertex positions agree within 0.00002;
  RGBA, UV and random draw counts agree. Full original physical reference scenes
  supply the independent source result. Nested/nearer references do not replace
  the first direct endpoint.
- `reports/particle-reference-native-v2.json`: **332 native checks pass**
  against **80 authored original-owner transform observations**. Bound animated
  anchors and canonical-root fallback follow original position/orientation/
  scale rules. Maximum matrix error is **0.0000009456111024**. Replaced model
  revisions, removed targets and missing physical nodes cannot reuse old links.
- `reports/particle-reference-live-v1.json`: **25 actual native drawing-path
  checks pass**. An authored moving beam runs through the production particle
  world, actual worker threads and private binary transport into Godot Vulkan.
  Twenty moving endpoint frames agree with original physical attachment poses;
  **846 framebuffer pixels** change when the beam is hidden. Two further worker
  frames verify target retirement and refusal to revive the old link. Exit is
  0, native errors are empty, and teardown leaves **zero pending jobs and zero
  remaining worker threads**. Its active screenshot was inspected.
- That renderer fixture uses authored nodes and a white authored texture.
  It is **not** evidence of an actual NWN server beam, installed lightning art
  fidelity or complete server effect creation. It makes no server connection.
- `reports/reference-world-regression-v1.json`: all **15** native particle
  ownership/backpressure/startup checks still pass.
- **`reports/native-reference-particles-local-v1.json`**: all **22 actual local
  multiplayer checks pass** with isolated staging build **v18**. Original
  installed flame pixels, dialogue/examine/chat, native model movement and
  clean disconnect remain working. Two workers produce 75 frames; the focused
  original flame check changes 13,617 pixels. No engine/renderer errors occur;
  worker teardown is empty. This real local fixture contains no linked effect,
  so linked-reference behavior remains authored integration evidence.
- **`reports/native-reference-transitions-v1.json`**: actual A–B–A and real
  shape/clothing/removal pass with the sparse cross-creature binding change.
  A pending old-area model export is discarded; six and twelve retired native
  world owners have zero survivors. All three worker epochs terminate with
  zero pending jobs/threads. The creature fixture has no linked emitters.

The initial Node run retained a negative assertion expecting all references
to be unsupported. It now verifies malformed endpoint matrices instead;
the new tests prove valid linked references work. Its failed log remains at
`particle-reference-node-initial-v1.log`. The initial native test's sandbox
certificate-store warning is retained; native v2 has normal access and no
engine errors.

These are functional checks. The project editor and unrelated programs are
preserved; no clean full-room FPS claim follows. No Arelith connection occurred.

## Reproduce

```powershell
node --test godot-client/tools/particle-reference.test.mjs
node godot-client/tools/reference-oracle.mjs --output=godot-client/reports/unused-reference-oracle.json
node godot-client/tools/reference-live-host.cjs --report=unused-reference-live.json
```

The native arithmetic test is `tests/particle_reference_test.gd` with
`--oracle=res://reports/unused-reference-oracle.json` and an unused `--report`.
Use an absolute dedicated log path. The drawing-path host uses a one-session
authenticated localhost socket, an external temporary ticket and the pinned
Godot executable; it closes only its own helpers.

## Remaining work

- Full native retarget notifications and legitimate reattachment after model
  changes, listener scheduling and referenced model asset/animation lifetimes.
  Current explicit invalidation protects ownership; it does not implement the
  complete original `_EmitterTarget` notification graph.
- Transient server visual/effect and projectile resource rosters, creation,
  attachments, original asset stages, path motion, impacts and destruction.
  [NATIVE-VISUAL-MODELS.md](NATIVE-VISUAL-MODELS.md) now verifies the private
  model resource/import/animation/attachment prerequisite; live effect ownership
  and original phase/program/path adapters are still required.
  Existing source projectile owners remain required; no decorative replacement
  or generic linear path substitutes for them.
- Animated ancestor transforms on unrigged static models, general mirrored/
  sheared attachment cases, scene wind/tint, chunks, non-Lightning P2P,
  punch-through and exact soft-depth/fog/gamma. The local fixture's absent cloud
  bitmap and wind-provider failures remain explicitly reported.
- Actual installed linked-effect cases against owned local/captured content,
  then full moving captured-world feature/fidelity/loading/performance checks.
  Full migration and sustained >=60 FPS remain unaccepted.

The verified Godot checkpoint also includes the two related authored shared
source files. `checkpoint.ps1 -RelatedSource` restricts these to ordinary
source files under this workspace's `src`/`electron` directories and rejects
linked/outside paths. They live under `__workspace__/...` in the ZIP; sidecar
records marked `sourceScope: workspace` identify their actual workspace-relative
restore paths. No proprietary binaries/assets enter the source backup.
