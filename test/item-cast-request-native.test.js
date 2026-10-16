import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {useItem,addItemCastSpellActions} from '../src/item_cast_request.js';
const oracle=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-cast-request-observations.json',import.meta.url)));
function fixture(c){
 const calls=[],actor={id:99,associateType:c.associate??0,nativeFieldEc:c.commandable??1,nativeField89c:c.pc??0,nativeField97c:c.polymorph??0,spellActionTargetId:123,nativeTarget740:124},
  item={id:55,baseItem:c.baseItem??49,possessorId:c.owner??99},parent={id:77,possessorId:c.parentOwner??99},target={id:100,objectType:c.targetType??5,possessorId:c.targetOwner??99},area={id:7},other={id:8},
  point=[...(c.point??[1.25,2.5,3.75])],property={type:c.type??15,subtype:c.subtype??33,remaining:c.remaining??1};
 const p={item:id=>{calls.push(['item',id]);return id===55?c.item===false?null:item:id===77&&c.parent?parent:null;},object:id=>{calls.push(['object',id]);return c.targetExists===false?null:target;},
  canUse:(_o,_i,ignore)=>{calls.push(['canUse',ignore]);return c.canUse??1;},activeProperty:(_i,index)=>{calls.push(['property',index>>>0]);return c.property===false?null:property;},
  asCreature:()=>{calls.push(['asCreature']);return c.targetCreature===false?null:target;},asItem:()=>{calls.push(['asItem']);return target;},
  visibility:(_o,id)=>{calls.push(['visibility',id]);return c.visibility===undefined?1:c.visibility;},baseInfo:i=>{calls.push(['base',i.baseItem]);return c.missingBase?null:{equipableSlots:c.slots??0};},
  equipped:()=>{calls.push(['equipped']);return c.equipped??1;},feedback:(_o,id)=>calls.push(['feedback',id]),
   addCast:(_o,r)=>{const {consume,...rest}=r;calls.push(['cast',{...rest,automatic:consume}]);return c.lowerResult??1;},addTrap:(_o,...a)=>{calls.push(['trap',...a]);return c.lowerResult??1;},useSkill:(_o,...a)=>{calls.push(['skill',...a]);return c.lowerResult??1;},
  possessed:()=>{calls.push(['possessed']);return c.possessed??0;},dm:()=>{calls.push(['dm']);return c.dm??0;},
  area:o=>{calls.push(['area',o===target?'target':'actor']);return o===target?(c.targetArea==='none'?null:c.targetArea==='other'?other:area):c.area===false?null:area;},
  position:o=>o===target?c.targetPoint??[2.5,0,0]:c.actorPoint??[0,0,0],
  spellIndex:id=>{calls.push(['spellIndex',id]);return c.spellId??100;},spell:id=>{calls.push(['spell',id>>>0]);return c.missingSpell?null:{id};},range:(_o,_s,id)=>{calls.push(['range',id]);return c.range??5;},
  move:(_o,...a)=>{calls.push(['move',...a]);return c.lowerResult??1;},queue:(_o,id,group,params,front)=>{calls.push(['queue',id,group,params.map(p=>({...p,value:p.value>>>0})),front]);return c.lowerResult??1;}};
 return {calls,actor,point,p};
}
test('UseItem preserves original possession, active properties, equipment, perception result2 and skill/trap routes',async()=>{
 for(const {case:c,result,calls,point,targetField,target740}of oracle().uses){const f=fixture(c);
  assert.equal(await useItem(f.actor,55,c.propertyIndex??0,c.mode??0,c.targetId??100,f.point,7,c.automatic??1,f.p),result,JSON.stringify(c));
  assert.deepEqual(f.calls,calls,JSON.stringify(c));assert.deepEqual(f.point,point);assert.equal(f.actor.spellActionTargetId,targetField);assert.equal(f.actor.nativeTarget740,target740);
 }
});
test('native item cast queue preserves point mutation, range, carried targets and physical action parameters',async()=>{
 for(const {case:c,result,calls,point,targetField,target740}of oracle().queues){const f=fixture(c);
  assert.equal(await addItemCastSpellActions(f.actor,{itemId:55,propertyIndex:c.propertyIndex??0,mode:c.mode??0,position:f.point,targetId:c.targetId??100,location:c.location??0,consume:c.automatic??1},f.p),result,JSON.stringify(c));
  assert.deepEqual(f.calls,calls,JSON.stringify(c));assert.deepEqual(f.point,point,JSON.stringify(c));assert.equal(f.actor.spellActionTargetId,targetField);assert.equal(f.actor.nativeTarget740,target740);
 }
});
