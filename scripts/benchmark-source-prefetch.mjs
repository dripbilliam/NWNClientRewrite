import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {Group} from 'three';import {NetworkScene} from '../src/network_scene.js';
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms)),runs=[];
for(const mode of ['ordered','prefetch','ordered','prefetch']){
 const objects=new Map(),trace=[],created=[],started=performance.now();let reads=0,active=0,peak=0,playerAt=null;
 const scene=new NetworkScene({world:{localObjectId:1,registry:{objects,get:id=>objects.get(id)}},resolver:{},loadAsset:async name=>{reads++;peak=Math.max(peak,++active);trace.push({kind:'read',name,at:performance.now()-started});await delay(15);active--;return{model:{nodes:[],animations:[]},textures:new Map()};},prepareAsset:()=>delay(2),instantiate:(_asset,name)=>{created.push(name);trace.push({kind:'instance',name,at:performance.now()-started});if(name==='m0')playerAt=performance.now()-started;return{root:new Group(),dispose(){}};},releaseAsset(){},report(){}});
 scene.area={id:9};scene.tables={placeables:{rows:new Map(Array.from({length:24},(_,i)=>[i,{ModelName:'m'+i}]))}};for(let i=23;i>=0;i--)objects.set(i+1,{id:i+1,objectType:9,areaId:9,replicated:{appearance:i,position:[i,0,0]}});
 if(mode==='ordered')scene.prefetchObjects=()=>{};
 await scene.requestSync();await scene.sourcePrefetch.idle();const durationMs=performance.now()-started;assert.equal(reads,24);assert.equal(created.length,24);assert.equal(created[0],'m0');assert.equal(scene.objects.size,24);assert.equal(new Set(created).size,24);
 runs.push({mode,durationMs,playerAt,reads,peakConcurrentReads:peak,prefetch:scene.sourcePrefetch.snapshot(),created,trace});await scene.dispose();
}
assert.deepEqual(runs[0].created,runs[1].created);assert.deepEqual(runs[2].created,runs[3].created);
const report={scope:'Production scene with injected 15ms independent IO and 2ms shader preparation; validates overlap, not actual network/server latency',runs};await fs.writeFile(new URL('../backups/animations/source-prefetch-overlap-v1.json',import.meta.url),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(runs.map(({trace,created,...summary})=>summary),null,2));
