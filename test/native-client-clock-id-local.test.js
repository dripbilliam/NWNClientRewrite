import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeClientClockLifecycle} from '../src/network_client_clock_lifecycle.js';
import {NetworkWorld} from '../src/network_world.js';

// Desired native per-ID contract. This file intentionally starts RED against
// the frozen globally-poisoning helper. It changes no accepted source/tests.
const ONE=0x80000041,TWO=0x80000042,THREE=0x80000043;
const A=id=>({action:'create',objectType:5,id,state:{areaId:91}});
const P=id=>({action:'appearance',objectType:5,id,mask:0x400,state:{name:{text:'Unknown owner'}}});
const D=id=>({action:'delete',objectType:5,id,remove:1});
const proxy=id=>({id,objectType:5});
const context=(p,canonical=null,externalOwner='absent')=>({canonicalBefore:canonical,stagedProxy:p,externalOwner,areaId:91});
function helper(options={}){const owner={};return {owner,h:new NativeClientClockLifecycle({owner,connection:3,recordHistoryComplete:true,externalRegistryHistoryComplete:true,...options})};}
function accept(f,records,contexts,{complete=true}={}){
 const tx=new Map();f.h.begin(tx,{complete,recordCount:records.length});records.forEach((record,index)=>f.h.observe(tx,record,index,contexts[index]));
 const list=f.h.commit(tx,id=>contexts.find(value=>value.canonicalBefore?.id===id)?.canonicalBefore??contexts.find(value=>value.stagedProxy?.id===id)?.stagedProxy??null);
 f.h.publish(tx);return {list,rows:list.map(boundary=>f.h.acceptedBoundary(f.owner,boundary))};
}
function world(){const w=new NetworkWorld({onDiagnostic:()=>{}});w.areaId=91;w.bindNativeClockConnection(3);return w;}
const apply=(w,records,complete=true)=>w.apply({kind:'object-updates',records,complete});
function facts(w,records){const values=w.nativeClockLifecycleBoundaries(records);assert.ok(values);return values.map(value=>w.nativeClockLifecycleBoundary(value));}
const name=(w,id)=>w.nativeActorNameFor(w.registry.get(id));

test('RED helper: valid unknown ID2 does not suppress a separately absent fresh ID3 across transactions',()=>{
 const f=helper(),p1=proxy(ONE),p2=proxy(TWO),p3=proxy(THREE);
 const first=accept(f,[A(ONE)],[context(p1)]),saved=structuredClone(first.rows[0]);
 const unknown=accept(f,[P(TWO),A(TWO)],[context(p2,null,'unknown'),context(p2,null,'unknown')]);
 assert.equal(unknown.rows[0].fact.constructionCertified,false);assert.equal(unknown.rows[0].fact.physicalToken,null);assert.equal(unknown.rows[0].recordHistoryComplete,true);
 const third=accept(f,[A(THREE)],[context(p3)]).rows[0];
 assert.equal(third.fact.constructionCertified,true,'Complete ID2 ambiguity is not a registry-history gap for never-seen ID3');
 assert.equal(third.fact.aiRegistrationCertified,true);assert.equal(third.fact.ownership,'new');assert.equal(third.constructionHistoryComplete,true);assert.equal(third.complete,true);
 assert.notEqual(third.fact.physicalToken,first.rows[0].fact.physicalToken);assert.deepEqual(f.h.acceptedBoundary(f.owner,first.list[0]),saved);
});

test('RED helper: same-batch per-ID event certainty is new1/unknown2/new3, not a poisoned suffix',()=>{
 const f=helper(),p1=proxy(ONE),p2=proxy(TWO),p3=proxy(THREE);
 const {rows}=accept(f,[A(ONE),P(TWO),A(TWO),A(THREE)],[context(p1),context(p2,null,'unknown'),context(p2,null,'unknown'),context(p3)]);
 assert.deepEqual(rows.map(row=>row.fact.recordIndex),[0,2,3]);assert.ok(rows.every(row=>row.complete));
 assert.deepEqual(rows.map(row=>row.fact.constructionCertified),[true,false,true]);
 assert.deepEqual(rows.map(row=>row.constructionHistoryComplete),[true,false,true]);
 assert.equal(rows[1].fact.physicalToken,null);assert.notEqual(rows[0].fact.physicalToken,rows[2].fact.physicalToken);
});

test('RED actual World: fresh ID3 clock certificate agrees with existing actor-name ctor after unknown ID2',()=>{
 const w=world(),one=[A(ONE)];apply(w,one);const saved=facts(w,one)[0];
 const two=[P(TWO),A(TWO)];apply(w,two);assert.equal(name(w,TWO).construction.kind,'unknown');assert.equal(facts(w,two)[0].fact.constructionCertified,false);
 const three=[A(THREE)];apply(w,three);const third=facts(w,three)[0];
 assert.equal(name(w,THREE).construction.kind,'new','Existing actor-name source already recognizes independent ID3 constructor');
 assert.equal(third.fact.constructionCertified,true,'Clock ctor ownership must agree for this same accepted absent type5 A');
 assert.equal(third.fact.aiRegistrationCertified,true);assert.equal(third.complete,true);assert.equal(third.constructionHistoryComplete,true);
 assert.equal(w.nativeClockLifecycleState(w.registry.get(ONE)).physicalCurrent,true);assert.deepEqual(facts(w,one)[0],saved);
});

