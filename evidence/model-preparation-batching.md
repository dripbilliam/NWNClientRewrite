# Multipart model preparation batching, 2026-10-21

Performance goal remains **active**. All live tests used the owned authored
native server at `127.0.0.1:5123`. No Arelith connections or original-client
changes were made. Existing installed models were read in place, not copied.

## Problem and implementation

The preceding dense native-server profiles showed approximately 7–10 seconds of
cumulative renderer CPU samples under `RendererModelPreparation` during each
area load. The old multipart path called `prepareModels`, then called `model`
again for each part. Each request recalculated the entire scene's lighting
profile, even when its asset had already been prepared. Each distinct palette
asset also entered Three's color, fade and shadow compilers separately.

`RendererModelPreparation.prepareBatch` now takes one actual current lighting
profile for a group of resource assets. It reserves every material owner before
waiting for prior work, deduplicates assets, retains individual templates, and
submits combined color, fade and shadow roots. Single-resource requests and
overlapping batches serialize the shared records. No cached/stale lighting
profile is introduced. Every submitted job settles before its material owners
can detach or dispose, including rejection and cancellation paths.

`NetworkScene.prepareModels` still fetches/decodes sources with the bounded
resource-preparation helper. Production supplies the new batch callback. The
ordered assembly then instantiates those exact prepared source/fallback assets,
instead of preparing each part a second time. Tile templates use the same
ordered reuse. If combined shader preparation fails, the original individual
resource/fallback path isolates the failed member. Ground/held item existence
selection, skeleton anchors, palette choices, animation and final appearance
guards remain with their existing owners.

This groups shader-preparation calls. It **does not batch GPU drawing** or
reduce lighting/shadow quality, geometry, resolution or the number of actors.

## Correctness and lifetime evidence

Focused suite: `backups/animations/model-batch-regression-v2.txt`, **36 tests
passed**. New tests cover one-profile grouping/deduplication, profile changes,
overlapping single/batch requests, release while polling, one rejected job with
other polls still alive, queued-owner cancellation, partial retirement, exact
prepared source/fallback identity and ordered failure handling. Existing
renderer-preparation, network loading/delivery, prefetch, area-graphics and GPU
retirement tests also pass.

The actual offline Chromium/WebGL fixture uses 19 authored material/texture
variants, alpha tests, transparency, double-sided surfaces, three real point
shadow maps and six changing poses. Individual and batched modes have:

- Byte-identical SHA-256 pixel hashes for every pose (all six poses differ).
- Identical draw geometry and program counts: 16 prepared programs, 17 after
  rendering the whole fixture (including its separately unprepared floor), 12
  remaining after template retirement.
- Three allocated 512×256 point-shadow atlases in each mode; visible shadows
  and textured geometry were inspected in `model-batch-gpu-v1.png`.
- 19 retained templates and 19 retired templates per mode; zero errors.
- **38 → 1** full profile queries and **57 → 3** compiler entry calls.

These are compiler API counts, not the number of individual GLSL programs.
Sequential GPU wall timings (632/26 ms in the first run) have uncontrolled
driver caches and are not used as a causal speedup claim. The fixture uses
authored resources; it is not a deterministic pixel replay of the multiplayer
crowd. `model-batch-gpu-v1.json` and its final run-v2 output retain the evidence.

Build passed (`model-batch-build-v1.txt`): main `index-CWvEl_gs.js`, source/vertex
worker `resource_worker-zWTWWm2T.js`, CSS `index-D6sJh7Rk.css`.

## Actual production native-server runs

Same authored DensePerf module hash as v6, 3440×1369 pixels, two native-scripted
area transfers, 48 independently wandering multipart characters, 48 braziers
and 32 chests per area. Both v7 and v8 passed and exited 0. All 48 actors moved
in every observation; zero failed models, shader/worker failures or renderer
errors. Readiness uses the same criterion as `dense-local-performance.md`.

| Run | Initial a | Transfer b | Return a |
| --- | ---: | ---: | ---: |
| v6, prior build | 20.89 s | 23.38 s | 17.71 s |
| v7, batching | 12.68 s | 13.37 s | 11.02 s |
| v8, repeat | 13.12 s | 13.80 s | 10.52 s |

Corresponding initial/transfer/return inclusive model-preparation samples:

| Run | Initial a | Transfer b | Return a |
| --- | ---: | ---: | ---: |
| v6 | 8.56 s | 9.94 s | 7.39 s |
| v7 | 1.37 s | 1.39 s | 1.33 s |

Inclusive CPU stack samples overlap and do not measure GPU duration. The source
maps were generated without changing emitted JS and checked for byte identity.
`model-batch-baseline-source-v1.json/.map` preserve the prior CDkpMJ_1 map;
`creation-performance-entry-source-v1.json/.map` describe CWvEl_gs. The generic
dense-profile summarizer chooses the map matching the recorded bundle.

v8 median FPS across its three observations: **26.77 / 30.46 / 30.81**. Median
reported p95: **42.6 / 37.0 / 36.3 ms**. Median render submission remains
**23.1 / 17.7 / 17.6 ms**; camera/light/shadow preparation adds roughly 6–7 ms.
Source and particle worker pools remain active and bounded. Thus the loading
work reduction is substantial, but the dense steady-frame goal is not met.

Each run verifies three fully closed source/vertex pools and drained prefetch
queues after disconnect. v8 also verifies **all 2,338 GPU templates destroyed**,
zero active templates/areas and zero pending preparation work before exiting.
The final client exited; the owned dense server was stopped afterward. Other
servers/clients were left untouched.

`scripts/verify-model-preparation-batching.mjs` independently checks source
hashes, exact fixture identity, endpoints, motion, resolution, failures, compiler
work counts, pixel/geometry equality, observed load reductions and final owners.
Derived result: `model-preparation-batching-proof-v1.json`, verification-v1 PASS.

## Limits and next step

Native wandering, evolving visibility and driver caches differ between runs;
these measurements are observed local workload improvements, not universal
load-time guarantees or matched original-client speedups. Original reported
230 FPS has not been reproduced under matched conditions. Arbitrary custom
assets, mounts/robes, NUI actions and portal/door input are not fully covered by
this authored crowd fixture.

The next large cost is steady render/shadow submission, binding-state checks
and scene traversal. Any reduction in GPU draw calls must preserve dynamic
material/animation behavior, per-object picking/highlights, camera keyholing,
shadow output and ownership. Extra resource workers alone do not remove these
remaining costs.
