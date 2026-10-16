import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {acquirePlaceableItem,removePlaceableItem} from '../src/item_acquisition.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-placeable-acquisition-observations.json',import.meta.url)));
test('placeable acquisition matches original source removal, failed-add possession and pointer replacement',async()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],source=c.sourceId??77,item={id:100,possessorId:c.possessor??source},merged={id:101,possessorId:source},ref={item},target={id:99},previous={id:source,objectType:c.sourceType},repository={index:0},sourceRepo={index:1},p={
   repository:o=>o===target?(c.repository===false?null:repository):sourceRepo,
   objectById:id=>{calls.push(['object',id]);return(c.lookupStatus??0)!==0||!c.sourceType?null:previous;},
   removeCreatureItem:(_o,item,...args)=>{calls.push(['removeCreature',item.id,...args]);return c.remove??1;},
   removePlaceableItem:(_o,item,flag)=>{calls.push(['removePlaceable',item.id,flag]);return c.remove??1;},
   baseInfo:()=>{calls.push(['baseInfo']);return{container:c.container??1};},removeRepositoryItem:(r,item)=>{calls.push(['removeRepository',r.index,item.id]);return c.remove??1;},
   removeFromArea:item=>calls.push(['removeFromArea',item.id]),add:(_r,ref,x,y,a,b)=>{calls.push(['add',ref.item.id,x,y,a,b]);if(c.replacement==='null')ref.item=null;else if(c.replacement==='merged')ref.item=merged;return c.add??1;},
   setPossessor:(item,id,a,b,d)=>{calls.push(['possessor',item.id,id,a,b,d]);item.possessorId=id;},
   contains:(_r,item,flag)=>{calls.push(['contains',item.id,flag]);return c.contains??1;},
  };
  const result=row.mode==='acquire'?await acquirePlaceableItem(target,ref,source,c.x??255,c.y??255,c.feedback??1,p):await removePlaceableItem(target,item,c.clear??0,p),label=JSON.stringify({mode:row.mode,...c});
  assert.deepEqual(calls,row.calls,label);assert.equal(result,row.result,label);assert.equal(ref.item?.id??null,row.item,label);assert.deepEqual([item.possessorId,merged.possessorId],row.possessors,label);
 }
 assert.equal(native.rows.length,615);
});
