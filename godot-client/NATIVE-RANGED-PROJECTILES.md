# Native ranged ammunition — partial binary-parity milestone

Later shield follow-up: real small/large/tower shield blocks now have native
physical attachment, viewport and expiry evidence. The original table loader
proves byte8 is **WeaponWield**, correcting the historical WeaponType label used
below and in the immutable raw impact corpus. See
[NATIVE-SHIELD-IMPACTS.md](NATIVE-SHIELD-IMPACTS.md) for the instruction/loader
receipt, native scheduling correction, acceptance and remaining lifetime gaps.

Later follow-up: sling hit/miss bounces and genuine server Deflect Arrows now
have native scene wiring and local evidence. Original stored collision planes,
polygon predicates and bounded static broad phases support their landing queries.
See [NATIVE-SPECIAL-PROJECTILES.md](NATIVE-SPECIAL-PROJECTILES.md) for current
acceptance and remaining BSP/shield/effects/mixed-client limitations. The ordinary
arrow milestone below retains its original report names and scope.

Ordinary ballistic ammunition now has a direct native receiver, model owner,
flight, physical body attachment and retirement. An actual original localhost
server resolves the bow attack and consumes ammunition. Godot uses its received
result and travel time; it does not invent damage, hits or inventory changes.
This is progress toward [base-binary parity](BASE-GAMEPLAY-GOAL.md), not full
ranged/combat or mixed-client acceptance.

## Ownership and original behavior

`native_data/projectile_ranged.gd` implements the reviewed receiver, including
active baseitems/ammunitiontypes lookups, signed BYTE ammunition selectors,
legacy physical-row fallback, rhand launch offsets, appearance/model-type scale
rules, hit-result mask, target selection, registration and original stage/path
ordering. Modern server selector columns take precedence over the legacy layout.
Authored table overrides are tested; production selection is not a fixed model
list. The scene currently admits ammunition 1/2/4/5/6 through ballistic path 2.
Ammo 3 and deflection path 13 were unsupported at this milestone; the later
special-projectile follow-up above adds their native scene wiring.

`native_data/model_random_part.gd` preserves original FLOAT area accumulation,
physical child order, cached model area, CRT random-draw range and strict weighted
selection. The binary reader retains the stored mesh area from disk offset
0x1f8, including skin meshes admitted by the original flags & 0x21 test. Native
actors/templates expose actual physical Parts and equipment slots; synthetic
Godot wrappers do not participate in the selection graph. Animated/scaled
triangles are not recomputed as substitute weights. Old prepared-model cache
keys are invalidated for this new field. ASCII models without a stored area
diagnose unavailable weights rather than inventing them.

`native_data/projectile_impact.gd` implements the original body/shield admission,
distinct model-handle/client-field checks, shield equipment slot 32, WeaponWield 7,
random shield anchor, node pose, impact orientation and duration/provider order.
The native scene resolves actual body/equipment Parts. Pure shield branches have
stored binary evidence; real shield-block evidence was added in the later
follow-up linked above.

`native_data/projectile_orientation.gd` and `projectile_atan_table.gd` port the
retained finite CRT atan2f/cosf/sinf paths and binary32 grouping for model and
impact rotations. These pass exact stored finite cases, including signed-zero
axes. Exceptional inputs and arbitrary CPU-dispatch parity remain outside that
evidence; this is not a complete CRT replacement claim.

`native_render/projectile_world.gd` owns pending headers, shared private type-8
IDs, active original model instances, physical node tracking and target lifetime
checks. Removed/reused targets retire their arrows and tracking. World close
releases all models, allocations and provider cycles. Runtime impact blood/weapon
effects are still diagnosed as pending. Native client field28 currently has its
default rather than complete replicated semantics.

Controlled equipment changes prefetch the active weapon's ammunition bundles
through the existing native worker/cache service. This observes only the
controlled actor's appearance signature; it does not rescan static scenery or
other actors each frame. The unique model set is bounded to 64 and publishes no
GPU instances while warming. In the retained cold experiment, first-arrow
preparation took 61 ms against a 78 ms flight. The final prewarmed local run
records 4 ms preparation for that same server travel duration. This is a scoped
first-shot result, not a general FPS or loading-time claim.

## Renderer binding correction

The ranged test reproduced four material-null renderer errors at arrow expiry,
before overall client shutdown. An isolated original-arrow test reproduced the
same errors on every retirement. Removing GPU readbacks and skin baking, and
detaching the actor before controller close, did not resolve them; the ineffective
actor-detachment change was removed.

