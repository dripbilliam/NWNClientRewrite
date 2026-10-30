# Native particle dispatch and remaining CPU cost

This follows [NATIVE-SCENE-POINT-WIND.md](NATIVE-SCENE-POINT-WIND.md). The scene
provider enables17 more local and472 more captured emitters. Preserve that
functionality while reducing CPU overhead. The full performance/migration goal
remains active.

## Production path

Compiled `animate_fountain`, `animate_explosion` and `animate_single` operations
directly call the existing native frame/update/standard-movement routines. They
remove the C++→GDScript→C++ update and movement adapters while preserving math,
source/fade/transform handling, RNG, creation and scene/chunk providers. Explicit
custom update/movement services keep composed dispatch; Lightning retains its
owner. No dormant/offscreen emitter is dropped as an optimization.

`particle_channels.gd` lazily retains immutable single-row, non-Bezier controller
results. It reapplies values each sample, including consumed byte pulses, and
copies vector outputs. One-row Bezier remains sampled because its original
endpoint behavior can read adjacent storage and change over time. Invalid-clock
and unused malformed-storage failures retain their prior timing.

A C++ numeric parameter-copy operation passes exact-word checks but did not make
the room faster. It is **diagnostic-only**; production retains GDScript field
copying. Both paths still marshal per-field Dictionaries, so changing language
boundaries alone did not eliminate that cost.

Offline switches:`native-world.ps1 -ComposedParticles`,
`-UncachedParticleChannels`, or `-NativeParticleParameters`. Internal equivalents
are `--particle-dispatch=composed`, `--particle-channels=sampled`, and
`--particle-parameters=cpp`. These do not enable JS simulation or alter assets.

## Current checks

The `native-point-final-*` reports use normal-heap CDB, four armed traps, unchanged
pinned sources and no trapped exception or engine/lifetime error:

| Suffix | Checks | Coverage |
| --- | ---: | --- |
| fused-v1 |13796|2160 moving frames; state/provider/RNG/packed vertices match original-checked GDScript owners; adapter callbacks fail if unexpectedly invoked|
| parameters-v1 |602|26 fields/21 inputs, exact float words/defaults/colors and explicit malformed values|
| channels-v1 |50|scalar/vector/byte clocks, caller mutation, Bezier endpoints and delayed bad-storage errors|
| wind-v1 |387|375 original observations plus actual compiled explosion/world services, custom movement fallback and retirement|
| schedule-v1 |1907|original frame/lifetime/update corpus|
| vertices-v1 |492|original packed vertex corpus|
| chunks-v1 |119|private chunk-model GPU owners|
| retirement-v1 |72|actual delayed-worker/overflow paths|
| publication-v1 |10|live stream/adoption effect ownership|
| particles-v1 |30|original torch/portal GPU fixture|

The fused fixture has fewer diagnostic checks than the composed18084 because
intermediate API calls disappeared; the2160 moving scenarios are unchanged.
Initial parameter fixtures used a literal negative zero that also changed their
reference default-zero word in this pinned engine. Explicit bit construction
isolates that input; retained failed runs were not promoted into passes.

`native-session-point-final-v1`:actual default launcher on owned Prelude,
unfinished-worker disconnect followed by three joins in PID48820. Each admits20
entities/nine tiles,25 simulated/fused emitters and32 collision-provider failures.
Authoritative/native movement,12 stale rejections in each direction, worker
retirement and final empty cache bindings pass. Dormant local explosions add no
sources; authored tests prove actual blast registration.

## Same-build captured comparison

Both final runs retain48 tiles/889 statics/eight animated creatures/one item.
Native clocks/skin positions advance and final default PNG is inspected. Both
simulate641 emitters, with710 failures:596 collision,10 ambient wind and104
unavailable fxpa_cloud02 bitmaps. Neither snapshot detonates a point source.

| Run | Settled mean / p95 | Simulation mean | Channels/pose mean |
| --- | --- | --- | --- |
| native-capture-point-final-default-v1 |36.403 /38.038 ms|11.540 ms|12.360 ms|
| native-capture-point-final-composed-v1 |39.528 /40.886 ms|13.757 ms|12.570 ms|

Each settled window contains179 intervals and zero>50 ms. Default preparation is
11749 ms;685 loading intervals average15.439 ms,p9544.057,worst64.475,8>50 ms.
Render CPU/GPU means2.081/3.503 ms. Editor1776 remains open. These uncontrolled,
incomplete-effect snapshots plus native animation are not full moving protocol
replay or clean60 FPS acceptance. The earlier roughly49 FPS checkpoint failed
472 more emitters and is not a fidelity-equivalent baseline.

Retained earlier-pin experiments:constant channels have no reliable FPS gain
(`...point-cached-v1`37.219 ms versus`...point-sampled-v1`37.367 ms). C++ field
copying was not faster (`...point-native-fields-v1`37.247 ms versus
`...point-gd-fields-v1`36.909 ms), so its default was rejected.

`tools/check-native-point-wind-dispatch.mjs` audits all13 current report sets,
source/DLL pins, original identity, dispatch counts, partial failures, reconnect
ownership and clean logs. Output:`reports/native-point-wind-dispatch-v1.verified.json`.

Follow-up: [NATIVE-PARTICLE-ADMISSION.md](NATIVE-PARTICLE-ADMISSION.md) resolves
the animation gates, traces the BSP sphere-admission callback, retains original
model classification and implements conservative native camera admission.
Original/native GPU checks and default local reconnects pass. The measured room
gain is small; full effects, moving replay and 60 FPS remain unmet.

Original investigation entry:Scene::DoEmitterBucket1400c7ae0 calls AnimateParticles
at1400c7c94 conditionally on scene virtual+280 or source Gob virtual+2a0. Resolve
those targets before asserting camera-frustum skipping is equivalent. Persistent
typed native state could also remove Dictionary/API marshalling; that remains a
proposed implementation, not an achieved speedup. Ambient wind, collision, event
playback, missing bitmaps, full replay/culling,60 FPS and remaining JS migration
are open. No public connections or original binary/asset changes occurred.
Native shutdown faults and the full migration/wiki goal are not declared solved.
