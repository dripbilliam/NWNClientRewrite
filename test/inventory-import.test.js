import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
import {parseGff} from '../src/gff.js';
import {writeGff,record as r,field as f} from '../scripts/native-oracle-data.mjs';
import {setCreatureGold} from '../src/creature_gold.js';
const item=(tag,slot=0)=>parseGff(writeGff('UTI ',r({BaseItem:f(5,0),Tag:f(10,tag)},slot)),'UTI ').root;
function fixture(IsPC=0){
  const s=new ModuleSession(null);s.characterRules={baseitems:parse2da('2DA V2.0\n\nModelType PropColumn InvSlotWidth InvSlotHeight Stacking Container TenthLBS EquipableSlots\n0 0 1 1 1 99 0 10 1'),appearance:parse2da('2DA V2.0\n\nSIZECATEGORY\n0 3')};
  s.module=s.register('module','module',{});const o=s.register('creature','actor',{authored:{IsPC,FeatList:[],ClassList:[]}});return{s,o};
}

test('creature inventory import allocates equipped items before carried items using the canonical registry',async()=>{
  const {s,o}=fixture();
  await s.loadInventory(o,{IsPC:0,Gold:17,Equip_ItemList:[item('helmet',1)],ItemList:[item('potion'),item('scroll')]});
  const items=o.inventory.map(id=>s.registry.get(id));
  assert.deepEqual(items.map(i=>i.tag),['helmet','potion','scroll']);
  assert.equal(s.equipmentSlot(o,1),items[0]);assert.deepEqual([...o.nativeRepository.ids()],items.slice(1).reverse().map(i=>i.id));
  assert.deepEqual(items.slice(1).map(i=>[i.repositoryX,i.repositoryY]),[[0,0],[1,0]]);assert.equal(o.nativeEquippedWeight968,10);
  assert.equal(s.commands.GetGold([o.id]),17);setCreatureGold(o,25);assert.equal(s.commands.GetGold([o.id]),25);
  for(let i=0;i<items.length;i++){
    assert.equal(items[i].ownerId,o.id);assert.equal(s.byTag(items[i].tag)[0],items[i]);
    if(i)assert.equal(items[i].id,items[i-1].id+1);
  }
});

test('native creature import limits physical equipment records to18 and only stats-PC carried records to360',async()=>{
  for(const IsPC of [0,1,2,undefined]){
    const {s,o}=fixture(IsPC);
    await s.loadInventory(o,{IsPC,Equip_ItemList:Array.from({length:20},(_,i)=>item(`hat${i}`,1)),ItemList:Array.from({length:362},(_,i)=>Object.assign(item(`carried${i}`),{Repos_PosX:i%10,Repos_Posy:Math.floor(i/10)}))});
    assert.equal(o.nativeRepository.length,360);assert.equal(o.nativeEquipment.ids[0],s.source('actor:Equip_ItemList:17').id);
    assert.equal(s.source('actor:Equip_ItemList:18'),undefined);assert.equal(Boolean(s.source('actor:ItemList:360')),IsPC===0);
    if(IsPC===0){assert.equal(s.source('actor:ItemList:360').possessorId,0x7f000000);assert.equal(s.source('actor:ItemList:361').possessorId,0x7f000000);}
  }
});

test('failed template loads consume IDs, remove incomplete objects and retain a diagnostic',async()=>{
  const {s,o}=fixture();const next=s.registry.nextObjectId[0];
  await s.loadInventory(o,{IsPC:0,ItemList:[{InventoryRes:''},item('valid')]});
  assert.equal(s.registry.get(next),undefined);assert.equal(s.byTag('valid')[0].id,next+1);assert.match(s.diagnostics[0],/empty template/);
});
