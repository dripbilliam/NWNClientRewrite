import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeIdList} from '../src/native_id_list.js';
import {updateSubareasOnJump} from '../src/subareas.js';
import {jumpAreaEffect} from '../src/area_effect.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const list=values=>{const out=new NativeIdList();values.forEach(v=>out.append(v));return out;};
test('jump membership and attached-AoE relocation match 420 original executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-jump-subarea-observations.json',import.meta.url)));assert.equal(data.rows.length,420);
 for(const row of data.rows){
  const c=row.case,calls=[],actor={nativeSubareaMembership:list(c.old??[]),nativeFollowingAOEs:list(c.following??[])},area={id:88},aoe={id:77,nativeAnchor334:99},point=[1,2,3];
  let result;
  if(c.operation==='subareas')result=await updateSubareasOnJump(actor,point,c.area?88:OBJECT_INVALID,{
   areaById:id=>{calls.push(['areaById',id]);return area;},
   inSubareas:(_a,p,next)=>{calls.push(['in',p]);next.copyFrom(list(c.next));return c.found;},
   aoe:id=>{calls.push(['aoe',id]);return id===666?null:aoe;},
   jumpAOE:(_o,a,p)=>{calls.push(['jump',a?.id??null,p]);actor.nativeSubareaMembership.copyFrom(list(c.mutated));},
   handleChanges:(_o,next,crossed,flag)=>{calls.push(['changes',[...next.view()],crossed??0,flag]);return c.changed;},
  });
  else await jumpAreaEffect(aoe,c.same?area:{id:89},point,{
   creature:id=>{calls.push(['creature',id]);return c.anchor?actor:null;},area:()=>{calls.push(['area']);return area;},
   warning:message=>calls.push(['warning',message]),
   removeSubareas:(_o,flag)=>{calls.push(['removeSubareas',flag,[...actor.nativeSubareaMembership.view()]]);actor.nativeSubareaMembership.copyFrom(list(c.mutated));},
   setPosition:(_o,p,flag)=>calls.push(['position',p,flag]),updateSubareas:(_o,p)=>calls.push(['updateSubareas',p??0,[...actor.nativeSubareaMembership.view()]]),
  });
  const got={calls,membership:[...actor.nativeSubareaMembership.view()],...(c.operation==='subareas'?{result}:{})};
  assert.deepEqual(got,{calls:row.calls,membership:row.membership,...(c.operation==='subareas'?{result:row.result}:{})},JSON.stringify(c));
 }
});
