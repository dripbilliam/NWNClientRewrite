import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {setClientObjectFade,updateClientObjectFade} from '../src/client_object_fade.js';
import {createClientProjectileDummy,updateClientProjectileDummy} from '../src/client_projectile_dummy.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-dummy-observations.json',import.meta.url))),view=new DataView(new ArrayBuffer(4));
const bits=v=>{view.setFloat32(0,v,true);return view.getUint32(0,true);};
function fixture(c){
 const calls=[],s={id:c.objectId??0x7f000000,position:[0,0,0],desiredPosition:[0,0,0],appearance:0xaaaa,temporary:c.temporary??0,blocked:c.blocked??0,fadeTarget:c.target??1,fadeState:c.fade??1,duration:c.duration??500,delayEnabled:c.delay??0,opacity:c.alpha??1,since:{day:9,time:900},visible:0,deleted:false},p={
  worldTime:()=>{calls.push(['time']);return{day:10,time:1000};},difference:()=>{calls.push(['difference']);return{day:c.elapsedDay??0,time:c.elapsed??0};},snapshotDifference:()=>{calls.push(['snapshot']);return BigInt(c.microseconds??16000);},
  modelHandle:()=>c.handle??1,mode:()=>c.mode??2,controlledId:()=>{calls.push(['controlled']);return c.controlled??7;},display:(_s,offset)=>calls.push(['display',offset]),targetAlpha:()=>{calls.push(['targetAlpha']);return c.targetAlpha??1;},alpha:(_s,a,part)=>calls.push(['alpha',bits(a),part]),handleScene:(_s,on)=>calls.push(['handleScene',on])
 };
 const state=()=>({id:s.id>>>0,position:s.position,desired:s.desiredPosition,appearance:s.appearance,temporary:s.temporary,target:s.fadeTarget,fade:s.fadeState,duration:s.duration>>>0,delay:s.delayEnabled,alpha:bits(s.opacity),since:s.since,visible:s.visible,deleted:s.deleted});
 return{s,p,calls,state};
}
test('native client delay setter and full fade/expiry owner match state and call ordering',()=>{
 let count=0;for(const row of native.rows.filter(r=>['set','expiry'].includes(r.case.modeName))){count++;const c=row.case,{s,p,calls,state}=fixture(c);let result;
  if(c.modeName==='set')setClientObjectFade(s,c.newTarget,c.newDelay,c.newDuration,p);else result=updateClientObjectFade(s,p);
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(state(),row.state,JSON.stringify(c));if(c.modeName==='expiry')assert.equal(result,row.result,JSON.stringify(c));
 }assert.ok(count>9000);
});
test('native missing-target creation retains model/registration/failure/ID/delay ordering',async()=>{
 for(const row of native.rows.filter(r=>r.case.modeName==='create')){const c=row.case,{s,p,calls,state}=fixture(c),area={};
  const result=await createClientProjectileDummy(c.targetId,[4,5,6],c.travel,{construct:()=>{calls.push(['allocate',0x480]);if(c.allocateFailure)return null;calls.push(['ctor']);return s;},loadModel:async(_s,name,part,flags)=>{calls.push(['load',name,part,flags]);return c.load;},player:()=>{calls.push(['player']);return c.player?{}:null;},area:()=>c.area?area:null,register:()=>{calls.push(['register']);return{status:c.register,id:7};},setId:(_s,id)=>{calls.push(['id',id]);s.id=id;},setArea:()=>calls.push(['area']),registerAI:()=>calls.push(['ai']),setScene:()=>calls.push(['scene',1234]),setPosition:(_s,pos)=>{calls.push(['position',pos]);s.position=pos;},setDelay:(s,...args)=>setClientObjectFade(s,...args,p)});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(result.aborted,row.aborted,JSON.stringify(c));assert.equal(result.targetId,row.targetId);assert.deepEqual(state(),row.state,JSON.stringify(c));
 }
});
test('native creature AI expiry removes AI before array deletion and conditionally destroys',()=>{
 for(const row of native.rows.filter(r=>r.case.modeName==='delete')){const c=row.case,{s,p,calls,state}=fixture(c);
  updateClientProjectileDummy(s,{expired:s=>updateClientObjectFade(s,p),removeAI:()=>calls.push(['removeAI']),deleteObject:id=>{calls.push(['delete',id]);return{status:c.deleteStatus,object:c.deleteObject?s:null};},destroy:()=>{calls.push(['destroy',1]);s.deleted=true;}});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(state(),row.state,JSON.stringify(c));
 }
 assert.equal(native.rows.length,9996);
});
