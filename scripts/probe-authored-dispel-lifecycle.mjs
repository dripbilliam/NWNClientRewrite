// Installed scripts with canonical buff IDs and real deferred removal events.
// Direct impact fixtures, not resource admission/release or campaign acceptance.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',rows=[];
for(const id of [94,41,67,122]){
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0})
  .initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 const buffCaster=[...s.registry.objects.values()].find(o=>o.objectType===5&&o!==s.player&&(o.creatureData??o.authored).ClassList?.reduce((n,c)=>n+c.ClassLevel,0)<=4);assert.ok(buffCaster);
 await s.enterArea(s.registry.get(buffCaster.areaId).resRef,buffCaster.position);s.scheduler.beforePump=()=>s.worldTimer.snapshot();s.scheduler.events=[];s.random.seed(1);
 const actor=s.player,events=[],enqueue=s.combat.enqueueEvent.bind(s.combat);s.combat.enqueueEvent=(...a)=>{if(a[0]===14)events.push(structuredClone(a));return enqueue(...a);};
 const invoke=async(id,caster=actor)=>{caster.nativeSpellClass22c=0;caster.nativeSpellDomain21c=0;caster.nativeSpellMetamagic22d=0;
  const spell=s.spellBook.castingSpell(id);s.combat.enqueueEvent(8,caster.id,caster.id,0,{spellId:id,casterId:caster.id,targetId:actor.id,itemId:OBJECT_INVALID,featId:65535,
   position:[actor.position[0],-actor.position[2],actor.position[1]],script:spell.impactScript});await s.scheduler.pump();
  const deadline=s.scheduler.time+1000;while(s.scheduler.events[0]?.due<=deadline){s.scheduler.advance(s.scheduler.events[0].due-s.scheduler.time);await s.scheduler.pump();}
 };
 const begin=runtimeDiagnostics.records.length;await invoke(100,buffCaster);await invoke(365,buffCaster);const before=structuredClone(actor.effects);assert.ok(before.some(e=>e.spellId===100));assert.ok(before.some(e=>e.spellId===365));
 await invoke(id);const after=structuredClone(actor.effects),errors=runtimeDiagnostics.records.slice(begin).filter(d=>d.severity==='error');assert.deepEqual(errors,[]);
 for(const event of events){assert.equal(event[1],actor.id);assert.equal(event[2],actor.id);assert.equal(event[3],0);assert.ok(!after.some(e=>e.id===event[4].id),'event14 removes every linked record');}
 rows.push({id,script:s.spellBook.castingSpell(id).impactScript,buffCasterId:buffCaster.id,before,after,events,vision:actor.visionFlags,diagnostics:runtimeDiagnostics.records.slice(begin)});
}
console.log(JSON.stringify({rows,limits:'Real installed buff/dispel impact scripts, real RNG and deferred linked-ID removal; isolated replacement sessions without ordinary cast/resource/release, general world AI, renderer or campaign acceptance.'},null,2));
assert.ok(rows.every(r=>r.events.length>0),'each installed dispel fixture must actually remove an active spell');
