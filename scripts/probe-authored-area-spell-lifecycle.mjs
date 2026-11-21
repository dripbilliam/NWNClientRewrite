// Installed-script fixtures for shared persistent-effect owners. Direct
// impact8 and controlled AoE clock updates, not cast/release or rendering.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const [install,modulePath,area,idsText,character='wizard']=process.argv.slice(2),rows=[];
for(const id of idsText.split(',').map(Number)){
  if(!Number.isInteger(id))throw new Error('Physical active spell IDs are required');
  const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0})
    .initialize([],{character:await fs.readFile(`${install}/data/lcv/${character}.bic`)});
  await s.enterArea(area,s.player.position);s.random.seed(1);const caster=s.player,spell=s.spellBook.castingSpell(id),before=runtimeDiagnostics.records.length;
  const aoes=()=>[...s.registry.objects.values()].filter(o=>o.objectType===11),samples=[],scriptRuns=[];
  const run=s.vm.run.bind(s.vm);s.vm.run=(program,self,...args)=>{scriptRuns.push({name:program.name,self,time:s.scheduler.time});return run(program,self,...args);};
  s.scheduler.beforePump=async()=>{s.worldTimer.snapshot();for(const o of aoes())try{await s.areaEffects.update(o);}catch(error){s.report(error,s.diagnosticContext(o.id));}await s.effects.updateObject(caster);};
  caster.nativeSpellClass22c=0;caster.nativeSpellMetamagic22d=0;caster.nativeSpellDomain21c=0;
  s.combat.enqueueEvent(8,caster.id,caster.id,0,{spellId:id,casterId:caster.id,targetId:caster.id,itemId:OBJECT_INVALID,featId:65535,
    position:[caster.position[0],-caster.position[2],caster.position[1]],script:spell.impactScript});
  const snapshot=()=>samples.push({time:s.scheduler.time,hp:caster.stats.currentHP,effects:structuredClone(caster.effects),areas:aoes().map(o=>({id:o.id,creator:o.nativeAreaEffectCreator330,spell:o.nativeSpellId218,
    effectSpell:o.nativeAreaEffectSpellId,level:o.nativeCasterLevel344,dc:o.nativeSpellSaveDC340,shape:o.nativeShape310,radius:o.nativeRadius318,anchor:o.nativeAnchor334,
    remaining:o.nativeDuration390,durationType:o.nativeDurationType394,heartbeat:o.nativeHeartbeat388,scripts:o.scripts,position:o.position,areaId:o.areaId,fieldD8:o.nativeFieldD8}))});
  for(const time of [0,6000,12000,18000]){s.scheduler.advance(time-s.scheduler.time);await s.scheduler.pump();snapshot();}
  const created=aoes().map(o=>o.id);
  for(const objectId of created)s.combat.enqueueEvent(11,objectId,objectId,0,null);
  await s.scheduler.pump();
  for(const objectId of created){assert.equal(s.registry.get(objectId),undefined);assert.equal(s.currentArea.nativeSpatial.indexOf(objectId),-1);assert.equal(s.currentArea.nativeSubareas.indexOf(objectId),-1);
    for(const o of s.registry.objects.values())if(o.objectType===5){assert.equal(o.nativeFollowingAOEs.indexOf(objectId),-1);assert.equal(o.nativeSubareaMembership.indexOf(objectId),-1);}}
  assert.equal(s.registry.get(caster.id),caster);
  rows.push({spellId:id,script:spell.impactScript,casterId:caster.id,samples,scriptRuns,removed:created,diagnostics:runtimeDiagnostics.records.slice(before)});
}
console.log(JSON.stringify({rows,limits:'Installed impact and persistent-script lifecycle fixtures; controlled clock with unrelated actor AI disabled. Not cast/resource/release, renderer, original-process, campaign or multiplayer acceptance.'},null,2));
if(rows.some(r=>r.diagnostics.some(d=>d.severity==='error')))process.exitCode=1;
