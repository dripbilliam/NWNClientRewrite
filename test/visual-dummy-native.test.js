import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {createClientDummyState,createClientVisualDummy} from '../src/client_projectile_dummy.js';
import {deliverObjectVisualAsync} from '../src/object_visual_delivery.js';
import {visualMilliseconds} from '../src/visual_phase_control.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-dummy-observations.json',import.meta.url)));
test('240 complete original visual receiver cases preserve dummy construction, admission, source-status inversion and lifetime order',async()=>{
 assert.equal(native.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(native.rows.length,240);
 for(const row of native.rows){
  const c=row.case,calls=[],dummy=createClientDummyState(),role=c.role,area={},position=role==='source'?[7,8,9]:[1.25,-2,3.5],duration=role==='target'?Math.fround(c.duration):0,lifetime=role==='point'?10000:duration===0?6000:visualMilliseconds(duration);
  dummy.appearance=0;
  const result=await createClientVisualDummy(role,position,lifetime,{
   construct:()=>{calls.push(['allocate',role,0x480]);if(c.allocateFailure)return null;calls.push(['construct',role]);return dummy;},
   loadModel:async(_s,name,part,flags)=>{calls.push(['load',role,name,part,flags]);return c.load;},currentArea:()=>{calls.push(['module']);return c.area?area:null;},
   register:()=>{calls.push(['register',role,c.register,0]);return{status:c.register,id:7};},setId:(s,id)=>{calls.push(['id',role,id]);s.id=id;},setArea:()=>calls.push(['area',role]),registerAI:()=>calls.push(['ai',role]),setScene:()=>calls.push(['scene',role,1234]),setPosition:(s,pos)=>{calls.push(['position',role,pos]);s.position=pos;},setDelay:(s,target,delay,duration)=>calls.push(['delay',role,target,delay,duration,s.temporary])
  });
  assert.deepEqual(calls,row.calls.filter(v=>!['object','add'].includes(v[0])),JSON.stringify(c));assert.equal(result.aborted,!row.calls.some(v=>v[0]==='add'),JSON.stringify(c));
  if(result.dummy)assert.deepEqual({role,id:dummy.id,position:dummy.position,desiredPosition:dummy.desiredPosition,appearance:dummy.appearance,temporary:dummy.temporary},row.dummies[0],JSON.stringify(c));
 }
});
test('asynchronous object-visual routing waits for native dummy admission before AddVisual and retains original source ID',async()=>{
 const calls=[],source={objectType:5,id:789},dummy={objectType:5,id:7};let resume;
 const pending=new Promise(r=>resume=r),delivery=deliverObjectVisualAsync({visualId:1,targetId:0x7f000000,sourceId:789,position:[1,2,3],sourcePosition:[4,5,6],flag:17,missMode:250,duration:2.5,transform:{}},{visualType:()=>({value:'P'}),object:id=>id===789?source:null,createDummy:async(role,p,d)=>{calls.push([role,p,d]);await pending;return dummy;},renderObject:o=>o,add:(actor,record)=>calls.push(['add',actor,record])});
 assert.equal(calls.length,1);resume();assert.equal(await delivery,1);assert.deepEqual(calls[0],['target',[1,2,3],2500]);assert.equal(calls[1][1],dummy);assert.equal(calls[1][2].sourceId,789);assert.equal(calls[1][2].delivery.instant,0);
});
