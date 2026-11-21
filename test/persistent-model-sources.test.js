import test from 'node:test';import assert from 'node:assert/strict';
import {PersistentModelSources} from '../src/persistent_model_sources.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
const response=(key,bytes=20)=>({key,bytes,model:{format:'ASCII MDL',nodes:[{properties:{},verts:[[1,2,3]]}],animations:[{name:key}],unsupportedAnimations:[]}});
test('validated reuse preserves source identity but inheritance cannot mutate the saved model arrays',async()=>{
 const cache=new PersistentModelSources(),base=response('a'),a=await cache.load('same',async(_name,known)=>{assert.equal(known,null);return base;});a.animations.push({name:'inherited'});a.unsupportedAnimations.push('area-only');a.animationsInherited=true;
 const b=await cache.load('same',async(name,known)=>{assert.equal(name,'same');assert.equal(known,'a');return{key:'a',reused:true};});assert.equal(b.nodes,a.nodes);assert.equal(b.animations.length,1);assert.deepEqual(b.unsupportedAnimations,[]);assert.equal(b.animationsInherited,undefined);assert.equal(Object.getPrototypeOf(b.nodes[0].properties),null);assert.equal(cache.snapshot().hits,1);
 const changed=await cache.load('same',async()=>response('different-server'));assert.notEqual(changed.nodes,b.nodes);assert.equal(changed.animations[0].name,'different-server');
});
test('overlapping contexts never coalesce by name; clear prevents a late request retaining data',async()=>{
 const cache=new PersistentModelSources();let finish;const a=cache.load('same',()=>new Promise(r=>finish=r)),b=await cache.load('same',async()=>response('B'));finish(response('A'));assert.equal((await a).animations[0].name,'A');assert.equal(b.animations[0].name,'B');
 let late;const work=cache.load('late',()=>new Promise(r=>late=r));cache.clear();late(response('old'));await work;assert.equal(cache.snapshot().entries,0);assert.equal(cache.snapshot().bytes,0);
});
test('byte budget evicts least recently used bases; unmatched validation fails without changing ownership',async()=>{
 const cache=new PersistentModelSources({maxBytes:40});await cache.load('a',async()=>response('a'));await cache.load('b',async()=>response('b'));await cache.load('a',async()=>({key:'a',reused:true}));await cache.load('c',async()=>response('c'));assert.equal(cache.entries.has('b'),false);assert.equal(cache.snapshot().bytes,40);assert.equal(cache.snapshot().evicted,1);
 await assert.rejects(cache.load('missing',async()=>({key:'bogus',reused:true})),/matching base/);assert.equal(cache.snapshot().bytes,40);await cache.load('large',async()=>response('big',100));assert.equal(cache.entries.has('large'),false);
});

test('reused child geometry inherits current server clips rather than a previous context parent',async()=>{
 const saved=new PersistentModelSources(),child={format:'ASCII MDL',modelName:'child',supermodel:'parent',nodes:[{properties:{}}],animations:[],unsupportedAnimations:[]};
 const make=clip=>new ModelSourceCache({getModelSource:async(name,known)=>{
  const key=name==='child'?'same-child':clip;
  return known===key?{key,reused:true}:{key,bytes:20,model:name==='child'?structuredClone(child):{...structuredClone(child),modelName:'parent',supermodel:'null',animations:[{name:clip,tracks:[]}]}};
 }},{persistent:true,preparedSources:saved});
 const a=make('A'),first=await a.load('child');a.dispose();const b=make('B'),second=await b.load('child');assert.equal(first.nodes,second.nodes);assert.deepEqual(first.animations.map(a=>a.name),['A']);assert.deepEqual(second.animations.map(a=>a.name),['B']);assert.equal(saved.entries.get('child').model.animations.length,0);b.dispose();
});

test('one mounted context reuses bases directly; another context must validate even equal names',async()=>{
 const cache=new PersistentModelSources();let reads=0;const read=async(_name,key)=>{reads++;return key==='a'?{key:'a',reused:true}:response('a');};
 const a=await cache.load('same',read,{context:'connection-A'}),b=await cache.load('same',()=>{throw Error('Redundant read');},{context:'connection-A'});assert.equal(a.nodes,b.nodes);assert.equal(reads,1);assert.equal(cache.snapshot().contextHits,1);
 const c=await cache.load('same',async()=>{reads++;return response('server-B');},{context:'connection-B'});assert.notEqual(c.nodes,a.nodes);assert.equal(c.animations[0].name,'server-B');assert.equal(reads,2);
 await cache.load('same',read);assert.equal(reads,3,'a caller without a resource-context identity always validates');
});
