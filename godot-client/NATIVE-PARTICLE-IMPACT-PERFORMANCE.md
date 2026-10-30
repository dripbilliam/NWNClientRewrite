# Native particle collision and Heal sparkles

2026-10-26. Scoped performance fix; full gameplay and particle parity remain
incomplete. Automated connections were to owned localhost servers only.
Particles still default off, preserving the user's preference.

Latest status: particle optimization/testing paused at the user's request while
another game is running. No further GPU/live particle tests are authorized now.
Feature integration resumes. The last owned test had finished before the stop
check: `native-particle-direct-lookup-crowd-v1` passed65 checks, clean exit0,
workers0 and unchanged source; no public connections. Its same-room Small Heal
windows measured direct native collision p95 about1.76–1.89ms versus24.15ms for
the retained script lookup, with particle callback p95 about11.49–12.91ms versus
44.66ms. These are profiled attribution measurements, not clean FPS acceptance.

The new `NwnSceneIndex` retains conservative root membership/order, weak model
tokens/NodeIDs and exact original face/current-Part queries. Resident particles
can query verified terrain/static groups directly in native code. Vertical WOK
sampling, batched terrain, unavailable indices and custom collision providers
retain the existing callback path. Empty groups are explicit; stale nonzero
tokens fall back. This is still our acceleration structure, not original BSP
parity. Headless original/reference checks passed413 index,16338 resident and
484 moving-model cases;903 actual resident/reference GPU checks also passed.
The first added tie fixture incorrectly expected a backface hit; its failed
`native-particle-native-index-tiles-v2` evidence is retained, and corrected
front-facing `v3` passes. Broader default-on gameplay/regression checks on this
latest native boundary remain queued for when tests resume.

Verified intermediate checkpoint: `native-particle-native-lookup-stage1-v1.zip`
SHA256 `03e4fe894f0d18193d031f6c733b35ade30734e977d9fec9bd440f4dbfa9cd87`.
Paused-work checkpoint: `native-particle-direct-paused-v1.zip`.

## Optional collision and bouncing

Main Menu → Options → Graphics now has **Particle collision and bouncing**.
It defaults on, persists independently of particle visibility, and applies to
existing and newly streamed emitters. Off clears only the effective visual
collision flag16, bypassing scene queries entirely. Original asset flags,
birth rates, lifetimes and other particle features remain intact. The resident
native owner receives a single flags patch when the preference changes;
paused emitters receive it on resumption. Turning it back on restores original
collision for subsequent movement. Already settled particles are not restarted.
This changes visual effects only: spell outcomes, movement and character
collision remain authoritative and unchanged. Disabling this feature intentionally
allows particles to pass through scenery; it is not visual parity acceptance.

The new owned `GodotPartCrowd1` localhost fixture uses12 original-model humans,
12 braziers and real server `EffectVisualEffect`/`ApplyEffectToObject` delivery.
Original Small Heal69 (`vim_heal01`) uses collision; Great Heal66 does not.
The original installed NWScript declarations/constants were checked, and the
module SHA256 is
`003090d95db3f3b827492e0b9872b4be845823f36d5e54046997943786508fc0`.
No proprietary art is copied into the authored fixture.

`reports/native-particle-collision-toggle-crowd-v1.json` passed41 live checks,
with12 visible crowd actors and real Heal viewport pixel differences. Its
complete four-second windows compare on/off/off/on for12 Small Heal effects:

| Metric | Collision on, two windows | Collision off, two windows |
|---|---:|---:|
| Frame interval mean | 25.36–26.38ms | 16.99–18.05ms |
| Frame interval p95 | 56.93–59.06ms | 22.74–24.06ms |
| Particle callback p95 | 42.84–43.74ms | 9.16–9.25ms |
| Scene collision p95 | 22.49–23.06ms | No collision callbacks |
| Peak total active particles | 1666–1688 | 1659–1660 |

This is diagnostic attribution with profiling and the original client still
open, not a clean standalone FPS benchmark. Other rendering/simulation costs
remain. Full raw rows are retained as `*-crowd-N.frames.json`; summaries are
written after measurements to avoid large diagnostic messages during capture.
The initial `native-particle-crowd-profile-v3` run exposed collision p95 around
32ms before the additional conservative lookup changes. These runs have different
baseline costs and do not establish a clean independent speedup for the index.

