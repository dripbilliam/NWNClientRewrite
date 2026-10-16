// Installed active forms + real shared equipment/effect/area/stat owners.
// Direct ApplyEffect and authored impact are isolated from unrelated actor AI;
// normal cast admission/release/render are verified separately by the UI smoke.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {intEntry} from '../src/combat_stats.js';
const [install='../FullDecomp/NwnRootInstall',modulePath=`${install}/data/nwm/Prelude.nwm`,output='backups/animations/installed-polymorph-form-v1.json']=process.argv.slice(2),report={forms:[]},messages=[];
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
const o=s.player,root=o.creatureData,stats=o.stats,equipment=o.nativeEquipment,id=o.id;
await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];const start=runtimeDiagnostics.records.length,table=await s.items.table('polymorph');
o.nativeSpellClass22c=0;o.nativeSpellFeat23c=65535;o.nativeSpellMetamagic22d=0;o.nativeSpellDomain21c=0;
const snapshot=()=>({id:o.id,appearance:root.Appearance_Type,race:root.Race,portrait:root.Portrait,portraitId:root.PortraitId??65535,sound:root.SoundSetFile,base:[root.Str,root.Dex,root.Con],hp:stats.currentHP,maxHP:stats.maxHP,temporaryHP:stats.temporaryHP??0,ac:stats.combat.armorClass,natural:stats.combat.finalBreakdown.armor.natural,locked:o.nativeField97c,position:[...o.position],areaId:o.areaId,equipment:[...equipment.ids],effects:structuredClone(o.effects)});
try{
 const custom=process.argv.find(v=>v.startsWith('--forms='))?.slice(8),selected=custom?custom.split(',').map(Number):process.argv.includes('--all')?table.orderedRows.flatMap((_r,n)=>intEntry(table,n,'AppearanceType').found?[n]:[]):[3,0,1,2,4];
 for(const form of selected){
  report.currentForm=form;const before=snapshot();report.lastBefore=before;const owned=before.equipment.filter(n=>n!==0x7f000000).map(n=>s.registry.get(n)),e=s.commands.EffectPolymorph([form,0],{self:id});e.durationType=1;e.duration=60;
  await s.effects.applyNative(e,id);const changed=snapshot();report.lastChanged=changed;assert.equal(changed.locked,1);assert.equal(changed.appearance,intEntry(table,form,'AppearanceType').value&65535);assert.deepEqual([...o.nativePolymorphEquipment980],before.equipment);
  assert.equal(o.nativeField9f4,0);assert.ok(o.effects.some(v=>v.type===83&&v.integers[0]===289));assert.equal(s.registry.get(id),o);assert.equal(o.stats,stats);assert.equal(o.nativeEquipment,equipment);assert.equal(o.creatureData,root);
  const shape=changed.equipment.filter(n=>n!==0x7f000000);assert.ok(shape.every(n=>!before.equipment.includes(n)));
  const pending=s.queuePlayerCancelPolymorph();await s.drainPlayerInputs();await pending;assert.equal(o.nativeField97c,1);assert.equal(o.effects.find(v=>v.type===62).duration,.5);
  s.scheduler.advance(500);s.worldTimer.snapshot();await s.effects.updateObject(o);assert.equal(o.nativeField97c,1);
  s.scheduler.advance(1);s.worldTimer.snapshot();await s.effects.updateObject(o);const restored=snapshot();
  assert.equal(restored.locked,0);assert.equal(o.nativeField9f4,0);assert.deepEqual(restored.equipment,before.equipment);assert.equal(restored.appearance,before.appearance);assert.equal(restored.race,before.race);assert.equal(restored.portrait,before.portrait);assert.equal(restored.sound,before.sound);assert.deepEqual(restored.base,before.base);
  if(process.argv.includes('--observe-hp')){if(restored.hp!==before.hp)(report.hpChanges??=[]).push({form,before:before.hp,after:restored.hp});}else assert.equal(restored.hp,before.hp);
  assert.equal(restored.maxHP,before.maxHP);assert.equal(restored.temporaryHP,before.temporaryHP);
  assert.ok(!o.effects.some(v=>[15,62,67,83].includes(v.type)));for(const item of owned)assert.equal(s.registry.get(item.id),item);for(const item of shape)assert.equal(s.registry.get(item),undefined);
  assert.equal(s.currentArea.nativeSpatial.ids.filter(n=>n===id).length,1);assert.equal(s.currentArea.nativePlayerCount150,1);
  report.forms.push({form,before,changed,restored,shapeItemsDestroyed:shape,canonicalIdentityPreserved:true});
 }
}catch(error){report.failure={message:error.message,stack:error.stack};report.failureState=snapshot();}
report.hpObservationMode=process.argv.includes('--observe-hp');report.messages=messages;report.diagnostics=runtimeDiagnostics.records.slice(start);report.errors=report.diagnostics.filter(r=>r.severity==='error');await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({forms:report.forms.length,hpObservationMode:report.hpObservationMode,hpChanges:report.hpChanges,failure:report.failure,errors:report.errors}));if(report.failure||report.errors.length)process.exitCode=1;
