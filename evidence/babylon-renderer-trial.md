# Babylon renderer trial — 22 October 2026

Babylon.js **9.32.0** is pinned as a development dependency. The experimental
engine adapter is connected to the offline captured-room replay, not the normal
client. No Arelith connection or original-client inspection was performed.

The original NWN process (PID 27848) was preserved when requested. On the later
instruction to start testing, no NWN/Electron game remained open. Tests used only
the offline capture. **The Babylon migration has not demonstrated a speedup and
remains disabled in the normal client.**

## Implemented boundary

`scripts/performance-candidates/babylon-room-adapter.mjs` creates Babylon's
WebGPU engine, scene, geometry, mesh, texture, material, uniform and render-bundle
owners from the existing decoded NWN objects. It supports shared geometry,
draw groups, mutable positions/normals/UVs/particle colours, source camera/world
matrices and native point/ambient Lambert attenuation through WGSL. Custom
particle blend factors have a small version-pinned Babylon pipeline-cache
adapter, checked on a real GPU. Source resources remain owned by NWN. Camera and
light data now use one shared frame uniform buffer. Unchanged world and normal
matrices retain their existing owners and GPU data. Negative winding and draw
range changes invalidate their cached render bundles.

The first port uses decoded RGBA base texture mips and linear filtering.
Shadows, fog, full mip/filter fidelity, special materials, picking, UI and the
complete live gameplay loop are not ported. Unsupported objects/states are
counted explicitly. Unknown topology changes fail rather than reusing stale
geometry. Nothing is promoted to the normal rendering path.

`babylon-room-audit.mjs` constructs an independent Three reference containing
the same admitted subset, captures both images, retains exact pixel differences
without a tolerance, and repeats renderer order for CPU preparation/submission
timing. GPU completion waits are outside the CPU timer. Those timings are not
whole-game FPS. Excluded content and the missing full-frame features must be
addressed before any engine migration is accepted.

The replay transform exposes `window.sceneReplayForTest.babylonRoom()` and the
Electron runner accepts `--babylon-room`. It pauses and restores the original
source animation loop and rendering mode during the audit. The resulting report
contains `babylonRoom`, with separate Babylon/reference PNGs. A failed Babylon
comparison also fails the report; the existing partial-capture gate is unchanged.

## Validation and prepared next checks

- Eight CPU adapter cases passed: shared resources/poses, camera/native light
  values, texture ownership/ranges, unsupported states/topology, native Babylon
  WGSL preprocessing, attribute replacement/index guards, persistent pose
  invalidation and the prepared-light pass lifetime.
- Together with the existing replay/frame acceptance checks: **32 passed**.
- Standalone authored fixture bundled successfully with Vite (404 modules).
  Later adapter changes require rebuilding before using that emitted bundle.
- GPU fixture is at `scripts/renderer-babylon-fixture.html`; its runner
  is `scripts/performance-queue/probe-babylon-room.cjs`. It checks real textures,
  changing transforms, negative facing, vertex updates and point/ambient light.
  **15 authored GPU cases pass exactly**, including polygon offset, texture
  transforms/flip, mutable draw ranges, native ambient-only points, custom
  particle alpha/additive blending and world-space particle positions.
  Final evidence: `runtime-logs/performance-queue/babylon-gpu-v1/gpu-final.json`.
- The queue manifest includes `babylon-adapter-boundaries` and
  `babylon-adapter-gpu`. GPU/replay runners refuse to run alongside another
  Electron/NWN game and block external web requests.

After the original game is closed, run the authored GPU check first, then make
a fresh diagnostic build with the existing builder:

```powershell
node scripts/performance-queue/prepare-preview-build.mjs --run --diagnostic --replay --draw-bridge --out=backups/animations/performance-queue/babylon-room-v1/diagnostic-build --report=runtime-logs/performance-queue/babylon-room-v1/build.json
```

Run `replay-scene.cjs` in Electron with the existing primary capture and three
supplements, that private build, a fresh report output, and `--babylon-room`.
The replay has no live server/session implementation and blocks all external
requests. Do not substitute a live connection for this test.

## Captured-room results

The latest unprofiled paired run is
`runtime-logs/performance-queue/babylon-room-v6/room-v6.json`:

| Renderer | CPU prep/submission, repeat 1 | Repeat 2 |
| --- | ---: | ---: |
| Three stock | 11.14 ms | 11.94 ms |
| Babylon WebGPU | 14.00 ms | 14.28 ms |

