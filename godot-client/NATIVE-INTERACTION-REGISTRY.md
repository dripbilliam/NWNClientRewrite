# Native interaction registry

The live native entry keeps authoritative world objects and rendered scenery
separate from mouse selection and highlighting. Non-interactive scenery remains
in `live_world.desired` and `instances`, without selection entries, mesh maps,
highlight bindings or per-mesh picking bodies. Particle and light owners keep
their existing lifecycle. JavaScript is not called to construct this registry.

## Policy and updates

`systems/native_interaction_policy.gd` projects received state into eligibility:

- Creatures and doors remain targets. A door's availability for Use is distinct
  from its availability for highlighting/examination.
- Items are targets on the ground, not when equipped or in an inventory channel.
- Placeables require usability and must not have a non-null `staticState`.
  Usability uses the first non-null received value from `replicated.field264`,
  `nativeUseable264`, `usable`, then authored `Useable`; missing values are false.
- Removed, destroyed and other-area objects are excluded.

The helper also describes transition-trigger eligibility, but this increment
does not add trigger geometry/admission to the live renderer.

`live_world.gd::instance_state_changed` refreshes selection metadata independently
of model appearance. Changing usability, ground/inventory state or a name does
not require rebuilding a model. Losing eligibility removes picking/highlight
state immediately; gaining it registers the existing instance. Deferred HUD
refresh coalesces admissions and clears obsolete labels/details.

## Geometry, movement and portals

`native_render/pick_geometry.gd` retains shared CPU vertex/index arrays and
bounds. It constructs a shared triangle picking shape only when a target needs
one. Live rendering uses the lazy path; the explicit eager diagnostic path is
retained. No GPU geometry readback is needed.

Original Render=0 model surfaces can be hit geometry. Their original triangles
are retained on existing physical parts without publishing a visible GPU mesh
or creating extra hit-only nodes. This preserves the original `plc_portal2`
mouse target. Geometry is not replaced with an invented box or visual guess.

Target bodies use physics layer 2. Original WOK floor bodies use layer 1 and
remain independent of selection eligibility. Mouse picking tries targets then
the walkmesh. This is a selection optimization, not a replacement for movement
collision or the authoritative server's movement decisions.

## Verification

All tests used original installed assets read-only and the owned local Prelude
server. No public-server connections were made. The user's Godot editor was
preserved, so these are functional checks, not clean FPS benchmarks.

- `reports/interaction-registry-final-v1.json`: 36 checks, including 600 rendered
  scenery objects with zero picking bodies/highlight bindings and zero shape
  construction, live eligibility changes without a model reload, shared lazy
  shapes, independent walkmesh, cleanup, active scenery effects and an actual
  ray against the original hidden `plc_portal2` hit triangles.
- `interaction-cache-final-v1`: 18 checks of shared templates/resources,
  bounded retention and private instance state.
- `interaction-delta-final-v1`: nine checks of changed-object updates, including
  600 unchanged static objects.
- `interaction-retirement-final-v1`: 72 checks of deferred retirement/workers.
- `interaction-runtime-final-v1`: 30 original-data particle/actor GPU checks.
- `interaction-prelude-final-v1`: authoritative movement, ground click/WASD,
  examine/dialogue, inventory unequip/re-equip/reopen and three door transfers.
- `interaction-local-cycles-final-v1`: three normal-entry reconnect cycles and
  an abort during area streaming.

The local entry retains all 20 world objects but registers seven selection
targets. Compared with `native-hotpaths-final-local-cycles-v1`, total collision
bodies fall from 140 to 90; nine walkmesh bodies remain unchanged. Shape counts
depend on shared-cache warmth, not just the number of currently loaded targets.
Debugger reports record normal heap, four armed exception traps, unchanged source
pins and no native exception or engine/lifetime errors.

Offline captures do not build this live selection registry. Do not attribute an
offline capture FPS gain to this change. Full binary interaction/visibility
parity, complete trigger support and 60 FPS acceptance remain open.

## Culling boundaries

Godot performs mesh view-frustum culling. Native particle admission additionally
skips simulation and vertex generation when conservative bounds are outside the
camera; unsupported bounds retain the prior active path. This local Prelude
run recorded 7,821 culled emitter frames in one area. Large bounds can still
admit off-screen emitters.

There is no active wall-occlusion setup, general off-screen actor-animation
throttling, or completed native room/portal visibility port. Experimental
4-by-4 tile batching is disabled in the normal live entry. Keeping an object
out of the interaction registry does not itself cull rendering or simulation.

## Rollback

Verified authored-source checkpoints:

- `backups/interaction-registry-before-v1.zip`, before this increment; SHA256
  `b33c8077d862590214e0446e6ac075bcd503dd0c649b5c7ad63e7c6e3ee4b941`.
- `backups/interaction-registry-after-v1.zip`, completed implementation and
  reference documentation; its adjacent verified manifest records hashes.

`reports/interaction-registry-final-audit-v1.json` checks the final evidence
against the current authored-source hashes.