The lookup now also indexes published static-object roots, invalidates membership
and cached candidates on authoritative pose/removal changes, and reuses ordered
candidate lists for repeated single-cell segments. Exact current-Part geometry
queries remain unchanged. `native-particle-static-index-v1` passed309 checks
including300 indexed/exhaustive queries and actual LiveWorld lifecycle changes.
`native-particle-toggle-index-v1` passed407 terrain/bounds checks.

`native-particle-toggle-settings-v1` passed29 real UI/input/persistence checks;
`native-particle-toggle-behavior-v1` passed17 resident/reference emitter checks
including zero collision callbacks, continued drawing, paused preference changes
and streamed inheritance. Default-on regression checks passed905 actual emitter
scene cases and2137 original geometry cases in the matching `toggle-*` reports.
All used debugger traps, unchanged source and clean exits. Existing wind-dependent
emitter limitations remain; these checks do not accept full particle parity.

To reproduce the crowded comparison on an isolated localhost original server:

```powershell
./godot-client/tools/test-native-actions.ps1 -Effects -Profile -ParticleCrowd -Run unique-collision-toggle
```

Action probes use isolated settings/layout files, preserving user preferences.
Source checkpoint: `backups/native-particle-collision-toggle-v1.zip`; acceptance
evidence: `reports/native-particle-collision-toggle-audit-v1.json`.

## Measured bottleneck

Real original-server attacks first exposed expensive particle collision queries.
The user then identified sustained slowdown during Heal's sparkle animation.
The dedicated fixture reproduces the original visual69, `vim_heal01`, through
`ApplyEffectToObject` on an unchanged original server. It does not manufacture
effect packets or alter the visual's particles, assets, lifetime or controllers.

Heal baseline `reports/native-heal-particle-profile-v3.json` captures the first
use, two repeated uses and a particles-disabled use. Full frame rows are saved
beside the report as `*-heal-N.frames.json`. This avoids hiding startup frames
behind a rolling240-frame sample. GPU time stays around0.64ms; model creation
costs under1ms once per use. Sustained scene collision was the main cost.
The later split capturev5 attributes almost all of it to terrain model traversal.
The WOK-only change inv4 did **not** materially improve Heal; it was not the
dominant branch for this effect. Retain this failed hypothesis with the evidence.

| Metric, three complete enabled Heal windows | Before, v3 | Native model loop, v7 |
|---|---:|---:|
| Frame time mean | 6.91–7.18ms | 5.17–5.46ms |
| Frame time p95 | 14.57–15.13ms | 7.83–8.37ms |
| Particle callback p95 | 10.65–11.17ms | 3.88–4.20ms |
| Particle scene collision p95 | 8.73–9.01ms | 2.13–2.31ms |
| Peak total active particles | 146–148 | 146 |

These are diagnostic attribution runs, with detailed profiling and the original
client also open. They are not clean standalone FPS benchmarks, Arelith evidence,
or a promise of those timings in every room. Counts vary with frame scheduling;
no birth-rate, lifetime, allocation-limit, resolution or particle-budget reduction
was used. Other scene costs remain, and an FPS delta depends on the starting FPS.

## Implementation and invariants

- `scene_query_index.gd` indexes published fixed tile roots by actual collision
  bounds, including overhangs. It preserves publication order, uses conservative
  margins and bounded global/long-segment fallbacks, and holds weak node refs.
  Area retirement clears membership. Batched terrain retains its previous path.
- `scene_geometry.gd`/`native/scene_geometry.hpp` retain immutable original
  collision indices, stored planes, face order and material30 exclusion. Native
  `/fp:strict` arithmetic reproduces polyhit231810's distinct FLOAT operation
  orders and inclusive edges. Backend choice is resolved once per resource.
- `projectile_scene.gd` resolves a published model's fixed physical mesh list
  once. `native/scene_model.hpp` copies immutable collision faces into a private
  native query owner. It resolves weak Node3D IDs and checks current Part poses
  on **every query**, including same-frame changes. Inverses and normal matrices
  are reused only while the actual transform is unchanged. Pinned Godot public
  operators perform transforms and normal normalization. No borrowed scene
  pointer or authoritative object is retained or invented.
- `terrain_surface.gd` shares one immutable native WOK collision snapshot across
  placements. Quarter turns, elevation, physical face order, masks and normals
  remain unchanged. Closing the area releases these snapshots.
