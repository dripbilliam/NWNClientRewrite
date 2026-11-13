import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';

const home = path.resolve('godot-client/reports'), evidence = [];
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
async function read(file) {
  const bytes = await fs.readFile(path.join(home, file));
  evidence.push({file, sha256: hash(bytes)});
  return JSON.parse(bytes);
}
function distribution(rows, key) {
  const values = rows.map(row => Number(row[key])).sort((a, b) => a - b);
  assert.ok(values.length && values.every(Number.isFinite), key);
  return {samples: values.length, mean: values.reduce((sum, value) => sum + value, 0) / values.length,
    p95: values[Math.ceil(values.length * .95) - 1], p99: values[Math.ceil(values.length * .99) - 1], max: values.at(-1)};
}
const fields = ['wall_ms', 'actor_animation', 'callback_effects', 'effect_selection_total',
  'effect_selection_setup', 'effect_selection_core', 'callback_particles', 'render_cpu_ms',
  'render_gpu_ms', 'video_memory_bytes'];
const pilot = process.argv.includes('--pilot');
const noActions = process.argv.includes('--no-actions');
const order = noActions
  ? (pilot ? [['compiled', 'v1'], ['scripted', 'v1']] : [['compiled', 'v1'], ['scripted', 'v1'], ['scripted', 'v2'], ['compiled', 'v2']])
  : (pilot ? [['scripted', 'v2'], ['compiled', 'v2']] : [['scripted', 'v2'], ['compiled', 'v2'], ['compiled', 'v3'], ['scripted', 'v3']]);
