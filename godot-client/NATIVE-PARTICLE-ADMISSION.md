# Binary-guided emitter admission

This follows [NATIVE-PARTICLE-DISPATCH.md](NATIVE-PARTICLE-DISPATCH.md). The full
streaming, native migration and eventual wiki goal remains incomplete. This
increment implements a scoped frame-admission method, not a general crash fix.

## Original evidence

Read-only NWN:EE build 89.8193.37-17, x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Selected full assembly/pseudocode dossiers are retained under
`../backups/animations/rea-native-emitter-*-v1.json` and
`rea-native-model-classification-*-v1.json`. They are decompiler observations,
not original source or proof of complete subsystem recovery.

| Function / call site | Observed behavior |
| --- | --- |
| Scene::Scene 1400c0ca0; vtable 140d8dd30 +280 | Resolves to Scene::IsAnimating 1400cafe0, reads byte +b9 |
| Gob::Gob 1400869d0; vtable 140d88a00 +2a0 | Resolves to Gob::IsForceAnimated 140092000, reads byte +1a |
| Scene::DoEmitterBucket 1400c7ae0, calls +280 at 1400c7c38 and +2a0 at 1400c7c7f | Scene animation OR source force-animation controls AnimateParticles at 1400c7c94. These are animation gates, not visibility tests; derived overrides remain separately unproved |
| ManageSceneBSP 1400db320, callback address at 1400dba64 | Resets emitter count and passes callback FUN_1400dc140 to BSPTraverseVolumeApprox with the current camera's plane list |
| FUN_1400dc140 1400dc140..1400dc8f3, call 1400dc3e4 | Tests each emitter's global center and radius +20c with SphereAbovePlane; strictly positive results reject, including a rotating starting-plane optimization |
| Callback append 1400dc425..1400dc42c | Only passing emitters enter the bucket consumed by DoEmitterBucket |
| MdlNodeEmitter::InternalControl 140052400, call 14005246d | Applies original controller updates before CalculateRadius |
| PartEmitter::CalculateRadius 140061710..1400619ed | Source model flag bit 1 gives radius 1000; target endpoints give their distance; ordinary radius combines lifetime, speed/random velocity, global wind magnitude, gravity, maximum start/end/mid sizes, and optional chunk extents |
| SphereAbovePlane 14022e360..14022e391 | Float32 grouped dot product plus plane D minus radius; tangency passes |
| Serialized model reader 140079f90, 14007a014..14007a019 | Copies serialized model +72 to runtime model +92 |
| classification 1400a11b0 | ASCII tile=2, character=4, effect/effects=1, door=8; unknown text leaves the byte unchanged |

`../scripts/inspect-native-emitter-admission.py` executes unchanged original
radius, vector magnitude, sphere-plane and complete BSP callback bodies in
Unicorn. Synthetic transform/target/chunk views, CRT sqrt, unrelated mesh
processing, empty unrelated lists and preallocated bucket capacity are explicit
boundaries. No original renderer or complete BSP traversal is emulated.

Corpus `native-emitter-admission-observations-v2.json`: 105 radius cases,
48 exact plane results and 60 complete callback cases, including strict tangency,
empty planes and different starting planes. SHA256
`8d402f8d25ba955c2ae45e042703f2f42b17f4faabd1cdaf26f35b36e5ea228c`.
Radius cases cover source flags, mass/lifetime signs, wind, middle sizes, target
distance, null chunk children and early null-view termination. Untouched
acceleration fields start at zero in these synthetic fixtures.

## Native adaptation

`systems/native_render/particle_bounds.gd` preserves the original arithmetic.
Binary/ASCII native parsers retain classification; model instances/templates and
actor source owners pass it to private emitters. The disk model cache key changed
so old prepared data cannot silently omit the byte.

`particle_emitter.gd` samples controller/source inputs, then performs camera
sphere admission before simulation, RNG draws, births and vertex publication.
Controller time advances while a rejected emitter's particle state stays frozen.
Returning to view uses the current delta, without accumulated simulation catch-up.
The retained GPU surface is hidden while rejected, and restored when admitted.

