# Live client projectile presentation — 2026-10-16

Progress toward the active spellcasting/combat/campaign goal. Local safeProjectile
messages now reach a live client receiver, independent client object array, active
spell metadata, real MDL/bitmap loading, native path/phase services and scene/model
cleanup. An installed wizard prepared cast produced a visible moving projectile.
This is not completion of all projectile appearances, effects, spells or combat.

Read-only target NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install/Ghidra project unchanged. REA isolated import remains warm.
Previous verified checkpoint `client-projectile-path-1824-20261016-v1.zip`:
9460 files,112337621 bytes. [Path evidence](client-projectile-path.md) and
[header evidence](client-projectile-message-motion.md) describe prior captures.

## Connected behavior

`ClientObjectArray` mirrors canonical objects into the external half of a separate
native-style client GameObjectArray. Fresh projectile state uses AddInternalObject
and type8. Mirrors hold canonical identity and live native XYZ pose getters;
inserting a mirror cannot overwrite its server object's ID. Client deletion and
internal allocation leave authoritative IDs/allocation cursors unchanged. This
reuses the previously tested allocator; it is not a new network object importer.

`ClientProjectileInbox` captures canonical source/target identity at receipt,
queues while the area is built and rejects old areas/replaced objects. The
presentation checks identity again after asynchronous model loading. Late loads
are disposed after area teardown; no resurrection or attachment to a reused ID.

`clientProjectileSpell` reads the active physical spell row, CResRef widths,
Proj/ProjType, ProjModel, ProjSpwnPoint, ProjOrientation, cast visual refs and
cast/projectile sounds. Loader evidence2b1f99..2124 and2b22ef..238e maps spawn
hand/head/monster suffix (CRT atoi/clamp0..9) and orientation target/path. Shared
casting metadata already has independent loader tests. This new field projection
has source/assembly checks and data tests; the complete loader is not re-executed.
There is no spell-name/ID runtime branch. Daze identifies an installed test input.

The spell branch follows receiver7ac670: source cast-controller call, authored
handconjure/headconjure/monsterN/root part lookup with packet+Z1 fallback, active
cast sound and Proj admission. It creates native-shaped projectile state from
9832a0, configures sounds/facing from9876a0, loads the active asset, sets pose,
scene, time, stage1, endpoint/target and path. Path4 creates four additional
projectiles only after its first model succeeds; first-load failure deletes the
first object without creating those extras. This receiver is traced from the
complete retained assembly/pseudocode plus tested lower owners, not independently
executed end-to-end against the full native receiver.

Near-zero packet direction uses +X with zero Y/Z: native7ac79c initializes the
cached zeros, and7aca65 overwrites X with1. Normal directions use native magnitude
and normalize semantics. The model orientation handler9ddda0 uses Vector Pitch
22de40, **Vector** Yaw22f690 (Quaternion Yaw22f5d0 is different), then
YawPitchRoll22f6d0. Yaw is atan2(-X,Y); native forward is +Y. Verified global axes
14128f918/+928/+938 select pitch+X/roll+Y/yaw+Z. Shared native math and quaternion
multiply preserve float32 grouping; the renderer's coordinate basis is separate.

`ClientProjectilePresentation` binds the previously tested path coordinator and
stage owner to real models, current world time and the client's animation RNG.
Generic visual/projectile loading now shares the same asset/texture/animator
functions. Each projectile owns its model/textures and releases them at teardown.
Native elapsed/path ordering, travel/impact phase, loop-sound lifecycle, impact
time and deletion now come from the shared AI coordinator983860. Async loading,
renderer frame scheduling, scene/culling and model creation remain adapters,
not proof of the complete native client AI/base-object construction/destructor.

## Validation

- AI capture `native-client-projectile-ai-observations.json`:1356 complete
  original AIUpdate executions, with time/subtraction, path, model stage, camera,
  sound APIs and destruction captured as lower services. Tests match phase,
  elapsed/remainder handling, stages, loop flags, sound ordering and teardown.
  Impact attachment is exercised with an unresolved target only; real target
  attachments, camera-facing calculations and audio output are outside scope.
