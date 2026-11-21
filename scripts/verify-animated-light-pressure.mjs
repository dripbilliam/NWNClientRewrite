import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';

const root=new URL('../',import.meta.url),dir=new URL('backups/animations/',root),artifacts=[];
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
async function read(name){const bytes=await fs.readFile(new URL(name,dir));artifacts.push({name,sha256:hash(bytes)});return JSON.parse(bytes);}
const retained=await read('creation-performance-animated-crowd-v13.json');
const fresh=await read('creation-performance-animated-crowd-v14.json');
const sustained=await read('creation-performance-animated-crowd-v15.json');
for(const report of[retained,fresh,sustained]){
 assert.equal(report.success,true);assert.equal(report.nodeFetchAttempts,0);assert.equal(report.joins,0);
 assert.deepEqual(report.errors,[]);assert.equal(report.glError,0);assert.equal(report.skinVariant,'current');assert.equal(report.skinAdapter.fastNormals,true);
 assert.equal(report.scenarios.length,2);assert.ok(report.cancelledBrowserRequests.every(url=>url.startsWith('https://fonts.googleapis.com/')));
 assert.equal(report.executedSkinHash,hash(await fs.readFile(new URL('src/model_skinning.js',root))));
}
assert.deepEqual(retained.sourceHashes,fresh.sourceHashes);
// The short comparison predates the added timeline/camera instrumentation.
// Its source hashes are frozen evidence, not a claim about today's fixture.
for(const[name,sha]of Object.entries(sustained.sourceHashes))assert.equal(hash(await fs.readFile(new URL(name,root))),sha,name);
assert.equal(retained.lightingPressure,'retained128');assert.equal(fresh.lightingPressure,'fresh64');
assert.equal(sustained.lightingPressure,'retained128');assert.equal(sustained.cameraOrbit,true);
const cases=[];
for(let i=0;i<2;i++){
 const a=retained.scenarios[i].counts[0],b=fresh.scenarios[i].counts[0],c=sustained.scenarios[i].counts[0];
 for(const[r,capacity,n]of[[a,128,180],[b,64,180],[c,128,2400]]){
  assert.equal(r.count,48);assert.deepEqual(r.renderSize,[3100,1121]);assert.equal(r.skinMeshes,48);assert.equal(r.animators,99);assert.equal(r.samples.length,n);
  assert.equal(r.lighting.slots.point.actual,42);assert.equal(r.lighting.slots.point.capacity,capacity);assert.equal(r.lighting.slots.point.shadowActual,15);assert.equal(r.lighting.shadows.admitted,15);assert.equal(r.shadows.renderedLights,15);
  assert.equal(r.pressureHistory.final.slots.point.capacity,capacity);assert.equal(r.pressureHistory.final.slots.point.actual,42);assert.equal(r.pressureHistory.initial.slots.point.actual,9);
  assert.ok(new Set(r.poseSamples).size>1);assert.ok(new Set(r.skinSamples.map(s=>s.positionHash)).size>1);
  assert.equal(new Set(r.samples.map(s=>s.programs)).size,1);assert.equal(new Set(r.samples.map(s=>s.memory.geometries)).size,1);assert.equal(new Set(r.samples.map(s=>s.memory.textures)).size,1);
  for(const sample of r.samples)assert.equal(sample.skinCalls,48);
 }
 assert.equal(a.pressureHistory.peak.slots.point.actual,63);assert.equal(b.pressureHistory.peak.slots.point.actual,42);
 assert.deepEqual(a.poseSamples,b.poseSamples);assert.deepEqual(a.skinSamples,b.skinSamples);
 for(let frame=0;frame<180;frame++)for(const key of['draws','triangles','programs','memory'])assert.deepEqual(a.samples[frame][key],b.samples[frame][key],key);
 for(const key of['casters','lights','tests','admitted','fallbackLights','reusedLights','renderedLights','drawCalls','triangles'])assert.equal(a.shadows[key],b.shadows[key],key);
 // A sustained case must actually last over a minute; frame count alone is insufficient.
 assert.ok(c.durationMs>=60000);assert.ok(c.timeline.length>=3);assert.ok(c.samples.at(-1).elapsedMs===c.durationMs);
 for(const sample of c.samples){assert.equal(sample.pointLights,42);assert.equal(sample.pointCapacity,128);assert.equal(sample.shadowActual,15);}
 cases.push({robe:sustained.scenarios[i].robe,capacityComparison:{retained:a.phases,fresh:b.phases,geometrySamplesEqual:true,drawsEqual:true,pixelsCompared:false},sustained:{durationMs:c.durationMs,frames:c.samples.length,cameraDegrees:(c.samples.length-1)*.008*180/Math.PI,phases:c.phases,timeline:c.timeline,hitches:c.samples.slice(30).filter(s=>s.totalMs>50).length,programs:c.samples.at(-1).programs,memory:c.samples.at(-1).memory,mainDrawRange:[Math.min(...c.samples.map(s=>s.draws)),Math.max(...c.samples.map(s=>s.draws))],shadowDrawRange:[Math.min(...c.samples.map(s=>s.shadowDraws)),Math.max(...c.samples.map(s=>s.shadowDraws))]}});
}
const proof={goalComplete:false,scope:'Offline installed Prelude with independent animated multipart actors, synthetic light/camera pressure, production renderer and shaders; no live replication or server join',productionChange:false,renderSize:[3100,1121],characters:48,lights:42,retainedPointSlots:128,actualShadows:15,artifacts,sourceHashes:sustained.sourceHashes,cases,limits:['Completed-frame work includes gl.finish/driver waits; not live FPS or isolated GPU time','Homogeneous installed actors run in place; synthetic 33 additional lights and scripted camera orbit; not a modded server population','Current local client and background GPU/driver caches remain uncontrolled','Short capacity comparison verifies sampled geometry and draw/shadow admission, not pixel output; no reserve policy was changed','The earlier compact-loop experiment stays disconnected after its recorded regression','No full reported106ms cause, physical-key acceptance, transition/fullscreen acceptance or whole-goal completion is claimed','Exploratory v12 ran default counts because its runner option update failed; it is not pressure evidence']};
await fs.writeFile(new URL('creation-performance-animated-light-pressure-proof-v1.json',dir),JSON.stringify(proof,null,2)+'\n');
const priorBytes=await fs.readFile(new URL('creation-experience-current-audit-v14.json',dir)),prior=JSON.parse(priorBytes);
for(const source of prior.sources)assert.equal(hash(await fs.readFile(new URL(source.name,root))),source.sha256,source.name);
const proofBytes=await fs.readFile(new URL('creation-performance-animated-light-pressure-proof-v1.json',dir));
const audit={scope:'Current goal coverage summary; detailed earlier observations remain in the hashed parent audit',goalComplete:false,parentAudit:{name:'creation-experience-current-audit-v14.json',sha256:hash(priorBytes)},sources:prior.sources,requirements:prior.requirements.map(({requirement,status})=>({requirement,status})),currentBuild:prior.currentBuild,recordedMovementBuild:prior.recordedMovementBuild,currentBuildLiveAccepted:false,liveTestingRestriction:'Owned local server only; this turn made no game joins and left the existing client/server untouched',animatedLightingPressure:{name:'creation-performance-animated-light-pressure-proof-v1.json',sha256:hash(proofBytes),cases:cases.map(c=>({robe:c.robe,durationMs:c.sustained.durationMs,phases:c.sustained.phases,timeline:c.sustained.timeline,hitches:c.sustained.hitches}))},remaining:[...prior.remaining.slice(0,4),'42-active/128-slot/15-shadow animated camera pressure is measured offline; it does not establish the full original106ms cause or acceptance of diverse replicated crowds. Current skin build is still not applied to the existing live client.']};
await fs.writeFile(new URL('creation-experience-current-audit-v15.json',dir),JSON.stringify(audit,null,2)+'\n');
console.log(JSON.stringify({goalComplete:false,productionChange:false,cases:cases.map(c=>({robe:c.robe,retainedMedian:c.capacityComparison.retained.totalMs.median,freshMedian:c.capacityComparison.fresh.totalMs.median,durationMs:c.sustained.durationMs,timeline:c.sustained.timeline,hitches:c.sustained.hitches}))}));
