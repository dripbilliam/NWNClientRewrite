'use strict';
// Stage the previously frozen original-observation corpus with either native
// binary. No working-tree source or global extension selector is consulted.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const mode = process.argv[2];
assert(['control', 'candidate'].includes(mode));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => fs.readFileSync(file);
const source = path.join(root, '.cache/nwn64/preparation-c2-accepted');
const sourceManifestFile = path.join(source, 'manifest.json');
const sourceManifestBytes = read(sourceManifestFile);
assert.equal(sha(sourceManifestBytes), 'bddffefbf7ba7cd765aa806711e8d1d5b7a7f0579a0e672df18cc80eb4f72b25');
const sourceManifest = JSON.parse(sourceManifestBytes);
const candidateManifestFile = path.join(root, '.cache/nwn64/duplicate-corners-a/manifest.json');
assert.equal(sha(read(candidateManifestFile)), '09034846c1e9f8439c7265a22fa9d8d1b2fc6e4e6b0d2b56af5ffe7f1aa337d9');
const candidateManifest = JSON.parse(read(candidateManifestFile));
assert.equal(candidateManifest.sourceFiles, 45);
const buildReceiptFile = path.join(root, '.cache/nwn64/duplicate-corners-a/kernel-build/build-receipt.json');
let binary, buildProof = null;
if (mode === 'candidate') {
  const receiptBytes = read(buildReceiptFile);
  const receipt = JSON.parse(receiptBytes.toString().replace(/^\uFEFF/, ''));
  assert(receipt.success && receipt.private && !receipt.accepted && !receipt.production);
  assert.equal(receipt.sourceManifestSha256, sha(read(candidateManifestFile)));
  assert.equal(receipt.sourceFiles, 45);
  assert(receipt.arguments.includes('/DNWN_PARTICLE_DUPLICATE_CORNERS=1'));
  assert.equal(path.resolve(receipt.binary), path.join(root, '.cache/nwn64/duplicate-corners-a/kernel-build/nwn-particle-kernel.dll'));
  binary = read(receipt.binary);
  assert.equal(sha(binary), receipt.binarySha256);
  buildProof = { relative: '.cache/nwn64/duplicate-corners-a/kernel-build/build-receipt.json', sha256: sha(receiptBytes), binarySha256: sha(binary) };
} else {
  binary = read(path.join(root, '.cache/native-kernel/nwn-particle-kernel.dll'));
  assert.equal(sha(binary), '485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d');
}
const out = path.join(root, '.cache/nwn64/duplicate-corners-a/test-' + mode);
assert(!fs.existsSync(out), 'Preserve existing test capsule');
const project = path.join(out, 'project');
fs.mkdirSync(project, { recursive: true });
const files = [];
for (const pin of sourceManifest.files) {
  assert(!path.isAbsolute(pin.relative) && !pin.relative.split(/[\\/]/).includes('..'));
  const original = read(path.join(sourceManifest.project, pin.relative));
  assert.equal(sha(original), pin.sha256, pin.relative);
  assert.equal(original.length, pin.bytes, pin.relative);
  const bytes = pin.relative === '.cache/native-kernel/nwn-particle-kernel.dll' ? binary : original;
  const target = path.join(project, pin.relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, bytes, { flag: 'wx' });
  files.push({ relative: pin.relative, bytes: bytes.length, sha256: sha(bytes) });
}
const oracles = [];
for (const pin of sourceManifest.oracles) {
  const relative = `backups/animations/${pin.name}.json`;
  const bytes = read(path.join(source, relative));
  assert.equal(sha(bytes), pin.sha256, relative);
  assert.equal(bytes.length, pin.bytes, relative);
  const target = path.join(out, relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, bytes, { flag: 'wx' });
  oracles.push({ relative, bytes: bytes.length, sha256: sha(bytes) });
}
const manifest = {
  version: 1, issue: 'NWN-64', mode, private: true, accepted: false,
  project, nativeBinarySha256: sha(binary),
  fixtureManifestSha256: sha(sourceManifestBytes),
  sourceManifestSha256: sha(read(candidateManifestFile)),
  buildProof, files, oracles,
  scope: 'Frozen original 245-case geometry corpus; isolated headless packet/state checks only.',
};
const bytes = Buffer.from(JSON.stringify(manifest, null, 2) + '\n');
fs.writeFileSync(path.join(out, 'manifest.json'), bytes, { flag: 'wx' });
process.stdout.write(JSON.stringify({ mode, manifest: path.join(out, 'manifest.json'), manifestSha256: sha(bytes), files: files.length, oracles: oracles.length, nativeBinarySha256: sha(binary) }) + '\n');
