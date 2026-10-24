# Native renderer comparison and performance work — 2026-10-19

Ghidra12.1.4 read-only REA MCP session confirms the installed nwmain.exe SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
No original executable/project/server/client was modified.

Fresh complete dossiers: GetNearestLights14007f660 filters active dynamic/
affect-dynamic lights by object position/radius and configured m_nMaxLights,
bounded at128.128 is NOT asserted to be the native default. SetupLightsForThis-
PositionAndRadius140080f80 constructs per-position candidates using adjusted
radius. GetShadowLights14007f840 uses m_nMaxShadowLights, shadow radius/distance,
and mode-specific filtering; mode1 stops after the first admitted dynamic light.
numbershadowlights1400812f0 changes that configured limit; no default inferred.

RenderDynamicShadows1400ce3a0 requests vs_shadowvol/fs_shadowvol and configures
separate stencil operations before consuming draw buckets0xD/0xC/0xB/0xE. This
inspected dynamic-shadow path is materially different from our Three cubemaps.
Full native static/dynamic shadow/light/bucket fidelity remains open. We do not
reduce light/shadow counts based on an inferred native quality setting.

User's live160 profile shows expensive WebGLBindingStates checks (many shadow
draws), sampler-budget material scanning, and hierarchy traversals. Typical
stage samples:9ms render submission,9ms camera/light setup,3ms particles;
about1700-1900 shadow draws and30-40FPS. Not a GPU-timer measurement.

Changes preserve the current rendered result:

* Sampler budget caches material field schemas while counting current maps and
  custom sampler arrays live. It observes null-map replacement, version changes,
  uniform growth and environment reservations. Isolated2600-material/40-pass
  CPU scan135.35ms ->38.96ms with identical104000 texture counts. No live FPS
  improvement is implied by that microbenchmark.
* Compact point-light GLSL preserves light order/math and constant sampler
  indexing for shadows, avoiding full expansion of unshadowed lighting code.
  GPUv2 tests0/1/6/128 lights and0/2/15 shadows with native attenuation/ambient-
  only lights: all five images byte-identical, zero GL errors.128/15 cold color
  compilation6988ms ->4186ms on this run; compile latency is not eliminated.
* Point shadow output reuses maps only when current light/caster inputs match:
  world pose, geometry/index/UV/bounds/groups, visibility/layers, material and
  texture state, target disposal, projection and explicit updates. Unsupported
  skinning/instancing/morphs/custom hooks/materials stay live. CPU-deformed meshes
  invalidate via attribute versions. Scene changes and context restoration retire
  stale records; explicit global clipping retains live draws.

GPU shadow cache fixture has separate reference and optimized shadow targets,
so a reference draw cannot silently repair a stale cached map. All14 image and
six-map comparisons are BYTE-IDENTICAL across motion, hiding/showing, texture
alpha, geometry deformation, moving/recoloring light, removal/addition,
reparenting and target disposal. Static maps:147draws ->0 (6reused); moving
caster:51draws/4reused; color-only light change:0draws/6reused. No resolution,
texture size, source light, caster or shadow admission is dropped.

37 focused regressions/buildv2 PASS, plus10 shadow/cache/restore regressions
after the context-owner reattachment test. Cache GPU screenshot inspected.
The v161 rollout was REJECTED for performance: the user measured9.4FPS,
106.5ms average frames and94.7ms render submission at3100x1121, with19 cached
programs, no pending assets/shaders,13 reused maps and2 drawn. Pixel-equivalent
fixtures were insufficient to establish live performance. The compact loop is
now disconnected from production again; its source remains an experiment.
The captured v161 CPU profile was taken while covered/throttled (mostly idle),
so it cannot assign the foreground regression to a particular helper.

The v162 rollback joined a fresh campaign starting room, then the100-tile
m0q1b. Its foreground profile shows redundant full hierarchy traversals, world
matrix updates and per-draw keyhole subtree bounds. It is NOT a controlled
same-area comparison with the user's144-tile m0q1d report. Its later m0q1b
measurements varied roughly24-40FPS. No claim of resolving the original drop.
One harness-only failed action used `talk` instead of `conversation.start`;
the failure was retained and recovered. No production interaction change.

Recovery build DxxWQSWr removes two of the three lighting hierarchy walks by
sharing fresh visible light/material membership among selection, shadow budget
and slot budgeting. Layer/shadow changes remain live between those stages.
Particle collision matrices refresh on the first actual collision request each
frame, rather than for every frame with no consumer. Ordinary leaf keyhole
bounds use the world matrix already updated by the renderer; skinned/subtree/
custom-hook paths retain the original query.40 changing poses including negative
scales match the prior bbox/native gates without repeated ancestor updates.

Transitions now detach logical objects immediately but retain outgoing renderer
resource/program owners through incoming area compilation and first object
preparation. Cleanup runs on completion/failure/disconnect. This avoids throwing
away reusable linked shaders before the next area can acquire them; it does not
eliminate cold compilation for genuinely new profiles. v162 logged8532ms area
compilation and16053ms later door preparation. Live transition improvement is
initially pending.43 focused regressions and build PASS. Installed native keyhole
GPU fixture PASS (red wall center250/0/0 -> revealed player0/255/0); v1 desktop
capture was blank, so v2 captures the real WebGL canvas and was inspected.

Sealed v161:99136417bytes, SHA256
5fd68c9f4aff0c3365bfe07cf64e6649b354ada7ac619ec26358456d82b54115.
Sealed v162:231812949bytes, SHA256
f557398d2ea48461829c2c569ead5c2cfe0d831c133572fe0e2b9505445e2bec.
Both closed normally. v163 is open and must be excluded from checkpoints.
Live v163 repeated ordinary door transitions m0q1a -> m0q1b -> m0q1a -> m0q1b.
First new128-light profile:9129ms area compilation and17967ms door preparation
(still unacceptable). Return area:20.7ms compilation. Repeat100-tile academy:
139.4ms compilation and no asset preparation over100ms. Afterward129 template
creations/102 destroyed/27 active (same active count as the first academy visit),
no pending assets/shaders, no failed objects/preparations or runtime errors.
This proves shader reuse on those warm transitions, NOT fast cold transitions.
Latest large-area FPS27.2 with15.8ms render submission; camera/lights11ms and
particles4.8ms remain costly. The original144-tile/9FPS view is still unverified.
Do not describe steady-state performance as fixed or claim a controlled FPS gain.
The broad multiplayer objective is unfinished; get_goal currently reports
usageLimited. This explicit performance/transition repair task continues.
