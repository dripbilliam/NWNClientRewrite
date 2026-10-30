# Native sling bounce and arrow deflection

Subsequent [native casting work](NATIVE-CAST-VISUALS.md) has scoped conjure/release
and original Detonate-event evidence. Remaining-work references below describe
this earlier checkpoint; complete combat/impact/clock/mixed-client parity stays
open.

The native client now constructs paths 11/12/13 rather than dropping special
ammunition or substituting straight flight. Original localhost servers supply
actual sling hit/miss and Deflect Arrows packets. Native Godot owns their model,
flight, ground queries and retirement. Server rolls, damage and ammunition stay
authoritative. This is a scoped milestone toward
[base-binary parity](BASE-GAMEPLAY-GOAL.md); full projectile/combat/mixed-client
acceptance remains incomplete.

## Original construction and math

`native_data/projectile_bounce.gd` implements the original builders:

- Path 11: initial ballistic flight, then two short ground bounces opposite
  the received launch direction in XY.
- Path 12: initial ballistic flight, then the corresponding two forward
  bounces for a missed sling shot.
- Path 13: initial flight followed by the original randomized deflection tail,
  using original atanf/cosf/sinf reductions and the native angular cap.

Physical node order, target-relative versus absolute points, FLOAT grouping,
UINT durations, CVTTSS2SI out-of-range behavior, scene-ray order, speed fractions
and CRT random draw count are retained. `projectile_orientation.gd` now includes
the original finite atanf path. Exceptional CRT state and arbitrary CPU dispatch
remain outside accepted scope.

Fresh read-only reference: NWN:EE 89.8193.37-17 SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Special ammo builder `140986db0..1409873bb`; deflection builder
`140985f20..14098638f`; magnitude `1402303d0`; CHitInfo constructor/clear
`1400c0c40` / `1400c5a90`. Existing shared path, motion and AI owners are listed
in [NATIVE-PROJECTILES.md](NATIVE-PROJECTILES.md).

`scripts/inspect-native-projectile-bounce.py` executes the original instructions
in isolated emulation. It captures allocation/list services, object presence,
authored scene responses and CRT random draws; sqrtf is an explicit correctly
rounded binary32 boundary. No original process is patched or injected. The
1,500 cases cover all three builders, scene/no-scene, hit/missing ray responses,
target presence, axes/signs, random modulo boundaries and UINT durations. Native
nodes, timing bits and callback order match exactly. This does not prove those
captured lower services or real server outcomes.

Fresh builder dossiers and observation data are retained under `reports/` as
`native-projectile-ammo-builder-research-v1.json`,
`native-projectile-deflection-builder-research-v1.json` and
`native-projectile-bounce-original-v1.json`.

## Native static scene queries

The original builders issue vertical finite rays through Scene::HitCheck mode 1,
mask FFFFFFFFBFFFFFFF. The earlier read-only scene investigation identifies that
mode as static BSP geometry rather than ordinary dynamic Gobs; see
`../evidence/native-camera-clear-view.md` and its cited `1400c9c90`, `1400d9f20`,
`140090170`, `1400905b0` and `140231810..140231a99` evidence.

The binary model reader now retains original MaxFace planes and surface types,
separately from optimized GPU draw lists. `scene_geometry.gd` shares immutable
collision vertices/indices/planes across model clones; hidden geometry retains
the same query data. Server resource selection and active ammunition tables
remain unchanged. Model cache keys invalidate old entries lacking these fields.

`native_data/polygon_hit.gd` ports the original front-to-back polygon predicate,
distinct dot-product sum orders and inclusive edges/endpoints. The 1,876 stored
original crossing cases and 256 normal/plane cases pass exact FLOAT bits.
Original MaxFace metadata hashes on installed chest/body/drow/robe resources
agree with the independent retained reader; no original model payload is copied
into authored source/evidence.

`projectile_scene.gd` queries loaded original WOK and static model faces, excludes
surface 30 and dynamic creatures, and chooses the nearest crossing. Visual
opacity, menu interaction/highlight eligibility and GPU draw simplifications do
not determine collision. The static membership/transforms are an explicit
adapter: complete original BSP registration/traversal, reference/animated helper
membership and unusual custom static state still need parity acceptance.

## Bounded broad phase and measured cost

The initial correct but unaccelerated landing query cost roughly 15 ms per ray
in the retained local sling scene. Conservative model bounds reduced this to
roughly 9 ms. Bounds are computed once per immutable template from actual
collision faces, including non-rendered faces and overhangs, then transformed by
each placement's current pose. No extra per-frame registry scan is introduced.

Decoded WOKs now retain their source bounds. `terrain_surface.gd` builds a static
XY grid after native WOK workers finish; only overlapping placed tiles reach the
polygon predicate. Tile corner origins and exact quarter-turns remain distinct
from the visual MDL's center origin. Overhangs spanning multiple tiles stay in
the candidate set. More than 1,024 cells for one unusually large tile uses a
bounded global fallback. Retirement clears the index with its world owner.

