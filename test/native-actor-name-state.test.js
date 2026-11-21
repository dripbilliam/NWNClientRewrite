import test from 'node:test';
import assert from 'node:assert/strict';
import {NATIVE_ACTOR_NAME_SLOT,NATIVE_ACTOR_NAME_SOURCE,stageNativeActorName as stage,validNativeActorNameState as valid} from '../src/network_actor_name_state.js';

const id=0x80000009;
const create={action:'create',objectType:5,id,state:{}};
const del={action:'delete',objectType:5,id,remove:0};
const p=name=>({action:'appearance',objectType:5,id,mask:0x400,state:{name}});
const fresh=(sequence=1)=>({sequence,typedOwner:'absent',historyComplete:true});
const present=sequence=>({sequence,typedOwner:'present',historyComplete:true});
const unknown=sequence=>({sequence,typedOwner:'unknown',historyComplete:false});
const env=(overrides=new Map(),records=[])=>({overrides,customTokens:{records}});
const ref=(strRef,gender=0)=>({strRef,gender});

test('fresh A uses explicit complete/typed absence, not IDs or snapshots',()=>{
 const out=stage(null,create,fresh());
 assert.equal(NATIVE_ACTOR_NAME_SLOT,'nativeActorNameState');assert.equal(out.source,NATIVE_ACTOR_NAME_SOURCE);
 assert.deepEqual(out.construction,{kind:'new',source:'A/type5',sequence:1});
 assert.deepEqual(out.override,{known:true,text:''});assert.equal(out.publication,null);assert.equal(out.presence,'present');assert.equal(valid(out),true);
 assert.equal(Object.hasOwn(out,'first'),false);assert.equal(Object.hasOwn(out,'nativeLifetime'),false);
});
test('incomplete history and unknown/present preexisting owners never obtain ctor defaults',()=>{
 for(const boundary of [{sequence:1,typedOwner:'absent',historyComplete:false},unknown(1),present(1)]){
  const out=stage(null,create,boundary);assert.equal(out.override.known,false);assert.equal(out.publication,null);assert.notEqual(out.construction.kind,'new');
 }
 assert.throws(()=>stage(null,create,{sequence:1,typedOwner:'absent'}),/construction boundary/);
});
test('generic U/I/P allocation alone cannot create stored-name provenance',()=>{
 for(const action of ['update','player-state','inventory-stats','inventory'])assert.equal(stage(null,{action,objectType:5,id,state:{name:{text:'Party label'}}}),null);
 assert.equal(stage(null,p({text:'Before full owner'}),unknown(2)),null);
 assert.equal(stage(null,p({text:'No owner'}),{sequence:2,typedOwner:'absent'}),null);
});
test('literal P writes first literal and known empty last without trimming',()=>{
 const before=stage(null,create,fresh());const out=stage(before,p({text:'  Native  '}),present(2));
 assert.equal(before.publication,null);assert.deepEqual(out.publication.first,{kind:'literal',text:'  Native  '});
 assert.deepEqual(out.publication.last,{kind:'literal',text:''});assert.equal(out.publication.current,true);
 assert.deepEqual(out.publication.environment,{customTokens:{known:false},parserState:{}});assert.equal(valid(out),true);
});
test('literal empty P is real empty first/last and never an Unknown name',()=>{
 const out=stage(stage(null,create,fresh()),p({text:''}),present(2));
 assert.equal(out.publication.first.text,'');assert.equal(out.publication.last.text,'');assert.deepEqual(out.override,{known:true,text:''});
});
test('literal P neither snapshots CUSTOM nor reads a token environment',()=>{
 const environment={};Object.defineProperty(environment,'customTokens',{get(){throw Error('CUSTOM copied for literal');}});Object.defineProperty(environment,'parserState',{get(){throw Error('parser copied for literal');}});
 const out=stage(stage(null,create,fresh()),p({text:'Literal'}),present(2),environment);assert.equal(out.publication.first.text,'Literal');
 assert.equal(stage(out,p({text:'Literal'}),present(3),environment),out);
});
test('P on explicitly present preexisting owner retains unknown ctor/override',()=>{
 const out=stage(null,p({firstName:{text:'First'},lastName:{text:'Last'}}),present(3),env());
 assert.deepEqual(out.construction,{kind:'unknown',source:'preexisting',sequence:3});assert.deepEqual(out.override,{known:false});
 assert.equal(out.publication.first.text,'First');assert.equal(valid(out),true);
});
test('localized descriptors retain wire genders, full refs and selected override results',()=>{
 const overrides=new Map([[0x01000005,'<CUSTOM12>'],[77,'Unrelated']]);const tokens={id:12,bytes:Uint8Array.of(65,0,66)};
 const environment=env(overrides,[tokens]);const name={firstName:ref(0x01000005,1),lastName:ref(3,0)};
 const copy=structuredClone(name);const out=stage(stage(null,create,fresh()),p(name),present(2),environment);
 assert.deepEqual(out.publication.first,{kind:'reference',strRef:0x01000005,gender:1,override:{known:true,present:true,text:'<CUSTOM12>'}});
 assert.deepEqual(out.publication.last,{kind:'reference',strRef:3,gender:0,override:{known:true,present:false}});
 assert.deepEqual(out.publication.environment.customTokens,{known:true,records:[{id:12,bytes:[65,0,66]}]});
 assert.deepEqual(name,copy);assert.equal(valid(out),true);
 overrides.set(0x01000005,'Later');tokens.bytes[0]=90;assert.equal(out.publication.first.override.text,'<CUSTOM12>');assert.equal(out.publication.environment.customTokens.records[0].bytes[0],65);
});
test('only selected direct override keys are read, never the whole override map',()=>{
 class SelectedMap extends Map{[Symbol.iterator](){throw Error('map iteration');}entries(){throw Error('map entries');}values(){throw Error('map values');}}
 const out=stage(stage(null,create,fresh()),p({firstName:ref(1),lastName:ref(2)}),present(2),env(new SelectedMap([[1,'One'],[99,'Unused']])));
 assert.equal(out.publication.first.override.text,'One');assert.equal(out.publication.last.override.present,false);
});
test('invalid-reference guard precedes an override entry and needs no token snapshot',()=>{
 const environment={overrides:new Map([[0xffffffff,'Must not be used']])};Object.defineProperty(environment,'customTokens',{get(){throw Error('invalid ref captured CUSTOM');}});
 const out=stage(stage(null,create,fresh()),p({firstName:ref(0xffffffff,1),lastName:{text:''}}),present(2),environment);
 assert.deepEqual(out.publication.first.override,{known:true,present:false});assert.deepEqual(out.publication.environment.customTokens,{known:false});
});
test('unavailable override/CUSTOM/state owners remain explicit unknowns',()=>{
 const out=stage(stage(null,create,fresh()),p({firstName:ref(12,1),lastName:{text:''}}),present(2));
 assert.deepEqual(out.publication.first.override,{known:false});assert.deepEqual(out.publication.environment,{customTokens:{known:false},parserState:{}});
});
test('explicit retained parser state is detached and never supplied by a controlled id',()=>{
 const parserState={gender:1,nativeB8:0,nativeBC:1,context:{id:18,objectType:5,replicated:{name:{firstName:{text:'Before'},lastName:{text:''}},stats:{race:1,classes:[{id:3,level:4}]}}}};
 const out=stage(stage(null,create,fresh()),p({firstName:ref(1),lastName:{text:''}}),present(2),{...env(new Map([[1,'<FirstName>']])),parserState});
 parserState.context.replicated.name.firstName.text='After';parserState.context.replicated.stats.classes[0].level=9;
 assert.equal(out.publication.environment.parserState.context.id,18);assert.equal(out.publication.environment.parserState.context.replicated.name.firstName.text,'Before');
 assert.equal(out.publication.environment.parserState.context.replicated.stats.classes[0].level,4);assert.equal(valid(out),true);
});
test('explicit NULL retained context stays distinct from unknown context',()=>{
 const out=stage(stage(null,create,fresh()),p({firstName:ref(1),lastName:{text:''}}),present(2),{...env(new Map([[1,'Value']])),parserState:{context:null,nativeB8:0}});
 assert.equal(out.publication.environment.parserState.context,null);assert.equal(Object.hasOwn(out.publication.environment.parserState,'nativeBC'),false);
});
test('same received names with changed selected override or CUSTOM make a new publication',()=>{
 const name={firstName:ref(1),lastName:{text:''}},environment=env(new Map([[1,'<CUSTOM12>']]),[{id:12,bytes:[65]}]);
 const a=stage(stage(null,create,fresh()),p(name),present(2),environment);
 assert.equal(stage(a,p(name),present(3),environment),a);
 environment.customTokens.records[0].bytes[0]=66;const b=stage(a,p(name),present(3),environment);
 assert.equal(b.publication.revision,3);assert.equal(a.publication.environment.customTokens.records[0].bytes[0],65);
 environment.overrides.set(1,'Other');const c=stage(b,p(name),present(4),environment);assert.equal(c.publication.first.override.text,'Other');
});
test('base references do not copy CUSTOM whose contents cannot affect parseFlag0',()=>{
 const environment={overrides:new Map()};Object.defineProperty(environment,'customTokens',{get(){throw Error('base fetched CUSTOM');}});
 const out=stage(stage(null,create,fresh()),p({firstName:ref(1),lastName:ref(2,1)}),present(2),environment);
 assert.deepEqual(out.publication.environment.customTokens,{known:false});
});
test('known-present repeated A preserves construction/name/override and costs no environment copy',()=>{
 const a=stage(stage(null,create,fresh()),p({text:'Stored'}),present(2));a.override={known:true,text:'Prior override'};
 const before=structuredClone(a),b=stage(a,create,present(3));assert.equal(b,a);assert.deepEqual(a,before);
});
test('D preserves stored bytes; known true reuse may restore their currentness',()=>{
 const a=stage(stage(null,create,fresh()),p({text:'Stored'}),present(2));const removed=stage(a,del,{sequence:3});
 assert.equal(removed.presence,'removed');assert.equal(removed.publication,a.publication);assert.equal(a.presence,'present');
 const reused=stage(removed,create,present(4));assert.equal(reused.presence,'present');assert.equal(reused.publication.current,true);assert.deepEqual(reused.construction,a.construction);
});
test('ambiguous D+A retains bytes, invalidates old first/last, preserves invariant empty override',()=>{
 const a=stage(stage(null,create,fresh()),p({text:'Stored'}),present(2));const d=stage(a,del,{sequence:3}),b=stage(d,create,unknown(4));
 assert.equal(b.publication.first.text,'Stored');assert.equal(b.publication.current,false);assert.deepEqual(b.override,{known:true,text:''});assert.deepEqual(b.construction,a.construction);
 const c=stage(b,p({text:'Current P'}),present(5));assert.equal(c.publication.current,true);assert.equal(c.publication.first.text,'Current P');assert.equal(valid(c),true);
});
test('ambiguous D+A never clears a known nonempty override but revokes readiness',()=>{
 const a=stage(stage(null,create,fresh()),p({text:'Stored'}),present(2));a.override={known:true,text:'Prior override'};
 const b=stage(stage(a,del,{sequence:3}),create,unknown(4));assert.deepEqual(b.override,{known:false,text:'Prior override'});assert.equal(b.publication.current,false);
 const c=stage(b,p({text:'New first'}),present(5));assert.deepEqual(c.override,b.override);assert.equal(a.override.known,true);
});
test('a claimed later absent boundary cannot reset an existing retained owner',()=>{
 const a=stage(stage(null,create,fresh()),p({text:'Retained'}),present(2));a.override={known:true,text:'Keep'};
 const b=stage(a,create,fresh(3));assert.equal(b.override.text,'Keep');assert.equal(b.override.known,false);assert.deepEqual(b.construction,a.construction);
});
test('party U cannot overwrite an existing actor P publication',()=>{
 const a=stage(stage(null,create,fresh()),p({text:'Actor'}),present(2));
 const out=stage(a,{action:'update',objectType:5,id,mask:0x10000,state:{name:{text:'Party'}}},{},{get customTokens(){throw Error('U read tokens');}});
 assert.equal(out,a);assert.equal(out.publication.first.text,'Actor');
});
test('malformed missing values and sequences fail without mutating input',()=>{
 const a=stage(null,create,fresh()),before=structuredClone(a);
 for(const name of [{firstName:{text:'Missing last'}},{firstName:{strRef:3},lastName:{text:''}},{text:'Raw',strRef:3},{firstName:ref(-1),lastName:{text:''}},{firstName:ref(1,2),lastName:{text:''}}])assert.throws(()=>stage(a,p(name),present(2)),TypeError);
 assert.throws(()=>stage(a,p({text:'X'}),present(1)),/sequence/);assert.throws(()=>stage(null,create,fresh(Number.MAX_SAFE_INTEGER+1)),/sequence/);
 assert.throws(()=>stage(a,{...p({text:'X'}),id:id+1},present(2)),/source identity/);
 assert.throws(()=>stage(a,{...p({text:'X'}),mask:0},present(2)),/name mask/);
 assert.throws(()=>stage(a,p({text:'X'}),{sequence:2,typedOwner:'bogus'}),/boundary/);
 assert.deepEqual(a,before);
});
test('malformed capture owners and accidentally broad parser contexts are rejected',()=>{
 const a=stage(null,create,fresh()),name=p({firstName:ref(1),lastName:{text:''}});
 assert.throws(()=>stage(a,name,present(2),{overrides:{}}),/override owner/);
 assert.throws(()=>stage(a,name,present(2),env(new Map([[1,7]]))),/override text/);
 for(const records of [[{id:12,bytes:[256]}],[{id:12,bytes:[1]},{id:12,bytes:[2]}],[{id:-1,bytes:[]}]])assert.throws(()=>stage(a,name,present(2),env(new Map([[1,'Override']]),records)),TypeError);
 assert.throws(()=>stage(a,name,present(2),{...env(new Map([[1,'Override']])),parserState:{controlledId:9}}),/parser state fields/);
 assert.throws(()=>stage(a,name,present(2),{...env(new Map([[1,'Override']])),parserState:{context:{world:{objects:[]}}}}),/parser context fields/);
});
test('JSON transport roundtrip preserves byte records and validity',()=>{
 const a=stage(stage(null,create,fresh()),p({firstName:ref(1,1),lastName:{text:'Last'}}),present(2),env(new Map([[1,'Override']]),[{id:12,bytes:Uint8Array.of(0,255,128)}]));
 const copy=JSON.parse(JSON.stringify(a));assert.deepEqual(copy,a);assert.equal(valid(copy),true);
 copy.publication.environment.customTokens.records[0].bytes[0]=512;assert.equal(valid(copy),false);assert.equal(valid({...a,revision:0}),false);
});