Both engines issued all **2,796 admitted draws** at **1424 × 921**. No objects
were filtered out by the adapter in this view. The source animation loop was
paused, shadows/fog and full texture mip fidelity were excluded on both sides,
and GPU/fence completion waits were kept outside the CPU timer. These are
renderer subset timings, **not whole-client FPS or a migration acceptance**.
The cached path reused all 2,796 world and normal matrices in the last measured
frame. It still did not beat Three.

Strict image parity fails: 15,632 of 1,311,504 pixels differ, with 20,410 of
21,998 differing channels off by one byte. Larger differences and alpha-edge
differences remain; the maximum channel error is 255. No tolerance was added.
The original capture's partial final-frame acceptance and current viewport
differences also remain failures in the outer report.

Earlier runs are retained as failures: v1 read light state after its lifetime;
v2 admitted only 127/3,534 items before polygon-offset support; v3 had incorrect
reference transforms for frozen lights; v4 corrected those transforms but still
used Babylon's default anisotropy instead of the reference's level 1. v5 was
built but not executed after the sampler discrepancy was identified. Different
runs used different viewport sizes; do not compare their absolute times as
paired improvements. All authored tests now pass with the corrections.

Scoped profiling is available with `--babylon-room --babylon-profile`. It
samples only the two warmed Babylon phases and labels the run as profiled.
`summarize-babylon-profile.mjs` resolves the exact private build's source map and
separates idle waits from active JS samples. Profiling output is diagnostic,
not a replacement for the unprofiled comparison above.

The successful scoped capture is
`runtime-logs/performance-queue/babylon-profile-v2/profile-v2.json`, with two
source-mapped profiles and `cpu-summary-v2.json`. This run used 3,222 draws at
1920 × 983; it is not directly comparable to the unprofiled v6 viewport.

| Profiled stage, per frame | Repeat 1 | Repeat 2 |
| --- | ---: | ---: |
| Adapter update | 4.18 ms | 4.14 ms |
| Babylon scene render | 13.01 ms | 13.01 ms |
| End-frame submission | 0.062 ms | 0.058 ms |

Across the 120 sampled frames, `ShaderMaterial.bind` accounted for approximately
3.68 ms/frame inclusively; `ShaderMaterial.isReady` 1.77 ms/frame; and
`Scene._evaluateActiveMeshes` 2.50 ms/frame. `Mesh.render` accounted for 8.88
ms/frame inclusively and contains material work: **do not add those nested
figures together**. Adapter `update` accumulated approximately 4.13 ms/frame,
including `syncRow` at 2.20 ms/frame. The evidence points to repeated CPU
mesh/material traversal, readiness checks, binding and adapter state refresh.
Loading and shader compilation were outside these steady samples.

The profile also contains 1,549.7 ms of unattributed `(program)` samples and
1,552.0 ms of idle samples. Neither is attributed to a CPU hotspot or claimed
as GPU execution. Stage clocks, rather than those unknown samples, establish
the measured CPU durations. The unsuccessful console-profile capture is retained
as `babylon-profile-v1`; its stage clocks existed but no CPU samples were returned.

Further experiments should target cached material/readiness owners, changed-only
adapter updates, stable render lists and fewer draw records. The results do not
justify promoting this engine port or claiming that swapping engines improves
the game.

## Backups and production boundary

Before this work: `backups/before-babylon-engine-adapter-20261022.zip`, verified
SHA-256 `e0f385a48ddde8d659832339bb9fc449fe126518b0cde819aaee699881b19633`.

Normal `src/main.js` SHA-256 remains
`7e84f596cc2c13f0d307931f2a90ce541a3e01f292b6be1df7f7a92741f0fb9e`.
Normal main bundle remains
`7448b09d205748ab44fe0174a765e36729fa4c88433fcfa33f9c739f87db3a66`.
The package/lock change adds only the pinned Babylon package. No game assets,
credentials or captures were copied into source or backups.

Primary API references: [Babylon WebGPU documentation](https://github.com/BabylonJS/Documentation/blob/master/content/setup/support/webGPU.md),
[native WGSL material documentation](https://github.com/BabylonJS/Documentation/blob/master/content/setup/support/webGPU/webGPUWGSL.md),
and the locally installed, pinned package implementation/types.
