'use strict';
// NWN-63 read-only original-scene ABBA review. The caller owns all report files.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const option = name => process.argv.find(x => x.startsWith(`--${name}=`))?.slice(name.length + 3);
const pairFile = option('pair');
const tag = option('tag');
if (!pairFile || !tag) {
  console.error('Usage: node tools/nwn63/final-review-pair.cjs --pair=PATH --tag=b [--out=PATH] [--samples-dir=PATH]');
  process.exit(2);
}
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const norm = file => String(file).replaceAll('\\', '/').toLowerCase();
const failures = [];
const check = (ok, detail) => { if (!ok) failures.push(detail); };
const good = x => typeof x === 'number' && Number.isFinite(x);
const avg = xs => xs.length && xs.every(good) ? xs.reduce((a, b) => a + b, 0) / xs.length : null;
const delta = (control, candidate) => good(control) && good(candidate) ? { control, candidate, delta: candidate - control } : null;
const controlHash = 'f3c2b35e783dd7d0dec24a1978a6f47edc2e3024ef2f37d8b158b6a8cfaca928';
const candidateHash = 'c9d5dbebbda14dac1b2afb79c9e10f95003e1f58aad39723a41124343a039110';
const target = 'systems/native_render/drive_collision_indexed.gd';
const sourceSet = new Set([target, 'native_live_world.gd']);
const projectPath = path.resolve(pairFile);
const pair = read(projectPath);
const summaryFile = path.join(path.dirname(projectPath), `abba-${tag}-summary.json`);
const summary = read(summaryFile);
check(pair.issue === 'NWN-63' && summary.issue === 'NWN-63', 'wrong ticket');
check(sha(pair.manifestFile) === pair.manifestSha256, 'pair manifest SHA mismatch');
check(sha(pair.driver.file) === pair.driver.sha256, 'driver SHA mismatch');
check(sha(pair.preferences.file) === pair.preferences.sha256, 'preferences seed SHA mismatch');
check(summary.completed === 4 && summary.accepted === true && summary.summaries?.length === 4, 'incomplete/rejected ABBA');
check(JSON.stringify(summary.summaries.map(x => x.leg)) === JSON.stringify(['control', 'candidate', 'candidate', 'control']), 'incorrect ABBA order');
const selections = {};
for (const mode of ['control', 'candidate']) {
  const ref = pair.selections[mode];
  check(sha(ref.file) === ref.sha256, `${mode}: selection SHA mismatch`);
  const selection = read(ref.file);
  const files = new Map(selection.mainSourceIdentity.files.map(x => [norm(x.file), x.sha256]));
  const expected = mode === 'control' ? controlHash : candidateHash;
  check(files.get(target) === expected, `${mode}: selected collision source SHA mismatch`);
  check(sha(path.join(selection.sourceProject, target)) === expected, `${mode}: staged collision bytes mismatch`);
  check(sha(path.join(selection.sourceProject, 'native_live_world.gd')) === files.get('native_live_world.gd'), `${mode}: staged world bytes mismatch`);
  selections[mode] = { ref, selection, files };
}
for (const [file, hash] of selections.control.files) {
  if (!sourceSet.has(file)) check(selections.candidate.files.get(file) === hash, `unrelated source differs: ${file}`);
}
check(selections.control.files.size === selections.candidate.files.size, 'selection source file counts differ');
check(JSON.stringify([...sourceSet].sort()) === JSON.stringify([...pair.differentSources].map(norm).sort()), 'pair differs beyond declared sources');
function describe(leg, ordinal) {
  const label = `${ordinal + 1}:${leg.leg}`;
  const expected = leg.leg === 'control' ? controlHash : candidateHash;
  check(leg.exit === 0 && leg.success === true, `${label}: leg failed`);
  check(sha(leg.report) === leg.reportSha256, `${label}: wrapper report SHA mismatch`);
  const wrapper = read(leg.report);
  const nativeFile = leg.report.replace(/\.json$/i, '.native.json');
  const native = read(nativeFile);
  check(JSON.stringify(wrapper.native) === JSON.stringify(native), `${label}: native sidecar differs`);
  check(wrapper.success === true && wrapper.failure == null, `${label}: wrapper failure`);
  check(native.success === true && native.clean_exit === true && native.playable === true && native.gameplay_success === true, `${label}: native gameplay failed`);
  check(wrapper.productionSelection?.sha256 === selections[leg.leg].ref.sha256, `${label}: selection identity mismatch`);
  check(wrapper.sourceUnchanged === true && wrapper.runtimeUnchanged === true && wrapper.driverUnchanged === true, `${label}: source/runtime/driver changed`);
  check(wrapper.driverSha256 === pair.driver.sha256, `${label}: driver differs`);
  const runtimeSources = new Map(Object.entries(wrapper.sourceSha256 || {}).map(([file, hash]) => [norm(file), hash]));
  check(runtimeSources.get(target) === expected, `${label}: runtime collision source differs`);
  check(runtimeSources.get('native_live_world.gd') === selections[leg.leg].files.get('native_live_world.gd'), `${label}: runtime world source differs`);
  const replay = wrapper.movementReplay || {};
  check(replay.enabled === true && replay.inputs === 360 && replay.accepted === 360 && replay.rejected === 0 && replay.prediction?.verified === true && (replay.failures || []).length === 0, `${label}: recorded movement acceptance failed`);
  const world = native.world || {};
  const index = world.drive_collision?.static_group_index || null;
  const fpsFile = leg.report.replace(/\.json$/i, '.fps.jsonl');
  const windows = fs.readFileSync(fpsFile, 'utf8').trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
  check(windows.some(x => x.ready && x.areaId === world.area_id), `${label}: no ready area window`);
  const profile = windows.filter(x => x.frame_profile?.frames > 0);
  const metrics = profile.map(x => x.frame_profile.metrics || {});
  check(profile.length > 0 && metrics.some(x => Object.keys(x).some(k => /process_ms|render_cpu_ms|root_world|frame_wall_ms/.test(k))), `${label}: CPU profile windows missing`);
  check(profile.length > 0 && windows.some(x => x.protocol_host?.rss > 0 || x.state?.pool), `${label}: memory observation windows missing`);
  const inputs = metrics.map(x => x.count_drive_model_group_inputs).filter(Boolean);
  const matches = metrics.map(x => x.count_drive_group_index_candidates).filter(Boolean);
  const staticQueries = metrics.map(x => x.drive_static_query_ms).filter(Boolean);
  if (leg.leg === 'candidate') {
    check(index?.ready === true && index.build_pending === false && index.build_steps > 0 && index.entries > 0 && index.unsafe_groups === 0 && index.last_query?.visited_nodes > 0, `${label}: index not built and used`);
    check(matches.length > 0 && inputs.length > 0 && matches.some((m, i) => m.mean > 0 && m.mean < inputs[i]?.mean), `${label}: no profiled indexed candidate reduction during movement`);
  } else check(index == null, `${label}: control unexpectedly has index`);
  check(staticQueries.length > 0, `${label}: no static-query profile windows`);
  const sampleRoot = option('samples-dir');
  const sampleFile = sampleRoot && path.join(sampleRoot, `${path.basename(leg.report, '.json')}.drive-static-samples.json`);
  const samples = sampleFile && fs.existsSync(sampleFile) ? read(sampleFile) : null;
  check(samples?.sourceSha256 === expected && samples?.selectionSha256 === selections[leg.leg].ref.sha256 && samples?.recordingSha256 === wrapper.recordingSha256 && Array.isArray(samples?.samplesMs) && samples.samplesMs.length > 0, `${label}: source-pinned per-preview query samples missing`);
  const sorted = (samples?.samplesMs || []).slice().sort((a, b) => a - b);
  const q = p => sorted.length ? sorted[Math.ceil(p * sorted.length) - 1] : null;
  const frame = native.frame_intervals || {};
  for (const key of ['median_ms', 'p95_ms', 'p99_ms', 'worst_ms']) check(good(frame[key]), `${label}: missing ${key}`);
  const base = world.base_scenery || {};
  check(world.ready === true && world.generation === pair.scene.generation && world.area_id === summary.summaries[0].areaId, `${label}: world readiness/area`);
  const view = native.performance_window?.view_begin || {};
  const settings = { viewport: view.viewport, screen: view.screen, vsync: view.vsync, msaa_3d: view.msaa_3d, fov_degrees: view.camera?.fov_degrees, gamma: view.settings?.gamma, particles: view.settings?.particles_enabled, compact: view.settings?.compact_scenery_enabled, camera_follow: view.camera?.follow };
  return { label, mode: leg.leg, report: leg.report, source: expected, runtimeSources, wrapper, native, settings, scene: { area: world.area_id, generation: world.generation, entities: world.entities, desired: world.desired, expected: base.expected, resolved: base.resolved, pending: base.pending, failed: base.failed }, movement: { inputs: replay.inputs, accepted: replay.accepted, dispatches: replay.dispatches, packets: replay.packets, samples: replay.samples, distance: native.controlled_distance }, frame, loading: { playable_ms: world.playable_ms, full_base_ms: world.base_scenery_first_known_complete_ms }, index, query: { profile_windows: staticQueries.length, sample_count: sorted.length, median_ms: q(0.5), p95_ms: q(0.95), p99_ms: q(0.99), worst_ms: sorted.at(-1) || null }, cpu: { profile_windows: profile.length }, memory: { profile_windows: profile.length }, diagnosticKinds: Object.fromEntries(Object.entries(wrapper.nativeDiagnostics || {}).map(([k, v]) => [k, v.kinds])) };
}
const rows = summary.summaries.map(describe);
const ref = rows[0];
for (const row of rows.slice(1)) {
  for (const [name, value] of ref.runtimeSources) if (!sourceSet.has(name)) check(row.runtimeSources.get(name) === value, `${row.label}: unrelated runtime source changed: ${name}`);
  for (const key of ['recordingSha256', 'capture']) check(JSON.stringify(row.wrapper[key]) === JSON.stringify(ref.wrapper[key]), `${row.label}: ${key} differs`);
  for (const key of ['engine', 'kernel', 'kernelManifest', 'resourceIndex', 'resourceIndexManifest']) check(row.wrapper.runtimeSha256?.[key] === ref.wrapper.runtimeSha256?.[key], `${row.label}: runtime ${key} differs`);
  check(JSON.stringify(row.settings) === JSON.stringify(ref.settings), `${row.label}: settings/camera differ`);
  check(JSON.stringify(row.scene) === JSON.stringify(ref.scene), `${row.label}: area/scene differs`);
  for (const key of ['inputs', 'accepted', 'dispatches', 'packets', 'samples']) check(row.movement[key] === ref.movement[key], `${row.label}: movement ${key} differs`);
  check(Math.abs(row.movement.distance - ref.movement.distance) <= 0.001, `${row.label}: final controlled distance differs`);
  check(JSON.stringify(row.diagnosticKinds) === JSON.stringify(ref.diagnosticKinds), `${row.label}: engine diagnostic class differs`);
}
const controls = rows.filter(x => x.mode === 'control');
const candidates = rows.filter(x => x.mode === 'candidate');
const paired = {};
for (const [section, keys] of Object.entries({ frame: ['median_ms', 'p95_ms', 'p99_ms', 'worst_ms'], loading: ['playable_ms', 'full_base_ms'], query: ['median_ms', 'p95_ms', 'p99_ms', 'worst_ms'] })) {
  for (const key of keys) paired[`${section}.${key}`] = delta(avg(controls.map(x => x[section][key])), avg(candidates.map(x => x[section][key])));
}
const result = { issue: 'NWN-63', accepted: failures.length === 0, failures, pair: { file: projectPath, sha256: sha(projectPath) }, summary: { file: summaryFile, sha256: sha(summaryFile) }, rows: rows.map(({ runtimeSources, wrapper, native, ...rest }) => rest), paired, limits: 'The FPS JSONL alone has no per-preview quantiles. Final acceptance requires source-pinned per-call samples and profiled indexed candidate counts.' };
const output = option('out');
if (output) fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`, { flag: 'wx' });
console.log(JSON.stringify({ accepted: result.accepted, failures: result.failures, paired: result.paired, rows: result.rows.map(x => ({ label: x.label, index: x.index, movement: x.movement, query: x.query })) }));
process.exit(result.accepted ? 0 : 1);
