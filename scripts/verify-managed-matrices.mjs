import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const dir=new URL('../backups/animations/',import.meta.url),hash=b=>createHash('sha256').update(b).digest('hex');
const read=async name=>{const bytes=await fs.readFile(new URL(name,dir));return{value:JSON.parse(bytes),sha256:hash(bytes)};};
const median=(rows,fn)=>{const values=rows.map(fn).sort((a,b)=>a-b);assert.ok(values.length&&values.every(Number.isFinite));return values[values.length>>1];};
const checkSources=async hashes=>{for(const file in hashes)assert.equal(hashes[file],hash(await fs.readFile(new URL('../'+file,import.meta.url))),file);};
const gpu=await read('managed-matrices-v1.json'),g=gpu.value;
assert.equal(g.success,true);assert.equal(g.failure,undefined);assert.deepEqual(g.errors,[]);await checkSources(g.sourceHashes);
assert.equal(g.result.comparisons.length,32);
for(const c of g.result.comparisons)for(const key of ['pixels','shadows','matrices','calls','triangles'])assert.equal(c[key],true,`${c.frame}:${key}`);
for(const c of g.result.comparisons)assert.ok(c.afterCounts.local<c.beforeCounts.local);
assert.ok(g.result.comparisons.slice(1).every(c=>c.afterCounts.world<c.beforeCounts.world));
const transformed=await read('managed-matrices-transformed-v1.json'),t=transformed.value;
assert.equal(t.success,true);assert.equal(t.managedMatrices,true);assert.equal(t.httpAttempts,0);assert.equal(t.joins,0);assert.equal(t.checks.length,8);assert.deepEqual(t.issues,[]);
const baseline=await read('dense-local-v20.json'),runs=[];
for(const version of ['v21','v22']){
 const r=await read(`dense-local-${version}.json`),v=r.value;
 assert.equal(v.success,true);assert.equal(v.failure,undefined);assert.deepEqual(v.rendererErrors,[]);await checkSources(v.sourceHashes);
 assert.equal(v.endpoint,'127.0.0.1:5123');assert.equal(v.fixture.sha256,baseline.value.fixture.sha256);assert.deepEqual(v.areas.map(a=>a.resRef),['dense_a','dense_b','dense_a']);
 const areas=v.areas.map((a,i)=>{
  assert.ok(a.movingActors>=45);assert.ok(a.clips.includes('walk'));assert.ok(a.samples.length>=30);assert.ok(a.samples.at(-1).at-a.samples[0].at>=19000);
  for(const s of a.samples){assert.deepEqual(s.scene.failed,[]);assert.equal(s.scene.controlled.rendered,true);assert.equal(s.frame.viewport.bufferWidth,3440);assert.equal(s.frame.viewport.bufferHeight,1369);assert.equal(s.models.failed,0);assert.equal(s.workers.failed,0);assert.equal(s.particleWorkers.failedJobs,0);}
  assert.equal(a.batches.enabled,false);assert.equal(a.batches.cachedBatches,0);
  const old=baseline.value.areas[i];
  return{area:a.resRef,readyMs:a.loadMs,fps:median(a.samples,s=>s.performance.fps),p95Ms:median(a.samples,s=>s.performance.p95FrameMs),renderMs:median(a.samples,s=>s.frame.renderMs),mainDraws:median(a.samples,s=>s.frame.draw.calls),beforeFps:median(old.samples,s=>s.performance.fps),beforeP95Ms:median(old.samples,s=>s.performance.p95FrameMs)};
 });
 assert.equal(v.retiredWorkers.length,3);
 for(const owner of v.retiredWorkers){for(const pool of [owner,owner.vertexWorkers]){for(const key of ['workers','pending','queued','failed'])assert.equal(pool[key],0);assert.equal(pool.closed,true);}assert.equal(owner.prefetch.pending,0);assert.equal(owner.prefetch.queued,0);}
 assert.equal(v.postCloseModels.pending,0);assert.equal(v.postCloseModels.activeTemplates,0);assert.equal(v.postCloseModels.activeAreas,0);assert.equal(v.postCloseModels.templates,v.postCloseModels.destroyed);
 assert.equal(v.postCloseGeometry.owners,0);assert.equal(v.postCloseGeometry.active,0);assert.equal(v.postCloseGeometry.created,v.postCloseGeometry.retired);
 for(const key of ['cachedGroups','geometryKeys','alphaKeys','currentMembers'])assert.equal(v.postCloseShadows[key],0);
 for(const key of ['cachedBatches','arrays','bytes','vertexBytes'])assert.equal(v.postCloseBatches[key],0);
 assert.ok(v.rendererClosedAt<v.finishedAt);runs.push({version,sha256:r.sha256,bundle:v.bundle,areas});
}
assert.match(await fs.readFile(new URL('../src/main.js',import.meta.url),'utf8'),/new RendererMainBatches\(renderer,\{enabled:false\}\)/);
const vanilla=await read('managed-matrices-vanilla-v1.json'),v=vanilla.value;
assert.equal(v.success,true);assert.equal(v.failure,undefined);assert.deepEqual(v.rendererErrors,[]);assert.equal(v.bundle,runs.at(-1).bundle);assert.equal(v.closedOwners.closed,true);
assert.equal(v.closedOwners.models.templates,v.closedOwners.models.destroyed);assert.equal(v.closedOwners.geometry.owners,0);assert.equal(v.closedOwners.geometry.created,v.closedOwners.geometry.retired);
assert.equal(v.closedOwners.batches.enabled,false);for(const key of ['cachedBatches','arrays','bytes','vertexBytes'])assert.equal(v.closedOwners.batches[key],0);
const small=v.largeViewport.slice(4),vanillaMetrics={sha256:vanilla.sha256,fps:median(small,s=>s.performance.fps),p95Ms:median(small,s=>s.performance.p95FrameMs),readyMs:v.firstControlledAt-v.connectAt,transferMs:v.secondControlledAt-v.transitionRequestedAt};
assert.ok(vanillaMetrics.fps>=60);
const proof={scope:'Producer-owned model local matrices; exact automatic-vs-managed GPU/matrix comparisons and owned loopback performance checks',goalComplete:false,mainBatchesEnabled:false,gpu:{sha256:gpu.sha256,frames:32,shadowAtlasesCompared:64,allPixelsExact:true,allMatricesExact:true,typicalCounts:g.result.comparisons[5]},transformed:{sha256:transformed.sha256,checks:8,httpAttempts:0,joins:0},baseline:{version:'v20',sha256:baseline.sha256},runs,vanilla:vanillaMetrics,limits:['Sequential native runs vary with wandering actors, visibility, caches and profiling; deterministic operation counts establish eliminated work, not a universal FPS multiplier','No matched original-client230FPS benchmark','Only explicitly owned model nodes/meshes and fixed scene/area/tile roots opt in; external PQS writers must commit','Dense p95 still exceeds16.7ms; the full goal remains active']};
await fs.writeFile(new URL('managed-matrices-proof-v1.json',dir),JSON.stringify(proof,null,2)+'\n');
console.log(JSON.stringify({ok:true,goalComplete:false,gpu:proof.gpu,runs,vanilla:vanillaMetrics}));
