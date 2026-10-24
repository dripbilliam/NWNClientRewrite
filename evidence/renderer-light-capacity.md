# Renderer light-capacity correction — 2026-10-19

This is renderer cache management, not a native light-selection implementation.
Original binaries, gameplay rules and server authority remain unchanged.

The sealed v124 real academy capture reported155..178actual point lights,
maxFragmentUniforms1024 and a changing capacity equal to actual. The previous
(1024-128)/8 policy allowed at most112 slots and provided no padding. Native
spell effects changed scene-wide Three shader counts and repeatedly compiled
programs during draw. Six sampled render calls exceeded1second; largest22.7s.

The replacement helper now budgets the actual renderer declarations separately:
point4/spot7/directional2/hemisphere3 vec4 slots per light, plus admitted fragment
shadow records/samplers point8/spot6/directional6, rect-area fields and128
common/material vectors. These are conservative renderer-layout estimates,
not NWN constants. Shadow admission runs before padding so unadmitted shadows
do not exhaust its reserve. Actual lights, colors, priorities and shadow
requests are preserved. If real usage exhausts room, no real light is removed.

Local primary implementation sources: Three lights_pars_begin.glsl.js and
shadowmap_pars_fragment.glsl.js; WebGLRenderer compileAsync. Four light/shadow
regressions and build pass. Added a regression for the captured155->178->155
range; capacity remains194 with15admitted shadows on the1024-vector profile.

Actual WebGL fixture155base/23transient lights,15shadows, three Lambert material
variants: five programs before/after addition; no shader/link/GL errors; added
render3ms, removal2ms; zero maximum pixel difference from unpadded reference.
Baseline cold compilation10.6s, reference cold compilation9.6s. These timings
are isolated fixture evidence, not live improvement or universal GPU proof.
New-material and shadow-topology compilation can still occur. Native per-object
light selection and exact native shadow passes remain open.

Live acceptance is pending. Full multiplayer goal remains ACTIVE.

First live v125 was not an accepted fix: telemetry found the actual animation
frame path still padded before shadow admission, counting83requested shadows.
That missed frame-path edit is corrected through one prepareRendererLights
helper used by both entry and frames. A regression restores authored shadow
requests between frames and verifies15admitted shadows plus stable padding.
Nine focused rendering/transition/interaction tests and buildv2 pass. v125
closed normally and remains evidence of the failed first rollout.

Sealed v126 live acceptance: one point-light capacity194 across academy NPC
casts and a native player cast; five native player effects map to five sampled
source-tagged loaded/impacted/destroyed projectiles, zero projectile failures
and runtime errors. No multi-second draw after entry during casting; cold
area-entry draws still occurred (5.1/14.8s in b,12.1/8.3s in c). Thus steady
light-profile improvement is accepted; entry preparation remained a separate
failure. Native b->c transfer succeeded after approaching the open leaf from
the opposite side; c stayed ready113seconds with no later gameplay request.
Earlier automatic return is not causally explained or declared fixed.

Source entry fix now gates rendering throughout area installation and binds
the installed native keyhole tile materials before compileAsync. Previously
setLoadedScene yielded before the gate, and first update cloned new keyhole
materials AFTER compilation. New entry diagnostics report completed preparation
and bound mesh counts. Eleven rendering/native-keyhole/transition tests and
buildv4 pass; fresh live entry verification is pending.

Final acceptance network-light-capacity-acceptance-v1.json binds sealed v126
and v127 hashes. v126 has a372second academy gameplay interval
with zero >1s draws, five complete player missile lifetimes and zero runtime
errors. Actual per-area point counts/capacities are in compact observations.
v127 prepared301native cutaway meshes in2.9s before area acknowledgement,
then still had three new-profile draws5.7/1.9/1.9s while capacity stayed64.
New dynamic model/material preparation is next, not declared solved.

Final76focused projectile/light/cutaway tests and buildv5 PASS;11earlier
rendering/native-keyhole/transition tests PASS. SP createSceneVisual now
actually forwards its captured area projectile owner to createVisualSceneRuntime;
this corrects a missing adapter property and preserves the existing native
projectile owner. No fresh live SP acceptance is claimed.

v127 final PNG captured the disconnected blank scene; it is not gameplay
visual acceptance. Full native light selection/shadows, dynamic GPU preparation,
shared hostile combat, audio and broader multiplayer gameplay remain open.

Post-seal final checkpoint multiplayer-light-capacity-live-20261019-v4.zip
VERIFIED35files/17669311bytes. Independent audit verifies37entries,3parent
hashes,14required entries,0missing/forbidden/duplicates/new credential candidates.
Audit and this note are outside the archive.

Passive v128/PID12528 is playing m0q1c at[26,35,0], both canonical player
identities present, no driver failure or scheduled gameplay inputs. Original
33744 and server20964 unchanged. Use network-renderer-control-v128.json for
owned QA inputs/normal close; retain the complete report only after it seals.
Do not archive active v128 full/live/control/stdout/stderr files. Explicit
ready screenshot network-light-capacity-ready-v128.png captured while playing;
it is newer than the archive. No combat acceptance inferred from it.

Next: dynamically appearing models/materials still compile in renderer.draw
after area setup. Inspect the pre-binding point in NetworkScene.sync, the
NetworkVisualPresentation asset/model factory boundary and Three compileAsync
with targetScene. Preserve native Type10 construction/start timing, cosmetic
internal IDs/RNG and canonical server identities; do not force early logical
projectiles or delay/calculate server gameplay. Guard late async preparation
after disposal/area/control replacement. Then continue the native Aribeth
conversation/encounter using current replicated actors; no module-specific
production behavior. Full multiplayer goal ACTIVE.
