// Installed authored impact + real affliction clocks/events/removal. This
// isolates unrelated AI; it does not claim normal cast admission or rendering.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {subtractWorldTimes} from '../src/reputation.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const [install,modulePath,area,tag,idsText='129,27',character='wizard',output='backups/animations/installed-affliction-lifecycle-v1.json']=process.argv.slice(2);
const resolver=await openLocalModule(install,modulePath),bytes=await fs.readFile(`${install}/data/lcv/${character}.bic`),rows=[];
for(const spellId of idsText.split(',').map(Number)){
 const row={spellId,stages:[]},start=runtimeDiagnostics.records.length;let phaseStart=start;rows.push(row);
 try{
  const s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:bytes}),target=s.byTag(tag)[0];assert.ok(target);await s.enterArea(area,target.position);s.random.seed(1);s.scheduler.events=[];
  row.loadDiagnostics=runtimeDiagnostics.records.slice(start);phaseStart=runtimeDiagnostics.records.length;
  s.scheduler.beforePump=async()=>{s.worldTimer.snapshot();await s.effects.updateObject(target);};
  const snapshot=()=>({at:s.scheduler.time,world:s.worldTimer.time(),id:target.id,hp:target.stats.currentHP,abilities:structuredClone(target.stats.equippedAbilities),effects:structuredClone(target.effects),icons:structuredClone(target.nativeEffectIcons778.records),looping:structuredClone(target.nativeLoopingVisuals160.records),draws:s.random.draws});
  row.before=snapshot();const spell=s.spellBook.castingSpell(spellId);assert.ok(spell);row.script=spell.impactScript;
  s.player.nativeSpellClass22c=0;s.player.nativeSpellMetamagic22d=0;s.player.nativeSpellDomain21c=0;
  s.combat.enqueueEvent(8,s.player.id,s.player.id,0,{spellId,casterId:s.player.id,targetId:target.id,itemId:OBJECT_INVALID,featId:65535,position:[target.position[0],-target.position[2],target.position[1]],script:spell.impactScript});
  await s.scheduler.pump();row.applied=snapshot();const parent=target.effects.find(e=>[5,35].includes(e.type));assert.ok(parent,'Authored impact must retain its real poison/disease record');row.parentId=parent.id;row.kind=parent.type;
  if(parent.type===35)assert.ok(target.effects.some(e=>e.type===37&&e.integers[2]===1));
  for(let stage=0;stage<4;stage++){
   const live=target.effects.find(e=>e.id===parent.id&&e.type===parent.type);if(!live)break;
   const due={day:live.integers[parent.type===35?4:3]>>>0,time:live.integers[parent.type===35?5:4]>>>0},delta=subtractWorldTimes(due,s.worldTimer.time(),s.worldTimer.dayLength);assert.equal(delta.status,0);
   const delay=delta.days*s.worldTimer.dayLength+delta.milliseconds,oldDeadline=[...live.integers];
   if(delay>0){s.scheduler.advance(delay-1);await s.scheduler.pump();const before=snapshot();assert.ok(target.effects.includes(live));assert.deepEqual(live.integers,oldDeadline);row.stages.push({phase:'before-deadline',...before});s.scheduler.advance(1);}
   await s.scheduler.pump();row.stages.push({phase:'at-deadline',...snapshot()});assert.equal(s.registry.get(target.id),target);
   if(parent.type===35){assert.equal(target.effects.some(e=>e.type===35),false);assert.equal(target.nativeEffectIcons778.records.some(e=>e.iconId===20),false);}
  }
  row.afterTicks=snapshot();const live=target.effects.find(e=>e.id===parent.id&&e.type===parent.type);if(live)await s.commands.RemoveEffect([target.id,live]);row.cured=snapshot();
  assert.equal(target.effects.some(e=>e.id===parent.id),false);assert.equal(target.nativeEffectIcons778.records.some(e=>e.iconId===(parent.type===35?20:21)),false);
  const initialIds=new Set(row.before.effects.map(e=>e.id));for(const id of new Set(target.effects.filter(e=>!initialIds.has(e.id)).map(e=>e.id)))await s.effects.remove(target.id,id);
  row.removed=snapshot();assert.deepEqual(row.removed.abilities,row.before.abilities);assert.deepEqual(row.removed.icons,row.before.icons);assert.deepEqual(row.removed.looping,row.before.looping);assert.equal(s.registry.get(row.before.id),target);
 }catch(error){row.failure={message:error.message,stack:error.stack};}
 row.diagnostics=runtimeDiagnostics.records.slice(phaseStart);
}
await fs.writeFile(output,JSON.stringify({rows,limits:'Installed authored impact8 and actual world-timer affliction polling, queued effect5/removal14, native runtime ability penalties and grouped cleanup. Unrelated actor AI disabled; seed1 fixture only. The final cleanup explicitly removes persistent ability-damage groups after the poison/disease source is cured. Does not prove normal casting/UI/rendering, recovery/rest healing, saved effect import, native-process RNG scheduling or campaign readiness.'},null,2));
console.log(JSON.stringify(rows.map(r=>({spellId:r.spellId,kind:r.kind,stages:r.stages.length,failure:r.failure?.message,errors:r.diagnostics.filter(d=>d.severity==='error').map(d=>d.message)}))));
assert.ok(rows.every(r=>!r.failure&&r.diagnostics.every(d=>d.severity!=='error')),'Installed affliction lifecycle failed; see report');
