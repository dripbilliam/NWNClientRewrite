import test from 'node:test';
import assert from 'node:assert/strict';
import { creatureBumpable } from '../src/creature_bump.js';
import { createCombatRound } from '../src/combat_round.js';
import { createObjectActionState,addObjectAction } from '../src/object_actions.js';
import { PathInformation } from '../src/path_information.js';
function fixture(){
  const actor={id:0x80000001,pc:0,familiar:0,associateIds:[]},target={id:0x80000002,pc:0,familiar:0,
    nativePathInfo:new PathInformation(0x80000002),animationState:0,nativeField700:0,combatRound:createCombatRound(),objectActionState:createObjectActionState()};
  const calls=[],p={associates:o=>o.associateIds,pc:o=>o.pc,possessedFamiliar:o=>{calls.push(o.id);return o.familiar;},reputation:()=>90};
  return{actor,target,p,calls};
}
test('friend bumpability uses native reputation threshold, associate membership and animation veto',async()=>{
  const {actor,target,p}=fixture();p.reputation=()=>89;assert.equal(await creatureBumpable(actor,target,p),0);
  actor.associateIds.push(target.id);p.reputation=()=>assert.fail('owned associate skips reputation');assert.equal(await creatureBumpable(actor,target,p),1);
  for(const animation of [6,8]){target.animationState=animation;assert.equal(await creatureBumpable(actor,target,p),0);}
  target.animationState=7;assert.equal(await creatureBumpable(actor,target,p),1);
  target.nativePathInfo.field4=0;assert.equal(await creatureBumpable(actor,target,{}),0);
});
test('NPC pair considers paused round, combat state and queued actions, independently from round started',async()=>{
  const {actor,target,p}=fixture();target.combatRound.started=true;assert.equal(await creatureBumpable(actor,target,p),1);
  target.combatRound.paused=true;assert.equal(await creatureBumpable(actor,target,p),0);
  target.combatRound.paused=false;target.nativeField700=2;assert.equal(await creatureBumpable(actor,target,p),0);
  target.nativeField700=0;addObjectAction(target.objectActionState,30);assert.equal(await creatureBumpable(actor,target,p),0);
});
test('PC to NPC bumps other queued actions but cannot bump queued attack or either spell action',async()=>{
  for(const action of [1,12,15,17,30,46,47]){
    const {actor,target,p}=fixture();actor.pc=1;target.combatRound.paused=true;target.nativeField700=1;
    addObjectAction(target.objectActionState,action);
    assert.equal(await creatureBumpable(actor,target,p),[12,15,46].includes(action)?0:1);
  }
});
test('NPC never bumps controlled player/familiar; controlled pair checks queued head only',async()=>{
  for(const familiar of [false,true]){
    const {actor,target,p}=fixture();target.pc=Number(!familiar);target.familiar=Number(familiar);
    assert.equal(await creatureBumpable(actor,target,p),0);actor.familiar=1;
    target.combatRound.paused=true;target.nativeField700=1;target.objectActionState.executingId=12;
    assert.equal(await creatureBumpable(actor,target,p),1,'executing action does not count as queued head');
    addObjectAction(target.objectActionState,30);assert.equal(await creatureBumpable(actor,target,p),0);
  }
});
test('native NPC possession queries are repeated rather than cached',async()=>{
  const {actor,target,p,calls}=fixture();assert.equal(await creatureBumpable(actor,target,p),1);
  assert.deepEqual(calls,[actor.id,target.id,actor.id,actor.id,actor.id,target.id]);
});
