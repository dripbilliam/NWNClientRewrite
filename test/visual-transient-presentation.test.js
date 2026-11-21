import test from 'node:test';
import assert from 'node:assert/strict';
import {LoopingVisualPresentation} from '../src/looping_visual_presentation.js';

function fixture(create){
 const actor={id:123,areaId:7,nativeLoopingVisuals160:{records:[]}},record={visualId:1,delivery:{instant:1}},render={};let live=actor,binding=render;
 const calls=[],diagnostics=[],instance={retired:false,attach:()=>calls.push('attach'),update:()=>calls.push('update'),isRetired:()=>instance.retired,stop:()=>calls.push('stop'),dispose:()=>calls.push('dispose')};
 const p=new LoopingVisualPresentation({areaId:7,objects:()=>live?[live]:[],object:()=>live,render:()=>binding,tables:async()=>({}),createNative:create??(async()=>instance),report:(code,message,data)=>diagnostics.push({code,message,data})});
 return{p,actor,record,instance,calls,diagnostics,destroy:()=>live=null,rebind:()=>binding={}};
}
async function add(f){assert.equal(f.p.addTransient(f.actor,f.record),1);await Promise.all([...f.p.entries.values()].map(e=>e.ready));}

test('duplicate one-shot messages have separate presentation identities and retire individually without canonical removal',async()=>{
 const f=fixture(),second={...f.instance,retired:false,isRetired:()=>second.retired};let count=0;f.p.createNative=async()=>count++?second:f.instance;
 await add(f);await add(f);assert.equal(f.p.entries.size,2);assert.equal(f.actor.nativeLoopingVisuals160.records.length,0);
 f.instance.retired=true;f.p.update(.1);assert.equal(f.p.entries.size,1);assert.equal(f.calls.filter(c=>c==='dispose').length,1);assert.equal(f.calls.includes('stop'),false);
 f.p.dispose();assert.equal(f.calls.filter(c=>c==='dispose').length,2);
});

test('late one-shot loads cannot attach after object destruction, area transfer, rebinding or presenter disposal',async()=>{
 for(const reason of ['destroy','area','rebind','dispose']){
  let resolve;const f=fixture(()=>new Promise(r=>resolve=r));f.p.addTransient(f.actor,f.record);const pending=[...f.p.entries.values()][0].ready;await Promise.resolve();
  if(reason==='destroy')f.destroy();if(reason==='area')f.actor.areaId=8;if(reason==='rebind')f.rebind();if(reason==='dispose')f.p.dispose();else f.p.update(0);
  resolve(f.instance);await pending;assert.deepEqual(f.calls,['dispose'],reason);assert.equal(f.p.entries.size,0,reason);assert.equal(f.p.retiring.size,0,reason);assert.deepEqual(f.diagnostics,[],reason);f.p.dispose();
 }
});

test('one-shot create, attach, update and retirement failures are diagnosed once and leave no dormant presentation entries',async()=>{
 for(const reason of ['create','attach','update','isRetired']){
  const f=fixture();const fail=()=>{throw new Error(`Failure ${reason}`);};if(reason==='create')f.p.createNative=fail;else f.instance[reason]=fail;
  await add(f);if(reason==='update'||reason==='isRetired')f.p.update(.1);
  assert.equal(f.p.entries.size,0,reason);assert.equal(f.p.retiring.size,0,reason);assert.equal(f.diagnostics.length,1,reason);f.p.update(.1);assert.equal(f.diagnostics.length,1,reason);f.p.dispose();
  assert.equal(f.calls.filter(c=>c==='dispose').length,reason==='create'?0:1,reason);
 }
});
