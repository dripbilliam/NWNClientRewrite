# NWN-71 CPU midpoint full pixel gate

Status: default-off candidate passed the full isolated GPU pixel oracle; live acceptance and the isolated prior access violation remain open. No FPS benchmark or shared-client restart was run.

## Exact gate

`tools/nwn71/run-cpu-midpoint-full-oracle.cjs` (SHA-256 `dcef5f603f6bfde0aba01f5f1bc65299f156cc5b35afe1aeb193e990a1d79768`) temporarily overlaid the current candidate into the previously frozen private original-asset project. It verified gamma source SHA-256 `8e60a4c334e8c659af10aa4045e811c2f36404541c81d583c18d88b80f4b5468`, postprocess `539878e853a113e59624b9fa33fedb7cba70e192061de4ada4748031abd57b2b`, unchanged 428-check oracle `bfa25a8c346201c56f9d2e2d4dee5ebf74515caad7c65abba8412c898aaf3257`, and private engine `0a2710bd80c0a2cbfeca8ac28338a071561ba741c52a01857df233d69efe02d1`. A `finally` block restored both frozen private sources and verified their old hashes. The accepted source files were only read.

Receipt `.cache/nwn71/cpu-midpoint-full-oracle-a/receipt.json` (SHA-256 `c42fe603d7d872b53303b79991f8d2ebff6fcc9ed839c2540aab9b6737206fc9`) records:

| Mode | Exit | Oracle checks | Failures | Sampled pixel difference from OFF |
| --- | ---: | ---: | ---: | ---: |
| GPU midpoint OFF/default | 0 | 428 | 0 | — |
| CPU midpoint ON | 0 | 428 | 0 | 0 across all 192 RGB samples |

The oracle includes every supported mask, 0/8/128 admitted lights, gamma and HDR/dark colors, original shader results, UI preservation, MSAA and resize. Both runs completed the test's world cleanup and process exit. The gamma effect reported no failure.

## Work removed, and work retained

The `NWN71_CPU_MIDPOINT=1` source branch in `native_gamma_effect.gd:185–188` creates only a 16-byte midpoint output buffer and returns before compiling or creating the midpoint shader/pipeline/input buffer. `publish_postprocess_frame` computes the four-float packet on the publishing thread. The callback uploads that packet when it changes and skips the 1×1 midpoint dispatch/barrier at lines 236–238. The full-screen tonal compositor dispatch at line 240 still runs. In this fixture, the OFF path counted 590 GPU midpoint dispatches and 25 uploads; the ON path counted 24 CPU midpoint publications and 17 uploads. These counters represent different operations, so their numeric difference is **not** a frame-time saving. The source and pixel gate establish less render-thread/GPU compute work with extra CPU work; they do not establish total latency or FPS benefit.

## Earlier `0xC0000005`

The first 256×256 ON run on the earlier gamma source `63bcee2a...` wrote a passing report and identical PNG, then exited `0xC0000005` before the runner could establish safe teardown. The failure is after report writing, which precedes `effect.close(); world.free(); await process_frame; quit()` in `tests/nwn71/gamma_prewarm_pixels.gd:50–53`. The saved stdout/stderr/engine log contain no native stack or RID error, and a Windows Application Error/Windows Error Reporting event query around 2026-11-12 13:51 local returned no record. The exact faulting operation remains unknown.

The later six small OFF/ON repetitions on current source all exited 0 with identical PNGs, and this full 428-check OFF/ON pair also exited 0. `native_gamma.gd:61–62` closes the effect when the full fixture frees its world, so that pair did exercise cleanup. The archived source change between the failing and current runs altered the default-OFF lock flow; it does not explain an ON crash. The candidate remains default-off until a native crash stack or stronger repeat/entry stability gate establishes that shutdown and live transitions are safe. NWN-71 remains In Progress.
