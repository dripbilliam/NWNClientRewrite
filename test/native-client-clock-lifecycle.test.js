import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeClientClockLifecycle,NATIVE_CLIENT_CLOCK_LIFECYCLE_SOURCE} from '../src/network_client_clock_lifecycle.js';

const ID=0x80000042,OTHER=0x80000043;
const proxy=(id=ID)=>({id,objectType:5});
const A=(id=ID)=>({action:'create',objectType:5,id,state:{}});
const D=(remove=0,id=ID)=>({action:'delete',objectType:5,id,remove});
const context=(stagedProxy,canonicalBefore=null,externalOwner='absent',areaId=91)=>({stagedProxy,canonicalBefore,externalOwner,areaId});
function setup(options={}){const owner={};return {owner,helper:new NativeClientClockLifecycle({owner,connection:3,recordHistoryComplete:true,externalRegistryHistoryComplete:true,...options})};}
function accepted(f,records,contexts,{complete=true,resolve=null}={}){
 const transaction=new Map();f.helper.begin(transaction,{complete,recordCount:records.length});
 records.forEach((record,index)=>f.helper.observe(transaction,record,index,contexts[index]));
 const boundaries=f.helper.commit(transaction,resolve??(id=>contexts.find(value=>value.stagedProxy?.id===id)?.canonicalBefore??contexts.find(value=>value.stagedProxy?.id===id)?.stagedProxy??null));
 assert.equal(f.helper.acceptedBatch(f.owner,transaction),null);
 for(const boundary of boundaries)assert.equal(f.helper.acceptedBoundary(f.owner,boundary),null);
 assert.equal(f.helper.publish(transaction),boundaries);
 return {boundaries,rows:boundaries.map(boundary=>f.helper.acceptedBoundary(f.owner,boundary))};
}
function fresh(f,id=ID){const p=proxy(id);const result=accepted(f,[A(id)],[context(p)]);return {p,...result};}

test('fresh external A certifies constructor and AI registration only at committed complete registry boundary',()=>{
 const f=setup(),p=proxy(),tx=new Map();
 f.helper.begin(tx,{complete:true,recordCount:1});
 assert.deepEqual(f.helper.observe(tx,A(),0,context(p)),{observed:true,lifecycle:true});
 assert.equal(f.helper.stateFor(f.owner,p),null);
 const [boundary]=f.helper.commit(tx,id=>{assert.equal(id,ID);return p;});
 assert.equal(f.helper.acceptedBoundary(f.owner,boundary),null);assert.equal(f.helper.stateFor(f.owner,p),null);
 assert.equal(f.helper.acceptedBatch(f.owner,tx),null);f.helper.publish(tx);
 assert.deepEqual(Object.keys(boundary),[]);assert.ok(Object.isFrozen(boundary));
 const row=f.helper.acceptedBoundary(f.owner,boundary);
 assert.equal(row.version,1);assert.equal(row.source,NATIVE_CLIENT_CLOCK_LIFECYCLE_SOURCE);assert.equal(row.complete,true);
 assert.deepEqual({...row.fact,physicalToken:null},{operation:'create',recordIndex:0,objectId:ID,objectType:5,ownership:'new',deletionFlag:null,areaId:91,ownerAbsentCertified:false,constructionCertified:true,aiRegistrationCertified:true,physicalToken:null});
 assert.match(row.fact.physicalToken,new RegExp(`^client-clock:${row.epoch}:3:1$`));
 assert.equal(row.fact.nativeLifetime,undefined);assert.equal(row.fact.timestamp,undefined);
 assert.equal(f.helper.stateFor(f.owner,p).physicalCurrent,true);
});

test('unverified registry history, partial delta and existing generic proxies cannot certify fresh A',()=>{
 for(const mode of ['unverified','partial','generic']){
  const f=setup({externalRegistryHistoryComplete:mode!=='unverified'}),p=proxy(),old=mode==='generic'?proxy():null;
  p.firstSnapshot=true;p.nativeLifetime=1;p.timerConstructed=true;
  const {rows}=accepted(f,[{...A(),timerConstructed:true,typedOwnerAbsent:true}],[context(p,old,'absent')],{complete:mode!=='partial',resolve:()=>old??p});
  assert.equal(rows[0].fact.ownership,'unknown');assert.equal(rows[0].fact.physicalToken,null);
  assert.equal(rows[0].fact.constructionCertified,false);assert.equal(rows[0].fact.aiRegistrationCertified,false);
  assert.equal(f.helper.history(f.owner).complete,mode!=='partial');assert.equal(f.helper.history(f.owner).constructionHistoryComplete,mode==='generic');
  assert.equal(f.helper.stateFor(f.owner,old??p).constructionHistoryComplete,false);
 }
});

