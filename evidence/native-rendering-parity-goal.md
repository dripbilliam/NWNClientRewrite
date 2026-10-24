# Native rendering parity goal

Created 2026-10-22 at the user's explicit request. Status: **active, incomplete**.
This is the current rendering architecture goal; earlier performance experiments
remain evidence, not accepted solutions.

## Outcome and boundaries

Reproduce the original client's verified rendering decisions, then remove work
the replacement performs unnecessarily. Broad renderer/backend changes are
authorized; JavaScript remains preferred. Preserve scene appearance, animation,
interaction, gameplay, networking and resource cleanup. Make verified source
checkpoints before substantial changes and at significant milestones.

Use the private captured room and owned local servers. Do not connect to or
interact with Arelith without renewed explicit authorization. Preserve user
sessions. Native binaries and the original Ghidra project remain read-only.

First acceptance target: sustained at least 60 FPS, p95 frame time at most
16.7 ms, and no multi-second client freezes in complete representative heavy
scenes. Then pursue the user's reported native 180–220 FPS using matched
workloads. The native number is user-reported, not our controlled measurement.
No FPS conversion from fenced submission microbenchmarks; no partial-room or
reduced-quality result counts as completion. The current replay's outer
content/viewport gate also needs resolution without weakening it.

## Evidence identity

Original: NWN:EE 89.8193.37-17, x86-64 `nwmain.exe`, SHA-256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Each new native rule must retain function address, caller instruction address,
validation source and remaining uncertainty. Pseudocode is analysis evidence,
not original source or proof of runtime cost.

## Initial crosswalk

| Work owner | Verified native evidence | Replacement state / next work |
|---|---|---|
| Frame/pass dispatch | Camera::RenderScene `0x14005a5d0`, scene dispatch `0x14005b208`; Scene::Render `0x1400cc730` dispatches RenderSinglePass `0x1400d0f10` at `0x1400ccdc9`. [Existing pipeline](rendering-pipeline.md). | Trace complete live/replay frame ownership, including UI, particles, lights, update and presentation; avoid measuring only the backend. |
| Visibility and collection | AddPartsToDrawBuckets `0x1400c38f0`, recursive AddPartsTreeToDrawBuckets `0x1400c4620`, IsPartRenderable and scene BSP work are mapped in part. Exact collection call sites and spatial admission/invalidation still need a fresh dossier. | `renderer_scene_plan.js` still scans members, checks per-mesh frusta, updates geometry and computes sorting position each frame. Audit tile/BSP visibility, bounds, LOD, keyholing and stale/changed membership before choosing a replacement. No native occlusion algorithm is assumed. |
| Draw buckets / face state | RenderDrawBucket `0x1400cd210`; first-item calls `0x1400cd621` and `0x1400cd69a` target GetFirstItem `0x1400d94f0`. At the latter it advances among three sublists and applies cull-state changes. Main-pass caller `0x1400d131b`; dynamic-geometry callers `0x1400ce298`, `0x1400ce2b6`. Retained REA dossier `backups/animations/rea-performance-draw-bucket-current.json`, evidence `ev_9cb4fee5f7abb56a1fbee9e133c16b18e9b842aa3563ed95e15eafd0504d3500`. | Map insertion/sorting/sublist semantics and state reuse. Current Three/Babylon paths retain per-item material/mesh work. Do not infer hardware instancing or material batching merely from the name "bucket". |
| Per-draw special state | Same function: SetModelMatrix call `0x1400cd721`; keyhole eligibility `0x1400cd8be`, dissolve setter `0x1400cd8c6`; temporary fog/opacity is restored after draw. Same dossier. | New persistent draw records must invalidate on pose, fade, dissolve, material, geometry and resource lifetime changes; transparent ordering must survive. |
| Light admission | GetNearestLights `0x14007f660`; per-position/radius SetupLightsForThisPositionAndRadius `0x140080f80`; RenderOnlyGobs light call `0x1400cfbca`. [Light evidence](renderer-light-selection.md). | Global focus admission is only partial parity. Configured maximum, separate static/dynamic owners, fade history, height plane and per-object candidate membership need closure. 128 is a ceiling, not a verified native default. |
| Shadows | GetShadowLights calls `0x1400d111b` / `0x1400d1135` select separate lists. RenderDynamicShadows `0x1400ce3a0`, volume submission `0x1400ce7aa`. [Shadow evidence](native-shadow-workload-comparison.md). | Native selection limits partly implemented; Three point maps still differ from native volume/projection passes. Map caster admission, cached/static projections, receiver rules and invalidation before replacing the technique. Native exact-room GPU counts remain unmeasured. |
| Vertex/material/GPU ownership | PartTriMesh::Draw `0x1400a24c0` → RenderFlat `0x1400a4710` → RenderVertexData `0x1400b59b0`; SetProgram call `0x1400b5ac0`. SetUniforms has changed-value caches; buffers are pooled. [Pipeline](rendering-pipeline.md). | Audit persistent geometry/program/material packets, state transitions and uploads. Preserve disposal/context recovery. Do not repeat rejected generic GL command replay or global light-buffer experiments as untested ideas. |
| Skin/animation/particles | ExecuteSkinGPU `0x1400deb90`, bone setter call `0x1400dee43`, 64-slot shader bone palette. Scene::Animate `0x1400c5210`; emitter lighting calls `0x1400d1c99`, `0x1400d1e57`, `0x140063092`. [Pipeline](rendering-pipeline.md). | Separate simulation, pose, palette, particle geometry and rendering costs. Compare changed owners and GPU skinning with our CPU work; maintain events, RNG, bounds and picking. Workers alone do not remove draw submission cost. |

