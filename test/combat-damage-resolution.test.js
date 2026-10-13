import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound } from '../src/combat_round.js';
import { createAttackData, setBaseAttackDamage, totalAttackDamage } from '../src/combat_attack_data.js';
import { resolveStrikeDamage, resolvePostStrikeDamage } from '../src/combat_damage_resolution.js';

function fixture() {
  const actor = { id:1, objectType:5, combatRound:createCombatRound(), feats:[], level:20 }, target = { id:2, objectType:5, combatRound:createCombatRound(), feats:[], hp:30, plot:false, immortal:0, nativeField700:1, creatureState:0, position:[1,2,3], level:5 };
  const data = actor.combatRound.attacks[0];data.result=1;data.weaponAttackType=7;const trace=[];
  const p = { offhand:()=>0, damageRoll:(a,t,flags)=>{trace.push(['roll',flags]);return 8;}, creature:o=>o.objectType===5?o:null,
    hitPoints:o=>o.hp,hasFeat:(o,f)=>Number(o.feats.includes(f)), flatFooted:()=>0, remainingUses:()=>1,
    decrementUses:(a,f)=>trace.push(['consume',a.id,f]),savingThrow:(...args)=>{trace.push(['save',...args.map(a=>a?.id??a)]);return 1},
    classLevel:()=>3,abilityModifier:()=>2,deathAttack:(a,t,d)=>trace.push(['deathAttack',d]),rangedEquipped:()=>0,
    position:o=>o.position,energyBonus:()=>trace.push('energy'),onHit:()=>trace.push('onHit'),itemCastSpell:()=>trace.push('cast'),onHitVisuals:()=>trace.push('visual'),
    message:(type,fields)=>({type,...fields}),random:{dice:()=>4},
    immortal:o=>o.immortal,attackWeapon:()=>null,devastatingCritical:()=>0,effectImmunity:()=>0,level:o=>o.level,
    effect:(type,creator,integers,duration)=>({type,creatorId:creator,integers,durationType:duration}),
    unarmed:()=>1,newTarget:()=>null,circleKick:()=>trace.push('circle'),cleave:(r,id,g)=>trace.push(['cleave',id,g]),weaponEffective:()=>1 };
  return {actor,target,data,p,trace,round:actor.combatRound};
}
test('base damage occupies component 12; total getter excludes physical bonuses only when requested', () => {
  const d=createAttackData();d.damage[0]=2;d.damage[1]=3;d.damage[2]=4;d.damage[3]=5;setBaseAttackDamage(d,6);
  assert.equal(d.raw.getInt16(0x2e,true),6);assert.equal(totalAttackDamage(d),20);assert.equal(totalAttackDamage(d,1),11);
  d.damage[3]=-2;setBaseAttackDamage(d,65535);assert.equal(totalAttackDamage(d,1),0);
});
test('ordinary damage stage fills records and calls energy/on-hit/cast/visual in order without touching HP', async () => {
  const {actor,target,data,p,trace}=fixture(); await resolveStrikeDamage(actor,target,{},p);
  assert.equal(data.damage[12],8);assert.equal(target.hp,30);
  assert.deepEqual(trace,[['roll',{offhand:0,critical:0,sneak:0,death:0,maximize:0}],'energy','onHit','cast','visual']);
});
test('maximum-damage feat consumption occurs immediately after the roll, before defender resiliency save', async () => {
  const {actor,target,data,p,trace}=fixture();data.attackType=882;target.hp=6;target.feats=[223];
  await resolveStrikeDamage(actor,target,{},p); assert.equal(data.damage[12],4);
  assert.deepEqual(trace.slice(1,4),[['consume',1,882],['save',2,2,8,0,1,1,223,1],['consume',2,223]]);
  assert.equal(trace[0][1].maximize,1);
});
test('resiliency failed save consumes its charge without halving; flat-footed bypasses save and charge', async () => {
  const {actor,target,data,p,trace}=fixture();target.hp=1;target.feats=[223];p.savingThrow=()=>0;
  await resolveStrikeDamage(actor,target,{},p);assert.equal(data.damage[12],8);assert.ok(trace.some(x=>Array.isArray(x)&&x[0]==='consume'));
  trace.length=0;p.flatFooted=()=>1;await resolveStrikeDamage(actor,target,{},p);assert.equal(data.damage[12],8);assert.ok(!trace.some(x=>Array.isArray(x)&&x[0]==='consume'));
});
test('death attack uses current record zero, inactive target, exact-one death flag, Assassin level and live Int', async () => {
  const {actor,target,data,p,trace}=fixture();data.deathAttack=1;target.nativeField700=0;p.savingThrow=()=>2;
  await resolveStrikeDamage(actor,target,{},p);assert.ok(trace.some(x=>Array.isArray(x)&&x[0]==='deathAttack'&&x[1]===7));
  trace.length=0;target.creatureState=8;await resolveStrikeDamage(actor,target,{},p);assert.ok(!trace.some(x=>Array.isArray(x)&&x[0]==='deathAttack'));
});
test('epic dodge records miss feedback and ranged target position once, skipping all base/on-hit stages', async () => {
  const {actor,target,data,p,trace}=fixture();target.feats=[856];p.rangedEquipped=()=>1;
  await resolveStrikeDamage(actor,target,{},p);assert.equal(data.result,4);assert.equal(data.damage[12],-1);
  assert.equal(target.combatRound.epicDodgeUsed,1);assert.deepEqual(data.lists[3],[{type:2,objects:[2],integers:[234]}]);
  assert.deepEqual([0,1,2].map(i=>data.raw.getFloat32(0x80+i*4,true)),target.position);assert.equal(trace.length,1);
  data.result=1;await resolveStrikeDamage(actor,target,{},p);assert.equal(data.damage[12],8);
});
test('plot exact-one zeros base and skips extras; zero still resolves item casts and visuals without on-hit', async () => {
  const {actor,target,data,p,trace}=fixture();target.plot=true;await resolveStrikeDamage(actor,target,{},p);assert.equal(data.damage[12],0);assert.equal(trace.length,1);
  trace.length=0;target.plot=false;p.damageRoll=()=>0;await resolveStrikeDamage(actor,target,{},p);assert.deepEqual(trace,['energy','cast','visual']);
});
test('missing damage stage provider refuses before the damage roll or record mutation', async () => {
  const {actor,target,data,p,trace}=fixture();delete p.onHit;
  await assert.rejects(resolveStrikeDamage(actor,target,{},p),/onHit/);assert.equal(trace.length,0);assert.equal(data.damage[12],-1);
});
test('killing prediction uses total HP, excludes physical flags, and respects exact-zero plot/immortal', async () => {
  const {actor,target,data,p}=fixture();setBaseAttackDamage(data,10);data.damage[0]=100;target.hp=11;
  await resolvePostStrikeDamage(actor,target,{},p);assert.equal(data.killingBlow,0);
  target.hp=10;await resolvePostStrikeDamage(actor,target,{},p);assert.equal(data.killingBlow,1);
  data.killingBlow=0;target.immortal=1;await resolvePostStrikeDamage(actor,target,{},p);assert.equal(data.killingBlow,0);
});
test('devastating critical save failure changes result and adds death; success adds target-specific feedback', async () => {
  const {actor,target,data,p}=fixture();data.result=3;setBaseAttackDamage(data,1);p.devastatingCritical=()=>1;p.savingThrow=()=>0;
  await resolvePostStrikeDamage(actor,target,{},p);assert.equal(data.result,10);assert.deepEqual(data.lists[0],[{type:19,creatorId:1,integers:[1,1],durationType:0}]);
  data.lists[0].length=0;data.result=3;p.savingThrow=()=>1;await resolvePostStrikeDamage(actor,target,{},p);assert.deepEqual(data.lists[3],[{type:2,objects:[2],integers:[257]}]);
});
test('crippling strike, quivering palm and coup de grace retain distinct effect payloads', async () => {
  const {actor,target,data,p}=fixture();setBaseAttackDamage(data,2);data.sneakAttack=1;actor.feats=[222];data.attackType=296;p.savingThrow=()=>0;
  await resolvePostStrikeDamage(actor,target,{},p);assert.deepEqual(data.lists[0].map(e=>[e.type,e.integers,e.durationType]),[[37,[0,2,4],2],[19,[1,1],0]]);
  data.lists[0].length=0;data.attackType=0;data.sneakAttack=0;data.coupDeGrace=1;await resolvePostStrikeDamage(actor,target,{},p);assert.deepEqual(data.lists[0][0].integers,[0,1]);
});
test('circle kick consumes its own budget before cleave; great cleave bypasses and preserves finite cleave budget', async () => {
  const {actor,target,data,p,round,trace}=fixture();setBaseAttackDamage(data,40);actor.feats=[409,391];p.newTarget=()=>({id:8});
  await resolvePostStrikeDamage(actor,target,{},p);assert.equal(round.circleKickAttacks,0);assert.equal(round.cleaveAttacks,1);assert.equal(round.newAttackTargetId,8);assert.equal(actor.passiveAttack,1);
  assert.deepEqual(trace,['circle',['cleave',8,1]]);
});
test('follow-up special IDs block both chain feats; weapon ineffective warning is once per round on damaging results only', async () => {
  const {actor,target,data,p,round,trace}=fixture();actor.feats=[409,6];p.newTarget=()=>({id:8});p.weaponEffective=()=>0;
  data.attackType=867;data.killingBlow=1;setBaseAttackDamage(data,0);await resolvePostStrikeDamage(actor,target,{},p);
  assert.equal(trace.length,0);assert.equal(round.weaponSucks,1);assert.deepEqual(data.lists[3],[{type:3,integers:[117]}]);
  await resolvePostStrikeDamage(actor,target,{},p);assert.equal(data.lists[3].length,1);
  round.weaponSucks=0;data.result=4;await resolvePostStrikeDamage(actor,target,{},p);assert.equal(round.weaponSucks,0);
});
