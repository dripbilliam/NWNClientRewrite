// Direct impact-event integration probe, explicitly NOT a cast/release test.
// Uses untouched installed authored NCS, active data and a canonical PC/target.
import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const [install,modulePath,area,spellText,targetTag,characterName='wizard',durationText='10000',seedText]=process.argv.slice(2),spellId=Number(spellText),messages=[],duration=Number(durationText);
if(!Number.isInteger(spellId))throw new Error('A physical active spell row ID is required');
if(!Number.isInteger(duration)||duration<0||duration>60000)throw new Error('Probe duration must be milliseconds in0..60000');
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)})
  .initialize([],{character:await fs.readFile(`${install}/data/lcv/${characterName}.bic`)});
const authoredTarget=targetTag?s.byTag(targetTag)[0]:null;
await s.enterArea(area,authoredTarget?.position??s.player.position??[0,0,0]);
const casterTag=process.argv.find(v=>v.startsWith('--caster-tag='))?.slice(13),caster=casterTag?s.byTag(casterTag)[0]:s.player,
  target=process.argv.includes('--target-player')?s.player:targetTag?s.byTag(targetTag)[0]:caster,spell=s.spellBook.castingSpell(spellId);if(!caster||!target||!spell)throw new Error('Probe caster/target/spell is unavailable');
const seed=seedText===undefined?null:Number(seedText);if(seed!==null)s.random.seed(seed);
const before=runtimeDiagnostics.records.length;
const engineCalls=[];
if(process.argv.includes('--trace-engine-calls'))for(const [name,implementation]of Object.entries(s.commands)){
 s.commands[name]=function(...args){
  const record={name,arguments:args[0]?.map(value=>['number','string','boolean'].includes(typeof value)?value:null)};engineCalls.push(record);
  return implementation.apply(this,args);
 };
}
// Isolate authored impact and its deferred situations from unrelated actor AI.
// The clock/scheduler still own due order; this is explicitly not a world run.
s.scheduler.beforePump=()=>{s.worldTimer.snapshot();};
caster.nativeSpellClass22c=0;caster.nativeSpellMetamagic22d=0;caster.nativeSpellDomain21c=0;
const point=[target.position[0],-target.position[2],target.position[1]],beforeHP=target.stats?.currentHP;
s.combat.enqueueEvent(8,caster.id,caster.id,0,{spellId,casterId:caster.id,targetId:target.id,itemId:OBJECT_INVALID,featId:65535,position:point,script:spell.impactScript});
await s.scheduler.pump();
for(let pumps=0;s.scheduler.events[0]?.due<=duration;pumps++){
  if(pumps>=10000)throw new Error('Authored impact probe deferred-event budget exceeded');
  s.scheduler.advance(Math.max(0,s.scheduler.events[0].due-s.scheduler.time));await s.scheduler.pump();
}
const state=()=>({aiState:target.nativeField771,commandable:target.nativeFieldEc,aiFlags:target.nativeField8d4,icons:structuredClone(target.nativeEffectIcons778?.records),looping:structuredClone(target.nativeLoopingVisuals160?.records),
  classes:(target.creatureData??target.authored)?.ClassList?.map(c=>({classId:c.Class,level:c.ClassLevel,negativeLevels:c.skillPenaltyByte})),
  combat:target.stats?.combat?structuredClone({attackBonuses:target.stats.combat.attackBonuses,saves:target.stats.combat.saves}):undefined});
const effects=structuredClone(target.effects),appliedState=state();let removedState;
if(process.argv.includes('--remove-effects')){
 for(const id of new Set(effects.map(e=>e.id)))await s.effects.remove(target.id,id);
 removedState={...state(),effects:structuredClone(target.effects)};
}
console.log(JSON.stringify({spellId,script:spell.impactScript,seed,casterId:caster.id,targetId:target.id,beforeHP,afterHP:target.stats?.currentHP,
  effects,appliedState,removedState,history:{caster:target.nativeLastSpellCaster230,spell:target.nativeLastSpell234,harmful:target.nativeLastSpellHarmful238},
  context:{savingSpell:caster.lastSpellId,effectSpell:caster.nativeEffectSpellId774},messages,
  elapsed:s.scheduler.time,pending:s.scheduler.events.map(e=>({targetId:e.targetId,due:e.due,type:e.event.type})),
  engineCalls,diagnostics:runtimeDiagnostics.records.slice(before),limits:'Direct authored impact8 plus deferred situations with unrelated actor AI disabled; does not exercise request/admission/resources/conjure/release, full spell visuals, campaign acceptance or original-process parity.'},null,2));
if(runtimeDiagnostics.records.slice(before).some(r=>r.severity==='error'))process.exitCode=1;
