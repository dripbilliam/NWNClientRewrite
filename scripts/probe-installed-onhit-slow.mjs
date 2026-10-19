import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {resolveOnHitProperty} from '../src/on_hit_property.js';
import {getAttackData} from '../src/combat_attack_data.js';
import {advanceLocalClocks,advanceToEffectExpiry} from './advance-effect-clock.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-onhit-slow-v1.json',report={checks:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/cleric.bic`)}),actor=s.player,target=[...s.registry.objects.values()].find(o=>o.objectType===5&&/goblin/i.test(o.tag)&&!o.plot&&!s.isDead(o)&&s.scriptEmotion(actor.id,o.id,'enemy')===1);assert.ok(target);
 await s.enterArea(s.registry.get(target.areaId).resRef,[target.position[0]+2,target.position[1],target.position[2]]);s.scheduler.events=[];s.scheduler.beforePump=()=>{};
 const item=s.equippedItems(actor).find(i=>(i.data.PropertiesList??[]).some(p=>p.PropertyName===48&&p.Subtype===9));assert.ok(item);const property=item.data.PropertiesList.find(p=>p.PropertyName===48&&p.Subtype===9),before=runtimeDiagnostics.records.length,refs=[...s.registry.objects],round=getAttackData(actor.combatRound,actor.combatRound.currentAttack&255),startingCursor=s.registry.nextObjectId[0];
 for(const immune of [false,true]){
  let immunity;if(immune){immunity=s.commands.EffectImmunity([9],{self:actor.id});await s.effects.apply(2,immunity,target.id);assert.notEqual(await s.combat.immunity(target,9,actor,1),0);}
  let selected=false;const attempts=[];for(let seed=1;seed<=128&&!selected;seed++){
   s.random.seed(seed);round.lists[0].length=0;await resolveOnHitProperty(actor,target,item,property,0,0,s.combat.onHitPropertyProviders(item,property));attempts.push({seed,payloadTypes:round.lists[0].map(e=>e.type)});selected=round.lists[0].some(e=>e.type===40);
  }assert.ok(selected,'Real active property chance/save gates must admit a payload');
  const payloads=round.lists[0].splice(0),link=payloads.find(e=>e.type===40),id=link.id;assert.equal(link.linkLeft.type,3);assert.equal(link.linkRight.integers[0],207);
  for(const payload of payloads)await s.combat.dispatchEvent(target,{eventId:5,callerId:actor.id,payload});assert.equal(target.nativeField180,0);
  if(immune){assert.ok(!target.effects.some(e=>e.id===id),'Rejected mechanical effect also removes its linked visual');assert.equal(target.nativeSlow764,0);await s.effects.remove(target.id,immunity.id);}
  else{const slow=target.effects.find(e=>e.type===3&&e.id===id);assert.ok(slow);assert.equal(target.nativeSlow764,1);assert.ok(target.effects.some(e=>e.id===id&&e.type===30&&e.integers[0]===207));advanceToEffectExpiry(s,slow);await s.effects.updateObject(target,s.activeTimer(target.id).time());advanceLocalClocks(s,1);await s.effects.updateObject(target,s.activeTimer(target.id).time());assert.ok(!target.effects.some(e=>e.id===id));assert.equal(target.nativeSlow764,0);}
  report.checks.push({check:immune?'active-property-save-gates-and-immune-linked-visual-cleanup':'active-property-save-gates-native-event-mechanical-visual-and-natural-expiry',itemId:item.id,targetId:target.id,property:{type:property.PropertyName,subtype:property.Subtype,cost:property.CostValue,param:property.Param1Value},attempts,duration:link.duration,id});
 }
 for(const[id,o]of refs)assert.equal(s.registry.get(id),o);assert.equal(s.registry.nextObjectId[0],startingCursor);runtimeDiagnostics.flushRepeated();report.diagnostics=runtimeDiagnostics.records.slice(before);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.loadDiagnostics=runtimeDiagnostics.records.slice(0,before);report.validation='PASS';report.limits='Installed Prelude/cleric equipped property and canonical hostile goblin, active IPRP_ONHIT/IPRP_ONHITDUR/cost tables, original-style RNG and actual saves. Explicit seed search admits native chance/save gates; no fixed success or DC. Real payload generation, combat event5/flag, effect/controller/linked visuals, shared-ID cleanup and native natural expiry. Immunity uses real EffectImmunity9 as an explicit NCS binding fixture. Individual dispatcher/delivery owners isolated from attack admission/damage/AI; separate broad Fear scenario exercises those. No renderer, full campaign or network acceptance; all diagnostics retained.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(c=>c.check),error:report.error,diagnostics:report.diagnostics?.length}));
