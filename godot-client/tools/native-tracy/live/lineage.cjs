'use strict';
// Read-only small-metadata ancestry check. Never accepts a loose engine hash.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function checkPin(pin) { assert(pin && typeof pin.file === 'string' && /^[a-f0-9]{64}$/.test(pin.sha256)); assert.equal(sha(pin.file), pin.sha256, 'Pinned plan/evidence changed: ' + pin.file); return JSON.parse(fs.readFileSync(pin.file)); }
const particleSignature = plan => JSON.stringify(plan.particlePins.map(row => [row.relative, row.sha256]).sort((a, b) => a[0].localeCompare(b[0])));
function verifyPlanLineage(engine, particle, expectedSource) {
 assert.equal(engine.success, true); assert.equal(engine.exit, 0); assert.equal(particle.success, true); assert.equal(particle.exit, 0);
 assert.equal(engine.normalRuntimeChanged, false); assert.equal(particle.normalRuntimeChanged, false);
 const wanted = { file: path.resolve(particle.plan), sha256: particle.planSha256 }, chain = [], visited = new Set();
 let current = { file: path.resolve(engine.plan), sha256: engine.planSha256 }, leaf = null, dllPlan = null;
 for (let depth = 0; ; depth++) {
  assert(depth < 8, 'Unbounded private engine ancestry');
  const real = fs.realpathSync(current.file).toLowerCase(); assert(!visited.has(real), 'Cyclic private engine ancestry'); visited.add(real);
  const plan = checkPin(current); if (!leaf) leaf = plan;
  assert.equal(plan.installedSourceIdentity, expectedSource);
  assert.equal(plan.kind, leaf.kind); assert.equal(plan.source, leaf.source); assert.equal(plan.particle, leaf.particle);
  assert.deepEqual(plan.engineArguments, leaf.engineArguments, 'Compiler/profiler options drift across ancestry');
  assert.deepEqual(plan.reconstruction, leaf.reconstruction); assert.deepEqual(plan.overlay, leaf.overlay);
  assert.equal(particleSignature(plan), particleSignature(leaf), 'DLL source closure changed in engine ancestry');
  for (const key of ['reconstruction', 'overlay']) checkPin(plan[key]);
  const fixes = [];
  for (const key of ['shutdownFix', 'shutdownPatchCorrection']) if (plan[key]) {
   checkPin(plan[key]); fixes.push({ kind: key, file: plan[key].file, sha256: plan[key].sha256 });
   if (plan[key].reproducer) { const proof = checkPin(plan[key].reproducer); assert.equal(proof.success, true, 'Thread startup reproducer rejected'); }
  }
  chain.push({ ...current, fixes });
  if (path.resolve(current.file).toLowerCase() === wanted.file.toLowerCase() && current.sha256 === wanted.sha256) dllPlan = plan;
  if (!plan.parentPlan) break;
  current = { file: path.resolve(plan.parentPlan.file), sha256: plan.parentPlan.sha256 };
 }
 assert(dllPlan, 'DLL build plan is not an exact verified ancestor of selected engine');
 return { leaf, dllPlan, chain, relation: chain.length === 1 ? 'same-plan' : 'verified-engine-descendant-of-unchanged-DLL-plan' };
}
module.exports = { verifyPlanLineage };
