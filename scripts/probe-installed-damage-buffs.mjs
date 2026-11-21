import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-damage-buffs-v1.json',report={spells:[],messages:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>report.messages.push(m)}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];const actor=s.player;report.playerId=actor.id;const start=runtimeDiagnostics.records.length;
 const drain=async()=>{for(let n=0;n<1000&&s.scheduler.events.length;n++){s.scheduler.time=Math.max(s.scheduler.time,s.scheduler.events[0].due);await s.dispatch(s.scheduler.events.shift());}};
 for(const [script,type,icon]of [['nw_s0_endele',2,1],['nw_s0_stoneskn',12,3],['x0_s0_divfav',13,31],['nw_s0_fireshld',16,null]]){
  const spellId=s.characterRules.spells.orderedRows.findIndex(r=>String(r.ImpactScript).toLowerCase()===script);assert.ok(spellId>=0,script);
  actor.nativeSpellId218=spellId;actor.nativeSpellTarget214=actor.id;actor.nativeSpellPoint208=[...actor.position];actor.nativeSpellClass22c=0;actor.nativeSpellFeat23c=65535;actor.nativeSpellMetamagic22d=0;actor.nativeSpellDomain21c=0;
  const before=new Set(actor.effects.map(e=>e.id)),messageStart=report.messages.length;await s.runScript(script,actor.id);await drain();
  const added=actor.effects.filter(e=>!before.has(e.id)),parents=added.filter(e=>e.type===type),icons=added.filter(e=>e.type===67),result={script,spellId,effects:structuredClone(added),messages:report.messages.slice(messageStart),cache:actor.damageImmunityCache?.slice()};report.spells.push(result);
  assert.ok(parents.length,`${script} admits native type${type}`);assert.ok(icons.length,`${script} admits child icon`);
  for(const parent of parents){const children=icons.filter(e=>e.id===parent.id);assert.ok(children.length);if(icon!==null)assert.ok(children.some(e=>e.integers[0]===icon));assert.ok(children.every(e=>e.integers.slice(1).every(v=>v===0)));}
  if(type===2||type===12)assert.deepEqual(result.messages.filter(m=>m.type==='effectFloaty').map(m=>m.data.strref),Array(parents.length).fill(type===2?2234:2233));
  for(const id of new Set(added.map(e=>e.id)))await s.effects.remove(actor.id,id);s.scheduler.events=[];assert.equal(actor.effects.some(e=>added.some(a=>a.id===e.id)),false);
 }
 report.diagnostics=runtimeDiagnostics.records.slice(start);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);assert.deepEqual(report.diagnostics.filter(d=>d.code==='effects.presentation-unimplemented'&&[2,12,13,14,16,17].includes(d.context?.effectType)),[]);
 report.limits='Unchanged installed wizard and four installed authored impact scripts under active Prelude resolver. Canonical native spell context, parent/icon identity, cleared child payload, cache snapshots and group removal checked. General AI/startup/entry isolated; direct impact invocation does not prove class eligibility, complete casting UI, damage resolution, save/protocol or campaign readiness. All load failures and other warnings retained.';
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({playerId:report.playerId,spells:report.spells.map(({script,spellId,effects})=>({script,spellId,types:effects.map(e=>e.type),icons:effects.filter(e=>e.type===67).map(e=>e.integers[0])})),failure:report.failure}));if(report.failure)process.exitCode=1;
