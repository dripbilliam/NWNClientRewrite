# Direct-native spell projectile delivery

Later [casting visual follow-up](NATIVE-CAST-VISUALS.md): conjure/release models,
chants and native model-event/cleanup ownership now run in Godot, including
Proj=0 parent release. The historical milestone below predates that work;
complete impact/special paths/clock/shape and mixed-client acceptance stay open.

Later native ranged follow-up: ordinary ballistic ammunition now has actual
localhost server/flight/body-attachment acceptance, original area-weighted Part
selection and finite CRT orientation coverage. See
[NATIVE-RANGED-PROJECTILES.md](NATIVE-RANGED-PROJECTILES.md) for current evidence,
the controller material-binding fix and remaining special-path/mixed-client gaps.
The spell milestone below retains its historical scope and report names.

The subsequent [special-projectile follow-up](NATIVE-SPECIAL-PROJECTILES.md)
adds sling hit/miss bounce and deflection, original collision-plane/polygon
queries and conservative static scene acceleration. Full special-path, impact,
clock and mixed-client acceptance remains open.

The normal client now forwards decoded safe-projectile headers to a Godot-owned
projectile receiver. Native workers resolve the active `spells.2da`, original
models, textures and named animation/controller data. JS does no projectile
model selection, asset preparation, motion, attachment or rendering. Protocol,
authentication and download services are still transitional JS owners.

This is **partial combat migration**. Homing Fireball has real original-server
delivery/render evidence. Common path owners have broader stored native
observation coverage. Specialized ranged/random/bounce branches, release visuals and mixed
original-client acceptance remain open; this is not complete projectile parity.

## Native ownership

- `native_data/projectile_spell.gd`: active physical spell rows, native widths,
  resource references, path/spawn/facing selection. Server tables determine
  these fields; no fixed spell-to-model database is used in production.
- `native_data/projectile_state.gd`: reviewed path configuration/initialization,
  node ownership/advancement, target resolution, high-ballistic/spiral builders,
  basic/spiral motion, binary32 arithmetic, UINT wrap/countdowns, stage selection,
  loop/impact sound ordering and final retirement. Model/RNG/scene services stay
  explicit providers.
- `native_render/projectile_world.gd`: retained world-scoped pending/active
  owners, native worker resources, actual physical source/target Parts, private
  original model instances, travel/impact animations, moving sounds and cleanup.
  Shared private allocation gives type-8 projectiles and temporary `c_dummy`
  targets distinct IDs without touching server state, collision or interaction
  registries. A missing target expires at original travel plus 500 ms.

Queue and per-frame preparation admission are bounded. Source/target identity
checks reject deferred events for replacement actors. A target absent when the
packet arrived stays a private dummy even if a real actor arrives during worker
preparation. Reusing a live canonical target retires the old projectile rather
than binding to its replacement. World shutdown drains worker jobs and releases
projectile models, auxiliary models, sounds, dummy IDs and provider references.

The travel clock includes native preparation delay instead of granting a fresh
full flight after resource loading. `ready` evidence records `preparationMs` and
the actual server duration. This uses local monotonic presentation time;
authoritative pause/world-clock synchronization and precise pre-world packet
age remain open. Profiling includes a disjoint `callback_projectiles` owner.

Scene wiring currently admits spell paths 1/2/3/5/6/7. Some lower path-3 external
animation behavior and linked-path scene cases still diagnose missing services;
stored path tests prove algorithm/provider ordering, not those renderer services.
Unsupported special ranged, random/burst and bounce branches emit diagnostics rather
than being replaced by straight-line projectiles or invented server outcomes.

## Original reference and scope

This ports retained original-derived owners and replays earlier read-only
observations. No new process injection or original-binary modification occurred.
Original target SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

Reviewed entries: receiver `1407ac670`; constructor `1409832a0`; AI `140983860`;
basic/spiral motion `1409845c0` / `1409848d0`; path configure `140987770`;
initialize `140987f10`; next node `140988ed0`; path update
`140984f00..1409854c1`; stage selection `140985510`; projectile animation handle
`1409ddd00..1409ddd9d`. Header decoding and object-ID widths remain in the
transitional protocol codec. Target lookup, animation, RNG, audio and GPU output
are distinct lower services, not automatically proven by these function cases.