- Orientation capture `native-client-projectile-orientation-observations.json`:
  130 original model-orientation executions, including native yaw/pitch,
  YawPitchRoll, normalize/quaternion multiply and embedded SSE CRT functions.
  Quaternion setter, sqrtf and CRT FP-status notification are captured. Exact
  quaternion bits, cutoff and success match. Explicit SSE dispatch0/round-nearest;
  live process CPU dispatch/exception state and arbitrary CRT inputs remain open.
  First run stopped at missing FP-status lower; finalv2 passes.
- Ownership/lifecycle tests verify external/internal collisions, authoritative
  cursor preservation, live poses, expired model/scene/client-ID cleanup, old
  area delivery, replaced canonical identity, late-load disposal, failed model,
  native first-load/path4 rule and explicit unsupported path failure cleanup.
- Full1834 tests and production build pass (`client-projectile-render-full-tests-v1.txt`,
  `client-projectile-render-build-v2.txt`). Targeted10 tests pass. Existing rendered
  spellbook, self-wheel, slot consumption, hotbar F2/cancel, cast animation and
  counterspell world-wheel regression pass after asset-loader sharing
  (`client-projectile-existing-casting-ui-v1.txt`).
- Rendered projectile acceptance `client-projectile-render-ui-v5.txt` and
  `live-projectile-ui.json`: untouched installed wizard prepared Daze37, selected
  through active Proj/ProjType/ProjModel data, actual spellbook/world target and
  release. Loads vpr_los, one client internal ID0, stage1 while moving, one impact,
  stage2 and one deletion, no receiver failure/JS error. It also runs the original
  installed spell impact/effect system; this fixture keeps startup/entry overrides
  and does not constitute campaign play. Canonical-ID preservation has separate
  ownership tests; no claim of a live native multiplayer protocol comparison.

The first rendered test incorrectly clicked a spellbook Close after target setup
had already closed it. The next assertion incorrectly demanded travel01 in every
model. Installed vpr_los has **no animation clips**. Native handle9ddd00 still
reports stage success when Gob cannot find a clip (independently tested earlier).
Acceptance compares the actual installed animation inventory and retains missing
travel01/impact01 diagnostics; no substitute clips were invented. Failed captures
are retained. The inspected PNG shows a bright authored projectile in a dark,
partly occluded library; lighting/occlusion remain issues, not an error-free world.

## Remaining work and diagnostics

The old broad `visual.projectile-scene-unimplemented` warning is replaced by real
delivery and specific observed omissions/failures:

- Native cast visual controller: `visual.projectile-cast-visuals-unimplemented`.
- Missing target c_dummy allocation/lifetime: `visual.projectile-dummy-unimplemented`.
- Ranged ammunition/weapon appearances: `visual.projectile-ranged-unimplemented`.
- Placeable/door impact part prefixes: `visual.projectile-target-prefix-unimplemented`.
- Impact/weapon/shield attachment: `visual.projectile-impact-attachment-unimplemented`.
- Moving loop audio: `visual.projectile-loop-audio-unimplemented`. Cast/impact
  one-shots reach browser audio with `visual.projectile-audio-adapter-incomplete`
  for native priority/attenuation. No claim of native mixer parity.
- Missing models/clips, stale identity, receiver/update and object sync failures
  have separate durable diagnostics. Unavailable path/init/reset-node services
  throw, are logged by the presentation boundary and free the allocated model.

Finish path8/11/12/13 scene-hit builders, random/linked initialization4/7/9/12,
child spawns, high-ballistic reset-node external animation, c_dummy, cast controller,
impact prefixes/attachment and audio. Then verify their live resource/lifetime
branches. Native client CC8 cast/release widgets remain separately diagnosed.
Previous auditv47 remains65 unbound/22 missing resources; no new engine-call audit
was run because this increment adds presentation services, not command bindings.
Full spells/combat/campaign acceptance remains unproved and the goal stays active.
