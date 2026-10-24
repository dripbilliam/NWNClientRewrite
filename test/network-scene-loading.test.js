import test from 'node:test';import assert from 'node:assert/strict';import {Group} from 'three';import {NetworkScene} from '../src/network_scene.js';
import {FrameWorkBudget} from '../src/frame_work_budget.js';
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};
function fixture(){const objects=new Map(),world={localObjectId:2,registry:{objects,get:id=>objects.get(id)}},started=[],disposed=[],reports=[],gates=new Map();
 const scene=new NetworkScene({world,resolver:{},report:(...a)=>reports.push(a),loadAsset:async name=>{started.push(name);await gates.get(name)?.promise;return{model:{nodes:[],animations:[],modelName:name}};},instantiate:(asset,name)=>({root:new Group(),dispose:()=>disposed.push(name)}),releaseAsset:()=>{}});
 scene.area={id:1};scene.tables={placeables:{rows:new Map([[1,{ModelName:'a'}],[2,{ModelName:'b'}]])}};
 const add=(id,appearance=1)=>{const o={id,objectType:9,areaId:1,replicated:{appearance,position:[1,2,3]}};objects.set(id,o);return o;};return{scene,world,objects,started,disposed,reports,gates,add};}
const turn=()=>new Promise(r=>setImmediate(r));
test('coalesced loading prioritizes the controlled object and keeps canonical updates free to advance',async()=>{
 const f=fixture();f.add(1,2);const local=f.add(2);const gate=deferred();f.gates.set('a',gate);const work=f.scene.requestSync();await turn();assert.deepEqual(f.started,['a']);assert.equal(f.scene.requestSync(),work);
 local.replicated.position=[7,8,9];gate.resolve();await work;assert.deepEqual(f.scene.objects.get(2).wrapper.position.toArray(),[7,9,-8]);assert.deepEqual(f.started,['a','b']);assert.equal(f.scene.objects.size,2);await f.scene.dispose();
});
test('deleted and changed appearances cannot attach after an asynchronous load',async()=>{
 const f=fixture(),o=f.add(2),gate=deferred();f.gates.set('a',gate);const work=f.scene.requestSync();await turn();o.replicated.appearance=2;f.scene.requestSync();gate.resolve();await work;assert.equal(f.scene.objects.get(2).models[0].resourceName,'b');assert.deepEqual(f.disposed,['a']);assert.equal(f.reports.length,0);
 const g=fixture(),deleted=g.add(2),gate2=deferred();g.gates.set('a',gate2);const pending=g.scene.requestSync();await turn();deleted.replicationRemoved=true;g.scene.requestSync();gate2.resolve();await pending;assert.equal(g.scene.objects.size,0);assert.deepEqual(g.disposed,['a']);await f.scene.dispose();await g.scene.dispose();
});
test('closing during resource preparation drains work and never attaches a late model',async()=>{
 const f=fixture();f.add(2);const gate=deferred();f.gates.set('a',gate);const work=f.scene.requestSync();await turn();const closed=f.scene.dispose();gate.resolve();await Promise.all([work,closed]);assert.equal(f.scene.objects.size,0);assert.equal(f.scene.instances.size,0);assert.equal(f.reports.length,0);
});

function budgetedFixture(){const f=fixture();let now=0,serial=0;const frames=new Map(),instantiate=f.scene.instantiate;f.scene.instantiate=(...args)=>{now+=3;return instantiate(...args);};f.scene.frameWork=new FrameWorkBudget({clock:()=>now,budgetMs:2,schedule:callback=>(frames.set(++serial,callback),serial),cancel:id=>frames.delete(id)});f.frame=()=>{const [id,callback]=frames.entries().next().value;frames.delete(id);callback();};f.frames=frames;return f;}

test('budgeted construction and attachment prioritize the player and recheck canonical identity after yielding',async()=>{
 const f=budgetedFixture();f.add(1,2);const local=f.add(2);const work=f.scene.requestSync();await turn();assert.equal(f.scene.frameWork.snapshot().queued,1);assert.equal(f.scene.objects.size,0);f.frame();await turn();assert.equal(f.scene.objects.size,0);local.replicated.position=[7,8,9];f.frame();await turn();assert.deepEqual(f.scene.objects.get(2).wrapper.position.toArray(),[7,9,-8]);assert.equal(f.scene.objects.has(1),false);
 for(let i=0;i<5&&f.frames.size;i++){f.frame();await turn();}await work;assert.equal(f.scene.objects.size,2);assert.deepEqual(f.started,['a','b']);await f.scene.dispose();assert.equal(f.scene.frameWork.snapshot().closed,true);assert.equal(f.frames.size,0);
});

test('an object removed between budgeted construction and attachment never joins the scene',async()=>{
 const f=budgetedFixture(),local=f.add(2),work=f.scene.requestSync();await turn();f.frame();await turn();local.replicationRemoved=true;f.frame();await work;assert.equal(f.scene.objects.size,0);assert.deepEqual(f.disposed,['a']);assert.equal(f.scene.root.children.length,0);await f.scene.dispose();
});

test('closing an area cancels queued construction before waiting for the ordered sync job',async()=>{
 const f=budgetedFixture();f.add(2);const work=f.scene.requestSync();await turn();assert.equal(f.scene.frameWork.snapshot().queued,1);await Promise.all([work,f.scene.dispose()]);assert.equal(f.scene.objects.size,0);assert.equal(f.scene.instances.size,0);assert.equal(f.scene.frameWork.snapshot().queued,0);assert.equal(f.scene.retiredFrameWork.closed,true);assert.equal(f.frames.size,0);assert.equal(f.reports.length,0);
});
test('item transform updates reuse model instances and reset removed visual state',async()=>{
 const f=fixture(),o=f.add(2);o.objectType=6;o.item={baseItem:0,parts:[1]};f.scene.resolver.getResource=async()=>new ArrayBuffer(8);f.scene.tables.baseitems={columns:['ModelType','ItemClass','DefaultModel'],rows:new Map([[0,{ModelType:'0',ItemClass:'it',DefaultModel:'default'}]])};
 await f.scene.requestSync();const binding=f.scene.objects.get(2);assert.ok(binding,JSON.stringify(f.reports));const starts=f.started.length;
 o.item.visualTransform={entries:[{key:0,value:{channels:[.2,1,1,0,0,0,0,0,0,1].map(value=>({value}))}}]};await f.scene.requestSync();
 assert.equal(f.scene.objects.get(2),binding);assert.equal(f.started.length,starts);assert.ok(Math.abs(binding.visualTransforms.root.scale-.2)<1e-7);
 o.item.visualTransform={entries:[]};await f.scene.requestSync();assert.equal(binding.visualTransforms.root.scale,1);await f.scene.dispose();
});