## What recent measurements establish

The Babylon room trial is not faster and has not been promoted. In the same
1424×921, 2,796-draw admitted subset, unprofiled CPU submission medians were
11.143 ms for Three and 13.998 ms for Babylon. Full-game parity is false and
strict room pixels fail. See [trial evidence](babylon-renderer-trial.md).

A separate diagnostic profile of 120 Babylon frames identified about 4.13 ms
per frame in adapter update, 2.50 ms inclusive in active-mesh evaluation,
3.68 ms inclusive in ShaderMaterial.bind and 1.77 ms inclusive in
ShaderMaterial.isReady. Nested timings overlap. These establish repeated CPU
work in that prototype; they do not establish native GPU work or complete
game FPS. Source: `runtime-logs/performance-queue/babylon-profile-v2/cpu-summary-v2.json`.

## Execution order and acceptance

1. Close the native visibility/collection and draw-bucket evidence gaps; map
   producers, consumers, initialization, update/invalidation and cleanup.
2. Capture matched per-frame counts and timings: visited/admitted/culled
   owners, reasons, bucket populations, state changes, uploads, shadow work,
   particles, animation, CPU stages and GPU time where measurable.
3. Implement one evidence-backed structural change in isolation, with native
   arithmetic/control-flow checks where possible and full fidelity checks.
   Changed-only static work and native light/caster admission are priorities,
   subject to findings. The backend may be replaced when the measurements
   justify it.
4. Compare complete offline replay/local gameplay at fixed viewport, camera,
   content, settings and presentation. Check movement, transitions, effects,
   UI/picking, transparency, animated models, resource growth and cleanup.
5. Retain only verified gains. Document regressions and uncertainty. Continue
   until performance and visual/gameplay acceptance are actually achieved.

Baseline source checkpoint before this goal's architectural changes:
`backups/babylon-offline-trial-profiled-20261022.zip`, verified SHA-256
`b4d7b90ba84058ee5756e6d427ae92df24f2b14226ac41711d194e4cb0fb9c60`.
No production renderer change is claimed by creating this goal.

The initial retained evidence is reproducible with
`node scripts/audit-native-render-evidence.mjs`. It checks the native build
identity and records source-file hashes, function identities, call-site edges,
pseudocode and coverage limitations in
`runtime-logs/native-render-parity/retained-evidence-audit.json`.
Initial result: nine evidence records, eight function records, 233 outgoing
call edges. This is an evidence index, not a rendering-parity test.

One concrete implementation difference found during the initial crosswalk:
`main.js`'s `updateSkin` calls `deformSkinnedVertices` and `updateSkinnedMesh`.
The latter rewrites CPU positions/normals, marks vertex buffers for upload,
and recomputes a bounding sphere. The mapped native path supplies bone
matrices to its vertex shader. Moving skin deformation to the GPU is therefore
a native-backed architectural candidate. Its contribution to the heavy room's
total frame time still needs measurement; it is not assumed to explain the
entire gap, and picking/bounds/normals must remain correct.

Fresh Scene::Render analysis confirms ManageSceneBSP `0x1400db320` is called at
`0x1400ccb38`, frame uniform dirty-data update at `0x1400ccdb6`, and bucket
collection at `0x1400ccdbe`. The LightNodeMeshes/LightBins BSP traversals at
`0x1400cccf0` / `0x1400ccd06` are conditional on a change to
`g_bFullDynamicLighting`; they are not unconditional full-frame lighting walks.
Validation: `runtime-logs/native-render-parity/scene-render-dossier.json`, REA
evidence `ev_17ec38a8462fe63e54833099ba8a0936b20e0b67c55d26a0bda6bf049d07a6a8`.

