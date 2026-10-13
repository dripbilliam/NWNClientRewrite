import test from 'node:test';
import assert from 'node:assert/strict';
import { invisibleVersus } from '../src/combat_visibility.js';
import { getBlind } from '../src/perception.js';
import { createCombatRound, addParryAttack, addParryIndex } from '../src/combat_round.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture(type=47,integers=[1,28,0,0]){
  const actor={id:1,objectType:5,position:[0,0,0]},viewer={id:2,objectType:5,position:[0,0,0],visionFlags:0,blindSightRange:0,
    creatureData:{Race:6,GoodEvil:70,LawfulChaotic:30}},effects=[{type,integers}],trace=[];
  const p={creature:o=>o.objectType===5?o:null,effects:()=>effects,index:()=>0,
    reaction:()=>2,visibility:()=>null,savingThrow:(...args)=>{trace.push(['save',...args.slice(1)]);return 1;},
    addVisibility:(o,...args)=>trace.push(['visibility',o.id,...args]),pacify:(o,id)=>trace.push(['pacify',o.id,id])};
  return{actor,viewer,effects,trace,p,query:feedback=>invisibleVersus(actor,viewer,feedback??0,p)};
}

test('vision blindness and perception-update bytes remain independent, retaining vision overrides',()=>{
  const o={visionFlags:0,perceptionUpdateFlags:0x10};assert.equal(getBlind(o),0);
  o.visionFlags=0x10;o.perceptionUpdateFlags=0;assert.equal(getBlind(o),1);
  for(const [flags,blind] of [[8,1],[10,0],[0x14,0],[0x30,0]]){o.visionFlags=flags;assert.equal(getBlind(o),blind);}
});

test('invisibility matches observer race and alignment before evaluating native vision masks',async()=>{
  for(const [conditions,expected] of [[[1,28,0,0],1],[[1,6,3,4],1],[[1,5,0,0],0],[[1,6,2,4],0],[[1,6,3,5],0]]){
    const f=fixture(47,conditions);assert.equal(await f.query(),expected);assert.deepEqual(f.trace,[]);
  }
  for(const [subtype,flags,expected] of [[1,2,1],[1,1,0],[4,4,0],[2,1,1],[2,2,0],[2,4,0],[3,7,1]]){
    const f=fixture(47,[subtype,28,0,0]);f.viewer.visionFlags=flags;assert.equal(await f.query(),expected);
  }
});

test('blindsight uses inclusive float32 three-dimensional range; other vision cannot reveal unknown subtypes',async()=>{
  const f=fixture(47,[3,28,0,0]);f.viewer.visionFlags=0x20;f.viewer.blindSightRange=5;
  f.viewer.position=[3,4,0];assert.equal(await f.query(),0);
  f.viewer.position=[3,4.001,0];assert.equal(await f.query(),1);
  f.effects.push({type:75,integers:[]});f.effects[0].integers[1]=5;
  assert.equal(await f.query(),0); // Stops at >63, without requiring other providers.
});

test('Sanctuary consumes no save for friendly observers or existing nonzero cache states',async()=>{
  const f=fixture(63,[0,28,0,0,17,1]);f.p.reaction=()=>1;assert.equal(await f.query(),0);
  f.p.reaction=()=>2;
  for(const [state,flags,expected] of [[4,0,1],[4,4,0],[8,4,1],[12,0,0]]){
    f.p.visibility=()=>state;f.viewer.visionFlags=flags;assert.equal(await f.query(),expected);
  }
  assert.deepEqual(f.trace,[]);
});

test('Sanctuary successful native save stores state2 and returns invisible; failed save pacifies before state1',async()=>{
  const f=fixture(63,[0,28,0,0,65553,1]);assert.equal(await f.query(1),1);
  assert.deepEqual(f.trace,[['save',3,17,0,invalid,1,0,0],['visibility',2,1,0,0,2,0]]);
  f.trace.length=0;f.p.savingThrow=()=>0;assert.equal(await f.query(),0);
  assert.deepEqual(f.trace,[['pacify',1,2],['visibility',2,1,0,0,1,0]]);
  f.trace.length=0;f.effects[0].integers[5]=0;delete f.p.savingThrow;assert.equal(await f.query(),0);
  assert.deepEqual(f.trace,[['pacify',1,2],['visibility',2,1,0,0,1,0]]);
});

test('invisibility rejects missing conditional implementations and ignores noncreature observers',async()=>{
  const f=fixture(63,[0,28,0,0,17,0]);delete f.p.pacify;await assert.rejects(f.query(),/pacify/);assert.deepEqual(f.trace,[]);
  f.viewer.objectType=9;assert.equal(await f.query(),0);
});

test('Parry riposte captures pre-compression head time and never adds an opportunity bonus attack',()=>{
  const r=createCombatRound();r.started=true;r.length=6000;r.timer=1000;r.onhandAttacks=2;
  const head={time:3000};r.actions=[head];addParryAttack(r,0x80000001);
  assert.equal(r.length,5200);assert.equal(head.time,2600);assert.equal(r.actions[0].time,2999);
  assert.equal(r.actions[0].duration,800);assert.equal(r.actions[0].targetId,0x80000001);
  assert.equal(r.additionalAttacks,0);assert.deepEqual(r.specialAttacks,[65003]);assert.deepEqual(r.specialAttackParameters,[0]);
});

test('Parry skip queues a time-zero type8 action only in started rounds, leaving consumption to AI',()=>{
  const r=createCombatRound();addParryIndex(r);assert.equal(r.actions.length,0);
  r.started=true;r.actions=[{time:0},{time:100}];addParryIndex(r);
  assert.equal(r.actions[1].nativeActionType,8);assert.equal(r.currentAttack,0);assert.equal(r.parryIndex,0);
  assert.equal(r.actions[1].targetId,invalid);assert.equal(r.actions[1].followTarget,1);
});
