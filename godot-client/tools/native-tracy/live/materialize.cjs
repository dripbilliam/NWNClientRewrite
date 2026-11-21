'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const { mayLink } = require('./storage-policy.cjs');
const paths = require('./path-policy.cjs');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function safe(root, relative) { relative = paths.relative(relative); const file = path.resolve(root, relative); assert(file.startsWith(path.resolve(root) + path.sep)); return file; }
function materialize(configFile, execute = false) {
 const config = JSON.parse(fs.readFileSync(configFile)), manifest = JSON.parse(fs.readFileSync(path.join(config.out, 'manifest.json')));
 assert.equal(sha(configFile), manifest.config.sha256); assert.equal(sha(manifest.base.file), manifest.base.sha256); assert(!fs.existsSync(config.view), 'Fresh view required');
 const base = JSON.parse(fs.readFileSync(manifest.base.file)), targets = paths.plan(base.pins, manifest.overlayPins, manifest.binaries);
 const rows = targets.base;
 if (!execute) return { executed: false, view: config.view, independentCopies: rows.filter(row => !mayLink(row)).length + manifest.overlayPins.length + manifest.binaries.length, immutableDossierLinks: rows.filter(mayLink).length, processStarts: 0 };
 fs.mkdirSync(config.view, { recursive: false }); let copies = 0, links = 0;
 const root = fs.realpathSync(manifest.base.project);
 function copy(source, target, expected) {
  assert.equal(sha(source), expected); fs.mkdirSync(path.dirname(target), { recursive: true }); fs.copyFileSync(source, target, fs.constants.COPYFILE_EXCL);
  assert.equal(sha(target), expected); const before = fs.statSync(source, { bigint: true }), after = fs.statSync(target, { bigint: true }); assert.equal(after.nlink, 1n); if (before.ino && after.ino) assert.notEqual(before.ino, after.ino); copies++;
 }
 for (const row of rows) {
  const source = safe(manifest.base.project, row.relative), target = safe(config.view, row.relative); assert(fs.realpathSync(source).startsWith(root + path.sep));
  if (mayLink(row)) { assert.equal(sha(source), row.sha256); fs.mkdirSync(path.dirname(target), { recursive: true }); fs.linkSync(source, target); links++; }
  else copy(source, target, row.sha256);
 }
 for (const row of targets.overlay) copy(row.file, safe(config.view, row.relative), row.sha256);
 for (const row of targets.binaries) copy(row.source, safe(config.view, row.relative), row.sha256);
 const feature = require(path.join(config.project, 'tools/native-feature-manifest.cjs')); assert.equal(feature.sourceIdentity(config.view).sha256, config.predictedSourceIdentity);
 const result = { version: 1, stageManifestSha256: sha(path.join(config.out, 'manifest.json')), materialized: true, independentCopies: copies, immutableDossierLinks: links, source: config.predictedSourceIdentity, nativeParsed: false, processStarts: 0 };
 fs.writeFileSync(path.join(config.out, 'materialized.json'), JSON.stringify(result, null, 2) + '\n', { flag: 'wx' }); return result;
}
module.exports = { materialize, safe };
if (require.main === module) console.log(JSON.stringify(materialize(process.argv[2], process.argv.includes('--execute'))));
