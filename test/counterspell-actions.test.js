import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {addCounterspellActions,executeCounterspellAction,clearCounterspellAction} from '../src/counterspell_actions.js';
import {removeCounterspeller} from '../src/spell_counterspell.js';
import {createObjectAction,setActionParameter} from '../src/object_actions.js';

test('counterspell queue, approach and cancellation match untouched native owners',async()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-counterspell-actions-observations.json',import.meta.url)));
  for(const [kind,rows] of [['queue',oracle.queues],['execute',oracle.actions],['clear',oracle.clears]])for(const row of rows){
    const c=row.case,calls=[],actor={id:99,nativeField8d4:c.flags??65535,combatMode:c.mode??0,counterSpellTargetId:98,nativeField81c:7,
      position:[0,0,0],lockOrientationId:c.lock??0x7f000000,objectActionState:{startDay:4,startTime:5}},
      target={id:100,position:[Math.fround(c.distance??2),0,0],nativeCounterspellers310:[...(c.ids??[]),...Array(10).fill(0x7f000000)].slice(0,10),nativeCounterCount338:c.count??c.ids?.length??0},
      head=c.head===null||c.head===undefined?null:{actionId:c.head,nativeField9c:c.headReady??0},node=createObjectAction(50,7);
    setActionParameter(node,0,3,c.id??100);node.nativeField9c=c.nodeReady??1;let areaCalls=0;
    const p={range:10,creature:id=>c.targetExists===false?null:id===99?actor:target,
      area:o=>o===actor?c.actorNoArea?null:{id:1}:c.targetNoArea||c.vanishArea&&++areaCalls===2?null:{id:c.otherArea?2:1},
      head:()=>head,clear:()=>calls.push(['clear',head?.nativeField9c??c.headReady??0]),
      queue:(_o,id,group,params)=>calls.push(['queue',id,group,params.map(v=>[v.type,v.value])]),
      dead:o=>{calls.push(['dead',o===actor?'actor':'target']);return o===actor?c.dead??0:c.targetDead??0;},
      dying:o=>{calls.push(['dying',o===actor?'actor':'target']);return o===actor?c.dying??0:c.targetDying??0;},
      activityManager:(_o,n)=>calls.push(['activity',n]),position:o=>o.position,
      broadcastState:()=>calls.push(['broadcastState']),initiative:()=>calls.push(['initiative']),setMode:(_o,mode,force)=>calls.push(['mode',mode,force]),
      lock:()=>{calls.push(['lockGet']);return actor.lockOrientationId;},setLock:(_o,id)=>{calls.push(['lock',id]);actor.lockOrientationId=id;},
      feedback:(_o,n)=>calls.push(['feedback',n]),moveFront:(_o,...args)=>calls.push(['move',...args]),waitFront:(_o,group)=>calls.push(['wait',group]),
      remove:removeCounterspeller,setAnimation:(_o,n)=>calls.push(['animation',n])};
    const result=kind==='queue'?await addCounterspellActions(actor,c.id??100,p):kind==='execute'?await executeCounterspellAction(actor,node,p):await clearCounterspellAction(actor,node,c.isHead??1,p);
    assert.equal(result,row.result,`${kind} ${JSON.stringify(c)}`);assert.deepEqual(calls,row.calls,`${kind} ${JSON.stringify(c)}`);
    assert.equal(actor.counterSpellTargetId,row.target);assert.equal(head?.nativeField9c??c.headReady??0,row.headReady);assert.equal(actor.lockOrientationId,row.lock);
    assert.equal(actor.nativeField81c,row.consumed);assert.deepEqual([actor.objectActionState.startDay,actor.objectActionState.startTime],row.time);
    assert.deepEqual(target.nativeCounterspellers310,row.ids);assert.equal(target.nativeCounterCount338,row.count);
  }
});
