# Performance and loading

The goal remains unfinished. Measure the client the user actually launches, at complete scene/effect coverage and matching camera, input, resolution and settings. Captured replay, component CPU work and actual online performance are different evidence scopes.

## Latest retained checkpoint

The current movement checkpoint records installed application identity `e62371bcf4380f09ccd72a9a3eae432dc4751106353e369eb438a025d72c5d30`. The planner avoids revisiting installed/pending appearances; an immutable light-palette fix preserves actual GPU bytes.

The final matched combined replay reports sampled input FPS 77→89 and quiet 97→97. Final quiet frame means are 9.566 ms control and 9.623 ms candidate. Geometry/counts/settings/camera, all 360 recorded input operations, DLL provenance and cleanup gates pass. This supports that replay, not a quiet-speed gain or public-server guarantee.

Earlier matched baselines vary (68–77 input FPS). The manual run later closed cleanly with ACK and no remaining workers; its automated gameplay-success flag is false, so it is not an automated authority acceptance. The user reports original uncapped 170–200 FPS; matching live camera/effects remains unverified.

The latest retained profile identifies particles, rigs and render-thread scene/canvas work as larger costs after planning improvements. A light-publication candidate is source-only, untested and uninstalled. Keep graphical workloads held during the user's comparison session.

Exact latest receipt paths and run restrictions remain in [the compact current goal](../godot-client/NATIVE-FPS-MAX-GOAL.md). Earlier checkpoints are in the [archive](archive.md).

## Effective configuration

`systems/native_data/client_feature_registry.json` is the supported selection schema. Inspect [CLIENT-FLAGS](../godot-client/CLIENT-FLAGS.md) and actual startup observations, not remembered command-line recipes.

Ordinary/streamed/merged loading, engine runtime, render-thread policy, light-input owner, snapshot preparation and collision route are independent choices. Indexed collision is now the ordinary default. Other experimental selections are not silently promoted by choosing a loading preset.

## Remaining work

Dense collision narrow phase, synchronous world application, options binding, packed serialization and indivisible shader/resource work still create tails. Cooperative publication has a soft budget: individual GPU/material/mesh calls may exceed it. A reported 3 ms budget is not a hard bound.

Distinguish cold startup/preparation, first shader use, player-ready admission, complete background scenery and retired-world destruction. A prepared draw/model cache does not equal a complete ahead-of-time source-format conversion pipeline.

Keep profiling off for FPS conclusions and run attribution separately. Do not add parent/child maxima or unrelated frames. Preserve actual input timing/lateness and complete population; a late replay does not reproduce network-delay timing exactly.

Track normal dense loading/frame acceptance in [NWN-54](https://linear.app/nwnanalog/issue/NWN-54). Particle-backend performance remains under NWN-8. Use the [deferred queue](../scripts/performance-queue/README.md) for existing bounded checks rather than inventing another benchmark framework.
