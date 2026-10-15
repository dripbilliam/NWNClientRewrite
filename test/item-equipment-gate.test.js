import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {canEquipWeapon,canEquipImportedItem,canEquipCreatureItem} from '../src/item_equipment_gate.js';
test('weapon equipment gate matches original slot changes, result codes and ordered feedback',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-equipment-weapon-observations.json',import.meta.url)));
  assert.equal(capture.observations.length,6480);
  for(const observation of capture.observations){
    const c=observation.case,o={nativeSize718:3},item={id:1,baseItem:c.base.id},right=c.rightBase?{id:2,baseItem:100}:null,left=c.leftBase?{id:3,baseItem:101}:null;
    const ref={slot:c.slot},feedback=[],p={weaponClientContext:()=>null,baseInfo:i=>i===item?c.base:i===right?c.rightBase:c.leftBase,
      equipmentSlot:(_o,s)=>s===16?right:left,feedback:(_o,code)=>feedback.push(code)};
    const result=await canEquipWeapon(o,item,ref,c.check,c.feedback,p);
    assert.deepEqual({result,slot:ref.slot,feedback},{result:observation.result,slot:observation.slot,feedback:observation.feedback},JSON.stringify(c));
  }
});
test('AI equip gate matches1296 native restriction, proficiency, lock, occupied-hand and DM traces',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-equipment-ai-gate-observations.json',import.meta.url)));assert.equal(capture.observations.length,1296);
  for(const row of capture.observations){const c=row.case,o={nativeSize718:3,nativeEquipmentLock97c:c.locked,nativeField868:0,nativeField86c:0,nativeField870:0},item={id:1,baseItem:c.base.id},right=c.rightBase?{id:2,baseItem:100}:null,left=c.leftBase?{id:3,baseItem:101}:null,ref={slot:c.slot},feedback=[];
    const p={isDM:()=>c.dm,alignmentRestrictions:()=>c.restrictions,classRestrictions:()=>c.restrictions,raceRestrictions:()=>c.restrictions,proficient:()=>c.proficient,possessedFamiliar:()=>0,
      weaponClientContext:()=>null,baseInfo:i=>({...i===item?c.base:i===right?c.rightBase:c.leftBase,equipableSlots:0x3ffff}),equipmentSlot:(_o,s)=>s===16?right:s===32?left:null,feedback:(_o,n)=>feedback.push(n)};
    const result=await canEquipCreatureItem(o,item,ref,0,0,1,p);assert.deepEqual({result,slot:ref.slot,feedback},{result:row.result,slot:row.slot,feedback:row.feedback},JSON.stringify(c));
  }
});
test('import equipment gate matches full original loading calls with independent proficiency/restriction stubs',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-equipment-import-gate-observations.json',import.meta.url)));
  assert.equal(capture.observations.length,8064);
  for(const observation of capture.observations){
    const c=observation.case,o={nativeSize718:3,nativeField868:0,nativeField86c:0,nativeField870:0},item={id:1,baseItem:c.base.id},right=c.rightBase?{id:2,baseItem:100}:null,left=c.leftBase?{id:3,baseItem:101}:null;
    const ref={slot:c.slot},feedback=[],p={weaponClientContext:()=>null,baseInfo:i=>({...i===item?c.base:i===right?c.rightBase:c.leftBase,equipableSlots:0x3ffff}),
      equipmentSlot:(_o,s)=>s===16?right:s===32?left:null,feedback:(_o,code)=>feedback.push(code),isDM:()=>0,alignmentRestrictions:()=>1,classRestrictions:()=>1,raceRestrictions:()=>1,possessedFamiliar:()=>0,proficient:()=>1};
    const result=await canEquipImportedItem(o,item,ref,p);
    assert.deepEqual({result,slot:ref.slot,feedback},{result:observation.result,slot:observation.slot,feedback:observation.feedback},JSON.stringify(c));
  }
});
