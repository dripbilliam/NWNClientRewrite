# Performance panel — 2026-10-19

Outer inspector now shows two-second rendered FPS, completion-to-completion
average/p95 frame time, resettable worst frame and >50ms hitch count. It counts
actual draws, not warmup callbacks; hidden periods do not become false hitches.
Readbacks/layout and DOM publication happen twice a second, not every frame.

Expandable details show CPU/driver submission stages (not GPU timer or ping),
separate main/shadow draw and triangle counts, buffer/viewport/pixel ratio,
actual lighting/shadow admission and shader pool capacities, cached programs
and recent growth, pending resource loads/shader preparation, preparation
failures, geometry/texture counts and available renderer JS heap measurement.
Shadow counts are measured before Three resets its counters for the color pass.
The reset button affects statistics only. No native gameplay changes.

Buildv2 and13 focused rendering/loading regressions pass. Numeric simulation
records approximately60FPS at60Hz, an immediately reported1000ms stall/one
hitch, and a non-drawing preparation state. Live160/PID53196, BFpbB-WG/BHtOrekZ,
connects to the unchanged vanilla server; panel is in the inspector and updates
with live renderer values. Source/GPU-driver/warmup defects remain open.

User reports30-40FPS on strong hardware. New passive5s profile retains source
locations: WebGLBindingStates attribute checks are hottest; shadow sampler
budget's material traversal is another major allocation/CPU cost. Screenshot
and CPU profile are retained. Live example:9ms render submission,9ms camera/
light setup,3ms particles, approximately1700 shadow draw calls. These are
observations of this scene, not a GPU bottleneck measurement.

Native renderer investigation is continuing using the existing Ghidra-backed
read-only REA MCP session. Full multiplayer goal remains active.
