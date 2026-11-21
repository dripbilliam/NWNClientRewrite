// Actual active character/class/item/race/2DA data through shared stat owners.
// This isolates base setters and polymorph AC queries; no form cast is claimed.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {scriptAbilityModifier} from '../src/ability_modifier_cache.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,modulePath,output='backups/animations/installed-polymorph-stat-owners-v1.json']=process.argv.slice(2),report={rows:[]};
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)}),o=s.player,root=o.creatureData,stats=o.stats,identity=o.id;
report.loadDiagnostics=[...runtimeDiagnostics.records];const start=runtimeDiagnostics.records.length;s.scheduler.events=[];
const snapshot=()=>({id:o.id,base:Object.fromEntries(['Str','Dex','Con','Int','Wis','Cha'].map(k=>[k,root[k]])),scores:structuredClone(stats.equippedAbilities),modifiers:Array.from({length:6},(_,i)=>scriptAbilityModifier(o,i)),hp:stats.currentHP,maxHP:stats.maxHP,temporaryHP:stats.temporaryHP??0,ac:stats.combat.armorClass,natural:structuredClone(stats.combat.finalBreakdown.armor.natural),equipment:[...o.nativeEquipment.ids],effects:structuredClone(o.effects),dirty:o.nativeField544});
try{
 const originalHP=stats.currentHP;stats.currentHP=stats.maxHP-7;stats.temporaryHP=9;s.damage.synchronize(o);
 const names=['Str','Dex','Con','Int','Wis','Cha'];
 for(const [index,name]of names.entries()){
  const before=snapshot(),value=root[name];await s.setBaseAbility(o,index,value+4,1);const changed=snapshot();
  assert.equal(root[name],(value+4)&255);assert.equal(changed.scores[name],before.scores[name]+4);assert.equal(changed.modifiers[index],before.modifiers[index]+2);
  if(index===2){assert.equal(changed.maxHP-changed.hp,before.maxHP-before.hp);assert.ok(changed.maxHP>before.maxHP);}else assert.equal(changed.hp,before.hp);
  assert.equal(changed.temporaryHP,before.temporaryHP);assert.deepEqual(changed.equipment,before.equipment);assert.deepEqual(changed.effects,before.effects);
  await s.setBaseAbility(o,index,value,1);const restored=snapshot();assert.deepEqual(restored.base,before.base);assert.deepEqual(restored.scores,before.scores);assert.deepEqual(restored.modifiers,before.modifiers);assert.equal(restored.hp,before.hp);assert.equal(restored.maxHP,before.maxHP);
  report.rows.push({name,before,changed,restored});
 }
 // Exactly1 adjusts native HP. Other flags update the CON cache only, with no
 // synthetic dying/death event, even when a decrease makes HP exceed maxHP.
 const con=root.Con,beforeNoAdjust=snapshot();await s.setBaseAbility(o,2,con+2,2);const noAdjust=snapshot();assert.equal(noAdjust.hp,beforeNoAdjust.hp);assert.notEqual(noAdjust.maxHP,beforeNoAdjust.maxHP);await s.setBaseAbility(o,2,con,0);assert.equal(stats.currentHP,beforeNoAdjust.hp);report.noAdjust={before:beforeNoAdjust,changed:noAdjust,restored:snapshot()};
 const table=await s.items.table('polymorph'),entry=table.orderedRows.findIndex(r=>Number(r.NATURALACBONUS)>0);assert.ok(entry>=0);const form=table.orderedRows[entry],originalNatural=root.NaturalAC,originalCache=o.nativeNaturalACD51;
 const beforeArmor=snapshot();o.nativeNaturalACD51=Number(form.NATURALACBONUS)&255;
 for(const gate of ['nativeField9f4','nativeField97c']){
  o[gate]=1;s.refreshCombat(o);const changed=snapshot();assert.equal(root.NaturalAC,originalNatural);assert.equal(changed.natural.authored,(o.nativeNaturalACD51<<24)>>24);assert.deepEqual(changed.natural.classGains,[]);assert.equal(changed.natural.armorSkin,beforeArmor.natural.armorSkin);assert.equal(changed.natural.dwarvenDefender,beforeArmor.natural.dwarvenDefender);
  o[gate]=0;s.refreshCombat(o);assert.equal(stats.combat.armorClass,beforeArmor.ac);report.rows.push({gate,physicalForm:entry,activeNaturalAC:form.NATURALACBONUS,before:beforeArmor,changed,restored:snapshot()});
 }
 o.nativeNaturalACD51=originalCache;stats.currentHP=originalHP;stats.temporaryHP=0;s.damage.synchronize(o);assert.equal(o.creatureData,root);assert.equal(o.stats,stats);assert.equal(s.registry.get(identity),o);report.canonicalIdentityPreserved=true;
}catch(error){report.failure={message:error.message,stack:error.stack};}
report.diagnostics=runtimeDiagnostics.records.slice(start);report.errors=report.diagnostics.filter(r=>!['info','warning'].includes(r.severity));await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({rows:report.rows.length,failure:report.failure,errors:report.errors}));if(report.failure||report.errors.length)process.exitCode=1;