Native pose setup had created per-surface material copies while the pooled
mesh-wide override remained the active drawn binding. Controller changes were
therefore hidden by that override. Setup now makes a private copy of the actual
mesh-wide binding when present, retaining per-surface handling for models without
one. Forty rendered checks verify active private binding, actual alpha-driven
viewport changes, unchanged pool colors and twelve clean retirements. The real
server ranged test and existing effects/beam/Fireball run also exit without the
material errors. This supports the binding/lifetime fix; no engine-internal C++
fault instruction or universal renderer-lifetime proof is claimed.

## Binary evidence

Original NWN:EE 89.8193.37-17 SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original executable and analysis inputs remain read-only.

- Ranged receiver: `1407acc9b..1407ae1b2`, constructor `1409832a0`.
- Impact AI branch: `140983e2e..1409841d2`.
- Part area: `14008f560..14008f5e3`; weighted Part selection `14008f740`
  and Gob selection `14008f680`. Fresh read-only evidence is retained in
  `reports/native-ranged-part-area-research-v1.json`. Runtime stored area is
  at 0x2bc; the original geometry interface's flags include skins.
- Shared projectile configuration/motion/stage addresses and lower-service
  limits remain in [NATIVE-PROJECTILES.md](NATIVE-PROJECTILES.md).

The earlier suspicion that the JS adapter omitted skins was disproved: its
`trimesh` category includes skinned parts. Godot's missing stored-area field was
the gap. Retained JS sources are read-only behavioral references, never runtime
asset/presentation owners for this native path.

## Current evidence

All final native checks pin sources, use normal-heap exception capture, reject
engine/lifetime errors and use no public server connections.

| Evidence under `reports/` | Scope |
|---|---|
| `native-ranged-live-final-v1.json` | 21 actual localhost checks: bowshot clips/rigid geometry, private path-2 flight, original arrow pixels, actual ammunition consumption and combat feedback, weighted body attachment, queue cancellation and 8000 ms expiry/model release |
| `native-ranged-receiver-final-v1.json` | 527 checks: 132 stored original receiver cases, 84 original random-Part cases and 189 authored metadata/override cases |
| `native-ranged-impact-final-v1.json` | 2604 checks: 2472 stored original impact/provider cases and 130 finite original orientation cases plus input identity checks |
| `native-ranged-area-final-v1.json` | 74 checks: independent original binary areas/hashes, actual drow/robe skins, native chest worker/template/anchor and scale-independent weights |
| `native-ranged-retirement-final-v2.json` | 40 rendered original-arrow binding, alpha/pool-isolation and repeated retirement checks |
| `native-ranged-lifetime-v2.json` | 11 actual native-owner checks under authored ranged headers: removed/deferred-reused/live-reused targets and complete world cleanup |
| `native-ranged-state-regression-v1.json` | Existing 20,903 stored original projectile path/motion/AI checks |
| `native-ranged-spell-lifetime-regression-v1.json` | Existing 11 spell projectile lifetime checks |
| `native-ranged-effects-regression-v1.json` | Existing 31 actual original-server effects/beam/Fireball checks |
| `native-ranged-actions-regression-v1.json` | Existing 62 actual original-server gameplay/menu/spell/melee checks |
| `native-ranged-lifecycle-v1.json` | Actual original Prelude: cancellation (1.773 ms in this run), streaming abort and two reconnect cycles, clean worker/owner retirement |

The inspected ranged capture is `native-ranged-live-final-v1.native-ranged.png`.
The original `wamar_001` changes 26 pixels in an 80-pixel-radius region centered
on its projected position, excluding the changing FPS label. Bowshot clocks,
50 local Parts and indexed rigid vertices advance; the stationary cloak skin is
not incorrectly required to deform during a rigid bow animation.

Failed and diagnostic runs remain retained: missing inventory requests; an
overstrict skin-only animation probe; a cold preparation delay consuming nearly
the whole short flight; the reproduced material errors; an inherited diagnostic
signature mismatch; an initial rigid-only area fixture replaced by actual
original skin resources; and a lifetime probe observing before its queued frame
ran. These are not accepted evidence. The fixed lifetime probe waits for the
actual queue/stale outcome, rather than assuming process-frame signal order.

## Remaining parity work

Full static BSP/registration parity, real shield blocks, other weapon and
target families, impact blood/weapon effects, embedded arrows across equipment/
shape replacement, complete native fields/options, pause/world-clock alignment,
cast release/child/burst/bounce/random branches and paired original-client play
remain open. Ordinary arrow success does not complete the combat ledger or the
overall migration. All automated joins remain on owned localhost servers.

Verified source checkpoints: `backups/native-projectiles-direct-after-v1.zip`
before this work and `backups/native-ranged-direct-after-v1.zip` after it. Both
contain authored sources/references only. Current evidence and critical source
hashes are indexed by `reports/native-ranged-final-audit-v1.json`. Recheck with
`node godot-client/tools/audit-native-ranged.mjs --report=native-ranged-audit-v2.json`.
Reports use exclusive creation; use a new name for each audit.
