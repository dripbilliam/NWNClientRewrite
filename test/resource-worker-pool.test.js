import test from 'node:test';
import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';
import {ResourceWorkerPool,resourceWorkerCount} from '../src/resource_worker_pool.js';
import {executeResourceTask,resourceTaskReply} from '../src/resource_worker_tasks.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {NetworkScene} from '../src/network_scene.js';
import {NetworkWorld} from '../src/network_world.js';
import {parse2da} from '../src/area.js';

const model=new TextEncoder().encode(`# authored worker test
newmodel worker_fixture
setsupermodel worker_fixture NULL
beginmodelgeom worker_fixture
node dummy root
 parent NULL
 position 1 2 3
endnode
endmodelgeom worker_fixture
donemodel worker_fixture
`).buffer;
const tga=()=>{const bytes=new Uint8Array(21);bytes[2]=2;bytes[12]=bytes[14]=1;bytes[16]=24;bytes.set([30,20,10],18);return bytes.buffer;};
const createWorker=()=>{
 const worker=new Worker(new URL('../scripts/resource-worker-thread-fixture.mjs',import.meta.url));
 return{postMessage:(...args)=>worker.postMessage(...args),terminate:()=>worker.terminate(),addEventListener(kind,fn){worker.on(kind,value=>fn(kind==='message'?{data:value}:{message:value.message,preventDefault(){}}));}};
};

test('real worker threads preserve parser graphs, pixel bytes and source-buffer ownership',async()=>{
 const pool=new ResourceWorkerPool({size:2,createWorker});
 try{
  const input=tga(),expected=executeResourceTask('tga',{buffer:input}),jobs=Array.from({length:12},(_,i)=>pool.decode(i%2?'model':'tga',i%2?model:input));
  const results=await Promise.all(jobs);for(let i=0;i<results.length;i++)assert.deepEqual(results[i],i%2?executeResourceTask('model',{buffer:model}):expected);
  assert.equal(input.byteLength,21);assert.equal(model.byteLength>0,true);assert.equal(results[1].byName.get('root'),results[1].nodes[0]);
  assert.equal(pool.snapshot().workers,2);assert.equal(pool.snapshot().completed,12);assert.equal(pool.snapshot().pending,0);assert.ok(pool.snapshot().maxQueued>=8);
  await assert.rejects(pool.decode('model',new ArrayBuffer(1)));assert.equal(pool.snapshot().failed,1);
  assert.deepEqual(await pool.decode('tga',input),expected);
 }finally{pool.dispose();}
});

