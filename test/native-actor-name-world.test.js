import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkWorld} from '../src/network_world.js';
import combatModule from '../godot-client/tools/raw-combat-events.cjs';
import scopeModule from '../godot-client/tools/native-text-event-scope.cjs';
const {RawCombatEvents}=combatModule,{NativeTextEventScope}=scopeModule;
const ID=0x80000042,OTHER=ID+1;
const create=(id=ID)=>({action:'create',objectType:5,id,state:{}});
const appearance=(name,id=ID)=>({action:'appearance',objectType:5,id,mask:0x400,state:{name}});
const remove=(id=ID)=>({action:'delete',objectType:5,id,remove:1});
const update=(name,id=ID)=>({action:'update',objectType:5,id,state:{name}});
const world=()=>new NetworkWorld({onDiagnostic:()=>{}});
const apply=(w,records,complete=true)=>w.apply({kind:'object-updates',records,complete});
const state=(w,id=ID)=>w.nativeActorNameFor(w.registry.get(id));

test('accepted complete A creates private name provenance; P owns actor names and U does not',()=>{
 const w=world();apply(w,[create(),appearance({text:'Actor'})]);
 const before=state(w);assert.equal(before.construction.kind,'new');assert.deepEqual(before.override,{known:true,text:''});
 assert.equal(before.publication.first.text,'Actor');assert.equal(before.publication.last.text,'');
 apply(w,[update({firstName:{text:'Party'},lastName:{text:'Label'}})]);
 assert.deepEqual(state(w),before);assert.equal(w.registry.get(ID).replicated.name.firstName.text,'Party');
 assert.deepEqual(w.nativeActorNameHistory(),{version:1,complete:true});
});
test('P-before-A and generic/imported owners cannot invent a stats constructor',()=>{
 for(const prefix of [[appearance({text:'Premature'})],[update({text:'Party'})],[{action:'inventory-stats',objectType:5,id:ID,state:{}}]]){
  const w=world();apply(w,[...prefix,create()]);assert.equal(state(w).construction.kind,'unknown');assert.equal(state(w).override.known,false);
 }
 const original=world();apply(original,[create(),appearance({text:'Original'})]);
 const imported=world(),forged={id:ID,objectType:5,replicated:{},nativeActorNameState:state(original)};
 assert.equal(imported.registry.addObjectAtPos(ID,forged).status,0);apply(imported,[create()]);
 assert.equal(state(imported).construction.kind,'unknown');assert.equal(state(imported).override.known,false);
});
test('repeated A preserves the name publication, ambiguous D+A retains bytes without asserting reuse',()=>{
 const w=world();apply(w,[create(),appearance({firstName:{text:'First'},lastName:{text:'Last'}})]);const before=state(w);
 apply(w,[create()]);assert.deepEqual(state(w),before);
 apply(w,[remove(),create()]);const revived=state(w);
 assert.deepEqual(revived.construction,before.construction);assert.deepEqual(revived.override,before.override);
 assert.equal(revived.publication.current,false);assert.equal(revived.publication.first.text,'First');assert.equal(revived.publication.last.text,'Last');
 apply(w,[appearance({text:'Republished'})]);assert.equal(state(w).publication.current,true);assert.equal(state(w).publication.first.text,'Republished');
});
test('failed later record rolls back metadata and sequence while tainting future certainty',()=>{
 const w=world();apply(w,[create(),appearance({text:'Before'})]);const before=state(w),sequence=w.nativeActorNameSequence();
 assert.throws(()=>apply(w,[appearance({text:'Must roll back'}),{action:'create',objectType:6,id:ID,state:{}}]),/Conflicting/);
 assert.deepEqual(state(w),before);assert.equal(w.nativeActorNameSequence(),sequence);assert.equal(w.nativeActorNameHistory().complete,false);
 apply(w,[create(OTHER)]);assert.equal(state(w,OTHER).construction.kind,'unknown');
});
test('incomplete decoded prefix and untracked calls cannot re-certify future constructors',()=>{
 for(const untrusted of [w=>apply(w,[create()],false),w=>w.applyObjectUpdates([create()])]){
  const w=world();untrusted(w);assert.equal(w.nativeActorNameHistory().complete,false);
  apply(w,[create(OTHER)]);assert.equal(state(w,OTHER).construction.kind,'unknown');assert.equal(w.nativeActorNameHistory().complete,false);
 }
});
test('reset scopes private ownership to the new canonical registry even when numeric IDs recur',()=>{
 const w=world();apply(w,[create(),appearance({text:'Old'})]);const old=w.registry.get(ID),view=state(w);
 w.reset();assert.equal(w.nativeActorNameFor(old),null);assert.equal(w.nativeActorNameSequence(),0);
 apply(w,[create(),appearance({text:'New'})]);assert.equal(state(w).construction.kind,'new');assert.equal(state(w).publication.first.text,'New');
 assert.equal(w.nativeActorNameFor(old),null);assert.equal(view.publication.first.text,'Old');
});
test('detached views and injected row properties cannot mutate or impersonate private ownership',()=>{
 const w=world();apply(w,[create(),appearance({text:'Stored'})]);const original=state(w),view=state(w),row=w.registry.get(ID);
 view.override.text='Injected';view.publication.first.text='Mutated';row.nativeActorNameState={...view,construction:{kind:'new',sequence:999}};
 assert.deepEqual(state(w),original);assert.equal(w.nativeActorNameFor({...row}),null);
 const clone=structuredClone(row);w.registry.delete(ID);assert.equal(w.registry.addObjectAtPos(ID,clone).status,0);
 assert.equal(state(w),null);apply(w,[create()]);assert.equal(state(w).construction.kind,'unknown');
});
test('raw transport borrows a stable immutable view instead of cloning unchanged names every frame',()=>{
 const w=world();apply(w,[create(),appearance({text:'Stable'})]);const row=w.registry.get(ID),view=w.nativeActorNameTransport(row);
 assert.equal(w.nativeActorNameTransport(row),view);assert.ok(Object.isFrozen(view));assert.ok(Object.isFrozen(view.publication.first));
 assert.throws(()=>{view.publication.first.text='Mutation';},TypeError);assert.equal(state(w).publication.first.text,'Stable');
 const detached=w.nativeActorNameFor(row);detached.publication.first.text='Local copy';assert.equal(state(w).publication.first.text,'Stable');
 assert.deepEqual(JSON.parse(JSON.stringify(view)),state(w));
});
test('P captures selected overrides and native CUSTOM bytes before later updates',()=>{
 const w=world();w.apply({kind:'custom-token',id:12,text:'Receipt'});w.apply({kind:'tlk-overrides',entries:[{strRef:10,text:'<CUSTOM12>'}]});
 const name={firstName:{strRef:10,gender:1},lastName:{text:''}};apply(w,[create(),appearance(name)]);const before=state(w);
 assert.deepEqual(before.publication.first.override,{known:true,present:true,text:'<CUSTOM12>'});
 assert.deepEqual(before.publication.environment.customTokens.records,[{id:12,bytes:[82,101,99,101,105,112,116]}]);
 name.firstName.strRef=11;w.apply({kind:'custom-token',id:12,text:'Later'});w.apply({kind:'tlk-overrides',entries:[{strRef:10,text:'Changed'}]});
 assert.deepEqual(state(w),before);
 apply(w,[appearance({firstName:{strRef:10,gender:1},lastName:{text:''}})]);assert.ok(state(w).publication.revision>before.publication.revision);
 assert.equal(state(w).publication.first.override.text,'Changed');
});
test('actual text-event boundary freezes opaque actor facts before raw snapshots can coalesce newer names',()=>{
 const w=world();w.areaId=0x80000001;apply(w,[create(),appearance({text:'At receipt'})]);
 const scope=new NativeTextEventScope(new RawCombatEvents()),message={kind:'server-speech',channel:1,objectId:ID,text:{text:'Hello'}};
 const captured=scope.capture(w,message,7,3);
 assert.equal(captured.actorName.version,1);assert.equal(captured.actorName.historyComplete,true);
 assert.equal(captured.actorName.state.publication.first.text,'At receipt');assert.equal(captured.source.id,ID);
 apply(w,[appearance({text:'New snapshot'})]);assert.equal(captured.actorName.state.publication.first.text,'At receipt');
 captured.actorName.state.override.text='Changed detached event';assert.equal(state(w).override.text,'');
 apply(w,[],false);assert.equal(scope.capture(w,message,7,3).actorName.historyComplete,false);
 assert.equal(captured.actorName.historyComplete,true);
});
