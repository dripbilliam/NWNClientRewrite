# Native location and private-host effects — partial migration

No public game-server connections were made. The supplied native screenshot is
the lighting/fog/asset reference; this milestone does not claim that scene's
complete visual parity. Original binaries, production `src/main.js` and the
existing production distribution remain unchanged.

## Two independent native paths

`ApplyEffectAtLocation` produces decoded **area-visual packet4/2**. It is not an
object looping effect with an invalid target. The original type11
CNWCVisualEffect selects one model, starts its impact clip and counts down an
independent retirement tail. The first local check exposed that Godot had no
consumer for this message, while the old hidden Three owner still consumed it.
The isolated bridge now disables that old presentation and Godot owns the
visible model, original animation, particles, countdown and disposal.

`prepareAreaVisualDefinition` reuses `src/area_visual_effect.js` loader872770's
physical column order and typed table results. The native
`area_visual_state.gd` ports start873160 and AI872330, including unsigned
millisecond remainder semantics, zero-countdown retention, sound call order,
instant/cessation phases and retirement. Models/resources remain external to
the workspace. Their native instances never enter replicated object, picking
or collision registries.

An **object-visual** with an invalid target follows receiver1407857f0 instead.
That path now uses the shared original-derived client object-array and dummy
admission helpers. Godot imports the original `c_dummy` (seven physical parts,
zero meshes) as a private host; effects resolve its actual anchors. ID/token
namespaces keep these hosts distinct from canonical actor IDs. The source-role
status-zero abort quirk is preserved, IDs are not recycled, and asynchronous
loads cannot publish into a retired world. Queued admissions resolve on close.
The same internal allocator also owns area-effect type11 identities; it is
prepared for future projectile integration, which is **not complete**.

`client_fade.gd` owns fade/expiry decisions in the native frame loop. The
10-second point-host delay begins at actual native model admission, so pending
asset IO cannot consume the visible lifetime. Its time provider is explicitly
a local monotonic projection using the module day length. Exact server pause,
time-offset synchronization, native cache/display virtual internals and
original synchronous resource scheduling remain unported.

## Evidence

- `client-fade-v3.json`: **9,600 original-instruction cases /27,936 comparisons**,
  zero state or provider-call mismatches. The first run falsely compared JSON
  integer and float representations; the corrected test compares numeric
  values recursively.
- `area-visual-state-v2.json`: **784 original-instruction start/AI cases /2,352
  comparisons**, zero mismatches. The existing JS test still verifies all928
  original loader/start/update cases against the retained binary observations.
- `point-visual-focused-v1.txt`: **54 Node tests pass**, covering original
  helpers, definitions, scoping, cancellation, internal-ID collisions, original
  source abort, transport bounds and cleanup. Two independent evidence tests
  reject socket-only/exit-zero, frozen pixels, missing expiry and leaked owners.
- `point-visual-series-v1.json`: **two source-frozen local Vulkan runs**, each
  with30 visual checks and16 preceding dialogue/examine checks. Both receive
  real `ApplyEffectAtLocation` packets from authored `GodotPoints`, render and
  animate the original model, change Vulkan pixels, retire the area effect and
  release its models/particles. Across the series,12 tracked outer world owners
  retire with zero tracked survivors; both particle pools close with zero
  remaining threads and native exit0 without forced shutdown.
- The same runs each include **two explicitly authored invalid-target adapter
  probes**. These are not represented as real server object-dummy packets.
  They verify original zero-mesh `c_dummy` import/anchors, placement, actual
  effect pixels, transient completion, one native10-second expiry, monotonic
  replacement IDs/tokens, one cached import/two fresh instances and shutdown
  while the second host is still active. Backend canonical IDs stay unchanged.
- `point-visual-local-v4.json` is an additional earlier30-check local pass.
  Series bridge **v39** is immutable and retains source/asset digests. Earlier
  v37/v38 builds are preserved. The ordinary owned `GodotFeedback1` server is
  restored by the series launcher.

Retained failures: `point-visual-local-v1` failed before world admission on a
probe type annotation; v2 lacked the area-message path; v3 exposed a probe's
incorrect `source50` field name (the original state cell is `source58`). These
are failed attempts, not successful acceptance. v4 and both frozen-series runs
pass. Previous native heap-corruption evidence remains unexplained and is not
declared fixed by these passes.

The original target is installed read-only nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Retained numeric observations are
`backups/animations/native-{client-dummy,area-visual}-observations.json`.
The authored fixture uses read-only installed NWScript signatures/constants,
module SHA256
`6487617c8a63db2319f90f04260fa9d4f2b53a4ba5d41495189c28f088d693b0`.

## Remaining

Special area ground-normal alignment, IDs39/40/219/253 special renderer rules,
shake, positional/duration audio and complete native light/material policy are
still diagnosed. Beam/procedural/projectile stages, transform-controller maps,
full native world timer/cache scheduling and live pending-work transition
coverage remain open. This component evidence is neither full VFX migration,
full multiplayer readiness, public-server acceptance nor sustained60FPS
acceptance. The migration goal remains active; the last accepted rollback is
still `native-retirement-tested-v1.zip`, with this milestone saved as WIP.

Later work: [native world audio](NATIVE-WORLD-AUDIO.md) connects the previously
diagnosed effect/script sound providers. Its functional/mixer evidence and
remaining shutdown failure are tracked separately from this rendering milestone.
