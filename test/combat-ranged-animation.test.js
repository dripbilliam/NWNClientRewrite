import test from 'node:test';
import assert from 'node:assert/strict';
import {createCombatRound,addReaction} from '../src/combat_round.js';
import {checkActionLengthAtTime as check} from '../src/combat_timing.js';
import {resolveRangedAnimations as animate} from '../src/combat_ranged_animation.js';

function fixture(base=8){
  const actor={id:1,position:[0,0,0],combatRound:createCombatRound(),orientation:[1,0,-0]},target={id:2,position:[55,0,0],combatRound:createCombatRound()};
  Object.assign(target.combatRound,{started:true,length:6000,timer:100});
  const data=actor.combatRound.attacks[0],trace=[];data.result=1;
  const p={attackWeapon:()=>({base}),baseItem:w=>w.base,position:o=>o.position,creature:o=>o,
    equippedItem:()=>null,weaponType:()=>7,random:{next:()=>{trace.push('draw');return 3;}},orientation:o=>o.orientation,
    setOrientation:(o,v)=>{trace.push(['orient',v]);o.orientation=v;}};
  return{actor,target,data,p,trace};
}
test('future reaction checks retain exact-one gates, pause ownership, signed overflow and round capacity',()=>{
  const r=createCombatRound();Object.assign(r,{started:true,paused:true,pausedBy:2,pauseTimer:1000,timer:100,length:1500});
  assert.equal(check(r,1,200,999),false);assert.equal(check(r,1,200,1000),true);
  assert.equal(check(r,2,200,0),true);assert.equal(check(r,2,1401,1000),false);
  r.paused=2;r.started=2;assert.equal(check(r,1,2147483647,0),true);
  r.paused=true;r.timer=2147483600;assert.equal(check(r,1,0,100),false);
});
test('AddReaction keeps idle rounds unchanged, adds timer with DWORD wrap and stable equal-time ordering',()=>{
  const r=createCombatRound();addReaction(r,0,100);assert.equal(r.actions.length,0);
  Object.assign(r,{started:2,timer:2147483647});addReaction(r,1,100);addReaction(r,1,200);
  assert.deepEqual(r.actions.map(a=>[a.nativeActionType,a.time,a.duration,a.targetId]),[[3,-2147483648,100,0x7f000000],[3,-2147483648,200,0x7f000000]]);
});
test('arrow hit replaces endpoint, uses 55 speed and rescales scheduled defender reaction with its round',async()=>{
  const {actor,target,data,p}=fixture();await animate(actor,target,500,p);
  assert.deepEqual([data.animationDuration,data.reactionDelay,data.reactionAnimation,data.attackDuration],[500,1000,14,500]);
  assert.equal(data.raw.getFloat32(0x80,true),55);
  assert.equal(target.combatRound.actions[0].nativeActionType,3);assert.equal(target.combatRound.actions[0].time,1008);
  assert.equal(target.combatRound.length,5500);
});
test('thrown hit uses 40 speed and non-creatures retain flight without adding reactions',async()=>{
  const {actor,target,data,p}=fixture(59);target.position=[0,0,40];p.creature=()=>null;
  await animate(actor,target,70000,p);assert.equal(data.animationDuration,4464);assert.equal(data.reactionDelay,1000);assert.equal(data.attackDuration,0);
  assert.equal(target.combatRound.actions.length,0);
});
test('no weapon zeros delay while preserving damaging reaction metadata and avoids spatial providers',async()=>{
  const {actor,target,data,p}=fixture();p.attackWeapon=()=>null;p.position=()=>assert.fail('No position read');data.reactionDelay=8;
  await animate(actor,target,500,p);assert.equal(data.reactionDelay,0);assert.equal(data.reactionAnimation,14);
});
test('shield miss-to-block retains missed endpoint, shared draw and negative attacker orientation including signed zero',async()=>{
  const {actor,target,data,p,trace}=fixture();data.result=4;data.raw.setFloat32(0x80,55,true);p.equippedItem=()=>({});
  await animate(actor,target,500,p);assert.deepEqual([data.result,data.reactionAnimation,data.reactionDelay,data.attackDuration],[2,12,1000,500]);
  assert.equal(trace[0],'draw');assert.deepEqual(target.orientation,[-1,-0,0]);
  assert.equal(target.combatRound.actions[0].time,779);
});
test('failed shield roll or second capacity check preserves original miss reaction instead of forcing idle',async()=>{
  for(const veto of ['roll','capacity']){
    const {actor,target,data,p}=fixture();data.result=4;data.reactionAnimation=11;data.raw.setFloat32(0x80,55,true);p.equippedItem=()=>({});
    if(veto==='roll')p.random.next=()=>1;else target.combatRound.length=800;
    await animate(actor,target,500,p);assert.equal(data.result,4);assert.equal(data.reactionAnimation,11);assert.equal(target.combatRound.actions.length,0);
  }
});
test('initial reaction veto or missing shield sets idle without consuming any random draw',async()=>{
  for(const veto of ['pause','shield']){
    const {actor,target,data,p}=fixture();data.result=4;data.raw.setFloat32(0x80,55,true);p.random.next=()=>assert.fail('No draw');
    if(veto==='pause')Object.assign(target.combatRound,{paused:true,pausedBy:3,pauseTimer:2000});
    await animate(actor,target,500,p);assert.equal(data.reactionAnimation,1);assert.equal(data.reactionDelay,1000);
  }
});
