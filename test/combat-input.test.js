import test from 'node:test';
import assert from 'node:assert/strict';
import {receiveAttackInput} from '../src/combat_input.js';
import {createCombatRound} from '../src/combat_round.js';
import {clearAllSpecialAttacks} from '../src/combat_attack_data.js';
import {ModuleSession} from '../src/module_session.js';

function fixture(){
  const actor={nativeField8ac:0,combatRound:createCombatRound()},trace=[];
  const p={clientObject:()=>actor,asCreature:o=>o,overflow:()=>0,underflow:()=>0,
    readObjectId:()=>{trace.push('read');return 0x80000001;},
    addAttack:(o,...args)=>{trace.push(['attack',o,...args]);return 0;},clearSpecial:r=>{trace.push('clear');clearAllSpecialAttacks(r);}};
  return{actor,p,trace};
}
test('normal decoded attack input forwards native0/1/0 flags and clears specials AFTER rejected attack; packet result is1',async()=>{
  const {actor,p,trace}=fixture();actor.combatRound.specialAttacks.push(7);actor.combatRound.specialAttackParameters.push(3);
  assert.equal(await receiveAttackInput({},p),1);assert.deepEqual(trace,['read',['attack',actor,0x80000001,0,1,0],'clear']);
  assert.deepEqual(actor.combatRound.specialAttacks,[]);assert.deepEqual(actor.combatRound.specialAttackParameters,[3]);
});

test('local manual cancellation drains through the same FIFO after attack input and never follows a changed controlled object',async()=>{
  const s=new ModuleSession(null);s.player=s.register('player','pc',{stats:{}});const actor=s.player,calls=[];
  s.combat.receiveAttackInput=async id=>{calls.push(['attack',id]);return 1;};s.combat.clearActions=async o=>calls.push(['clear',o.id]);
  const attack=s.queuePlayerAttack(88),cancel=s.queuePlayerClearActions();assert.deepEqual(calls,[]);
  await s.drainPlayerInputs();assert.equal(await attack,1);assert.equal(await cancel,1);assert.deepEqual(calls,[['attack',88],['clear',actor.id]]);
  const stale=s.queuePlayerClearActions();s.player=s.register('player','replacement',{stats:{}});await s.drainPlayerInputs();assert.equal(await stale,0);assert.equal(calls.length,2);
});
test('controlled object cast, nonzero8ac veto and both codec gates prevent attack while preserving native read/query order',async()=>{
  for(const gate of ['missing','cast','veto','overflow','readOverflow','underflow']){
    const f=fixture();
    if(gate==='missing')f.p.clientObject=()=>null;if(gate==='cast')f.p.asCreature=()=>null;if(gate==='veto')f.actor.nativeField8ac=2;
    if(gate==='overflow')f.p.overflow=()=>1;
    if(gate==='readOverflow'){let calls=0;f.p.overflow=()=>calls++===0?0:1;f.p.underflow=()=>assert.fail('Overflow queried underflow');}
    if(gate==='underflow')f.p.underflow=()=>1;
    assert.equal(await receiveAttackInput({},f.p),0);assert.deepEqual(f.trace,gate==='overflow'?[]:['read']);
  }
});
test('unimplemented attack leaves special queue intact and cannot masquerade as accepted input',async()=>{
  const f=fixture();f.actor.combatRound.specialAttacks.push(7);f.p.addAttack=()=>{throw new Error('Unavailable native dependency');};
  await assert.rejects(receiveAttackInput({},f.p),/Unavailable/);assert.deepEqual(f.actor.combatRound.specialAttacks,[7]);
  f.p.readObjectId=()=>-1;await assert.rejects(receiveAttackInput({},f.p),/OBJECTID is unavailable/);
});
test('native special clearing preserves consumed records, parameter queue and sequence; clamp warnings requery the live attack count',()=>{
  const r=createCombatRound();r.onhandAttacks=52;r.currentAttack=50;r.attacks[49].attackType=7;
  r.specialAttacks=[7];r.specialAttackParameters=[123];r.specialAttackSequence=124;let warnings=0;
  clearAllSpecialAttacks(r,()=>{warnings++;if(warnings===2)r.onhandAttacks=51;});
  assert.equal(warnings,2);assert.equal(r.attacks[49].attackType,0);assert.deepEqual(r.specialAttackParameters,[123]);assert.equal(r.specialAttackSequence,124);
});
test('live local decoded-input adapter uses the actual canonical client object and rejects unbound clients',async()=>{
  const s=new ModuleSession(null);assert.equal(await s.combat.receiveAttackInput(1),0);
  s.player=s.register('player','pc',{stats:{}});s.player.combatRound=createCombatRound();let called;
  s.combat.requestAttack=(...args)=>{called=args;return 0;};
  assert.equal(await s.combat.receiveAttackInput(0xffffffff),1);assert.deepEqual(called,[s.player,0xffffffff,0,1,0]);
  s.player.nativeField8ac=1;called=null;assert.equal(await s.combat.receiveAttackInput(2),0);assert.equal(called,null);
});