test('typed existing A retains known physical owner without a second construction or AI registration',()=>{
 const f=setup(),first=fresh(f),clone={...first.p};
 const {rows}=accepted(f,[A()],[context(clone,first.p,'unknown')],{resolve:()=>first.p});
 assert.equal(rows[0].fact.ownership,'retained');assert.equal(rows[0].fact.physicalToken,first.rows[0].fact.physicalToken);
 assert.equal(rows[0].fact.constructionCertified,false);assert.equal(rows[0].fact.aiRegistrationCertified,false);
 assert.equal(f.helper.stateFor(f.owner,clone),null);assert.equal(f.helper.history(f.owner).complete,true);
 const g=setup({externalRegistryHistoryComplete:false}),existing=proxy(),staged={...existing};
 const explicit=accepted(g,[A()],[context(staged,existing,'live')],{resolve:()=>existing});
 assert.equal(explicit.rows[0].fact.ownership,'retained');assert.ok(explicit.rows[0].fact.physicalToken);
 assert.equal(explicit.rows[0].fact.constructionCertified,false);assert.equal(explicit.rows[0].complete,true);assert.equal(explicit.rows[0].constructionHistoryComplete,false);
});

test('D preserves both raw BOOL bits and marks retained physical identity ambiguous, not destroyed',()=>{
 for(const bit of [0,1]){
  const f=setup(),first=fresh(f),staged={...first.p};
  const {rows}=accepted(f,[D(bit)],[context(staged,first.p,'live')],{resolve:()=>first.p});
  assert.equal(rows[0].fact.operation,'remove');assert.equal(rows[0].fact.deletionFlag,bit);
  assert.equal(rows[0].fact.physicalToken,first.rows[0].fact.physicalToken);
  const state=f.helper.stateFor(f.owner,first.p);
  assert.equal(state.presence,'removed-ambiguous');assert.equal(state.physicalCurrent,false);assert.ok(state.physicalToken);
  assert.equal(state.destroyed,undefined);
 }
});

test('absent D survives coalescing as an ordered unknown removal without creating a canonical owner',()=>{
 const f=setup();let calls=0;
 const {rows}=accepted(f,[D(1)],[context(null,null,'unknown',null)],{resolve:id=>{assert.equal(id,ID);calls++;return null;}});
 assert.equal(calls,1);assert.equal(rows.length,1);assert.equal(rows[0].fact.ownership,'unknown');
 assert.equal(rows[0].fact.deletionFlag,1);assert.equal(rows[0].fact.areaId,null);assert.equal(rows[0].fact.physicalToken,null);
 assert.equal(rows[0].complete,true);assert.equal(f.helper.history(f.owner).complete,true);assert.equal(f.helper.history(f.owner).constructionHistoryComplete,true);
 const next=fresh(f);assert.equal(next.rows[0].fact.constructionCertified,false);
 assert.equal(fresh(f,OTHER).rows[0].fact.constructionCertified,true,'Unknown absent-proxy D applies only to its own ID');
});

test('certified absent D is a complete no-op and permits the first fresh staged A in the same packet',()=>{
 for(const bit of [0,1]){
  const f=setup(),p=proxy();
  const {rows}=accepted(f,[D(bit),A()],[context(null,null,'absent'),context(p)]);
  assert.deepEqual(rows.map(row=>row.fact.recordIndex),[0,1]);
  assert.deepEqual(rows.map(row=>row.fact.ownerAbsentCertified),[true,false]);
  assert.deepEqual(rows.map(row=>row.fact.constructionCertified),[false,true]);
  assert.equal(rows[0].fact.physicalToken,null);assert.equal(rows[0].fact.deletionFlag,bit);
  assert.equal(rows[1].fact.ownership,'new');assert.match(rows[1].fact.physicalToken,/:1$/);
  assert.deepEqual(rows.map(row=>row.complete),[true,true]);assert.deepEqual(rows.map(row=>row.constructionHistoryComplete),[true,true]);
 }
 const f=setup();accepted(f,[D()],[context(null,null,'absent')]);
 assert.equal(f.helper.history(f.owner).constructionHistoryComplete,true);assert.equal(fresh(f).rows[0].fact.constructionCertified,true);
});

