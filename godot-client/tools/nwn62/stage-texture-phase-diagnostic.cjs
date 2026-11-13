'use strict';
// Stage a source-pinned private texture-phase probe. Does not launch a client.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const scope = path.join(root, '.cache/nwn62/texture-phase-diagnostic-a');
const probeScope = path.join(root, '.cache/nwn62/texture-phase-probe-a');
const referenceFile = path.join(root, '.cache/native-presentation-parity/production-replay/nwn61-current-entry-staged-a/production-selection.json');
const captureFile = path.join(root, '.cache/nwn74/base-merge-pair-a/staged.json');
const relative = 'systems/native_render/resource_pool.gd';
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
async function main() {
  const probe = JSON.parse(fs.readFileSync(path.join(probeScope, 'manifest.json')));
  assert(probe.private && !probe.accepted && probe.issue === 'NWN-62');
  assert.equal(probe.source, relative);
  assert.equal(sha(path.join(root, relative)), probe.sourceSha256);
  assert.equal(sha(path.join(root, probe.overlay)), probe.overlaySha256);
  const reference = JSON.parse(fs.readFileSync(referenceFile));
  const captured = JSON.parse(fs.readFileSync(captureFile));
  assert.equal(sha(path.join(captured.capture, 'recording.json')), captured.recordingSha256);
  const seeds = {version: 1, expected: reference.preferences.expected, description: 'NWN-62 texture-phase diagnostic; same original-scene preferences'};
  for (const name of ['render', 'layout']) seeds[name] = {file: reference.preferences[name].source, sha256: reference.preferences[name].sha256};
  const argv = [...reference.options];
  const helper = require(path.join(root, 'tools/native-production-selection.cjs'));
  if (process.argv.includes('--verify-only')) {
    console.log(JSON.stringify({issue: 'NWN-62', private: true, accepted: false, clientStarts: 0, sourceSha256: probe.sourceSha256, overlaySha256: probe.overlaySha256, recordingSha256: captured.recordingSha256, options: argv}, null, 2));
    return;
  }
  assert(!fs.existsSync(scope), 'Preserve prior private diagnostic stage');
  const control = await helper.stageProductionSelection({project: root, label: 'nwn62-texture-phase-control-a', argv, preferenceSeeds: seeds, env: {}});
  fs.mkdirSync(scope, {recursive: true});
  const candidateInput = path.join(scope, 'candidate-input');
  fs.cpSync(control.selection.sourceProject, candidateInput, {recursive: true, errorOnExist: true, force: false});
  fs.copyFileSync(path.join(root, probe.overlay), path.join(candidateInput, relative));
  for (const engineFile of ['.tools/native-core/Godot_native_core_e_win64.exe', '.tools/native-core/accepted-core-e.json']) {
    const target = path.join(candidateInput, engineFile);
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.linkSync(path.join(root, engineFile), target);
  }
  const candidateHelper = require(path.join(candidateInput, 'tools/native-production-selection.cjs'));
  const candidate = await candidateHelper.stageProductionSelection({project: candidateInput, label: 'nwn62-texture-phase-candidate-a', argv, preferenceSeeds: seeds, env: {}});
  await helper.readProductionSelection(control.file, control.sha256);
  await candidateHelper.readProductionSelection(candidate.file, candidate.sha256);
  assert.equal(control.selection.runtime.executableSha256, candidate.selection.runtime.executableSha256);
  assert.equal(control.selection.preferences.render.sha256, candidate.selection.preferences.render.sha256);
  assert.equal(control.selection.preferences.layout.sha256, candidate.selection.preferences.layout.sha256);
  const a = new Map(control.selection.mainSourceIdentity.files.map(row => [row.file, row.sha256]));
  const b = new Map(candidate.selection.mainSourceIdentity.files.map(row => [row.file, row.sha256]));
  assert.deepEqual([...a.keys()].sort(), [...b.keys()].sort());
  assert.deepEqual([...a.keys()].filter(file => a.get(file) !== b.get(file)), [relative]);
  const receipt = {version: 1, issue: 'NWN-62', private: true, accepted: false, capture: captured.capture, recordingSha256: captured.recordingSha256, engineSha256: control.selection.runtime.executableSha256, changed: [relative], sourceSha256: probe.sourceSha256, overlaySha256: probe.overlaySha256, selections: {control: {file: control.file, sha256: control.sha256, sourceIdentity: control.selection.mainSourceIdentity.sha256}, candidate: {file: candidate.file, sha256: candidate.sha256, sourceIdentity: candidate.selection.mainSourceIdentity.sha256}}, scope: 'Original-scene no-FPS texture phase attribution; only private ResourcePool probe differs. Neither source nor artifact is accepted.'};
  fs.writeFileSync(path.join(scope, 'staged.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
  console.log(JSON.stringify({stage: path.join(scope, 'staged.json'), control: receipt.selections.control.sourceIdentity, candidate: receipt.selections.candidate.sourceIdentity, changed: receipt.changed, clientStarts: 0}));
}
main().catch(error => {console.error(error.stack); process.exitCode = 1;});
