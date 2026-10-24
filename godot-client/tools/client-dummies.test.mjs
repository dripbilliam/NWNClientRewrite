import {test} from 'node:test';import assert from 'node:assert/strict';
import {ClientDummies} from './client-dummies.mjs';import {VisualDelivery} from './visual-delivery.mjs';
const turn=()=>new Promise(resolve=>setImmediate(resolve));
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{resolve,promise};};
function fixture(){
 const canonical={id:0,objectType:5,areaId:7},world={areaId:7,registry:new Map([[0,canonical]])},session={world,areaGeneration:2},sent=[],diagnostics=[],report={};let ready=true,reads=0;
 const result={manifest:{kind:'visual-model',modelResources:['c_dummy'],rigs:{entities:[{models:[{partNames:['c_Dummy','rootdummy','Impact']}]}]}}};
 const scope=()=>ready?{connection:1,areaId:7,generation:session.areaGeneration,transferId:3}:null;
 const owner=new ClientDummies({session,connection:1,active:()=>true,ready:scope,prepare:async()=>{reads++;return result;},write:async()=>({scene:'external.glb',sha256:'a'.repeat(64),metadataSha256:'b'.repeat(64)}),send:v=>sent.push(v),diagnose:(...v)=>diagnostics.push(v),report});
 return{owner,world,session,sent,diagnostics,report,canonical,scope,result,ready:v=>ready=v,reads:()=>reads};
}
test('point/target dummies share original monotonic internal IDs and c_dummy resource, never canonical IDs',async()=>{
 const f=fixture();const a=await f.owner.create('point',[1.1,2.2,3.3],10000),b=await f.owner.create('target',[4,5,6],6000);
 assert.deepEqual([a.id,b.id],[0,1]);assert.equal(f.reads(),1);assert.equal(f.world.registry.size,1);assert.equal(f.world.registry.get(0),f.canonical);assert.equal(f.canonical.id,0);
 assert.equal(a.position[0],Math.fround(1.1));assert.equal(a.appearance,201);assert.equal(a.temporary,1);assert.deepEqual(f.sent[0].delay,[1,1,10000]);
 assert.equal(f.owner.status({...f.scope(),id:0,token:1,stage:'expired',transferId:2}),false);assert.equal(f.owner.has(a),true);
 assert.equal(f.owner.status({...f.scope(),id:0,token:1,stage:'expired'}),true);assert.equal(f.owner.has(a),false);
 const c=await f.owner.create('point',[0,0,0],10000);assert.equal(c.id,2);await f.owner.close();assert.equal(f.owner.objects.array.objects.size,0);assert.equal(f.report.pending,0);
});
test('original source-role successful registration abort is retained and inaccessible allocations are reclaimed',async()=>{
 const f=fixture();assert.equal(await f.owner.create('source',[1,2,3],6000),null);assert.equal(f.sent.length,0);assert.equal(f.owner.objects.array.objects.size,0);assert.equal(f.diagnostics[0][0],'visual.object-dummy-source-native-abort');
 assert.equal((await f.owner.create('point',[1,2,3],10000)).id,1);await f.owner.close();
});
test('unadmitted point effects queue without model IO and close resolves pending receivers',async()=>{
 const f=fixture();f.ready(false);const waiting=f.owner.create('point',[1,2,3],10000);assert.equal(f.reads(),0);assert.equal(f.owner.queue.length,1);await f.owner.close();assert.equal(await waiting,null);assert.equal(f.sent.length,0);
});
test('resource IO from a retired area/world/connection cannot publish private owners',async()=>{
 for(const retire of [f=>f.session.areaGeneration++,f=>f.session.world={...f.world},f=>f.session.closed=true]){
  const f=fixture(),gate=deferred();f.owner.prepare=()=>gate.promise;const waiting=f.owner.create('point',[1,2,3],10000);retire(f);gate.resolve(f.result);assert.equal(await waiting,null);assert.equal(f.sent.length,0);assert.equal(f.owner.owned.size,0);await f.owner.close();
 }
});
test('actual original instant routing reserves private host token and cancels asynchronous definition after expiry',async()=>{
 const f=fixture(),report={},prepared=[],gate=deferred();
 const service=new VisualDelivery({session:f.session,connection:1,active:()=>true,ready:f.scope,dummies:f.owner,prepare:async request=>{prepared.push(request);return gate.promise;},write:async()=>({file:'external',sha256:'c'.repeat(64)}),tables:async()=>({columns:['Type_FD'],orderedRows:[{Type_FD:'I'}]}),particles:()=>null,send:v=>f.sent.push(v),diagnose:()=>{},report});
 await service.instant({visualId:0,targetId:0x7f000000,position:[1,2,3]});service.flush();await turn();
 const entry=[...service.entries.values()][0];assert.equal(entry.actor===f.canonical,false);assert.equal(entry.privateHost.token,1);assert.equal(f.sent[0].kind,'client-dummy');assert.equal(f.sent[1].privateToken,1);assert.equal(prepared[0].privateHosts[0].model.loadedName,'c_dummy');
 f.owner.status({...f.scope(),id:0,token:1,stage:'expired'});gate.resolve({resources:{}});await turn();assert.equal(f.sent.some(row=>row.kind==='visual-ready'),false);service.flush();assert.equal(f.sent.at(-1).kind,'visual-cancel');await service.close();assert.equal(report.pendingJobs,0);
});
test('closing visual delivery with an unadmitted instant dummy cannot deadlock',async()=>{
 const f=fixture();f.ready(false);const service=new VisualDelivery({session:f.session,connection:1,active:()=>true,ready:f.scope,dummies:f.owner,tables:async()=>({columns:['Type_FD'],orderedRows:[{Type_FD:'I'}]}),send:()=>{},diagnose:()=>{},report:{}});
 const receiving=service.instant({visualId:0,targetId:0x7f000000,position:[0,0,0]});await turn();assert.equal(f.owner.queue.length,1);await service.close();await receiving;assert.equal(service.instantJobs.size,0);
});
test('area effects use the shared internal allocator and release their type11 identity on failure or native retirement',async()=>{
 for(const fail of [false,true]){
  const f=fixture(),sent=[],report={};let prepared;
  const service=new VisualDelivery({session:f.session,connection:1,active:()=>true,ready:f.scope,dummies:f.owner,prepare:async value=>{prepared=value;if(fail)throw Error('Authored IO failure');return{resources:{}};},write:async()=>({file:'external',sha256:'a'.repeat(64)}),send:v=>sent.push(v),diagnose:()=>{},report});
  service.areaInstant({visualId:69,position:[1,2,3]});service.flush();await turn();
  assert.equal(prepared.kind,'area-visual');assert.equal(f.owner.owned.get(0)?.actor.objectType,fail?undefined:11);assert.equal(sent[0].areaVisual,true);assert.equal(f.world.registry.get(0),f.canonical);
  if(!fail){assert.equal(sent.at(-1).kind,'visual-ready');service.status({effectId:1,stage:'retired'});assert.equal(f.owner.owned.size,0);}
  assert.equal(f.report.areaAllocated,1);assert.equal(f.report.areaRetired,1);const dummy=await f.owner.create('point',[0,0,0],10000);assert.equal(dummy.id,1);await service.close();
 }
});
