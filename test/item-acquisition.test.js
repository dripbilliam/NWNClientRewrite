import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {scriptCreateItem,acquireCreatureItem} from '../src/item_acquisition.js';
import {setItemIdentified} from '../src/item_identification.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
import {writeGff,record as r,field as f} from '../scripts/native-oracle-data.mjs';
const invalid=0x7f000000,capture=JSON.parse(readFileSync(new URL('../backups/animations/native-item-acquisition-observations.json',import.meta.url)));
test('CreateItemOnObject matches1800 original full wrapper runs, retaining IDs even when acquisition BOOL fails',async()=>{
  assert.equal(capture.created.length,1800);
  for(const expected of capture.created){
    const c=expected.case,item={id:42,stackSize:1,droppable:0},calls=[];
    const acquire=async(kind,ref)=>{calls.push(['acquire',kind,item.stackSize]);if(kind!==14)ref.item=c.mutation==='null'?null:c.mutation==='existing'?{id:43}:ref.item;return 0;};
    const p={construct:()=>{calls.push(['construct',invalid]);return item;},loadTemplate:()=>{calls.push(['load']);return c.loaded;},destroy:i=>calls.push(['destroy',i.id]),baseInfo:()=>c.validBase?{stacking:c.maximum}:null,
      acquireCreature:(_o,ref)=>acquire(5,ref),acquirePlaceable:(_o,ref)=>acquire(9,ref),acquireContainer:(_o,ref)=>acquire(6,ref),addStore:()=>acquire(14,{item})};
    const result=await scriptCreateItem('item',c.present?{objectType:c.type}:null,c.stack,'',p);
    assert.deepEqual({result,calls,stack:item.stackSize,droppable:item.droppable},{result:expected.result,calls:expected.calls,stack:expected.stack,droppable:expected.droppable},JSON.stringify(c));
  }
});
test('fresh creature acquisition matches384 original branch/order/pointer runs and keeps possession separate from fit and insertion',async()=>{
  assert.equal(capture.acquired.length,384);
  for(const expected of capture.acquired){
    const c=expected.case,actor={id:11},item={id:42,stackSize:17,possessorId:invalid},existing={id:43,possessorId:invalid},ref={item},repo={},calls=[];
    const p={repository:()=>c.repository?repo:null,objectById:()=>null,itemById:()=>null,
      findPosition:(_r,_i,drop)=>{calls.push(['find',drop]);return c.find?{x:1,y:2}:null;},fit:(_r,_i,x,y)=>{calls.push(['fit',x,y]);return c.fit;},
      add:(_r,ref,x,y,drop,merge)=>{calls.push(['add',x,y,drop,merge]);ref.item=c.mutation==='null'?null:c.mutation==='existing'?existing:ref.item;return c.add;},
      encumbrance:(_a,n)=>calls.push(['encumbrance',n]),removeFromArea:i=>calls.push(['removeArea',i.id]),
      setPossessor:(i,id,events,feedback,quantity)=>{calls.push(['possessor',i.id,id,events,feedback,quantity]);i.possessorId=id;}};
    const result=await acquireCreatureItem(actor,ref,invalid,invalid,c.x,c.y,1,c.feedback,p);
    assert.deepEqual({result,itemId:ref.item?.id??null,possessor:ref.item?.possessorId??null,calls},{result:expected.result,itemId:expected.itemId,possessor:expected.possessor,calls:expected.calls},JSON.stringify(c));
  }
});
test('SetIdentified matches24 native raw INT and sticky price-cache observations',()=>{
  assert.equal(capture.identified.length,24);
  for(const c of capture.identified){const item={nativePriceDirty398:c.dirty};setItemIdentified(item,c.value);assert.equal(item.identified,c.identified);assert.equal(item.nativePriceDirty398,c.resultDirty);}
});
test('live created items use resource data, canonical IDs, deferred tag override and physical stack merging',async()=>{
  const bytes=writeGff('UTI ',r({BaseItem:f(5,0),Tag:f(10,'old'),Identified:f(0,1),Dropable:f(0,0)})),queries=[];
  const s=new ModuleSession({getResource:async(name,type)=>{queries.push([name,type]);return bytes;}});s.characterRules={baseitems:parse2da('2DA V2.0\n\nModelType BasePropColumn InvSlotWidth InvSlotHeight Stacking Container TenthLBS EquipableSlots\n0 0 1 1 1 99 0 10 1'),appearance:parse2da('2DA V2.0\n\nSIZECATEGORY\n0 3')};
  s.module=s.register('module','module',{});const actor=s.register('creature','actor',{authored:{IsPC:0,FeatList:[],ClassList:[]},reputationPCFlag:0});await s.loadInventory(actor,{IsPC:0});
  const first=await s.commands.CreateItemOnObject(['VeryLongResourceName',actor.id,17,'new']);const object=s.registry.get(first);
  // The lower UTI data owner overwrites the requested resource with the
  // serialized TemplateResRef (empty when absent), before the tag override.
  assert.deepEqual(queries,[['verylongresource',2025]]);assert.equal(object.templateResRef,'');assert.equal(object.possessorId,actor.id);assert.equal(object.stackSize,17);assert.equal(object.droppable,1);assert.equal(s.byTag('new')[0],object);assert.equal(s.byTag('old').length,0);
  const before=s.registry.nextObjectId[0],second=await s.commands.CreateItemOnObject(['VeryLongResourceName',actor.id,3,'new']);
  assert.equal(second,first);assert.equal(object.stackSize,20);assert.equal(s.registry.get(before),undefined);assert.deepEqual([...actor.nativeRepository.ids()],[first]);
  s.commands.SetIdentified([first,2]);assert.equal(s.commands.GetIdentified([first]),2);
  assert.equal(await s.commands.CreateItemOnObject(['item',invalid,1,'']),invalid);
});