test('certified absent D permits one allocation only, never a second staged alias',()=>{
 const f=setup(),tx={},p=proxy(),alias=proxy();f.helper.begin(tx,{complete:true,recordCount:3});
 f.helper.observe(tx,D(),0,context(null,null,'absent'));f.helper.observe(tx,A(),1,context(p));
 assert.throws(()=>f.helper.observe(tx,A(),2,context(alias,null,'unknown')),/staged proxy alias/);
 assert.equal(f.helper.stateFor(f.owner,p),null);assert.equal(f.helper.history(f.owner).recordHistoryComplete,false);f.helper.abort(tx);
});

test('A/D/A in one packet retains independent ordered pre/post facts rather than the final row',()=>{
 const f=setup(),p=proxy();
 const {rows}=accepted(f,[A(),D(1),A()],[context(p),context(p,null,'unknown'),context(p,null,'unknown',92)]);
 assert.deepEqual(rows.map(row=>row.fact.recordIndex),[0,1,2]);
 assert.deepEqual(rows.map(row=>row.fact.operation),['create','remove','create']);
 assert.deepEqual(rows.map(row=>row.fact.ownership),['new','retained','unknown']);
 assert.deepEqual(rows.map(row=>row.fact.areaId),[91,91,92]);
 assert.deepEqual(rows.map(row=>row.fact.constructionCertified),[true,false,false]);
 assert.equal(rows[0].fact.physicalToken,rows[1].fact.physicalToken);assert.equal(rows[2].fact.physicalToken,null);
 assert.deepEqual(rows.map(row=>row.complete),[true,true,true]);assert.deepEqual(rows.map(row=>row.constructionHistoryComplete),[true,true,false]);
 assert.equal(f.helper.stateFor(f.owner,p).areaId,92);assert.equal(f.helper.stateFor(f.owner,p).physicalCurrent,false);
});

test('D+A can retain a token only from a separately trusted retained-owner fact',()=>{
 const f=setup(),first=fresh(f),staged={...first.p};
 const {rows}=accepted(f,[D(),A()],[context(staged,first.p,'live'),context(staged,first.p,'retained')],{resolve:()=>first.p});
 assert.equal(rows[1].fact.ownership,'retained');assert.equal(rows[1].fact.physicalToken,first.rows[0].fact.physicalToken);
 assert.equal(rows[1].fact.constructionCertified,false);assert.equal(f.helper.history(f.owner).complete,true);
 const g=setup(),old=fresh(g),s={...old.p};
 accepted(g,[D()],[context(s,old.p,'live')],{resolve:()=>old.p});
 const ambiguous=accepted(g,[A()],[context({...old.p},old.p,'live')],{resolve:()=>old.p});
 assert.equal(ambiguous.rows[0].fact.ownership,'unknown');assert.equal(ambiguous.rows[0].fact.physicalToken,null);
});

test('P/I/U allocation before A remains unknown even when raw DTO declares a constructor',()=>{
 for(const action of ['appearance','update','player-state','inventory-stats']){
  const f=setup(),p=proxy();
  const {rows}=accepted(f,[{action,objectType:5,id:ID,state:{timerConstructed:true}},A()],[context(p,null,'unknown'),context(p)]);
  assert.equal(rows.length,1);assert.equal(rows[0].fact.ownership,'unknown');assert.equal(rows[0].fact.constructionCertified,false);
  assert.equal(f.helper.stateFor(f.owner,p).physicalCurrent,false);
  assert.equal(rows[0].complete,true);assert.equal(rows[0].recordHistoryComplete,true);assert.equal(rows[0].constructionHistoryComplete,false);
  assert.equal(f.helper.history(f.owner).recordHistoryComplete,true);assert.equal(f.helper.history(f.owner).constructionHistoryComplete,true);
  assert.equal(f.helper.stateFor(f.owner,p).constructionHistoryComplete,false);
 }
});

