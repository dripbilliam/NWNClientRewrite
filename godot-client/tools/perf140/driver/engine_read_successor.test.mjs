import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {engineReadSourceComposition, engineReadV2BuildInvocation, CONSUMER_V2_MANIFEST_SHA, CONSUMER_V2_BUILDER_SHA} from './engine_read_successor.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const agent = path.join(root, '.cache/native-140fps/particles-agent');
const sha = value => createHash('sha256').update(value).digest('hex');
const overlayBytes = fs.readFileSync(path.join(agent, 'synchronous-engine-read-integration-v1/source-overlay.json'));
const successorBytes = fs.readFileSync(path.join(agent, 'synchronous-engine-read-consumer-v2/source-manifest.json'));
assert.equal(sha(overlayBytes), '8af556f79785a0468f25cd9c87792e40da1f121eecd3a7ba81b0a7462da77e1b');
assert.equal(sha(successorBytes), CONSUMER_V2_MANIFEST_SHA);
const overlay = JSON.parse(overlayBytes), successor = JSON.parse(successorBytes);
test('Frozen V1 remains unchanged when no successor is requested', () => {
  const rows = engineReadSourceComposition(overlay);
  assert.deepEqual(rows, overlay.outputs);
  rows[0].sha256 = 'changed';
  assert.notEqual(rows[0].sha256, overlay.outputs[0].sha256);
});
test('Explicit V2 changes exactly the reviewed header with detached rows', () => {
  const rows = engineReadSourceComposition(overlay, successor, CONSUMER_V2_MANIFEST_SHA);
  assert.equal(rows.filter(row => row.sha256 !== overlay.outputs.find(old => old.relative === row.relative).sha256).length, 1);
  assert.deepEqual(rows, successor.productionFiles);
  rows[0].relative = 'changed';
  assert.notEqual(rows[0].relative, successor.productionFiles[0].relative);
});
test('Successor cannot be selected implicitly or with an unrelated approval hash', () => {
  assert.throws(() => engineReadSourceComposition(overlay, successor));
  assert.throws(() => engineReadSourceComposition(overlay, successor, 'a'.repeat(64)));
  assert.throws(() => engineReadSourceComposition(overlay, null, CONSUMER_V2_MANIFEST_SHA));
});
const wrong = {
  'parent lineage': row => {row.parentManagedReceiptSha256 = 'changed';},
  'overlay lineage': row => {row.parentProductionOverlay.sha256 = 'changed';},
  'ABI replacement': row => {row.abi.sha256 = 'changed';},
  'producer replacement': row => {row.producerManifestSha256 = 'changed';},
  'different header': row => {row.productionFiles.at(-1).sha256 = 'changed';},
  'other source mutation': row => {row.productionFiles[0].sha256 = 'changed';},
  'duplicate source': row => {row.productionFiles[0] = row.productionFiles[1];},
  'extra test binding': row => {row.productionFiles.push({relative: 'native/test_only.hpp', sha256: 'a'.repeat(64)});},
  'widened delta': row => {row.productionDeltaFromV1.push('native/particle_kernel.cpp');}
};
for (const [name, change] of Object.entries(wrong)) test('Rejects ' + name, () => {
  const row = structuredClone(successor);change(row);
  assert.throws(() => engineReadSourceComposition(overlay, row, CONSUMER_V2_MANIFEST_SHA));
});

const project = path.join(root, '.cache/native-140fps/particles-agent/fixture-build-path/candidate');
const apiRoot = path.join(root, '.tools/extension-api');
const builder = path.join(agent, 'synchronous-engine-read-compose-v2/build_v2.ps1');
function invocationFixture() {
  const output = path.join(project, '.cache/native-kernel');
  return {compiler: '14.50.35717', sourceReceiptUnchanged: true, builderUnchanged: true,
    actualInvocation: {version: 1, compilerFile: path.join(root, '.tools/cl.exe'),
      compilerSha256: 'a'.repeat(64), compilerVersion: '14.50.35717',
      builderFile: builder, builderSha256: CONSUMER_V2_BUILDER_SHA, workingDirectory: project,
      environmentGuard: {policy: 'reject-nonempty-CL-and-_CL_', CL: false, _CL_: false, checkedImmediatelyBeforeCompiler: true},
      arguments: ['/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD',
        '/I'+apiRoot,'/Fo'+path.join(output,'engine-read-v2-kernel.obj'),
        '/Fe'+path.join(output,'nwn-particle-kernel.dll'),path.join(project,'native/particle_kernel.cpp'),
        '/link','/INCREMENTAL:NO','/IMPLIB:'+path.join(output,'engine-read-v2-kernel.lib')]}};
}
test('Exact executed invocation is admitted without mutating its proof', () => {
  const proof = invocationFixture(), before = structuredClone(proof);
  assert.equal(engineReadV2BuildInvocation(proof, project, apiRoot, builder), true);
  assert.deepEqual(proof, before);
});
const badInvocation = {
  'missing invocation': row => {delete row.actualInvocation;},
  'changed source receipt': row => {row.sourceReceiptUnchanged = false;},
  'changed builder': row => {row.builderUnchanged = false;},
  'unreviewed builder hash': row => {row.actualInvocation.builderSha256 = 'b'.repeat(64);},
  'relocated builder': row => {row.actualInvocation.builderFile += '.other';},
  'different working directory': row => {row.actualInvocation.workingDirectory = root;},
  'relative compiler': row => {row.actualInvocation.compilerFile = 'cl.exe';},
  'compiler version mismatch': row => {row.actualInvocation.compilerVersion = 'different';},
  'inherited CL flags': row => {row.actualInvocation.environmentGuard.CL = true;},
  'inherited trailing flags': row => {row.actualInvocation.environmentGuard._CL_ = true;},
  'missing precompiler guard': row => {delete row.actualInvocation.environmentGuard.checkedImmediatelyBeforeCompiler;},
  'fast math': row => {row.actualInvocation.arguments[2] = '/fp:fast';},
  'test-access define': row => {row.actualInvocation.arguments.splice(9, 0, '/DNWN_PARTICLE_READ_TEST_ACCESS');},
  'alternate native source': row => {row.actualInvocation.arguments[12] = path.join(root, 'native/particle_kernel.cpp');},
  'alternate DLL output': row => {row.actualInvocation.arguments[11] = '/Fe'+path.join(root,'other.dll');},
  'alternate API include': row => {row.actualInvocation.arguments[9] = '/I'+root;}
};
for (const [name, change] of Object.entries(badInvocation)) test('Rejects actual build ' + name, () => {
  const proof = invocationFixture();change(proof);
  assert.throws(() => engineReadV2BuildInvocation(proof, project, apiRoot, builder));
});
