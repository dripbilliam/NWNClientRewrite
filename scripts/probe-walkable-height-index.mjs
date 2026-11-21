// Read-only installed/native and authored module walkmeshes; no network joins.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {openLocalModule} from './local-module.mjs';import {parseAreaModule,loadAreaWalkmesh} from '../src/area.js';import {findWalkableHeight} from '../src/walkmesh.js';import {WalkableHeightIndex} from '../src/walkable_height_index.js';
const sha=b=>createHash('sha256').update(b).digest('hex'),report={scope:'Offline installed Prelude and authored DensePerf exact grounding queries; timings are CPU queries, not FPS',joins:0,httpAttempts:0,sourceHashes:{},areas:[]};
for(const file of ['src/walkable_height_index.js','src/network_scene.js','src/walkmesh.js','scripts/probe-walkable-height-index.mjs'])report.sourceHashes[file]=sha(await fs.readFile(file));
for(const [module,names]of [['../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm',['m0q1a','m0q1b']],['runtime-logs/dense-performance-server/modules/DensePerf.mod',['dense_a','dense_b']]]){
 const resolver=await openLocalModule('../FullDecomp/NwnRootInstall',module);
 for(const name of names){
  const area=await parseAreaModule(name,resolver),walkmesh=await loadAreaWalkmesh(area,resolver);assert.deepEqual(walkmesh.missing,[]);
  const began=performance.now(),index=new WalkableHeightIndex(walkmesh.triangles),buildMs=performance.now()-began,queries=[];let seed=41;
  const random=()=>((seed=Math.imul(seed,1664525)+1013904223|0)>>>0)/2**32;
  for(let i=0;i<4000;i++)queries.push([random()*area.width*10,-random()*area.height*10,i%3?random()*8-2:Infinity,i%5?Infinity:.4]);
  for(const t of walkmesh.triangles.slice(0,300))for(let i=0;i<3;i++){const a=t.vertices[i],b=t.vertices[(i+1)%3];for(const epsilon of [-1e-5,0,1e-5])queries.push([(a[0]+b[0])*.5+epsilon,(a[2]+b[2])*.5-epsilon,(a[1]+b[1])*.5,Infinity]);}
  const values=[];for(const q of queries){const actual=index.height(...q),expected=findWalkableHeight(walkmesh.triangles,...q);assert.ok(Object.is(actual,expected),`${name} query mismatch`);values.push(actual);}
  const initial=index.snapshot();const scan=()=>{let sum=0;for(const q of queries)sum+=findWalkableHeight(walkmesh.triangles,...q)??0;return sum;},indexed=()=>{let sum=0;for(const q of queries)sum+=index.height(...q)??0;return sum;};
  assert.equal(scan(),indexed());const times=[];
  for(let pass=0;pass<5;pass++){let start=performance.now();const a=(pass%2?indexed:scan)(),first=performance.now()-start;start=performance.now();const b=(pass%2?scan:indexed)(),second=performance.now()-start;assert.equal(a,b);times.push(pass%2?{baselineMs:second,indexedMs:first}:{baselineMs:first,indexedMs:second});}
  index.dispose();const closed=index.snapshot();assert.equal(closed.cells,0);assert.equal(closed.references,0);assert.equal(index.source,null);
  report.areas.push({name,triangles:walkmesh.triangles.length,queries:queries.length,exact:true,resultSha256:sha(JSON.stringify(values)),buildMs,initial,times,closed});
 }
}
report.success=true;await fs.writeFile('backups/animations/height-index-offline-v1.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:true,areas:report.areas.map(a=>({name:a.name,triangles:a.triangles,queries:a.queries,candidateRatio:a.initial.candidates/(a.queries*a.triangles),baselineMs:a.times[2].baselineMs,indexedMs:a.times[2].indexedMs}))}));
