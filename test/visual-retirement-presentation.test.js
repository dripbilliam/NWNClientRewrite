import test from 'node:test';
import assert from 'node:assert/strict';
import {parse2da} from '../src/area.js';
import {LoopingVisualPresentation} from '../src/looping_visual_presentation.js';

function fixture(){
 const visuals=parse2da('2DA V2.0\n\nProgFX_Duration\n0 0\n'),programs=parse2da('2DA V2.0\n\nType\n0 4\n');
 const records=[{visualId:0},{visualId:0}],actor={id:123,areaId:7,nativeLoopingVisuals160:{records}},oldRender={};let live=actor,render=oldRender;
 const instances=[],calls=[],diagnostics=[];
 const p=new LoopingVisualPresentation({areaId:7,objects:()=>live?[live]:[],object:()=>live,render:()=>render,tables:async()=>({visuals,programs}),create:async(_actor,_render,record)=>{
  const instance={record,retired:false,attach:()=>calls.push(['attach',record]),stop:value=>calls.push(['stop',record,value]),update:delta=>calls.push(['update',record,delta]),isRetired:()=>instance.retired,dispose:()=>calls.push(['dispose',record])};instances.push(instance);return instance;
 },report:(...args)=>diagnostics.push(args)});
 return{p,actor,records,instances,calls,diagnostics,rebind:()=>render={},destroy:()=>live=null};
}
async function ready(f){f.p.update(0);await Promise.all([...f.p.entries.values()].map(e=>e.ready));f.calls.length=0;}

test('canonical removal starts cessation once, preserves duplicate identity, and waits for the instance native retirement predicate',async()=>{
 const f=fixture();await ready(f);const removed=f.records.pop();f.p.update(.1);
 assert.equal(f.p.entries.size,1);assert.equal(f.p.retiring.size,1);assert.deepEqual(f.calls.filter(c=>c[0]==='stop'),[['stop',removed,1]]);assert.equal(f.calls.some(c=>c[0]==='dispose'),false);
 f.p.update(10);assert.equal(f.p.retiring.size,1);assert.equal(f.calls.filter(c=>c[0]==='stop').length,1);
 f.instances[1].retired=true;f.p.update(.1);assert.equal(f.p.retiring.size,0);assert.deepEqual(f.calls.filter(c=>c[0]==='dispose'),[['dispose',removed]]);
 f.p.dispose();f.p.dispose();assert.equal(f.calls.filter(c=>c[0]==='dispose').length,2);assert.deepEqual(f.diagnostics,[]);
});

test('area transfer, binding replacement, destruction and presenter cleanup immediately release retiring instances',async()=>{
 for(const reason of ['area','rebind','destroy','dispose']){
  const f=fixture();await ready(f);f.records.pop();f.p.update(.1);f.calls.length=0;
  if(reason==='area')f.actor.areaId=8;if(reason==='rebind')f.rebind();if(reason==='destroy')f.destroy();
  if(reason==='dispose')f.p.dispose();else f.p.update(.1);
  assert.equal(f.p.retiring.size,0,reason);assert.equal(f.calls.filter(c=>c[0]==='dispose').length,2,reason);assert.equal(f.calls.some(c=>c[0]==='stop'),false,reason);
  f.p.dispose();assert.equal(f.calls.filter(c=>c[0]==='dispose').length,2,reason);
 }
});

test('retirement failure and disposal failure are recorded once and do not leak a live instance',async()=>{
 for(const failure of ['stop','update','isRetired','dispose']){
  const f=fixture();await ready(f);const instance=f.instances[1];instance[failure]=()=>{throw new Error(`Failed ${failure}`);};
  f.records.pop();f.p.update(.1);if(failure==='dispose'){instance.retired=true;f.p.update(.1);}
  assert.equal(f.p.retiring.size,0,failure);assert.equal(f.diagnostics.length,1,failure);
  f.p.update(.1);assert.equal(f.diagnostics.length,1,failure);f.p.dispose();
 }
});
