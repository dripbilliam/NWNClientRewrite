'use strict';
// Historical source/data review only. Does not rerun capture, exporter or engine.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const { table } = require('./trace-table.cjs');
const project = path.resolve(__dirname, '../..'), at = relative => path.join(project, relative), sha = data => crypto.createHash('sha256').update(data).digest('hex');
const pin = file => { const data = fs.readFileSync(file); return { file, sha256: sha(data), bytes: data.length }; };
const read = file => JSON.parse(fs.readFileSync(file)), base = at('.cache/native-tracy/captures/headless-wire-a'), readback = path.join(base, 'readback-a');
const cpu = table(fs.readFileSync(path.join(readback, 'cpu.tsv'), 'utf8'), 'cpu'), summary = table(fs.readFileSync(path.join(readback, 'summary.tsv'), 'utf8'), 'summary'), self = table(fs.readFileSync(path.join(readback, 'self.tsv'), 'utf8'), 'summary'), gpu = table(fs.readFileSync(path.join(readback, 'gpu.tsv'), 'utf8'), 'gpu');
const named = new Map(), identities = new Map(), threads = new Set(); let first = null, last = null, incomplete = 0;
for (const row of cpu) {
 const start = BigInt(row.ns_since_start), duration = BigInt(row.exec_time_ns); if (duration < 0n) { incomplete++; continue; }
 if (first === null || start < first) first = start; if (last === null || start + duration > last) last = start + duration;
 threads.add(row.thread);
 const key = JSON.stringify([row.name, row.src_file, row.src_line]);
 for (const [map, id] of [[named, row.name], [identities, key]]) {
  let value = map.get(id); if (!value) { value = { name: row.name, source: row.src_file, line: row.src_line, events: 0, inclusiveNs: 0n, threads: new Set() }; map.set(id, value); }
  value.events++; value.inclusiveNs += duration; value.threads.add(row.thread);
 }
}
const phaseNames = ['frame', 'setup', 'advance_batch', 'sort_pack', 'geometry_batch', 'publication', 'counters_summary'].map(name => 'NWNCapture/Particles/' + name);
for (const name of phaseNames) { assert.equal(named.get(name)?.events, 490); assert.deepEqual([...named.get(name).threads], ['1']); }
assert.equal(named.get('NWNCapture/Worker/task_scope')?.events, 123); assert.equal(named.get('NWNCapture/Worker/task_scope').threads.size, 24);
assert.equal(named.get('NWNCapture/Worker/wait_task_scope')?.events, 123); assert.equal(named.get('NWNCapture/Render/sync_scope')?.events, 490);
const reportFile = at('.cache/native-tracy/smoke/wire-a/report.json'), processFile = at('.cache/native-tracy/smoke/wire-a/process-proof.json'), report = read(reportFile), processProof = read(processFile);
assert.equal(report.success, true); assert.deepEqual(report.failures, []); assert.equal(report.connected_seen, true);
assert.equal(report.final_bridge.bytes, 72); assert.equal(report.final_bridge.begun, report.final_bridge.ended);
for (const key of ['invalid_token', 'live_scopes', 'overflow']) assert.equal(report.final_bridge[key], 0);
assert.equal(processProof.success, false); assert.equal(processProof.engineExit, -2147483645); assert.equal(processProof.forced, false);
assert.equal(gpu.length, 0);
const view = value => ({ name: value.name, source: value.source, line: value.line, events: value.events, inclusiveNs: value.inclusiveNs.toString(), exporterThreadIds: [...value.threads] });
const output = {
 version: 1, kind: 'historical-private-tracy-wire-partial-evidence', checkedUtc: new Date().toISOString(),
 evidenceParsed: true, fullIntegrationAccepted: false, lifecycleAccepted: false, performanceAccepted: false,
 inputPins: [...['cpu.tsv', 'summary.tsv', 'self.tsv', 'gpu.tsv'].map(name => pin(path.join(readback, name))), pin(path.join(base, 'capture.tracy')), pin(path.join(base, 'capture-process.json')), pin(path.join(base, 'capture.stdout.log')), pin(path.join(base, 'run-proof.json')), pin(reportFile), pin(processFile), pin(at('.cache/native-tracy/smoke/wire-a/engine.stderr.log')), pin(__filename)],
 rows: { cpu: cpu.length, summary: summary.length, self: self.length, gpu: gpu.length, completedCPU: cpu.length - incomplete, incompleteCPU: incomplete, uniqueNames: named.size, distinctSourceLocations: identities.size },
 capturedCPU: { firstNs: first.toString(), lastNs: last.toString(), spanNs: (last - first).toString(), exporterThreadIds: [...threads], nativePhases: phaseNames.map(name => view(named.get(name))), otherNamedScopes: [...named.values()].filter(value => value.name.startsWith('NWNCapture/') && !phaseNames.includes(value.name)).map(view), scriptScopes: [...identities.values()].filter(value => value.name.startsWith('smoke_')).map(view) },
 captureTool: { processExit: read(path.join(base, 'capture-process.json')).exit, summaryText: fs.readFileSync(path.join(base, 'capture.stdout.log'), 'utf8').trim(), captureRowsCanDifferAtBounds: true },
 bridgeOutsideAndAcrossCapture: report.final_bridge, smokeScript: { success: report.success, failures: report.failures, nativeFrames: report.native_frames, mainFrames: report.main_frames, completedTasks: report.completed, display: report.display, nativeActiveParticles: report.native_empty_summary.active },
 actualLifetimeFailure: { engineExit: processProof.engineExit, hexExit: '0x80000003', forced: false, overallProcessSuccess: processProof.success, standardErrorIncludesFatalThreadRelease: fs.readFileSync(at('.cache/native-tracy/smoke/wire-a/engine.stderr.log'), 'utf8').includes('FATAL: Condition "!is_main_thread_assigned.clear_if_set()" is true.'), globalScriptCacheErrorPresent: true },
 exportQualification: 'Initial wrapper exporter was forced after a null MainModule race; readback-a is a later direct official-tool export. Parent reports all4 direct exports exit0; this directory contains TSV/stderr but no separate retained process-identity/exit receipts, so independent review establishes parsed data and pins rather than a new wrapper acceptance.',
 limits: [
  'Empty headless smoke demonstrates actual CPU-zone and worker-thread visibility, not heavy-area work, live particles, assets, public protocol or graphical fidelity.',
  'Exporter thread integers come from zone_thread_data.Thread(); they are not asserted to be Windows TIDs or Godot logical IDs.',
  'Repeated smoke names have distinct source lines; per-name totals combine those locations. All7 native phases independently have490 captured events.',
  'Native bridge snapshot covers615 smoke frames, beyond the490 exported frame-zone events. Its lifetime totals cannot be equated to exactly exported events.',
  'Zone times are inclusive/nested and must not be summed into frame cost. No GPU events are present.',
  'Valid saved wire data and balanced bridge counters do not excuse engine shutdown failure. The fixed engineC needs its own independent capture/lifetime acceptance.'
 ],
 nativeStarts: 0, exporterExecutions: 0, compilerStarts: 0, installedSelectionChanged: false
};
const out = at('.cache/native-tracy/wire-review-a'); fs.mkdirSync(out, { recursive: true }); const file = path.join(out, 'receipt.json'); fs.writeFileSync(file, JSON.stringify(output, null, 2) + '\n', { flag: 'wx' }); console.log(JSON.stringify({ file, sha256: pin(file).sha256, cpuRows: cpu.length, exporterThreads: threads.size, integrationAccepted: false, engineExit: processProof.engineExit }));
