import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeItemRuntime,canonicalItemData} from '../src/native_item_runtime.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';

function fixture(){
  const s=new ModuleSession(null);s.characterRules={baseitems:parse2da('2DA V2.0\n\nModelType PropColumn InvSlotWidth InvSlotHeight Stacking Container TenthLBS\n0 0 1 1 1 99 0 10'),
    itemprops:parse2da(`2DA V2.0\n\nLabel Allowed\n${Array.from({length:90},(_,i)=>`${i} p${i} ${i===62?0:1}`).join('\n')}`)};
  const runtime=new NativeItemRuntime(s),item=s.register('item','item',{tag:'Potion',authored:{}});runtime.initialize(item);
  return{s,runtime,item};
}

test('native item import admits properties in physical order and retains effect/property IDs in separate sequences',async()=>{
  const {s,runtime,item}=fixture();
  assert.equal(item.baseItem,24);assert.equal(item.possessorId,0x7f000000);assert.equal(item.stackSize,1);assert.equal(item.charges,50);
  assert.equal(item.repositoryX,0);assert.equal(item.droppable,1);assert.equal(item.identified,0);
  await runtime.loadData(item,{BaseItem:0,Charges:255,StackSize:65536,PropertiesList:[{PropertyName:62},{PropertyName:15,Subtype:4,CostValue:8},{PropertyName:1,Subtype:2}]});
  assert.equal(item.charges,250);assert.equal(item.stackSize,0);assert.equal(item.nativeUnitWeight45c,10);assert.equal(item.identified,0);
  assert.deepEqual(item.activeProperties.map(p=>[p.type,p.usesPerDay,p.remaining,p.propertyId]),[[15,1,1,'0000000000000001']]);
  assert.deepEqual(item.passiveProperties.map(p=>[p.type,p.propertyId]),[[1,'0000000000000002']]);
  assert.deepEqual(item.effects.map(e=>[e.id,e.type,e.propertyId]),[['0000000000000002',91,'0000000000000001'],['0000000000000003',91,'0000000000000002']]);
  assert.equal(s.effects.nextId,4n);assert.equal(item.activeUseMask,1);assert.equal(item.activeUseBytes[0],1);
  assert.deepEqual(canonicalItemData(item).PropertiesList.map(p=>p.PropertyName),[15,1]);
  assert.deepEqual(item.authored.PropertiesList.map(p=>p.PropertyName),[62,15,1]);
  item.authored.StackSize=17;assert.equal(item.stackSize,17);item.stackSize=19;assert.equal(item.authored.StackSize,19);
  item.ownerId=0x80000001;assert.equal(item.possessorId,0x80000001);item.possessorId=23;assert.equal(item.ownerId,23);
  await assert.rejects(runtime.loadData(item,{}),/reload/);
});

test('empty or rejected pools make the item identified and unsupported saved states remain explicit',async()=>{
  const {runtime,item}=fixture();await runtime.loadData(item,{BaseItem:0,PropertiesList:[{PropertyName:62}],ModelPart1:65537,ModelPart2:17,Leather1Color:20});
  assert.equal(item.identified,1);assert.equal(item.effects.length,0);assert.deepEqual(item.modelParts,[1,0,0]);assert.deepEqual(item.colors,[0,0,0,0,0,0]);
  const {runtime:r,item:i}=fixture();await assert.rejects(r.loadData(i,{BaseItem:999}),/invalid base item/);
  // Saved-object state belongs to LoadFromGff, after the lower data owner.
  await assert.rejects(r.loadFromGff(i,{BaseItem:0,ActionList:[{NumParams:1,Paramaters:[{Type:5,Value:{}}]}]}),/script-situation loading state/);
});

test('plot and cursed import keep separate native cells and canonical GFF fields',async()=>{
  for(const [plot,cursed] of [[0,0],[1,0],[0,1],[2,-1]]){
    const {runtime,item}=fixture();await runtime.loadData(item,{BaseItem:0,Plot:plot,Cursed:cursed});
    assert.equal(item.plot,Number(plot!==0));assert.equal(item.cursed,Number(cursed!==0));
    assert.equal(canonicalItemData(item).Plot,item.plot);assert.equal(canonicalItemData(item).Cursed,item.cursed);
  }
});
