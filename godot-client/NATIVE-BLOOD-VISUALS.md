# Native blood and hit visuals — scoped mode1 migration

Later mode0 parry-spark work and its separate scoped acceptance are in
[NATIVE-PARRY-VISUALS.md](NATIVE-PARRY-VISUALS.md). Full combat remains incomplete.

This is original-derived hit presentation in the direct native entry. It does
not complete combat, all SpawnHitVisuals modes, or mixed-client acceptance.
The server still owns damage, results, targets, inventory and creature identity.

## Reference and runtime

Read-only target: original nwmain.exe SHA-256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
`SpawnHitVisuals14080bb10` mode1 owns three physical blood-model slots. Earlier
instruction-execution observations and authored JS reference are in
`../evidence/multiplayer-blood-visuals.md`; JS is reference only. Runtime selection,
pose, resource preparation, clips and particles are native Godot.

| Source | Responsibility |
| --- | --- |
| systems/native_data/blood_visual.gd | Original selector, signed WORD arithmetic, physical slot query/reuse, finite pose math |
| systems/native_render/blood_world.gd | Hit requests, canonical lifetime/model binding, three private models, physical attachment and retirement |
| systems/native_render/projectile_world.gd | Original ranged AI impact record and incoming projectile direction |
| systems/native_render/effect_world.gd | Native workers/models, per-world ownership, snapshot and closure |
| systems/native_render/live_world.gd | Static-scene particle collision service and query/hit counters |
| systems/native_render/particle_emitter.gd | Collision boundary discovery only for flags16 emitters |
| systems/native_render/projectile_scene.gd and scene_geometry.gd | Original static collision faces and nearest position/normal |

Active appearance.BLOODCOLR and visualeffects.Imp_Impact_Node supply resources;
original row/category constants do not hardcode model names in production.
LowViolence redirection, red/green/yellow/white families, normal/large hits,
signed damage/maximum-HP selection, unarmed type7 low violence and constructor
kind/override defaults follow the original selector. Full/low gore uses the
replicated maximum HP when the original branch asks for it; missing data is
diagnosed, not replaced by guessed health. Later native render-override delivery
and full shape/clock semantics remain open.

The existing combat presentation gates damaging melee impacts from received
server attack records. Ranged impact uses the original zeroed attack-info record
with result1/3 and received impact damage; weaponAttackType remains0, not1.
Melee direction is attacker minus defender. Ranged direction is current minus
previous projectile position. Defender animation/equipment selects the original
orientation adjustment. Native quaternions are converted once to Godot axes.

Models play their own original impact clip, attach to the actual physical Part
with flags3, follow position and retain independent world orientation. Finished
impact runs leave models retained. Later hits destroy/reuse the first available
finished slot; a fourth simultaneous active hit allocates nothing. Creature
removal, lifetime reuse, physical model replacement and world close release the
owner and cancel stale pending work. Finished particle count is not a guessed
model lifetime. These private effects never become interaction/highlight objects.

## Scene collision boundary

REA observed PartEmitter constructor140060420 allocate
CHitInfo(mode1, maskFFFFFFFFBFFFFFFF, box0). Its receipt and pseudocode are in
reports/native-blood-scene-provider-research-v1.json. Original Standard movement
140068010..1400687f9 already has independently executed movement/response oracles.
The runtime now supplies that boundary from static native scene geometry rather
than stopping every bounce-enabled blood emitter as unsupported.

Original stored triangle planes/material mask and conservative immutable model
bounds are reused. Dynamic Gobs are excluded by mode1. Positions and normals
come from actual faces; there is no invented flat ground plane. World counters
particle_scene_queries/particle_scene_hits and the detailed profiling span
native_particle_scene_collision expose its cost. Non-collision emitters retain
their existing fused native path.

This scene membership and normal transform are a Godot adapter, not complete
original BSP/registration parity. Original normal-transform floating-point order,
all nonuniform/skeletal/dynamic scene semantics and chunk ignore-list delivery
remain unaccepted. Collision cost in dense fights needs broader measurement.

## Controls and acceptance

Options → Graphics → Blood effects saves Low0, Normal1 (original default), or
Full2. The world inherits changes immediately for later hits. Particles remain
off by default as requested; blood particle drawing follows that existing toggle.
Changing either preference never sends a combat result to the server.

Current component evidence:

- native-blood-data-v1: 4,579 checks against 1,020 complete original selector/reuse
  cases, 2,015 exact float acos outputs, 18 native physical animation queries,
  and 380 successful original pose cases. Pose bound remains1e-6; 1,452/1,520
  components compare exactly. Maximum numeric error is5.56e-17, including tiny
  residual differences; this is not an all-bit-exact-pose claim.
- native-blood-world-final-v1: 21 actual original-model checks: clips, non-null
  physical anchors, three-slot admission, moving bones/fixed orientation,
  retained finished models, ordered reuse, canonical/model replacement, stale
  requests and closure. Its no-geometry collision callback is explicit component
  scope, not world collision acceptance.
- native-blood-scene-v1: 83 original-face metadata and authored static scene
  position/normal/mask/transform/quarter-turn checks.
