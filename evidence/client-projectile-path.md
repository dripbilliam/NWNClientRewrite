# Client projectile path lifecycle — 2026-10-16

This advances the active spellcasting/combat/campaign goal. Shared path logic and
animation stage selection are implemented and compared against original code.
The live safeProjectile handler still records `visual.projectile-scene-unimplemented`:
these services are not yet connected to projectile models, client object-array
allocation or scene lifetime. There are no spell-specific runtime exceptions.

Target: read-only NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
REA isolated Ghidra analysis identifies function bodies/callers; Unicorn executes
original instructions with owned synthetic state. Original game/project untouched.
Previous verified backup: `client-projectile-1815-20261016-v1.zip`,9423 files,
110550160 bytes. The prior [header/motion evidence](client-projectile-message-motion.md)
is historical; the implementations below supersede its open path items.

## Implemented owners

`src/client_projectile_path.js`:

- Configure987770..987e9f retains the raw path INT, updates the endpoint from a
  successful object lookup, destroys the queued physical nodes and constructs
  native common layouts. Invalid/unresolved target references use absolute
  coordinates; resolved client objects use offsets. Path7 attachment storage is
  zeroed separately. Path10 creates a kind12 node. Path50 creates two nodes with
  the original overflow-before-division split and child-spawn metadata. Unhandled
  switch values clear the queued list but retain the current node, as native.
- Initialize987f10..988d58 preserves type admission, missing-object zero-vector
  behavior, model-null versus part-lookup-failure behavior, offset addition,
  epsilon and timer rounding. Implemented deterministic kinds include native
  gravity2, accelerating5 and decelerating10;1/6 retain velocity while clearing
  acceleration. Kind10 mutates the supplied orientation argument's Z, which can
  alias caller storage. Configure/advancement pass a copy, matching their callers.
  Random/linked kinds4/7/9/12 remain explicit `initializeSpecial` providers.
- Build986390..986598 constructs high-ballistic ascent, instantaneous reset and
  descent nodes, preserving the unsigned half-duration split and native30-unit
  lift. Build986890..986bd2 constructs spiral entry/orbit nodes, CRT side draw,
  perpendicular fallback, optional initial reposition and fixed2500ms orbit.
  Shorter total time preserves native unsigned subtraction, without a new clamp.
- Update984f00..9854c1 resolves the live impact node twice where required, caches
  attachment coordinates, handles native model/lookup fallbacks and deflection
  offsets, and preserves expiry, elapsed remainder and subtraction ordering.
  Radius admission, previous position, basic/spiral dispatch and unknown kinds
  match the original. Lookup failure differs between its first and second pass.
- Next988ed0..9893bc destroys the prior current node once, retains physical queue
  order, implements kind11 reset position and default/travel animation transitions,
  sets new timers/endpoints and calls initialization. It retains elapsed-time
  comparisons and skipped-node behavior rather than accumulating a guessed timer.
  Child projectile construction remains an explicit `spawnNodeChildren` service.

`src/client_projectile_animation.js`:

- Projectile animation ctor9dd9c0 identifies CNWCAnimBaseProjectile vtablee7d8e8;
  slot+80 points to9ddd00..9ddd9d. Stages0/1/2 select default/travel01/impact01;
  impact ORs flag1. Zero speed becomes1; other stages clear the model animation
  with speed1/flags0. The animation handle returns1 even if the underlying clip
  cannot play. Asset diagnostics must remain separate from this native success.
- Stage wrapper985510..98556a returns0 without a model handle; otherwise it
  stores the WORD stage on handler success. No guessed clip completion/lifetime.

The callable provider boundaries throw when unavailable. Unsupported path builders
8/11/12/13, random/linked initialization and child spawns are not substituted with
homing motion or generic particles. Full active-data loading and their live durable
error boundary remain part of the pending renderer integration.

## Original-code validation

`scripts/inspect-native-client-projectile-path.py` finalv5 capture:
`native-client-projectile-path-observations.json`,17518 cases:

| Mode | Cases | Executed original scope |
| --- | ---: | --- |
| Configure |912|Entire coordinator; special builders and initializer captured|
| Initialize |1281|Selected deterministic kinds, lookup/pose cases and no node|
| Update |11917|Entire frame coordinator; motion and next-node captured|
| Build |480|Actual high-ballistic and spiral builders|
| Next |2688|Actual advancement, with zero child counts|
| Flow |240|Configuration, initialization, building, advancement and actual motion composed|

Flow mode executes7920 native frame updates across paths1/2/3/5/6, valid/invalid
target IDs, model/part availability, timings and both spiral sides. Every frame's
position, orientation, velocity, acceleration, endpoint, cached attachments,
queue/current node, timers, stage and observable call order match the replacement.
It asserts240 trajectories explicitly, avoiding a vacuous pass on an old capture.
The80-step bound intentionally retains non-finished underflow cases; this is not
proof that every authored path completes. No full AI/scene/campaign claim.

Object/model/part/scene lookups, physical list allocation, external animation,
handle stage and imported sqrtf are captured lower services. The latter returns a
correctly rounded binary32 result; native normalize executes. In the individual
modes, the table above names additional captured lowers. Flow executes those
path/motion owners unchanged. Node advancement tests have no child spawns; path50
tests prove metadata/configuration, not child creation. Selected vectors compare
exact binary32 bits; nonfinite arithmetic compares NaN classification.

The first capture stopped at an incorrectly bounded vector-add helper. Verified
direct-call leaf CFG22b180..22b1ad corrected that range before acceptance. A later
test was started whilev5 capture was still running and correctly rejected the
older row count; it is not acceptance. Final targetedv4 passes after nativev5
terminal completion. Earlier captures/logs remain retained.

`inspect-native-client-projectile-animation.py`:1104 original cases, actual
985510/9ddd00 execute with Gob::PlayAnimation captured. Covers stage WORD wrap,
missing handle, positive/negative/zero speeds, flags, start times and both lower
return statuses. Targeted comparisons pass; this does not establish asset loading.

Full1824 tests and production build pass (`client-projectile-path-full-tests-v1.txt`,
`client-projectile-path-build-v1.txt`). Verified checkpoint is recorded in the
continuation note. Existing missing resources and native client-message/rendering diagnostics
remain. Auditv47 is still the previous65 unbound/22 missing result, not a new audit.

## Next required integration

Bind these owners to native client transients/type8 and external object mirrors,
active physical spell records, real model load/part lookups, per-frame world time,
travel/impact playback and destructor cleanup. Preserve authoritative ID cursors.
Finish random/linked/scene-sampled builders, child spawns, dummy targets, impact
attachments, audio and ranged appearances. No current utility claims those done.

Additional isolated dossiers now retain bounce985750, burst986db0 and
deflection985f20, plus projectile animation ctor/load/stage. They include native
vertical scene-hit queries and/or CRT calls; do not replace those with invented
floor heights or unseeded Math.random. Existing native_math/combat_animation
services are available for verified CRT arithmetic and random draws.