test('RED actual World: same packet keeps per-record ID1/ID2/ID3 constructor certainty independent',()=>{
 const w=world(),records=[A(ONE),P(TWO),A(TWO),A(THREE)];apply(w,records);const rows=facts(w,records);
 assert.equal(name(w,ONE).construction.kind,'new');assert.equal(name(w,TWO).construction.kind,'unknown');assert.equal(name(w,THREE).construction.kind,'new');
 assert.deepEqual(rows.map(row=>row.fact.objectId),[ONE,TWO,THREE]);assert.deepEqual(rows.map(row=>row.fact.recordIndex),[0,2,3]);
 assert.deepEqual(rows.map(row=>row.fact.constructionCertified),[true,false,true]);assert.deepEqual(rows.map(row=>row.constructionHistoryComplete),[true,false,true]);
 assert.ok(rows.every(row=>row.recordHistoryComplete));
});

test('countercase: initially unverified external/record histories still block every fresh certificate',()=>{
 for(const options of [{externalRegistryHistoryComplete:false},{recordHistoryComplete:false}]){
  const f=helper(options),row=accept(f,[A(THREE)],[context(proxy(THREE))]).rows[0];
  assert.equal(row.fact.constructionCertified,false);assert.equal(row.fact.aiRegistrationCertified,false);assert.equal(row.fact.physicalToken,null);assert.equal(row.constructionHistoryComplete,false);
 }
});

test('countercase: actual incomplete record prefix and rollback poison unrelated future helper IDs globally',()=>{
 for(const mode of ['incomplete','rollback']){
  const f=helper();
  if(mode==='incomplete')accept(f,[],[],{complete:false});
  else {const tx={};f.h.begin(tx,{complete:true,recordCount:1});f.h.observe(tx,A(ONE),0,context(proxy(ONE)));f.h.abort(tx);}
  const row=accept(f,[A(THREE)],[context(proxy(THREE))]).rows[0];
  assert.equal(row.complete,false);assert.equal(row.constructionHistoryComplete,false);assert.equal(row.fact.constructionCertified,false);assert.equal(row.fact.physicalToken,null);
 }
});

test('countercase: actual World incomplete/untracked/rejected history remains globally conservative',()=>{
 for(const mode of ['incomplete','untracked','rollback']){
  const w=world();
  if(mode==='incomplete')apply(w,[],false);
  else if(mode==='untracked')w.applyObjectUpdates([]);
  else {apply(w,[A(ONE)]);assert.throws(()=>apply(w,[P(ONE),{action:'create',objectType:6,id:ONE,state:{}}]),/Conflicting/);}
  const records=[A(THREE)];apply(w,records);const row=facts(w,records)[0];
  assert.equal(row.complete,false);assert.equal(row.constructionHistoryComplete,false);assert.equal(row.fact.constructionCertified,false);assert.equal(name(w,THREE).construction.kind,'unknown');
 }
});

test('countercase: same-ID D+A is still ambiguous and cannot mint a new constructor or revive old token',()=>{
 const f=helper(),p=proxy(ONE),old=accept(f,[A(ONE)],[context(p)]).rows[0];
 const staged={...p},returned=accept(f,[D(ONE),A(ONE)],[context(staged,p,'live'),context(staged,p,'unknown')]).rows;
 assert.equal(returned[1].fact.ownership,'unknown');assert.equal(returned[1].fact.constructionCertified,false);assert.equal(returned[1].fact.aiRegistrationCertified,false);assert.equal(returned[1].fact.physicalToken,null);
 assert.equal(f.h.stateFor(f.owner,p).physicalToken,old.fact.physicalToken);assert.equal(f.h.stateFor(f.owner,p).physicalCurrent,false);
 const w=world(),first=[A(ONE)];apply(w,first);const token=facts(w,first)[0].fact.physicalToken;
 const records=[D(ONE),A(ONE)];apply(w,records);const rows=facts(w,records);
 assert.equal(rows[1].fact.constructionCertified,false);assert.equal(rows[1].fact.aiRegistrationCertified,false);assert.equal(rows[1].fact.physicalToken,null);
 assert.equal(w.nativeClockLifecycleState(w.registry.get(ONE)).physicalToken,token);assert.equal(w.nativeClockLifecycleState(w.registry.get(ONE)).physicalCurrent,false);
});

test('unknown no-proxy D tombstone stays local across transactions and clears with its epoch',()=>{
 const f=helper();
 const deletion=accept(f,[D(TWO)],[context(null,null,'unknown')]).rows[0];
 assert.equal(deletion.fact.physicalToken,null);assert.equal(deletion.fact.ownerAbsentCertified,false);assert.equal(deletion.constructionHistoryComplete,false);assert.equal(deletion.complete,true);
 const unrelated=accept(f,[A(THREE)],[context(proxy(THREE))]).rows[0];assert.equal(unrelated.fact.constructionCertified,true);
 const same=accept(f,[A(TWO)],[context(proxy(TWO))]).rows[0];assert.equal(same.fact.constructionCertified,false);assert.equal(same.fact.physicalToken,null);
 const reset=helper();assert.equal(accept(reset,[A(TWO)],[context(proxy(TWO))]).rows[0].fact.constructionCertified,true);
});
