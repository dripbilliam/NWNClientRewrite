# NWN-64 original G2 particle subphase checkpoint

The private diagnostic at `reports/nwn64-current-heavy-subphase-g2-b.json` reached generation 2 and recorded 18 complete samples with 1,829 fast members. It used the same original capture, engine and preferences as the accepted-DLL coarse sample at `reports/nwn64-current-heavy-phase-g2-a.json`, but a separate, previously parity-checked C2 diagnostic DLL. Both replay reports have `success: false` because the engine emitted shader-cache-folder and root-certificate errors. Their particle samplers report zero errors and the intended full scene; neither is a clean performance acceptance result.

| Instrumented G2 phase | Mean ms per sampled frame |
| --- | ---: |
| Simulation total | 0.676 |
| Eligibility | 0.406 |
| Patch/detonate guard | 0.283 |
| Emitter pose | 0.282 |
| Channels | 0.244 |
| Source pose | 0.172 |
| Admission | 0.131 |

Each sample has about 3,005 active particles and 638 culled emitters. There are 670 chunk emitters, 20 wind emitters, zero bounce emitters, about five births, 626 sampled channels, and 1,829 emitter plus 1,829 source pose reads. Source IDs repeat 876 times, 368 within conservative same-segment groups. The phase spans add measurement work per emitter and some phases nest; their numbers cannot be added or subtracted as uninstrumented costs. The accepted-DLL coarse entry phase averaged 1.751 ms over 14 full-scene samples; the diagnostic entry phase averaged 3.133 ms over 18. That difference is not a candidate regression measurement.

Source checks reject two tempting changes. The patch/detonate scope has zero patch boundaries in G2, so its 0.283 ms is largely guard plus per-emitter probe overhead, not evidence of patch application work. Eligibility already uses the direct engine ABI (`native/particle_scene_direct.hpp.inc`), while repeated pose reuse was previously slower in the synthetic component check. Simulation has no bounce and very few births; a prior clear-hit coalescing candidate changed service-call count/order and was restored. There is no proven substantial safe compact-header change from this capture. Keep `native/particle_compact.hpp` and `native/particle_compact_bridge.hpp` unchanged pending a component win with exact state, RNG, and service-call order.

The private staging selection is `.cache/nwn64/current-heavy-subphases-b/staged.json`. The first `-a` staging attempt stopped when its helper already existed in the cloned source; `-b` hash-checked that helper and validated every production-selection pin before the single replay. No accepted engine, DLL, preference or default was changed.
