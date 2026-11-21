'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function verify(configFile) {
 const config = JSON.parse(fs.readFileSync(configFile)), manifest = JSON.parse(fs.readFileSync(path.join(config.out, 'manifest.json')));
 assert.equal(sha(configFile), manifest.config.sha256);
 for (const row of manifest.launchPins) assert.equal(sha(row.file), row.sha256);
 for (const row of Object.values(manifest.sourceReceipts)) assert.equal(sha(row.file), row.sha256);
 const engine = JSON.parse(fs.readFileSync(manifest.sourceReceipts.engine.file)), particle = JSON.parse(fs.readFileSync(manifest.sourceReceipts.particle.file));
 const lineage = require('./lineage.cjs').verifyPlanLineage(engine, particle, config.expectedEngineSourceIdentity || config.expectedMainSourceIdentity); assert.deepEqual(lineage.chain, manifest.planLineage);
 if (manifest.scriptUpdateProof) { assert.deepEqual(config.scriptUpdateProof, manifest.scriptUpdateProof); assert.equal(sha(manifest.scriptUpdateProof.file), manifest.scriptUpdateProof.sha256); }
 assert.equal(sha(config.host), config.hostSha256); assert.equal(sha(config.bootstrap), config.bootstrapSha256);
 for (const row of manifest.overlayPins) assert.equal(sha(path.join(config.view, row.relative)), row.sha256);
 for (const row of manifest.binaries) assert.equal(sha(path.join(config.view, row.relative)), row.sha256);
 const feature = require(path.join(config.project, 'tools/native-feature-manifest.cjs'));
 assert.equal(feature.sourceIdentity(config.project).sha256, config.expectedMainSourceIdentity);
 assert.equal(feature.sourceIdentity(config.view).sha256, config.predictedSourceIdentity);
 const materialized = JSON.parse(fs.readFileSync(path.join(config.out, 'materialized.json'))); assert.equal(materialized.stageManifestSha256, sha(path.join(config.out, 'manifest.json'))); assert.equal(materialized.materialized, true);
 return { success: true, source: config.predictedSourceIdentity, engine: config.engineSha256, particle: config.particleSha256, diagnosticOnly: true, performanceAccepted: false, nativeRuntimeChecked: false };
}
module.exports = { verify };
if (require.main === module) console.log(JSON.stringify(verify(process.argv[2])));
