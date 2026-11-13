'use strict';
// NWN-74 matched normal-client pair. Verify only unless coordinator runs a
// planned label during an exclusive FPS lease.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { spawn, spawnSync, execFile } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const scope = path.join(root, '.cache/nwn74/vertex-cache-pair');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const driver = path.join(__dirname, 'replay-vertex-cache-pair.mjs');
const driverSha = 'e573c37c0102c97c28df5e2275b9bb7b043517308792a809f1beb89f16dc0b9f';
const selectionFile = path.join(root, '.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json');
const selectionSha = '522506865b61b04ff4e810f805488135d5ba65099adf9f7acdd4b9660d138079';
const capture = 'C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf';
const captureSha = '1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463';
const receiptFile = path.join(root, '.cache/nwn74/engine-build-i-cache/receipt.json');
const engineSha = '3d0e9e6ed669c0c936405332b6e576031a3b65adfaec10494308edc71c05fca7';
const modes = ['off', 'on', 'on', 'off'];
const runs = modes.map((mode, index) => ({ run: `nwn74-vertex-cache-${String.fromCharCode(97 + index)}-${mode}`, mode }));

function verify() {
  assert.equal(sha(driver), driverSha);
  assert.equal(sha(selectionFile), selectionSha);
  assert.equal(sha(path.join(capture, 'recording.json')), captureSha);
  assert.equal(sha(path.join(root, '.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe')), '0a2710bd80c0a2cbfeca8ac28338a071561ba741c52a01857df233d69efe02d1');
  assert.equal(sha(path.join(root, '.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp')), 'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd');
  assert.equal(sha(path.join(root, '.cache/nwn74/source-vertex-cache-i.cpp')), '05b7e8379000b331fbb26dedc9577b594eca7d09d7ea7872cbc54078b3837e74');
  const receipt = JSON.parse(fs.readFileSync(receiptFile));
  assert(receipt.success && receipt.sourceUnchanged && receipt.acceptedUnchanged && receipt.guardUnchanged);
  assert.equal(receipt.binary.sha256, engineSha);
  assert.equal(sha(receipt.binary.file), engineSha);
  const selection = JSON.parse(fs.readFileSync(selectionFile));
  assert(selection.complete && selection.production && selection.profiling === 'false');
  const sequence = runs.map(({ run, mode }) => ({
    run, mode,
    argv: [process.execPath, driver, `--capture=${capture}`, '--generation=2', `--production-selection=${selectionFile}`, `--production-selection-sha256=${selectionSha}`, '--engine=production-selection', '--profiling=false', '--observe-profile=false', '--steady-ms=15000', '--preview', `--nwn74-mode=${mode}`, `--run=${run}`],
    environment: { NWN74_VERTEX_CACHE: mode === 'on' ? '1' : '0', NWN74_VERTEX_CACHE_CENSUS: '0' }
  }));
  for (const entry of sequence) {
    // Replay verify-only rejects an existing run prefix by design. A completed
    // leg is instead covered by its immutable receipt and summary assertions.
    if (fs.existsSync(path.join(root, 'reports', entry.run + '.json'))) {
      assert(fs.existsSync(path.join(scope, entry.run + '.receipt.json')), 'Completed leg lacks receipt: ' + entry.run);
      continue;
    }
    const probe = spawnSync(process.execPath, [...entry.argv.slice(1), '--verify-only'], { cwd: root, windowsHide: true, env: { ...process.env, ...entry.environment }, encoding: 'utf8', timeout: 30000 });
    assert.equal(probe.status, 0, probe.stderr);
    const result = JSON.parse(probe.stdout);
    assert(result.complete && result.events === 5704 && result.catalogs === 1 && result.networkConnections === 0);
  }
  return { issue: 'NWN-74', scope: 'Same private engine, vertex cache off/on, ABBA matched normal-client FPS pair', execution: 'verify-only until coordinator grants exclusive lease', driverSha, selectionSha, captureSha, receiptSha: sha(receiptFile), engineSha, sequence, runtimeLimitMs: 240000, memoryLimitBytes: 8 * 1024 ** 3 };
}

