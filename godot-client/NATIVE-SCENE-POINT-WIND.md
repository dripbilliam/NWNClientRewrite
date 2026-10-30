# Native scene point-source wind: partial effects migration

`point_wind.gd` ports the original radial point-list arithmetic and lifetime;
`scene_point_wind.gd` owns that state per native world. Explosion emitters bind
the scene provider from native ancestry. Lists and clocks never enter cached
model templates. Allocation overflow is explicit, and world retirement releases
state. Live and offline captured worlds both construct the native owner.
Ambient/noise wind, grass sampling, scene collision and full original bucket/
event ordering remain incomplete. No zero-vector substitute is supplied for the
missing ambient wind service. This does not complete the ordered goal.

Follow-up: [NATIVE-PARTICLE-DISPATCH.md](NATIVE-PARTICLE-DISPATCH.md) records current
dispatch/controller checks, an opt-in field-copy experiment rejected as a
default, final reconnect/captured comparisons and remaining CPU costs. Reports
below retain their earlier source/checkpoint scope.

Read-only target:NWN:EE89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Complete selected REA views in `../backups/animations` record:
AddPointSourceWind1400f1250..1400f12d9, pointSourceWindVector1400f2070..1400f224d,
updateTimer1400f2250..1400f2572, GetGlobalPointWind1400f1530..1400f155e,
Scene::Render1400cc730..1400ccea6 and DoEmitterBucket1400c7ae0..1400c7eff.
The timer call at1400ccda9 precedes draw-bucket collection at1400ccdbe;
DoEmitterBucket calls AnimateParticles at1400c7c94. Godot's timer priority10
precedes emitter priority20. Complete virtual dispatch, visibility/global scene
ordering and the rest of WindManager are not accepted from these selected views.

Point-list storage grows from16 by doubling; source influence has a strict sphere
boundary and no lifetime fade. Exact-zero remaining lifetime survives; negative
remaining time removes/shifts and rechecks the slot. Existing unchanged-original
observations `native-point-wind-observations.json` contain189 sample,126 append
and60 timer cases. Their original execution fixture supplies noise/instrumentation
as explicit lower boundaries, not a complete WindManager port.

Initial current checks:

- `native-point-wind-v3`:386 checks, including375 original observations plus
  actual compiled-explosion/native-world binding, pose conversion, independent
  clocks, exact-zero expiry, scene retirement and explicit overflow. Initial v1
  failed on untyped test dictionaries; v2's overflow check had no surviving
  camera after retiring its first world. The camera is now retained by the
  surviving test world so the emitter actually ticks.
- `native-point-wind-particles-v1`:30 standard original torch/portal GPU checks;
  `...chunks-v1`:119 chunk/private-model GPU checks;
  `...retirement-v1`:72 delayed-worker/overflow checks;
  `...publication-v1`:10 live stream effect-adoption checks.
- `native-session-point-wind-v1`:actual default client, pending-stream abort and
  three complete owned Prelude joins in PID35752.25 of57 emitters now have
  simulation frames;32 collision-provider failures remain. Each completed world
  has an independent wind owner. These scenes produce zero detonation sources;
  actual blast registration is proved by the authored GPU fixture, not by these
  dormant server emitters. Cleanup/source pins/debugger checks pass.
- `native-capture-point-wind-v1`:original offline snapshot48 tiles/889 statics/
  eight animated creatures/one item, zero workers.472 more emitters can simulate;
  remaining710 failures are596 intersections,10 ambient-wind and104 unavailable
  fxpa_cloud02 bitmaps. Sources added are zero in this snapshot. Preparation11696
  ms;179 settled intervals average38.858 ms,p9540.460,worst41.186. Loading659
  intervals average16.139 ms,p9544.640,worst71.158,11>50 ms. Editor1776 preserved;
  incomplete effects/uncontrolled timing, not clean performance acceptance.

The newly enabled emitters expose substantial CPU cost: rolling channels/pose
mean12.690 ms and simulation13.489 ms. Render CPU/GPU means2.068/3.509 ms. Keep
those emitters enabled while reducing adapter/channel overhead. Do not restore
their failure path to inflate FPS. No public connections or original assets/
binaries were modified. Complete effects,60 FPS, remaining JS and the final wiki
remain open.
