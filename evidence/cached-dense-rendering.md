# Cached dense rendering, 2026-10-20

This is an offline workload using the selected, previously downloaded server
collection plus the installed game. It makes no server connection and forbids
content fetches. It does not reconnect Arelith or reuse the original NWSync DB.
The current local gameplay client and both local server processes stay open.

A QA-only Vite transform appends an entry to the replacement application's
main module in memory. The production source and built application are not
changed by this benchmark. The entry calls the actual model source cache,
network asset decoder, texture decoder, buildObject, area-light setup,
RendererModelPreparation, light selection/capacity, shadow budget/traversal
and renderer callbacks. Filesystem watching and dependency discovery are
disabled. The hidden Electron window owns a separate scene and renderer.

The data-driven workload selects16 distinct ttr01 tiles and12 placeable models
from the active tables, placing64 tiles and24 placeables. These are synthetic
placements, not a captured live server area. It adds15 synthetic512-pixel
shadow lights and moves one placeable while the camera repeatedly orbits.
Actual area lighting is installed.197 successful resource demands comprise
166 selected-manifest resources (native location5) and31 installed resources
(location1). This includes downloaded MDLs and textures; no resource bytes are
written into evidence. HTTP attempts remain zero.

The final v5 observation lasts120004ms with7033 rendered frames at3100x1121.
After excluding the first two seconds,6922 completed-frame measurements have
a15.6ms median,20.3ms p95,23.5ms maximum and no >50ms hitches. The first30-second
window has15.6/20.2ms median/p95; the last has16.0/20.4ms. All measured frames
retain10 programs. Geometry and texture counts remain1062 and171. The view
submits950–1018 main draws,779 shadow draws and75–79 admitted real point lights;
all15 requested shadows are admitted. This does not reproduce progressive
slowdown in this bounded renderer workload.

Resource preparation took613ms, assembly58ms and shader preparation5961ms.
Shader/driver cache state is uncontrolled. These are current observations,
not a causal speedup ratio or fresh-system shader timings. Completed-frame
times include explicit gl.finish; hidden/offscreen scheduling is different
from interactive gameplay FPS. JS heap values are incidental GC observations,
not proof of a leak or its absence.

Asset/particle acceptance is explicitly incomplete. Twelve source models name
fxpa_cloud02; none of TGA/PLT/DDS/KTX/native16-bit catalogs contain that bitmap
in this context.48 instantiated emitter nodes fail for that missing bitmap.
The remaining24 emitters have no active particles in this tested model state.
The fixture executes production particle updates, but does not establish
particle-heavy performance, chunk-model ownership or correct destroyed-
furniture effects. It retains these warnings rather than accepting an overall
clean asset load. No fallback image or server-specific asset is hardcoded.

The production code was not changed by this renderer investigation. Character
animation, input/collision, replication, transitions, arbitrary custom models,
the earlier actual modded world, and exclusive OS fullscreen remain outside
this fixture. Physical WASD feedback and an additional source for33 missing
portrait rows are still pending. The overall goal stays active.

Reports: creation-performance-cached-dense-v4/v5.json and assertion-checked
creation-performance-cached-dense-proof-v1.json. The verifier hashes production
and fixture sources. The screenshot was visually checked for a visible textured
scene. Rejected v1 stalled during development-harness startup and was stopped
only after its PID/command were verified. Exploratory v2 lacked shadows and
particles; v3 lacked area sunlight. They are retained without treating their
timings as comparable before/after results. v4 is the short lit run; v5 is the
sustained lit run. The source checkpoint and independent restore-chain audit
preserve all scoped observations and limitations.


2026-10-20 active-effect follow-up: v7/v8 adds16 looping actual vce_positive/cessation models through the same production loader, animator and particle runtime. v8 runs120019ms at3100x1121. After2seconds,6942frames have14.6ms median/20.5ms p95/26.3ms maximum and zero >50ms frames. First30seconds14.5/20.1ms, last15.1/20.7ms: no progressive collapse in this window, not a controlled comparison with v5.48 authored effect emitters have zero failures,0..336 active particles and0..2016 submitted vertices;6531 settled frames have particles. Burst gaps are retained. Particle/animation work median2.4ms/p955.5ms.10programs,1110geometries and173textures stay stable.48 unrelated fxpa_cloud02 failures remain. No pixel-difference/original GPU or fill-rate equivalence claim; the screenshot is a dark textured synthetic scene with small effects, not a native visual match. Fixed1/60 simulation per rendered frame and explicit gl.finish remain fixture limitations. Character crowds, network replication, transitions and exclusive OS fullscreen are not validated. Assertion-checked active-dense-proof-v1 hashes the current fixture and metadata. No server joins or HTTP.
