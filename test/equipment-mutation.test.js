import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {equipCreatureItem,unequipCreatureItem} from '../src/equipment_mutation.js';
import {EquipmentInventory} from '../src/equipment_inventory.js';
test('equip/unequip mutations match576/72 native event, ownership, property, slot, cache and weight traces',async()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-equipment-mutation-observations.json',import.meta.url)));assert.equal(oracle.equip.length,576);assert.equal(oracle.unequip.length,72);
  for(const row of [...oracle.equip,...oracle.unequip]){const c=row.case,calls=[],inventory=new EquipmentInventory(()=>{}),o={id:77,nativeStatsIsPCb0:c.pc,nativeEquippedWeight968:c.initialWeight,nativeEquipmentLock97c:c.lock??0,nativeEncumbranceDirty53c:0},item={id:99,possessorId:c.possessor};
    if(c.contains)inventory.put(16,item);
    const p={equipEvent:(_o,item,slot)=>calls.push(['object',0,item.id],['object',1,o.id],['integer',0,inventory.index(slot)],['event',0,0,o.id,55,10,39]),
      setPossessor:(item,id,...flags)=>{calls.push(['possessor',id,...flags]);item.possessorId=id;},contains:()=>inventory.contains(item),unequip:(_o,_i,...flags)=>{calls.push(['unequip',...flags]);return c.unequipResult;},
      applyProperties:(_i,_o,...flags)=>calls.push(['apply',...flags]),put:(_o,slot,item)=>{calls.push(['put',slot]);inventory.put(slot,item);},armor:(_o,_i,...flags)=>calls.push(['armor',...flags]),combatInformation:()=>calls.push(['combat']),weight:()=>{calls.push(['weight']);return c.weight;},
      unequipEvent:(_o,item,slot)=>calls.push(['script',16,item.id,o.id,inventory.index(slot)]),slot:()=>inventory.slot(item),removeProperties:(_i,_o,slot)=>calls.push(['remove-properties',slot]),remove:()=>{calls.push(['remove']);return inventory.remove(item);}};
    const result=c.mode==='equip'?await equipCreatureItem(o,c.slot,item,c.apply,c.loading,c.event,p):await unequipCreatureItem(o,item,c.force,c.event,p);
    assert.deepEqual({result,calls,weight:o.nativeEquippedWeight968,possessor:item.possessorId,dirty:o.nativeEncumbranceDirty53c,slots:inventory.ids},{result:row.result,calls:row.calls,weight:row.weight,possessor:row.possessor,dirty:row.dirty,slots:row.slots},JSON.stringify(c));
  }
});
