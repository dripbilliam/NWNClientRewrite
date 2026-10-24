import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const root=process.cwd(), directory=path.join(root,'backups/animations');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const read=name=>JSON.parse(fs.readFileSync(path.join(directory,name+'.json'),'utf8'));
const names=['dense-local-batch-keys-base-v1','dense-local-batch-keys-v1','main-batches-hooks-v2','main-batches-performance-v2','point-light-packets-v7','point-light-packets-v8'];
const artifacts={};
for(const name of names){
  const report=read(name);
  assert.equal(report.success,true,name);
  assert.deepEqual(report.errors??report.rendererErrors,[],name);
  for(const [file,hash] of Object.entries(report.sourceHashes??{}))assert.equal(sha(fs.readFileSync(path.join(root,file))),hash,`${name}: ${file}`);
  artifacts[name]={sha256:sha(fs.readFileSync(path.join(directory,name+'.json'))),success:true};
}
for(const name of names.slice(0,2)){
  const report=read(name);
  assert.equal(report.areas.length,3);
  assert(report.areas.every(area=>area.movingActors>=40));
  assert.equal(report.retiredWorkers.length,3);
  for(const worker of report.retiredWorkers){
    assert(worker.closed&&!worker.pending&&!worker.queued&&!worker.workers);
    assert(worker.vertexWorkers.closed&&!worker.vertexWorkers.pending&&!worker.vertexWorkers.queued&&!worker.vertexWorkers.workers);
  }
  for(const key of ['materials','programs','references','bytes'])assert.equal(report.postCloseModels.programCache[key],0);
  for(const key of ['cachedBatches','arrays','bytes'])assert.equal(report.postCloseBatches[key],0);
}
function bundleAt(folder){
  const html=fs.readFileSync(path.join(folder,'index.html'),'utf8');
  const match=html.match(/src="([^"]*assets\/index-[^"]+\.js)"/);
  assert(match,folder);
  const file=path.join(folder,match[1].replace(/^\.?\//,''));
  const bytes=fs.readFileSync(file);
  return {file:path.relative(root,file),sha256:sha(bytes),executableSha256:sha(bytes.toString().replace(/\/\/# sourceMappingURL=.*$/m,'').trim())};
}
const production=bundleAt(path.join(root,'dist'));
const testedBaseline=bundleAt(path.join(directory,'main-batches-cached-keys-baseline-v1'));
assert.equal(production.executableSha256,testedBaseline.executableSha256,'Restored production must match the native-tested batching-OFF executable');
const proof={checkedAt:new Date().toISOString(),scope:'Owned local server and offline fixtures only; no Arelith connections.',artifacts,production,testedBaseline,decision:'Experimental main batching and point-light packets remain disabled. Whole-client gains are mixed; 60 FPS and p95 <=16.7 ms acceptance remains unmet. Pause requested after this comparison.',limits:['Native camera routes and random actor wandering differ between runs.','Native p95 summaries average rolling windows, rather than representing a whole-run percentile.','Offline draw-count reductions do not establish whole-client gains.','Batch first-use GPU preparation before area reveal remains unfinished.']};
fs.writeFileSync(path.join(directory,'main-batches-pause-proof-v1.json'),JSON.stringify(proof,null,2)+'\n');
console.log(JSON.stringify({success:true,production,experimentalBatching:false,goalComplete:false}));
