import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-effect-copies-v1.json',report={spells:[],direct:[],vision:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];const actor=s.player,identity=actor.id,stats=actor.stats,baseline=new Set(actor.effects.map(e=>e.id));report.playerId=identity;const start=runtimeDiagnostics.records.length;
 const drain=async()=>{for(let n=0;n<1000&&s.scheduler.events.length;n++){s.scheduler.time=Math.max(s.scheduler.time,s.scheduler.events[0].due);await s.dispatch(s.scheduler.events.shift());}};
 const added=()=>actor.effects.filter(e=>!baseline.has(e.id));
 const purge=async()=>{for(let n=0;n<100&&added().length;n++)await s.effects.remove(actor.id,added()[0].id);assert.deepEqual(added(),[]);s.scheduler.events=[];assert.equal(s.registry.get(identity),actor);assert.equal(actor.stats,stats);};
 const checkIcons=rows=>{for(const e of rows.filter(e=>e.type===67)){assert.ok(e.integers.slice(1).every(n=>n===0));assert.ok(e.floats.every(n=>n===0));assert.ok(e.objectIds.every(n=>n===0x7f000000));assert.ok(e.strings.every(n=>n===''));assert.equal(e.customTag,'');assert.equal(e.exposed,false);}};
 for(const [script,type]of [['nw_s0_bullstr',36],['nw_s0_haste',1],['nw_s0_invisib',47],['nw_s0_imprinvis',76],['nw_s0_darkvis',71],['nw_s0_truesee',72],['nw_s0_splresis',33]]){
  const spellId=s.characterRules.spells.orderedRows.findIndex(r=>String(r.ImpactScript).toLowerCase()===script);assert.ok(spellId>=0,script);actor.nativeSpellId218=spellId;actor.nativeSpellTarget214=actor.id;actor.nativeSpellPoint208=[...actor.position];actor.nativeSpellClass22c=0;actor.nativeSpellFeat23c=65535;actor.nativeSpellMetamagic22d=0;actor.nativeSpellDomain21c=0;
  await s.runScript(script,actor.id);await drain();const rows=added();report.spells.push({script,spellId,effects:structuredClone(rows)});assert.ok(rows.some(e=>e.type===type),`${script} retains type${type}`);checkIcons(rows);await purge();
 }
 actor.nativeSpellId218=-1;
 for(const [command,type]of [['EffectSilence',46],['EffectFrightened',8],['EffectStunned',8]]){
  const e=s.commands[command]([],{self:identity});await s.effects.apply(2,e,identity);const rows=added();report.direct.push({command,effects:structuredClone(rows),state:actor.nativeField771,silence:actor.nativeSilence75c});assert.ok(rows.some(e=>e.type===type));assert.ok(rows.some(e=>e.type===67));checkIcons(rows);await purge();assert.equal(actor.nativeField771,0);assert.equal(actor.nativeSilence75c,0);
 }
 // Suppression uses a fresh ID; restoring an inactive row preserves that ID.
 // Exercise canonical darkness membership, actual shared removal and attributes.
 const volume=s.register('areaOfEffect','owned-copy-fixture-darkness',{nativeAreaEffectId30c:36});actor.nativeSubareaMembership.append(volume.id);
 for(const command of ['EffectUltravision','EffectTrueSeeing']){
  const dark=s.commands.EffectDarkness([],{self:identity}),vision=s.commands[command]([],{self:identity});await s.effects.apply(2,dark,identity);const active=added().find(e=>e.type===73);assert.ok(active);await s.effects.apply(2,vision,identity);const inactive=added().find(e=>e.type===89);assert.ok(inactive);assert.notEqual(inactive.id,active.id);assert.equal(inactive.integers[0],8);assert.equal(inactive.exposed,active.exposed);assert.equal(inactive.showIcon,active.showIcon);
  await s.effects.remove(identity,vision.id);const restored=added().find(e=>e.type===73);assert.ok(restored);assert.equal(restored.id,inactive.id);report.vision.push({command,active:structuredClone(active),inactive:structuredClone(inactive),restored:structuredClone(restored)});await purge();assert.equal(actor.visionFlags&14,0);
 }
 actor.nativeSubareaMembership.remove(volume.id);s.unregister(volume.id);
 const beamId=s.characterRules.visualeffects.orderedRows.findIndex(r=>String(r.Type_FD).toUpperCase()==='B');assert.ok(beamId>=0);const beam=s.commands.EffectBeam([beamId,identity,1,0,2,[1,2,3],[4,5,6]],{self:identity});await s.effects.apply(1,beam,identity,2);const visual=added().find(e=>e.type===30);assert.ok(visual);assert.equal(visual.id,beam.id);assert.equal(visual.integers[0],beamId);assert.equal(visual.objectIds[0],identity);assert.deepEqual(visual.floats,[2,0,0,0]);assert.deepEqual(visual.vectors,[[1,2,3],[4,5,6]]);assert.ok(visual.integers.slice(3).every(n=>n===0));report.beam={beamId,effect:structuredClone(visual)};await purge();
 report.diagnostics=runtimeDiagnostics.records.slice(start);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.canonicalIdentityPreserved=true;
 report.limits='Read-only installed wizard and active Prelude resources; seven unchanged authored impact scripts, direct engine silence/fear/stun and beam applications, real child handlers and group cleanup, plus darkness/vision suppression/restoration with canonical membership and effect IDs. General AI/startup/entry isolated. Direct impacts do not prove class eligibility or normal cast UI for every listed spell; no whole campaign, HUD buff art, save/protocol completion claim. All unrelated warnings/load failures retained.';
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({playerId:report.playerId,spells:report.spells.map(({script,spellId,effects})=>({script,spellId,types:effects.map(e=>e.type)})),direct:report.direct.map(r=>r.command),vision:report.vision.map(r=>({command:r.command,active:r.active.id,inactive:r.inactive.id,restored:r.restored.id})),beam:report.beam?.beamId,failure:report.failure}));if(report.failure)process.exitCode=1;