Conservative bounds include rounding margin only for rejection. The original
polygon predicate gains no epsilon. Authored checks cover actual transformed
model bounds, rotated sloped WOKs, overhangs more than one tile away and bounded
large custom geometry. A half-tile origin mismatch in an intermediate indexed
version was caught during review and corrected before acceptance; its passing
flat-scene result alone is not treated as coordinate-parity evidence.

Final local sling hit/miss runs record about 1.5–2.8 ms per query, with both ground
hits preserved. `projectiles.stats` exposes scene query/hit counts and total/max
CPU microseconds. These are constructor query costs in a small functional scene,
not GPU timings, general loading benchmarks, dense-world FPS or complete original
renderer performance acceptance.

## Local acceptance and retained failures

The test fixture uses an unchanged original server at 127.0.0.1:5125. A copy of
the installed ranger receives original sling/bullet UTI data only in memory;
the installed character is read-only. Bullet slot selection comes from installed
nwscript constants. Actual original attack rolls and ammunition consumption
produce hit and miss packets; the high-AC authored target changes no server code.

The Deflect Arrows fixture grants the original feat to an authored NPC and starts
a genuine NPC combat round through original ActionAttack. Its original per-round
deflection allowance and saving throw produce the path-13 packet. An idle NPC
with the feat had produced ordinary hits and was not accepted as a deflection
test. The native animation probe also now samples an actual live attack cue with
enough remaining time, since a stale action record can coexist with a ready or
incoming reaction clip. It still requires moving original geometry and clocks.

Final native checks use pinned sources, normal-heap exception capture and strict
engine/lifetime-error rejection. Evidence includes:

- `native-special-bounce-final-v1.json`: 1,501 original builder checks.
- `native-special-polygon-final-v1.json`: 2,133 original polygon/plane checks.
- `native-special-scene-broadphase-v1.json`: 80 original metadata and authored
  scene/filter/transform/index checks.
- `native-special-state-regression-v1.json`: existing 20,903 projectile checks;
  `native-special-impact-regression-v1.json`: existing 2,604 impact/orientation
  checks; receiver/area regressions retain their original scopes.
- `native-special-surface-regression-v1.json`: 33,081 original Prelude WOK
  height, cold/warm cache and worker checks; no movement-height behavior change.
- Final live bow/sling/miss/deflection, effect/gameplay and reconnect records are
  indexed by `reports/native-special-projectiles-final-audit-v1.json`.

The final special/ordinary/spell lifetime owner regressions pass 16/11/11 checks
headlessly. Their first headless batch stalled on a graphical-only draw signal;
that owned batch was verified and stopped, logs retained, and the shared test
settling helper now waits for draw only with an actual display. Headless results
prove node/model ownership and cleanup, not GPU retirement; prior graphical
material/retirement evidence retains its original scope.

`native-special-lifecycle-v1.json` passes two full original Prelude cycles,
one streaming abort and cancellation, with all workers retired. The inspected
final sling/miss/deflection captures show actors and the expected original area,
but also contain black terrain wedges. Those are a remaining rendering gap;
projectile pixel deltas and original face tests do not establish complete visual
parity for the room. These are functional captures, not accepted FPS benchmarks.

Subsequent [window-startup changes](NATIVE-WINDOW-STARTUP.md) have separate native
menu evidence: secondary screen, retained no-focus flag and uncaptured mouse.
They postdate the final combat/lifecycle runs. The audit checks unchanged combat
and scene sources against those runs and current launcher sources against the
new startup check; it does not claim a new full lifecycle after that isolated
startup change.

An empty-metadata hash update error in the first scene probe was corrected by
handling the empty SHA256 input; comparisons were not weakened. Original emulator
dependencies and all failed/diagnostic live runs remain retained. No public
game-server connection is part of this milestone.

## Remaining work and checkpoints

Real shield-block attachment, broader weapon/target families, impact blood/weapon
effects, embedded arrows across shape/equipment replacement, complete native
fields/options and paused/world-clock semantics remain open. Random/burst/linked
lower services, cast release/children, wider effects/audio and paired original-
client gameplay still need acceptance. These checks do not complete the base
gameplay ledger, full migration or performance goal.

Verified sources: `backups/native-ranged-direct-after-v1.zip` before this work,
`backups/native-special-paths-before-broadphase-v1.zip` before acceleration, and
`backups/native-special-projectiles-direct-after-v1.zip` after accepted checks.
See `tools/audit-native-special-projectiles.mjs` for evidence/current-source and
checkpoint verification without launching a game. Output reports use exclusive
creation; choose a new `--report=native-special-projectiles-audit-v2.json` name.