- native-blood-settings-v1: 23 actual settings/input/persistence and existing
  particle/profiling checks, non-activating on a secondary display.
- native-blood-bow-final-v1: 24 real local-server checks, original blood particles,
  non-null body anchors, viewport changes, actual static-scene particle collision,
  ammunition consumption and the existing8,000ms embedded-arrow expiry.
- native-blood-melee-final-v1: 65 real local gameplay checks including the original
  type7 low-violence blood model. The small visible effect changes15 viewport
  pixels in that final capture; this proves output exists, not matched native-client
  appearance or every gore/weapon branch. The first v1 probe sampled the initial
  zero-size phase and failed pixels; it is retained. The corrected probe waits
  for actual impact controller time beyond0.12s without modifying effect rules.
- native-blood-casting-regression-v1: 39 real-server Fireball/Magic Missile
  conjure/release, Detonate, effect/audio requests and cleanup regressions.

native-blood-prelude-regression-v1 passes two rendered Prelude cycles, one
streaming abort, pending-connect cancellation and reconnect. All final live
runs exit0 with unchanged pinned sources, native debugger traps armed, no caught
native exception and zero remaining workers. Final bow output changes55 pixels;
its world records22 collision queries/1 hit. Final melee records45 queries/1 hit.
The casting regression now exercises13,225 collision queries/570 hits as well;
these are work counts, not a performance acceptance.

Read-only aggregate verification: tools/audit-native-blood.mjs writes
reports/native-blood-final-audit-v1.json after checking original corpus hashes,
relevant current-source pins, native lifecycle results, pixel evidence and the
verified checkpoint. Before: backups/native-casting-visuals-direct-after-v1.zip,
SHA85f4882a45998f6439dcacbc28cc7754183cb821c309a7d849577e234aceacfd.
After: backups/native-blood-visuals-direct-after-v1.zip; the read-back manifest
contains its digest and per-file identities. Original binaries/art are external.

Screenshots retain the existing black terrain wedges. Some unrelated original
world emitters still diagnose missing scene wind; the tested blood emitters have
no embedded failures. Broader parry/shield/weapon effects, full death and
reaction/audio/timing coverage, broad custom content and paired original-client
gameplay remain required. No public/Arelith server was contacted. Background
captures are not clean FPS/performance evidence.

## Private constructor HP follow-up

The combined correction/combat checks exposed a separate bug: an ordinary
unarmed hit forces low-violence selection, which asks for the target's maximum
HP. NPCs often do not disclose HP. Treating that absence as a preparation error
made results depend on whether the attack happened to bypass that query.

Read-only original evidence in
`backups/animations/rea-client-presentation-hp-v1.json` traces creature
constructor1407fb140 → stats constructor1407ea7a0 → base1407ea230.
The base clears shorts84/86/88/8a. The derived constructor then computes
current88 and maximum8a from its initial one-level class4/race6 storage, the
active ruleset ability minimum/neutral/increment and active race/class gains,
clamping HP to at least1. These are client storage defaults, not inferred NPC
health. The normal update140781e80 mask400 replaces all four shorts; getter
1407f5e20 reads maximum8a. Class/type setters do not recompute those shorts.

`scripts/inspect-native-client-presentation-hp.py` executes unchanged base and
derived constructor, class-gain query, modifier, level/class getters, class
setters and maximum getter instructions from the pinned original. Its192 cases
vary rules, race adjustment and class gain, including byte wrap and signed
modifier behavior. Allocation, TLK, empty nested containers, ruleset lookup and
unrelated attack/spell caches are captured boundaries. The post-disclosure
fixture reproduces verified field writes; it does not execute a whole network
packet. Scope and source hash remain in the observation file.

Native `client_presentation_hp.gd` projects that constructor using connection
tables. Blood preparation waits for those tables and any declared class gain
table, caches the private result per world, and uses received HP when present.
It never adds guessed HP to authoritative objects, health UI or server actions.
Other HP consumers are not silently changed by this follow-up.

Current scoped receipts, all with unchanged pinned native sources:

- `native-client-hp-oracle-v1`:771 checks against the192 original cases and
  authoritative-data isolation/received-short replacement.
- `native-client-hp-blood-selection-v1`:4,579 existing selector/pose checks.
- `native-client-hp-blood-world-v1`:25 actual model/lifetime checks, including
  an unarmed undisclosed-HP hit selecting the original medium low-violence model.
- `native-client-hp-combat-actions-v1`:67 real owned-server checks on5125,
  including rendered target facing (0° error), native attack deformation,
  blood model anchors with zero preparation failures,12 changed viewport pixels,
  and server-confirmed action cancellation. Public connections0; native exit0;
  debugger armed/no caught native exception; no remaining asset workers.

The graphical run retains the known scene-wind warning and black terrain wedges.
It is not an FPS benchmark, full mixed-client acceptance, every HP mutation
path, malformed/missing rules table acceptance, or a complete effects-parity
claim. Earlier maximum-unavailable failures remain retained as failed evidence.
