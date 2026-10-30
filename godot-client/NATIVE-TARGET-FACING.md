# Native target-facing integration

2026-10-27. First scoped correction under the UI/combat migration goal. UI visual
parity, sliding/correction playback, complete combat timing and mixed-client
acceptance remain incomplete.

## Defect and correction

Received `facingTarget` reached combat metadata, but the native motion owner did
not resolve it or update the actual creature pivot from it. `combat_animation.gd`
read pivot orientation for selection; it did not turn that pivot toward a target.
No amount of selecting a correct attack clip fixed this missing link.

`network_motion.gd` now resolves a non-sentinel/non-self target before its existing
turning step. It retains derived bearing across target unlock, stops turning
toward an unresolved target, and leaves path-facing priority intact while walking.
The world resolves only current, non-removed, same-area objects. It uses a target
creature's native simulated position when available, otherwise its received
position, so rendering/asset readiness is not a prerequisite. Received state and
authoritative positions are never edited to create a facing result.

Full and delta world snapshots update the target lock even when there is no
movement event. Motion observations can also carry an explicit target update.
Closing the world clears the resolver; retiring/closed worlds cannot resolve
against a new scope. No extra server action or JS rendering is introduced.

## Original-binary evidence and limits

Read-only existing dossier:
`../backups/animations/rea-network-client-movement-model-update.json`,
nwmain SHA2563b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a,
NWN:EE89.8193.37-17 x64, FUN_1407fcd70. Assembly at0x1407fcdd6 reads target
ID at owner+0x3a8;0x1407fce08 calls CGameObjectArray::GetGameObject. Target/source
positions at+0x38/+0x3c/+0x40 form a delta;0x1407fce6b calls magnitude and
0x1407fce70 checks the threshold. At0x1407fceac the planar delta's Z is zeroed;
0x1407fcebd/0x1407fcec9 normalize and0x1407fced2..0x1407fcedd store+0x2b4/+0x2bc.
The later category branch chooses path versus target direction before
0x1407fcf48 calls the existing turning function0x140807690. The failed lookup
branch invokes an orientation setter using current facing.

This establishes ordering/ownership, not broad runtime parity. The adapter
preserves bearing for exactly vertically coincident targets rather than asking
the turning routine to turn toward a zero planar vector. That defensive edge
has a finite-state test but no original live comparison; do not claim that edge
or arbitrary shape/root conventions have proven parity.

## Evidence

- `native-target-facing-v1`:15 authored received-state -> world resolver ->
  original turn step -> actual pivot checks. Includes moving/unrendered targets,
  unlock, target-only snapshots, path priority, removal, other-area/self/vertical
  targets, unchanged wire state and resolver cleanup.
- `native-target-facing-motion-v2`:47421 retained original movement/facing/gait
  comparisons pass; maximum observed numeric difference5.96046448864129e-08.
  The initial wrapper receipt failed because this older fixture omitted a
  `success` field, despite zero numerical failures. Added the explicit field;
  assertions/tolerances and original observations were not weakened.
- `native-target-facing-live-motion-v3`:141 actual live-world motion checks,
  through initialized scene/combat owners and private model-rig playback.
  The obsolete fixture originally constructed the world outside the tree and
  produced nil combat-owner errors. It now creates the real owners and tests
  selected rig animation/speed instead of an actor-method spy. Its intermediate
  `passed`-only receipt also needed an explicit wrapper-compatible `success`.
- `native-target-facing-playability-v1`:1314 existing native playability checks.
- `native-target-facing-actions-v1`:unchanged owned local server on5125,
  graphical native client under normal-heap CDB, all action checks pass, source
  unchanged, zero public connections, no remaining workers and finish acknowledged.
  During a real server melee attack, server target2147483652 is resolved and
  actual rendered pivot dot1.00000011920929 (binary32 rounding; clamped angle0deg).
  The original attack clip advances two model clocks, changes53 local parts and
  deforms sampled GPU skin vertices by0.0436139479279518. Cast, inventory,
  preparation/quickbar, party, store, level-up, familiar and cancellation checks
  remain covered by this same scoped scenario, not the entirety of their UI.

Failed receipts remain retained and must not be reported as passing. The above
are functional correctness observations, not performance benchmarks or UI-look
acceptance. No public server action or original-process modification was made.

## Next sliding investigation

`network_motion.gd:correct` produces correctionCue24/25/26/27, type6 and remaining
correction duration for an idle model whose visual position is catching up.
At this target-facing checkpoint, `live_world.gd:apply_pose` consumed ordinary
gait/facing-turn but not that cue. Existing correction observations covered the numeric
producer, not an actual playback consumer. Before implementing, inspect original
type6 cue/animation ownership and preserve active attack/cast priority, duration,
clock behavior and loop/reset rules. Do not simply replace all motion with an
idle or force an attack animation to hide the slide.

Follow-up: `NATIVE-MOVEMENT-CUE-PLAYBACK.md` records the implemented native
consumer, original type6 evidence, real server correction playback and remaining
combat-parity gaps.
