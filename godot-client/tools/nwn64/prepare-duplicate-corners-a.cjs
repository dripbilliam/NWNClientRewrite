// Freeze one private opt-in native source closure from the accepted 45-file set.
// This never writes the accepted DLL, descriptor, or working native sources.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '../..');
const baseline = path.join(root, '.cache/nwn64/baseline-project');
const pinsFile = path.join(root, '.cache/nwn64/baseline-source-pins.json');
const target = path.join(root, '.cache/nwn64/duplicate-corners-a');
const candidate = path.join(target, 'kernel-project');
const changes = {
  'native/particle_streams.hpp': {
    before: '764e5883282b3ce4ed8faa371d2a0c39eee926b5cb4b8f2c07aeea7a64b388a1',
    after: '7c0823f0f8e396765424c651b2e28c72d33c419289c95b0ccb984c612b038d35',
  },
  'native/particle_compact_vertices.hpp': {
    before: '83d3c2b958a70c2e6b0c763d2aa7e8c19a534c0e454e6e2408601ebecee9f484',
    after: 'd81f74798333f5deaf38da58fe239dc421dc1847a56794d0cbe589e98b31de8b',
  },
};
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const pinsBytes = fs.readFileSync(pinsFile);
const pins = JSON.parse(pinsBytes).pins;
if (pins.length !== 45) throw new Error('Accepted native closure file count changed');
for (const pin of pins) {
  const source = path.join(baseline, pin.relative);
  const accepted = fs.readFileSync(source);
  if (hash(accepted) !== pin.sha256 || accepted.length !== pin.bytes) throw new Error(`Accepted source pin changed: ${pin.relative}`);
  const override = changes[pin.relative];
  if (override && override.before !== pin.sha256) throw new Error(`Candidate baseline mismatch: ${pin.relative}`);
  const bytes = override ? fs.readFileSync(path.join(root, pin.relative)) : accepted;
  if (override && hash(bytes) !== override.after) throw new Error(`Candidate source changed: ${pin.relative}`);
  const destination = path.join(candidate, pin.relative);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  if (fs.existsSync(destination)) {
    if (hash(fs.readFileSync(destination)) !== hash(bytes)) throw new Error(`Private source already differs: ${pin.relative}`);
  } else fs.writeFileSync(destination, bytes);
}
const manifest = {
  version: 1,
  issue: 'NWN-64',
  role: 'private candidate; production/default behavior remains macro-off',
  acceptedPinsSha256: hash(pinsBytes),
  sourceFiles: pins.length,
  candidate: path.relative(root, candidate).replaceAll('\\', '/'),
  changes,
  compileDefine: 'NWN_PARTICLE_DUPLICATE_CORNERS=1',
  corpus: 'tests/nwn64_compact_vertices_test.gd: 245 original-observation cases in default, direct, and instances packet modes',
  gate: 'Exact packet/state parity first; then matched profile=false full-owner and frame timing. Reject if no whole-frame gain.',
};
const manifestPath = path.join(target, 'manifest.json');
const serialized = `${JSON.stringify(manifest, null, 2)}\n`;
if (fs.existsSync(manifestPath)) {
  if (fs.readFileSync(manifestPath, 'utf8') !== serialized) throw new Error('Private manifest already differs');
} else fs.writeFileSync(manifestPath, serialized);
process.stdout.write(`${JSON.stringify({ manifest: manifestPath, sha256: hash(Buffer.from(serialized)), sourceFiles: pins.length })}\n`);