const modes = {scripted: [], compiled: []}, scenarios = new Map();
let sources, fixture, states, observerSource;
for (const [mode, revision] of order) {
  const run = `${noActions ? 'native-no-actions-local' : 'native-snapshot-local'}-${mode}-${revision}`, report = await read(run + '.json');
  assert.equal(report.success, true, run);
  assert.equal(report.sourceUnchanged, true, run);
  assert.equal(report.nativeExit, 0, run);
  assert.equal(report.nativeException, false, run);
  assert.equal(report.publicConnections, 0, run);
  assert.equal(report.actions.success, true, run);
  assert.deepEqual(report.actions.failures, [], run);
  assert.equal(report.actions.checks.length, 115, run);
  assert.equal(report.engineRuntime.kind, 'release');
  assert.equal(report.engineRuntime.executableSha256,
    'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562');
  if (sources) assert.deepEqual(report.sourceSha256, sources, 'Timed implementation differs');
  else sources = report.sourceSha256;
  if (fixture) assert.deepEqual(report.actionFixture, fixture, 'Original server fixture differs');
  else fixture = report.actionFixture;
  const scene = await read(run + '.native-crowd-19.summary.json');
  assert.equal(scene.effect_entries, 98);
  assert.equal(scene.effect_models, 98);
  assert.equal(scene.effect_states.length, 96);
  assert.equal(scene.world_instances, 28);
  assert.equal(scene.particles, true);
  assert.equal(scene.collision, true);
  assert.equal(scene.membership_indexed, true);
  assert.equal(scene.particle_state.failed, 0);
  assert.ok(scene.particle_state.active > 0 && scene.peaks.active > 0);
  assert.equal(scene.engine_runtime.editor, false);
  assert.equal(scene.engine_runtime.debug, false);
  assert.equal(scene.engine_runtime.version.hash, 'ed1daf0bf001b61586d9930840f2f1394092c079');
  assert.equal(scene.selection_backend.compiled_requested, false);
  assert.equal(scene.selection_backend.reused_setup, mode === 'compiled');
  assert.equal(scene.selection_backend.reused_calls > 0, mode === 'compiled');
  assert.equal(scene.selection_backend.failures, 0);
  assert.equal(scene.selection_backend.context_depth, 0);
  assert.equal(scene.selection_backend.snapshot.requested, mode === 'compiled');
  assert.equal(scene.selection_backend.snapshot.failures, 0);
  assert.equal(scene.selection_backend.snapshot.calls > 0, mode === 'compiled');
  if (noActions) assert.equal(scene.selection_backend.snapshot.noops > 0, mode === 'compiled');
  for (const name of ['model_controls', 'model_plans', 'model_storage']) assert.equal(scene[name].failures, 0);
  assert.equal(scene.model_controls.compiled_requested, true);
  assert.equal(scene.model_controls.bulk_requested, true);
  assert.equal(scene.model_plans.requested, true);
  assert.equal(scene.model_storage.requested, true);
  assert.equal(scene.model_storage.snapshot_arrays, 0);
  const actual = scene.effect_states.map(row => ({...row})).sort((a, b) => a.actor - b.actor || a.visual - b.visual);
  if (states) assert.deepEqual(actual, states, 'Live effect state differs');
  else states = actual;
  const rows = await read(run + '.native-crowd-19.frames.json');
  assert.equal(rows.length, scene.frame_count);
  const memory = await read(run + '.process-memory.json');
  assert.equal(memory.success, true, run);
  assert.equal(memory.source_unchanged, true, run);
  assert.ok(memory.counter_api.startsWith('K32GetProcessMemoryInfo/'));
  assert.equal(memory.run, run);
  assert.equal(memory.identity.pid, scene.process_window.pid);
  assert.equal(memory.identity.executable_sha256, report.engineRuntime.executableSha256);
  assert.equal(path.resolve(memory.identity.executable), path.resolve(report.engineRuntime.executable));
  if (observerSource) assert.equal(memory.source_sha256, observerSource, 'Observer implementation differs');
  else observerSource = memory.source_sha256;
  const samples = memory.samples.filter(row => row.unix_ms >= scene.process_window.start_unix_ms && row.unix_ms <= scene.process_window.end_unix_ms);
  assert.ok(samples.length >= 20, 'Insufficient OS memory samples for the actual dense window');
  assert.ok(samples.every(row => row.private_bytes > 0 && row.working_set_bytes > 0));
  modes[mode].push({run, rows, memory: samples, snapshot: scene.selection_backend.snapshot,
    window: scene.process_window, observer_cpu_ms: memory.watcher_cpu_ms,
    observer_queries: distribution(memory.samples, 'query_ms')});
  for (let index = 0; index < 20; index++) {
    const detail = index === 19 ? scene : await read(`${run}.native-crowd-${index}.summary.json`);
    const frames = index === 19 ? rows : await read(`${run}.native-crowd-${index}.frames.json`);
    assert.equal(frames.length, detail.frame_count);
    if (!scenarios.has(index)) scenarios.set(index, {label: detail.label, scripted: [], compiled: []});
    const group = scenarios.get(index); assert.equal(group.label, detail.label);
    group[mode].push(...frames);
  }
}
const aggregate = {};
for (const [mode, runs] of Object.entries(modes)) {
  const rows = runs.flatMap(run => run.rows), memory = runs.flatMap(run => run.memory);
  aggregate[mode] = {runs: runs.map(({rows, memory, ...run}) => run),
    metrics: Object.fromEntries(fields.map(key => [key, distribution(rows, key)])),
    process_memory: Object.fromEntries(['private_bytes', 'working_set_bytes', 'query_ms'].map(key => [key, distribution(memory, key)])),
    hitches: {samples: rows.length, over_60fps_budget: rows.filter(row => row.wall_ms > 1000 / 60).length,
      over_25ms: rows.filter(row => row.wall_ms > 25).length, over_50ms: rows.filter(row => row.wall_ms > 50).length}};
}
const comparison = {};
for (const key of fields) {
  const before = aggregate.scripted.metrics[key], after = aggregate.compiled.metrics[key];
  comparison[key] = {before, after, mean_reduction_percent: 100 * (before.mean - after.mean) / before.mean,
    p95_reduction_percent: 100 * (before.p95 - after.p95) / before.p95};
}
const scenarioComparison = [...scenarios].map(([index, group]) => ({index, label: group.label,
  scripted: Object.fromEntries(fields.map(key => [key, distribution(group.scripted, key)])),
  compiled: Object.fromEntries(fields.map(key => [key, distribution(group.compiled, key)]))}));
