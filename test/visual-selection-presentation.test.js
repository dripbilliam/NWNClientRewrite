import test from 'node:test';
import assert from 'node:assert/strict';
import {parse2da} from '../src/area.js';
import {LoopingVisualPresentation} from '../src/looping_visual_presentation.js';

test('native priority selection follows canonical physical order across out-of-order async loads and reattaches the surviving duplicate immediately',async()=>{
 const records=[{visualId:0,scope:20},{visualId:0,scope:20}],actor={id:123,nativeLoopingVisuals160:{records}},render={},finishes=new Map(),instances=new Map(),calls=[],diagnostics=[];
 const visuals=parse2da('2DA V2.0\n\nProgFX_Duration\n0 0\n'),programs=parse2da('2DA V2.0\n\nType\n0 4\n');
 const p=new LoopingVisualPresentation({objects:()=>[actor],object:()=>actor,render:()=>render,tables:async()=>({visuals,programs}),report:(...args)=>diagnostics.push(args),create:(_a,_render,record)=>new Promise(resolve=>finishes.set(record,()=>{
  const nativeState={programType10d:4,visualF8:record.visualId,scope10c:record.scope,finishedF4:0,attached114:0,field110:0,closedEc:0};
  const instance={nativeState,attach:()=>{calls.push(['start',record]);nativeState.attached114=1;},update:()=>{},attachModels:()=>{calls.push(['attach',record]);nativeState.attached114=1;},detachModels:()=>{calls.push(['detach',record]);nativeState.attached114=0;},dispose:()=>calls.push(['dispose',record])};instances.set(record,instance);resolve(instance);
 }))});
 p.update(0);await Promise.resolve();const [first,second]=records;
 finishes.get(second)();await p.entries.get(second).ready;assert.equal(instances.get(second).nativeState.attached114,1);
 finishes.get(first)();await p.entries.get(first).ready;
 assert.equal(instances.get(first).nativeState.attached114,0);assert.equal(instances.get(second).nativeState.attached114,1);
 assert.equal(calls.filter(c=>c[0]==='start').length,2);p.update(.1);assert.equal(calls.filter(c=>c[0]==='start').length,2);
 records.pop();p.update(.1);assert.equal(instances.get(first).nativeState.attached114,1);assert.deepEqual(calls.filter(c=>c[0]==='dispose'),[['dispose',second]]);
 p.dispose();assert.equal(calls.filter(c=>c[0]==='dispose').length,2);assert.deepEqual(diagnostics,[]);
});

test('unsupported selected view gates are diagnosed and clean up loaded instances without repeated asynchronous reload',async()=>{
 const record={visualId:0},actor={id:123,nativeLoopingVisuals160:{records:[record]}},render={},diagnostics=[];let created=0,disposed=0;
 const visuals=parse2da('2DA V2.0\n\nProgFX_Duration\n0 0\n'),programs=parse2da('2DA V2.0\n\nType\n0 4\n');
 const p=new LoopingVisualPresentation({objects:()=>[actor],object:()=>actor,render:()=>render,tables:async()=>({visuals,programs}),report:(...args)=>diagnostics.push(args),create:async()=>{created++;return{nativeState:{programType10d:4,visualF8:0,scope10c:20,finishedF4:0,attached114:1,field110:1,closedEc:0},attach:()=>{},update:()=>{},dispose:()=>disposed++};}});
 p.update(0);await p.entries.get(record).ready;assert.equal(disposed,1);assert.equal(diagnostics[0][0],'visual.selection-failed');assert.match(diagnostics[0][1],/viewGate1407dadb0/);
 p.update(.1);p.update(.1);assert.equal(created,1);assert.equal(diagnostics.length,1);p.dispose();assert.equal(disposed,1);
});