Read-only settings inspection found `graphics.lighting.max-lights = 32` in
both Documents/Neverwinter Nights/settings.tml and
Documents/Neverwinter Nights.0/settings.tml; their schema also says default 32.
The executable's initialized data at `0x14128e588` is 32
(`rea-performance-max-light-initial-data-current.json`). The replacement's
global selection defaults to 128. This is a concrete configuration mismatch,
not proof of the original's live override or complete per-object rule. Simply
globally dropping to 32 could remove lights that native per-object/bin ownership
would retain, so admission needs mapping before promoting a lower limit.

## Fresh native collection and static-light findings

All functions below are from the pinned executable above, with retained
assembly and pseudocode under `runtime-logs/native-render-parity/`.

- ManageSceneBSP `0x1400db320` compares camera displacement against 0.3 and
  Scene::Sequence before setting a re-evaluation flag. That flag and changed
  cached positions gate part/Gob spatial updates. This is **not** a license to
  skip all rendering/culling while the camera is still: volume traversal still
  occurs. Dossier `manage-scene-bsp-dossier.json`, evidence
  `ev_09d80d9119302b831669f89420d3bae5e7a0578e74b2e20ff5ac6f593308b6a1`.
- Its call `0x1400dba72` enters BSPTraverseVolumeApprox `0x140229dc0`, passing
  camera position, the camera plane list and collection callback `0x1400dc140`.
  Traversal classifies node split polygons against planes, distributes the
  remaining plane lists to children, rejects excluded children and falls back
  to ordinary BSP traversal when no remaining plane tests are needed. This is
  hierarchical plane reduction, not established screen-space occlusion.
  Dossier `traverse-volume-dossier.json`, evidence
  `ev_efc35458ae38284c80ef29426391194188ae68dcec4dc450bb62437b1e189ce1`.
- The callback enters ProcessTriMeshParts `0x1400dc900` at `0x1400dc4c3`.
  Ordinary parts are tested with PartOutside `0x1400dbf30` before mesh-bucket
  insertion; fade-enabled tile branches have separate state. PartOutside
  tests stored AABBs against the plane list, starts with the last rejecting
  plane and rejects only on a **strict positive** BoxAbovePlane result.
  Touching a plane is retained. BoxAbovePlane `0x14022b350`, called at
  `0x1400dbf8c`, selects each AABB endpoint by the sign of its plane normal.
  Dossiers `bsp-collect-dossier.json`, `process-trimesh-parts-dossier.json`,
  `part-outside-dossier.json`, `box-above-plane-dossier.json`. The last-plane
  index is shared native state; do not mislabel it as a per-object cache.
- IsPartRenderable `0x1400a2eb0` is a visibility/model-render/vertex-data
  eligibility check, **not itself** a spatial frustum test. Caller
  `0x1400c3aeb` in AddPartsToDrawBuckets. Dossier
  `part-renderable-dossier.json`, evidence
  `ev_195f2606fe3da9fb947808e2b6a9ff86a62e9f2a1e7eba58ca1088af2473298d`.
- DoStaticLightBuckets `0x1400d9330`, called at `0x1400db76f`, processes a
  pending node list, calls LightNodeTile `0x1400da6c0` at `0x1400d941e`,
  conditionally relights bins when that list is nonempty, then clears the count.
  LightNodeTile selects overlapping non-dynamic lights for individual meshes
  and calls LightPartTriMesh `0x1400da970` at `0x1400da8ff`. Under
  `g_bFullDynamicLighting == 0`, LightPartTriMesh allocates/updates per-vertex
  color and optional static-light-direction pools; it does not leave all
  static lighting to an unconditional per-pixel world-light loop. Its pool
  ownership/rebuild/deletion branches are retained. Dossiers
  `static-light-buckets-dossier.json`, `light-node-tile-dossier.json`,
  `light-part-trimesh-dossier.json`. Determine what populates/invalidates the
  list, resolves the renderer quality setting and sets FullDynamicLighting
  before enabling this path in the replacement.

The two stored native settings profiles differ in shader quality: the ordinary
Documents profile says Performance; the `.0` profile says High Quality.
Neither file alone establishes which profile/options produced the reported
native FPS. The pinned Three 0.180 MeshLambert shader accumulates direct lights
in its fragment shader (`lights_fragment_begin`), as does the current Babylon
matching shader. Matching native shader quality/static-light ownership is thus
a priority investigation, not an already-proven explanation of the FPS gap.

