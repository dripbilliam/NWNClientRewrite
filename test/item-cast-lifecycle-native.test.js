import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {setItemCharges,itemActiveUsesLeft} from '../src/item_presentation_state.js';
import {getScriptItemCharges,setScriptItemCharges} from '../src/item_charge_command.js';
import {receiveItemDestroy} from '../src/item_destroy_event.js';
import {clearItemCast} from '../src/item_cast_action.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-cast-lifecycle-observations.json',import.meta.url)));
function item(c){return{id:55,nativeDestroyableF0:c.destroyable??1,possessorId:77,charges:c.charges??42,stackSize:c.stackSize??257,plot:c.plot??0,
 activeProperties:structuredClone(c.properties??[{type:15,costValue:c.cost??1,remaining:c.remaining??1,usesPerDay:c.daily??1}])};}
test('native item resource widths, charge clamping and readiness match original instructions',()=>{
 for(const row of oracle.charges){const i=item(row.case);setItemCharges(i,row.case.value,row.case.update);assert.equal(i.charges,row.charges);assert.deepEqual(i.activeProperties,row.properties);}
 for(const row of oracle.uses)assert.equal(itemActiveUsesLeft(item(row.case),row.case.index??0),row.result,JSON.stringify(row.case));
});
test('native Get/SetItemCharges preserves raw getter and deferred nonplot zero-charge destruction',async()=>{
 for(const row of oracle.set){const c=row.case,i=item(c),calls=[];const result=await setScriptItemCharges(55,c.value,99,{item:id=>{calls.push(['item',id]);return c.present===false?null:i;},
  enqueue:(...a)=>calls.push(['enqueue',...a]),setCharges:(o,n,v)=>{calls.push(['setCharges',n>>>0,v]);setItemCharges(o,n,v);},activeChanged:(_o,n)=>calls.push(['activeChanged',n])});
  assert.equal(result,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(i.charges,row.charges);assert.deepEqual(i.activeProperties,row.properties);
 }
 for(const row of oracle.get){const i=item(row.case),calls=[];assert.equal(getScriptItemCharges(55,{item:id=>{calls.push(['item',id]);return row.case.present===false?null:i;}}),row.pushed|0);assert.deepEqual(calls,row.calls);}
});
test('native item cast cancellation preserves the noninterruptible phase and ordinary cast guard',async()=>{
 for(const row of oracle.clear){const c=row.case,calls=[],actor={nativeField828:41,spellActionTargetId:42,nativeTarget740:43,nativeField81c:46,lockOrientationId:c.lock,objectActionState:{startDay:44,startTime:45}},node={nativeField9c:c.interruptible};
  assert.equal(await clearItemCast(actor,node,c.head,{removeSpellActions:()=>calls.push(['removeSpellActions']),setAnimation:(_o,n)=>calls.push(['animation',n]),pendingEquipment:()=>calls.push(['pendingEquipment']),setLock:(_o,id)=>calls.push(['setLock',id])}),row.result);
  assert.deepEqual(calls,row.calls);assert.deepEqual([actor.nativeField828,actor.spellActionTargetId,actor.nativeTarget740,actor.objectActionState.startDay,actor.objectActionState.startTime,actor.nativeField81c],row.clearFields);
 }
});
test('native item event11 closes containers, removes actual ownership, then removes area and destroys',async()=>{
 for(const row of oracle.destroy){const c=row.case,i=item(c),calls=[],owner={objectType:c.type??5},holder={},repo={},dialog={},clients=(c.openIds??[]).map((id,index)=>({id,index}));
  await receiveItemDestroy(i,{baseInfo:()=>{calls.push(['base']);return c.missingBase?null:{container:c.container??0};},
   clients:()=>{calls.push(['clients']);return clients;},clientObject:client=>{calls.push(['clientObject',client.index]);return c.missingClients?.includes(client.index)?null:{id:100+client.index};},
   openContainerId:client=>client.id,closeContainer:(_i,id,n)=>calls.push(['closeContainer',id,n]),
   object:id=>{calls.push(['object',id]);return id===77?c.owner===false?null:owner:id===88?c.holder?holder:null:id===55&&c.repoMatches!==false?i:null;},
   asCreature:o=>{calls.push(['asCreature']);return o===holder&&c.holderCreature===false?null:o;},asItem:o=>{calls.push(['asItem']);return o;},asPlaceable:o=>{calls.push(['asPlaceable']);return o;},asStore:o=>{calls.push(['asStore']);return o;},
   removeCreatureItem:(_o,_i,...a)=>calls.push(['removeCreatureItem',...a]),hasInventory:()=>c.hasInventory??1,repository:()=>repo,repositoryIds:()=>c.repository??[1,55],removeRepositoryItem:()=>calls.push(['removeRepositoryItem']),
   inStore:(_o,id)=>{calls.push(['inStore',id]);return c.inStore??1;},removeStoreItem:()=>calls.push(['removeStoreItem']),setPossessor:(_i,...a)=>calls.push(['setPossessor',...a]),
   lastHolder:()=>88,conversation:(_o,n)=>{calls.push(['conversation',n]);return c.dialog?dialog:null;},removeDialogItem:(_d,id)=>calls.push(['removeDialogItem',id]),removeFromArea:()=>calls.push(['removeFromArea']),destroy:(_i,n)=>calls.push(['destroy',n])});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