function memoryProbe() {
  const script = "$p=Get-Process -Name 'Godot_nwn74_vertex_cache_i_win64' -ErrorAction SilentlyContinue; if($p){[long](($p | Measure-Object -Property PrivateMemorySize64 -Sum).Sum)} else {0}";
  return new Promise((resolve, reject) => execFile('pwsh', ['-NoProfile', '-Command', script], { windowsHide: true, timeout: 5000 }, (error, output) => error ? reject(error) : resolve(Number(output.trim()) || 0)));
}

async function runOne(plan, label) {
  const entry = plan.sequence.find(row => row.run === label);
  assert(entry, 'Only a planned run label is allowed');
  const reportFile = path.join(root, 'reports', entry.run + '.json');
  const resultFile = path.join(scope, entry.run + '.receipt.json');
  const logFile = path.join(scope, entry.run + '.driver.log');
  for (const file of [reportFile, resultFile, logFile]) assert(!fs.existsSync(file), 'Preserve previous output: ' + file);
  const log = fs.createWriteStream(logFile, { flags: 'wx' });
  const child = spawn(process.execPath, entry.argv.slice(1), { cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, ...entry.environment } });
  for (const stream of [child.stdout, child.stderr]) stream.on('data', bytes => log.write(bytes));
  let peakPrivateBytes = 0, haltReason = null, checking = false;
  const started = Date.now();
  const stop = reason => { if (haltReason) return; haltReason = reason; execFile('taskkill', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true }, () => {}); };
  const timer = setInterval(async () => {
    if (Date.now() - started > plan.runtimeLimitMs) return stop('240-second watchdog');
    if (checking) return;
    checking = true;
    try { const bytes = await memoryProbe(); peakPrivateBytes = Math.max(peakPrivateBytes, bytes); if (bytes > plan.memoryLimitBytes) stop('Private engine exceeded 8 GiB'); }
    catch (error) { stop('Memory guard unavailable: ' + error.message); }
    finally { checking = false; }
  }, 3000);
  const exit = await new Promise((resolve, reject) => { child.once('error', reject); child.once('exit', resolve); });
  clearInterval(timer);
  await new Promise(resolve => log.end(resolve));
  const report = fs.existsSync(reportFile) ? JSON.parse(fs.readFileSync(reportFile)) : null;
  const result = { issue: 'NWN-74', run: entry.run, mode: entry.mode, exit, haltReason, peakPrivateBytes, report: reportFile, reportSha: report ? sha(reportFile) : null, rawSuccess: report?.success ?? false, rawFailure: report?.failure ?? null, sourceUnchanged: report?.sourceUnchanged ?? null, runtimeUnchanged: report?.runtimeUnchanged ?? null, fpsObservations: report?.fpsObservations ?? null, engineSha, selectionSha, captureSha };
  fs.writeFileSync(resultFile, JSON.stringify(result, null, 2) + '\n', { flag: 'wx' });
  console.log(JSON.stringify({ resultFile, exit, haltReason, rawSuccess: result.rawSuccess, rawFailure: result.rawFailure, fpsSamples: result.fpsObservations?.samples ?? 0, peakPrivateBytes }));
  if (haltReason || !report || report.sourceUnchanged !== true || report.runtimeUnchanged !== true || (result.fpsObservations?.samples ?? 0) < 3) process.exitCode = 1;
}

async function main() {
  const plan = verify();
  fs.mkdirSync(scope, { recursive: true });
  const planFile = path.join(scope, 'plan.json');
  if (fs.existsSync(planFile)) assert.deepEqual(JSON.parse(fs.readFileSync(planFile)), plan);
  else fs.writeFileSync(planFile, JSON.stringify(plan, null, 2) + '\n', { flag: 'wx' });
  const label = process.argv.find(arg => arg.startsWith('--run='))?.slice(6);
  if (!label) { console.log(JSON.stringify({ verified: true, planFile, planSha: sha(planFile), sequence: plan.sequence.map(({ run, mode }) => ({ run, mode })), execution: plan.execution })); return; }
  await runOne(plan, label);
}
main().catch(error => { console.error(error.stack); process.exitCode = 1; });
