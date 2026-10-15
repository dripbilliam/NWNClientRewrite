// Direct installed impact plus removal/expiry verification. This does not
// exercise cast requests, resources, release timing, visual rendering or AI.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {abilityModifierCells} from '../src/ability_modifier_cache.js';
const [install,modulePath,area,idsText,character='wizard']=process.argv.slice(2),ids=idsText.split(',').map(Number);
if(ids.some(id=>!Number.isInteger(id)||id<0))throw new Error('Physical active spell IDs are required');
const snapshot=o=>({id:o.id,currentHP:o.stats.currentHP,maxHP:o.stats.maxHP,abilities:structuredClone(o.stats.equippedAbilities),bonuses:structuredClone(o.stats.abilityBonuses),
  modifiers:abilityModifierCells.map(k=>o[k]),factor:o.nativeMovementFactor8e8,haste:o.nativeHaste760,slow:o.nativeSlow764,silence:o.nativeSilence75c,vision:o.visionFlags,icons:structuredClone(o.nativeEffectIcons778.records)});
const resolver=await openLocalModule(install,modulePath),characterBytes=await fs.readFile(`${install}/data/lcv/${character}.bic`),rows=[];
for(const id of ids){
  const messages=[],s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,onCombatMessage:m=>messages.push(m),serverPvpSetting:0}).initialize([],{character:characterBytes});
  await s.enterArea(area,s.player.position??[0,0,0]);s.scheduler.beforePump=()=>s.worldTimer.snapshot();s.random.seed(1);
  const o=s.player,spell=s.spellBook.castingSpell(id);if(!spell)throw new Error(`Active spell${id} is unavailable`);
  const diagnostics=runtimeDiagnostics.records.length,before=snapshot(o),beforeInvisible=[...s.module.nativeInvisibleCreatureIds330],existing=new Set(o.effects.map(e=>e.id));
  o.nativeSpellClass22c=0;o.nativeSpellMetamagic22d=0;o.nativeSpellDomain21c=0;
  s.combat.enqueueEvent(8,o.id,o.id,0,{spellId:id,casterId:o.id,targetId:o.id,itemId:OBJECT_INVALID,featId:65535,position:[o.position[0],-o.position[2],o.position[1]],script:spell.impactScript});
  await s.scheduler.pump();
  while(s.scheduler.events[0]?.due<=1000){s.scheduler.advance(Math.max(0,s.scheduler.events[0].due-s.scheduler.time));await s.scheduler.pump();}
  const applied=snapshot(o),appliedInvisible=[...s.module.nativeInvisibleCreatureIds330],effects=structuredClone(o.effects),errors=runtimeDiagnostics.records.slice(diagnostics).filter(d=>d.severity==='error');
  if(!errors.length){for(const effectId of new Set(o.effects.filter(e=>!existing.has(e.id)).map(e=>e.id)))await s.effects.remove(o.id,effectId);}
  const removed=snapshot(o),removedInvisible=[...s.module.nativeInvisibleCreatureIds330],record={id,script:spell.impactScript,before,applied,effects,removed,beforeInvisible,appliedInvisible,removedInvisible,messages,diagnostics:runtimeDiagnostics.records.slice(diagnostics)};
  rows.push(record);
  if(!errors.length){assert.deepEqual(removed,before,`Spell${id} removal must restore canonical ability/HP/control state`);assert.deepEqual(removedInvisible,beforeInvisible);assert.ok(o.effects.every(e=>existing.has(e.id)));}
}
console.log(JSON.stringify({rows,limits:'Direct installed self-target impact and removal with isolated actor AI; not full casting, renderer, native process or campaign acceptance. Seed1 is fixture repeatability only.'},null,2));
if(rows.some(r=>r.diagnostics.some(d=>d.severity==='error')))process.exitCode=1;
