import test from 'node:test';
import assert from 'node:assert/strict';
import { setCombatMode,setCombatActivity } from '../src/combat_mode.js';

function fixture(){
  const actor={combatMode:0,pendingCombatMode:0,combatRound:{started:false},activities:0,lockedActivities:0,effects:[]},trace=[],items=new Map();
  const p={item:(o,slot)=>{trace.push(['item',slot]);return items.get(slot)??null;},ranged:i=>i.ranged??0,
    classIndex:()=>255,monkWeapon:i=>i.monk??0,relativeSize:()=>0,hasFeat:()=>0,
    feedback:(o,n)=>trace.push(['feedback',n]),warning:m=>trace.push(['warning',m]),remainingUses:()=>1,
    decrementUses:(o,n)=>trace.push(['decrement',n]),activity:(o,mask,value)=>setCombatActivity(o,mask,value,{
      defensiveCasting:(o,v)=>{o.defensiveCasting=Number(v);trace.push(['casting',v]);},
      applyStance:()=>trace.push('stance+'),removeStance:(o,id)=>trace.push(['stance-',id])})};
  return{actor,trace,items,p};
}
test('native started exact-one defers mode byte without equipment query; forced switches immediately',async()=>{
  const {actor,p,trace}=fixture();actor.combatRound.started=true;
  await setCombatMode(actor,0x109,0,p);assert.equal(actor.pendingCombatMode,9);assert.equal(actor.combatMode,0);assert.deepEqual(trace,[]);
  await setCombatMode(actor,9,1,p);assert.equal(actor.combatMode,9);assert.equal(actor.activities,0x40000);assert.equal(actor.defensiveCasting,1);
});
test('ranged Parry rejection preserves old mode and activity while emitting native feedback188',async()=>{
  const {actor,p,trace,items}=fixture();actor.combatMode=9;actor.activities=0x40000;items.set(16,{ranged:1});
  await setCombatMode(actor,1,1,p);assert.equal(actor.combatMode,9);assert.equal(actor.activities,0x40000);
  assert.deepEqual(trace,[['item',16],['feedback',188]]);
});
test('forced same-mode refresh clears then re-enables and observes defensive casting side effects',async()=>{
  const {actor,p,trace}=fixture();actor.combatMode=9;actor.activities=0x40000;
  await setCombatMode(actor,9,1,p);
  assert.deepEqual(trace,[['item',16],['casting',false],['casting',true]]);assert.equal(actor.combatMode,9);
});
test('enabling a combat bit clears other unlocked combat bits in native order, preserving locked bits',async()=>{
  const {actor,p,trace}=fixture();actor.activities=0x400|0x40000|0x100000;actor.lockedActivities=0x400;actor.effects=[{type:95,id:'stance'}];
  await setCombatMode(actor,1,1,p);
  assert.deepEqual(trace,[['item',16],['casting',false],['stance-','stance']]);assert.equal(actor.activities,0x400|0x1000);
});
test('Flurry validates either native class slot and monk weapons or conditional feats; Rapid Shot rejects crossbows',async()=>{
  const {actor,p,items,trace}=fixture();items.set(16,{data:{BaseItem:1},monk:1});items.set(32,{monk:0});
  p.classIndex=(o,id)=>id===40?1:255;p.relativeSize=()=>-1;p.hasFeat=(o,id)=>Number(id===866);
  await setCombatMode(actor,5,1,p);assert.equal(actor.combatMode,5);
  items.set(16,{data:{BaseItem:6},ranged:1});await setCombatMode(actor,6,1,p);
  assert.equal(actor.combatMode,5);assert.deepEqual(trace.at(-1),['feedback',188]);
  items.set(16,{data:{BaseItem:8},ranged:1});await setCombatMode(actor,6,1,p);assert.equal(actor.combatMode,6);
});
test('no stance uses still clears the old mode before feedback199; successful activation consumes feat947',async()=>{
  const {actor,p,trace}=fixture();actor.combatMode=9;actor.activities=0x40000;p.remainingUses=()=>0;
  await setCombatMode(actor,11,1,p);assert.equal(actor.combatMode,0);assert.equal(actor.activities,0);
  assert.deepEqual(trace,[['item',16],['casting',false],['feedback',199]]);
  p.remainingUses=()=>1;trace.length=0;await setCombatMode(actor,11,1,p);
  assert.deepEqual(trace,[['item',16],'stance+',['decrement',947]]);assert.equal(actor.combatMode,11);
});
test('locked selected activity changes stored mode without enabling its bit; unknown bytes warn and remain stored',async()=>{
  const {actor,p,trace}=fixture();actor.lockedActivities=0x1000;
  await setCombatMode(actor,1,1,p);assert.equal(actor.combatMode,1);assert.equal(actor.activities,0);
  await setCombatMode(actor,0xff,1,p);assert.equal(actor.combatMode,255);assert.equal(trace.filter(a=>a[0]==='warning').length,1);
});
