import test from 'node:test';
import assert from 'node:assert/strict';
import { activeItemProperty, itemPropertyByType, onHitItem, resolveOnHitProperties, resolveItemOnHitSpells, resolveOnHitVisuals } from '../src/combat_on_hit.js';
import { createCombatRound } from '../src/combat_round.js';
import { parse2da } from '../src/area.js';

const item=(id,slot,base,properties=[])=>({id,slot,data:{BaseItem:base,PropertiesList:properties}});
const property=(PropertyName,Subtype=0)=>({PropertyName,Subtype});
const actor=()=>({id:0x80000000,combatRound:createCombatRound()});

test('native item property classification narrows ushort IDs and preserves first subtype/wildcard match',()=>{
  assert.deepEqual(Array.from({length:100},(_,i)=>i).filter(activeItemProperty),[15,55,70,80]);
  assert.equal(activeItemProperty(65551),1);
  const first=property(82,3),second=property(82,4),third=property(82,3);
  const i=item(42,16,0,[first,second]);i.temporaryProperties=[third];
  assert.equal(itemPropertyByType(i,82),first);assert.equal(itemPropertyByType(i,82,4),second);
  assert.equal(itemPropertyByType(i,65618,65539),first);assert.equal(itemPropertyByType(i,82,8),null);
});

test('native on-hit bow/crossbow/sling selection substitutes ammo even when none is equipped',()=>{
  const a=actor();a.combatRound.attacks[0].weaponAttackType=1;
  for(const [base,slot] of [[8,2048],[11,2048],[6,8192],[7,8192],[61,4096]]){
    const weapon=item(1,16,base),ammo=item(2,slot,20),other=item(3,slot===2048?8192:2048,20);
    assert.equal(onHitItem(a,[weapon,other],{}),null);
    assert.equal(onHitItem(a,[weapon,ammo,other],{}),ammo);
  }
  const weapon=item(1,16,0);assert.equal(onHitItem(a,[weapon],{}),weapon);
  a.combatRound.attacks[0].weaponAttackType=3;
  const claw=item(4,16384,0);assert.equal(onHitItem(a,[weapon,claw],{}),claw);
});

test('on-hit property dispatch only visits matching passive properties of the actual attack item, in order',async()=>{
  const a=actor();a.combatRound.attacks[0].weaponAttackType=1;
  const i=item(42,16,0,[property(80),property(36),property(48),property(67),property(72),property(37),property(82)]);
  const target={id:44},seen=[];
  await resolveOnHitProperties(a,target,[i],{},1,0,{applyProperty:(...args)=>seen.push(args)});
  assert.deepEqual(seen.map(args=>args[3].PropertyName),[36,48,67,72]);
  assert.ok(seen.every(args=>args[0]===a&&args[1]===target&&args[2]===i&&args[4]===1&&args[5]===0));
  await assert.rejects(resolveOnHitProperties(a,target,[i],{},0,0,{}),/applyProperty/);
  await resolveOnHitProperties(a,target,[],{},0,0,{});
});

test('native item-triggered spells use weapon/ammo then chest fallback then qualifying shield, with the first property82',async()=>{
  const a=actor();a.combatRound.attacks[0].weaponAttackType=1;
  const weapon=item(1,16,8,[property(82)]),ammo=item(2,2048,20,[property(82,9),property(82,10)]);
  const chest=item(3,2,16,[property(82)]),natural=item(4,131072,79,[property(82)]),shield=item(5,32,14,[property(82)]);
  const target={id:8,objectType:5},seen=[],p={castSpell:(a,t,i,prop)=>seen.push([i.id,prop.Subtype])};
  await resolveItemOnHitSpells(a,target,[weapon,ammo],[chest,natural,shield],{},p);
  assert.deepEqual(seen,[[2,9],[3,0],[5,0]]);
  seen.length=0;shield.data.BaseItem=0;
  await resolveItemOnHitSpells(a,target,[weapon,ammo],[natural,shield],{},p);
  assert.deepEqual(seen,[[2,9],[4,0]]);
  seen.length=0;target.objectType=10;
  await resolveItemOnHitSpells(a,target,[weapon,ammo],[chest,shield],{},p);
  assert.deepEqual(seen,[[2,9]]);
});

test('native hit visuals scan positive signed components and require successful table reads, including exact ranged byte1',async()=>{
  const a=actor(),data=a.combatRound.attacks[0];data.damage[0]=3;data.damage[1]=-1;data.damage[2]=32768;data.damage[3]=1;data.damage[31]=2;
  const rules={damagehitvisual:parse2da('2DA V2.0\nDEFAULT: 999\n\nVisualEffectID RangedEffectID\n0 10 20\n1 11 21\n2 12 22\n3 **** 23')};
  for(const ranged of [0,1,2]){
    data.ranged=ranged;data.lists[0].length=0;
    await resolveOnHitVisuals(a,rules,{effect:(...args)=>args});
    assert.deepEqual(data.lists[0],ranged===1?[[30,a.id,[20],0],[30,a.id,[23],0]]:[[30,a.id,[10],0]]);
  }
  data.damage.fill(-1);await resolveOnHitVisuals(a,{},{});
  data.damage[12]=1;await assert.rejects(resolveOnHitVisuals(a,{},{}),/table is unavailable/i);
});
