'use strict';
// Read-only NWN-63 four-leg reviewer. It never starts a client or changes source.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const util = require('node:util');

const TARGET = 'systems/native_render/drive_collision_indexed.gd';
const SOURCE = {
  control: 'f3c2b35e783dd7d0dec24a1978a6f47edc2e3024ef2f37d8b158b6a8cfaca928',
  candidate: 'c9d5dbebbda14dac1b2afb79c9e10f95003e1f58aad39723a41124343a039110',
};
const arg = Object.fromEntries(process.argv.slice(2).filter(x => x.startsWith('--') && x.includes('=')).map(x => {
  const at = x.indexOf('='); return [x.slice(2, at), x.slice(at + 1)];
}));
if (arg.help || !arg.receipt) {
  console.log('Usage: node tools/nwn63/final-review-graphical.cjs --receipt=PATH [--samples-dir=PATH] [--out=PATH]');
  console.log('Optional per-leg sample sidecars: <report basename>.drive-static-samples.json in --samples-dir. Missing per-call samples fail final acceptance.');
  process.exit(arg.help ? 0 : 2);
}
const failures = [];
const check = (ok, message) => { if (!ok) failures.push(message); };
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const json = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const norm = value => String(value).replaceAll('\\', '/').toLowerCase();
const same = (a, b) => util.isDeepStrictEqual(a, b);
const finite = value => typeof value === 'number' && Number.isFinite(value);
const requireFinite = (value, label) => { check(finite(value), `${label}: missing finite value`); return finite(value) ? value : null; };
const compare = (a, b, label) => check(same(a, b), `${label}: unequal`);
const get = (value, ...keys) => keys.reduce((v, k) => v?.[k], value);
const reportMetric = (metric, key) => finite(metric?.[key]) ? metric[key] : null;
function quantiles(values) {
  if (!values.length || values.some(x => !finite(x) || x < 0)) return null;
  const sorted = values.slice().sort((a, b) => a - b);
  const pick = q => sorted[Math.ceil(q * sorted.length) - 1];
  return { count: sorted.length, median_ms: pick(0.5), p95_ms: pick(0.95), p99_ms: pick(0.99), worst_ms: sorted.at(-1) };
}
function metricTotals(windows, name) {
  let total = 0, activeFrames = 0, max = 0, available = false;
  for (const window of windows) {
    const metric = get(window, 'frame_profile', 'metrics', name);
    if (!metric || !finite(metric.mean) || !finite(window.frame_profile.frames)) continue;
    available = true; total += metric.mean * window.frame_profile.frames;
    activeFrames += Number(metric.active_samples || 0); max = Math.max(max, Number(metric.max || 0));
  }
  return { available, total, activeFrames, max };
}
function frameMetric(windows, name) {
  const rows = windows.map(w => ({ elapsed_ms: w.elapsedMs, metric: get(w, 'frame_profile', 'metrics', name) }))
    .filter(x => x.metric && Number(x.metric.active_samples || 0) > 0)
    .map(x => ({ elapsed_ms: x.elapsed_ms, active_frames: x.metric.active_samples,
      mean_ms_per_frame: reportMetric(x.metric, 'mean'), mean_ms_when_present: reportMetric(x.metric, 'when_present_mean'),
      p95_ms_per_frame: reportMetric(x.metric, 'p95'), max_ms_per_frame: reportMetric(x.metric, 'max') }));
  return rows;
}
function mean(rows, key) {
  const values = rows.map(row => row[key]).filter(finite);
  return values.length ? values.reduce((a, b) => a + b, 0) / values.length : null;
}
function selectionPins(selection, label) {
  const map = new Map();
  check(Array.isArray(selection?.pins) && selection.pins.length > 0, `${label}: selection pins missing`);
  for (const pin of selection?.pins || []) {
    const key = norm(pin.relative);
    check(key && !map.has(key) && /^[0-9a-f]{64}$/i.test(pin.sha256 || ''), `${label}: invalid/duplicate source pin ${key}`);
    map.set(key, String(pin.sha256 || '').toLowerCase());
  }
  return map;
}
function sourcePins(source, label) {
  const map = new Map();
  check(source && typeof source === 'object', `${label}: runtime source map missing`);
  for (const [key, value] of Object.entries(source || {})) map.set(norm(key), String(value).toLowerCase());
  return map;
}
function comparePinMaps(a, b, label) {
  compare([...a.keys()].sort(), [...b.keys()].sort(), `${label}: selected file set`);
  for (const [key, value] of a) if (key !== TARGET) check(b.get(key) === value, `${label}: unrelated file changed: ${key}`);
}
function samplePath(wrapperFile) {
  if (!arg['samples-dir']) return null;
  return path.resolve(arg['samples-dir'], `${path.basename(wrapperFile, '.json')}.drive-static-samples.json`);
}
function loadLeg(entry, index) {
  const label = `leg ${index + 1}`;
  const mode = String(entry.mode || '').toLowerCase();
  check(mode === 'control' || mode === 'candidate', `${label}: expected explicit control/candidate mode`);
  const wrapperFile = path.resolve(entry.report?.file || '');
  check(fs.existsSync(wrapperFile), `${label}: wrapper report missing`);
  if (!fs.existsSync(wrapperFile)) return null;
  check(sha(wrapperFile) === String(entry.report.sha256 || '').toLowerCase(), `${label}: wrapper SHA mismatch`);
  const wrapper = json(wrapperFile);
  const nativeFile = wrapperFile.replace(/\.json$/i, '.native.json');
  const performanceFile = wrapperFile.replace(/\.json$/i, '.performance.jsonl');
  check(fs.existsSync(nativeFile) && fs.existsSync(performanceFile), `${label}: native/performance sidecar missing`);
  if (!fs.existsSync(nativeFile) || !fs.existsSync(performanceFile)) return null;
  const native = json(nativeFile);
  check(same(wrapper.native, native), `${label}: wrapper/native sidecar disagreement`);
  const windows = fs.readFileSync(performanceFile, 'utf8').trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
  check(windows.length > 0, `${label}: performance windows empty`);
  const selectionFile = path.resolve(wrapper.productionSelection?.file || '');
  check(fs.existsSync(selectionFile), `${label}: selection missing`);
  if (!fs.existsSync(selectionFile)) return null;
  const selectionHash = sha(selectionFile);
  check(selectionHash === String(wrapper.productionSelection.sha256 || '').toLowerCase(), `${label}: selection SHA mismatch`);
  if (entry.selectionSha256) check(selectionHash === String(entry.selectionSha256).toLowerCase(), `${label}: receipt/selection SHA mismatch`);
  const selection = json(selectionFile);
  const pins = selectionPins(selection, label);
  const runtimePins = sourcePins(wrapper.sourceSha256, label);
  const expectedSource = SOURCE[mode];
  check(pins.get(TARGET) === expectedSource, `${label}: selected collision source is not expected ${mode} SHA`);
  check(runtimePins.get(TARGET) === expectedSource, `${label}: runtime collision source is not expected ${mode} SHA`);
  check(wrapper.sourceUnchanged === true && wrapper.driverUnchanged === true && wrapper.runtimeUnchanged === true,
    `${label}: source, driver or runtime changed during replay`);
  check(native.success === true && native.clean_exit === true && native.playable === true && native.gameplay_success === true,
    `${label}: native gameplay/exit failed`);
  check(get(native, 'performance_window', 'steady') === true, `${label}: steady window missing`);
  check(get(native, 'world', 'drive_collision', 'ready') === true, `${label}: drive collision not ready`);
  check(get(native, 'world', 'drive_collision_route') === 'indexed', `${label}: indexed route not selected`);
  check(Number(wrapper.movementReplay?.dispatches || 0) > 0 && Number(wrapper.movementReplay?.packets || 0) > 0,
    `${label}: movement replay did not dispatch inputs and packets`);
  check((wrapper.movementReplay?.failures || []).length === 0, `${label}: movement replay failure`);
  const drive = get(native, 'world', 'drive_collision') || {};
  const indexState = drive.static_group_index || null;
  const movingWindows = windows.filter(w => Number(get(w, 'frame_profile', 'metrics', 'drive_static_query_ms', 'active_samples') || 0) > 0);
  check(movingWindows.length > 0, `${label}: no profiled movement/static-query windows`);
  const groupInputs = metricTotals(movingWindows, 'count_drive_model_group_inputs');
  const groupMatches = metricTotals(movingWindows, 'count_drive_group_index_candidates');
  if (mode === 'candidate') {
    check(indexState?.ready === true && indexState.build_pending === false && Number(indexState.entries || 0) > 0 &&
      Number(indexState.group_keys || 0) === Number(drive.static_groups || -1) && Number(indexState.unsafe_groups || 0) === 0,
    `${label}: final group index is not complete and ready`);
    check(Number(indexState?.last_query?.visited_nodes || 0) > 0, `${label}: no successful coarse-tree query in final snapshot`);
    const actualWindows = movingWindows.filter(w => get(w, 'state', 'drive_collision', 'static_group_index', 'ready') === true &&
      Number(get(w, 'frame_profile', 'metrics', 'count_drive_group_index_candidates', 'active_samples') || 0) > 0);
    check(actualWindows.length > 0 && groupMatches.available && groupInputs.available &&
      groupMatches.total > 0 && groupMatches.total < groupInputs.total,
    `${label}: no measured in-movement indexed query/candidate reduction`);
  } else check(indexState == null, `${label}: control unexpectedly has candidate index state`);
  const sampleFile = samplePath(wrapperFile);
  let sampleStats = null;
  if (sampleFile && fs.existsSync(sampleFile)) {
    const sidecar = json(sampleFile);
    check(sidecar.sourceSha256 === expectedSource && sidecar.selectionSha256 === selectionHash &&
      sidecar.recordingSha256 === wrapper.recordingSha256, `${label}: per-call sample sidecar identity mismatch`);
    sampleStats = quantiles(sidecar.samplesMs || []);
  }
  check(sampleStats && sampleStats.count > 0, `${label}: raw per-preview static-query samples missing; median/p99 cannot be inferred from 240-frame summaries`);
  const view = get(native, 'performance_window', 'view_begin') || {};
  const settings = { viewport: view.viewport, screen: view.screen, primary_screen: view.primary_screen,
    vsync: view.vsync, msaa_3d: view.msaa_3d, fov_degrees: view.fov_degrees,
    maximum_fps: view.maximum_fps, gamma: view.settings?.gamma,
    particles_enabled: view.settings?.particles_enabled,
    particle_collision_enabled: view.settings?.particle_collision_enabled,
    compact_scenery_enabled: view.settings?.compact_scenery_enabled,
    camera: { position: view.camera?.position, target: view.camera?.target, follow: view.camera?.follow } };
  const scene = { generation: get(native, 'world', 'generation'), area_id: get(native, 'world', 'area_id'),
    entities: get(native, 'world', 'entities'), desired: get(native, 'world', 'desired'),
    static_entries: drive.static_entries, terrain_tiles: get(native, 'world', 'terrain', 'tiles'),
    base_expected: get(native, 'world', 'base_scenery_first_known_complete_expected'),
    protocol_digest: crypto.createHash('sha256').update(JSON.stringify(native.protocol_objects || [])).digest('hex') };
  const memory = Object.fromEntries(['objects', 'nodes', 'resources', 'buffer_memory_bytes', 'texture_memory_bytes', 'video_memory_bytes']
    .map(name => [name, { mean: mean(movingWindows.map(w => get(w, 'frame_profile', 'metrics', name) || {}), 'mean'),
      max: Math.max(0, ...movingWindows.map(w => Number(get(w, 'frame_profile', 'metrics', name, 'max') || 0))) }]));
  const cpu = Object.fromEntries(['process_ms', 'render_cpu_ms', 'render_gpu_ms', 'wall_ms', 'drive_static_query_ms']
    .map(name => [name, frameMetric(movingWindows, name)]));
  const frame = native.frame_intervals || {};
  for (const key of ['median_ms', 'p95_ms', 'p99_ms', 'worst_ms']) requireFinite(frame[key], `${label}: whole-frame ${key}`);
  const loading = { first_playable_ms: requireFinite(get(native, 'world', 'playable_ms'), `${label}: first playable`),
    full_base_ms: requireFinite(get(native, 'world', 'base_scenery_first_known_complete_ms'), `${label}: full base`) };
  return { label, mode, files: { wrapper: wrapperFile, native: nativeFile, performance: performanceFile,
    wrapper_sha256: sha(wrapperFile), native_sha256: sha(nativeFile), performance_sha256: sha(performanceFile),
    selection: selectionFile, selection_sha256: selectionHash, samples: sampleFile },
  pins, runtimePins, wrapper, native, windows, settings, scene, loading, frame,
  controlled_distance: native.controlled_distance, memory, cpu,
  static_query_samples: sampleStats, static_query_profile_windows: frameMetric(movingWindows, 'drive_static_query_ms'),
  indexed: { state: indexState, input_groups: groupInputs, selected_groups: groupMatches },
  diagnostics: wrapper.nativeDiagnostics };
}
function delta(candidate, control) {
  return finite(candidate) && finite(control) ? { control, candidate, delta: candidate - control,
    percent: control === 0 ? null : 100 * (candidate - control) / control } : null;
}
let result;
try {
  const receiptFile = path.resolve(arg.receipt);
  check(fs.existsSync(receiptFile), 'run receipt missing');
  const receipt = json(receiptFile);
  check(receipt.complete === true && Array.isArray(receipt.legs) && receipt.legs.length === 4,
    'run receipt incomplete or not four legs');
  if (receipt.plan && receipt.planSha256) check(sha(receipt.plan) === String(receipt.planSha256).toLowerCase(), 'run plan SHA mismatch');
  const legs = (receipt.legs || []).map(loadLeg);
  check(legs.length === 4 && legs.every(Boolean), 'one or more report legs missing');
  const modes = legs.map(x => x?.mode);
  check(same(modes, ['control', 'candidate', 'candidate', 'control']) ||
    same(modes, ['candidate', 'control', 'control', 'candidate']), 'legs are not a balanced ABBA');
  const reference = legs[0];
  if (reference && legs.every(Boolean)) {
    for (const leg of legs.slice(1)) {
      comparePinMaps(reference.pins, leg.pins, `${leg.label}: selection`);
      comparePinMaps(reference.runtimePins, leg.runtimePins, `${leg.label}: runtime`);
      compare(reference.wrapper.runtimeSha256, leg.wrapper.runtimeSha256, `${leg.label}: runtime binaries`);
      compare(reference.wrapper.productionSelection.engineSha256, leg.wrapper.productionSelection.engineSha256, `${leg.label}: engine`);
      compare(reference.wrapper.recordingSha256, leg.wrapper.recordingSha256, `${leg.label}: recording`);
      compare(reference.wrapper.capture, leg.wrapper.capture, `${leg.label}: capture`);
      compare(reference.settings, leg.settings, `${leg.label}: viewport/camera/preferences`);
      compare(reference.scene, leg.scene, `${leg.label}: area/scene/protocol`);
      compare(reference.wrapper.movementReplay?.dispatches, leg.wrapper.movementReplay?.dispatches, `${leg.label}: movement dispatches`);
      compare(reference.wrapper.movementReplay?.packets, leg.wrapper.movementReplay?.packets, `${leg.label}: movement packets`);
      compare(reference.wrapper.movementReplay?.samples, leg.wrapper.movementReplay?.samples, `${leg.label}: movement samples`);
      const distance = Math.abs(Number(leg.controlled_distance) - Number(reference.controlled_distance));
      check(finite(distance) && distance <= 0.001, `${leg.label}: controlled distance changed (${distance})`);
      compare(reference.diagnostics, leg.diagnostics, `${leg.label}: engine diagnostic classes`);
    }
  }
  const controls = legs.filter(x => x?.mode === 'control');
  const candidates = legs.filter(x => x?.mode === 'candidate');
  const pooled = {};
  const keys = ['first_playable_ms', 'full_base_ms', 'median_ms', 'p95_ms', 'p99_ms', 'worst_ms'];
  for (const key of keys) {
    const section = key.endsWith('_playable_ms') || key === 'full_base_ms' ? 'loading' : 'frame';
    pooled[key] = delta(mean(candidates.map(x => x[section]), key), mean(controls.map(x => x[section]), key));
  }
  for (const name of ['process_ms', 'render_cpu_ms', 'render_gpu_ms', 'wall_ms']) {
    pooled[name] = delta(mean(candidates.map(x => ({ value: mean(x.cpu[name], 'mean_ms_per_frame') })), 'value'),
      mean(controls.map(x => ({ value: mean(x.cpu[name], 'mean_ms_per_frame') })), 'value'));
  }
  for (const name of ['objects', 'nodes', 'resources', 'buffer_memory_bytes', 'texture_memory_bytes', 'video_memory_bytes']) {
    pooled[name] = delta(mean(candidates.map(x => x.memory[name]), 'max'), mean(controls.map(x => x.memory[name]), 'max'));
  }
  pooled.static_query_median_ms = delta(mean(candidates.map(x => x.static_query_samples || {}), 'median_ms'),
    mean(controls.map(x => x.static_query_samples || {}), 'median_ms'));
  pooled.static_query_p95_ms = delta(mean(candidates.map(x => x.static_query_samples || {}), 'p95_ms'),
    mean(controls.map(x => x.static_query_samples || {}), 'p95_ms'));
  pooled.static_query_p99_ms = delta(mean(candidates.map(x => x.static_query_samples || {}), 'p99_ms'),
    mean(controls.map(x => x.static_query_samples || {}), 'p99_ms'));
  pooled.static_query_worst_ms = delta(mean(candidates.map(x => x.static_query_samples || {}), 'worst_ms'),
    mean(controls.map(x => x.static_query_samples || {}), 'worst_ms'));
  result = { issue: 'NWN-63', accepted: failures.length === 0, failures,
    receipt: { file: receiptFile, sha256: sha(receiptFile) }, source: SOURCE,
    legs: legs.map(x => x && ({ label: x.label, mode: x.mode, files: x.files, settings: x.settings, scene: x.scene,
      loading: x.loading, frame: x.frame, controlled_distance: x.controlled_distance,
      memory: x.memory, cpu: x.cpu, static_query_samples: x.static_query_samples,
      static_query_profile_windows: x.static_query_profile_windows, indexed: x.indexed })),
    paired_deltas: pooled,
    limits: 'FrameProfile JSONL stores 240-frame aggregates, not raw preview calls. Individual static-query median/p95/p99/worst require source-pinned per-call sidecars; missing sidecars fail acceptance.' };
} catch (error) {
  failures.push(`reviewer exception: ${error.message}`);
  result = { issue: 'NWN-63', accepted: false, failures };
}
if (arg.out) {
  const out = path.resolve(arg.out);
  fs.writeFileSync(out, `${JSON.stringify(result, null, 2)}\n`, { flag: 'wx' });
}
console.log(JSON.stringify({ accepted: result.accepted, failures: result.failures,
  source: result.source, receipt: result.receipt, paired_deltas: result.paired_deltas }));
process.exit(result.accepted ? 0 : 1);
