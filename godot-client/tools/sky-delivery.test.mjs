import test from 'node:test';import assert from 'node:assert/strict';
import {SkyDelivery} from './sky-delivery.mjs';
const deferred=()=>{let resolve;return{promise:new Promise(r=>resolve=r),resolve};};
function fixture(){
 const session={world:{areaId:8},areaGeneration:2},scope={connection:4,areaId:8,generation:2,transferId:3},sent=[],diagnostics=[],prepared=[],written=[];
 let active=true,ready=scope;
 const table={orderedRows:[{}, {DAWN:'SkyDa_001',DAY:'Sky_001',DUSK:'SkyD_001',NIGHT:'SkyN_001'}, {DAWN:'SkyBl_001',DAY:'SkyBl_001',DUSK:'SkyBl_001',NIGHT:'SkyBl_001'}]};
 const owner=new SkyDelivery({session,connection:4,active:()=>active,ready:()=>ready,rules:async()=>table,prepare:async name=>{prepared.push(name);return{name};},write:async value=>{written.push(value.name);return{scene:value.name,sha256:'authorfixture'};},send:v=>sent.push(v),diagnose:(code,reason)=>diagnostics.push({code,reason})});
 return {owner,session,scope,sent,diagnostics,prepared,written,table,retire:()=>active=false,unready:()=>ready=null};
}
const settled=async f=>Promise.all([...f.owner.jobs]);
test('original physical phases resolve through session rules and models; no repeated frame IO',async()=>{
 const f=fixture();f.owner.flush(1);await settled(f);
 assert.deepEqual(f.prepared,['skyda_001','sky_001','skyd_001','skyn_001','skyfade1']);assert.deepEqual(f.written,f.prepared);assert.equal(f.sent.length,1);assert.deepEqual(f.sent[0].phases,f.prepared.slice(0,4));assert.equal(f.sent[0].horizon,'skyfade1');assert.equal(f.sent[0].kind,'area-sky');
 for(let i=0;i<1000;i++)f.owner.flush(1);await settled(f);assert.equal(f.sent.length,1);assert.equal(f.prepared.length,5);
 assert.deepEqual(Object.fromEntries(Object.keys(f.scope).map(k=>[k,f.sent[0][k]])),f.scope);
});
test('noncyclical shared original model imports once and sky zero needs no asset/table IO',async()=>{
 const f=fixture();f.owner.flush(2);await settled(f);assert.deepEqual(f.prepared,['skybl_001','skyfade1']);assert.equal(new Set(f.sent[0].phases).size,1);
 f.owner.flush(0);await settled(f);assert.deepEqual(f.sent[1].phases,[]);assert.deepEqual(f.sent[1].resources,{});assert.equal(f.sent[1].horizon,null);assert.equal(f.prepared.length,2);
});
test('a delayed old area bundle cannot enter another native world, even if IDs recur',async()=>{
 const f=fixture(),gate=deferred();f.owner.prepare=async()=>gate.promise;f.owner.flush(1);await Promise.resolve();
 f.session.world={areaId:8};f.session.areaGeneration=3;f.scope.generation=3;gate.resolve({});await settled(f);assert.equal(f.sent.length,0);
 f.owner.flush(2);await settled(f);assert.equal(f.sent.length,1);assert.equal(f.sent[0].generation,3);
});
test('retirement waits pending asset work and suppresses both delivery and stale errors',async()=>{
 const f=fixture(),gate=deferred();f.owner.prepare=async()=>gate.promise;f.owner.flush(1);await Promise.resolve();let closed=false;const end=f.owner.close().then(()=>closed=true);
 await Promise.resolve();assert.equal(closed,false);gate.resolve(null);await end;assert.equal(f.owner.jobs.size,0);assert.equal(f.sent.length,0);assert.equal(f.diagnostics.length,0);
});
test('unready, closed, invalid or mismatched native scopes do not start sky preparation',async()=>{
 for(const change of [f=>f.unready(),f=>f.retire(),f=>f.session.closed=true,f=>f.scope.connection++,f=>f.scope.areaId++,f=>f.scope.generation++]){const f=fixture();change(f);f.owner.flush(1);await settled(f);assert.equal(f.prepared.length,0);assert.equal(f.sent.length,0);}
 const f=fixture();for(const v of [-1,256,NaN,1.5,'1'])f.owner.flush(v);await settled(f);assert.equal(f.sent.length,0);
});
test('missing table rows and invalid phase refs are diagnosed without fabricated fallback art',async()=>{
 const f=fixture();f.owner.flush(9);await settled(f);assert.equal(f.sent.length,0);assert.equal(f.diagnostics[0].code,'godot.sky-preparation-failed');
 f.table.orderedRows[1].DAY='../not_a_model';f.owner.flush(1);await settled(f);assert.equal(f.prepared.length,0);assert.equal(f.sent.length,0);assert.equal(f.diagnostics.length,2);
});
