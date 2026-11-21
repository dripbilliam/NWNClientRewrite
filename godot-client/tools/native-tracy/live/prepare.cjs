'use strict';
// Emits only small source/config overlays. Does not copy the project or binaries.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const { hostSource, runtimeSource, manualArguments } = require('./source.cjs');
const { verifyPlanLineage } = require('./lineage.cjs');
const paths = require('./path-policy.cjs');
const { identityFromPins } = require('../../native-render-gap/transport/live/prepare.cjs');
const MAIN = 'ea3469f0b87fa346acd28c0ffe97bba646601ed567e80d5f8eee03068989ebda';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const pin = file => { const data = fs.readFileSync(file); return { file, sha256: sha(data), bytes: data.length }; };
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
function prepare(label, project = path.resolve(__dirname, '../../..'), engineReceiptRelative = '.cache/native-tracy/engine-msvc-a/engine-build-c/receipt.json', scriptUpdateFile = null) {
 assert(/^[a-z0-9-]+$/.test(label || ''), 'Explicit fresh label required');
 const out = path.join(project, '.cache/native-tracy/live', label); assert(!fs.existsSync(out), 'Preserve prior stage');
 const engineReceiptFile = path.resolve(project, engineReceiptRelative);
 const particleReceiptFile = path.join(project, '.cache/native-tracy/engine-msvc-a/particle-build/receipt.json');
 const engine = read(engineReceiptFile), particle = read(particleReceiptFile);
 for (const receipt of [engine, particle]) { assert.equal(receipt.success, true); assert.equal(receipt.exit, 0); assert.equal(receipt.normalRuntimeChanged, false); assert(/^[a-f0-9]{64}$/.test(receipt.binary.sha256)); }
 const lineage = verifyPlanLineage(engine, particle, MAIN), buildPlan = lineage.leaf;
 const acceptedFile = path.join(project, '.tools/native-core/accepted-core-d.json'), accepted = read(acceptedFile);
 assert.equal(accepted.fullFunctionalFlags.length, 16);
 const baseFile = path.join(project, '.cache/native-render-gap/scene/normal-integration-d-c-a/manifest.json'), base = read(baseFile);
 const normalizedBase = paths.unique(base.pins, 'Base');
 const restored = new Map(normalizedBase.map(row => [paths.key(row.relative), row]));
 for (const relative of ['native_live_world.gd', 'native_session_world.gd', 'tools/native-session-host.cjs']) restored.set(paths.key(relative), { relative, sha256: pin(path.join(project, relative)).sha256 });
 assert.equal(identityFromPins([...restored.values()]).sha256, MAIN, 'Restore normalD product bytes before private tracing changes');
 let selectedSource = MAIN, scriptUpdate = null, scriptUpdates = [];
 if (scriptUpdateFile) {
  scriptUpdateFile = path.resolve(project, scriptUpdateFile); scriptUpdate = read(scriptUpdateFile);
  assert.equal(scriptUpdate.success, true); assert.equal(scriptUpdate.beforeSource, MAIN);
  assert.equal(scriptUpdate.engine.sha256, accepted.engineSha256);
  assert.equal(scriptUpdate.results.length, 4); assert(scriptUpdate.results.every(row => row.success && row.exit === 0));
  assert.deepEqual(scriptUpdate.changed.map(row => row.file), ['systems/native_data/prepared_cache.gd'], 'Only the validated cache-directory fix may enter this update');
  for (const row of scriptUpdate.changed) {
   assert.equal(restored.get(paths.key(row.file)).sha256, row.beforeSha256);
   assert.equal(pin(path.join(project, row.file)).sha256, row.sha256);
   const value = { relative: row.file, sha256: row.sha256 }; scriptUpdates.push(value); restored.set(paths.key(row.file), value);
  }
  selectedSource = identityFromPins([...restored.values()]).sha256; assert.equal(selectedSource, scriptUpdate.afterSource);
 }
 assert.equal(require(path.join(project, 'tools/native-feature-manifest.cjs')).sourceIdentity(project).sha256, selectedSource, 'Current product source must match the validated script closure');
 const config = { version: 1, project, out, view: path.join(out, 'project'), baseProject: base.candidate, run: 'native-tracy-' + label, expectedMainSourceIdentity: selectedSource, expectedEngineSourceIdentity: MAIN,
  engineRelative: '.tools/native-tracy/Godot_native_d_tracy_win64.exe', descriptorRelative: '.tools/native-tracy/runtime.json', node: process.execPath,
  electron: path.join(path.dirname(project), 'node_modules/electron/dist/electron.exe'), userdata: path.join(out, 'working-settings'), appdata: path.join(out, 'working-appdata'), localappdata: path.join(out, 'working-localappdata'),
  host: path.join(project, 'tools/native-session-host.cjs'), bootstrap: path.join(project, 'tools/native-session-bootstrap.cjs'), source: path.join(out, 'source') };
 config.engineLaunch = path.join(config.view, config.engineRelative); config.hostSha256 = pin(config.host).sha256; config.bootstrapSha256 = pin(config.bootstrap).sha256;
 if (scriptUpdateFile) config.scriptUpdateProof = pin(scriptUpdateFile);
 const descriptor = { version: 1, kind: 'private-tracy-native-bundle', production: false, accepted: false, performanceAccepted: false,
  engineSha256: engine.binary.sha256, engineBytes: engine.binary.bytes, nativeKernelSha256: particle.binary.sha256, originalGameAssetsPacked: false, fullFunctionalFlags: [...accepted.fullFunctionalFlags],
  acceptedReference: { source: MAIN, descriptor: pin(acceptedFile), engineSha256: accepted.engineSha256, nativeKernelSha256: accepted.nativeKernelSha256, relation: 'Accepted D functional source/flags; actual diagnostic binaries differ explicitly' },
  engineBuildProof: { receipt: pin(engineReceiptFile), plan: pin(engine.plan), particleReceipt: pin(particleReceiptFile), sourceOverlay: buildPlan.overlay, reconstruction: buildPlan.reconstruction, planLineage: lineage.chain, engineToDllRelation: lineage.relation },
  tracing: { singleClient: 'engine-only', mode: 'on-demand', version: '0.13.0', port: buildPlan.port, gpuZones: false, memoryTracing: false, systemTracing: false, callstackSampling: false },
  currentScriptSource: selectedSource,
  scope: 'Manual private diagnostic selection, pending real native startup/capture/lifetime acceptance. No normal binary promotion or performance claim.' };
 assert(Number.isSafeInteger(descriptor.engineBytes) && descriptor.engineBytes > 0);
 const descriptorData = Buffer.from(JSON.stringify(descriptor, null, 2) + '\n');
 const descriptorSha256 = sha(descriptorData), overlayPins = [], binaries = [
  { relative: config.engineRelative, source: engine.binary.file, sha256: engine.binary.sha256, bytes: engine.binary.bytes },
  { relative: '.cache/native-kernel/nwn-particle-kernel.dll', source: particle.binary.file, sha256: particle.binary.sha256 }
 ];
 const put = (relative, data) => { relative = paths.relative(relative); assert(!overlayPins.some(row => paths.key(row.relative) === paths.key(relative)), 'Duplicate source override'); const file = path.join(out, 'overrides', relative); fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, data, { flag: 'wx' }); const row = { relative, ...pin(file) }; overlayPins.push(row); return row; };
 put(config.descriptorRelative, descriptorData);
 const runtime = runtimeSource(fs.readFileSync(path.join(project, 'tools/native-performance-runtime.cjs'), 'utf8'), descriptor, descriptorSha256, config);
 put('tools/native-performance-runtime.cjs', Buffer.from(runtime));
 const host = hostSource(fs.readFileSync(config.host, 'utf8'), config), hostPin = put('tools/native-session-host.cjs', Buffer.from(host)); config.compiledHost = hostPin.file; config.compiledHostSha256 = hostPin.sha256;
 for (const relative of ['native_live_world.gd', 'native_session_world.gd']) put(relative, fs.readFileSync(path.join(project, relative)));
 for (const row of scriptUpdates) put(row.relative, fs.readFileSync(path.join(project, row.relative)));
 for (const row of buildPlan.particlePins) { assert.equal(pin(row.file).sha256, row.sha256); put('native/' + row.relative, fs.readFileSync(row.file)); }
 put('.cache/native-kernel/build-manifest.json', Buffer.from(JSON.stringify({ version: 1, kind: 'private-tracy-diagnostic-build-provenance', normalEnsureBuildSupported: false, nativeReceipt: pin(particleReceiptFile), sourcePlan: pin(engine.plan), binary: particle.binary, scope: 'Actual diagnostic DLL build; do not rebuild using the normal installed ensure policy' }, null, 2) + '\n'));
 const targetPlan = paths.plan(normalizedBase, overlayPins, binaries);
 const all = new Map([...restored.values()].map(row => [paths.key(row.relative), row])); for (const row of [...targetPlan.overlay, ...targetPlan.binaries]) all.set(paths.key(row.relative), { relative: row.relative, sha256: row.sha256 });
 config.predictedSourceIdentity = identityFromPins([...all.values()]).sha256;
 config.engineSha256 = descriptor.engineSha256; config.particleSha256 = descriptor.nativeKernelSha256; config.descriptorSha256 = descriptorSha256;
 config.bootstrapArguments = [config.bootstrap, ...manualArguments(config.run)];
 const launchPins = [];
 fs.mkdirSync(config.source, { recursive: true });
 for (const name of ['source.cjs', 'prepare.cjs', 'lineage.cjs', 'path-policy.cjs', 'materialize.cjs', 'verify.cjs', 'bootstrap-preload.cjs', 'host-preload.cjs', 'launch.ps1', 'README.txt']) {
  const file = path.join(config.source, name); fs.copyFileSync(path.join(__dirname, name), file, fs.constants.COPYFILE_EXCL); launchPins.push(pin(file));
 }
 const storageFile = path.join(config.source, 'storage-policy.cjs'); fs.copyFileSync(path.join(project, 'tools/native-render-gap/transport/live/storage-policy.cjs'), storageFile, fs.constants.COPYFILE_EXCL); launchPins.push(pin(storageFile));
 config.screenHelper = path.join(config.source, 'native-window-screen.ps1'); fs.copyFileSync(path.join(project, 'tools/native-window-screen.ps1'), config.screenHelper, fs.constants.COPYFILE_EXCL); launchPins.push(pin(config.screenHelper));
 const identitySource = 'module.exports.identityFromPins=' + identityFromPins.toString() + ';\n';
 // The original helper closes over constants. Freeze an equivalent standalone reader.
 const identityFile = path.join(config.source, 'identity.cjs');
 const identityOriginal = fs.readFileSync(path.join(project, 'tools/native-render-gap/transport/live/prepare.cjs'), 'utf8');
 const specialLine = identityOriginal.split('\n').find(line => line.startsWith('const special=')); assert(specialLine);
 fs.writeFileSync(identityFile, "const crypto=require('node:crypto');const sha=b=>crypto.createHash('sha256').update(b).digest('hex');\n" + specialLine + '\n' + identitySource, { flag: 'wx' }); launchPins.push(pin(identityFile));
 const configFile = path.join(out, 'config.json'); fs.writeFileSync(configFile, JSON.stringify(config, null, 2) + '\n', { flag: 'wx' });
 const manifest = { version: 1, kind: 'private-tracy-manual-source-plan', status: 'SOURCE_READY_UNMATERIALIZED_NATIVE_UNPARSED', createdUtc: new Date().toISOString(), source: selectedSource,
  config: pin(configFile), base: { ...pin(baseFile), project: base.candidate, pinnedFiles: base.pins.length }, diagnosticDescriptor: { relative: config.descriptorRelative, sha256: descriptorSha256 },
  sourceReceipts: { engine: pin(engineReceiptFile), particle: pin(particleReceiptFile), plan: pin(engine.plan) }, planLineage: lineage.chain, engineToDllRelation: lineage.relation, overlayPins, binaries, launchPins,
  scriptUpdateProof: scriptUpdateFile ? pin(scriptUpdateFile) : null, scriptUpdates,
  predictedSourceIdentity: config.predictedSourceIdentity, runtimeNativeAcceptance: false, captureAcceptance: false, publicConnections: 0, processStarts: 0, installedSelectionChanged: false,
  storage: 'Independent copies of active code/native/engine; only five exact immutable REA dossiers may link. No materialization or settings access in this prepare step.',
  scope: 'Genuine private runtime/descriptor selection with ordinary protocol/auth/login flow. Source-only readiness, no public login, launch or performance acceptance.' };
 const file = path.join(out, 'manifest.json'); fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + '\n', { flag: 'wx' });
 return { ...pin(file), config: configFile, status: manifest.status, overlayFiles: overlayPins.length, plannedProjectFiles: base.pins.length, processStarts: 0 };
}
module.exports = { prepare, MAIN };
if (require.main === module) console.log(JSON.stringify(prepare(process.argv[2], undefined, undefined, process.argv[3] || null)));
