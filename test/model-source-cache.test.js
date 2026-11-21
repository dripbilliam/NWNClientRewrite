import test from 'node:test';
import assert from 'node:assert/strict';
import {ModelSourceCache} from '../src/model_source_cache.js';
const model=(name,parent='null')=>({modelName:name,supermodel:parent,animationScale:1,animations:[],unsupportedAnimations:[]});
test('concurrent actor sources share parent IO/parse/inheritance once and retain independent instances elsewhere',async()=>{
 const read=[],cache=new ModelSourceCache({getResource:async name=>{read.push(name);return model(name,name==='parent'?'null':'parent');}},{parse:m=>m});const [a,b,c]=await Promise.all([cache.load('a'),cache.load('b'),cache.load('A')]);assert.equal(a,c);assert.notEqual(a,b);assert.deepEqual(read.sort(),['a','b','parent']);assert.equal(cache.stats.parsed,3);cache.dispose();await assert.rejects(cache.load('a'),/closed/);
});
test('separate server contexts cannot share equal resource names and cycles fail instead of deadlocking',async()=>{
 const a=new ModelSourceCache({getResource:async()=>({...model('same'),server:'A'})},{parse:m=>m}),b=new ModelSourceCache({getResource:async()=>({...model('same'),server:'B'})},{parse:m=>m});assert.equal((await a.load('same')).server,'A');assert.equal((await b.load('same')).server,'B');
 const cycle=new ModelSourceCache({getResource:async name=>model(name,name==='a'?'b':'a')},{parse:m=>m});await assert.rejects(cycle.load('a'),/cycle/);
});
test('parallel roots with a cyclic supermodel graph reject instead of waiting on each other',async()=>{
 const cache=new ModelSourceCache({getResource:async name=>model(name,name==='a'?'b':'a')},{parse:m=>m});let timer;
 try{const results=await Promise.race([Promise.allSettled([cache.load('a'),cache.load('b')]),new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Parallel inheritance deadlocked')),250))]);assert.ok(results.every(r=>r.status==='rejected'&&/cycle/.test(r.reason.message)));}
 finally{clearTimeout(timer);cache.dispose();}
});
test('late source IO after disposal cannot parse or repopulate the dependency graph',async()=>{
 let release,parsed=0;const cache=new ModelSourceCache({getResource:()=>new Promise(r=>release=r)},{parse:m=>{parsed++;return m;}}),pending=cache.load('late');cache.dispose();release(model('late'));await assert.rejects(pending,/closed/);assert.equal(parsed,0);assert.equal(cache.models.size,0);assert.equal(cache.parents.size,0);
});

test('prepared base models resolve current supermodels in each resource context and never cache inherited animations',async()=>{
 const saved={...model('child','parent'),prepared:true},load=()=>structuredClone(saved);let reads=0;
 const make=clip=>new ModelSourceCache({getModelSource:async name=>{reads++;return name==='child'?load():{...model('parent'),animations:[{name:clip,tracks:[]}]};}},{persistent:true,parse:()=>{throw Error('Local parse must be bypassed');}});
 const a=make('server-a'),b=make('server-b');assert.equal((await a.load('child')).animations[0].name,'server-a');assert.equal((await b.load('child')).animations[0].name,'server-b');assert.equal(saved.animations.length,0);assert.equal(saved.animationsInherited,undefined);assert.equal(reads,4);assert.equal(a.stats.persistent,2);a.dispose();b.dispose();
});

test('an unavailable preparation service falls back to decoding without hiding a missing resource or reading after close',async()=>{
 let reads=0;const cache=new ModelSourceCache({getModelSource:async()=>{throw Error('Worker unavailable');},getResource:async()=>{reads++;return model('source');}},{persistent:true,parse:value=>value});assert.equal((await cache.load('source')).modelName,'source');assert.equal(cache.stats.persistentFallbacks,1);assert.equal(cache.stats.parsed,1);assert.equal(reads,1);cache.dispose();
 const missing=new ModelSourceCache({getModelSource:async()=>{throw Object.assign(Error('Missing'),{code:'RESOURCE_NOT_FOUND'});},getResource:async()=>{throw Error('Unexpected fallback');}},{persistent:true});await assert.rejects(missing.load('absent'),{code:'RESOURCE_NOT_FOUND'});assert.equal(missing.stats.persistentFallbacks,0);missing.dispose();
});

test('retiring an area stops waiting for its shared preparation service immediately',async()=>{
 let finish;const cache=new ModelSourceCache({getModelSource:()=>new Promise(resolve=>finish=resolve),getResource:()=>{throw Error('No stale fallback');}},{persistent:true});const pending=cache.load('old');cache.dispose();await assert.rejects(pending,/closed/);finish(model('old'));await new Promise(resolve=>setImmediate(resolve));assert.equal(cache.models.size,0);assert.equal(cache.stats.persistent,0);
});

test('multipart palettes decode once per active resource context without sharing mutable output textures',async()=>{
 let loads=0,release;const images=new Map([['skin',{data:Uint8Array.of(1,2,3,4)}]]),a=new ModelSourceCache({}),b=new ModelSourceCache({}),load=()=>{loads++;return new Promise(r=>release=r);};
 const first=a.paletteImages(load),second=a.paletteImages(load);await Promise.resolve();assert.equal(loads,1);release(images);assert.equal(await first,await second);
 assert.notEqual(await b.paletteImages(async()=>new Map()),images);a.dispose();await assert.rejects(a.paletteImages(load),/closed/);
 const pending=new ModelSourceCache({});let done;const work=pending.paletteImages(()=>new Promise(r=>done=r));await Promise.resolve();pending.dispose();done(images);await assert.rejects(work,/closed/);
});
