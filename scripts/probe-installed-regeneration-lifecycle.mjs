// Installed authored spell impacts with canonical world/effect clocks. Direct
// impacts and controlled injuries isolate the shared owners from unrelated AI.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const [install,modulePath,output='backups/animations/installed-regeneration-lifecycle-v1.json']=process.argv.slice(2),rows=[];
const resolver=await openLocalModule(install,modulePath),bytes=await fs.readFile(`${install}/data/lcv/cleric.bic`);
for(const spellId of [374,525,142,153]){
 const row={spellId,stages:[]},start=runtimeDiagnostics.records.length;let phaseStart=start;rows.push(row);
 try{
  const messages=[],s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)}).initialize([],{character:bytes}),npc=s.byTag('M1Q0D19Goblin')[0];assert.ok(npc);await s.enterArea('m0q1d',npc.position);s.random.seed(1);s.scheduler.events=[];
  const target=[142,153].includes(spellId)?npc:s.player,rowStart=runtimeDiagnostics.records.length;row.loadDiagnostics=runtimeDiagnostics.records.slice(start,rowStart);phaseStart=rowStart;
  const snapshot=()=>({at:s.scheduler.time,world:s.worldTimer.time(),id:target.id,hp:target.stats.currentHP,maximum:s.hitPoints(target.id,true),flags:target.nativeField8d4,commandable:target.nativeFieldEc,listening:target.nativeListening1ec,effects:structuredClone(target.effects),icons:structuredClone(target.nativeEffectIcons778.records)});
  if([142,153].includes(spellId)){
   await s.commands.SetIsDestroyable([1,1,0],{self:target.id});target.stats.currentHP=-10;s.damage.synchronize(target);target.nativeFieldEc=0;target.nativeField8d4=0;
  }else{target.stats.currentHP=s.hitPoints(target.id,true)-20;s.damage.synchronize(target);}
  s.scheduler.beforePump=async()=>{s.worldTimer.snapshot();await s.effects.updateObject(target);};
  row.before=snapshot();const spell=s.spellBook.castingSpell(spellId);row.script=spell.impactScript;s.player.nativeSpellClass22c=0;s.player.nativeSpellMetamagic22d=0;s.player.nativeSpellDomain21c=0;
  s.combat.enqueueEvent(8,s.player.id,s.player.id,0,{spellId,casterId:s.player.id,targetId:target.id,itemId:OBJECT_INVALID,featId:65535,position:[target.position[0],-target.position[2],target.position[1]],script:spell.impactScript});await s.scheduler.pump();row.applied=snapshot();
  if([142,153].includes(spellId)){
   assert.ok(target.stats.currentHP>0);assert.equal(target.nativeFieldEc,1);assert.equal(target.nativeField8d4,65535);assert.equal(target.nativeListening1ec,1);assert.equal(s.isDead(target),false);
  }else{
   const parent=target.effects.find(e=>e.type===7);assert.ok(parent,'Authored spell must apply shared regeneration');const interval=parent.integers[1];assert.ok(interval>0&&interval<60000);
   s.scheduler.advance(interval);await s.scheduler.pump();row.stages.push({phase:'exact-interval',...snapshot()});assert.equal(target.stats.currentHP,row.before.hp);assert.equal(parent.integers[3]>>>0,row.applied.world.time);
   s.scheduler.advance(1);await s.scheduler.pump();row.stages.push({phase:'after-interval',...snapshot()});assert.equal(target.stats.currentHP,Math.min(row.before.hp+parent.integers[0],s.hitPoints(target.id,true)));
   assert.equal(parent.integers[3]>>>0,s.worldTimer.time().time);
   const next=target.stats.currentHP;s.scheduler.advance(interval);await s.scheduler.pump();assert.equal(target.stats.currentHP,next);s.scheduler.advance(1);await s.scheduler.pump();row.stages.push({phase:'second-tick',...snapshot()});assert.ok(target.stats.currentHP>next);
   await s.effects.remove(target.id,parent.id);row.removed=snapshot();assert.equal(target.effects.some(e=>e.id===parent.id),false);assert.equal(target.nativeEffectIcons778.records.some(e=>e.iconId===2),false);
   const cured=target.stats.currentHP;s.scheduler.advance(interval+1);await s.scheduler.pump();assert.equal(target.stats.currentHP,cured);
  }
  assert.equal(s.registry.get(target.id),target);row.messages=messages;
 }catch(error){row.failure={message:error.message,stack:error.stack};}
 row.diagnostics=runtimeDiagnostics.records.slice(phaseStart);
}
await fs.writeFile(output,JSON.stringify({rows,limits:'Installed authored impact8 with real shared regeneration/healing/resurrection owners and clock updates. Controlled injury/raiseable state, startup/unrelated AI disabled, seed1. Does not prove normal cast slots/request/release, original-process RNG scheduling, rendered feedback/death UI, native saved effects or campaign readiness. All loading diagnostics retained separately.'},null,2));
console.log(JSON.stringify(rows.map(r=>({spellId:r.spellId,stages:r.stages.length,failure:r.failure?.message,errors:r.diagnostics.filter(d=>d.severity==='error').map(d=>d.message)}))));assert.ok(rows.every(r=>!r.failure&&r.diagnostics.every(d=>d.severity!=='error')),'Installed regeneration/recovery failed; see report');
