// Actual installed runtime against the separately executed ORIGINAL stat
// pipeline, not a universal "HP must return unchanged" assumption. These
// isolated fixtures do not run campaign AI or claim complete visual parity.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {intEntry,rulesetInt} from '../src/combat_stats.js';
import {scriptAbilityModifier} from '../src/ability_modifier_cache.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-form-defenses-v1.json',report={hp:[],turn:[]},native=JSON.parse(await fs.readFile('backups/animations/native-polymorph-hp-pipeline-observations.json','utf8'));
const make=async()=>new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
try{
 for(const [form,injury]of [[26,0],[40,0],[26,7],[40,7]]){
  const s=await make(),o=s.player,root=o.creatureData,stats=o.stats,equipment=o.nativeEquipment;await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];
  report.loadDiagnostics??=[...runtimeDiagnostics.records];const start=runtimeDiagnostics.records.length,table=await s.items.table('polymorph'),race=root.Race,con=intEntry(table,form,'CON'),formRace=intEntry(table,form,'RacialType'),profile={base:root.Con,initialAdjust:intEntry(s.characterRules.racialtypes,race,'ConAdjust').value,formAdjust:intEntry(s.characterRules.racialtypes,formRace.found?formRace.value:race,'ConAdjust').value,formCon:con.found?con.value&255:null,dice:root.LvlStatList.map(v=>v.LvlStatHitDie),toughness:s.combat.hasFeat(o,40)!==0,injury};
  const row=native.rows.find(row=>JSON.stringify(row.case)===JSON.stringify(profile));assert.ok(row,'Installed fixture must match an executed ORIGINAL pipeline profile');
  o.nativeSpellClass22c=0;o.nativeSpellFeat23c=65535;stats.currentHP=stats.maxHP-injury;s.damage.synchronize(o);
  const snapshot=()=>({hp:stats.currentHP,maximum:s.effects.abilityProviders().maximumHP(o,1),con:root.Con,modifier:scriptAbilityModifier(o,2)}),before=snapshot(),ids=[...equipment.ids];assert.deepEqual(before,row.before);
  const effect=s.commands.EffectPolymorph([form,0],{self:o.id});effect.durationType=1;effect.duration=60;await s.effects.applyNative(effect,o.id);const changed=snapshot();assert.deepEqual(changed,row.changed);
  await s.effects.remove(o.id,effect.id);s.scheduler.advance(501);s.worldTimer.snapshot();await s.effects.updateObject(o);const restored=snapshot();assert.deepEqual(restored,row.restored);
  assert.equal(s.registry.get(o.id),o);assert.equal(o.creatureData,root);assert.equal(o.stats,stats);assert.equal(o.nativeEquipment,equipment);assert.deepEqual([...equipment.ids],ids);
  report.hp.push({form,profile,before,changed,restored,nativeCompared:true,diagnostics:runtimeDiagnostics.records.slice(start)});
 }
 const s=await make(),pc=s.player,npc=[...s.registry.objects.values()].find(o=>o.objectType===5&&o.nativeStatsIsPCb0===0),rule=rulesetInt(s.characterRules,'TURN_RESISTANCE_AFFECTS_PCS',0);assert.ok(npc);const start=runtimeDiagnostics.records.length;
 for(const actor of [pc,npc]){
  const initial=s.commands.GetTurnResistanceHD([actor.id]),increase=s.commands.EffectTurnResistanceIncrease([7],{self:pc.id}),decrease=s.commands.EffectTurnResistanceDecrease([4],{self:pc.id});assert.equal(increase.type,77);assert.equal(decrease.type,88);assert.equal(increase.subtype,8);assert.equal(decrease.creatorId,pc.id);
  for(const e of [increase,decrease]){e.durationType=2;await s.effects.applyNative(e,actor.id);}
  const changed=s.commands.GetTurnResistanceHD([actor.id]),eligible=rule!==0||actor.nativeStatsIsPCb0===0;assert.equal(changed,initial+(eligible?3:0));
  for(const e of [increase,decrease])await s.effects.remove(actor.id,e.id);assert.equal(s.commands.GetTurnResistanceHD([actor.id]),initial);report.turn.push({actorId:actor.id,statsPC:actor.nativeStatsIsPCb0,rule,initial,changed,restored:initial});
 }
 report.turnDiagnostics=runtimeDiagnostics.records.slice(start);
}catch(error){report.failure={message:error.message,stack:error.stack};}
report.errors=[...report.hp.flatMap(r=>r.diagnostics),...(report.turnDiagnostics??[])].filter(r=>r.severity==='error');await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({hpCases:report.hp.length,turnCases:report.turn.length,failure:report.failure,errors:report.errors}));if(report.failure||report.errors.length)process.exitCode=1;
