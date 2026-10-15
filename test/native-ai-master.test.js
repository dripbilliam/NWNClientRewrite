import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeAIMaster} from '../src/native_ai_master.js';
function fixture(){
  const master=new NativeAIMaster(),objects=new Map(),events=[],trace=[];let clock=0n;
  const add=(id,level)=>{const o={id,objectType:5,nativeAILevel7c:-1,nativeAILocked80:0};objects.set(id,o);master.setLevel(o,level);return o;};
  const p={worldTime:()=>({day:1,time:10}),microseconds:()=>clock,object:id=>objects.get(id)??null,
    peekEvent:()=>events[0],eventDue:e=>e.due<=10,takeEvent:()=>events.shift(),
    dispatchEvent:e=>trace.push(['event',e.event.eventId]),deferEvent:(e,ms)=>{trace.push(['defer',ms,e.event.payload]);events.push({...e,due:10+ms});},
    disposeEvent:e=>trace.push(['dispose',e.targetId]),random:()=>{trace.push('rand');return 0;},
    updateObject:o=>trace.push(['update',o.id]),updateDialog:o=>trace.push(['dialog',o.id]),resetWork:()=>trace.push('reset'),
    overflow:(...args)=>trace.push(['overflow',...args.slice(1)]),moduleUpdate:()=>trace.push('module'),playerDialogs:()=>trace.push('players')};
  const advance=n=>{clock+=BigInt(n);};return{master,objects,events,trace,add,p,advance};
}
test('AI list cursor increments before selection and wraps, preserving uint32 IDs and missing-object termination',()=>{
  const {master,objects,add,p}=fixture(),a=add(0x80000001,3),b=add(2,3),c=add(3,3);
  assert.equal(master.nextObject(3,p),b);assert.equal(master.nextObject(3,p),c);assert.equal(master.nextObject(3,p),a);
  objects.delete(b.id);assert.equal(master.nextObject(3,p),null);assert.equal(master.nextObject(3,p),c);
});
test('AI drains due events before each level, traverses4 down to0, and stops on repeated first object',async()=>{
  const {master,add,events,trace,p}=fixture();add(1,4);add(2,2);add(3,2);add(4,0);
  events.push({targetId:1,due:10,event:{eventId:10}});await master.updateState(p);
  assert.deepEqual(trace,[['event',10],'reset',['update',1],['dialog',1],'reset','reset','reset',['update',3],['dialog',3],
    'reset',['update',2],['dialog',2],'reset','reset','reset',['update',4],['dialog',4],'reset','module','players']);
  assert.equal(master.levels[2].cursor,1);assert.deepEqual(master.durations,[0,0,0,0]);
});
test('new due event exits the current level and dispatches before the next level update',async()=>{
  const {master,add,events,trace,p}=fixture();add(1,4);add(2,4);add(3,3);
  p.updateObject=o=>{trace.push(['update',o.id]);if(o.id===2)events.push({targetId:3,due:10,event:{eventId:10}});};
  await master.updateState(p);assert.deepEqual(trace.filter(x=>Array.isArray(x)&&['event','update'].includes(x[0])),[['update',2],['event',10],['update',3]]);
  assert.equal(events.length,0);
});
test('native60% budget excludes script event time and equality still allows an AI update',async()=>{
  const {master,add,events,trace,p,advance}=fixture();add(1,4);add(2,4);
  events.push({targetId:1,due:10,event:{eventId:10}});p.dispatchEvent=e=>{trace.push('event');advance(100000);};
  p.updateObject=o=>{trace.push(['update',o.id]);advance(6000);};
  await master.updateState(p);assert.deepEqual(trace.filter(x=>Array.isArray(x)&&x[0]==='update'),[['update',2],['update',1]]);
  assert.equal(master.durations.at(-1),112000);assert.equal(trace.filter(x=>x==='event').length,1);
});
test('AI event15 deferral consumes one shared rand and retains payload, while other events are immediate',async()=>{
  const {master,add,events,trace,p}=fixture();add(1,3);const payload={identity:123};
  events.push({targetId:1,due:10,event:{type:'combatAI',eventId:15,payload}}, {targetId:1,due:10,event:{eventId:10}});
  await master.updateState(p);assert.deepEqual(trace.slice(0,3),['rand',['defer',1,payload],['event',10]]);assert.equal(events[0].event.payload,payload);
  master.durations=[10000,10000,10000,10000];trace.length=0;events[0].due=10;
  await master.updateState(p);assert.deepEqual(trace[0],['event',15]);assert.ok(!trace.includes('rand'));
});
test('AI event15 uses unsigned moving average, inclusive threshold and millisecond floor',async()=>{
  const {master,add,events,trace,p,advance}=fixture();add(1,3);master.durations=[10000,10000,10000,10000];
  events.push({targetId:1,due:10,event:{eventId:10}},{targetId:1,due:10,event:{type:'combatAI',eventId:15,payload:null}});
  p.dispatchEvent=e=>{trace.push(['event',e.event.eventId]);advance(625);};p.random=()=>29999;
  await master.updateState(p);assert.deepEqual(trace.slice(0,2),[['event',10],['defer',39,null]]);assert.equal(events[0].due,49);
});
test('AI discards invalid-target events and reports inclusive75ms overflow before module update',async()=>{
  const {master,add,events,trace,p,advance}=fixture();add(1,4);events.push({targetId:99,due:10,event:{eventId:10}});
  p.updateObject=()=>advance(75000);await master.updateState(p);
  assert.deepEqual(trace[0],['dispose',99]);assert.deepEqual(trace.find(x=>Array.isArray(x)&&x[0]==='overflow'),['overflow',163,75000,75000,0]);
  assert.deepEqual(trace.slice(-2),['module','players']);
});
test('AI events created during level0 remain queued for the next master update',async()=>{
  const {master,add,events,trace,p}=fixture();add(1,0);p.updateObject=()=>events.push({targetId:1,due:10,event:{eventId:10}});
  await master.updateState(p);assert.equal(events.length,1);assert.ok(!trace.some(x=>Array.isArray(x)&&x[0]==='event'));
});
