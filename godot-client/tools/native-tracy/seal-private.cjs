'use strict';
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict'), crypto = require('node:crypto');
const project = path.resolve(__dirname, '../..');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const pin = file => ({ file, sha256: sha(file) });
const file = relative => path.join(project, relative);
const configFile = path.resolve(process.argv[2]), config = read(configFile);
require(path.join(config.source, 'verify.cjs')).verify(configFile);
const evidence = {};
function proof(name, relative) { const source = file(relative), data = read(source); evidence[name] = pin(source); assert.equal(data.success, true, name); return data; }
const native = proof('native', path.relative(project, path.join(config.out, 'native-checks-a/acceptance.json')));
const graphical = proof('graphical', path.relative(project, path.join(config.out, 'graphical-check-a/process-proof.json')));
const graphReport = proof('graphicalOutput', path.relative(project, path.join(config.out, 'graphical-check-a/report.json')));
const headless = proof('headless', '.cache/native-tracy/smoke/wire-b/process-proof.json');
const smoke = proof('bridge', '.cache/native-tracy/smoke/wire-b/report.json');
const headTrace = proof('headlessTrace', '.cache/native-tracy/captures/headless-wire-b/trace-acceptance.json');
const graphTrace = proof('graphicalTrace', '.cache/native-tracy/captures/graphical-wire-a/trace-acceptance.json');
for (const value of [headless, graphical]) { assert.equal(value.engineExit, 0); assert.equal(value.forced, false); }
assert.equal(headless.captureExit, 0);
assert.equal(native.stageManifestSha256, sha(path.join(config.out, 'manifest.json')));
assert.equal(graphical.stageManifestSha256, native.stageManifestSha256);
for (const value of [headTrace, graphTrace]) {
 assert.equal(value.client.sha256, config.engineSha256); assert.equal(value.client.connectionObserved, true);
 assert(value.cpu.completedEvents > 0); assert(value.cpu.threadIds.length > 1); assert.equal(value.gpu.required, false);
 assert.equal(sha(value.trace.file), value.trace.sha256);
}
assert(graphReport.pixels > 0); assert.equal(graphReport.network_connections, 0);
const normalPins = [
 ['.tools/native-core/Godot_native_core_d_win64.exe', '10b24711d277f745ad72cc504b6a3e573c12bb1ce1be7fd8545faabab82b9f13'],
 ['.tools/native-core/accepted-core-d.json', '5b76f260b5c65f18fcaa332ce806f2843325e08ec218f751652dd545689c579e'],
 ['.cache/native-kernel/nwn-particle-kernel.dll', '485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d'],
 ['.cache/native-resource-index/nwn-resource-index.dll', 'f2ac66d99c91368613e07c2474f37947663f3f8773d482c9ad3ac65014050da5']
].map(([relative, expected]) => { const source = file(relative); assert.equal(sha(source), expected); return pin(source); });
const accepted = { version: 1, createdUtc: new Date().toISOString(), stageManifestSha256: native.stageManifestSha256,
 nativeParsed: true, functionalPassed: true, bridgePassed: true, lifetimePassed: true, manuallyReviewed: true,
 graphicalCPUTracePassed: true, originalTexturePixelCheckPassed: true, publicConnections: 0,
 manualHostSessionTested: false, arelithTested: false, performanceAccepted: false, normalRuntimeChanged: false,
 normalPins, evidence, headlessTrace: headTrace.trace, graphicalTrace: graphTrace.trace,
 coverage: ['Godot CPU named zones', 'GDScript CPU scopes', 'main/render/worker CPU timelines', 'engine-owned C ABI native particle phase bridge'],
 limits: ['Local fixture validation; no Arelith or manual host/login session yet.', 'GPU timestamp zones and statistical stack sampling are not enabled.', 'Tracy compressed thread IDs are not Windows thread IDs or proof of simultaneous core utilization.', 'Instrumented MSVC source-equivalent diagnostic build is not accepted as a normal FPS comparison.'],
 scope: 'Exact private stage passed parser/capability/32-lamp owner checks, real native bridge capture, graphical compositor/pixel output and clean shutdown. Normal client remains selected.' };
const target = path.join(config.out, 'native-acceptance.json');
fs.writeFileSync(target, JSON.stringify(accepted, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify({ success: true, acceptance: pin(target), headlessCPUEvents: headTrace.cpu.completedEvents, graphicalCPUEvents: graphTrace.cpu.completedEvents, normalUnchanged: true }));
