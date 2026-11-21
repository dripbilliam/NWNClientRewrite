import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound } from '../src/combat_round.js';
import { resolveStrikeRoll } from '../src/combat_roll_resolution.js';
import { resolveSituationalModifiers, resolveCachedSpecialAttacks } from '../src/combat_strike_preparation.js';

function fixture(rolls=[12]) {
  const actor={id:1,objectType:5,position:[0,0,0],combatRound:createCombatRound()},target={id:2,objectType:5,position:[0,0,0],stats:{level:1},combatRound:createCombatRound(),combatMode:0,creatureState:0};
  const data=actor.combatRound.attacks[0],trace=[];
  const p={offhand:()=>0,creature:o=>o.objectType===5?o:null,
    random:{dice:(n,s)=>{trace.push(['die',n,s]);assert.ok(rolls.length);return rolls.shift()}},
    attackModifier:()=>{trace.push('modifier');return 2},armorClass:()=>{trace.push('AC');return 10},
    sneak:()=>trace.push('sneak'),death:()=>trace.push('death'),defensive:()=>{trace.push('defense');return 0},
    rangedEquipped:()=>0,skillRank:()=>{trace.push('skill');return 5},parryAttack:()=>trace.push('riposte'),parryIndex:()=>trace.push('index'),
    criticalThreat:()=>{trace.push('threat');return 20},difficulty:()=>{trace.push('difficulty');return 0},
    effectImmunity:()=>{trace.push('immunity');return 0},message:(type,fields)=>({type,...fields})};
  return {actor,target,data,p,trace};
}
test('strike roll writes caller-owned bytes after native-order modifier, AC, sneak and death queries',async()=>{
  const {actor,target,data,p,trace}=fixture();await resolveStrikeRoll(actor,target,{},p);
  assert.deepEqual(trace,[['die',1,20],'modifier','AC','sneak','death','defense','threat']);
  assert.equal(data.result,1);assert.equal(data.roll,12);assert.equal(data.raw.getInt32(0x10,true),2);
});
test('coup de grace still consumes the first d20 and queries modifiers, then skips defenses and confirmation',async()=>{
  const {actor,target,data,p,trace}=fixture([1]);data.coupDeGrace=1;await resolveStrikeRoll(actor,target,{},p);
  assert.equal(data.roll,20);assert.equal(data.result,7);assert.deepEqual(trace,[['die',1,20],'modifier','AC','sneak','death']);
});
test('defensive handler may finish the record only on an exact-one return',async()=>{
  const {actor,target,data,p}=fixture();p.defensive=(a,t,h,d)=>{assert.equal(h,1);d.result=6;return 1};
  await resolveStrikeRoll(actor,target,{},p);assert.equal(data.result,6);
});
test('natural one misses only after the parry chance and uses the one-point miss byte',async()=>{
  const {actor,target,data,p,trace}=fixture([1,1]);target.combatMode=1;target.combatRound.parryActions=1;p.skillRank=()=>-10;
  await resolveStrikeRoll(actor,target,{},p);assert.equal(data.result,4);assert.equal(data.missedBy,1);assert.ok(trace.includes('index'));assert.equal(target.combatRound.parryActions,0);
});
test('successful parry consumes one action, adds riposte only at the ruleset difference and skips threat roll',async()=>{
  const {actor,target,data,p,trace}=fixture([5,15]);target.combatMode=1;target.combatRound.parryActions=2;
  await resolveStrikeRoll(actor,target,{},p);assert.equal(data.result,2);assert.equal(target.combatRound.parryActions,1);assert.ok(trace.includes('riposte'));assert.ok(!trace.includes('threat'));
});
test('natural twenty skips parry; confirmation has no special natural-one success/failure rule',async()=>{
  const {actor,target,data,p,trace}=fixture([20,1]);target.combatMode=1;target.combatRound.parryActions=2;p.attackModifier=()=>20;
  await resolveStrikeRoll(actor,target,{},p);assert.equal(data.result,3);assert.equal(data.confirmation,1);assert.equal(data.threatened,1);assert.equal(target.combatRound.parryActions,2);assert.ok(!trace.includes('skill'));
});
test('easy NPC critical versus a PC skips the immunity query; immunity instead preserves hit plus native type-zero feedback',async()=>{
  let {actor,target,data,p,trace}=fixture([20,20]);target.isPC=true;p.difficulty=()=>1;
  await resolveStrikeRoll(actor,target,{},p);assert.equal(data.result,1);assert.ok(!trace.includes('immunity'));
  ({actor,target,data,p,trace}=fixture([20,20]));p.effectImmunity=()=>1;await resolveStrikeRoll(actor,target,{},p);
  assert.equal(data.result,1);assert.deepEqual(data.lists[3],[{type:0,objects:[2],integers:[126]}]);
});
test('noncreature targets use AC zero, skip creature history and can still receive critical results',async()=>{
  const {actor,target,data,p,trace}=fixture([20,1]);target.objectType=10;
  await resolveStrikeRoll(actor,target,{},p);assert.equal(data.result,3);assert.ok(!trace.includes('AC'));assert.ok(!trace.includes('sneak'));assert.ok(!trace.includes('difficulty'));
});
test('missing roll providers refuse before consuming RNG or changing storage',async()=>{
  const {actor,target,data,p,trace}=fixture();delete p.death;await assert.rejects(resolveStrikeRoll(actor,target,{},p),/death/);
  assert.deepEqual(trace,[]);assert.equal(data.roll,0);assert.equal(data.result,0);
});
test('ranged coup-de-grace boundary includes equality, full height and native byte status/level wrap',()=>{
  const {actor,target,data}=fixture();data.ranged=1;target.creatureState=8;target.position=[10,0,0];
  resolveSituationalModifiers(actor,target,data,{});assert.equal(data.coupDeGrace,1);
  data.coupDeGrace=0;target.position=[10,1,0];resolveSituationalModifiers(actor,target,data,{});assert.equal(data.coupDeGrace,0);
  target.position=[0,0,0];target.creatureState=264;target.stats.level=260;resolveSituationalModifiers(actor,target,data,{});assert.equal(data.coupDeGrace,1);
  data.coupDeGrace=0;target.isPC=true;resolveSituationalModifiers(actor,target,data,{});assert.equal(data.coupDeGrace,0);
});
test('cached special queues fill the first unused future slot and consume one paired ushort entry',()=>{
  const {actor}=fixture(),r=actor.combatRound;r.onhandAttacks=3;r.specialAttacks.push(65000,9);r.specialAttackParameters.push(65536+4,7);r.attacks[0].attackType=1;
  resolveCachedSpecialAttacks(actor);assert.equal(r.attacks[1].attackType,65000);assert.equal(r.attacks[1].specialParameter,4);assert.deepEqual(r.specialAttacks,[9]);assert.deepEqual(r.specialAttackParameters,[7]);assert.equal(r.currentAttack,0);
  resolveCachedSpecialAttacks(actor);assert.equal(r.attacks[2].attackType,9);assert.equal(r.attacks[2].specialParameter,7);
});
test('full attack records retain pending specials; unavailable paired head refuses without consuming either queue',()=>{
  const {actor}=fixture(),r=actor.combatRound;r.specialAttacks.push(9);r.attacks[0].attackType=1;
  resolveCachedSpecialAttacks(actor);assert.deepEqual(r.specialAttacks,[9]);r.attacks[0].attackType=0;
  assert.throws(()=>resolveCachedSpecialAttacks(actor),/head data/);assert.deepEqual(r.specialAttacks,[9]);assert.equal(r.attacks[0].attackType,0);
});
