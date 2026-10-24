# Animated characters with retained light capacity

This investigation makes no production change. It extends the offline installed
Prelude fixture from nine active lights / sixteen shader slots / nine shadows to
the user's reported count pattern: 42 active lights, 128 retained point-light
slots, and 15 actual point shadows. It uses the current production skin adapter,
light selection, uniform capacity, shadow budget/traversal/cache and main render
callbacks. The previously rejected compact-loop experiment remains disconnected
from production; see `renderer-native-performance.md` for that regression.

The fixture reads installed assets in memory and independently assembles 48
multipart wizards, then 48 robed variants, with 99 animators and 48 skin meshes
per case. Characters run in place at a fixed 1/60 animation step. No server is
joined, no download is made, and no asset payload is copied into the workspace.
The open local client and both owned servers are left untouched.

Thirty-three synthetic lights supplement nine original tile lights. Six extra
lights request shadows, using production 512px map configuration. To reproduce
retained capacity through the actual reserve policy, the 128-slot case first
adds 54 lights (63 active total), prepares lighting, removes 21, and prepares
again. The fresh case adds only 33, yielding 42 active / 64 reserved. Runtime
checks require these exact counts, rather than assigning the desired capacity
directly. All fifteen actual shadow maps redraw in the animated workload.

Short v13/v14 cases use 180 frames per style, exclude the first 30, and complete
GPU work with gl.finish at an asserted 3100x1121 framebuffer. Retained/fresh
median completed work was 32.1/30.9ms for the unrobed actor and 25.8/25.2ms for
the robed actor. Geometry/pose samples, per-frame main draw/triangle/memory/program
counts and final actual shadow workloads agree. Final shadow draws are 7,980 /
6,152 for the two styles. These comparisons do not include pixel equivalence.
Their execution order, open background client and uncontrolled driver cache
preclude attributing the small timing difference solely to uniform padding.
This does not justify changing the production reserve policy.

The v15 sustained cases add continuous camera rotation and 2,400 frames per
style. The verifier requires more than a minute of actual wall time per style,
records 30-second timing windows, verifies light/shadow counts on every frame,
and checks stable program, geometry and texture counts. The resulting timings
are recorded in `creation-performance-animated-light-pressure-proof-v1.json`.
The cases actually lasted 80.95s and 66.40s. Unrobed 30-second-window medians
were 32.2 / 32.8 / 32.7ms; robed medians were 26.6 / 26.5 / 25.9ms (the final
window in each case is partial). Four unrobed and three robed settled frames
exceeded 50ms, with a worst frame of 58.5ms overall. Eight programs remain
stable in each case; geometry/texture counts remain 793/78 unrobed and 601/74
robed. All 4,800 frames retain the required 42/128/15 light counts. Each case
rotates through about 1,100 degrees. This run shows no progressive collapse
toward the original 106ms average; it does not explain or dismiss that report.

These are completed-frame measurements, not live FPS or isolated GPU timings.
The workload has homogeneous installed characters, synthetic extra lights and
camera positions, and no movement replication or gameplay collision. Every map
redrawing also differs from the original report's thirteen reused/two redrawn
maps. This is a stronger lighting/animation pressure check, not reproduction of
the full original 106ms frame or proof that dense-server loading, transitions,
physical input or exclusive fullscreen are fixed.

`scripts/verify-animated-light-pressure.mjs` checks actual reports and current
v15 source hashes. Historical v13/v14 hashes are frozen comparison evidence;
the fixture subsequently gained timeline/camera instrumentation. Earlier v12
ran the default small-to-large counts after an option-update command failed;
it is retained as exploratory evidence and is not pressure validation. The
earlier accepted v10/v11 skin comparison is preserved in checkpoint v33 and is
not rewritten against the later fixture.

The goal remains active. Additional varied live replication, transitions,
fullscreen and physical input acceptance remain separate, as do the 27 absent
portrait image sources and unavailable effect bitmaps. No remote connection is
needed or authorized for these checks.
