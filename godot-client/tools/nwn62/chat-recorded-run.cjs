'use strict';
// One headless recorded-entry diagnostic; no graphical/FPS window is requested.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const scope = path.join(root, '.cache/nwn62/chat-recorded-a');
const stageFile = path.join(scope, 'staged.json');
const stage = JSON.parse(fs.readFileSync(stageFile));
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const run = 'nwn62-chat-recorded-a';

async function main() {
 assert(stage.private && stage.headlessOnly && !stage.accepted && stage.issue === 'NWN-62');
 assert.deepEqual(stage.changed, ['systems/native_chat_hud.gd']);
 assert.equal(sha(path.join(stage.capture, 'recording.json')), stage.recordingSha256);
 assert.equal(sha(path.join(root, stage.overlay.file)), stage.overlay.beforeSha256, 'Reviewed source changed');
 const helper = require(path.join(root, 'tools/native-production-selection.cjs'));
 const control = await helper.readProductionSelection(stage.selections.control.file, stage.selections.control.sha256);
 const candidate = await helper.readProductionSelection(stage.selections.candidate.file, stage.selections.candidate.sha256);
 assert.equal(candidate.runtime.executableSha256, stage.engineSha256);
 assert.equal(control.runtime.executableSha256, stage.engineSha256);
 assert.deepEqual(control.options, candidate.options);
 assert.deepEqual(control.flags, candidate.flags);
 assert.equal(sha(path.join(candidate.sourceProject, stage.overlay.file)), stage.overlay.afterSha256);
 const argv = [
  path.join(root, 'tools/replay-native-loading.mjs'),
  '--capture=' + stage.capture, '--generation=' + stage.generation,
  '--production-selection=' + stage.selections.candidate.file,
  '--production-selection-sha256=' + stage.selections.candidate.sha256,
  '--engine=production-selection', '--profiling=false', '--headless', '--preview',
  '--publication-completion-diagnose', '--run=' + run
 ];
 const plan = {stageSha256: sha(stageFile), sourceSignature: candidate.mainSourceIdentity.sha256, engineSha256: stage.engineSha256,
  recordingSha256: stage.recordingSha256, headless: true, profiling: false, steadyMs: null, preview: true,
  publicationCompletionDiagnose: true, chatProbeViaPrivateAlias: true, argv};
 if (process.argv.includes('--verify-only')) {console.log(JSON.stringify({...plan, clientStarts: 0})); return;}
 const report = path.join(root, 'reports', run + '.json');
 const log = path.join(scope, 'driver.log');
 assert(!fs.existsSync(report) && !fs.existsSync(log), 'Preserve prior diagnostic run');
 const output = fs.createWriteStream(log, {flags: 'wx'});
 const child = spawn(process.execPath, argv, {cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']});
 for (const stream of [child.stdout, child.stderr]) stream.on('data', chunk => output.write(chunk));
 const exit = await new Promise((resolve, reject) => {child.once('error', reject); child.once('exit', resolve);});
 await new Promise(resolve => output.end(resolve));
 const receipt = {plan, run, exit, report, reportSha256: fs.existsSync(report) ? sha(report) : null,
  engineLog: path.join(root, 'reports', run + '.engine.log'), driverLog: log, driverLogSha256: sha(log)};
 fs.writeFileSync(path.join(scope, 'run-receipt.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
 console.log(JSON.stringify({run, exit, report, reportSha256: receipt.reportSha256, driverLog: log}));
}
main().catch(error => {console.error(error.stack); process.exitCode = 1;});
