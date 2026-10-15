import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {ItemRepository,repositoryRemove} from '../src/item_repository.js';
import {removeCreatureItem} from '../src/item_removal.js';
import {clearCreatureActivities} from '../src/combat_mode.js';
import {receiveInventoryDisturbance,lastDisturbed,inventoryDisturbItem,inventoryDisturbType} from '../src/inventory_disturbance.js';
import {ModuleSession} from '../src/module_session.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-inventory-control-observations.json',import.meta.url)));
const repo=(owner,ids)=>{const r=new ItemRepository(owner,10,36,60,0);for(const id of [...ids].reverse())r.insertHead(id);return r;};

test('creature removal matches native ownership, bag, unequip, failure weight and quickbar ordering',async()=>{
  assert.equal(capture.removed.length,768);
  for(const row of capture.removed){
    const c=row.case,calls=[],actor={id:11},item={id:33,possessorId:c.possessor},owner={id:22,objectType:c.ownerType,possessorId:c.parent},r=repo(11,c.contains?[33]:[]),bag=repo(22,[]);
    const result=await removeCreatureItem(actor,c.present?item:null,2,3,c.skip,c.clear,{
      inEquipment:()=>c.equipped,runUnequip:(_o,...a)=>calls.push(['unequip',...a]),repository:o=>o===actor?r:bag,
      objectById:()=>owner,removeRepositoryItem:r=>{calls.push(['remove',r.ownerId]);return c.removed;},
      encumbrance:(o,v)=>calls.push(['weight',o.id,v]),setPossessor:(i,...a)=>{calls.push(['possessor',...a]);i.possessorId=a[0];},
      quickbar:()=>c.quickbar?{}:null,removeQuickbarItem:(_o,id)=>calls.push(['quickbar',id]),
    });
    assert.deepEqual({result,possessor:item.possessorId,calls},{result:row.result,possessor:row.possessor,calls:row.calls},JSON.stringify(c));
  }
});

test('repository removal matches first-ID unlink and container property weight gates',async()=>{
  assert.equal(capture.repositories.length,720);
  for(const row of capture.repositories){
    const c=row.case,calls=[],r=repo(22,c.ids),owner={id:22,objectType:c.ownerType,possessorId:c.parent},actor={id:11,objectType:c.parentCreature?5:9};
    const result=await repositoryRemove(r,{id:33},{objectById:id=>id===22?owner:actor,baseInfo:()=>({container:c.container}),hasProperty:(_o,t)=>c.properties.includes(t),updateEncumbrance:(o,v)=>calls.push(['weight',o.id,v])});
    // Native linked list primitives were captured substitutes in this oracle.
    assert.deepEqual({result,ids:[...r.ids()],calls},{result:row.result,ids:row.ids,calls:row.calls.filter(c=>c[0]!=='unlink')},JSON.stringify(c));
    assert.equal(r.length,row.ids.length);assert.equal(r.head?.previous??null,null);assert.equal(r.tail?.next??null,null);
  }
});

test('activity clearing matches original mask whitelist and physical order',async()=>{
  for(const row of capture.activities){const calls=[];await clearCreatureActivities({activities:row.active,lockedActivities:row.locked},row.mask,(_o,...args)=>calls.push(['activity',...args]));assert.deepEqual(calls,row.calls,JSON.stringify(row));}
  const o={activities:3,lockedActivities:0},calls=[];await clearCreatureActivities(o,31,(_o,bit)=>{calls.push(bit);o.lockedActivities=2;});assert.deepEqual(calls,[1]);
});

test('disturbance handler and getters match native histories, script context and cast gates',async()=>{
  for(const row of capture.events){const c=row.case,o={id:11,objectType:5},calls=[];
    await receiveInventoryDisturbance(o,row.history[0],{type:27,objectIds:[c.disturbItem],integers:[c.disturbType]}, {
      setLastHostile:(_o,...a)=>calls.push(['hostile',...a]),runEventScript:(o,index)=>{if(c.hasScript)calls.push(['script',o.id,o.objectType*1000+index]);},
    });
    assert.deepEqual([o.nativeLastDisturbed19c,o.nativeDisturbItem1b0,o.nativeDisturbType1b4],row.history);assert.deepEqual(calls,row.calls);
  }
  for(const row of capture.getters){const c=row.case,o=c.present&&c.objectCast?{objectType:c.objectType,nativeLastDisturbed19c:0x80000001,nativeDisturbItem1b0:0x80000002,nativeDisturbType1b4:-1}:null;
    assert.deepEqual([lastDisturbed(o),inventoryDisturbItem(o),inventoryDisturbType(o)],row.values,JSON.stringify(c));}
});

test('live event dispatch exposes canonical deleted IDs inside the authored disturbance script',async()=>{
  const s=new ModuleSession(null),o=s.register('creature','victim',{scripts:{disturbed:'authored_disturb'}}),calls=[];
  s.damage.setLastHostile=(_o,caller,force)=>calls.push(['hostile',caller.id,force]);s.program=async name=>name;
  s.vm={run:async(name,self,options)=>{calls.push(['script',name,self,options.scriptEventContext]);assert.equal(s.commands.GetLastDisturbed([],{self}),0x80000001);assert.equal(s.commands.GetInventoryDisturbItem([],{self}),0x80000002);assert.equal(s.commands.GetInventoryDisturbType([],{self}),0);}};
  await s.combat.dispatchEvent(o,{eventId:10,callerId:0x80000001,payload:{type:27,objectIds:[0x80000002],integers:[0]}});
  assert.deepEqual(calls,[['hostile',0x80000001,0],['script','authored_disturb',o.id,5005]]);
  assert.equal(o.creatureState,o.nativeField771);o.creatureState=261;assert.equal(o.nativeField771,5);o.nativeField771=15;assert.equal(o.creatureState,15);
});