test('unknown-born objects do not poison a different continuously tracked physical owner',()=>{
 const f=setup(),first=fresh(f),other=proxy(OTHER);
 accepted(f,[{action:'appearance',objectType:5,id:OTHER,state:{}}],[context(other,null,'unknown')]);
 assert.equal(f.helper.history(f.owner).recordHistoryComplete,true);assert.equal(f.helper.history(f.owner).constructionHistoryComplete,true);
 assert.equal(f.helper.stateFor(f.owner,first.p).physicalCurrent,true);
 const repeated=accepted(f,[A()],[context({...first.p},first.p,'unknown')],{resolve:()=>first.p});
 assert.equal(repeated.rows[0].fact.ownership,'retained');assert.equal(repeated.rows[0].fact.physicalToken,first.rows[0].fact.physicalToken);
 const later=fresh(f,0x80000044);assert.equal(later.rows[0].fact.constructionCertified,true);assert.equal(later.rows[0].complete,true);
});

test('a later live typed owner cannot inherit an ambiguous or gap-invalidated historical token',()=>{
 const f=setup(),first=fresh(f),staged={...first.p};
 accepted(f,[D(),A()],[context(staged,first.p,'live'),context(staged,first.p,'unknown')],{resolve:()=>first.p});
 const recovered=accepted(f,[A()],[context({...first.p},first.p,'live')],{resolve:()=>first.p});
 assert.equal(recovered.rows[0].fact.ownership,'retained');
 assert.notEqual(recovered.rows[0].fact.physicalToken,first.rows[0].fact.physicalToken);
 assert.equal(recovered.rows[0].fact.constructionCertified,false);assert.equal(recovered.rows[0].fact.aiRegistrationCertified,false);
 assert.equal(recovered.rows[0].complete,true);assert.equal(recovered.rows[0].constructionHistoryComplete,false);
 const g=setup(),old=fresh(g),tx={};g.helper.begin(tx,{complete:true,recordCount:0});g.helper.abort(tx);
 const afterGap=accepted(g,[A()],[context({...old.p},old.p,'live')],{resolve:()=>old.p});
 assert.notEqual(afterGap.rows[0].fact.physicalToken,old.rows[0].fact.physicalToken);
 assert.equal(afterGap.rows[0].fact.constructionCertified,false);
});

test('partial accepted history and rollback taint are sticky until a new registry epoch',()=>{
 const f=setup();accepted(f,[],[],{complete:false});
 assert.equal(f.helper.history(f.owner).complete,false);
 const later=fresh(f);assert.equal(later.rows[0].fact.constructionCertified,false);
 const next=new NativeClientClockLifecycle({owner:f.owner,connection:3,recordHistoryComplete:true,externalRegistryHistoryComplete:true}),p=proxy(),tx={};
 next.begin(tx,{complete:true,recordCount:1});next.observe(tx,A(),0,context(p));
 const [boundary]=next.commit(tx,()=>p);next.publish(tx);const row=next.acceptedBoundary(f.owner,boundary);
 assert.notEqual(row.epoch,later.rows[0].epoch);assert.equal(row.fact.constructionCertified,true);
 assert.equal(next.acceptedBoundary(f.owner,later.boundaries[0]),null);assert.equal(next.stateFor(f.owner,later.p),null);
});

test('abort publishes no state or token and never upgrades certainty on the next complete delta',()=>{
 const f=setup(),p=proxy(),tx={};f.helper.begin(tx,{complete:true,recordCount:1});f.helper.observe(tx,A(),0,context(p));
 assert.deepEqual(f.helper.abort(tx),{aborted:true});assert.equal(f.helper.stateFor(f.owner,p),null);
 assert.equal(f.helper.history(f.owner).complete,false);assert.throws(()=>f.helper.commit(tx,()=>p),/stale-or-untracked/);
 const canonical=proxy(),s={...canonical};
 const next=accepted(f,[A()],[context(s,canonical,'live')],{resolve:()=>canonical});
 assert.match(next.rows[0].fact.physicalToken,/:1$/);assert.equal(next.rows[0].fact.constructionCertified,false);
});

