import test from 'node:test';
import assert from 'node:assert/strict';
import { advanceExcitedDuration, advanceCombatStateTimers } from '../src/combat_frame.js';
import { createCombatRound } from '../src/combat_round.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

const actor=()=>({nativeField700:1,nativeField704:8000,nativeAttackField748:6000,
  nativeField750:0,nativeField754:0,nativeMovementField74c:1000,excitedDuration:8000,
  animationState:1,combatRound:createCombatRound(),nativeAttackTarget724:7,attackActionTargetId:8});

test('native combat timeout expires on the frame after crossing zero, clearing round records while retaining other target references',async()=>{
  const a=actor(),r=a.combatRound;r.actions.push({time:4});r.attacks[0].result=3;
  await advanceCombatStateTimers(a,8000,{});
  assert.equal(a.nativeField700,1);assert.equal(a.nativeField704,0);assert.equal(r.attacks[0].result,3);
  await advanceCombatStateTimers(a,0,{});
  assert.equal(a.nativeField700,0);assert.equal(a.initiativePending,1);assert.equal(a.nativeField744,100);
  assert.equal(a.nativeAttackTarget724,invalid);assert.equal(a.attackActionTargetId,8);
  assert.equal(r.actions.length,0);assert.equal(r.attacks[0].result,0);
});

test('native NPC combat heartbeat checks before subtraction, resets after direct script, and skips PC/familiar and dead actors',async()=>{
  const a=actor(),trace=[];a.nativeAttackField748=100;
  const p={dead:()=>0,heartbeat:o=>{trace.push(o.nativeField704);o.nativeAttackField748=123;}};
  await advanceCombatStateTimers(a,100,p);assert.deepEqual(trace,[]);assert.equal(a.nativeAttackField748,0);
  await advanceCombatStateTimers(a,20,p);assert.deepEqual(trace,[7880]);assert.equal(a.nativeAttackField748,5980);
  for(const flag of ['isPC','isPossessedFamiliar']){
    const o=actor();o[flag]=true;o.nativeAttackField748=0;await advanceCombatStateTimers(o,20,{});
    assert.equal(o.nativeAttackField748,0);
  }
  const dead=actor();dead.nativeAttackField748=0;
  await advanceCombatStateTimers(dead,20,{dead:()=>1,heartbeat:()=>assert.fail('Dead actor ran heartbeat')});
  assert.equal(dead.nativeAttackField748,5980);
});

test('native movement opportunity cadence waits an extra frame for suppression expiry and uses raw animation4/86/87',async()=>{
  const a=actor(),trace=[];a.animationState=4;a.nativeMovementField74c=0;a.nativeField750=1;a.nativeField754=1500;
  const p={hasFeat:()=>0,opportunity:(...args)=>trace.push(args.slice(1))};
  await advanceCombatStateTimers(a,1500,p);
  assert.equal(a.nativeField750,1);assert.equal(a.nativeField754,0);assert.deepEqual(trace,[]);
  assert.equal(a.nativeMovementField74c,1500);
  await advanceCombatStateTimers(a,1500,p);
  assert.equal(a.nativeField750,0);assert.equal(a.nativeMovementField74c,0);assert.deepEqual(trace,[]);
  await advanceCombatStateTimers(a,0,p);assert.deepEqual(trace,[[invalid,1]]);
  assert.equal(a.nativeMovementField74c,1500);
  for(const animation of [4,86,87]){
    a.animationState=animation;a.nativeMovementField74c=0;await advanceCombatStateTimers(a,0,p);
  }
  assert.equal(trace.length,4);a.animationState=9;a.nativeMovementField74c=2;
  await advanceCombatStateTimers(a,100,p);assert.equal(a.nativeMovementField74c,2);
});

test('native feat392 prevents movement provocation only while combat state is nonzero, and nonzero suppression flags avoid feat queries',async()=>{
  const a=actor(),trace=[];a.animationState=86;a.nativeMovementField74c=0;
  const p={hasFeat:()=>1,opportunity:()=>trace.push('opportunity')};
  await advanceCombatStateTimers(a,0,p);assert.deepEqual(trace,[]);
  a.nativeField700=0;a.nativeMovementField74c=0;await advanceCombatStateTimers(a,0,p);
  assert.deepEqual(trace,['opportunity']);
  a.nativeField750=2;a.nativeMovementField74c=0;
  await advanceCombatStateTimers(a,0,{hasFeat:()=>assert.fail('Suppressed actor queried feat')});
  assert.equal(a.nativeField750,2);assert.equal(a.nativeMovementField74c,1500);
});

test('native excited duration uses unsigned comparison, expires immediately at equality and commits zero before notification',async()=>{
  const a=actor(),trace=[];a.excitedDuration=0xffffffff;
  const p={expired:o=>trace.push(o.excitedDuration)};
  await advanceExcitedDuration(a,1,p);assert.equal(a.excitedDuration,0xfffffffe);
  a.excitedDuration=20;await advanceExcitedDuration(a,20,p);
  assert.deepEqual(trace,[0]);await advanceExcitedDuration(a,20,{});
});

test('missing live movement-opportunity work fails without claiming its timer reset or attack completion',async()=>{
  const a=actor();a.animationState=87;a.nativeMovementField74c=0;
  await assert.rejects(advanceCombatStateTimers(a,20,{hasFeat:()=>0}),/opportunity/);
  assert.equal(a.nativeMovementField74c,0);
});
