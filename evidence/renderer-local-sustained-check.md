# Local-only rendering and contact investigation, 2026-10-20

Live tests used only the unchanged owned vanilla Prelude server at
127.0.0.1:5121, nwserver PID20964. No Arelith connection, server modification,
original-process injection or game-asset copy was performed. Production source
and the current v19 client build were unchanged during this investigation.

The neutral-light reserve hypothesis did not produce a useful optimization.
An isolated actual WebGL fixture at3100x1121 drew1275 synthetic objects,
17838 main triangles,42 real lights and15 real point shadows. Alternating128
and64 declared point slots gave means5.17/5.25/5.18/5.14ms, with identical
final pixels. Both preserve all actual light/shadow admission. No production
reserve/admission change was made. The earlier arithmetic note was wrong:
ceilPow2(42*1.5) is64, not128; offscreen potential lights or an earlier retained
pool can account for a larger live capacity.

With the production512px point-shadow map size and two moving casters, the
same synthetic fixture averaged7.07/6.75ms with the existing cache, versus
10.22ms with all15 maps forcibly refreshed. Five maps redrew and ten reused;
cached and forced final matching poses had zero changed pixel bytes. Steady
frames compiled no new programs. These tests use a one-pixel texture and
synthetic unskinned geometry, not a complete dense installed/modded world.
gl.finish includes GPU completion/driver waits. Only final matching poses are
pixel-compared. Results and verifier:

- creation-performance-light-capacity-v1.json (static64px maps).
- creation-performance-light-capacity-v2.json (moving512px maps).
- creation-performance-light-capacity-proof-v1.json.
- scripts/verify-renderer-capacity-experiment.mjs.

An ordinary local campaign dialogue/door transition then loaded the100-tile,
92-object academy. Acknowledgement arrived1416ms after area-loading; all92
objects were prepared5981ms after it. This is one current-build run with an
uncontrolled driver cache, not a controlled speedup ratio. The following
two-minute3100x1121 observation included approximately7828 degrees of camera
rotation. After excluding two seconds following resize,229 samples gave
66.6–96.2FPS and11.7–25.2ms sampled p95 frame times. Submission was3.7–12.8ms,
main draws151–415, shadow draws295–573, actual point lights6–17. Programs
remained22, with zero new shaders, pending shaders/assets or failed models.
No renderer errors. The client disconnected cleanly. This does not prove the
earlier remote dense scene or exclusive OS fullscreen is fixed.

Local run/proof: creation-performance-graphics-local-v6.json and
creation-performance-local-sustained-proof-v1.json; verifier
scripts/verify-local-sustained-performance.mjs. The local-only restriction
continues. The separate contact hitch remains unresolved and the goal ACTIVE.
