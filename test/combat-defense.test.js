import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound } from '../src/combat_round.js';
import { defensiveChances,resolveDefensiveEffects } from '../src/combat_defense.js';
const effect=(type,integers)=>({type,integers});
function fixture(rolls=[]) {
  const actor={id:1,objectType:5,visionFlags:0,creatureData:{Race:6,GoodEvil:50,LawfulChaotic:50},feats:[],effects:[],equipment:new Map()},target={id:2,objectType:5,visionFlags:0,feats:[],effects:[],combatRound:createCombatRound(),equipment:new Map()};
  const data=createCombatRound().attacks[0],trace=[];
  const p={effects:o=>o.effects,hasFeat:(o,f)=>Number(o.feats.includes(f)),flatFooted:()=>0,
    equippedItem:(o,slot)=>o.equipment.get(slot)??null,rangedWeapon:i=>i.ranged,relativeWeaponSize:()=>0,
    savingThrow:(...args)=>{trace.push(['save',args.slice(1)]);return 1},random:{dice:(n,s)=>{trace.push(['die',n,s]);assert.ok(rolls.length);return rolls.shift()}}};
  return{actor,target,data,p,trace};
}
test('miss chance sources obey defender blindness and exact ranged/melee conditions before taking the maximum',async()=>{
  const{actor,target,data,p}=fixture();actor.effects=[effect(75,[40,1]),effect(75,[30,2]),effect(75,[20,3])];
  assert.deepEqual(await defensiveChances(actor,target,data,{},p),{missChance:20,concealment:0});
  target.visionFlags=2;assert.equal((await defensiveChances(actor,target,data,{},p)).missChance,40);
  target.visionFlags=0;data.ranged=2;assert.equal((await defensiveChances(actor,target,data,{},p)).missChance,30);
});
test('invisibility subtype and perception masks differ; conditional concealment uses the attacker race/alignment',async()=>{
  const{actor,target,data,p}=fixture();target.effects=[effect(47,[2,28,0,0]),effect(76,[70,6,1,1,0])];
  assert.equal((await defensiveChances(actor,target,data,{},p)).concealment,70);
  target.effects=[effect(47,[2,28,0,0])];actor.visionFlags=1;
  assert.equal((await defensiveChances(actor,target,data,{},p)).concealment,50);
  target.effects=[effect(47,[1,28,0,0])];assert.equal((await defensiveChances(actor,target,data,{},p)).concealment,0);
});
test('only highest self-concealment feat applies, even if a lower tier would give a larger overridden rule',async()=>{
  const{actor,target,data,p}=fixture();target.feats=[748,752];assert.equal((await defensiveChances(actor,target,data,{},p)).concealment,50);
});
test('equal chances use miss-chance result, strict equality succeeds and Blind Fight rerolls only the failed chance',async()=>{
  let{actor,target,data,p,trace}=fixture([20]);actor.effects=[effect(75,[20,0])];target.effects=[effect(76,[20,28,0,0,0])];
  assert.equal(await resolveDefensiveEffects(actor,target,0,data,{},p),0);assert.equal(trace.length,1);
  ({actor,target,data,p,trace}=fixture([19,20]));actor.feats=[408];actor.effects=[effect(75,[20,0])];
  assert.equal(await resolveDefensiveEffects(actor,target,0,data,{},p),0);assert.equal(trace.length,2);
  ({actor,target,data,p,trace}=fixture([19]));actor.effects=[effect(75,[20,0])];target.effects=[effect(76,[20,28,0,0,0])];
  assert.equal(await resolveDefensiveEffects(actor,target,0,data,{},p),1);assert.equal(data.result,9);assert.equal(data.concealmentChance,20);assert.equal(data.missedBy,1);
});
test('concealment can end even an attack below AC, and records the chance byte',async()=>{
  const{actor,target,data,p}=fixture([1]);target.effects=[effect(76,[256+50,28,0,0,0])];
  assert.equal(await resolveDefensiveEffects(actor,target,0,data,{},p),1);assert.equal(data.result,8);assert.equal(data.concealmentChance,50);
});
test('Deflect Arrows consumes its once-per-round gate before saving, and a successful save still requires an attacker weapon',async()=>{
  const{actor,target,data,p,trace}=fixture();data.ranged=1;target.combatRound.deflectArrow=1;target.feats=[8];actor.equipment.set(16,{ranged:1});
  assert.equal(await resolveDefensiveEffects(actor,target,1,data,{},p),1);assert.equal(data.result,2);assert.equal(data.deflected,1);assert.equal(target.combatRound.deflectArrow,0);
  assert.deepEqual(trace,[['save',[2,20,0,1,1,8,1]]]);
  target.combatRound.deflectArrow=1;actor.equipment.clear();data.deflected=0;
  assert.equal(await resolveDefensiveEffects(actor,target,1,data,{},p),0);assert.equal(target.combatRound.deflectArrow,0);assert.equal(data.deflected,0);
});
test('Deflect Arrows allows a bare main hand even with an occupied offhand, but rejects a ranged or large main weapon',async()=>{
  const{actor,target,data,p}=fixture();data.ranged=1;target.feats=[8];actor.equipment.set(16,{ranged:1});target.equipment.set(32,{});
  target.combatRound.deflectArrow=1;assert.equal(await resolveDefensiveEffects(actor,target,1,data,{},p),1);
  target.equipment.set(16,{ranged:1});target.equipment.delete(32);target.combatRound.deflectArrow=1;
  assert.equal(await resolveDefensiveEffects(actor,target,1,data,{},p),0);assert.equal(target.combatRound.deflectArrow,1);
  target.equipment.set(16,{ranged:0});p.relativeWeaponSize=()=>1;assert.equal(await resolveDefensiveEffects(actor,target,1,data,{},p),0);
});
test('deflect save must return exactly one; natural misses and noncreatures never consume it',async()=>{
  const{actor,target,data,p,trace}=fixture();data.ranged=1;target.feats=[8];target.combatRound.deflectArrow=1;actor.equipment.set(16,{});p.savingThrow=()=>2;
  assert.equal(await resolveDefensiveEffects(actor,target,1,data,{},p),0);assert.equal(target.combatRound.deflectArrow,0);
  target.combatRound.deflectArrow=1;assert.equal(await resolveDefensiveEffects(actor,target,0,data,{},p),0);assert.equal(target.combatRound.deflectArrow,1);
  target.objectType=10;assert.equal(await resolveDefensiveEffects(actor,target,1,data,{},{}),0);assert.equal(trace.length,0);
});
