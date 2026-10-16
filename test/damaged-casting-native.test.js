import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {checkDamagedCasting} from '../src/damaged_casting.js';
import {parse2da} from '../src/area.js';
import {createObjectActionState,addObjectAction,deleteCurrentObjectAction} from '../src/object_actions.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-damaged-casting-observations.json',import.meta.url)));
test('damaged casting roll, level/DC, cancellation, consumption and messages match original block',async()=>{
 for(const {case:c,calls:expected} of oracle.rows){
  const calls=[],o={id:99,animationState:c.animation??15,nativeSpellId218:1,nativeSpellClass22c:c.class??0},creator=c.creator===false?null:{id:98},spell={id:1,master:2,innate:c.innate??3,conjureAnimation:c.conjure??1,useConcentration:c.concentration??1};
  await checkDamagedCasting(o,creator,c.amount??1,{ruleset:parse2da(`2DA V2.0\n\nLabel Value\n0 CONCENTRATION_BASE_DC ${c.dc??10}`)},
   {spell:id=>{calls.push(['spell',id]);return id===1?c.missing?null:spell:c.masterMissing?null:{id:2};},
    roll:(...a)=>{calls.push(['roll',...a]);return c.roll??20;},skill:(_o,id,creator,base)=>{calls.push(['skill',id,creator?.id??null,base]);return c.rank??10;},
    level:(_o,id,index)=>{calls.push(['level',id,index]);return id===1?c.level??1:c.masterLevel??2;},
    deleteCurrent:()=>calls.push(['delete']),animation:(_o,id)=>calls.push(['animation',id]),consume:(_o,...a)=>{calls.push(['consume',...a]);return 0;},feedback:(_o,id)=>calls.push(['feedback',id]),
    create:(type,creatorId,integers)=>({type,creatorId,integers}),apply:(_o,e,loading)=>calls.push(['visual',e.type,e.creatorId,e.integers[0],loading]),message:(_o,data)=>calls.push(['message',data])},c.loading??0);
  assert.deepEqual(calls,expected,JSON.stringify(c));
 }
});
test('current action deletion honors ClearAction admission and disposes only the selected head',async()=>{
 const actor={objectActionState:createObjectActionState()},first=addObjectAction(actor.objectActionState,15),next=addObjectAction(actor.objectActionState,15),calls=[];
 await deleteCurrentObjectAction(actor,{clearAction:async(o,node,head)=>{calls.push([node,head]);return 0;}});assert.equal(actor.objectActionState.list.head.action,first);
 await deleteCurrentObjectAction(actor,{clearAction:async(o,node,head)=>{calls.push([node,head]);return 1;}});assert.equal(actor.objectActionState.list.head.action,next);assert.equal(actor.objectActionState.list.count,1);assert.deepEqual(calls,[[first,1],[first,1]]);
});
