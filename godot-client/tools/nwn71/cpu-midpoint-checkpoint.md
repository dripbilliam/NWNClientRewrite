# NWN-71 CPU midpoint candidate checkpoint

## Why this branch

The saved transition contains a 63.591 ms main render sync overlapping 71.699 ms in the render-thread compositor body. A separate callback-identity capture maps a 34.9897 ms first-use callback to native gamma with high confidence. Gamma's tonal preparation creates two compute pipelines; the second is only the 1×1 light midpoint reduction. The existing prewarm experiment moved about 43.9 ms before first draw but did not remove the work or improve total entry latency. The older 49.892 ms unidentified worker-group wait remains a separate unresolved stall.

## Opt-in source

`NWN71_CPU_MIDPOINT=1` in `systems/native_render/native_gamma_effect.gd` computes the midpoint from the already captured maximum 128-light packet on the publishing thread. It uploads the four resulting float values (16 bytes) into the existing tonal storage binding. The opt-in skips `MIDPOINT_SOURCE` shader/pipeline creation, the 4,240-byte input storage buffer, its GPU upload, and the 1×1 dispatch/barrier. The default GPU path and existing `NWN71_GAMMA_PREWARM` option remain available. The extra CPU work may offset the render-thread saving; no whole-frame or entry benefit has been measured.

Before-edit copies are under `.cache/nwn71/cpu-midpoint-a/before` (gamma SHA-256 `a0d92018181d096fb79d68cbfb851fc6ad8c3eaab2f9416b5aac9f6588ca3e3a`, postprocess `0495dc4364e242ab9cdf6889988e14501de1d358e077b903adc941f6835913d2`). Candidate source hashes: gamma `8e60a4c334e8c659af10aa4045e811c2f36404541c81d583c18d88b80f4b5468`, postprocess `539878e853a113e59624b9fa33fedb7cba70e192061de4ada4748031abd57b2b`.

## Current correctness evidence

- The first small 256×256 Vulkan off/on run wrote matching PNGs and passing reports, but the ON process exited with Windows `0xC0000005` after its report. Its receipt is preserved at `.cache/nwn71/cpu-midpoint-a/fixture-runs/receipt.json`. This remains a stability concern.
- After the default-path lock flow was restored to its original single lock, a bounded six-run OFF/ON/ON/OFF/OFF/ON sequence used fresh user-data folders. All six exited 0, reported no effect failures and produced byte-identical PNG SHA-256 `c460a180a82731b6e0eb12e3fe6f9d6f78f04cf263b2a5bf00a616d5e332915f`. Receipt: `.cache/nwn71/cpu-midpoint-a/fixture-repeat-b/receipt.json`, SHA-256 `1683c12da4554d49dbcac76952289434aa5622df9d8ac973fe3538d36b30b6a7`.
- A **CPU-only** headless check recreated the 24 mask × admitted-light-count combinations (0, 8 and 128 lights) used by the frozen unchanged-original GPU shader oracle. Across 192 saved oracle observations, maximum midpoint difference was `2.23517418185271e-8`, with zero failures. Report: `.cache/nwn71/cpu-midpoint-a/cpu-oracle.json`, SHA-256 `0e7b59ab27c053e08682f9eeeb3e4e91c04fd7a7e8b83ef28aa676faa2615568`. This verifies the midpoint arithmetic for those authored cases, not complete rendered-image parity.
- A second headless check exercised contrast selection/publication, vibrance-only selection, stale tone reset, surface-output rollback and close with the option OFF and ON. Both exited 0 with no failures: `.cache/nwn71/cpu-midpoint-a/state-check/off.json` and `on.json`.
- Source whitespace check and test-runner syntax check passed. No accepted engine rebuild or FPS benchmark was performed for this candidate.

## Acceptance still needed

The user's approximate full-PC testing window elapsed. Pause graphical and FPS work until renewed availability. Then run the complete 428-check original-shader GPU pixel fixture with opt-in OFF/ON, including contrast masks, UI, MSAA and resize. Repeat bounded startup/shutdown checks because of the isolated ON crash. If those pass, make a compatible full-entry pair with callback/CPU-main attribution and only then consider a coordinator-exclusive matched FPS pair. Keep this candidate default-off and NWN-71 In Progress until a measured end-to-end benefit and transition correctness are established.
