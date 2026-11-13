'use strict';
// Source and retained-report audit only. No route flip, native tests, or compiler.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const pin = relative => {
  const bytes = fs.readFileSync(path.join(root, relative));
  return { relative, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') };
};
const read = relative => JSON.parse(fs.readFileSync(path.join(root, relative)));
const rig = read('.cache/native-render-gap/original/rig-residual/audit-a.json');
const sources = ['systems/model_rigs.gd', 'systems/model_native_animation.gd', 'systems/model_native_pose.gd', 'systems/model_runs.gd',
  'systems/native_data/actor_model.gd', 'systems/native_data/model_control_plan.gd', 'systems/native_render/actor_instance.gd',
  'systems/native_render/combat_rigs.gd', 'systems/combat_animation.gd', 'native/model_pose_storage.hpp',
  'tests/model_runs_test.gd', 'tests/native_animation_test.gd', 'tests/native_model_control_resources_test.gd',
  'tests/native_model_pose_compiled_resources_test.gd', 'tests/native_skeletal_pose_test.gd'];
const reportPaths = ['reports/model-runs-native-v4.json', 'reports/native-animation-graph-v3.json', 'reports/native-animation-graph-gpu-v2.json',
  'reports/native-model-pose-default-oracle-v1.json', 'reports/native-model-pose-compiled-resources-v1.json'];
