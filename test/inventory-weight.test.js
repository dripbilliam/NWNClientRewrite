import test from 'node:test';
import assert from 'node:assert/strict';
import {computeItemUnitWeight as unit,getItemWeight as weight,updateEncumbrance as encumbrance} from '../src/inventory_weight.js';
import {parse2da} from '../src/area.js';
import {ModuleSession} from '../src/module_session.js';
const baseitems=parse2da('2DA V2.0\n\nModelType TenthLBS\n0 0 3\n1 3 999\n');
const encumbranceTable=parse2da('2DA V2.0\n\nNormal Heavy\n0 100 200\n');
test('unit mass uses tenth-pound data, summed passive extra weight and strongest reduction without stack scaling',()=>{
  const item={authored:{BaseItem:0,StackSize:20,PropertiesList:[{PropertyName:81,CostValue:257},{PropertyName:11,CostTable:7,CostValue:0},{PropertyName:11,CostTable:7,CostValue:1}]}};
  const rules={baseitems,iprp_weightinc:parse2da('2DA V2.0\n\nValue\n0 0\n1 7\n'),itemCosts:new Map([[7,parse2da('2DA V2.0\n\nValue\n0 .5\n1 .25\n')]])};
  assert.equal(unit(item,rules),2);assert.equal(item.nativeUnitWeight45c,2);
  item.authored.PropertiesList=[];assert.equal(unit(item,rules),3);
});
test('armor mass uses computed armor class as physical armor row and rejects unknown loader scratch',()=>{
  const item={authored:{BaseItem:1,ArmorPart_Torso:0,PropertiesList:[]}};
  const rules={baseitems,parts_chest:parse2da('2DA V2.0\n\nACBonus\n0 1\n'),armor:parse2da('2DA V2.0\n\nWEIGHT\n0 0\n1 80\n')};
  assert.equal(unit(item,rules),80);assert.throws(()=>unit({authored:{BaseItem:2,PropertiesList:[]}},{baseitems}),/model type/);
});
test('GetWeight includes bag contents once, multiplies signed stacks only above1 and preserves DWORD overflow',async()=>{
  for(const [stack,expected] of [[-1,3],[0,3],[1,3],[20,60],[2147483647,2147483645]])
    assert.equal(await weight({}, {repository:()=>null,unitWeight:()=>3,stack:()=>stack}),expected);
  assert.equal(await weight({}, {repository:()=>({}),unitWeight:()=>3,contents:()=>20,stack:()=>assert.fail('Bag ignores stack')}),23);
});
test('encumbrance reads actual client before thresholds and preserves unsigned strength narrowing and exclusive thresholds',async()=>{
  const actor={id:1,masterId:2,associateType:0,nativeWeightDirty96c:0,nativeEncumbrance970:0};let carried=100;const trace=[];
  const p={pc:()=>1,client:id=>{trace.push(id);return {};},strength:()=>256,totalWeight:()=>carried,dm:()=>0,feedback:(o,code)=>trace.push(code),movementRate:()=>trace.push('movement')};
  await encumbrance(actor,1,{encumbrance:encumbranceTable},p);assert.equal(actor.nativeEncumbrance970,0);assert.deepEqual(trace,[1]);
  carried=201;trace.length=0;await encumbrance(actor,1,{encumbrance:encumbranceTable},p);assert.deepEqual(trace,[1,'movement',8,9]);
  carried=200;trace.length=0;await encumbrance(actor,1,{encumbrance:encumbranceTable},p);assert.deepEqual(trace,[1,'movement',8]);
  carried=0;trace.length=0;await encumbrance(actor,1,{encumbrance:encumbranceTable},p);assert.deepEqual(trace,[1,'movement']);
});
test('ordinary NPC weight refreshes only nonzero dirty cache while clientless PC skips calculations',async()=>{
  const actor={nativeWeightDirty96c:0,associateType:0,masterId:0x7f000000};const p={pc:()=>0,totalWeight:()=>44};
  await encumbrance(actor,1,{},p);assert.equal(actor.nativeTotalWeight978,undefined);
  actor.nativeWeightDirty96c=2;await encumbrance(actor,1,{},p);assert.equal(actor.nativeTotalWeight978,44);
  await encumbrance(actor,1,{}, {pc:()=>1,client:()=>null,totalWeight:()=>assert.fail('No attached client')});
});
test('live item event16 initializes equipped mass before stack decrement and preserves same registered ammo object',async()=>{
  const s=new ModuleSession(null);s.characterRules={baseitems};const actor=s.register('creature','archer',{inventory:[],reputationPCFlag:0});
  const item=s.register('item','ammo',{ownerId:actor.id,equipmentSlot:2048,authored:{BaseItem:0,StackSize:20,PropertiesList:[]}});actor.inventory=[item.id];
  await s.combat.dispatchEvent(item,{eventId:16,callerId:actor.id});
  assert.equal(item.authored.StackSize,19);assert.equal(actor.nativeEquippedWeight968,57);assert.equal(s.registry.get(item.id),item);
});
test('delayed attack effect dispatch retains native temporary duration metadata instead of converting it to instant',async()=>{
  const s=new ModuleSession(null),actor=s.register('creature','target',{}),calls=[];
  s.effects.apply=(...args)=>calls.push(args);const value={type:11,durationType:1,duration:24};
  await s.combat.dispatchEvent(actor,{eventId:5,callerId:9,payload:value});assert.deepEqual(calls,[[1,value,actor.id,24]]);
});
