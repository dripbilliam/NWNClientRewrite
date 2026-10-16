// Live queued casting with a controlled incoming processed-damage event.
// Native RNG and skills remain real; no synthetic spell slots or spell effects.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',rows=[];
for(const {amount,prime} of [{amount:1,prime:false},{amount:20,prime:false},{amount:20,prime:true}]){
 const messages=[],s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)})
  .initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 const target=[...s.registry.objects.values()].find(o=>o.objectType===5&&/goblin/i.test(o.tag));assert.ok(target);
 await s.enterArea(s.registry.get(target.areaId).resRef,[target.position[0]+2,target.position[1],target.position[2]]);await s.combat.updatePerception(s.player,target,1);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 const actor=s.player,spellId=144,start=runtimeDiagnostics.records.length,uses=()=>s.spellBook.uses(actor,spellId,0,0,0),before=uses(),impacts=[],run=s.runScript.bind(s);assert.ok(before>0);
 s.runScript=(name,id,options)=>{if(name.toLowerCase()===s.spellBook.castingSpell(spellId).impactScript.toLowerCase())impacts.push(name);return run(name,id,options);};
 const tick=async()=>{s.scheduler.advance(100);s.worldTimer.snapshot();await s.combat.updateTimer(actor,100);await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));await s.scheduler.pump();};
 if(prime){const prior=s.queuePlayerCastSpell({spellId:100,classIndex:0,targetId:actor.id});await s.drainPlayerInputs();assert.equal(await prior,1);
  for(let n=0;n<200&&(actor.objectActionState.list.count||actor.combatRound.started);n++)await tick();assert.equal(actor.nativeSpellClass22c,0);assert.equal(actor.objectActionState.list.count,0);}
 const request=s.queuePlayerCastSpell({spellId,classIndex:0,targetId:target.id});await s.drainPlayerInputs();assert.equal(await request,1);
 for(let n=0;n<50&&!([15,16].includes(actor.animationState)&&actor.objectActionState.list.head?.action.actionId===15);n++)await tick();
 assert.equal(actor.objectActionState.list.head?.action.actionId,15);assert.ok([15,16].includes(actor.animationState));const hpBefore=actor.stats.currentHP;assert.ok(hpBefore>amount);
 const classBefore=actor.nativeSpellClass22c;s.random.seed(1);const hit=s.commands.EffectDamage([amount,4],{self:target.id});hit.integers[36]=1;await s.effects.apply(0,hit,actor.id);assert.equal(actor.stats.currentHP,hpBefore-amount);
 const afterHit={animation:actor.animationState,queue:[...actor.objectActionState.list].map(n=>n.actionId),uses:uses()};
 for(let n=0;n<150&&actor.objectActionState.list.count;n++)await tick();
 const errors=runtimeDiagnostics.records.slice(start).filter(d=>d.severity==='error');assert.deepEqual(errors,[]);assert.equal(uses(),before-(amount===1||classBefore!==255?1:0));assert.equal(actor.objectActionState.list.count,0);
 if(amount===1){assert.ok(afterHit.queue.includes(15));assert.equal(impacts.length,1);}else{assert.equal(afterHit.animation,14);assert.ok(!afterHit.queue.includes(15));assert.equal(impacts.length,0);}
 rows.push({amount,prime,classBefore,spellId,actorId:actor.id,targetId:target.id,hpBefore,hpAfter:actor.stats.currentHP,before,after:uses(),afterHit,impacts,messages,diagnostics:runtimeDiagnostics.records.slice(start)});
}
console.log(JSON.stringify({rows,limits:'Live local cast queue, installed character/impact script, real skills/RNG/resources and controlled incoming damage during conjure. General AI/startup disabled; not independent original-process, full encounter, rendering or network acceptance.'},null,2));
