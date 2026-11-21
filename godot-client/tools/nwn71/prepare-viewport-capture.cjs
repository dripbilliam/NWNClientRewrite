'use strict';

// Stage one original-area attribution capture. This does not launch a client.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const oldFile = path.join(root, '.cache/nwn71/render-pump-entry-a/run-proposal.json');
const oldSha = '34b688a67908762469491bc4886e99d617a8cf1aeb57d35b81e2cbea0a107d0b';
assert.equal(sha(oldFile), oldSha, 'Earlier reviewed capture proposal changed');
const old = JSON.parse(fs.readFileSync(oldFile));
const preparationFile = path.join(root, '.cache/nwn71/viewport-entry-a/preparation.json');
assert.equal(sha(preparationFile), 'debde1fb3d362fb63c7f52770777d3f61fb963272c13e201a6dc029fc9cf73db');
const preparation = JSON.parse(fs.readFileSync(preparationFile));
const selection = preparation.selection;
assert.equal(sha(selection.file), selection.sha256);
assert.equal(preparation.runtime.engineSha256, 'fcd6452c3de46dd4592142a2db4c4ed64f559215e04b1369b170da2bba00c04b');
assert.equal(sha(path.join(root, 'tools/replay-native-loading.mjs')), old.replay.driverSha256);
assert.equal(sha(old.capture.executable), old.capture.sha256);

const captureDir = path.join(root, '.cache/nwn71/capture-viewport-entry-a');
const proposalFile = path.join(root, '.cache/nwn71/viewport-entry-a/run-proposal.json');
assert(!fs.existsSync(captureDir) && !fs.existsSync(proposalFile), 'Preserve existing capture or proposal');
const replayArguments = old.replay.arguments.map(arg => {
	if (arg.startsWith('--production-selection=')) return '--production-selection=' + selection.file;
	if (arg.startsWith('--production-selection-sha256=')) return '--production-selection-sha256=' + selection.sha256;
	if (arg.startsWith('--run=')) return '--run=nwn71-viewport-entry-a';
	return arg;
});
assert(replayArguments.includes('--preview') && replayArguments.includes('--profiling=false'));
const captureArguments = old.capture.arguments.slice();
const outputIndex = captureArguments.indexOf('-o');
assert(outputIndex >= 0);
captureArguments[outputIndex + 1] = path.join(captureDir, 'entry.tracy');
const proposal = {
	...old,
	schema: 'nwn71-one-viewport-stage-entry-proposal-v1',
	preparation: { file: preparationFile, sha256: sha(preparationFile) },
	selection,
	replay: { ...old.replay, arguments: replayArguments },
	capture: { ...old.capture, arguments: captureArguments },
	engine: { sha256: preparation.runtime.engineSha256, kind: 'private-tracy-diagnostic' },
	nativeDllSha256: preparation.runtime.dllSha256,
	orchestration: 'ROOT pauses all workers, runs ONE original gen4 20s replay with private viewport stage labels on secondary screen, and captures Tracy within existing memory/time limits. No other client or profiler process.',
	acceptance: 'Same sealed source/runtime/driver/preferences/camera/protocol/completion gates as the prior pump entry. Attribute 3D/2D/setup costs within the render-thread viewport draw. No normal-build FPS gain is inferred.',
	scope: 'Exact frozen reviewedB+63 original-entry source; only private diagnostic EXE/descriptor/runtime substitutions. Source-only proposal; no launch or FPS measurement.'
};
fs.writeFileSync(proposalFile, JSON.stringify(proposal, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify({ proposal: proposalFile, sha256: sha(proposalFile), selection: selection.sha256, engine: proposal.engine.sha256, capture: captureArguments[outputIndex + 1], launches: 0 }));
