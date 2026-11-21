// Compare complete, same-source original-localhost scenes. Release runtime
// selection changes no particle/animation/state algorithm or rendering option.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';

const home = path.resolve('godot-client/reports');
const evidence = [];
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
async function read(file) {
  const bytes = await fs.readFile(path.join(home, file));
  evidence.push({file, sha256: hash(bytes)});
  return JSON.parse(bytes);
}
function distribution(rows, key) {
  const values = rows.map(row => Number(row[key])).sort((a, b) => a - b);
  assert.ok(values.length && values.every(Number.isFinite), key);
  return {
    samples: values.length, mean: values.reduce((sum, value) => sum + value, 0) / values.length,
    p95: values[Math.ceil(values.length * .95) - 1],
    p99: values[Math.ceil(values.length * .99) - 1], max: values.at(-1),
    available: key !== 'memory_static_bytes' || values.some(value => value > 0),
  };
}
const fields = ['wall_ms', 'actor_animation', 'callback_rigs', 'callback_effects',
  'effect_selection_total', 'effect_selection_setup', 'effect_selection_core',
  'callback_particles', 'render_cpu_ms', 'render_gpu_ms', 'memory_static_bytes',
  'video_memory_bytes', 'buffer_memory_bytes'];
const order = [['release', 'v2'], ['editor', 'v1'], ['editor', 'v2'], ['release', 'v3']];
const modes = {editor: [], release: []};
const scenarios = new Map();
let sources, fixture, states, version, packSignature;
for (const [mode, revision] of order) {
  const run = `native-runtime-local-${mode}-${revision}`;
  const report = await read(run + '.json');
  assert.equal(report.success, true, run);
  assert.equal(report.sourceUnchanged, true, run);
  assert.equal(report.nativeExit, 0, run);
  assert.equal(report.nativeException, false, run);
  assert.equal(report.publicConnections, 0, run);
  assert.equal(report.actions.success, true, run);
  assert.deepEqual(report.actions.failures, [], run);
  assert.equal(report.actions.checks.length, 115, run);
  assert.equal(report.engineRuntime.kind, mode, run);
  if (sources) assert.deepEqual(report.sourceSha256, sources, 'Timed source differs');
  else sources = report.sourceSha256;
  if (fixture) assert.deepEqual(report.actionFixture, fixture, 'Original fixture differs');
  else fixture = report.actionFixture;
  if (mode === 'release') {
    assert.equal(report.engineRuntime.executableSha256,
      'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562');
    assert.equal(hash(await fs.readFile(report.engineRuntime.executable)), report.engineRuntime.executableSha256);
    assert.equal(hash(await fs.readFile(report.engineRuntime.pack)), report.engineRuntime.packSha256);
    if (packSignature) assert.equal(report.engineRuntime.sourceSignature, packSignature);
    else packSignature = report.engineRuntime.sourceSignature;
    const pack = JSON.parse(await fs.readFile(report.engineRuntime.receipt));
    assert.equal(pack.success, true);
    assert.equal(pack.original_game_assets_packed, false);
    for (const row of pack.source_files) {
      if (row.path in report.sourceSha256) assert.equal(row.sha256, report.sourceSha256[row.path], row.path);
    }
    for (const required of ['systems/native_data/feedback_descriptors.json',
      'native/window_modes.c', 'tools/build-window-modes.ps1', '.cache/native-window/build-manifest.json']) {
      assert.ok(pack.source_files.some(row => row.path === required), required);
    }
  }
  const scene = await read(run + '.native-crowd-19.summary.json');
  assert.equal(scene.engine_runtime.editor, mode === 'editor');
  assert.equal(scene.engine_runtime.debug, mode === 'editor');
  if (version) assert.deepEqual(scene.engine_runtime.version, version);
  else version = scene.engine_runtime.version;
  assert.equal(version.hash, 'ed1daf0bf001b61586d9930840f2f1394092c079');
  assert.equal(scene.effect_entries, 98);
  assert.equal(scene.effect_models, 98);
  assert.equal(scene.effect_states.length, 96);
  assert.equal(scene.world_instances, 28);
  assert.equal(scene.particles, true);
  assert.equal(scene.collision, true);
  assert.equal(scene.membership_indexed, true);
  assert.equal(scene.particle_state.failed, 0);
  assert.ok(scene.particle_state.active > 0 && scene.peaks.active > 0);
  for (const field of ['requested', 'runs', 'controllers', 'references', 'events', 'phases']) {
    assert.equal(scene.scalar_representation[field], true, field);
  }
  for (const field of ['compiled_requested', 'bulk_requested']) assert.equal(scene.model_controls[field], true);
  for (const field of ['failures', 'bulk_failures']) assert.equal(scene.model_controls[field], 0);
  assert.equal(scene.model_controls.poses, 98);
  assert.equal(scene.model_plans.requested, true);
  assert.ok(scene.model_plans.calls > 0);
  assert.equal(scene.model_plans.failures, 0);
  assert.equal(scene.model_plans.prepare_failures, 0);
  assert.equal(scene.model_storage.requested, true);
  assert.equal(scene.model_storage.poses, 98);
  assert.equal(scene.model_storage.failures, 0);
  assert.equal(scene.model_storage.snapshot_arrays, 0);
  assert.equal(scene.selection_backend.compiled_requested, false);
  assert.equal(scene.selection_backend.reused_setup, false);
  assert.equal(scene.selection_backend.failures, 0);
  const actual = scene.effect_states.map(row => ({...row})).sort((a, b) => a.actor - b.actor || a.visual - b.visual);
  if (states) assert.deepEqual(actual, states, 'Effect states differ');
  else states = actual;
  const rows = await read(run + '.native-crowd-19.frames.json');
  assert.equal(rows.length, scene.frame_count);
  modes[mode].push({run, rows, runtime: report.engineRuntime, peak: scene.peaks});
  // Retain the other baseline, Heal, on/off, culling and wind windows too;
  // selecting the dense window must not hide a regression elsewhere.
  for (let index = 0; index < 20; index++) {
    const detail = index === 19 ? scene : await read(`${run}.native-crowd-${index}.summary.json`);
    const frames = index === 19 ? rows : await read(`${run}.native-crowd-${index}.frames.json`);
    assert.equal(frames.length, detail.frame_count);
    // The probe attaches runtime metadata to its final dense capture only;
    // all earlier windows belong to that same immutable launched process.
    if (detail.engine_runtime) assert.equal(detail.engine_runtime.editor, mode === 'editor');
    if (!scenarios.has(index)) scenarios.set(index, {label: detail.label, editor: [], release: []});
    const group = scenarios.get(index);
    assert.equal(group.label, detail.label, 'Scenario differs');
    group[mode].push(...frames);
  }
}
const aggregate = {};
for (const [mode, runs] of Object.entries(modes)) {
  const rows = runs.flatMap(run => run.rows);
  aggregate[mode] = {
    runs: runs.map(({rows, ...run}) => run),
    metrics: Object.fromEntries(fields.map(key => [key, distribution(rows, key)])),
    hitches: {
      samples: rows.length, over_60fps_budget: rows.filter(row => row.wall_ms > 1000 / 60).length,
      over_25ms: rows.filter(row => row.wall_ms > 25).length,
      over_50ms: rows.filter(row => row.wall_ms > 50).length,
    },
  };
}
const comparison = Object.fromEntries(fields.map(key => {
  const before = aggregate.editor.metrics[key], after = aggregate.release.metrics[key];
  if (!before.available || !after.available) return [key, {before, after, comparable: false,
    reason: 'The release engine does not instrument this memory counter; zero is unavailable, not zero allocated memory.'}];
  return [key, {before, after, mean_reduction_percent: 100 * (before.mean - after.mean) / before.mean,
    p95_reduction_percent: 100 * (before.p95 - after.p95) / before.p95}];
}));
const scenarioComparison = [...scenarios].map(([index, group]) => ({
  index, label: group.label,
  editor: Object.fromEntries(fields.map(key => [key, distribution(group.editor, key)])),
  release: Object.fromEntries(fields.map(key => [key, distribution(group.release, key)])),
}));
const regression = [];
for (const [run, checks] of [
  ['native-release-scalar-v3', 394149], ['native-release-model-v1', 29698],
  ['native-release-runs-v1', 5296], ['native-release-phases-v1', 13596],
  ['native-release-resources-v1', 60163], ['native-release-references-v1', 784],
  ['native-release-particle-state-v1', 6871], ['native-release-particle-order-v1', 25810],
  ['native-release-particle-lifetime-v1', 12080], ['native-release-particle-visual-lifetime-v1', 11],
  ['native-release-particle-pixels-v1', 92], ['native-release-original-pixels-v1', 11],
  ['native-release-prework-process-v2', 24], ['native-editor-prework-process-v1', 24],
  ['native-release-video-input-v1', 37], ['native-release-ui-preload-v1', 21],
]) {
  const guard = await read(run + '.debugger.json'), report = await read(run + '.json');
  assert.equal(guard.success, true, run);
  assert.equal(guard.sourceUnchanged, true, run);
  assert.equal(guard.engineOrLifetimeError, false, run);
  assert.equal(report.success, true, run);
  assert.equal(report.checks, checks, run);
  for (const [file, digest] of Object.entries(sources)) {
    // The post-comparison worker packaging fix cannot affect the measured
    // frame path. All animation/particle/effect implementations must match.
    if ((file.startsWith('native/') || file.startsWith('systems/')) &&
        file !== 'systems/native_prework_process.gd' && file in guard.sourceSha256) {
      assert.equal(guard.sourceSha256[file], digest, `${run}: ${file}`);
    }
  }
  regression.push({run, checks, runtime: guard.runtime});
}
const effects = await read('native-release-effects-established-v2.json');
for (const key of ['success', 'sourceUnchanged']) assert.equal(effects[key], true);
assert.equal(effects.nativeExit, 0);
assert.equal(effects.nativeException, false);
assert.equal(effects.publicConnections, 0);
assert.equal(effects.actions.success, true);
assert.equal(effects.actions.checks.length, 39);
assert.deepEqual(effects.actions.failures, []);
const output = path.join(home, 'native-engine-runtime-evaluation-v1.json');
await fs.writeFile(output, JSON.stringify({
  success: true, goal_complete: false, default_changed: false,
  decision: 'Keep the verified release runtime available as an opt-in candidate; do not promote a particle renderer or declare the frame-time goal complete.',
  scope: 'Four complete same-source authoritative localhost crowd runs, release/editor/editor/release. Same engine version, native libraries, original assets, renderer/state flags, wind, collision, and 96 sustained effects.',
  version, measured_sources: sources, fixture, aggregate, comparison, scenarioComparison,
  regression, established_effects: {run: 'native-release-effects-established-v2', checks: 39}, evidence,
  limits: [
    'The primary aggregate is the sustained eight-second dense-effect window; the other 19 baseline/Heal/culling/wind probe windows are also reported separately. These do not establish all gameplay, loading, or rare-hitch behavior.',
    'Release removes engine debug checks, not all engine overhead. The editor executable was already optimized; it was not an unoptimized development build.',
    'Memory counters describe the whole engine, not isolated particle allocations. Release omits some debug leak warnings; explicit lifetime assertions and exception traps remain necessary.',
    'Release reports zero for the engine static-memory counter. It is explicitly unavailable and no CPU-memory saving is inferred; Windows process/heap measurements remain required.',
    'Original-parity gaps and shared paused-hide failures remain documented in NATIVE-PARTICLE-OPTIMIZATION-GOAL.md. No visual quality or effect count is reduced to improve these numbers.',
  ],
}, null, 2) + '\n');
console.log(JSON.stringify({success: true, goal_complete: false, default_changed: false, output,
  wall: comparison.wall_ms, animation: comparison.actor_animation, effects: comparison.callback_effects,
  particles: comparison.callback_particles, hitches: aggregate.release.hitches}, null, 2));
