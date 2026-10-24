# Native rendering parity: deferred test plan

2026-10-22 latest instruction: **“Okay, you can live test what you have so far.”**
This supersedes the previous testing hold. Use offline captured-room replay and
owned local servers only; no Arelith connections. Preserve user sessions.
The first 55 focused CPU cases passed, followed by 33 replay/measurement/bridge
checks. The legacy-light authored GPU fixture hit its 180-second deadline in
the candidate's 128-light topology step; no completed GPU parity result or
performance acceptance follows from that run. Private alpha/keyhole room
comparisons are next. Unexecuted cases below remain plans, not passing results.

The [active goal](native-rendering-parity-goal.md) defines fidelity and
performance acceptance. Existing exact authored checks and room failures remain
unchanged. The following cases specify the next comparisons; native behavior
must be mapped before filling an expected result, rather than deriving an
expectation from our implementation.

## Reference and workload gates

- Pin the original executable SHA-256, replacement source checkpoint, asset
  signatures, captured content, camera pose, viewport/drawing-buffer dimensions,
  resolution scale, quality, lights/shadows, presentation and warm-up policy.
- Run the original and replacement separately, without another game or analysis
  import competing for resources. Preserve user sessions and use owned local
  servers/offline replay. No Arelith access is authorized by this plan.
- Confirm full canonical inventory: 898 render-eligible objects, 1,077 models,
  1,357 emitters for the captured room. Retain the 700 pre-existing unsupported
  emitters as a documented limitation, not a newly accepted omission.
- Resolve the recorded final-frame partial-content/viewport mismatch explicitly;
  do not relax the outer acceptance gate. Count the exact visible and eligible
  content at each measured pose, rather than relying on global totals alone.

## Visibility, collection and invalidation

| Case | Operation | Required observations / acceptance |
|---|---|---|
| V1 Boundary crossing | Place a mesh bounds sphere/box just inside, touching and outside each view plane; repeat with translation, rotation and negative/nonuniform scale. | Native call-site/branch-derived decisions; conservative bounds must not drop visible vertices. Classify object-level versus part-level rejection. |
| V2 Parent changes | Toggle a transform-only ancestor, child visibility, layer mask and reparenting; add/remove a model after warm-up. | Membership changes once per effective mutation, hidden descendants do not draw, restored descendants return. No stale draw records or changed picking IDs. |
| V3 Spatial transitions | Move/rotate the camera through tile/bin boundaries, behind walls and around a doorway; open/close the door. | Native BSP/tile policy must be identified first. Record candidate bins, visited/admitted parts, rejection reasons and invalidation. No assumption that a wall implies occlusion. |
| V4 Animated bounds | Animate a limb/robe beyond the bind-pose bounds, attach equipment, change shape/scale and return. | Mesh remains visible, selectable and shadow-casting at the correct locations. Bounds are updated by the owning pose change, not indefinitely stale. |
| V5 View-dependent effects | Enter/leave keyhole range; change fade/opacity, LOD and material effect eligibility. | Match the native bucket/state decision and transparency order; no permanent state leaking from a previous draw/pass. |

Fresh static trace adds specific cases to V1/V3: strict-positive AABB/plane
rejection retains contact, the last rejecting plane is a shared search hint,
and child plane reduction must preserve the rejected/admitted set. Exercise
the camera displacement threshold immediately below/at/above 0.3 with unchanged
and changed Scene::Sequence. Camera rotation still requires fresh visibility
traversal; the movement threshold must not freeze the entire visible set.
Compare a plain all-plane oracle with the hierarchical candidate for identical
decisions, counting reduced tests separately from visible pixels/draws.

## Draw, lighting and GPU ownership

