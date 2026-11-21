import test from 'node:test';import assert from 'node:assert/strict';
import {prepareResourceBatch} from '../src/resource_preparation.js';
import {NetworkScene} from '../src/network_scene.js';
import {NetworkWorld} from '../src/network_world.js';
const gate=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};
test('preparation overlaps independent resources with a bounded live set and retains input-indexed failures',async()=>{
 const gates=Array.from({length:7},gate),started=[];let active=0,peak=0;
 const work=prepareResourceBatch(gates,async(g,i)=>{started.push(i);peak=Math.max(peak,++active);await g.promise;active--;if(i===2)throw Error('bad resource');return i;},{limit:3});
 assert.deepEqual(started,[0,1,2]);gates[1].resolve();await new Promise(r=>setImmediate(r));assert.deepEqual(started,[0,1,2,3]);
 for(const g of gates)g.resolve();const results=await work;assert.equal(peak,3);assert.equal(results[2].status,'rejected');assert.match(results[2].reason.message,/bad resource/);assert.deepEqual(results.filter(r=>r.status==='fulfilled').map(r=>r.value),[0,1,3,4,5,6]);
});
test('closing an owner stops unscheduled preparation while waiting for already-started jobs',async()=>{
 const g=gate(),started=[];let current=true,finished=false;const work=prepareResourceBatch([1,2,3,4],async n=>{started.push(n);await g.promise;return n;},{limit:2,current:()=>current}).then(v=>{finished=true;return v;});
 current=false;await Promise.resolve();assert.equal(finished,false);g.resolve();await work;assert.deepEqual(started,[1,2]);
});
test('scene prefetch has no logical instances, preserves fallback/error ownership and remains resolver-scoped',async()=>{
 const make=server=>new NetworkScene({world:new NetworkWorld(),resolver:{server},loadAsset:async(name,resolver)=>{if(name==='bad')throw Error('missing');return{model:{server:resolver.server},textures:new Map()};},instantiate:asset=>({root:{removeFromParent(){}},dispose(){},server:asset.model.server}),releaseAsset:()=>{},report:()=>{}});
 const a=make('A'),b=make('B');await a.prepareModels([{model:'same'},{model:'bad',fallbackModel:'same'}]);assert.equal(a.instances.size,0);assert.equal(a.objects.size,0);
 assert.equal((await a.model('same')).server,'A');assert.equal((await b.model('same')).server,'B');await assert.rejects(a.model('bad'),/missing/);await a.dispose();await b.dispose();
});
