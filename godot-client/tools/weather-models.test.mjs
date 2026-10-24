import test from 'node:test';import assert from 'node:assert/strict';import {WeatherModels} from './weather-models.mjs';import {validateCommand} from './local-protocol.cjs';
const gate=()=>{let resolve;return{promise:new Promise(r=>resolve=r),resolve};};
function fixture(){
 const scope={connection:2,areaId:7,generation:1,transferId:3},session={world:{areaId:7},areaGeneration:1},sent=[],patches=[],reads=[],diagnostics=[];
 const manifest={particles:{emitters:Array.from({length:4},(_,i)=>({id:i,objectId:0,properties:{texture:'authored'},nativeParent:{objectId:0,rigNode:i,modelIndex:0},nativeRoot:{objectId:0,rigNode:0,modelIndex:0},clips:{rain:{length:3,tracks:[{property:'emitter.birthrate',keys:[0,70]}]}}}))}};
 const bundle={manifest};const delivery={patch:async change=>patches.push(structuredClone(change))};
 const owner=new WeatherModels({session,connection:2,active:()=>true,ready:()=>scope,prepare:async name=>{reads.push(name);return bundle;},write:async()=>({scene:'outside',sha256:'authored'}),particles:()=>delivery,send:v=>sent.push(v),diagnose:(...v)=>diagnostics.push(v)});
 const message={...scope,kind:'weather-state',weather:{type:1,enabled:true},rows:{1:{model:'fx_rain',animation:'rain'}}};
 const activate={resourceId:1,type:1,batchId:1,ids:[1,2,3,4,5,6]};return{owner,scope,session,sent,patches,reads,diagnostics,bundle,delivery,message,activate};
}
test('original four-emitter metadata becomes six independent private model bindings and24 worker entries',async()=>{
 const f=fixture();await f.owner.receive(f.message,f.session.world);await f.owner.receive(f.message,f.session.world);assert.deepEqual(f.reads,['fx_rain']);assert.equal(f.sent.length,1);
 await f.owner.activate(f.activate);const rows=f.patches[0].add;assert.equal(rows.length,24);assert.equal(new Set(rows.map(v=>v.id)).size,24);assert.equal(new Set(rows.map(v=>v.objectId)).size,6);assert.ok(rows.every(v=>v.awaitPose&&v.weatherModel===v.nativeParent.weatherModel&&v.weatherModel===v.nativeRoot.weatherModel));assert.ok(f.bundle.manifest.particles.emitters.every(v=>v.objectId===0&&!v.weatherModel));
 assert.equal(f.sent[1].emitters.length,24);assert.equal(f.sent[1].emitters[0].clips.rain.tracks,undefined);assert.equal(rows[0].clips.rain.tracks.length,1);
 await f.owner.release({batchId:1});assert.equal(f.patches[1].removeObjects.length,6);assert.equal(f.owner.batches.size,0);
 await assert.rejects(f.owner.activate({...f.activate,batchId:2}),/recycled/);
});
test('native weather protocol requires one scoped batch of exactly six unique private identities',()=>{
 const scope={connection:2,areaId:7,generation:1},m={...scope,transferId:3,kind:'weather-create',resourceId:1,type:1,batchId:1,ids:[1,2,3,4,5,6]};assert.doesNotThrow(()=>validateCommand(m,scope));
 for(const change of [{ids:[1,2]},{ids:[1,2,3,4,5,5]},{ids:[1,2,3,4,5,Infinity]},{type:0},{type:256},{resourceId:0},{transferId:-1},{batchId:0},{connection:1},{generation:0}])assert.throws(()=>validateCommand({...m,...change},scope));
});
test('retired worlds, generation and ticket never receive a delayed weather bundle',async()=>{
 for(const change of [f=>f.session.world={areaId:7},f=>f.scope.generation++,f=>f.scope.transferId++,f=>f.scope.connection++]){const f=fixture(),g=gate();f.owner.prepare=()=>g.promise;const work=f.owner.receive(f.message,f.session.world);change(f);g.resolve(f.bundle);await work;assert.equal(f.sent.length,0);}
});
test('release during a worker patch removes old emitter owners and suppresses stale native adoption',async()=>{
 const f=fixture(),g=gate();await f.owner.receive(f.message,f.session.world);let first=true;f.delivery.patch=async c=>{f.patches.push(c);if(first){first=false;await g.promise;}};
 const create=f.owner.activate(f.activate);await Promise.resolve();const remove=f.owner.release({batchId:1});g.resolve();await Promise.all([create,remove]);assert.equal(f.sent.length,1);assert.ok(f.patches.slice(1).every(v=>v.removeObjects.length===6&&v.add.length===0));
});
test('close waits pending model staging, publishes nothing and releases captured source worlds',async()=>{
 const f=fixture(),g=gate();f.owner.prepare=()=>g.promise;const create=f.owner.receive(f.message,f.session.world);let closed=false;const end=f.owner.close().then(()=>closed=true);await Promise.resolve();assert.equal(closed,false);g.resolve(f.bundle);await Promise.all([create,end]);assert.equal(f.sent.length,0);assert.equal(f.owner.context,null);assert.equal(f.owner.jobs.size,0);
});
