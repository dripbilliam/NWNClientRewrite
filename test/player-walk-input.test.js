import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {receiveWalkInput} from '../src/player_movement_input.js';
import {PathInformation} from '../src/path_information.js';
import {ModuleSession} from '../src/module_session.js';
import {addObjectAction} from '../src/object_actions.js';

const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-player-walk-input-observations.json',import.meta.url)));
test('decoded waypoint acceptance, duplicate suppression, flags, action ordering and combat steps match original code',async()=>{
 for(const row of capture.rows){
  const c=row.case,calls=[],path=new PathInformation(),actor={id:99,nativePathInfo:path,nativeField8ac:c.field8ac??0,nativeFieldEc:c.commandable??1,creatureAnimation:c.state??0,currentAITargetId:100,
   position:(c.position??[4,5,0]).map((_,i)=>i===0?(c.position??[4,5,0])[0]:i===1?(c.position??[4,5,0])[2]:-(c.position??[4,5,0])[1]),combatRound:{}},other={position:[(c.targetPosition??[6,5,0])[0],(c.targetPosition??[6,5,0])[2],-(c.targetPosition??[6,5,0])[1]]};
  const off=c.reverse?0x64:0x4c;path.raw.setInt32(0x74,c.reverse??0,true);path.raw.setUint32(c.reverse?0x70:0x60,c.storedArea??88,true);path.field28=c.storedTarget??0x7f000000;
  (c.stored??[1,1,1]).forEach((v,i)=>path.raw.setFloat32(off+i*4,v,true));let id=0,axis=0,byte=0,bool=0;
  const reset=path.resetAtEnd.bind(path);path.resetAtEnd=()=>{calls.push(['reset']);reset();};
  const result=await receiveWalkInput(null,{readObjectId:()=>[c.areaId,c.targetId][id++],readFloat:()=>c.point[axis++],readByte:()=>[c.sequence,c.fractional][byte++],readBool:()=>[c.run,c.clientPath][bool++],overflow:()=>c.overflow??0,underflow:()=>c.underflow??0,
   clientObject:()=>c.controlled===false?null:actor,asCreature:o=>c.creature===false?null:o,area:()=>c.area===false?null:{},object:()=>c.target===false?null:other,asObject:o=>c.asObject===false?null:o,
   pause:(_o,...args)=>calls.push(['pause',...args]),pauseTimer:(_o,...args)=>calls.push(['pauseTimer',...args]),combatStep:(_o,...args)=>calls.push(['combatStep',...args]),
   computeAIState:o=>{calls.push(['compute']);o.creatureAnimation=c.computed??0;},stickyModes:()=>c.sticky,setMode:(_o,...args)=>calls.push(['mode',...args]),clearSpecial:()=>calls.push(['clearSpecial']),actionManager:(_o,n)=>calls.push(['actionManager',n]),
   addMove:(_o,group,point,...args)=>calls.push(['move',group,[point[0],-point[2],point[1]],...args]),
  });
  assert.deepEqual({result,calls,sequence:path.raw.getUint32(0x20,true),fractional:path.field19c},{result:row.result,calls:row.calls,sequence:row.sequence,fractional:row.fractional},JSON.stringify(c));
 }
 assert.equal(capture.rows.length,215);
});

test('queued movement snapshots the request and rejects stale area/control identities',async()=>{
 const s=new ModuleSession(null),a=s.register('player','a',{areaId:42}),b=s.register('player','b',{areaId:42});s.player=a;const requests=[];s.combat.receiveWalkInput=async r=>{requests.push(r);return 1;};
 const position=[1,2,3],promise=s.queuePlayerMovement({areaId:42,position});position[0]=99;await s.drainPlayerInputs();assert.equal(await promise,1);assert.deepEqual(requests[0].position,[1,2,3]);
 const wrongArea=s.queuePlayerMovement({areaId:42,position});a.areaId=43;await s.drainPlayerInputs();assert.equal(await wrongArea,0);
 a.areaId=42;const wrongActor=s.queuePlayerMovement({areaId:42,position});s.player=b;await s.drainPlayerInputs();assert.equal(await wrongActor,0);assert.equal(requests.length,1);
 await assert.rejects(s.queuePlayerMovement({areaId:42,position:[NaN,0,0]}),/XYZ/);
});

test('keyboard release cancels only its current movement sequence and preserves a subsequent command',async()=>{
 const s=new ModuleSession(null),a=s.register('player','a',{areaId:42});s.player=a;const cancelled=[];
 s.combat.cancelQueuedAction=async(...args)=>{cancelled.push(args);return 1;};
 const node=addObjectAction(a.objectActionState,1,65535,Array.from({length:8},(_,i)=>({type:1,value:i===7?17:0})));
 const old=s.queuePlayerMovementStop(16);await s.drainPlayerInputs();assert.equal(await old,0);
 const current=s.queuePlayerMovementStop(17);await s.drainPlayerInputs();assert.equal(await current,1);assert.deepEqual(cancelled,[[a,0,node.groupId]]);
 a.objectActionState.list.shift();addObjectAction(a.objectActionState,8,65535,[]);
 const replaced=s.queuePlayerMovementStop(17);await s.drainPlayerInputs();assert.equal(await replaced,0);assert.equal(cancelled.length,1);
});
