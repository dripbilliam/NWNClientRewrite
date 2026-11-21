import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {ItemRepository} from '../src/item_repository.js';
import {selectMeleeWeapon,selectRangedWeapon,selectAmmunition} from '../src/weapon_selection.js';
test('melee/ranged/ammunition selection matches864 original order, ties, restores, queue and recursive traces',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-weapon-selection-observations.json',import.meta.url)));assert.equal(capture.observations.length,864);
  for(const row of capture.observations){const c=row.case,calls=[],slots=new Map(),r=new ItemRepository(99,10,36,60,0),items=new Map(Object.entries(capture.descriptors).map(([id,d])=>[Number(id),{id:Number(id),baseItem:d.base,...d}])),o={id:99};
    for(const id of c.stock.slice().reverse())r.insertHead(id);if(c.old!==null)slots.set(16,c.old);if(c.ammo)slots.set(2048,151);
    const p={repository:()=>c.repo?r:null,object:id=>c.target&&id!==0x7f000000?{id:11,objectType:5}:null,item:id=>items.get(id),baseInfo:i=>capture.bases[i.baseItem],equipped:(_o,slot)=>items.get(slots.get(slot)),
      unequip:(_o,i,...args)=>{calls.push(['unequip',i.id,...args]);const slot=[...slots].sort(([a],[b])=>a-b).find(([,id])=>id===i.id)?.[0];if(slot!==undefined)slots.delete(slot);return 1;},
      equip:(_o,slot,i,...args)=>{calls.push(['equip',slot,i.id,...args]);slots.set(slot,i.id);return 1;},stash:(_o,ref,...args)=>{calls.push(['stash',ref.item.id,...args]);if(![...r.ids()].includes(ref.item.id))r.insertHead(ref.item.id);return 1;},
      remove:(_r,i)=>{calls.push(['remove',i.id]);for(let node=r.head;node;node=node.next)if(node.id===i.id){r.removeNode(node);break;}return 1;},
      canEquip:(_o,i,ref)=>{calls.push(['gate',i.id,ref.slot]);return c.gate;},relativeSize:()=>0,weaponAttackType:()=>1,monkAbilities:()=>c.monk,
      damage:(_o,t,offhand)=>{calls.push(['damage',Boolean(t),offhand]);return items.get(slots.get(offhand?32:16))?.damage??1;},elemental:(_o,t,offhand)=>{calls.push(['elemental',Boolean(t),offhand]);return 0;},
      attackModifier:(_o,t)=>{calls.push(['attack',Boolean(t)]);return items.get(slots.get(16))?.attack??0;},addEquip:(_o,i,...args)=>{calls.push(['queue',i.id,...args]);return 1;},warning:()=>calls.push(['warning'])};
    p.ammunition=(...args)=>selectAmmunition(...args,p);const target=c.target?11:0x7f000000;
    const result=c.mode==='melee'?await selectMeleeWeapon(o,target,c.offhand,0,p):c.mode==='ranged'?await selectRangedWeapon(o,target,p):await selectAmmunition(o,target,items.get(c.launcher),p);
    assert.deepEqual({result,calls,stock:[...r.ids()],slots:Object.fromEntries(slots)},{result:row.result,calls:row.calls,stock:row.stock,slots:row.slots},JSON.stringify(c));
  }
});
