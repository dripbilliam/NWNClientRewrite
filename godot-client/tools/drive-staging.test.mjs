import test from 'node:test';import assert from 'node:assert/strict';
import {createDriveStaging} from './drive-staging.mjs';
function fixture(){
 const actor={id:1,objectType:5,areaId:7,appearance:{appearance:6},replicated:{position:[10,20,0],animation:0,walkRate:2200,runRate:4400}},other={id:2,objectType:5,areaId:7,appearance:{appearance:6},replicated:{position:[30,20,0]}};
 const objects=new Map([[1,actor],[2,other]]),world={areaId:7,localObjectId:1,registry:{objects,get:id=>objects.get(id)}},p={area:{id:7},world,motion:{objects:new Map([[1,{render:[1,2,0]}]]),height:(_point,z)=>z},closed:false},frontend={world,areaGeneration:3};let inspected,acknowledgement=false;
 const base={scene:p,obstacles:async()=>({}),async query(_actor,options={}){inspected=this.scene.motion.objects;acknowledgement=options.acknowledgement;return(_from,end)=>end[0]<=11;}};
 const adapter=createDriveStaging({presentation:()=>p,frontend,geometry:()=>base});
 const request={actorId:1,areaId:7,generation:3,position:[10,20,0],render:[10,20,0],orientation:[1,0,0],flags:3,poses:[{id:2,position:[10.5,20,0]}]};
 return{actor,p,frontend,adapter,request,base,inspected:()=>inspected,ack:()=>acknowledgement};
}
test('collision uses private native displayed poses and preserves canonical/source motion',async()=>{
 const f=fixture(),before=structuredClone(f.actor),source=structuredClone([...f.p.motion.objects]);const result=await f.adapter.preview(f.request);
 assert.ok(result.path.target[0]<=11);assert.ok(result.path.resendFraction<1);assert.deepEqual(f.inspected().get(2).render,[10.5,20,0]);assert.deepEqual(f.actor,before);assert.deepEqual([...f.p.motion.objects],source);
});
test('retired area and appearance IO cannot publish a collision result',async()=>{
 for(const retire of [f=>f.frontend.areaGeneration++,f=>f.p.closed=true,f=>f.actor.appearance.appearance++]){
  const f=fixture();let release;f.base.obstacles=()=>new Promise(r=>release=r);const work=f.adapter.preview(f.request);retire(f);release({});assert.equal(await work,null);
 }
});
test('server interruptions and disabled movement do not invent a local preview',async()=>{
 const f=fixture();f.actor.replicated.animation=6;assert.equal(await f.adapter.preview(f.request),null);f.actor.replicated.animation=0;f.actor.replicated.field8D4=0;assert.equal(await f.adapter.preview(f.request),null);
});
test('received path repair reuses original acknowledgement geometry and rejects mismatched action ownership',async()=>{
 const f=fixture(),request={...f.request,path:[[11,20]],serverPosition:[10,20,0],state:{render:[10,20,0],path:[],cursor:0,script:1,lastSequence:4,sequence:3}};
 assert.equal(await f.adapter.admit(request),null);assert.equal(f.ack(),true);request.state.sequence=4;assert.deepEqual((await f.adapter.admit(request)).path,[[11,20]]);
});