const result = {
  version: 1, kind: 'actor-native-animation-route-feasibility-audit', createdUtc: new Date().toISOString(),
  conclusion: 'The small native_owner cohort is partly explicit routing policy, but a blanket actor route switch is blocked by missing inherited/controller capabilities and incomplete actor-facing API integration. Native run blending already exists. A transactional per-clip admission/selector and actor publication design are needed before any performance experiment.',
  scope: 'Source-only feasibility and retained-evidence review. No new native/GPU/FPS/compile test, no routing implementation, no installed source mutation. Historical component reports are not relabeled as a current sealed ordinary-actor route proof.',
  actualCoverage: {
    observed: 'Prior retained census reported7 native model owners/FxLight and zero native_owner-bound emitter owners in the heavy recording. This measures the route selected, not the availability of native metadata for all other assets.',
    source: 'ModelRigs._model creates AnimationPlayer for nonempty clips. native_owner is created only by play_native() or set_model_colour_scope(). Ordinary actor/combat/placeable calls use set_playback(). Explicit native callers include chunk/effect/door/visual-model routes.',
    unknown: 'No current-room per-model/per-requested-clip census of inheritedFrom, native controller-root availability, unsupported flags or transition complexity is present in the retained compact evidence. No proportion of actor clips is inferred.',
  },
  realBlockers: [
    {
      area: 'Inherited/supermodel and missing controller storage',
      evidence: 'ActorModel.native_animation returns no nativeAnimation if a physical node has no controller_storage. Binary clips with inheritedFrom OR empty controller_nodes receive an unavailable marker rather than a root. ASCII needs native_ascii_preparation.available; an unavailable ASCII preparation similarly supplies no usable clip roots.',
      distinction: 'ActorModel.rig_asset can still build ordinary AnimationPlayer tracks for these clips. A nativeAnimation Dictionary alone is not proof a requested clip is admissible.',
      resolution: 'Reconstruct the inherited/supermodel controller graph and original model selection, or retain a validated per-clip fallback. Census actual actor requests first.',
    },
    {
      area: 'Ordinary playback API ownership',
      evidence: 'set_playback()/set_animation() always call _play(), which drives AnimationPlayer. _update() chooses native_owner whenever that field exists and continues before the AnimationPlayer branch. Later ordinary combat/locomotion requests therefore do not automatically update the active native run owner.',
      distinction: 'This is an integration prerequisite; it is not evidence of an observed present FX regression. Existing explicit native callers use a different API.',
      resolution: 'One selector must own play/restart/speed/loop/side/follow/clip-length/playback-state and dispatch every request consistently to the selected route.',
    },
    {
      area: 'Nontransactional speculative admission',
      evidence: 'play_native() configures and assigns native_owner and stops model.player BEFORE calling native_owner.play(). The latter may return false for flags0x100 or a known clip without a native root. _update() still sees the attached owner.',
      distinction: 'A future try-native-then-ordinary fallback cannot just call this API and fall back on false. Configure can also initialize/publish physical Part state and private materials.',
      resolution: 'Validate the complete candidate graph/clip/capability and stage ownership before visible publication; commit owner/player handoff only after success, or provide a proven rollback preserving current pose, time, serial, events and materials.',
    },
    {
      area: 'Explicit unsupported native providers/solvers',
      evidence: 'ModelNativeAnimation.play rejects flags0x100 motion-run provider. ModelNativePose and native model_pose_storage diagnose animated-vertex flags0x80 as unavailable and dangly flags0x100 as unavailable. NativeAnimation providers use animationScale/playbackScale=1 and no-op updateRoot/periodicUpdate; _apply ignores motion context.',
      distinction: 'No claim that the current actor cohort requests each capability, or that the ordinary route already implements every missing native solver. These are capability boundaries to classify rather than silently suppress.',
      resolution: 'Admit only proven supported requests, map actual actor scaling/root/periodic policies, and keep unsupported routes explicit.',
    },
  ],
  presentCapabilitiesAndRemainingProof: [
    { capability: 'Blending and run scheduling', alreadyExists: 'model_runs supports ordered simultaneous runs, queue/reuse/current/remove flags, transitions and weights, reverse/loop/one-shot clocks and start/done/authored events. Historical authored graph exercised up to3 concurrent runs.', needsProof: 'Ordinary AnimationPlayer transition and reset behavior is not identical by construction to native ordered Part accumulation. Compare interrupted blends/restarts/reverse/time boundaries and mixed available/unavailable clips through the actual actor API.' },
    { capability: 'Multiple model pieces/side/follow maps', alreadyExists: 'ModelRigs entry retains models, source.parts, side_maps, clip_map, loop_map, follow, event_source and animated_models; NativePose binds a per-model physical Part graph to entry nodes.', needsProof: 'One actor request can affect several body/equipment pieces with different available clips. Preserve independent and follow=false pieces, event-source identity and current missing-clip policy without partial route commits.' },
    { capability: 'Manual poses/attachments/reference nodes', alreadyExists: 'Native manual Part60 state and descendant recursion exist. Both routes retain ModelRigs sync_attachments, external anchor lifetime/visibility, scale/rotation flags and shared skin publication.', needsProof: 'Equipment/reference/colour callback order, root placement, reparent/free/reentry and manual part suppression must remain exact. Native route admission must not reorder authored events relative to attachment/skin work.' },
    { capability: 'Materials/light/emitter controllers', alreadyExists: 'Native pose handles TRS plus trimesh colour/alpha/selfillumination, light fields and retained emitter fields. Colour-scope admission preserves held model time on its supported path. Native model storage retains weak node IDs/private materials.', needsProof: 'Ordinary track builder publishes TRS; switching to native Part publication can expose extra material/light/emitter state and clone active materials. Prove actor alpha/environment/colour scopes, native references and particle canonical clock handoff rather than treat all non-TRS output as free.' },
    { capability: 'Compiled arithmetic and retained Part state', alreadyExists: 'Windows native owner defaults enable prepared numeric controller plans, bulk hierarchy and NwnModelPoseStorage when prerequisites hold.', needsProof: 'Run scheduling and provider Callables are still GDScript. Native storage publishes Node3D position/quaternion/scale via3 ptrcalls per nonmanual part, and publishes per applied run. AnimationMixer already combines complete TRS into one set_transform. Native route is not automatically cheaper; a typed one-publication actor producer/consumer design may be required.' },
  ],
  retainedProofScope: reportPaths.map(relative => {
    const x = read(relative);
    return { ...pin(relative), passed: x.passed ?? x.success, checks: x.checks, scope: x.scope,
      resources: x.resources ? x.resources.map(r => ({ name: r.resource, clips: r.clips, parts: r.parts })) : undefined,
      frames: x.frames, maximumRuns: x.maximumRuns, gpuExecution: x.gpu_execution };
  }),
  proofLimitations: [
    'model-runs-native-v4 proves5296 scheduling/clock checks against retained native executions, not actor render/pose integration.',
    'Native authored graph reports385/502 checks across37 frames against original-derived ordered Part state, maximum3 runs; not full actor/effect/scene parity.',
    'Compiled-resource report60152 checks covers11 actual resources/68 admitted clips, including c_golstone42clips. Its reference and candidate BOTH use NativeAnimation and compiled controller arithmetic; it compares direct publishing/root hierarchy changes. It does not compare ordinary AnimationPlayer against native actor routing. The test skips clips without native roots.',
    'The18217 default-oracle report covers numeric Part/hierarchy/manual/rejected-input ownership; it explicitly excludes full scenes, actual original models, GPU pixels and performance.',
    'native_skeletal_pose_test compares ModelRigs against a separate Skeleton-based rig implementation, not the native_owner run/controller route. RigSkinPublisher ABI tests and particle59908 checks are not actor animation-route proof.',
    'These historical reports lack this audit\'s current-engine/process/source execution closure. Their scope and review-time hashes are retained honestly; no fresh PASS is claimed.',
  ],
  sampledCpuCeiling: {
    input: pin('.cache/native-render-gap/original/rig-residual/audit-a.json'),
    scope: 'DiagnosticV8 middle20seconds,5733 statistical main-thread RIP samples before combined particle/E changes. Fractions are an affected envelope, not current-combined exact times.',
    allModelRigs: { samples: 732, fraction: 732 / 5733 },
    update: { samples: 450, fraction: 450 / 5733 },
    retainedNativeSkin: { samples: 70, fraction: 70 / 5733 },
    retainedAttachments: { samples: 64, fraction: 64 / 5733 },
    metadataPlayback: { samples: 119, fraction: 119 / 5733 },
    interpretation: 'The450 _update samples (~7.85% of sampled main work) include more than AnimationPlayer; they are not all removable. Native skin/attachments/manual/event/publication work remains after migration. Even eliminating this entire impossible envelope gives only~8.5% ideal throughput gain in that diagnostic, not the missing100FPS. Eliminating all ModelRigs is also impossible; its12.77% envelope is not a savings forecast.',
  },
  decision: {
    recommended: 'Build an actor-facing transactional animation selector and immutable inherited controller plan first, retaining explicit fallback. Then evaluate a typed retained Part producer with one coherent per-model publication against existing AnimationPlayer; only after state/visual equivalence measure matched performance.',
    firstProofMatrix: ['Current actor request/asset capability census (per clip, inheritance and model piece)', 'Same clip/no-restart/speed/loop/side and follow semantics', 'Blend interruption/queued run/reverse/end/seek and event serial/sentinel order', 'One actor with body+equipment+external/reference attachments and colour/alpha changes', 'Manual root/child poses, particle canonical clock binding, skin deformation/shadows/picking', 'Missing inherited clip or unsupported request before/after owner handoff and atomic fallback', 'Callbacks/reentry/free/reparent/scope retirement and clean shutdown', 'Exact compiled branch use followed by repeated matched frame/FPS measurement'],
    prohibitedShortcut: 'Do not enable native_owner for every actor or infer eligibility from nativeAnimation being a Dictionary. Do not claim absent blending, all-other-assets unsupported, zero actor cost, or a guaranteed speedup.',
  },
  sourcePins: sources.map(pin),
  implementedChanges: [], newTests: [],
};
const output = '.cache/native-render-gap/original/actor-native-route-a.json';
fs.writeFileSync(path.join(root, output), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(pin(output)));