- `particle_resident.hpp` now admits ordinary bouncing sprites. Its collision
  bridge copies back position and hit normal, including miss-side mutations,
  without exporting entire particle records. Active/free identity, random order,
  simulation, controllers and GPU bytes remain covered by reference comparisons.
  Wind, chunks, lightning and custom movement retain their separate owners.

This is our conservative acceleration structure, **not** a claim that the
original scene BSP or complete native scene membership has been ported. Original
reference: read-only NWN:EE89.8193.37-17, nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original polygon instructions/outputs are retained in
`backups/animations/native-camera-polygon-observations.json`; no original art or
executables were copied into source checkpoints.

## Validation and reproduction

All named accepted runs have source pins, native exception traps, clean engine
termination and no leaked workers. Retained failed runs are not acceptance.

- `native-particle-final-original-faces-v1`:2137 checks, including1876 unchanged
  original polygon cases with exact FLOAT bits and256 full-mesh comparisons.
- `native-heal-model-poses-v1`:484 checks, including480 native model queries
  against exhaustive script traversal of eight real moving/scaled Parts,
  same-frame changes, edges, freed identities and stale geometry-token rejection.
- `native-particle-final-index-v1`:407 checks, including400 indexed/exhaustive
  queries, actual overhangs, bounded fallbacks and retirement.
- `native-particle-final-wok-v2`:2923 checks, including2904 decoded original
  WOK queries across six resources/four orientations against the retained
  pre-optimization traversal, snapshot reuse and retirement.
- `native-particle-final-resident-v1`:16338 checks over3240 moving frames,
  with collision hits/misses, exact state/RNG/recycling/GPU byte comparisons.
- `native-particle-final-resident-scene-v1`:905 actual Godot surface/pose/frustum,
  snapshot and lifetime checks using the final compiled-library build.
- `native-heal-particle-profile-v7`: real original-server Heal repeats and
  particles-disabled comparison, with complete frame rows. Exit0/workers0.
- `native-particle-final-effects-v1`:39 real original-server visual/casting
  checks, including actual Healing area pixels, beams, Fireball, Magic Missile,
  sound, original timing and retirement.
- `native-particle-final-shield-v1`:26 real original-server shield/projectile,
  attachment, pixel, cancellation and lifetime checks.
- `native-particle-final-parry-v1`:15 real original-server parry/spark/pixel and
  cleanup checks.
- `native-particle-final-prelude-v1`:two original Prelude gameplay/door-transfer
  cycles, streaming abort and connection cancellation, clean exit/workers0.
- `native-particle-final-impact-profile-v1`:actual hit callbacks in alternating
  particles-off/on windows. Enabled collision p95 is0.48–0.72ms; total particle
  callback p95 is2.16–2.77ms. The240-frame rolling windows here differ from the
  dedicated Heal probe's complete four-second frame captures.

From the workspace root:

```powershell
./godot-client/tools/test-native-actions.ps1 -Effects -Profile -Run unique-heal-profile
./godot-client/tools/test-native-actions.ps1 -SpecialAttack -SpecialAttackKind ki -Profile -Run unique-impact-profile
./godot-client/tools/test-native-actions.ps1 -Effects -Run unique-visible-effects
```

Use new run names; evidence outputs are never overwritten. `-Effects -Profile`
selects the Heal timing probe; omit `-Profile` for the full visible-effects test.
`--scene-geometry=gd` retains the script geometry reference for diagnostics.

## Remaining acceptance

Broader crowded-room and mixed-client performance, original BSP/membership,
wind-dependent emitters, complete clocks/shapes and general particle parity
remain open. Earlier intermittent Stunning Fist output is not declared resolved
by the one passing `native-impact-stun-visibility-v1` run. Chained special-feat
activation and equipped weapon/aura lifecycle remain separate combat work.
The full gameplay goal is active/incomplete.

Verified source checkpoints before the native model loop:
`backups/native-particle-collision-before-v1.zip` (SHA256
`d361e8e9e0862575664c21aa1ddade9983d572701d47e63588739ad1f97fdee4`)
and `native-particle-collision-stage1-v1.zip` (SHA256
`52c95547e5538219c9ab8bc36f9b5c6d0e9afaa2355f8647d0ac2e8aae37ed10`).

Final source checkpoint: `backups/native-particle-collision-after-v1.zip`, with
read-back file hashes in its `.verified.json` manifest. The scoped acceptance
ledger and hashes of all12 retained evidence reports are in
`reports/native-particle-collision-final-audit-v1.json`. Its full-goal and
full-particle-parity flags deliberately remain false.
