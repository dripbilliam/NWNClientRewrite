# Dynamic GPU model preparation — 2026-10-19

Renderer cache work toward the active multiplayer goal. Original binaries and
server gameplay are unchanged. The installed native client/server build remains
NWN:EE89.8193.37-17; this browser-renderer change makes no new native API claim.

Sealed v127, after stable light counts and area cutaway preparation, still had
5.7/1.9/1.9s draw stalls as new program profiles appeared. New logical models
were instantiated immediately after CPU resources loaded, leaving linking to
the first draw.

RendererModelPreparation retains separate GPU-only templates and asynchronously
prepares color plus renderer depth/distance shadow variants. Shadow preparation
uses a private offscreen target with synchronous save/restore before yielding.
Template lights do not affect the live scene; prototypes never attach, create
ModelAnimators/particles, consume native RNG, allocate client object IDs or start
visual phases. Asset/palette owners retain templates to keep linked programs
alive. Native models still instantiate at their prior native boundaries.

NetworkScene.asset calls the optional preparation adapter for new AND cached
resources, including reference/effect assets. Main uses the existing area-entry
compile while the scene is unbound and prepares dynamic assets only in the
current attached network scene. Model building suppresses editor-only emitter
previews for templates so preparing cannot mutate texture caches or leak atlas
clones. Resources retire without destroying handles still polled by
compileAsync; late completion cannot publish readiness. Canonical world state,
uint32 IDs, uint64 effect IDs and server authority remain unchanged.

Primary implementation evidence: installed Three WebGLRenderer.compileAsync,
WebGLShadowMap.getDepthMaterial and its offscreen shadow output profile. This is
not an implementation of NWN per-object light selection or its shadow renderer.

Five preparation unit/integration cases cover coalescing, immutable resources,
color/shadow profiles, light/target restoration, late teardown/no instantiation,
profile changes, failure diagnostics and single release.175 focused rendering/
visual/projectile/reference/scene tests and buildv2 PASS.

Actual WebGL v2:1.76s async preparation with175event-loop heartbeats; real new
textured/alpha-tested model draw6ms; program count5before/after real draw;
unchanged live-scene pixels during preparation,35743changed image bytes when
model admitted, no shader/GL errors. Pixel image inspected. Synthetic scene
with real GPU/material/shadow code; live installed-model acceptance pending.
The first fixture failed because its hardcoded child count omitted the existing
neutral-light group; v2 compares the recorded baseline, with no production
change for that failure.

New light/shadow-count/material-feature changes can still require other shader
profiles. KHR_parallel_shader_compile was available in this GPU check; behavior
without that extension, native per-object lighting and full shared combat/audio
remain open. No full multiplayer completion claim.

During live v129 (initial preparation build),47installed templates loaded with
zero preparation errors or >1s startup draws. The native Aribeth ambush added
four mages and grew to84templates/87profile preparations with no failed resource
preparation. Academy NPCs killed all mages before a player attack; no player or
shared victory is claimed. A stale QA target probe was rejected, retained and
replaced. Later one1.7s draw coincided with a new program; its precise cause is
not proven. Native quest dialogue granted Aribeth's Key, displayed in actual
inventory; native UI equipped the installed crossbow and99bolts.

Source now sets the emitter's static twosidedtex material flag at construction,
matching its existing first-simulation material state before GPU preparation.
Preparation also retains both opaque/transparent color profiles for later model
fades, without playing native animation/simulation. Real GPU v4 includes the
two-sided particle material and a later opacity-profile change:3.59s async with
358event-loop heartbeats,6.1ms first draw,8programs before/after actual draw
and no new program for the fade; unchanged scene pixels during preparation and
no shader/GL errors.190 focused tests and buildv5 pass. These refinements are
not yet live accepted; v129 runs the earlier preparation build.

Later v129 completed native Aribeth dialogue and key-operated C->B->D doors.
One production IPC combat.attack request then yielded two native player hits
and11Physical damage each against weak goblins, followed by target removal;
server automatic retargeting handled the second enemy. Two wambo_001 projectile
lifecycles loaded/impacted/destroyed with no projectile failures. This is basic
hostile combat evidence, not active concurrent original-client shared combat or
proof of every attack/death animation. Equipped bolt stack remains99 in sampled
replication; do not claim ammunition decrement. Physical canvas attack picking
was not used for this check. Compact quest/combat snapshots preserve the facts.

Camera distance was1.18 after entry and normal wheel zoom restored4.21. No new
camera workaround was added. Native controller field128/3 blocked area visual253;
the general selfillumcolor fix and its validation are documented separately in
model-selfillum-controller.md. Native Type12 visuals, packet40, audio, per-object
lighting and full shared gameplay remain open. Full goal ACTIVE.

After sealing v129, visual inspection found the final chambers screenshot blank.
The report has10 shader-uniform overflow errors at230point lights. Zero GPU
preparation exceptions did not imply successful shader links or area rendering.
The follow-up admission work and its explicit native limits are recorded in
renderer-light-selection.md. Do not claim D-area visual acceptance from v129.