The expanded evidence audit now covers 20 retained records, 19 function records
and 409 outgoing call edges. Eleven fresh compact dossiers preserve their
assembly, pseudocode, binary identity and limitations. The owned analysis
session was closed after saving; no game launch, server connection or GPU
benchmark occurred during this investigation pass. The user's temporary test
hold was subsequently lifted; [the written test plan](native-rendering-parity-test-plan.md)
records the latest authorization. Implementation and full-scene acceptance
remain outstanding.

2026-10-22 implementation trial: the conservative hierarchical visibility
candidate has been implemented and compared in the complete offline room.
37 CPU/measurement checks pass, and the independent non-MSAA color/shadow
comparison is exact. It is about 2.5% slower than the cooperative control
(21.2 versus 21.7–21.8 FPS), so it remains disabled. The default-framebuffer
and original recorded-partial-content gates remain failed. See
[the measured trial](native-spatial-visibility-trial.md). This shifts priority
to native static/dynamic shader and light ownership; a direct native
FullDynamicLighting writer has been located for the next trace.

2026-10-22 static investigation during the renewed **actual-tests hold**:
[the enhanced lighting method map](native-enhanced-lighting-policy.md) now
connects the option callbacks, shader prefix, light color/range upload and
runtime enabled-light count. Enhanced Lighting sets full-dynamic/gamma/fragment
lighting; shader quality is a separate parameter. Both saved native profiles
enable Enhanced Lighting, so the Performance name alone does not support a
static-baking explanation for the native speed advantage. The base enhanced
shader has finite light support; our current adapter implements the legacy
infinite-support curve. Native SetUniforms packs enabled slots and uploads their
actual count, rather than making the shader loop to unused capacity. These are
verified policy differences, **not measured performance improvements**.

The known per-Gob GetNearestLights call belongs to the mapped no-BSP branch;
it is not evidence of per-object light lists in the captured main BSP area.
Headlight reservations, fade ownership, exact enhanced uniform arithmetic,
active resource overrides and matched runtime settings still need validation.
The deferred test plan records those cases. No games, test suites, rendering
fixtures or benchmarks ran during this static pass; no production renderer
change or 60 FPS acceptance is claimed. Alpha/keyhole source-only candidates
prepared before the hold remain disabled, with GPU/full-room checks pending.

Static source follow-up found invalid finite-radius culling of legacy
negative-decay lights in the disabled point-buffer/packet and zero-work
experiments. Conservative guards are corrected; direct/packed regression cases
and a native-legacy GPU-fixture mode are written, all unexecuted under the
hold. Earlier authored passes do not validate these new sources. The ordinary
client and its last measured performance remain unchanged.

Continued held-test work mapped the native CPU color-power and four-component
material upload boundaries, plus unchanged-property generation behavior.
The base shader's signed texture/output conversion and independent material
ambient/diffuse weighting require separate handling from CPU light color.
A disconnected CPU light-upload preparation and seven deferred data-flow cases
are written; none have run and no runtime path is promoted. This prepares
enhanced finite-range lighting without assuming that a curve-only change
matches native pixels. See the expanded enhanced-lighting method map.

2026-10-22 testing resumed explicitly. The 55 focused CPU cases and 33 replay
guards passed. The native-legacy zero-work GPU fixture timed out at the
128-light step. The complete alpha/keyhole room v1 run loaded all canonical
content and had exact independent-target color/shadow pixels, but alpha
specialization was inactive; its timing acceptance correctly failed. Keyhole
repeat drift also prevents speedup inference. The compressed-alpha follow-up
passed 15 related CPU checks, but room v2 again failed activation and stopped
early. Neither experiment is promoted. The ordinary client is unchanged.

The user requested a proper native game engine and authorized a new top-level
folder. Native Godot work now lives in `godot-client/`. Its verified official
4.7.2 runtime loaded the captured world's 4,145 exported source-visible mesh
nodes and completed a 600-frame Vulkan diagnostic, averaging ~44.6 FPS with
35.607 ms p95. This is a frozen import with visibly different stock lighting
and particle blending and no gameplay/animation migration. It is not a matched
speedup comparison, fidelity acceptance or completion of this goal. See
`godot-client/STATUS.md` and `MIGRATION.md`; preserved failed transfers and test
reports remain available. No Arelith connection occurred. Continue the native
engine migration within the original complete-scene and quality requirements.

Latest clarification permits engine visual differences while keeping the same
textures and models. For the Godot migration, exact old-renderer framebuffer
matching is superseded by asset integrity (geometry/UVs/textures/appearances),
acceptable engine presentation and preserved gameplay/effect behavior. Missing
parts, broken blending and frozen animation remain defects. Keep the full
workload, sustained performance and resource-lifetime requirements in force.
