# Frame scheduling and model shader preparation — 2026-10-19

The v163 foreground profile attributed325 samples to the renderer's full world
matrix traversal and291 to the preceding light-selection traversal. v164
prepares scene matrices once, updates only the subsequently changed neutral-light
subtree, then temporarily suppresses the renderer's redundant scene pass.
The original auto-update flag is restored even on draw failure. No real light,
caster, geometry, texture, animation step or pixel-resolution reduction.

GPU fixture:8 animated mesh/light poses including negative scales produce zero
changed image bytes,2 reference matrix passes versus1 optimized, zero GL/shader
errors.37 focused regressions initially passed. Live v164 showed34.49FPS near
the v163 camera (distance11.735 vs11.706, yaw102.434/pitch50), versus28.57FPS
before. Admission14 lights,13 reused maps/1 drawn,308 shadow draws match; main
draws238 vs237. This is a close-view observation, not a strict controlled A/B.
The user subsequently changed the camera (about7.24 distance/61FPS), so the
later frozen rolling capture cannot stand in for the earlier matched view.

Next build FuaJGZ6Y also shares an event-invalidated renderer hierarchy index
between emitter discovery and camera-keyhole binding. It retains traversal
order, observes descendant add/remove/reparent/clear, and retires listeners
after the final consumer. Poses/visibility/simulation remain live. Producer tags
are assigned before Object3D attachment; in-place metadata edits must call the
explicit invalidator. Keyhole binding restores removed/reparented materials
and retains retry behavior for initially missing geometry.

Model preparation now starts color, fade and shadow jobs together with separate
material copies and shared geometry. Source lights/materials remain unchanged;
all polled jobs settle before failure, cancellation or teardown can release
their handles. Every variant is still ready before instance publication.
GPUv5 passes live-scene pixel invariance, first real draw and fade without new
programs,13 point shadows, shader/GL checks, event-loop responsiveness and owner
retirement.8 programs prepared/drawn;300 heartbeats during3001ms preparation.
Phase durations overlap: shadow22ms, color2823ms, fade2998ms. Older v4 measured
3586ms, but this is not a controlled timing comparison. The PNG was inspected.
49 focused regressions and build PASS. Live rollout remains pending.

Fresh read-only Ghidra12.1.4 evidence for original nwmain.exe SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a:
AurSetMaxLights14007dce0 accesses global14128e588. Its analyzed initial8 bytes
are2000000001000000: max-lights32 and the adjacent shadow-limit1. Existing
GetShadowLights14007f840 assembly confirms shadow-limit14128e58c references.
The actual installed settings.tml has graphics.lighting.max-lights32 and
graphics.shadows.max-casting-lights3. Callback1406bd3f0 forwards configured
integer values to AurSetMaxLights. ControlLightsFade14007ddb0 uses the configured
max (bounded128), headlight reservation, separate fade state and Only-Gob logic;
GetNearestLights14007f660 also applies per-object position/radius/flags.
These facts do not establish a correct replacement for all candidate/fade/static
paths. No arbitrary32-light global cap or3-cubemap cap was introduced, and no
graphics settings/library dependency was added during this investigation.

v164 benchmark route initially requested its next interactions before native
dialogue replies arrived, causing one harness-only premature door-transition
failure. It was retained and recovered; no production transition workaround.
Do not mark the broader multiplayer objective complete.

Live v165 is now observed: user-driven A/B/A/B transitions prepared initial B
in3603ms and its first door variants in4939ms, with overlapping fade/color
phases. Return A9.1ms and repeated B67.7ms reuse prepared area programs.
Passive later B observation reached roughly59–60FPS at3100x1121. Camera and
driver caches differ from old runs; these are not controlled A/B speedups.
Frozen bounded proof: network-hierarchy-parallel-proof-v165.json. The live
full report remains unsealed until normal closure. Merchant/token warnings
discovered during that user test are tracked separately.
