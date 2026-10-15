import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {creatureCorpseItemCount,getCreatureLootable,setCreatureLootable,importCreatureCorpseFields} from '../src/corpse_inventory.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-corpse-inventory-observations.json',import.meta.url)));
test('corpse inventory and lootable gates match original slot order, direct nodes, gold and raw script INTs',async()=>{
  for(const row of capture.rows){const c=row.case,calls=[],actor={objectType:5,nativeGold898:c.gold,nativeLootable4e8:c.old??0,nativeField89c:c.pc??0};let result=0;
    if(c.mode==='count'){
      const items=c.droppable.map(droppable=>({droppable})),nodes=c.repository.map((item,index)=>({item,index}));nodes.forEach((node,n)=>node.next=nodes[n+1]??null);
      result=creatureCorpseItemCount(actor,c.filter,{hasEquipment:()=>c.equipment,equipment:(_actor,slot)=>{calls.push(['slot',slot]);return items[c.slots[String(slot)]??-1]??null;},
        repository:()=>c.carried?{head:nodes[0]??null}:null,repositoryItem:(_repo,node)=>{calls.push(['repositoryItem',node.index]);return items[node.item]??null;}});
    }else{
      calls.push(['creature',77]);const object=c.exists?actor:null;
      if(c.mode==='get')calls.push(['result',getCreatureLootable(object)]);
      else await setCreatureLootable(object,c.value,{dead:()=>{calls.push(['dead']);return c.dead;},dying:()=>{calls.push(['dying']);return c.dying;},possessed:()=>{calls.push(['possessed']);return c.possessed;}});
    }
    assert.deepEqual({result,calls,lootable:actor.nativeLootable4e8},{result:row.result,calls:row.calls,lootable:row.lootable},JSON.stringify(c));
  }
});
test('corpse GFF fields match original BOOL/BYTE import, unsigned decay floor and lootable overrides',()=>{
  for(const row of capture.imports){const c=row.case,actor={nativeStatsIsPCb0:c.pc,nativeBodyBag8a8:c.body};importCreatureCorpseFields(actor,c.data);
    assert.deepEqual({lootable:actor.nativeLootable4e8,decay:actor.nativeDecayTime4ec,destroyable:actor.nativeDestroyableF0,raiseable:actor.nativeRaiseableF4,selectable:actor.nativeSelectableWhenDeadF8,noPermDeath:actor.nativeNoPermDeath8bc,body:actor.nativeBodyBag8a8},
      {lootable:row.lootable,decay:row.decay,destroyable:row.destroyable,raiseable:row.raiseable,selectable:row.selectable,noPermDeath:row.noPermDeath,body:row.body},JSON.stringify(c));
  }
});