This uses Godot camera planes, not a reconstructed NWN BSP/camera. It admits a
conservative superset: source scale, emission extent, complete quads, existing
particles and motion-blur trails can enlarge the original sphere. Unknown source
classification, scene wind, custom movement/transform services, lightning targets
and chunk models retain the prior simulation route. Complete target/chunk/scene
wind bounds are not silently approximated. Effect models retain radius 1000.

Inside centers use Godot's native point-frustum query. Original-radius and full
conservative bounds are calculated only when needed; unchanged scalar bounds
are cached privately. Camera-plane caching checks frame, camera identity,
transform and projection, including same-frame changes. No camera Object is
retained in the static cache.

Rollback diagnostic: `native-world.ps1 -UnculledParticles` or
`--particle-culling=none`. Original assets, models, UVs and textures are unchanged.

## Validation and limits

Final source cohort, normal-heap CDB, four traps, unchanged sources, no trapped
exception or engine/lifetime error:

| Report | Checks | Scope |
| --- | ---: | --- |
| native-admission-final-v2 | 346 | 213 original observations; exact words; classification parsing; GPU leave/re-enter; no state/RNG/history/upload catch-up; same-frame projection; conservative fallbacks; PackedScene flag ownership |
| native-admission-fused-v2 | 13796 | Existing 2160 moving-frame compiled/GDScript state, provider, RNG and packed-vertex equivalence cases |
| native-admission-particles-v2 | 30 | Authored and original installed torch/portal resources, animated native templates and GPU publication |

`native-session-admission-v1`: actual default launcher, owned Prelude only.
One unfinished stream is disconnected, then three joins complete in PID 33764.
Each admits 20 entities/nine tiles with 25 simulated emitters and 32 explicit
collision-provider failures. Native/server movement matches at 1.500033 m.
Twelve retired messages and twelve retired commands are rejected; all three
retired worlds release, workers reach zero, cache bindings are empty on exit.
The editor PID 1776 is preserved. This is not a public-server reproduction.

Same-build captured-room runs retain 48 tiles, 889 statics, eight creatures and
one item, with advancing native clocks/skin vertices. Final fast PNG inspected.
Both retain 1351 emitters and the same 710 diagnosed failures: 596 collision,
10 ambient wind and 104 missing fxpa_cloud02 bitmaps. Native admission rejects
99 offscreen emitters; 542 are simulated at least once versus 641 unculled.
All supported owners remain present and re-entry is covered separately.

| Run | Settled mean / p95 | Simulation mean | Admission mean |
| --- | --- | --- | --- |
| native-capture-admission-fast-v1 | 36.821 / 38.554 ms | 8.899 ms | 3.173 ms |
| native-capture-admission-unculled-v1 | 38.085 / 39.288 ms | 11.712 ms | 0.462 ms |

Each settled window has 179 intervals and zero >50 ms. Fast preparation is
11601 ms; loading 748 intervals has eight >50 ms, p95 43.348 ms and worst
72.774 ms. Initial eager admission cost 5.008 ms and erased most savings;
`native-capture-admission-v1` and failed initial camera-cache fixture are retained.
The cache now invalidates on transform/projection changes, with a passing test.

These are uncontrolled, incomplete-effect snapshots plus native animation,
not full moving protocol replay, clean benchmarks or 60 FPS acceptance. The
small timing difference does not solve the CPU bottleneck: channels/pose still
cost about 12.7 ms, and Dictionary/API marshalling remains in simulation. Next
major work is persistent typed particle/controller state, complete scene services
and full moving replay acceptance. Streaming/native faults, remaining protocol
JS and the full migration/wiki goal remain open. No new public connections or
original binary/asset modifications occurred.

`tools/check-native-particle-admission.mjs` audits current report/source pins,
original corpus, same-build room diagnostics and default reconnect ownership.