function pltFixture(seed=0){const bytes=new Uint8Array(24+32*2),view=new DataView(bytes.buffer);bytes.set(new TextEncoder().encode('PLT V1  '));view.setUint32(8,1,true);view.setUint32(16,8,true);view.setUint32(20,4,true);for(let i=0;i<32;i++)bytes[24+i*2]=i*7;const data=Uint8Array.from({length:256*4*4},(_,i)=>i%4===3?255:(i*13+seed)%256);return{input:bytes.buffer,images:new Map([['pal_skin01',{width:256,height:4,data}]])};}
test('resident PLT palettes clone once per real worker and preserve every palette row and source buffer',async()=>{
 const packets=[],pool=new ResourceWorkerPool({size:2,createWorker:()=>{const worker=createWorker(),post=worker.postMessage;worker.postMessage=(message,...args)=>{packets.push(message);return post(message,...args);};return worker;}}),f=pltFixture(3),source=f.images.get('pal_skin01').data.slice();
 try{
  const jobs=Array.from({length:30},(_,i)=>pool.decodePlt(f.input,f.images,[i%4])),results=await Promise.all(jobs);
  for(let i=0;i<results.length;i++)assert.deepEqual(results[i],executeResourceTask('plt',{buffer:f.input,palettes:f.images,rows:[i%4]}));
  assert.equal(packets.filter(p=>p.payload.paletteImages).length,2);assert.ok(packets.every(p=>!p.payload.palettes&&!p.payload.paletteContext));assert.equal(pool.snapshot().paletteReuses,28);assert.equal(pool.snapshot().paletteBytes,source.byteLength*2);assert.equal(f.input.byteLength,88);assert.deepEqual(f.images.get('pal_skin01').data,source);
  // Explicit resident sources are immutable snapshots. Later mutable callers
  // can use the existing generic decode path or provide another context Map.
  f.images.get('pal_skin01').data.fill(0);const retained=await pool.decodePlt(f.input,f.images,[2]);assert.deepEqual(retained,results[2]);const other=pltFixture(9);assert.deepEqual(await pool.decodePlt(other.input,other.images,[1]),executeResourceTask('plt',{buffer:other.input,palettes:other.images,rows:[1]}));assert.deepEqual(await pool.decodePlt(f.input,f.images,[0]),results[0]);
 }finally{pool.dispose();}assert.equal(pool.snapshot().workers,0);await assert.rejects(pool.decodePlt(f.input,f.images,[]),/closed/);
});
test('worker replacement resends resident palettes and oversized sets keep the ordinary task path',async()=>{
 const slots=[],pool=new ResourceWorkerPool({size:1,createWorker:()=>{const listeners={},slot={addEventListener:(kind,fn)=>listeners[kind]=fn,postMessage:message=>slot.message=message,terminate(){},listeners};slots.push(slot);return slot;}}),f=pltFixture();
 const first=pool.decodePlt(f.input,f.images,[0]),rejected=assert.rejects(first,/crashed/);slots[0].listeners.error({message:'crashed',preventDefault(){}});await rejected;const next=pool.decodePlt(f.input,f.images,[0]);assert.ok(slots[1].message.payload.paletteImages);slots[1].listeners.message({data:{id:slots[1].message.id,result:'ok'}});assert.equal(await next,'ok');
 const oversized=new Map([['pal_skin01',{width:256,height:9000,data:new Uint8Array(256*9000*4)}]]),fallback=pool.decodePlt(f.input,oversized,[]);assert.equal(slots[1].message.payload.palettes,oversized);assert.equal(slots[1].message.payload.paletteId,undefined);slots[1].listeners.message({data:{id:slots[1].message.id,result:'fallback'}});assert.equal(await fallback,'fallback');assert.equal(pool.snapshot().paletteFallbacks,1);pool.dispose();
});
test('worker palette contexts reject missing or stale IDs without borrowing another context',()=>{
 const context={},f=pltFixture(),message={id:1,kind:'plt',payload:{buffer:f.input,paletteId:1,rows:[0]}};assert.match(resourceTaskReply(message,context).message.error.message,/stale/);const populated={...message,payload:{...message.payload,paletteImages:f.images}};assert.deepEqual(resourceTaskReply(populated,context).message.result,executeResourceTask('plt',{buffer:f.input,palettes:f.images,rows:[0]}));assert.match(resourceTaskReply({...message,payload:{...message.payload,paletteId:2}},context).message.error.message,/stale/);assert.match(resourceTaskReply(message).message.error.message,/unavailable/);
});
test('equal palette IDs in separate area pools cannot share pixels and retirement drops resident sources',async()=>{
 const a=new ResourceWorkerPool({size:1,createWorker}),b=new ResourceWorkerPool({size:1,createWorker}),one=pltFixture(1),two=pltFixture(7);
 try{const [x,y]=await Promise.all([a.decodePlt(one.input,one.images,[0]),b.decodePlt(two.input,two.images,[0])]);assert.notDeepEqual(x.data,y.data);a.dispose();assert.equal(a.paletteContexts.get(one.images),undefined);assert.equal(a.snapshot().workers,0);assert.deepEqual(await b.decodePlt(two.input,two.images,[0]),y);assert.equal(b.snapshot().paletteReuses,1);}finally{a.dispose();b.dispose();}
});

