# Local entry profiling and shared-material shadow admission

Live tests are restricted to the unchanged owned Prelude server at
`127.0.0.1:5121`. No remote server connection is part of this work.

The entry profiler attaches CDP only to the replacement renderer and collects
CPU call stacks and sample intervals, without heap values or network payloads.
The hidden source map is generated without replacing `dist`; its emitted JS
must exactly equal the current production bundle before symbolization. Node's
SourceMap resolves original source coordinates. Summaries retain VM/native,
idle and GC buckets; inclusive stack times overlap and are not GPU timings.

Baseline `index-CH11PlBE.js` entry-window-v2 reached the controlled avatar in
4.05 seconds after connect and all 92 academy objects about 6.0 seconds after
the next area-loading state. Profiling adds overhead, so these are observations,
not a before/after speedup. The transition CPU profile spans 7.52 seconds and
attributes 258 ms self time to `RendererShadowBudget.materialTextures`,
618 ms to Three's `updateMatrixWorld`, 499 ms to `needsUpdate`, and 300 ms
self time to the 2DA parser source. Rendering, shader preparation, parsing and
scene traversal all contribute; the maximum measured host read is only 2.04 ms.
Idle samples do not identify their external wait owner.

The first trial retained the launcher's old contact-fixture default and failed
its unchanged heading acknowledgement check after initial profiling. It is
preserved as entry-window-v1. The corrected launcher explicitly disables
keyboard/contact checks for this loading experiment. No movement acceptance
claim is made by this test.

The v2 maximized stage really uses a 3100 x 1121 framebuffer and records a
median 85.8 FPS. The fullscreen flag was true but the actual framebuffer was
only 1100 x 712. That run does not establish display-sized fullscreen
performance. The helper now establishes and checks display-sized native bounds
before that stage. A verifier also corrected its initial mistaken assumption
that fullscreen implies `isMaximized()`: Windows reports fullscreen true and
maximized false. It still requires the explicit fullscreen state.

## Production change

`RendererShadowBudget.update` now deduplicates materials for its synchronous
sampler scan. Multiple meshes sharing a material contribute the same maximum
sampler requirement. A new Set is local to each update: next-frame map changes,
custom uniform arrays, material version changes and scene environment remain
live, and no resource owner is retained. Light ordering, capacity and authored
shadow requests are unchanged. This is an optimization of the existing GPU
sampler guard, not an implementation of native per-object light selection.

Twenty-three focused shadow-budget, model-preparation, light-slot and shadow
traversal tests pass. The new regression covers material arrays, repeated
references, map removal, changing uniforms, environment and schema changes.
The CPU-only benchmark compares the preserved previous implementation against
the new one over interleaved rounds and 60 evolving-state comparisons:

| Mesh instances / 64 materials | Before median | Current median |
| --- | --- | --- |
| 64 | 0.038 ms | 0.022 ms |
| 512 | 0.251 ms | 0.032 ms |
| 2048 | 0.995 ms | 0.063 ms |

The benchmark initially reused mutable plain-light admission state between
both implementations, so the second owner saw already-disabled requests.
It now supplies explicit authored requests, as production model lights do;
the equality gate remains unchanged. These synthetic timings are not a live
FPS gain, do not measure GPU time, and do not establish the original lag cause.

Remaining work includes full world/frame movement parity, remaining effect
resource ownership and broader local visual/performance acceptance. The goal
remains active.

## Final local checks

Baseline entry-window-v3 verifies native fullscreen bounds of 3440 x 1440,
scale 1, and a game framebuffer of 3100 x 1192. During the 60-second orbit,
settled FPS ranges from 69.7 to 90.6, median 83.0; the first/last ten-second
medians are 86.4/82.4. All 92 objects remain present, the controlled avatar
renders, programs remain at 22 and asset/shader queues stay empty. The prior
10-FPS collapse was not reproduced in this local academy scene. Maximized
3100 x 1121 has median 82.1 FPS. This is the **pre-optimization bundle**,
`index-CH11PlBE.js`, not a current-build performance ratio.

The optimized production build is `index-BCGnOBME.js`. Build and actual packaged
renderer/preload image smoke checks pass (main-v16, zero joins/external fetches).
A fresh local login reaches the avatar in 4.05 seconds. The ordinary tutorial
dialogue/door transition succeeds, acknowledges the new area in 4.51 seconds,
renders its avatar in 5.26 seconds and prepares all 92 objects by 5.76 seconds.
There are zero renderer errors or failed models. No causal comparison is made
against profiled runs or differently populated/cache-warmed sessions. The
updated client is reopened for passive local use after finite test inputs stop.