test('prepared commit exposes no accepted batch until publish and can be aborted without private mutation',()=>{
 const f=setup(),p=proxy(),tx={};f.helper.begin(tx,{complete:true,recordCount:1});f.helper.observe(tx,A(),0,context(p));
 const boundaries=f.helper.commit(tx,()=>p);
 assert.equal(f.helper.acceptedBatch(f.owner,tx),null);assert.equal(f.helper.acceptedBoundary(f.owner,boundaries[0]),null);assert.equal(f.helper.stateFor(f.owner,p),null);
 f.helper.abort(tx);assert.equal(f.helper.publish(tx),null);assert.equal(f.helper.acceptedBoundary(f.owner,boundaries[0]),null);
 const old=proxy(),s={...old},next=accepted(f,[A()],[context(s,old,'live')],{resolve:()=>old});
 assert.match(next.rows[0].fact.physicalToken,/:1$/);assert.equal(f.helper.history(f.owner).recordHistoryComplete,false);
});

test('publish uses prepared record metadata, returns detached opaque batch and does not reread rows',()=>{
 const f=setup(),p=proxy(),tx=new Map();f.helper.begin(tx,{complete:true,recordCount:1});f.helper.observe(tx,A(),0,context(p));
 let resolverCalls=0;const boundaries=f.helper.commit(tx,()=>{resolverCalls++;return p;});
 p.areaId=999;p.timerConstructed=false;p.replicated={timestamp:123};
 f.helper.publish(tx);assert.equal(resolverCalls,1);
 const batch=f.helper.acceptedBatch(f.owner,tx);assert.ok(Object.isFrozen(batch));assert.notEqual(batch,boundaries);assert.equal(batch[0],boundaries[0]);
 assert.equal(f.helper.acceptedBatch(f.owner,new Map(tx)),null);assert.equal(f.helper.acceptedBatch({},tx),null);
 const row=f.helper.acceptedBoundary(f.owner,batch[0]);assert.equal(row.fact.areaId,91);assert.equal(row.fact.timestamp,undefined);
 assert.equal(f.helper.publish(tx),null);
});

test('failed commit validates all canonical identities before any metadata/token publication',()=>{
 const f=setup(),one=proxy(),two=proxy(OTHER),tx={};
 f.helper.begin(tx,{complete:true,recordCount:2});f.helper.observe(tx,A(),0,context(one));f.helper.observe(tx,A(OTHER),1,context(two));
 assert.throws(()=>f.helper.commit(tx,id=>id===ID?one:{...two}),/Canonical commit identity changed/);
 assert.equal(f.helper.stateFor(f.owner,one),null);assert.equal(f.helper.stateFor(f.owner,two),null);assert.equal(f.helper.history(f.owner).complete,false);
 const old=proxy(),s={...old};const next=accepted(f,[A()],[context(s,old,'live')],{resolve:()=>old});
 assert.match(next.rows[0].fact.physicalToken,/:1$/);
});

test('ordered indices, malformed raw bits and untracked transactions reject without partial publication',()=>{
 for(const mode of ['index','count','remove','unknown-action','boundary']){
  const f=setup(),p=proxy(),tx={};f.helper.begin(tx,{complete:true,recordCount:1});
  const record=mode==='remove'?D(true):mode==='unknown-action'?{...A(),action:'invented'}:A();
  if(mode==='count')assert.throws(()=>f.helper.commit(tx,()=>p),/incomplete or stale/);
  else assert.throws(()=>f.helper.observe(tx,record,mode==='index'?1:0,mode==='boundary'?{}:context(p)),/Invalid native client clock lifecycle/);
  assert.equal(f.helper.stateFor(f.owner,p),null);assert.equal(f.helper.history(f.owner).complete,false);f.helper.abort(tx);
 }
 const f=setup();assert.throws(()=>f.helper.observe({},A(),0,{}),/stale-or-untracked/);assert.equal(f.helper.history(f.owner).complete,false);
});

