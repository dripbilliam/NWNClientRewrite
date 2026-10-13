import test from 'node:test';
import assert from 'node:assert/strict';
import { executeAttackAction } from '../src/combat_attack_action.js';
import { dispatchAttackRoundAction } from '../src/combat_action.js';
import { createCombatRound } from '../src/combat_round.js';
import { createObjectActionState,addObjectAction } from '../src/object_actions.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture(decision='round',valid=true){
  const actor={id:0x80000001,attackActionTargetId:2,attackTargetPosition:[1,2,3],
    objectActionState:createObjectActionState(),combatRound:createCombatRound()},trace=[];
  const node=addObjectAction(actor.objectActionState,12,7,[{type:3,value:0x80000002}]);
  const providers={evaluate:async(o,id)=>{trace.push(['evaluate',id]);return{decision,targetValid:valid};},
    changeTarget:async(o,n,id)=>{trace.push(['target',id]);n.parameterData[0]=id|0;o.attackActionTargetId=id;},
    setAnimation:async(o,state)=>{trace.push(['animation',state]);o.animationState=state;},
    startRound:async(o,id)=>{trace.push(['start',id]);o.combatRound.started=true;},
    dispatch:async(o,id,valid)=>{trace.push(['dispatch',id,valid]);return{};},
    newTarget:async()=>{trace.push(['search']);return null;}};
  return{actor,node,providers,trace};
}
test('attack owner keeps raw high-bit target, starts once, and retains pending in-range attacks',async()=>{
  const f=fixture();assert.equal(await executeAttackAction(f.actor,f.node,f.providers),1);
  assert.deepEqual(f.trace,[['evaluate',0x80000002],['start',0x80000002],['dispatch',0x80000002,true]]);
  assert.deepEqual(f.actor.attackTargetPosition,[0,0,0]);f.trace.length=0;
  assert.equal(await executeAttackAction(f.actor,f.node,f.providers),1);
  assert.deepEqual(f.trace,[['evaluate',0x80000002],['dispatch',0x80000002,true]]);
});
test('actor death/perception clears target without round startup; self target only clears animation',async()=>{
  const f=fixture('clearTarget');assert.equal(await executeAttackAction(f.actor,f.node,f.providers),3);
  assert.equal(f.actor.attackActionTargetId,invalid);assert.equal(f.actor.combatRound.started,false);
  assert.deepEqual(f.actor.attackTargetPosition,[1,2,3]);
  const self=fixture('clearAnimation');self.actor.nativeField700=1;
  assert.equal(await executeAttackAction(self.actor,self.node,self.providers),3);
  assert.equal(self.actor.nativeField700,1);assert.equal(self.actor.attackActionTargetId,2);
  assert.equal(self.actor.animationState,0);assert.equal(self.actor.combatRound.started,false);
});
test('invalid target still starts a round, then selects a replacement and changes the executing parameter',async()=>{
  const f=fixture('round',false);f.providers.newTarget=async()=>({id:0x80000003});
  assert.equal(await executeAttackAction(f.actor,f.node,f.providers),1);
  assert.equal(f.actor.attackTargetChanged,1);assert.equal(f.node.parameterData[0]>>>0,0x80000003);
  assert.equal(f.trace[1][0],'start');assert.equal(f.trace[2][0],'dispatch');assert.deepEqual(f.trace[3],['target',0x80000003]);
});
test('paused invalid target stays pending without replacement search, while its stored point resets',async()=>{
  const f=fixture('round',false);f.actor.combatRound.started=true;f.actor.combatRound.paused=true;
  f.providers.dispatch=(o,id,valid)=>dispatchAttackRoundAction(o,id,valid);
  assert.equal(await executeAttackAction(f.actor,f.node,f.providers),1);
  assert.deepEqual(f.trace,[['evaluate',0x80000002]]);assert.deepEqual(f.actor.attackTargetPosition,[0,0,0]);
});
test('unpaused invalid target cancels a due strike before replacement search and finishes if none exists',async()=>{
  const f=fixture('round',false),r=f.actor.combatRound;r.started=true;
  const strike={time:0,nativeActionType:1};r.actions.push(strike);
  f.providers.dispatch=(o,id,valid)=>dispatchAttackRoundAction(o,id,valid);
  assert.equal(await executeAttackAction(f.actor,f.node,f.providers),3);
  assert.equal(r.actions.length,0);assert.equal(r.currentAttack,0);assert.equal(r.paused,false);
  assert.deepEqual(f.trace,[['evaluate',0x80000002],['search'],['target',invalid]]);
});
test('approach delegates its queue transition and preserves unsupported work without inventing movement',async()=>{
  const f=fixture('approach');await assert.rejects(executeAttackAction(f.actor,f.node,f.providers),/approach/);
  assert.equal(f.actor.combatRound.started,false);assert.equal(f.actor.objectActionState.list.head.action,f.node);
  f.providers.approach=async(o,n,e)=>{assert.equal(n,f.node);assert.equal(e.decision,'approach');return 2;};
  assert.equal(await executeAttackAction(f.actor,f.node,f.providers),2);assert.deepEqual(f.actor.attackTargetPosition,[1,2,3]);
});
