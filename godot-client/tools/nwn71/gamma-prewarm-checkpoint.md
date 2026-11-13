# NWN-71 gamma first-use preparation checkpoint

## Candidate

`systems/native_render/native_gamma_effect.gd` now has a private `NWN71_GAMMA_PREWARM=1` opt-in. Once native surface output is enabled, it queues regular and tonal shader/pipeline preparation on the render thread before world camera entry. The original callback preparation remains available if the queue does not finish or the rendering device is unavailable. With the environment variable absent, the previous path runs unchanged. Candidate source SHA256: `a0d92018181d096fb79d68cbfb851fc6ad8c3eaab2f9416b5aac9f6588ca3e3a`.

## Correctness

- A private 256×256 Vulkan fixture (`.cache/nwn71/gamma-prewarm-a/runs/receipt.json`) passed with opt-in off/on, zero failures. Output PNGs were byte-identical, SHA256 `c460a180a82731b6e0eb12e3fe6f9d6f78f04cf263b2a5bf00a616d5e332915f`. The on run asserted tonal and midpoint pipelines valid before camera/compositor installation.
- The compatible frozen original shader pixel fixture (`.cache/nwn71/gamma-original-pixels-a/receipt.json`) passed **428 checks in each mode**, zero failures, and zero maximum sampled-pixel delta. This covers all supported postprocess masks, original shader oracle comparisons, admitted-light cases, UI, MSAA and resize from `tests/native_postprocess_pixels_test.gd`. The isolated project differs from its frozen parent only in gamma effect source.

## Short original-entry diagnostic

Both runs used the same private project, original gen4 input, selected diagnostic engine SHA256 `0a2710bd80c0a2cbfeca8ac28338a071561ba741c52a01857df233d69efe02d1`, native DLL, settings and production flags. Only `NWN71_GAMMA_PREWARM` differed. The exact selections, driver hash, traces and reports are pinned in `.cache/nwn71/gamma-entry-c/plan.json` and its per-mode receipts.

| Observation | Off | On |
| --- | ---: | ---: |
| Longest `NWN71/RD/compositor_effects` zone | 34.004 ms | 0.421 ms |
| Second-longest compositor zone | 11.806 ms | 0.339 ms |
| Tonal compute pipeline creations | 15.035 + 14.084 ms, inside 34 ms compositor zone | 13.705 + 13.643 ms, before first compositor zone |
| Regular gamma pipeline creation | 10.623 ms, inside 11.8 ms compositor zone | 11.045 ms, before first compositor zone |
| Reported prewarm time | — | 12.092 ms regular + 31.803 ms tonal |
| Playable milestone | 2,801.793 ms | 2,835.365 ms |
| Area-ready milestone | 4,278.405 ms | 4,323.935 ms |

The on trace's three pipeline creations occur around 8.67–8.71 s of that trace; its first compositor zone begins at 10.774 s. The off trace contains the tonal creations within a 34.004 ms compositor zone, then regular gamma creation within an 11.806 ms compositor zone. The prewarm moved the compile work out of those callbacks. It did not eliminate the work. The single on/off pair shows playable +33.6 ms and area-ready +45.5 ms; those differences are diagnostic and roughly match the 43.9 ms preparation moved earlier. They are not a statistically reliable total-latency or FPS conclusion.

Both short replays reached playable and reported gamma active with no gamma failure. **Neither passed strict replay acceptance**: the sandbox could not read the Windows root certificate store, and both reports classified that engine diagnostic as a failure. The 5 s observation also ended before the complete-world gate. Private user-data directories removed the earlier shader-cache-path error. Do not treat either short replay as accepted, and do not promote the opt-in as default from this evidence. A matched full original-entry pair under a valid certificate-store context and exclusive timing lease remains the next acceptance step.
