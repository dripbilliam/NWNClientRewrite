'use strict';
// Correctness only. Uses the frozen private corpus, not the live client.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const mode = process.argv[2];
assert(['control', 'candidate'].includes(mode));
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const json = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const out = path.join(root, '.cache/nwn64/duplicate-corners-a/test-' + mode);
const manifest = json(path.join(out, 'manifest.json'));
assert.equal(manifest.mode, mode);
assert.equal(manifest.fixtureManifestSha256, 'bddffefbf7ba7cd765aa806711e8d1d5b7a7f0579a0e672df18cc80eb4f72b25');
assert.equal(manifest.sourceManifestSha256, '09034846c1e9f8439c7265a22fa9d8d1b2fc6e4e6b0d2b56af5ffe7f1aa337d9');
assert.equal(sha(path.join(root, '.cache/nwn64/duplicate-corners-a/manifest.json')), manifest.sourceManifestSha256);
assert.equal(sha(path.join(root, '.cache/nwn64/preparation-c2-accepted/manifest.json')), manifest.fixtureManifestSha256);
const expectedBinary = mode === 'control' ? '485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d' : manifest.buildProof?.binarySha256;
assert.equal(manifest.nativeBinarySha256, expectedBinary);
assert.equal(sha(path.join(root, '.cache/native-kernel/nwn-particle-kernel.dll')), '485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d');
if (mode === 'candidate') {
  const receiptFile = path.join(root, manifest.buildProof.relative);
  assert.equal(sha(receiptFile), manifest.buildProof.sha256);
  const receipt = json(receiptFile);
  assert(receipt.success && receipt.arguments.includes('/DNWN_PARTICLE_DUPLICATE_CORNERS=1'));
  assert.equal(receipt.binarySha256, expectedBinary);
}
const verify = () => {
  for (const pin of manifest.files) assert.equal(sha(path.join(manifest.project, pin.relative)), pin.sha256, pin.relative);
  for (const pin of manifest.oracles) assert.equal(sha(path.join(out, pin.relative)), pin.sha256, pin.relative);
};
verify();
const descriptorFile = path.join(root, '.tools/native-core/accepted-core-e.json');
assert.equal(sha(descriptorFile), '29b1c6adcdecb11eebc859730c770e879a108279dfaaf60792e4c11c00add78a');
const descriptor = json(descriptorFile);
const engine = path.join(root, '.tools/native-core/Godot_native_core_e_win64.exe');
assert.equal(sha(engine), '753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
assert.equal(descriptor.engineSha256, sha(engine));
assert.equal(descriptor.fullFunctionalFlags.length, 16);
const formats = ['regular', 'direct', 'instances'];
const selected = process.argv.find(value => value.startsWith('--format='))?.slice('--format='.length);
if (selected) assert(formats.includes(selected));
const label = process.argv.find(value => value.startsWith('--label='))?.slice('--label='.length);
if (label) assert(/^[a-z0-9-]+$/.test(label));
for (const format of selected ? [selected] : formats) {
  const tag = label ? `${format}-${label}` : format;
  const report = path.join(out, `${tag}.json`);
  const log = path.join(out, `${tag}.log`);
  const receiptFile = path.join(out, `${tag}-receipt.json`);
  assert(!fs.existsSync(report) && !fs.existsSync(log) && !fs.existsSync(receiptFile), 'Keep previous test evidence');
  const appdata = path.join(out, `user-data-${tag}`), localdata = path.join(out, `local-data-${tag}`);
  fs.mkdirSync(appdata, { recursive: true }); fs.mkdirSync(localdata, { recursive: true });
  const args = ['--headless', '--path', manifest.project, '--script', 'res://tests/nwn64_compact_vertices_test.gd', '--', ...descriptor.fullFunctionalFlags, `--report=${report}`];
  if (format !== 'regular') args.push(`--particle-streams=${format}`);
  const result = cp.spawnSync(engine, args, { env: { ...process.env, APPDATA: appdata, LOCALAPPDATA: localdata }, encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024, windowsHide: true });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(log, output, { flag: 'wx' });
  verify();
  assert.equal(result.status, 0, output.slice(-6000));
  assert(!result.error && !/SCRIPT ERROR|(?:^|\n)ERROR:|ObjectDB instances leaked|resources still in use/.test(output), output.slice(-6000));
  const data = json(report);
  assert(data.success && data.cases === 245 && Array.isArray(data.failures) && data.failures.length === 0);
  const receipt = { success: true, issue: 'NWN-64', mode, format, checks: data.checks, cases: data.cases, report, reportSha256: sha(report), kernelSha256: expectedBinary, engineSha256: sha(engine), capsuleInputsUnchanged: true, arguments: args, scope: 'Original geometry corpus and exact native packets; headless correctness, no FPS or graphical acceptance.' };
  fs.writeFileSync(receiptFile, JSON.stringify(receipt, null, 2) + '\n', { flag: 'wx' });
  process.stdout.write(JSON.stringify(receipt) + '\n');
}
