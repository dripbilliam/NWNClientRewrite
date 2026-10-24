# Private visual model resources

This is an effect/projectile resource prerequisite, **not** completed server
effect or projectile presentation. Godot can now import, animate, attach, draw
and retire an independent model graph without inventing a replicated creature,
collision body or pick target. Original meshes, UVs, bitmap data, clips, skin
arrays and reference ownership use the existing resource pipeline.

## Resource and instance ownership

`tools/staging-visual-model.mjs` loads through the active area's original visual
asset provider, instantiates in an isolated identity scene, and uses the real
`ModelReferenceScene` for recursive child ownership. It does not restart the
Three frame loop, add canonical object IDs or add these instances to the old
world's animation roster. Export success, failure and retired-area completions
all release the private temporary models. Connection/presenter/area-generation
changes discard late results; current preparation errors remain visible.

`tools/export-visual-model.mjs` shares the rig, skin, clip and particle transfer
code. `prepareVisualRigTransfer` accepts an explicit private graph rather than
a fabricated world/registry adapter. Handle 0 is local to the resource. Models
retain their physical root part even when source node storage is out of order;
duplicate-name lookup follows the physical DFS order. Referenced roots remain
independent siblings with P/Q-only attachment and their own scale. An outside
anchor or unrelated model cannot silently enter the resource graph.

`external-bundle.cjs` writes authenticated GLB and metadata only into external
OS temporary directories. Private resources cannot replace the captured-room
reference. The normal room/delta inventory requirements remain in force.

`systems/visual_model.gd` owns each imported scene, private rig, AnimationPlayers,
skeletons and mesh index. It creates no EntityRegistry or physics bodies.
Instances have independent animation and skin owners. Canonical animation runs
before external attachment sampling, then private rigs, then particle sampling.
Native P/Q attachment ignores anchor scale; mode 3 retains world orientation.
Detach preserves world pose. Explicit retirement or a destroyed external anchor
releases the instance. Ordinary named-clip playback is exposed explicitly;
original stacked playback flags have **not** been reduced to a loop boolean.

## Evidence

- `reports/visual-model-node-regressions-v3.log`: **50 Node cases pass**, including
  recursive reference cleanup, source graph immutability, skin/clip transfer,
  malformed/private graph rejection, area/disconnect/export races, external
  bundle ownership and existing world/particle/export regressions.
- `reports/visual-model-native-vulkan-v2.json`: **74 actual Vulkan checks pass**.
  Two private instances import a real external authored GLB; independent native
  players/skeletons, mode 0/3 reference poses, GPU skin readback, physical root
  aliases/duplicate names, no physics, external attachment, detach, invalid
  metadata and complete retirement are verified. Maximum source-reference
  matrix error is `6.4473e-7`; maximum skin position error is `1.5259e-5`.
  Active/hidden drawing differs by **1,358 pixels**. These are authored assets.
- `reports/visual-model-rigs-regression-v1.json`: all **65 existing native GPU
  rig/skin/collider checks pass** after the shared importer changes.
- `reports/native-visual-resource-local-v1.json`: build **v20** exports the actual
  installed `c_golstone` through the new staging function during an owned local
  server session. The external bundle has **19 meshes / 806 triangles** and
  original bitmap data. All **16** dialogue/examine checks also pass; native
  exit 0 and renderer errors empty. This alone does not prove resource drawing.
- `reports/visual-model-installed-v1.json`: **9 separate native installed-asset
  checks pass** using that exact authenticated bundle. The original
  `ca1slashl` clip advances 16 physical parts; the installed bitmap reaches native
  materials, actual Vulkan drawing differs from hidden by **9,141 pixels**, and
  retirement succeeds. The captured frame was inspected. Its high-contrast
  surface pattern is present in the external source bitmap; this is not an
  assertion of native lighting/material parity or a clean benchmark.
- `reports/native-visual-resource-local-v2.json`: final build **v21** additionally
  guards connection-world object identity, including reconnects that reuse the
  same numeric area/generation. All 16 local checks pass, native exit is 0 and
  renderer/engine errors are empty. Its model GLB and metadata hashes exactly
  match the v20 bundle already imported/drawn in the installed-asset test.
- `reports/native-visual-model-particles-local-v1.json`: build v19's **22** real
  local particle/dialogue/examine checks pass, including original flame pixels
  (**14,563** changed pixels), 70 worker frames, disconnect/exit 0 and closed
  workers. Four absent cloud bitmaps and two unavailable wind emitters remain
  explicit existing failures; native buffer/render errors are zero.

Initial headless v1 exposed a GDScript type-inference parse error. V2 exposed
an unnecessary collision metadata lookup and missing-anchor retirement failure.
Their logs remain. Corrected v3 passes all 39 then-existing headless checks;
the later final Vulkan v2 includes the extra physical-root checks. Native logs
for the final Vulkan/installed/rig runs contain no script, renderer or leak errors.

## Reproduce and remaining work

Run `join-local.ps1 -VisualModelSmoke -Report <unused-name>.json` against the
owned `GodotGameplay` module. This additionally exports the installed model to
an external bundle. Then run `tests/visual_model_resource_test.gd` with
`--source-report=res://reports/<that-name>.json` and an unused `--report`, using
the pinned Godot executable, Vulkan and an absolute dedicated `--log-file`.
The authored graph/skin test is `tests/visual_model_test.gd` using an oracle from
`tools/visual-model-fixture.mjs`. Preserve unrelated games/editor and do not use
these functional runs as clean FPS measurements.

Still required: scoped live transient-effect rosters and async asset caching;
reuse of original visual loader/selection/phase/program/cessation owners;
stacked native animation runs and manual part gates; real source/target beam
reattachment and retarget notifications; effect-scoped particle bindings,
per-instance emitter IDs, lights/material controllers and audio; original
projectile paths/stages/impacts and dummy lifetimes. The private resource path
is available to those adapters, but it does not yet spawn server effects.
Actual installed effect cases, transitions/reconnect with pending effect jobs,
full feature coverage and sustained moving-world >=60 FPS remain unaccepted.
No Arelith connection was made. The migration goal remains active.

[NATIVE-VISUAL-PHASES.md](NATIVE-VISUAL-PHASES.md) now adds native phase timing,
an original-loader definition adapter and scoped imported-resource caching.
Live event/list delivery and native placement/program/playback integration
remain required before this becomes server effect presentation.

Subsequent integration: [NATIVE-LIVE-EFFECTS.md](NATIVE-LIVE-EFFECTS.md) records
actual local event delivery, native selection and private geometry/particle
lifetime checks. Live rosters and basic manual part gates now work. Full
stacked playback, controllers, programs and projectiles remain incomplete.
