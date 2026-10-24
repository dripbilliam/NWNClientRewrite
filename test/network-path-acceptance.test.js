import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {NetworkPathAcceptance,acceptClientPath} from '../src/network_path_acceptance.js';
import {NetworkMotion} from '../src/network_motion.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-path-acceptance-v1.json',import.meta.url))),clone=structuredClone;

test('73 original acknowledgement cases match ordered queries, repaired paths, skips, and reset notifications',async()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,73);
 for(const [index,row]of oracle.cases.entries()){
  const c=row.case,before=clone(c),queries=[],projected=[];
  const result=await acceptClientPath({area:c.area,render:c.render,path:c.priorPath,cursor:c.cursor,script:c.script,sequence:c.sequence,lastSequence:c.lastSequence},c.path,c.serverPosition,async(start,end)=>{const native=row.queries[queries.length];assert.ok(native,'extra query '+index);assert.deepEqual(start,native.start);assert.deepEqual(end,native.end);assert.equal(native.radius,1/64);assert.equal(native.height,1/64);assert.equal(native.creatures,0);queries.push({start,end});return native.result===1;},async point=>{const value=[...point.slice(0,2),c.height];projected.push(value);return value;});
  assert.equal(queries.length,row.queries.length,'query count '+index);assert.deepEqual(result?[result.path]:[],row.installed,'path '+index);assert.deepEqual(result?.reset?[result.reset]:[],row.rendered,'reset '+index);assert.deepEqual(projected,row.projected,'projection '+index);assert.deepEqual(projected,row.notifications,'notification '+index);assert.deepEqual(c,before);
 }
});

function fixture(){
 const object={id:1,objectType:5,areaId:7,replicated:{position:[10,20,1],orientation:[1,0,0],animation:4,walkRate:2200,runRate:4400}},objects=new Map([[1,object]]),errors=[],motion=new NetworkMotion(),m=motion.ensure(object),binding={animation:0};
 const scene={world:{registry:objects},objects:new Map([[1,binding]]),area:{id:7},closed:false,motion,report:(...e)=>errors.push(e),acknowledgementGeometry:()=>({query:async(_actor,options)=>{assert.equal(options.acknowledgement,true);return async()=>true;}})},admission=new NetworkPathAcceptance(scene);
 const changes={path:[[11,20,0],[12,20,0]],position:[10,20,1],animation:4,actionFlag:0,field8F4:1,field8EC:1};
 return{scene,object,objects,errors,m,binding,changes,admission};
}

test('scene-owned acceptance installs a clear server path without mutating canonical data',async()=>{
 const f=fixture(),before=clone(f.object);await f.admission.observe(f.object,f.changes);assert.deepEqual(f.m.path,f.changes.path);assert.equal(f.m.active,true);assert.equal(f.binding.animation,null);assert.deepEqual(f.object,before);assert.deepEqual(f.errors,[]);
});

test('delayed connectivity is recomputed from the current displayed pose',async()=>{
 const f=fixture(),queries=[];let release,calls=0;f.scene.acknowledgementGeometry=()=>({query:async()=>{if(++calls===1)await new Promise(r=>release=r);return async(from,to)=>{queries.push({from:from.slice(),to:to.slice()});return true;};}});
 const work=f.admission.observe(f.object,f.changes);f.m.position[0]=10.2;f.m.render[0]=10.15;release();await work;assert.equal(calls,2);assert.equal(queries[1].from[0],Math.fround(10.15));assert.deepEqual(f.m.path,f.changes.path);
});

test('new paths and interruption, object replacement, area exit or disposal cannot accept old IO',async()=>{
 for(const action of['new-path','stop','replace','area','dispose','sequence']){
  const f=fixture();let release,calls=0;f.scene.acknowledgementGeometry=()=>({query:async()=>{if(++calls===1)await new Promise(r=>release=r);return async()=>true;}});
  const work=f.admission.observe(f.object,f.changes);
  if(action==='new-path')void f.admission.observe(f.object,{...f.changes,path:[[15,20,0]]});
  if(action==='stop')f.admission.observe(f.object,{animation:0,path:[]});
  if(action==='replace')f.objects.set(1,clone(f.object));
  if(action==='area')f.object.areaId=8;
  if(action==='dispose'){f.admission.dispose();f.scene.closed=true;}
  if(action==='sequence'){f.m.script=1;f.m.driveSequence=24;f.admission.pending.get(1).changes.actionFlag=23;}
  release();await work;
  assert.deepEqual(f.m.path,action==='new-path'?[[15,20,0]]:[],action);assert.deepEqual(f.errors,[],action);
 }
});

