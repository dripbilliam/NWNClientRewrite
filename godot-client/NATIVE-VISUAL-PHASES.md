# Native effect timing, definitions and resource cache

The native phase clock, original-loader definition path and scoped resource
cache are implemented and verified as components. **Live server effect spawning
is still incomplete.** These components are not yet the native effect roster,
selection/placement/program provider or projectile runtime.

## Ownership and original methods

`systems/visual_phases.gd` ports the reviewed original start/restart
`140970e20..14097152b`, stop/cessation `140971530..140971955`, and update
`140971a80..140971e10` owners. Logical offset names preserve their field identity.
It retains impact/duration/cessation transitions, unsigned countdowns, the
first-slot cessation retirement writes, first-equal physical model aliases,
callback-driven pointer replacement, sound/controller cleanup and idempotent
disposal. Placement, model playback, program dispatch and audio remain explicit
synchronous providers rather than invented fallback actions.

`systems/visual_clock.gd` advances that owner from Godot's process loop. It
preserves fractional milliseconds across frames and the existing scene adapter's
whole-millisecond/DWORD conversion, rather than truncating each delta separately.
It does not await network packets or asset IO. Retirement emits a notification;
the outer physical effect list still owns selection/removal order. Closing or
freeing the clock disposes its phase owner once.

`tools/visual-definition.mjs` reuses `loadVisualEffectAsync` for the actual loader
decisions: size/quality/violence alternatives, physical anchor availability,
root-model program suppression, instant/duration gating, controller copying,
model aliases and warning/retirement fields. Resources are cached as data within
one definition; each geometry slot retains an independent model handle. All
active program parameter query outputs, including found/default semantics and
the correct Type4/7/12 resource columns, are retained for the native provider.
No phase clock, CPU model animation or skin deformation runs in this helper.

`staging-visual-definition.mjs` reads the actual physical host binding and active
area tables. Target/source binding replacement, new connection-world identity,
area/generation change and closed presenters invalidate pending results.
Removed/out-of-area actors cannot acquire definitions. Nonidentity network or
body transform controllers remain explicitly unsupported, matching the existing
source adapter's limitation.

`visual-definition-bundle.cjs` writes original resource payloads and resolved
definition metadata only into external OS temporary bundles. Hashes cover the
scope, phase decisions and resource references. `systems/visual_resources.gd`
validates those hashes and admitted-world scope before importing resources.
Each GLB is imported and packed once per immutable resource in that world;
fresh native model instances own their own nodes, players, skins and reference
attachments. Cached rigid geometry and textures are shared. Reusing a resource
name with a different digest cannot replace the current world's template.
Clearing the cache releases templates while existing instances retain their
owned resource references; the outer world/effect owner must retire those nodes.

## Evidence and its limits

- `reports/visual-phases-native-v8.json`: **13,596 native checks pass**, with
  engine exit 0 and no script/leak errors. This includes 96 authored scenarios /
  2,400 operation steps comparing complete state and provider callback order,
  816 exact-binary64 frame-clock steps and actual Godot process-loop advancement.
  Sub-millisecond accumulation, large DWORD wrapping, target/render loss,
  model aliases, replacement callbacks and repeated disposal are included.
- The same native run directly passes **688 retained original-function
  observations**: 362 start/stop and 326 update cases. Target build SHA-256 is
  `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
  These are existing controlled observations, not fresh profiling or changes
  to the original running process. Their lower providers remain explicit.
- `reports/visual-phase-definition-regressions-v1.log`: **53 Node cases pass**,
  including new loader/staging/external-envelope tests, existing model/export/
  reference regressions and the original loader/phase/selection observation
  suites. The latter cover 767 loader, 688 phase and 1,221 selection/competing
  removal original cases; native selection itself is **not** ported here.
- `reports/native-visual-definition-local-v1.json`: build **v22** passes all
  **16** real owned-local dialogue/examine checks with native exit 0 and no
  renderer errors. A separate bounded **installed-data probe** uses the actual
  active tables and controlled actor to resolve visual ID 1, one original
  69,540-byte resource, no loader warnings, and an external scoped definition.
  It does not fabricate or claim a decoded server effect event.
- `reports/visual-resources-native-v2.json`: **19 actual Vulkan checks pass**
  using that definition and the original stone model bundle. Two GLB imports
  create three private instances, with one verified cache hit. Geometry and
  original bitmap references are shared; player states remain independent.
  Scope/digest/name-change guards, cached-instance drawing after cache release
  (**5,708** changed pixels), and **114/114** native nodes freed are verified.
  The frame was inspected. This is a small functional resource test, not an
  effect-fidelity or sustained-world FPS result.

Failed runs remain visible. Initial phase harness runs exposed numeric int/float
comparison, signed-64-bit decimal formatting and mutated fixture initialization
problems. The native disposal port also initially invoked the wrong outer clear
callback; direct lower cleanup now matches the original order. Clock v5 exposed
an explicit GDScript type requirement. Clock v6 showed decimal JSON perturbing
fractional inputs; exact binary64 input/expected bits prove the final clock
without relaxing equality. Cache v1 queried animation time on an intentionally
idle sibling and logged an engine error despite passing assertions; v2 verifies
the idle state directly and has a clean engine log.

## Reproduce

Generate an authored oracle with `tools/visual-phases-oracle.mjs --output=<unused>`.
Run `tests/visual_phases_test.gd` headlessly with `--oracle=<that-file>` and an
unused `--report`, using the pinned executable and an absolute `--log-file`.
The test also reads the retained observation metadata from
`backups/animations/native-visual-phase-{control,update}-observations.json`.

`join-local.ps1 -VisualDefinitionSmoke -Report <unused-name>.json` requires the
owned `GodotGameplay` module. After it completes, run
`tests/visual_resources_test.gd` with Vulkan,
`--source-report=res://reports/<that-name>.json`, an unused `--report`, and an
absolute dedicated engine log. Preserve unrelated games/editor. No Arelith
connection or clean benchmark was performed for this milestone.

## Remaining integration

- Decoded loop/instant server effect delivery, physical list ordering, async
  cancellation/retry, duplicate removal and native selection/rebinding.
- Full native placement/type-program providers, exact manual part control gates
  and stacked animation runs; the new clock intentionally does not map original
  playback flags onto a generic loop boolean.
- Effect-scoped particle IDs and native binding resolution, source/target beam
  retarget notifications, controller/material/light updates and audio.
- Original procedural projectile paths/stages/impacts and shared dummy lifetimes.
- Actual server-spawned effect visual checks, repeated transitions/reconnect with
  pending effect work, complete feature coverage and sustained >=60 FPS.

The goal remains active. The prior working client and original binaries are
unchanged relative to their pre-milestone pins; component passes do not complete
Godot migration or performance acceptance.

Subsequent integration: [NATIVE-LIVE-EFFECTS.md](NATIVE-LIVE-EFFECTS.md) connects
the phase clock/cache to actual local duration and instant messages, native
selection and basic placement/playback. The requirements above remain open
except those explicitly covered by that integrated evidence.
