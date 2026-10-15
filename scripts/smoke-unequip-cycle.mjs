// Installed plain-item fixture with explicit round clocks. Exercises real
// queue cancellation/conversion and item owners; not authored fight parity.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {createRoundAction} from '../src/combat_action.js';
import {addObjectAction} from '../src/object_actions.js';
const [install,modulePath,area,template='nw_wswdg001',tag='M1Q0D19Goblin']=process.argv.slice(2),messages=[];
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)})
  .initialize([],{character:await fs.readFile(`${install}/data/lcv/fighter.bic`)});
await s.enterArea(area,[72.8,0.00001,-104.8]);const o=s.byTag(tag).find(o=>o.objectType===5&&!s.isDead(o));assert.ok(o);const r=o.combatRound;
const begin=runtimeDiagnostics.records.length,itemId=await s.createItem(template,o.id,1,''),item=s.registry.get(itemId);assert.ok(item?.nativeItemLoaded);
await s.combat.clearActions(o);r.started=false;
await s.commands.ActionEquipItem([item.id,4],{self:o.id});assert.equal(o.objectActionState.list.head.action.actionId,8);await s.combat.runActions(o,0,0);assert.equal(s.equipmentSlot(o,16),item);
await s.commands.ActionUnequipItem([item.id],{self:o.id});
assert.equal(o.objectActionState.list.head.action.actionId,11);await s.combat.runActions(o,0,0);
assert.equal(s.equipmentSlot(o,16),null);assert.ok([...o.nativeRepository.ids()].includes(itemId));assert.equal(item.possessorId,o.id);
const prepare=()=>{Object.assign(r,{started:true,paused:false,length:6000,timer:0,overlap:0,currentAttack:0,onhandAttacks:3,offhandAttacks:0,additionalAttacks:0,bonusEffectAttacks:0});r.actions=[createRoundAction(1,OBJECT_INVALID,{time:0,count:1,duration:1000})];return addObjectAction(o.objectActionState,12,65535,[{type:3,value:OBJECT_INVALID}]);};
let attack=prepare();await s.commands.ActionEquipItem([item.id,4],{self:o.id});
assert.equal(r.actions[0].nativeActionType,6);assert.equal(await s.combat.cancelQueuedAction(o,3,attack.groupId),1);
assert.deepEqual([...o.objectActionState.list].map(a=>a.actionId),[8]);assert.deepEqual(r.actions,[]);
await s.combat.runActions(o,0,0);assert.equal(s.equipmentSlot(o,16),item);
attack=prepare();await s.commands.ActionUnequipItem([item.id],{self:o.id});
assert.equal(r.actions[0].nativeActionType,7);assert.equal(await s.combat.cancelQueuedAction(o,3,attack.groupId),1);
assert.deepEqual([...o.objectActionState.list].map(a=>a.actionId),[11]);assert.deepEqual(r.actions,[]);
await s.combat.runActions(o,0,0);assert.equal(s.equipmentSlot(o,16),null);assert.ok([...o.nativeRepository.ids()].includes(itemId));assert.equal(item.possessorId,o.id);
const errors=[...new Set(runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error').map(r=>r.message))];assert.deepEqual(errors,[]);
console.log(JSON.stringify({validation:'PASS',actorId:o.id,itemId,canonicalOwner:item.possessorId,objectActions:o.objectActionState.list.count,roundActions:r.actions.length,errors,limits:'Installed NPC plain-item fixture with explicit round timing. PC item-level restrictions/passive effects and full native combat parity remain unverified.'}));
