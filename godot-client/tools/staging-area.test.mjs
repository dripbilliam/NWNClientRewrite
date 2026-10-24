import test from 'node:test';import assert from 'node:assert/strict';
import {createAreaStaging} from './staging-area.mjs';
import {Scene,PerspectiveCamera} from 'three';
function fixture(){
 const binding=()=>({models:[{resourceName:'authored'}],wrapper:{position:{toArray:()=>[1,2,3]},rotation:{y:.5}}});
 const p={objects:new Map([[1,binding()]]),area:{id:5,resRef:'a'},closed:false},frontend={world:{areaId:5,localObjectId:1},areaGeneration:7};let stopped=false,release;
 const waiting=new Promise(r=>release=r),context={scene:new Scene(),camera:new PerspectiveCamera(),presentation:()=>p,frontend,focus:()=>[0,0,0],stop:()=>stopped=true,content:{rows:()=>[{id:1,revision:1}]},rigs:()=>({data:{}}),exporter:async()=>{await waiting;return{manifest:{entities:[{id:1}]}};}};
 return{p,frontend,binding,release,context,run:()=>createAreaStaging(context)({areaId:5,generation:7}),stopped:()=>stopped};
}
test('area transfer captures original bindings and immutable scope while stopping source frames',async()=>{
 const f=fixture(),work=f.run();f.release();const result=await work;assert.ok(f.stopped());assert.deepEqual(result.manifest.live,{areaId:5,generation:7,controlledId:1,area:'a'});assert.deepEqual(result.manifest.entities[0].pose,{position:[1,2,3],rotation:.5});
});
test('area switch during asynchronous texture export cannot produce a mixed-world package',async()=>{
 const f=fixture(),work=f.run();await new Promise(r=>setImmediate(r));f.frontend.world.areaId=6;f.frontend.areaGeneration=8;f.release();assert.equal(await work,null);
});
test('new, replaced or removed bindings during initial export force a consistent retry',async()=>{
 for(const change of [f=>f.p.objects.set(2,f.binding()),f=>f.p.objects.set(1,f.binding()),f=>f.p.objects.delete(1)]){
  const f=fixture(),work=f.run();await new Promise(r=>setImmediate(r));change(f);f.release();assert.equal(await work,null);
 }
});
test('preparation failure from a retired presenter is discarded; current failures remain visible',async()=>{
 const a=fixture();a.context.exporter=async()=>{await new Promise(r=>setImmediate(r));a.p.closed=true;throw Error('retired');};assert.equal(await a.run(),null);
 const b=fixture();b.context.exporter=async()=>{throw Error('current');};await assert.rejects(b.run(),/current/);
});

test('frontend phase cannot admit an older area presenter',async()=>{
 const f=fixture();f.p.area.id=4;assert.equal(await f.run(),null);
});