test('area retirement cancels queued and in-flight work and ignores late results',async()=>{
 const slots=[],create=()=>{const listeners={};const worker={addEventListener:(kind,fn)=>listeners[kind]=fn,postMessage:message=>worker.message=message,terminate:()=>worker.terminated=true,listeners};slots.push(worker);return worker;};
 const pool=new ResourceWorkerPool({size:2,createWorker:create}),jobs=Array.from({length:6},()=>pool.decode('model',model)),settled=Promise.allSettled(jobs);pool.dispose();
 for(const slot of slots){assert.equal(slot.terminated,true);slot.listeners.message({data:{id:slot.message.id,result:{wrong:true}}});}
 assert.ok((await settled).every(r=>r.status==='rejected'&&/closed/.test(r.reason.message)));assert.equal(pool.snapshot().cancelled,6);assert.equal(pool.snapshot().completed,0);await assert.rejects(pool.decode('model',model),/closed/);
});

test('rule tables retain row labels, physical row order, defaults, aliases and null-prototype dictionaries',async()=>{
 const pool=new ResourceWorkerPool({size:2,createWorker}),text='2DA V2.0\nDEFAULT: missing\n\nName Value\n9 "quoted name" 2\n4 fallback\n9 replaced 3\n',bytes=new TextEncoder().encode(text),reads=[];
 const cache=new ModelSourceCache({getResource:async(name,type)=>{reads.push([name,type]);return bytes;}},{parseTable:bytes=>pool.decode('2da',bytes)});
 try{const [first,second]=await Promise.all([cache.table('RULES'),cache.table('rules')]);assert.equal(first,second);assert.deepEqual(first,parse2da(text));assert.equal(first.rows.get(9),first.orderedRows[2]);assert.equal(reads.length,1);assert.equal(cache.stats.tableHits,1);}
 finally{cache.dispose();pool.dispose();}
 await assert.rejects(cache.table('rules'),/closed/);
});

test('crashed workers reject their task and remaining jobs use a replacement worker',async()=>{
 const slots=[],pool=new ResourceWorkerPool({size:1,createWorker:()=>{const listeners={},slot={addEventListener:(kind,fn)=>listeners[kind]=fn,postMessage:message=>slot.message=message,terminate(){},listeners};slots.push(slot);return slot;}});
 const first=pool.decode('model',model),second=pool.decode('model',model);const rejected=assert.rejects(first,/crashed/);slots[0].listeners.error({message:'crashed',preventDefault(){}});await rejected;
 assert.equal(slots.length,2);slots[1].listeners.message({data:{id:slots[1].message.id,result:'next'}});assert.equal(await second,'next');pool.dispose();
});

test('scene teardown cancels decoding before awaiting scene sync and asset release',async()=>{
 let terminated=false,released=false;const pool=new ResourceWorkerPool({size:1,createWorker:()=>({addEventListener(){},postMessage(){},terminate(){terminated=true;}})});
 const scene=new NetworkScene({world:new NetworkWorld(),resolver:{},loadAsset:()=>pool.decode('model',model),instantiate(){throw Error('Retired model must not instantiate');},releaseAsset(){throw Error('Cancelled asset must not release');},report(){},cancelResources:()=>pool.dispose(),releaseSources:()=>released=true});
 scene.syncWork=scene.asset('test');scene.syncWork.catch(()=>{});await Promise.resolve();await Promise.resolve();assert.equal(pool.snapshot().pending,1);await scene.dispose();assert.equal(terminated,true);assert.equal(released,true);assert.equal(scene.assets.size,0);
});

test('late asynchronous parser cannot repopulate a retired cache or share another server context',async()=>{
 let complete;const cache=new ModelSourceCache({getResource:async()=>model},{parse:()=>new Promise(resolve=>complete=resolve)}),pending=cache.load('same');while(!complete)await Promise.resolve();cache.dispose();complete({modelName:'same',supermodel:'null'});await assert.rejects(pending,/closed/);assert.equal(cache.parents.size,0);
 assert.deepEqual([1,2,4,8,64].map(resourceWorkerCount),[1,1,2,4,4]);
});