| Case | Operation | Required observations / acceptance |
|---|---|---|
| D1 Bucket ordering | Mix ordinary opaque/nonopaque meshes, tree parts, cap/fade meshes, special materials and front/back/two-sided geometry. | Derive bucket and sublist expectations from native insertion/consumption; record order, state changes and draws. Unknown numeric bucket meanings remain explicit. |
| D2 Persistent state | Render a static scene, then change only camera, one material parameter, one texture, one mesh pose and one draw range independently. | Uploads/rebuilds correspond to the changed owner. A cache must observe material mutation, resource replacement/disposal and context restoration. Same pixels and complete draw coverage. |
| L1 Per-object lights | Two separated objects with different overlapping light sets; static/dynamic and ambient-only lights, radius boundary, priority ties and configured limit. | Match native per-position/radius rules, configured ceiling, dynamic eligibility and fade ownership. Test actual shader work, not just total scene lights. |
| L2 Static invalidation | Keep the room still, move a light, change color/radius, animate/fade a light, move one receiver and change area lighting. | Only affected static/dynamic light ownership is rebuilt where native rules permit. Lighting remains visually correct during and after changes. |
| S1 Shadow ownership | Stationary/dynamic light with stationary/moving caster and receiver; caster enters/leaves range or view; door/equipment/shape changes. | Match mapped native caster/receiver admission and fade/static projection invalidation. Measure shadow passes/submissions/triangles separately from the main pass. |
| G1 Resource lifetime | Repeat area transitions and model/equipment swaps, dispose assets, recreate the graphics context and return to the room. | No stale GPU handles, missing models or unbounded resource growth. Rebuild legitimate lost resources and preserve source ownership. |

## Enhanced-lighting policy checks prepared during the test hold

These are deferred cases, not results. Follow the newly traced
[native settings/shader/light route](native-enhanced-lighting-policy.md).
Do not enable a candidate merely because its shader has fewer instructions.

| Case | Controlled variation | Required observations / acceptance |
|---|---|---|
| L3 Independent options | Set Enhanced Lighting off/on independently of Minimal, Performance and High Quality. | Check FullDynamicLighting and integer parameters 0/1/7 against their mapped callbacks. Record the actual native configuration and active shader resources; a preset name alone is insufficient. |
| L4 Enhanced cutoff | Receiver samples at squared distances just below, exactly at and just above the adjusted squared range; repeat with ambient-only and diffuse lights. | Native return uses a strict range comparison. Match zero/finite behavior at the boundary and the complete inside-range attenuation, color space, material and ambient terms. Keep the legacy path unchanged. |
| L5 Adjusted inputs | RGB maximum below/at/above 1; authored radius below/at/above 1000; independent multiplier, cutoff-range multiplier and fade changes. | Match the color normalization and radius bypass/multiplication order at SetLightGL call sites. Check signed squared range and float rounding. Include zero/invalid inputs through an explicit native oracle; do not invent sanitization rules. |
| L6 Uniform equations | Vary intensity-at-range, maximum intensity and cutoff multiplier one at a time under both gamma states. | Capture or execute the complete SetUniforms scalar/math boundary after testing is authorized. Resolve the unnamed power-like helper's ABI and rounding before assigning exact expected values. Shader helper-only agreement does not prove native uniform parity. |
| L7 Active-count transport | Keep capacity fixed while toggling enabled slots, including sparse holes and zero count; then change configured capacity separately. | Match native packing order and actual count. Verify removal/re-enable, light state generation, per-program first use, unchanged-generation reuse, force refresh and context recovery. Count array uploads and shader iterations. Preserve the Three shadow-sampler constant-index constraint. |
| L8 Separate improvements | Compare unchanged control, active-count-only, native-enhanced-equations-only, finite spatial selection and combinations. | Avoid bundling a faster transport with a different image. Each comparison has identical content and declared native/replacement visual references. Retain failed variants and include list-construction/upload CPU costs. Prior slower UBO/packet experiments remain prior evidence. |
| L9 Caller and fade ownership | Exercise ordinary BSP area, no-BSP model preview and dynamic geometry independently; switch admitted lights across the ceiling. | Verify which route owns each list. Retain fade-in/out histories, headlight reservations and unused slot disabling. The no-BSP per-Gob call is not an oracle for main-area per-object lists. |

Static review also corrected two disabled experiments' invalid finite-radius
rejection of negative-decay legacy lights. Two new cases in
`test/renderer-point-light-buffer.test.js` cover direct/packed selection and the
uploaded float32 snapshot. Run the existing zero-work GPU fixture in both its
ordinary mode and `runZeroLightWorkFixture({nativeLegacy:true})` after testing
is authorized. The legacy mode installs the actual model-light shader adapter,
so light beyond the authored radius must remain visible. All these new cases
now pass CPU regression checks. The native-legacy GPU run timed out at its
128-light step; earlier authored passes do not validate that GPU behavior.

