'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const base = path.join(root, '.cache/nwn64/duplicate-corners-b');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const json = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const buildFile = path.join(base, 'kernel-build/build-receipt.json');
const build = json(buildFile);
assert(build.success && build.private && !build.accepted && !build.production);
assert.equal(build.sourceManifestSha256, sha(path.join(base, 'manifest.json')));
assert.equal(build.binarySha256, sha(build.binary));
assert.equal(sha(path.join(root, '.cache/native-kernel/nwn-particle-kernel.dll')), '485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d');
const rows = [];
for (const format of ['regular', 'direct', 'instances']) {
  const reports = ['control', 'candidate'].map(mode => {
    const dir = path.join(base, 'test-' + mode);
    const manifest = json(path.join(dir, 'manifest.json'));
    const file = path.join(dir, `${format}-clean-b.json`);
    const receipt = json(path.join(dir, `${format}-clean-b-receipt.json`));
    const report = json(file);
    const log = fs.readFileSync(path.join(dir, `${format}-clean-b.log`), 'utf8');
    assert(manifest.files.every(pin => sha(path.join(manifest.project, pin.relative)) === pin.sha256));
    assert(manifest.oracles.every(pin => sha(path.join(dir, pin.relative)) === pin.sha256));
    assert(receipt.success && receipt.capsuleInputsUnchanged && receipt.reportSha256 === sha(file));
    assert(report.success && report.cases === 245 && report.failures.length === 0);
    assert(!/SCRIPT ERROR|(?:^|\n)ERROR:|ObjectDB instances leaked|resources still in use/.test(log));
    return { mode, reportSha256: sha(file), checks: report.checks, cases: report.cases, kernelSha256: receipt.kernelSha256, manifestSha256: sha(path.join(dir, 'manifest.json')) };
  });
  assert.equal(reports[0].reportSha256, reports[1].reportSha256, format);
  assert.equal(reports[0].checks, reports[1].checks, format);
  rows.push({ format, originalPacketParity: true, reports });
}
const review = { version: 1, issue: 'NWN-64', success: true, private: true, accepted: false, production: false, buildReceiptSha256: sha(buildFile), candidateBinarySha256: build.binarySha256, sourceManifestSha256: build.sourceManifestSha256, rows, scope: 'Compiled opt-in duplicate corner copy: all 245 captured original cases in regular, direct and instance packets; clean headless logs. No normal-frame/FPS gain or visual acceptance.' };
const file = path.join(base, 'correctness-review.json');
fs.writeFileSync(file, JSON.stringify(review, null, 2) + '\n', { flag: 'wx' });
process.stdout.write(JSON.stringify({ file, sha256: sha(file), rows: rows.map(row => ({ format: row.format, checks: row.reports[0].checks, match: row.originalPacketParity })) }) + '\n');