Reference owners are `src/client_projectile_runtime.js`,
`client_projectile_path.js`, `client_projectile_motion.js`,
`client_projectile_animation.js`, `client_projectile_target.js` and
`client_projectile_dummy.js`. Their original observation files remain under
`backups/animations/`; original resource payloads are not authored here.

## Evidence

- `reports/native-projectile-state-v2.json`: **20,903 checks**. Inputs cover
  17,518 path cases (including 240 complete multiframe trajectories), 1,318
  motion cases and 1,356 AI/timer/sound cases. Exact binary32 bit patterns,
  signed zero/NaN classification, callback order, target lookup failures,
  radius/threshold admission and countdown wrap are compared. This is replay
  of stored original observations, not fresh binary measurement.
- `reports/native-projectile-spell-v2.json`: **11 checks**. Seven installed
  original spell rows match the retained original-derived loader; an authored
  server override controls model/path/physical spawn/facing and invalid rows
  remain unavailable. The complete default effect/projectile scripts parse.
- `reports/native-projectile-live-final-v1.json`: **31 checks**, actual unchanged
  original server at localhost port 5125. The authored `-native-projectile`
  command queues a real Fireball through original `ActionCastSpellAtObject`;
  the original server emits the safe-projectile packet. Source/target identity,
  active spell model, physical flight, actual viewport output and travel/impact
  cleanup pass. The packet duration is 242 ms and native preparation is 14 ms
  in the inspected v6 run; the final run records its own values. The render comparison samples a 200×200 region around the
  projectile, excluding the changing FPS label. The capture was inspected.
- `reports/native-projectile-reference-node-v1.log`: **23 tests**, raw event
  transport and retained projectile/reference regressions.
- `reports/native-projectile-lifetime-v3.json`: **11 checks** using actual native
  models/owners under authored headers. Reused/deferred stale targets, late
  canonical arrival after a missing-target packet, an already-expired delayed
  flight and complete private host/model/provider cleanup pass.
- `reports/native-projectile-actions-regression-v1.json`: the existing **62**
  actual original-server gameplay/menu/combat checks pass.
- `reports/native-private-dummies-projectile-regression-v1.json`: **12** original
  native dummy expiry/allocation checks pass after the shared allocator change.
- `reports/native-projectile-lifecycle-v1.json`: cancellation (2.097 ms in this
  run), abort during streaming, two actual original Prelude reconnect cycles and
  stale-connection isolation pass, with clean native exit/worker release.

Native runs use normal-heap exception capture and pinned sources. The accepted
final live run exits with no trapped exception, unchanged sources, zero remaining
workers and zero public connections. Functional FPS counters and small-scene
timings do not prove general performance or original-binary rendering parity.

Retained failures: the initial native state fixture used numeric zero instead
of a missing model; generic NaN normalization touched UINT identities. Fixtures
were corrected without changing stored native expectations. The initial server
target was across a real line-of-sight blocker: original feedback 21 / TLK 7954
correctly rejected the spell and emitted no projectile. The authored target was
moved onto the known-clear admission walk. Another run exposed a probe querying
the UI instead of the session's interaction registry. These failures remain
recorded rather than being treated as passing live projectile acceptance.

## Remaining acceptance

Special ranged ammunition/shield/deflection and random/linked/bounce/burst
paths, conjure/cast release visuals, children, complete impact effects,
exceptional-state/CPU-dispatch CRT parity,
full native client-field replication, additional model/shape/door targets,
paused clocks and mixed-client play remain open. Homing spell and ordinary
ballistic arrow flight have scoped real-server render evidence; other paths
require their own end-to-end checks.

Particles stay off by default. The visual test temporarily enables them in
memory and restores the user's setting. All current automated joins use owned
localhost servers. The full acceptance gate remains
[original-client parity and base playability](BASE-GAMEPLAY-GOAL.md).

Verified source checkpoints: `backups/native-point-area-beam-after-v1.zip`
before this projectile implementation, and
`backups/native-projectiles-direct-after-v1.zip` after it. The latter includes
related authored JS reference sources/tests, not original binaries/assets.
`reports/native-projectiles-final-audit-v1.json` indexes accepted evidence,
current tested source hashes and checkpoint integrity. Recheck without launching
a game using `node godot-client/tools/audit-native-projectiles.mjs --report=native-projectiles-audit-v2.json`.
Reports use exclusive creation; choose a new name for each retained audit.
