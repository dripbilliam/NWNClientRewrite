# Multiplayer parry visuals — 2026-10-19

The native model-hit callback now connects parry sparks to the existing area
visual owner. This is rendering-only progress toward the active multiplayer
goal, not full combat or end-to-end multiplayer acceptance.

## Original-code evidence

Read-only NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original executables/processes and Ghidra project were not modified. No assets
or executables copied into the repository.

Existing whole80e490 hit-callback oracle establishes the melee/result2-or4/
defender-animation206/207/208/262 gates, abort-on-parry ordering, defender
weapon gate and weaponAttackType7 exclusion. The new provider retains these
gates; it does not infer a parry from damage, distance or local combat rolls.

SpawnHitVisuals80bb10 mode0 looks up actor DWORD3a8, the replicated facing
target, independently of the current attack-record target. Creature update
781e80 stores that field (78306d/78379a). It reads the target appearance's
CREPERSPACE and actor main-model world impact-node pose; missing target or
node returns0. Collision space <=.5 doubles, including zero/negative values.
Native float point is targetXY minus actorFacingXY*space; Z is actorZ plus
ABS(impactZ-targetZ). Height >5 emits a warning. Area7da460 creates visual118
with an empty controller map. This constant is intrinsic to the native parry
branch; resource selection uses the active visualeffects table.

Whole original mode0 execution agrees with client_parry_visual.js in52cases,
including service order, size/height boundaries, missing dependencies and area
failure. Lookup, table FLOAT, model-node pose, map allocation and area creation
are explicit synthetic service boundaries. Blood mode is not executed by this
oracle. The first run stopped one instruction before the complete epilogue;
the final range includes the original return at80e265.

Actor800ee0 forwards GetModel to animation context virtual10. Simple964690 and
head99b174 return null for18. Composite99e6bc adjusts the virtual base and reads
its separate model pointer; loader99e778->99e790 names selector18 "robe" and
stores that exact pointer. Eighteen whole getter executions verify null/present
pointer behavior across three non-overlapping synthetic virtual-base layouts.
An initial invalid fixture overlapped its pointer with the displacement word;
it was corrected, not interpreted as native behavior. Current absent robe
returns false; requested but unsupported robe remains an explicit diagnostic.

## Renderer integration and validation

NetworkParryVisual uses displayed poses, motion-owner facing and the shared
world-node pose adapter. It submits visual118 to NetworkAreaVisualPresentation,
which owns client type11 IDs, installed assets, playback and retirement. It
does not create server actors/effects, mutate authoritative HP/equipment/path,
or run scripts/combat resolution. Scene closure cancels pending asset admission.
Missing presentation dependencies are diagnosed rather than replaced by guessed
positions. The area loader is asynchronous; immediate return1 means the request
was queued, not that native synchronous model admission succeeded.

Installed GPU fixture v3 PASS: c_skel_com01 inherits a_ba nwcloseh's two physical
hit events. Both reach the production hit/parry providers, load active row118
vwp_spark, create client internal IDs0/1, use the installed impact-node pose and
render132 peak particle vertices. Impact countdown966ms and native3000ms
retirement drain both effects by4275ms. Canonical registry/cursors unchanged;
no console errors or failed effects. Peak PNG visually inspected.

The fixture uses synthetic actors/server outcome and capsule bodies. Creature
playback is the existing decoded adapter used by production combat. UIv1
attempted native inherited playback and correctly failed its existing unsupported
scale gate. UIv2 failed because the fixture did not sample its controlled world
clock; v3 fixes only that fixture clock. These failed logs are retained.
Particle scene collision and presentation approximations remain diagnosed.
This is not new live-server parry or original-client pixel equivalence.

33 focused tests PASS; buildv1 PASS (existing bundle-size warning). Tests cover
the original52 placements/18 getters, actual hit-provider ordering, facing-target
distinction, missing/removed/out-of-area targets, node/facing failures, scene
closure, robe diagnostics, existing combat/audio/area/pose/wire behavior.

The audio-position question from the previous checkpoint is resolved without a
code change: original1e0050 initially submits positive nativeZ, while playing
source SetPosition1e15a0 submits negativeZ even on equal positions. Current
BufferAudioSource already preserves both behaviors; listener1e1410 is unchanged.

## Remaining scope

Damage/blood mode1 and weapon blur/special attack7fd6b0/7fecc0/803c50 remain
diagnosed. Native inherited creature animation scale/stack, robe rendering,
material effects, complete mixer and original-origin shared active gameplay
remain open. Do not claim complete combat, spellcasting or multiplayer.

Live replacement153/PID33496, original33744 and vanilla nwserver20964 were
revalidated and left untouched. Buildjp9jnuoj is not loaded into153. No CD key
was used this increment; active153 captures/control/interactive output are
excluded from the checkpoint. No automatic gameplay input added.
