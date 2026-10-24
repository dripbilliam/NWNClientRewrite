import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';
import {VisualDelivery} from './visual-delivery.mjs';import {isolateVisualDelivery} from './isolate-visual-delivery.mjs';
const deferred=()=>{let resolve;const promise=new Promise(value=>resolve=value);return{promise,resolve};};
const turn=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(){
 const actor={id:1,objectType:5,areaId:7},world={areaId:7,registry:new Map([[1,actor]])},session={world,areaGeneration:2,closed:false},sent=[],diagnostics=[],patches=[],report={};let ready=true;
 const metadata={particles:{emitters:[{id:1,objectId:0,nativeParent:{objectId:0,modelIndex:0,rigNode:1},nativeRoot:{objectId:0,modelIndex:0,rigNode:0},referenceTarget:{nativeRoot:{objectId:0,modelIndex:1,rigNode:4}}}]}},definition={resources:{authored:{manifest:metadata}}};
 const particle={patch:async value=>patches.push(value)};
 const options={session,connection:1,active:()=>true,ready:()=>ready?{connection:1,areaId:7,generation:session.areaGeneration,transferId:3}:null,prepare:async()=>definition,write:async()=>({file:'external-definition',sha256:'a'.repeat(64)}),tables:async()=>({columns:['Type_FD'],orderedRows:[{Type_FD:'I'}]}),particles:()=>particle,send:value=>sent.push(value),diagnose:(...row)=>diagnostics.push(row),report};
 const service=new VisualDelivery(options),add=visualId=>service.receive([{action:'visual-effects',id:1,changes:[{action:'A',visualId}]}]);
 return{actor,world,session,sent,diagnostics,patches,report,metadata,definition,particle,service,add,ready:value=>ready=value};
}
test('server event reservations/removals preserve physical order while assets resolve independently',async()=>{
 const f=fixture(),first=deferred(),second=deferred();let reads=0;f.service.prepare=()=>++reads===1?first.promise:second.promise;f.ready(false);f.add(10);f.add(10);f.service.receive([{action:'visual-effects',id:1,changes:[{action:'D',visualId:10}]}]);f.service.flush();assert.deepEqual(f.sent,[]);
 f.ready(true);f.service.flush();assert.deepEqual(f.sent.map(row=>row.kind),['visual-reserve','visual-reserve','visual-remove']);assert.deepEqual(f.sent.slice(0,2).map(row=>row.effectId),[1,2]);
 f.service.status({effectId:1,stage:'canceled'});second.resolve(f.definition);first.resolve(f.definition);await turn();assert.deepEqual(f.sent.filter(row=>row.kind==='visual-ready').map(row=>row.effectId),[2]);assert.equal(f.report.discarded,1);await f.service.close();assert.equal(f.report.pendingJobs,0);
});
test('area changes, same-number world reconnect and canonical actor replacement cannot publish old effect definitions',async()=>{
 for(const retire of [f=>f.session.areaGeneration++,f=>f.session.world={...f.world,registry:new Map([[1,f.actor]])},f=>f.world.registry.set(1,{...f.actor})]){
  const f=fixture(),gate=deferred();f.service.prepare=()=>gate.promise;f.add(10);f.service.flush();retire(f);gate.resolve(f.definition);await turn();assert.equal(f.sent.filter(row=>row.kind==='visual-ready').length,0);await f.service.close();
 }
});
test('native private model registration remaps emitter and binding identities without creating gameplay objects',async()=>{
 const f=fixture();f.add(10);f.service.flush();await turn();await f.service.modelCreated({effectId:1,modelId:11,resource:'authored'});
 const row=f.patches[0].add[0];assert.ok(row.id>2**40);assert.equal(row.objectId,-11);assert.equal(row.visualModel,11);assert.equal(row.nativeParent.visualModel,11);assert.equal(row.referenceTarget.nativeRoot.visualModel,11);assert.equal(f.metadata.particles.emitters[0].objectId,0);assert.equal(f.world.registry.size,1);assert.equal(f.sent.at(-1).kind,'visual-model-particles');
 await f.service.modelReleased({effectId:1,modelId:11});assert.deepEqual(f.patches.at(-1),{removeObjects:[-11],add:[]});assert.equal(f.service.models.size,0);await f.service.close();
});
test('model removal during a worker patch cannot resurrect private native particles',async()=>{
 const f=fixture(),gate=deferred();let count=0;f.particle.patch=async change=>{f.patches.push(change);if(++count===1)await gate.promise;};f.add(10);f.service.flush();await turn();const creating=f.service.modelCreated({effectId:1,modelId:12,resource:'authored'});await turn();await f.service.modelReleased({effectId:1,modelId:12});gate.resolve();await creating;
 assert.equal(f.sent.filter(row=>row.kind==='visual-model-particles').length,0);assert.deepEqual(f.patches.at(-1).removeObjects,[-12]);await f.service.close();assert.equal(f.report.pendingJobs,0);
});
test('ordinary instant visual messages use the original routing owner and preserve transient flags',async()=>{
 const f=fixture();await f.service.instant({visualId:0,targetId:1,position:[1,2,3]});f.service.flush();await turn();assert.equal(f.sent[0].transient,true);const entry=[...f.service.entries.values()][0];assert.equal(entry.record.delivery.instant,1);assert.equal(entry.record.sourceId,0x7f000000);assert.equal(f.report.input[0].kind,'instant');await f.service.close();
});
test('unready host models retry without losing effect identity or reserving duplicate positions',async()=>{
 const f=fixture();let calls=0,now=0;f.service.now=()=>now;f.service.prepare=async()=>++calls===1?{pending:true}:f.definition;f.add(10);f.service.flush();await turn();now=100;f.service.flush();await turn();assert.equal(f.sent.filter(row=>row.kind==='visual-reserve').length,1);assert.equal(f.sent.filter(row=>row.kind==='visual-ready').length,1);await f.service.close();
});
test('isolated build disables only old object-visual presentation while retaining original resource providers',async()=>{
 const original=await fs.readFile('src/network_scene.js','utf8'),changed=isolateVisualDelivery(original);assert.ok(original.includes('return this.visuals?.receive(events)'));assert.ok(changed.includes('receiveVisualChanges(_events){return Promise.resolve();}'));assert.ok(changed.includes('receiveObjectVisual(_message){return Promise.resolve();}'));assert.ok(changed.includes('receiveAreaVisual'));assert.throws(()=>isolateVisualDelivery(changed),/boundary/);assert.equal(await fs.readFile('src/network_scene.js','utf8'),original);
});