test('continually changing poses defer work to the next frame without unbounded retries',async()=>{
 const f=fixture();let calls=0;f.scene.acknowledgementGeometry=()=>({query:async()=>{calls++;f.m.render[0]+=.01;return async()=>true;}});
 await f.admission.observe(f.object,f.changes);assert.equal(calls,3);assert.equal(f.m.active,false);assert.equal(f.admission.pending.size,1);
 f.scene.acknowledgementGeometry=()=>({query:async()=>async()=>true});f.admission.update();await f.admission.running.get(1);assert.equal(f.m.active,true);assert.equal(f.admission.pending.size,0);
});

test('fully disconnected path uses the native server position reset, retaining correction timer',async()=>{
 const f=fixture();f.m.correction=512;f.m.render[0]=9.7;f.scene.acknowledgementGeometry=()=>({query:async()=>async()=>false});const before=clone(f.object);
 await f.admission.observe(f.object,{...f.changes,position:[10.3,20.1,1]});assert.deepEqual(f.m.position,[10.3,20.1,1].map(Math.fround));assert.deepEqual(f.m.render,f.m.position);assert.equal(f.m.correction,512);assert.deepEqual(f.object,before);
});

test('initial area loading keeps the latest path pending until its geometry is available',async()=>{
 const f=fixture();f.scene.canAcceptPaths=()=>false;await f.admission.observe(f.object,f.changes);assert.equal(f.m.active,false);assert.equal(f.admission.pending.size,1);
 f.scene.canAcceptPaths=()=>true;f.admission.update();await f.admission.running.get(1);assert.equal(f.m.active,true);assert.equal(f.admission.pending.size,0);
});

test('failure from a replaced query cannot delete or report against a newer path',async()=>{
 const f=fixture();let reject,calls=0;f.scene.acknowledgementGeometry=()=>({query:async()=>{if(++calls===1)await new Promise((_r,j)=>reject=j);return async()=>true;}});
 const first=f.admission.observe(f.object,f.changes);void f.admission.observe(f.object,{...f.changes,path:[[15,20,0]]});reject(Error('obsolete query failed'));await first;assert.deepEqual(f.m.path,[[15,20,0]]);assert.deepEqual(f.errors,[]);
});

test('obsolete idle/path acknowledgements cannot cancel a pending matching path',async()=>{
 for(const path of[[],[[2,3,0]]]){
  const f=fixture();f.m.script=1;f.m.driveSequence=23;let release;f.scene.acknowledgementGeometry=()=>({query:async()=>{await new Promise(r=>release=r);return async()=>true;}});
  const work=f.admission.observe(f.object,{...f.changes,actionFlag:23});f.admission.observe(f.object,{path,animation:0,actionFlag:22,walkRate:2000});assert.equal(f.admission.pending.size,1);assert.equal(f.m.walkRate,2000);release();await work;assert.deepEqual(f.m.path,f.changes.path);
 }
});

test('a position omitted from the path delta is captured before resource IO',async()=>{
 const f=fixture();let release;f.scene.acknowledgementGeometry=()=>({query:async()=>{await new Promise(r=>release=r);return async()=>false;}});const changes={...f.changes};delete changes.position;
 const work=f.admission.observe(f.object,changes);f.object.replicated.position=[99,99,0];release();await work;assert.deepEqual(f.m.position,[10,20,1]);assert.deepEqual(f.object.replicated.position,[99,99,0]);
});

test('a replacement canonical actor with the same ID starts with fresh motion ownership',()=>{
 const f=fixture();f.m.script=1;f.m.driveSequence=23;f.m.correction=400;f.m.previewBase=true;f.m.previewGeneration=8;f.m.render=[7,8,0];
 const replacement=clone(f.object);replacement.replicated.position=[50,60,1];const fresh=f.scene.motion.ensure(replacement);
 assert.notEqual(fresh,f.m);assert.deepEqual(fresh.position,[50,60,1]);assert.deepEqual(fresh.render,[50,60,1]);assert.equal(fresh.script,0);assert.equal(fresh.driveSequence,undefined);assert.equal(fresh.previewGeneration,undefined);
});

test('a create record clears old drive ownership even when the canonical proxy is retained',async()=>{
 const f=fixture();f.m.script=1;f.m.driveSequence=23;f.m.previewBase=true;f.m.previewGeneration=8;f.object.replicated.position=[50,60,1];
 await f.admission.observe(f.object,{...f.changes,path:[[51,60,0]],position:[50,60,1],actionFlag:4},true);
 const fresh=f.scene.motion.objects.get(1);assert.notEqual(fresh,f.m);assert.deepEqual(fresh.path,[[51,60,0]]);assert.equal(fresh.driveSequence,undefined);assert.equal(fresh.previewBase,undefined);assert.deepEqual(f.object.replicated.position,[50,60,1]);
});
