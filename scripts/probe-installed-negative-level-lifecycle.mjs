// Actual installed drain/restoration scripts plus live shared counters, linked
// groups, caster/DC/skill queries and independently owned bonus HP expiration.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {creatureLevel} from '../src/negative_level_effect.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const [install,modulePath,output='backups/animations/installed-negative-level-lifecycle-v1.json']=process.argv.slice(2),rows=[];
const resolver=await openLocalModule(install,modulePath),bytes=await fs.readFile(`${install}/data/lcv/wizard.bic`);
for(const cure of [70,152,'bonusHP']){
 const row={cure},start=runtimeDiagnostics.records.length;let phaseStart=start;rows.push(row);
 try{
  const messages=[],s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)}).initialize([],{character:bytes}),caster=s.byTag('M0Q0_SUMMON_MAGE')[0],target=s.player;assert.ok(caster);await s.enterArea('m0q1d',caster.position);s.scheduler.events=[];
  row.loadDiagnostics=runtimeDiagnostics.records.slice(start);phaseStart=runtimeDiagnostics.records.length;
  s.scheduler.beforePump=async()=>{s.worldTimer.snapshot();await s.effects.updateObject(target);await s.effects.updateObject(caster);};
  // Query the ordinary class0 context; constructor context255 deliberately
  // selects the unrelated feat/fallback branches in GetCasterLevel/save DC.
  for(const o of [caster,target]){o.nativeSpellClass22c=0;o.nativeSpellDomain21c=0;}
  const snapshot=async o=>({id:o.id,baseLevel:creatureLevel(o,0),level:creatureLevel(o,1),casterLevel:s.spellBook.casterLevel(o),spellDC:s.spellBook.saveDC(o,1),skill:await s.combat.skill(o,0,null,0),
   hp:o.stats.currentHP,temporaryHP:o.stats.temporaryHP??0,classes:o.creatureData.ClassList.map(c=>({type:c.Class,level:c.ClassLevel,penalty:c.skillPenaltyByte})),effects:structuredClone(o.effects),icons:structuredClone(o.nativeEffectIcons778.records),slots:o.nativeTalentClasses.map(c=>c.memorized.map(r=>r.length))});
  const impact=async(id,actor,recipient)=>{
   actor.nativeSpellClass22c=0;actor.nativeSpellMetamagic22d=0;actor.nativeSpellDomain21c=0;const spell=s.spellBook.castingSpell(id);
   s.combat.enqueueEvent(8,actor.id,actor.id,0,{spellId:id,casterId:actor.id,targetId:recipient.id,itemId:OBJECT_INVALID,featId:65535,position:[recipient.position[0],-recipient.position[2],recipient.position[1]],script:spell.impactScript});await s.scheduler.pump();
  };
  row.before=await snapshot(target);row.sourceBefore=await snapshot(caster);
  if(cure==='bonusHP'){
   const effect=s.commands.EffectNegativeLevel([1,1],{self:caster.id});await s.commands.ApplyEffectToObject([1,effect,target.id,60],{self:caster.id});row.applied=await snapshot(target);row.sourceApplied=await snapshot(caster);
   const parent=target.effects.find(e=>e.type===82),bonus=caster.effects.find(e=>e.type===15);assert.ok(parent);assert.ok(bonus);assert.notEqual(bonus.id,parent.id);assert.equal(bonus.creatorId,caster.id);assert.equal(bonus.integers[0],5);assert.equal(bonus.duration,18);
   assert.equal(row.applied.level,row.before.level-1);assert.equal(row.sourceApplied.temporaryHP,row.sourceBefore.temporaryHP+5);
   await s.commands.RemoveEffect([target.id,parent],{self:target.id});await s.scheduler.pump();row.cured=await snapshot(target);row.sourceAfterCure=await snapshot(caster);assert.equal(row.cured.level,row.before.level);assert.equal(row.sourceAfterCure.temporaryHP,5);
   s.scheduler.advance(18000);await s.scheduler.pump();assert.ok(caster.effects.some(e=>e.id===bonus.id));s.scheduler.advance(1);await s.scheduler.pump();row.sourceExpired=await snapshot(caster);assert.equal(caster.effects.some(e=>e.id===bonus.id),false);assert.equal(row.sourceExpired.temporaryHP,row.sourceBefore.temporaryHP);
  }else{
   s.random.seed(4);await impact(52,caster,target);row.applied=await snapshot(target);const parent=target.effects.find(e=>e.type===82);assert.ok(parent,'Authored hostile drain must survive native save gates and retain its parent');const count=parent.integers[0];row.count=count;
   assert.equal(row.applied.level,row.before.level-count);assert.equal(row.applied.casterLevel,row.before.casterLevel-count);assert.equal(row.applied.spellDC,row.before.spellDC-count);assert.equal(row.applied.classes[0].penalty,count);assert.equal(row.applied.baseLevel,row.before.baseLevel);
   await impact(cure,target,target);row.cured=await snapshot(target);assert.deepEqual(row.cured.classes,row.before.classes);assert.equal(row.cured.level,row.before.level);assert.equal(row.cured.casterLevel,row.before.casterLevel);assert.equal(row.cured.spellDC,row.before.spellDC);assert.equal(row.cured.skill,row.before.skill);assert.equal(target.effects.some(e=>e.id===parent.id),false);assert.equal(target.nativeEffectIcons778.records.some(e=>e.iconId===50),false);
  }
  assert.equal(s.registry.get(target.id),target);assert.equal(s.registry.get(caster.id),caster);row.messages=messages;
 }catch(error){row.failure={message:error.message,stack:error.stack};}
 row.diagnostics=runtimeDiagnostics.records.slice(phaseStart);
}
await fs.writeFile(output,JSON.stringify({rows,limits:'Actual installed Enervation and Greater/ordinary Restoration impacts. Authored hostile wizard casts at the imported PC, seed4 fails its real saving throw. Bonus HP fixture directly calls native script constructor/application/removal to cover an independent source effect and strict expiry. Unrelated AI/startup disabled, no counterfeit slots, source/target IDs stable. Not ordinary drain casting/renderer/continuous campaign or original-process RNG scheduling proof; every load/engine diagnostic retained.'},null,2));
console.log(JSON.stringify(rows.map(r=>({cure:r.cure,count:r.count,level:[r.before?.level,r.applied?.level,r.cured?.level],failure:r.failure?.message,errors:r.diagnostics.filter(d=>d.severity==='error').map(d=>d.message)}))));assert.ok(rows.every(r=>!r.failure&&r.diagnostics.every(d=>d.severity!=='error')),'Installed negative-level lifecycle failed; see report');
