'use strict';
// Retained evidence only. Never launches a client, compiler, profiler, or Ghidra.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const rel = p => p.replaceAll('\\', '/');
const read = p => JSON.parse(fs.readFileSync(path.join(root, p)));
const pin = p => {
  const b = fs.readFileSync(path.join(root, p));
  return { file: rel(p), bytes: b.length, sha256: crypto.createHash('sha256').update(b).digest('hex') };
};
const evidencePaths = {
  nativeChain: '.cache/native-render-gap/original/flow-map-final.json',
  nativeReview: '.cache/native-render-gap/original/render-chain-review.json',
  nativeGates: '.cache/native-render-gap/original/admission-chain/native-gob-clock-gates-b.json',
  nativeLightInstruction: '.cache/native-render-gap/original/admission-chain/light-exemption-instructions-a.json',
  nativeLightLifetime: '.cache/native-render-gap/original/admission-chain/light-lifetime-instructions-a.json',
  nativeChunkRadius: '.cache/native-render-gap/original/chunk-childless-radius-a.json',
  pacingV5: '.cache/native-render-gap/analysis/render-gap-sample-control-v5-a-a.pacing.json',
  pacingFullA: '.cache/native-render-gap/analysis/render-gap-hot-full-v7-b-a.pacing.json',
  pacingFullB: '.cache/native-render-gap/analysis/render-gap-hot-full-v7-b-b.pacing.json',
  visibilitySteady: '.cache/native-render-gap/analysis/full-v7-steady-features-a.json',
  scriptMiddle20: '.cache/native-render-gap/original/frame-pacing/rip-script-v8-a/script-annotation-middle20-b.json',
  sourcePoseAudit: '.cache/native-render-gap/original/pose-segments/audit-a.json',
  rigAudit: '.cache/native-render-gap/original/rig-residual/audit-a.json',
  keyCensus: '.cache/native-render-gap/particles/key-survey-b/render-gap-key-count-v7-a-a.analysis.json',
  corePlacement: '.cache/native-render-gap/particles/core-survey-a/render-gap-core-placement-v7-a-a.analysis.json',
  normalC: '.cache/native-render-gap/scene/normal-integration-c/manifest.json',
  normalLocal: '.cache/native-render-gap/original/local-authority/j/acceptance.json',
  combinedFunctional: '.cache/native-render-gap/particles/combined-b/review-a.json',
  combinedComparison: '.cache/native-render-gap/queues/particle-combined-abba-a/comparison.json',
  ob3Functional: '.cache/native-render-gap/particles/combined-ob3-b/review-a.json',
  lightEFunctional: '.cache/native-render-gap/scene/light-member-acceptance-c-a/acceptance.json',
};
const evidence = Object.fromEntries(Object.entries(evidencePaths).map(([name, p]) => [name, pin(p)]));
const chain = read(evidencePaths.nativeChain);
const review = read(evidencePaths.nativeReview);
const c = read(evidencePaths.normalC);
const compare = read(evidencePaths.combinedComparison);
const vis = read(evidencePaths.visibilitySteady);
const scripts = read(evidencePaths.scriptMiddle20);
const pose = read(evidencePaths.sourcePoseAudit);
const rigs = read(evidencePaths.rigAudit);
const pacing = [evidencePaths.pacingV5, evidencePaths.pacingFullA, evidencePaths.pacingFullB].map(p => {
  const x = read(p);
  return {
    run: x.run, evidence: p, steady: x.steady, detailedProfiling: x.detailedProfiling,
    frames: x.main.totalMs.count, frameIntervalMs: x.main.intervalMs.mean,
    mainProcessMs: x.main.processMs.mean, mainCpuBusyFraction: x.main.cpu.busyFraction,
    syncMs: x.main.syncMs.mean, pacingDelayMs: x.main.delayMs.mean,
    renderWallMs: x.render.totalMs.mean, renderCpuBusyFraction: x.render.cpu.busyFraction,
    renderSetupMs: x.render.setupMs.mean,
    scope: 'Own-thread wall spans and coarse 120-frame CPU windows; main and RT overlap. This is not a GPU-duration measurement or a fresh benchmark.',
  };
});
const artifact = {
  version: 1,
  kind: 'remaining-render-gap-evidence-synthesis',
  createdUtc: new Date().toISOString(),
  scope: 'Read-only synthesis of retained evidence as of 2026-11-08 approximately18:55UTC. No new benchmark, compilation, Ghidra import, source mutation or FPS acceptance. Root owns later candidate results and final promotion.',
  conclusion: 'The remaining ceiling is predominantly serialized CPU work on the main thread. The strongest larger opportunity is to retain more domain state and reproduce original admission/animation ownership, rather than infer a GPU limit or blindly suppress visible work. The full original-client FPS gap is not closed or causally apportioned.',
  identity: {
    original: review.original,
    canonicalNativeSnapshot: review.snapshot,
    canonicalNativeProjection: review.projection,
    currentInstalledSource: '4553daad7d614e5d9f6e353be56df6356aa717d9c220c491e5c9af6e103a3e12',
    currentInstalledBundle: c.normal.renderCore,
    currentRoute: 'ParticleStreamGroup -> NwnParticlePresentation::Owner::frame -> Step::advance; the older ParticleFrameGroup route is not the measured active route.',
    combinedParticle: 'Private combined-b DLL485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d; root accepted repeated performance evidence and is preparing normal integrationD. Not substituted into this report\'s installedC identity.',
  },
  measured: {
    pacing,
    interpretation: [
      '75bc/HotC full quiet tail900: main7.77–7.88ms,99.29–99.56% of one core; RT3.15–3.20ms,~41.4% CPU. Main sync~2us and frame delay<1us do not explain the ceiling.',
      'The renderer already runs on a separate thread. Main saturation and idle capacity on other cores coexist. Main+RT+GPU times are overlapping spans, not an additive frame budget.',
      'Historical e623 manual GPU windows were about3.5–4.7ms and were not matched against the original binary. No current75bc/combined GPU time is inferred from those older windows or from RT wall time.',
      'All91 entry snapshots in the retained CPU24 diagnostic used Windows EfficiencyClass1; there is no observed E-class placement at those sample instants. Continuous residency and focused-vs-unfocused policy effects were not established.',
    ],
    scriptOwnerTrace: {
      engine: 'DiagnosticV8 c5d691c4878577551c35fceed7054b618a8262b7b3adbe542a8f6160978af278; HotMappedC DLLdee6. Trace predates combined resident/empty optimizations and E candidates.',
      denominator: 5733,
      owners: scripts.bySource.slice(0, 8).map(x => ({ source: x.source, samples: x.count, fraction: x.fraction })),
      scope: 'Middle20seconds statistical RIP samples, assigned to the innermost active GDScript caller, including native leaves called by it. Not full/inclusive stacks, exact timings, or current-combined fractions.',
    },
    combinedMatchedReplay: {
      controls: compare.control,
      candidates: compare.candidate,
      delta: compare.delta,
      caveat: 'Serialized same-DLL legacy-vs-both ABBA: +6.38% recorded-input median FPS, +1.96% quiet median FPS,0.2969ms mean steady tick saving. The comparison artifact leaves saved-view review separate; root owns final visual acceptance. Not an original-client comparison.',
    },
    visibility: {
      frames: vis.frames, elapsedMs: vis.elapsedMs, delta: vis.visibility.delta,
      implication: '15,278,443 queries were cache hits with zero new invalidations/misses/walks in this steady window. Loading-lifetime invalidation counts do not justify further quiet-frame epoch optimization.',
    },
  },
  originalChain: [
    { stage: 'Main/pacing/present', proof: 'SDL_main046340 -> Update0448b0 -> client06db800 -> GUI update/render; Update calls limiter041ac0 then final RenderInterface/GL swap0bb640. Limiter sleeps only for a positive active cap; GL swap calls SDL_GL_SwapWindow and resets render state. No native60Hz-only scene-tick conclusion.', uncertainty: 'Static original code establishes ordering, not native runtime costs or actual driver waits.' },
    { stage: 'Model/Gob animation', proof: 'Scene Animate0c5210 traverses registered Gobs. Gob Animate04dbd0 has a per-scene-sequence guard, outer animation policy, pre-gate bookkeeping/wind/hook, then prior-view/f0/effect eligibility before clocks/hierarchy/events. Skipped inner-gate time does not accumulate/catch up.', uncertainty: 'Base-vtable bindings remain conditional for subclass dynamic types. ForceAnimated does not bypass the inner view gate.' },
    { stage: 'Retained controller/bounds state', proof: 'Emitter InternalControl052400 samples controllers directly into retained Part fields then CalculateRadius061710 before current collection. AnimateParticles061210 consumes retained fields and does not perform another channel sample.', uncertainty: 'This does not mean the measured current cohort samples channels twice: actual target native_owner emitter coverage is zero.' },
    { stage: 'BSP/admission', proof: 'Scene Render0cc730 -> ManageSceneBSP0db320 updates fit on refresh/changed center, resets reused typed bucket counts, traverses current frustum BSP leaves; collector0dc140 uses current transform, stored radius+0x20c and cached rejecting plane. Current in-view bits are recomputed after scene animation.', uncertainty: 'Current emitter sphere admission is not an exact prior-view whole-Gob state. Dynamic radius/child/scale/effect and lifetime semantics must be reproduced before skipping earlier work.' },
    { stage: 'Materials/geometry/skin', proof: 'AddPartsToDrawBuckets0c38f0 visits admitted Gobs and constructs reused typed/material buckets. ProcessGob093b10 lazily refreshes tree geometry flags. Per-Part static/rigid draws reuse shared VertexDataObjects. Renderable skins gather bones per admitted primitive and emit up to64 mapped GPU matrices.', uncertainty: 'Native still has Part trees, per-Part draws and per-mesh bone gathering. A Godot-node-vs-server-entity count alone does not prove duplicated rendering or a native whole-rig palette.' },
    { stage: 'Lights/shadows/submission', proof: 'RenderSinglePass0d0f10 consumes opaque/dynamic/fade/shadow/water/additive/beam stages before admitted emitter simulation/sort/draw. GL submission retains buffers, skips identical program binds and versions uniform state. Native stencil-volume shadow ranges differ from Godot shadow-map preparation.', uncertainty: 'Different shadow architecture is a possible future quality-sensitive project, not proof that shadows cost the missing100FPS.' },
  ],
  coveredAndRemaining: [
    { topic: 'Native scene boundaries', current: 'All1829 target emitters are fast native owners, including670 chunks. POD direct scene boundary, retained known parameter locations, setup binding and native stream geometry already exist. No per-emitter grouped fallback tick is present in this cohort.', remaining: 'Each registered owner still reaches pre-admission eligibility/clock/controller/live pose work; the original hierarchy/BSP ownership may admit less work before these boundaries.' },
    { topic: 'Chunk admission', current: 'Bounded unchanged-original CalculateRadius instruction proof and childless semantic fixture exist. Private childless admission rejected301 additional zero-active chunks; all670 chunks had zero active particles/no allocated child models in that diagnostic.', remaining: 'That experiment showed no FPS win and does not remove earlier setup. It is not a selected normalC flag and does not justify clipping unknown live children or caching hypothetical bounds as original BSP state.' },
    { topic: 'Gob light exemption', current: 'Known constructors initialize Gob+0xf0=0 and set it1 when an owning light has isdynamic/nDynamicType(+0x100) or affectdynamic(+0x104); both model defaults1. Tested leaf destruction does not clear the latch.', remaining: 'Rendered/admitted/budgeted/current live lights do not reconstruct construction history. Need original Gob-vs-appended/reference-part ownership, primary classification and additional producer/clearer coverage.' },
    { topic: 'Dirty render setup', current: 'Actual original dirty probe located~1.34ms pair rebuilding, not generic shadow/BVH guesswork.75bc selects exact pair-record reuse, consumer-filtered Forward+ light relations plus layer correctness fix, native skin publication and stable Skeleton force-pass reuse.', remaining: 'Earlier250 dirty AABBs were LOCAL equality; they did not establish all transformed-world bounds equal. Only4 pure-bone unchanged-world pair candidates were known. Most ordinary-part transforms actually changed; whole-skeleton upload buffers each contained changed bones.' },
    { topic: 'Remaining dynamic value work', current: 'Precombined script trace: particle stream32.67%, light registry13.62%, ModelRigs12.77%. Key survey found many fixed-slot and clip-map accesses; combined removes the common empty-clip lookup and text-copy costs. E member-index experiment alone was inconclusive in root\'s5-run queue.', remaining: 'These fractions are affected envelopes, not savings. More index/slot specialization needs an actual remaining lookup census; existing known-key fast bindings already have essentially zero private-map fallback.' },
  ],
  nextArchitecture: [
    {
      priority: 1,
      proposal: 'Retain a typed Gob/model/Part admission graph with original animation ownership and stable spatial membership.',
      rationale: 'It can remove work before per-emitter boundaries and ordinary offscreen animation evaluation, instead of only making each generic call cheaper. It follows a concrete native architectural difference and the particle/rig main-thread envelopes.',
      proofRequired: ['Exact model-piece/reference/attachment Gob mapping and effect classification', 'Complete f0 lifetime producers/clearers and authored mutation behavior', 'Previous-view update order plus pre-gate bookkeeping/event/no-catchup oracle', 'Conservative dynamic emitter bounds, radius invalidation, camera-reentry and child creation/removal tests', 'Measure admitted/evaluated counts and unchanged image/state before any FPS claim'],
      status: 'Larger high-value research target; not currently safe to enable blanket offscreen skipping or promise an amount of improvement.',
    },
    {
      priority: 2,
      proposal: 'Move remaining domain state publication through validated typed owners and numeric slots, with explicit observable mutation boundaries.',
      rationale: 'Sampled main-thread work still includes Dictionary/Variant/row ownership. The accepted combined experiment proves some overhead is real. Preserve live values while reducing name lookup/copy/control-container churn.',
      proofRequired: ['Actual postcombined census; do not re-optimize removed empty-map work', 'Alias/readonly/reentry/destruction/thread oracles, generation and scope checks', 'No stale value cache across callbacks, implicit last-reference destruction or external scene writes', 'Matched repeated performance and visual tests; root E/index results warn that fewer lookups need not improve FPS'],
      status: 'Current E/normal-binding/Ob3/pure-feats candidates remain independently selected and measured by root; this report accepts none automatically.',
    },
    {
      priority: 3,
      proposal: 'After immutable numeric snapshots exist, parallelize only measured pure evaluation and return deterministic ordered publication.',
      rationale: 'Main CPU saturation leaves core capacity, but Godot node reads/writes, arbitrary Callables, RNG/order, errors and RefCounted callbacks are not safe worker work by default.',
      proofRequired: ['Find a sufficiently large remaining pure numeric span after current optimizations', 'Snapshot ownership/generation/lifetime, deterministic random consumption and callback order', 'Bounded workers, cancellation on scope retirement, main-thread publication and clean shutdown', 'Prove scheduling/snapshot cost is smaller than the saved main work'],
      status: 'Parallelism is a follow-on design, not a blanket thread-pool wrapper around the current1829-owner loop.',
    },
  ],
  rejectedShortcuts: [
    'Do not add main+RT+GPU durations or claim low whole-machine usage means a frame cap.',
    'Do not claim44k Godot nodes versus1918 entities proves44k duplicated native objects; native Gobs also own Part trees.',
    'Do not equate the user\'s reported original170–200FPS with a matched captured native benchmark. Same resolution/preferences is necessary but does not fix focus/view/population/time/settings and workload differences.',
    'Do not use current admitted lights to infer f0, pause all offscreen clocks, accumulate skipped time, or let ForceAnimated bypass the proven inner gate.',
    'Do not implement a Part->emitter resampling bridge as the busy recording fix: measured native_owner coverage0.',
    'Do not globally snapshot source transforms:953 shared sources/1829 unique poses yields only876 ideal redundant reads of3658; callbacks and implicit destructors can mutate/free/reparent. Conversion cache already had36.7million hits/3678 conversions.',
    'Do not eliminate all rig skin/attachment work from the12.77% script fraction. Outside_update282samples include required skin70 and attachments64; clip/play metadata119samples is only2.08% of the sampled main thread.',
    'Do not enable arbitrary transform/skeleton setter skips, world-bound pair skips, faster floating-point reassociation, lower visible effect density, weaker shadows or unproven ISA changes to manufacture parity.',
  ],
  originalComparisonLimit: {
    userObservation: 'Original frame limiter disabled: approximately200FPS Hub and170–200FPS in the heavy recorded area.',
    mathematicalBudgetOnly: '170–200FPS corresponds to5.88–5.00ms per displayed frame. That is a target budget, not an exact measured differential with any specific replay result.',
    requiredMatchedProof: 'Capture exact original executable/settings, camera/FOV/resolution, focused/background state, world population/animation state, elapsed settled window, frame pacing and simultaneous CPU/GPU measurements under matched conditions. Do not subtract different sessions to assign the missing time to a subsystem.',
  },
  evidence,
  changeLog: { mainMutations: [], newRuntimeTests: [], originalBinaryModifications: [], newGhidraSessions: [] },
};
const out = path.join(root, '.cache/native-render-gap/original/remaining-gap-a.json');
fs.writeFileSync(out, JSON.stringify(artifact, null, 2) + '\n');
console.log(JSON.stringify({ file: out, ...pin(path.relative(root, out)), successful: true, evidenceFiles: Object.keys(evidence).length }));
