// Installed-template fixture. Adds a carried plain weapon through the engine
// call to exercise switching; preserves actor stats. Not authored-fight parity.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {createRoundAction} from '../src/combat_action.js';
const [install,modulePath,area,tag,template]=process.argv.slice(2);
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0})
  .initialize([],{character:await fs.readFile(`${install}/data/lcv/fighter.bic`)});
await s.enterArea(area,[72.8,0.00001,-104.8]);
const actor=s.byTag(tag).find(o=>o.objectType===5&&!s.isDead(o));assert.ok(actor);
const begin=runtimeDiagnostics.records.length,itemId=await s.createItem(template,actor.id,1,''),item=s.registry.get(itemId);assert.ok(item&&item.objectType===6);
assert.equal(item.possessorId,actor.id);assert.ok([...actor.nativeRepository.ids()].includes(itemId));
await s.combat.clearActions(actor);
// Native timer/group fields are set explicitly for this fixture; selection,
// equip/unequip/caches and canonical repositories use the live owners.
actor.combatRound.started=false;
assert.equal(await s.combat.addEquip(actor,item,16,0,0,OBJECT_INVALID),1);
assert.equal(actor.objectActionState.list.head.action.actionId,8);
await s.combat.runActions(actor,0,0);assert.equal(s.equipmentSlot(actor,16),item);assert.equal(actor.objectActionState.list.count,0);
const old=s.equipmentSlot(actor,16),otherId=await s.createItem(template,actor.id,1,''),other=s.registry.get(otherId),r=actor.combatRound;
Object.assign(r,{started:true,paused:false,length:6000,timer:240,currentAttack:0,onhandAttacks:3,offhandAttacks:0,additionalAttacks:0,bonusEffectAttacks:0});
r.actions=[createRoundAction(1,s.player.id,{time:900,count:1,duration:1000})];
assert.equal(await s.combat.addEquip(actor,other,16,0,0,OBJECT_INVALID),1);
assert.equal(r.actions[0].nativeActionType,6);assert.equal(r.actions[0].equipmentSlot,16);assert.equal(r.length,4500);
r.timer=0;
const result=await s.combat.dispatchAttack(actor,s.player.id,true,{equipment:(o,a)=>s.runEquip(o,a.targetId,a.equipmentSlot,OBJECT_INVALID),recomputeRound:o=>s.combat.recomputeRound(o)});
assert.equal(result.status,'dispatched');assert.equal(s.equipmentSlot(actor,16),other);assert.equal(r.paused,true);assert.equal(r.pauseTimer,1500);
assert.ok([...actor.nativeRepository.ids()].includes(old.id));assert.ok(![...actor.nativeRepository.ids()].includes(other.id));
for(const id of [old.id,other.id])assert.equal(s.registry.get(id).possessorId,actor.id);
const errors=[...new Set(runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error').map(r=>r.message))];assert.deepEqual(errors,[]);
console.log(JSON.stringify({validation:'PASS',actorId:actor.id,oldItemId:old.id,equippedItemId:other.id,roundLength:r.length,pauseTimer:r.pauseTimer,errors,limits:'Installed plain-item fixture, not full native fight parity.'}));