const regression = [];
const regressionRuns = noActions ? [
  ['native-visual-no-actions-final-proof-v1', 18519], ['native-visual-no-actions-final-integration-v1', 21463],
  ['native-visual-no-actions-final-original-v1', 10370], ['native-visual-no-actions-final-custom-v1', 7090],
  ['native-visual-no-actions-final-phases-v1', 13596], ['native-visual-no-actions-pixels-v1', 92],
  ['native-visual-no-actions-original-pixels-v1', 11],
] : [['native-visual-snapshot-canonical-v2', 21463],
  ['native-visual-snapshot-release-v1', 21463], ['native-visual-snapshot-original-v1', 10370],
  ['native-visual-snapshot-setup-v1', 7090], ['native-visual-snapshot-custom-v1', 7090],
  ['native-visual-snapshot-reused-v1', 21463],
  ['native-visual-snapshot-phases-v1', 13596]];
for (const [run, checks] of regressionRuns) {
  const guard = await read(run + '.debugger.json'), test = await read(run + '.json');
  assert.equal(guard.success, true, run);assert.equal(guard.sourceUnchanged, true, run);
  assert.equal(guard.engineOrLifetimeError, false, run);assert.equal(test.success, true, run);
  assert.equal(test.checks, checks, run);regression.push({run, checks});
  assert.equal(guard.sourceSha256['native/visual_selection.hpp'], sources['native/visual_selection.hpp']);
}
const effectsRun = noActions ? 'native-visual-no-actions-effects-v1' : 'native-visual-snapshot-effects-v1';
const effects = await read(effectsRun + '.json');
assert.equal(effects.success, true);assert.equal(effects.sourceUnchanged, true);
assert.equal(effects.nativeException, false);assert.equal(effects.publicConnections, 0);
assert.equal(effects.actions.success, true);assert.equal(effects.actions.checks.length, 39);
const outputName = noActions ? 'native-visual-no-actions' : 'native-visual-snapshot';
const file = path.join(home, outputName + (pilot ? '-pilot-v1.json' : '-evaluation-v1.json'));
await fs.writeFile(file, JSON.stringify({success: true, goal_complete: false, default_changed: false,
  pilot, no_actions_proof: noActions,
  scope: `${pilot ? 'One complete same-source matched pair; repeat comparison is unproven.' : noActions ? 'Four complete same-source scenes in compiled/scripted/scripted/compiled order.' : 'Four complete same-source scenes in scripted/compiled/compiled/scripted order.'} Release-runtime original-localhost workload. The candidate combines invocation-local canonical ownership/state/type snapshot setup with previously validated reusable callback plumbing${noActions ? ' and a fresh-state proof that this individual selection would execute no callbacks or mutations' : ''}. Renderer, particle semantics, per-entry phase order and all other flags remain fixed.`,
  decision: pilot ? 'Do not promote from a single matched pair. Keep the prototype opt-in and assess repeated full-scene and slow-tail evidence.' : 'Opt-in experiment; assess full-frame and tail distributions, not just setup timing. No renderer promotion or goal-completion claim.',
  sources, fixture, aggregate, comparison, scenarioComparison, regression, evidence,
  limitations: ['OS private commit/working-set samples are whole-process measurements, not isolated particle allocations or a heap census.',
    'The primary dense windows are eight seconds each. All other 19 baseline/Heal/wind/culling scenarios are recorded separately; this is not all gameplay or rare-hitch coverage.',
    'The first scripted-v1 diagnostic completed 115 gameplay checks but its OS observer failed; compiled-v1 measured the snapshot alone with an overly expensive .NET process refresh. Those runs and failed observer receipts are retained and excluded from this matched direct-counter comparison.',
    'Original-parity gaps and shared paused-hide image failures documented in NATIVE-PARTICLE-OPTIMIZATION-GOAL.md remain unfinished. No effects are dropped or quality reduced.']}, null, 2) + '\n');
console.log(JSON.stringify({success: true, goal_complete: false, output: file, wall: comparison.wall_ms,
  setup: comparison.effect_selection_setup, effects: comparison.callback_effects,
  memory: {before: aggregate.scripted.process_memory, after: aggregate.compiled.process_memory},
  hitches: {before: aggregate.scripted.hitches, after: aggregate.compiled.hitches}}, null, 2));
