import test from 'node:test';
import assert from 'node:assert/strict';
import {createCombatRound} from '../src/combat_round.js';
import {resolvePostRangedDamage as post} from '../src/combat_ranged_damage.js';
import {resolveSafeProjectile as projectile} from '../src/safe_projectile.js';
function fixture(){
  const actor={id:1,combatRound:createCombatRound(),position:[0,0,0]},target={id:2,plot:0,position:[10,0,0]},data=actor.combatRound.attacks[0],trace=[];
  data.result=1;data.damage[12]=3;
  const p={creature:o=>{trace.push('cast');return o;},hitPoints:()=>20,immortal:()=>0,position:o=>o.position,attackWeapon:()=>null,
    devastatingCritical:()=>0,effectImmunity:()=>0,abilityModifier:()=>4,level:()=>10,savingThrow:()=>0,
    effect:(type,creatorId,integers,subtype)=>({type,creatorId,integers,subtype}),message:(type,fields)=>({type,...fields}),weaponEffective:()=>1};
  return{actor,target,data,trace,p};
}
test('ranged post-damage retains native creature casts and killing blow without requiring melee follow-up owners',async()=>{
  const {actor,target,data,trace,p}=fixture();p.hitPoints=()=>2;data.sneakAttack=1;
  await post(actor,target,{},p);assert.equal(data.killingBlow,1);assert.deepEqual(trace,['cast','cast','cast']);assert.deepEqual(data.lists,[[],[],[],[]]);
});
test('ranged coup effect uses inclusive f32 3D range, signed INT square and active rules independently of immortality',async()=>{
  const {actor,target,data,p}=fixture();data.coupDeGrace=1;p.immortal=()=>1;
  await post(actor,target,{},p);assert.equal(data.killingBlow,0);assert.deepEqual(data.lists[0],[{type:19,creatorId:1,integers:[0,1],subtype:0}]);
  data.lists[0].length=0;target.position=[10,0,.001];await post(actor,target,{},p);assert.equal(data.lists[0].length,1);
  data.lists[0].length=0;target.position=[10,0,.01];await post(actor,target,{},p);assert.equal(data.lists[0].length,0);
});
test('ranged devastating critical uses BYTE level/signed cached strength, distinct success and failure payloads, and existing lethal veto',async()=>{
  const {actor,target,data,p}=fixture();data.result=3;p.devastatingCritical=()=>1;let dc;
  p.level=()=>266;p.abilityModifier=()=>260;p.savingThrow=(...args)=>{dc=args[2];return 0;};
  await post(actor,target,{},p);assert.equal(dc,19);assert.equal(data.result,10);assert.deepEqual(data.lists[0][0].integers,[1,1]);
  data.result=3;data.lists[0].length=0;p.savingThrow=()=>2;await post(actor,target,{},p);assert.equal(data.result,3);assert.deepEqual(data.lists[3][0],{type:2,objects:[2],integers:[257]});
  data.killingBlow=1;p.savingThrow=()=>assert.fail('Already lethal');await post(actor,target,{},p);
});
test('ranged ineffective-weapon warning uses captured total/hand and emits only once for creature or other objects',async()=>{
  const {actor,target,data,p}=fixture();data.damage.fill(0);data.weaponAttackType=2;p.creature=()=>null;p.weaponEffective=(o,id,hand)=>{assert.equal(hand,1);return 0;};
  await post(actor,target,{},p);await post(actor,target,{},p);assert.deepEqual(data.lists[3],[{type:3,integers:[117]}]);assert.equal(actor.combatRound.weaponSucks,1);
});
test('safe projectile writes canonical ammunition ID and freezes metadata without strings/lists before queuing self event21',async()=>{
  const {actor,data}=fixture(),weapon={id:3},ammo={id:0x80000004},events=[];data.strings[0]='owned';data.lists[0].push({type:1});data.targetId=0x80000005;
  const p={aiMaster:()=> 'AI',equippedItem:(o,slot)=>slot===16?weapon:ammo,baseItem:()=>8,baseItemInfo:()=>null,enqueue:(...args)=>events.push(args)};
  await projectile(actor,123,0,p);assert.equal(data.raw.getUint32(0x8c,true),ammo.id);
  const [ai,id,caller,target,delay,copy]=events[0];assert.deepEqual([ai,id,caller,target,delay],['AI',21,1,1,123]);assert.equal(copy.targetId,0x80000005);
  assert.equal(copy.raw.getUint32(0x8c,true),ammo.id);assert.deepEqual(copy.strings,['','']);assert.deepEqual(copy.lists,[[],[],[],[]]);
  data.targetId=7;assert.equal(copy.targetId,0x80000005);
  let warning;p.equippedItem=(o,slot)=>slot===16?weapon:null;p.warning=m=>warning=m;await projectile(actor,0,0,p);
  assert.ok(warning);assert.equal(data.raw.getUint32(0x8c,true),0x7f000000);
});