The disconnected `native_light_upload.js` preparation adds seven passing CPU
cases in `test/native-light-upload.test.js`. First validate their boundary
data-flow cases. Verify their expectations against original-code owners:
RGB normalization,
radius1000 bypass, fade-before-power ordering, ambient range sign, CPU alpha
preservation, NaN comparison branches and float32 exponent/parameter roles.
The stub power callbacks establish only transport/data flow. They must not be
reported as tests of the original CRT's rounding or an actual rendered image.

Before an enhanced shader candidate is eligible for whole-room acceptance,
match CPU color conversion, shader texture/output conversion, independent
ambient/diffuse material colors, emissive/constant-light floor and gamma-specific
clamping. Compare negative/overbright/near-black inputs, fractional alpha,
fogged edges, texture formats, normal/specular/environment features and active
custom-shader overrides. Confirm that sampler/gamma format selection does not
apply the conversion twice. The ordinary Lambert/fog shader's order is not
assumed wrong merely because the native uses different transfer equations.

Prepared alpha/keyhole candidates need the following additional GPU checks;
their earlier 16 passing CPU cases predate the hold and do not cover these:

1. Compare color and shadow buffers for opaque-alpha specialization with every
   supported texture format, explicit mip level, cutoff/opacity transition,
   shared-material owner and source callback mutation. Unsupported/unknown
   alpha storage must retain the ordinary path. Compare after detach/dispose.
2. Compare inactive keyhole programs before/during/after camera eligibility,
   including multiple owners/passes, source material changes and custom hooks.
   Track actual compiled program keys, variant residency and first-use hitches;
   a runtime uniform of zero does not prove the discard code was compiled out.
3. Test candidates independently and together, with all scene content and the
   same camera/shadow state. Use the existing independent color/shadow target
   in addition to default framebuffer checks, preserving both failure gates.
4. Run the complete-room acceptance below only after correctness checks and
   complete the now-authorized runtime checks. Promote none on static evidence.

## GPU skinning candidate

The native path uses a 64-bone vertex-shader palette. The current replacement
deforms vertices/normals and rebuilds the bounding sphere on the CPU.

1. Use the existing original-code bone-matrix oracle, including nonidentity
   inverse bind, sparse slots, invalid/zero-weight entries, duplicate root-slot
   stopping behavior and the 64-slot boundary. Preserve native arithmetic rules.
2. Compare GPU-deformed positions against the oracle for all four influences,
   mixed weights and transformed model/skin roots. Declare a numerical tolerance
   based on the native/replacement arithmetic; do not hide pixels with it.
3. Compare lighting normals and tangents against the native shader rule. The
   current CPU flat-normal recomputation must not silently define native parity.
4. Verify robe/armor seams, equipment attachments, mounts, elemental shapes,
   shadows and highlight outlines across moving poses and negative scale.
5. Verify raycasts, selection, spell targeting and bounding boxes/spheres. CPU
   picking needs an explicit deformation/bounds strategy when rendered vertices
   are moved on the GPU; bind-pose-only picking is not acceptable.
6. Measure pose/palette evaluation, CPU vertex deformation, normal generation,
   bounds, buffer uploads, GPU draw time and whole-frame time separately. Include
   zero, one and many animated creatures. Do not claim a room win from a skin
   microbenchmark alone.

## Complete-room acceptance after candidate checks

Replay the same fixed camera sequence and local gameplay sequence on baseline
and candidate, including idle, rotation, WASD, interaction, open UI, spell/effect
bursts, shape/equipment changes and area exit/return. Separate cold preparation,
warm preparation and steady-state rendering. Retain image/content comparisons
and CPU/GPU stage/count diagnostics with frame-time distributions.

Report median, p95, worst frame and hitch counts over a sustained interval, plus
loading readiness and resource counts after repeated transitions. The first
performance target remains at least 60 FPS with p95 at most 16.7 ms and no
multi-second client freeze at matching visual quality. Native 180–220 FPS is a
reported comparison to reproduce under controlled matching conditions.

No candidate is promoted unless complete content, visual/gameplay behavior,
resource lifetime and full-frame performance pass together. A test cannot be
marked passed because its expected native behavior has not yet been mapped.
