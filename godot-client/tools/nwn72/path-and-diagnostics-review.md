# NWN-72 isolated work-reduction review

The shared `systems/network_motion.gd` already contains several NWN-72 changes. This review extracts two independently applicable reductions without editing the production files or the accepted runtime. The patches have **different frozen baselines** and are review artifacts, not sequential patches. Current `network_motion.gd` SHA-256 is `7b943610ba9765c8052e22fccdeaf2ca0e33f27eb86917db8ac44be5ab1d0762`; `combat_motion.gd` is `e2594c557285697cbc558eb58c40dd925e38d94e9791e9b435c1cede87f824d6`. Neither was changed in this audit.

## Path traversal

`path-slice-only.patch` removes `state.path.slice(cursor)` allocation from `distance()` and caches the path and length in `step_path()`. Negative cursors retain Array.slice's effective start clamp. No facing or diagnostics code is part of this patch. Frozen source SHA-256 `717f9d432b74d3eb7d018c765705df3f63f605bb66b52d197374acea663f5310` becomes `e7dfccb1733ecf0201189070bc4793390d7e4dab3382c7bf0734f70bafc94fe9`; patch SHA-256 `2b2ae40a8cb63bc1a118319c0e17523fb479243029e59d3f380f589a4047448d`.

The resulting candidate SHA exactly matches the saved captured ABBA oracle `.cache/nwn72/path-traversal-20261112a/captured-timed-a.json`: 9/9 checks, bit-identical final state for the captured 13-creature input and explicit 208-row synthetic scaling. Its 13-row median was 33 µs control versus 32 µs candidate; the 208-row synthetic medians were 502 µs control versus 492/496 µs candidate. These component timings do not establish a whole-client FPS gain. A private Git apply check with line-ending conversion disabled recreated the candidate byte for byte; `.cache/nwn72/path-slice-review-a/verification.json` records patch and oracle hashes.

## Normal-profiler counter gate

`diagnostics-gate-only.patch` makes the existing per-row evaluation counters conditional on `collect_diagnostics` while retaining its default `true` for direct diagnostics. Frozen source SHA-256 `ce9321701128554f145e1e326e22b65715927ea065cab63972d546e6c0732461` becomes `ac31ad2e26315cb61067be58b99fbf4c9a236b64f3129521996a052c769b93de`; patch SHA-256 `a24e08276debdcd40bd47d9b26052a6faa969e75d6a736d90926d33e810a1a97`. The normal world already sets `motion.collect_diagnostics=FrameProfile.enabled` at `live_world.gd:695` (read-only source SHA-256 `ec5c12122567a3824650dedbc0b212b3a0e2651d20825493ece161ea6bd4f422`).

The isolated candidate passed 13/13 new headless captured-state checks: 13 and 208 rows have bit-identical final motion state with counters enabled or disabled; enabled counted 32 updates and disabled counted zero. The saved component ABBA on the integrated source also reports identical states; 13-row median fell from 32 to 30 µs with counters off, and the explicit 208-row synthetic medians fell from 500/494 to 475 µs. This is component work reduction, not a live FPS claim. A private Git apply check recreated the isolated candidate byte for byte; `.cache/nwn72/diagnostics-review-a/verification.json` records its hashes.

Both private patch checks and the focused headless fixture completed without changing `systems/native_render/live_world.gd`, launching a client, or measuring FPS. The captured normal population reached at most 13 registered creatures; larger-population timing is synthetic. Production promotion still belongs to the coordinator's whole-client gate.
