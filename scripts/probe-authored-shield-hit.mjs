// Direct installed shield impacts followed by a processed weapon-damage event.
// This is reflection integration, not a full attack/roll/release fixture.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',rows=[];
for(const id of [47,519,524]){
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0})
  .initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 const attacker=[...s.registry.objects.values()].find(o=>o.objectType===5&&/goblin/i.test(o.tag));assert.ok(attacker);
 await s.enterArea(s.registry.get(attacker.areaId).resRef,[attacker.position[0]+2,attacker.position[1],attacker.position[2]]);s.scheduler.beforePump=()=>s.worldTimer.snapshot();s.scheduler.events=[];s.random.seed(1);
 const actor=s.player,spell=s.spellBook.castingSpell(id),start=runtimeDiagnostics.records.length;actor.nativeSpellClass22c=0;actor.nativeSpellDomain21c=0;actor.nativeSpellMetamagic22d=0;
 s.combat.enqueueEvent(8,actor.id,actor.id,0,{spellId:id,casterId:actor.id,targetId:actor.id,itemId:OBJECT_INVALID,featId:65535,position:[actor.position[0],-actor.position[2],actor.position[1]],script:spell.impactScript});await s.scheduler.pump();
 while(s.scheduler.events[0]?.due<=1000){s.scheduler.advance(s.scheduler.events[0].due-s.scheduler.time);await s.scheduler.pump();}
 assert.ok(actor.effects.some(e=>e.type===61));const hpBefore={defender:actor.stats.currentHP,attacker:attacker.stats.currentHP};
 const hit=s.commands.EffectDamage([1,4],{self:attacker.id});hit.integers[36]=1;await s.effects.apply(0,hit,actor.id);await s.scheduler.pump();
 const diagnostics=runtimeDiagnostics.records.slice(start),errors=diagnostics.filter(d=>d.severity==='error');assert.deepEqual(errors,[]);
 assert.equal(actor.stats.currentHP,hpBefore.defender-1);assert.ok(attacker.stats.currentHP<hpBefore.attacker);
 rows.push({id,script:spell.impactScript,actorId:actor.id,attackerId:attacker.id,hpBefore,hpAfter:{defender:actor.stats.currentHP,attacker:attacker.stats.currentHP},diagnostics});
}
console.log(JSON.stringify({rows,limits:'Actual installed shield scripts, active IPRP_DAMAGECOST/DamageHitVisual, real reflection/mitigation/HP/death. Incoming processed damage is a fixture, not an independently played attack; general AI and startup disabled. No original-process/network/renderer acceptance.'},null,2));