test('only touched creature IDs are resolved; ignored records retain their physical indices',()=>{
 const f=setup(),p=proxy(),tx={},records=[{action:'work-remaining'},{action:'create',objectType:6,id:OTHER},A(),{action:'update',objectType:9,id:OTHER},D()];
 f.helper.begin(tx,{complete:true,recordCount:records.length});
 records.forEach((record,index)=>f.helper.observe(tx,record,index,context(p,null,index===2?'absent':'unknown')));
 const calls=[],boundaries=f.helper.commit(tx,id=>{calls.push(id);return p;});f.helper.publish(tx);
 assert.deepEqual(calls,[ID]);assert.deepEqual(boundaries.map(value=>f.helper.acceptedBoundary(f.owner,value).fact.recordIndex),[2,4]);
});

test('external namespace validation rejects internal/sentinel/reserved IDs without certifying birth',()=>{
 for(const id of [42,0x7f000000,0x81000000,0xff000000,-1,0x100000000]){
  const f=setup(),tx={},p=proxy(id);f.helper.begin(tx,{complete:true,recordCount:1});
  assert.throws(()=>f.helper.observe(tx,A(id),0,context(p)),/external creature identity/);assert.equal(f.helper.history(f.owner).complete,false);f.helper.abort(tx);
 }
 for(const id of [0x80000000,ID,0x80ffffff,0xff000001,0xffffffff]){const f=setup();assert.equal(fresh(f,id).rows[0].fact.constructionCertified,true);}
});

test('getters accept private boundaries only, return detached scalars and reject proxy aliases',()=>{
 const f=setup(),first=fresh(f),boundary=first.boundaries[0],row=f.helper.acceptedBoundary(f.owner,boundary),state=f.helper.stateFor(f.owner,first.p);
 row.fact.objectId=0;row.complete=false;state.presence='destroyed';
 assert.equal(f.helper.acceptedBoundary(f.owner,boundary).fact.objectId,ID);assert.equal(f.helper.stateFor(f.owner,first.p).presence,'live');
 assert.equal(f.helper.acceptedBoundary(f.owner,{...row}),null);assert.equal(f.helper.acceptedBoundary({},boundary),null);assert.equal(f.helper.stateFor({},first.p),null);
 assert.equal(f.helper.stateFor(f.owner,{...first.p}),null);
 first.p.id=OTHER;assert.equal(f.helper.stateFor(f.owner,first.p),null);
 const tx={};f.helper.begin(tx,{complete:true,recordCount:1});assert.throws(()=>f.helper.observe(tx,A(OTHER),0,context({...first.p},first.p,'live')),/canonical proxy alias/);f.helper.abort(tx);
});

test('connection binding is explicit, does not reconstruct owner, and cannot alias another epoch',()=>{
 const f=setup({connection:null}),first=fresh(f),before=first.rows[0];
 assert.equal(before.connection,null);assert.match(before.fact.physicalToken,/:unbound:1$/);
 f.helper.bindConnection(f.owner,7);assert.equal(f.helper.stateFor(f.owner,first.p).physicalToken,before.fact.physicalToken);
 assert.equal(f.helper.acceptedBoundary(f.owner,first.boundaries[0]).connection,null);
 assert.equal(f.helper.bindConnection(f.owner,7).connection,7);
 assert.throws(()=>f.helper.bindConnection(f.owner,8),/new registry epoch/);assert.equal(f.helper.history(f.owner).complete,false);
 const next=new NativeClientClockLifecycle({owner:f.owner,connection:8,recordHistoryComplete:true,externalRegistryHistoryComplete:true});
 assert.equal(next.acceptedBoundary(f.owner,first.boundaries[0]),null);assert.notEqual(next.history(f.owner).epoch,before.epoch);
});

test('reentrant/concurrent transaction attempts cannot publish stale prepared facts',()=>{
 const f=setup(),one={},two={},p=proxy();f.helper.begin(one,{complete:true,recordCount:1});f.helper.observe(one,A(),0,context(p));
 assert.throws(()=>f.helper.begin(two,{complete:true,recordCount:0}),/transaction begin/);
 assert.throws(()=>f.helper.commit(one,()=>p),/incomplete or stale/);f.helper.abort(one);
 const g=setup(),tx={},q=proxy();g.helper.begin(tx,{complete:true,recordCount:1});g.helper.observe(tx,A(),0,context(q));
 assert.throws(()=>g.helper.commit(tx,()=>{g.helper.abort(tx);return q;}),/Reentrant commit changed owner/);
 assert.equal(g.helper.stateFor(g.owner,q),null);
});
