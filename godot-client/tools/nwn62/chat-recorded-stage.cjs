'use strict';
// Immutable headless recorded-entry source selection. No client launch here.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const scope = path.join(root, '.cache/nwn62/chat-recorded-a');
const reference = JSON.parse(fs.readFileSync(path.join(root, '.cache/native-presentation-parity/production-replay/nwn61-current-entry-staged-a/production-selection.json')));
const capture = JSON.parse(fs.readFileSync(path.join(root, '.cache/nwn62/worker-texture-pair-c/staged.json')));
const helper = require(path.join(root, 'tools/native-production-selection.cjs'));
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const relative = 'systems/native_chat_hud.gd';
const oldFlag = 'OS.get_cmdline_user_args().has("--nwn62-chat-activation-phases")';
const newFlag = 'OS.get_cmdline_user_args().has("--publication-completion-diagnose")';

async function main() {
 assert(!fs.existsSync(scope), 'Preserve prior stage');
 assert.equal(sha(path.join(capture.capture, 'recording.json')), capture.recordingSha256);
 const original = fs.readFileSync(path.join(root, relative), 'utf8');
 assert.equal(original.split(oldFlag).length, 2, 'Expected exactly one reviewed phase flag');
 assert(original.includes('NWN62_CHAT_ACTIVATION_PHASES'));
 const seeds = {version: 1, expected: reference.preferences.expected, description: 'NWN-62 headless recorded-entry chat completion attribution'};
 for (const name of ['render', 'layout']) seeds[name] = {file: reference.preferences[name].source, sha256: reference.preferences[name].sha256};
 const argv = reference.options;
 const control = await helper.stageProductionSelection({project: root, label: 'nwn62-chat-recorded-control-a', argv, preferenceSeeds: seeds, env: {}});
 fs.mkdirSync(scope, {recursive: true});
 const input = path.join(scope, 'candidate-input');
 fs.cpSync(control.selection.sourceProject, input, {recursive: true, errorOnExist: true, force: false});
 assert.equal(sha(path.join(input, relative)), sha(path.join(root, relative)));
 fs.writeFileSync(path.join(input, relative), original.replace(oldFlag, newFlag));
 for (const name of ['.tools/native-core/Godot_native_core_e_win64.exe', '.tools/native-core/accepted-core-e.json']) {
  const target = path.join(input, name); fs.mkdirSync(path.dirname(target), {recursive: true}); fs.linkSync(path.join(root, name), target);
 }
 const candidateHelper = require(path.join(input, 'tools/native-production-selection.cjs'));
 const candidate = await candidateHelper.stageProductionSelection({project: input, label: 'nwn62-chat-recorded-candidate-a', argv, preferenceSeeds: seeds, env: {}});
 await helper.readProductionSelection(control.file, control.sha256);
 await candidateHelper.readProductionSelection(candidate.file, candidate.sha256);
 assert.equal(control.selection.runtime.executableSha256, candidate.selection.runtime.executableSha256);
 assert.deepEqual(control.selection.options, candidate.selection.options);
 assert.deepEqual(control.selection.flags, candidate.selection.flags);
 const before = new Map(control.selection.mainSourceIdentity.files.map(row => [row.file, row.sha256]));
 const changed = candidate.selection.mainSourceIdentity.files.filter(row => before.get(row.file) !== row.sha256).map(row => row.file);
 assert.deepEqual(changed, [relative]);
 assert.equal(sha(path.join(input, relative)), sha(path.join(candidate.selection.sourceProject, relative)));
 const stage = {
  issue: 'NWN-62', private: true, headlessOnly: true, accepted: false,
  scope: 'Exact current source plus a private one-line flag alias to activate both existing diagnostics in one recorded entry. No production source edit.',
  capture: capture.capture, recordingSha256: capture.recordingSha256, generation: 2,
  engineSha256: control.selection.runtime.executableSha256,
  overlay: {file: relative, beforeSha256: sha(path.join(root, relative)), afterSha256: sha(path.join(input, relative)), oldFlag, newFlag},
  changed,
  selections: {
   control: {file: control.file, sha256: control.sha256, sourceSignature: control.selection.mainSourceIdentity.sha256},
   candidate: {file: candidate.file, sha256: candidate.sha256, sourceSignature: candidate.selection.mainSourceIdentity.sha256}
  }
 };
 const file = path.join(scope, 'staged.json'); fs.writeFileSync(file, JSON.stringify(stage, null, 2) + '\n', {flag: 'wx'});
 process.stdout.write(JSON.stringify({file, sha256: sha(file), changed, engineSha256: stage.engineSha256}) + '\n');
}
main().catch(error => {console.error(error.stack); process.exitCode = 1;});
